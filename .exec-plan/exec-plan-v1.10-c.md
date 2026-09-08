# SKILL-v1.10 定向生产验证 — 执行计划

> **版本**: exec-plan-v1.10-c
> **制定日期**: 2026-09-09
> **依据**: `.GPT/Production Validation Prompt — SKILL-v1.10 Targeted Validation.md`（唯一事实源）
> **被测对象**: `SKILL-v1.10.md`
> **执行模式**: 单一 sub-agent 串行执行，禁止任何形式的多 sub-agent 并行
> **生产主运行环境**: Windows + PowerShell 7.x
> **兼容性回归环境**: PowerShell 5.1（不作为当前生产准入主环境）
> **修订记录**: 见 §9 修订日志

---

## 0. 计划总览

### 0.1 核心目标

v1.9 修复了 v1.8 的 T38/T22/T23 异常路径清理与锁释放问题，但 T38 仍存在 P1：Step 4 的多个不可恢复错误路径以裸 `return` 终止，未输出 `RUN_STATUS|failed|` 终态。

v1.10 的唯一修复目标：

```
Step 4 所有不可恢复错误出口
    ↓
cleanup（tmp 清理）
    ↓
lock release（锁释放）
    ↓
明确最终失败状态（RUN_STATUS|failed|）
```

v1.10 新增 constraint #13（SKILL L81）：

> 步骤 4 的不可恢复错误路径必须在清理/锁处理之后输出且仅输出一次 `RUN_STATUS|failed|`，不得以裸 `return` 作为最终状态。

### 0.1.1 目标与完成定义（DoD）

```
Step 4 所有不可恢复错误路径被真实注入失败
        ↓
每条路径均输出 REVIEW_WRITE_ERROR| / RUNTIME_ERROR|
        ↓
每条路径均输出 RUN_STATUS|failed|（constraint #13）
        ↓
tmp 清理 + lock release 正确执行
        ↓
主 md / result.json / stats / items 未被错误修改
        ↓
PRODUCTION_READY（P0=0, P1=0, FAIL=0, BLOCKED=0, 全部硬门槛 PASS）
        ↓
禁止出现的假成功：RUN_STATUS|failed| 被改写为 PASS / 旧证据冒充新证据 / 被测 SKILL 被修改以消除失败
```

### 0.1.2 输入基线

开工前采集以下关键对象的指纹（Phase 0 执行）：

| 对象 | 指纹类型 | 保存文件 | 消费者（复核环节） |
|---|---|---|---|
| `SKILL-v1.10.md` | SHA256 | `v110.sha256` | Phase 11 self-review 第 1/2 项 |
| `SKILL-v1.9.md` | SHA256 | `v19.sha256` | Phase 11 self-review 第 11 项 |
| `.output/GitHub更新监测列表.md` | SHA256 | `state.sha256` | Phase 11 self-review 基线完整性 |

### 0.2 v1.9 → v1.10 Diff 概要

以下为基于 `git diff --no-index SKILL-v1.9.md SKILL-v1.10.md` 的变更分析（详见 Phase 1）：

| 变更点 | SKILL-v1.10 行号 | v1.9 行为 | v1.10 修复 |
|---|---|---|---|
| constraint #13 新增 | L81 | 不存在 | 新增：不可恢复错误路径须输出 RUN_STATUS\|failed\| |
| heartbeat 失败 | L477 | 裸 return | 新增 `RUN_STATUS\|failed\|步骤4 heartbeat 失败，整轮终止。` + return |
| result.json 读取失败 | L478 | 无 try/catch（异常冒泡） | 新增 try/catch：lock release + `RUN_STATUS\|failed\|读取 result.json 失败` + return |
| stats/items 完整性失败 | L480 | `Release-LockSafely; return`（裸 return） | 新增 `RUN_STATUS\|failed\|review 程序事实完整性校验失败` — **注意：return 被移除，执行落入后续 try 块** |
| review tmp 写入失败 | L487 | 裸 return | 新增 `RUN_STATUS\|failed\|review 写入失败` + return |
| review JSON 校验失败 | L496 | 裸 return | 新增 `RUN_STATUS\|failed\|review 临时 JSON 校验失败` + return |
| review 原子替换失败 | L506 | 裸 return | 新增 `RUN_STATUS\|failed\|review 原子替换失败` + return |
| Changelog | L766 | 不存在 | 新增 v1.10 变更条目（L768） |

**关键发现**：L480 stats/items 完整性失败路径移除了 `return`，输出 `RUN_STATUS|failed|` 后执行落入后续 `try { $doc|ConvertTo-Json... }` 块（L481）。其他 5 条错误路径（L487/L496/L506/heartbeat/result.json-read）均在 `RUN_STATUS|failed|` 后保留 `return`。此不一致性是本轮 T38 验证重点之一。

### 0.3 执行架构

```
Phase 0 (sub-agent) → 主 agent 审查 → Phase 1 (sub-agent) → 主 agent 审查 → ... → Phase 11 (sub-agent) → 主 agent self-review → Phase 12 (主 agent)
```

- **严格串行**：下一 Phase 仅在上一 Phase 的主 agent 审查通过后启动
- **单一 sub-agent**：每个 Phase 派遣且仅派遣一个 sub-agent 执行
- **禁止并行**：任何时刻最多一个 sub-agent 在运行

### 0.4 中断接续方案

| 中断类型 | 检测方式 | 恢复策略 |
|---|---|---|
| LLM API 调用失败 | sub-agent 无返回或返回错误 | 主 agent 重试同一 Phase，传入 `resume_from` 参数指向已完成步骤 |
| 网络波动 | GitHub API 调用超时/失败 | 步骤内退避重试（max_retries=3），仍失败则标记 BLOCKED |
| 资源限制 | sub-agent 输出截断/不完整 | 主 agent 检查已产出证据文件，从断点继续 |
| sub-agent 上下文溢出 | sub-agent 返回不完整结果 | 主 agent 核验已生成证据，拆分剩余工作到新 sub-agent |

**断点保存机制**：每个 Phase 完成后，sub-agent 须在测试目录下生成 `phase-progress.json`：

```json
{
  "phase": "Phase0",
  "start_time": "2026-09-09T10:00:00Z",
  "end_time": "2026-09-09T10:30:00Z",
  "status": "completed|partial|failed",
  "completed_steps": ["step1", "step2"],
  "pending_steps": [],
  "evidence_files": ["v110.sha256", "v19.sha256"],
  "next_phase": "Phase1"
}
```

主 agent 在启动下一 Phase 前读取此文件，确认状态为 `completed` 后方可继续。若 `partial`，则向新 sub-agent 传入 `resume_from` 参数。**恢复不依赖会话记忆，只依据产物文件 + progress 文件 + `resume_from`。**

### 0.5 测试隔离机制

所有测试通过 `GITHUB_VERSION_MONITOR_BASE` 环境变量实现 fixture 隔离。SKILL-v1.10 每个 step 均支持此变量（SKILL L163/L241/L432/L474/L522）。

- 每个测试子目录作为独立 base 目录
- 通过 `$env:GITHUB_VERSION_MONITOR_BASE = '<test-dir>'` 指向测试目录
- `.monitor/` 由 Step 1 在 base 目录下动态创建（Prompt §1 要求运行态在测试目录重新生成）
- `.output/GitHub更新监测列表.md` 使用 fixture 副本，不触碰生产文件

**Mock 重定向机制**（用于 T02/T04/T05/T08 状态机测试）：

SKILL 中 API URL 硬编码为 `https://api.github.com`（SKILL L341/L479），无 base 覆盖机制。测试采用 **PowerShell 函数覆盖** 方案：
1. 提取 step2.ps1 代码原样保存（不修改）
2. 测试 harness 在 dot-source step2.ps1 前，先定义 mock `Invoke-RestMethod` 函数覆盖内置 cmdlet
3. Mock 函数根据测试场景返回受控 HTTP 响应（状态码 + headers + body）
4. 此方案不修改被测代码，仅在运行时注入函数覆盖

**T46 运行目录**：T46 测试在 `.production-validation-v110-final/T46/` 目录下运行，通过 `GITHUB_VERSION_MONITOR_BASE` 指向该目录，不触碰生产根目录。

### 0.6 独立性原则

本计划是"独立"验证的执行计划。以下原则适用于计划制定与执行全过程：

```
1. 所有测试设计决策必须基于以下两个事实源的直接阅读：
   - SKILL-v1.10.md 源码（行号 + 代码逻辑）
   - Production Validation Prompt — SKILL-v1.10 Targeted Validation 原文

2. 旧版本验证报告（v17/v18/v19）的结论不得作为本轮测试设计的依据。
   旧报告中的发现只能作为"待独立验证的声明"，不能作为已验证事实。

3. 如果在计划制定过程中引用了旧报告的发现，
   必须在执行阶段由 sub-agent 独立验证该发现是否成立。
   验证方法：实际运行相关脚本/工具，记录独立证据。

4. 旧报告的"结论"（如 PASS/FAIL/P2 计数）仅供信息参考，
   不得影响本轮任何测试的构造方法、验证项或判定逻辑。

5. 链式继承风险：如果 v1.9 引用了 v1.8 的结论，
   v1.8 引用了 v1.7 的结论，… 一直回溯到 v1.1，
   那么最初版本的任何系统性偏差将沿链传播到所有后续版本。
   本计划通过上述原则切断此继承链。
```

### 0.7 执行模式

- 所有脚本经 `pwsh -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>` 执行（后台静默，输出重定向到文件）。
- **进程模型声明**：`-File` 模式下每个脚本独立进程，**脚本间无共享变量**。凡需"中途注入/在同进程内分段控制"的场景，必须设计同进程 harness（内联复制目标代码 + 明确注入点 + 受限 diff 验证），并说明为何其他方式（如 dot-source）不可行。
- 常驻辅助进程（监听/锁持有）用 `Start-Process -WindowStyle Hidden` 启动、测试后 `Stop-Process` 终止。

### 0.8 正式汇报：执行模式声明

**后台静默模式覆盖范围**：本计划全部 13 个 Phase（Phase 0-12）的所有执行操作和测试流程均采用后台静默模式运行，确保不会弹出任何前台窗口或对话框干扰用户正常操作。

具体实现：
- PowerShell 脚本：`pwsh -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>`（PS7）或 `powershell.exe -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>`（PS5.1 兼容性测试）
- 常驻辅助进程（文件锁持有者、并发锁持有者）：`Start-Process -WindowStyle Hidden` 启动，`Stop-Process` 终止
- 同进程 harness（T39/T38-B/T38-stats-items）：`pwsh -NoProfile -NonInteractive -File <harness.ps1> *>&1 > <output.txt>`

**前台执行模式声明**：本计划**不存在**必须使用前台执行模式的特殊场景。所有测试（包括 PS5.1 兼容性测试、并发锁测试、进程终止测试）均可通过后台静默模式完成。

> 如执行过程中因环境限制（如 PS5.1 不存在、ACL 权限不足）导致某测试无法在后台静默模式完成，sub-agent 须标记 BLOCKED 并在 test-report.md 中记录具体原因，不得自动切换至前台模式。

### 0.9 任务追踪机制

主 agent 维护一张全局任务追踪表，记录每个 Phase 的执行状态。此表在主 agent 审查点更新，不依赖 sub-agent 的会话记忆。

**追踪表模板**（主 agent 在每个 Phase 审查通过后更新）：

| Phase | 模块名 | 开始时间 | 结束时间 | 执行状态 | 关键节点 | 审查结果 |
|---|---|---|---|---|---|---|
| 0 | Clean-Room + SHA256 | {{ISO8601}} | {{ISO8601}} | completed | 3 SHA256 文件生成 / git add 完成 | PASS |
| 1 | Diff + 代码提取 | {{ISO8601}} | {{ISO8601}} | completed | 28 项能力核验 / 5 脚本提取 | PASS |
| 2 | T38 P1 回归 | {{ISO8601}} | {{ISO8601}} | {{status}} | T38-A/B/C/heartbeat/result-read/stats-items 结果 | {{result}} |
| 3 | T22/T23 回归 | {{ISO8601}} | {{ISO8601}} | {{status}} | T22/T23 结果 | {{result}} |
| 4 | T37 成功回归 | {{ISO8601}} | {{ISO8601}} | {{status}} | RUN_STATUS\|success\| 确认 | {{result}} |
| 5 | T39 回归 | {{ISO8601}} | {{ISO8601}} | {{status}} | commit+lock 失败终态确认 | {{result}} |
| 6 | T43+T46 | {{ISO8601}} | {{ISO8601}} | {{status}} | 全管线+路径契约确认 | {{result}} |
| 7 | T04+T05-PS7+T26+T18 | {{ISO8601}} | {{ISO8601}} | {{status}} | 状态机+flag+保留确认 | {{result}} |
| 8 | PS5.1 兼容 | {{ISO8601}} | {{ISO8601}} | {{status}} | PS5.1 header 兼容确认 | {{result}} |
| 9 | Lock+ProcessKill | {{ISO8601}} | {{ISO8601}} | {{status}} | 并发/陈锁/ownership/kill 确认 | {{result}} |
| 10 | 静态审计+Invariant | {{ISO8601}} | {{ISO8601}} | {{status}} | early-return audit / I1-I7 确认 | {{result}} |
| 11 | Self-Review | {{ISO8601}} | {{ISO8601}} | {{status}} | 16 项复核完成 | {{result}} |
| 12 | Final Report | {{ISO8601}} | {{ISO8601}} | {{status}} | 报告生成 / commit 完成 | {{result}} |

**追踪表保存位置**：`.production-validation-v110-final/task-tracker.md`（主 agent 维护，每个 Phase 审查后更新）

**追踪表与 phase-progress.json 的关系**：
- `phase-progress.json`：sub-agent 生成，记录 Phase 内部步骤级进度（自动化恢复用）
- `task-tracker.md`：主 agent 维护，记录 Phase 级全局状态（审查与决策用）
- 两者互为补充：恢复时先读 `task-tracker.md` 确定从哪个 Phase 继续，再读该 Phase 的 `phase-progress.json` 确定从哪个步骤继续

---

## 1. 模块分解

### 模块总览表

| Phase | 模块名 | 输入 | 输出 | 优先级 |
|---|---|---|---|---|
| 0 | Clean-Room + Git/SHA256 + 被测对象纳入 git | SKILL-v1.9.md, SKILL-v1.10.md, .output/...md | 目录树 + 3 个 SHA256 文件 + git staging | 基础 |
| 1 | Diff Integrity + 代码提取 + 工具集 | v1.9/v1.10 SHA256 + 两文件 | diff-integrity.md + lib/*.ps1 + extraction-manifest.json + mock 工具 | 基础 |
| 2 | T38 — 核心 P1 回归 + 多异常分支 | lib/step4.ps1, fixture | T38-A/B/C + heartbeat + result.json-read + stats/items-integrity 测试目录 + 证据 | **硬门槛** |
| 3 | T22/T23 — md tmp 写入/原子替换失败回归 | lib/step5-full.ps1, fixture | T22 + T23 测试目录 + 证据 | **硬门槛** |
| 4 | T37 — 正常成功回归 | lib/step1-5.ps1, fixture | T37 测试目录 + 证据 | **硬门槛** |
| 5 | T39 — Commit 成功 + 锁释放失败 | lib/step5-t39-harness.ps1, fixture | T39 测试目录 + 证据 | **硬门槛** |
| 6 | T43 + T46 — 全管线 + 路径契约 | fixture（6 场景） | T43 + T46 测试目录 + 证据 | **关键** |
| 7 | T04 + T05-PS7 + T26 + T18 — 状态机 + Flag + 状态保留 | lib/step2-mock-harness.ps1, fixture | 多个测试目录 + 证据 | 中 |
| 8 | PS5.1 兼容性回归 | lib/mock-invoke-restmethod.ps1, PS5.1 | 2 个测试目录 + 证据 | 兼容 |
| 9 | Lock 回归 + Process Kill | lib/step1.ps1, fixture | 多个测试目录 + 证据 | 中 |
| 10 | Runtime Error Contract 静态审计 + Final Invariant | SKILL-v1.10.md 全文 + 全部前序证据 | early-return-final-status-audit.md + invariant-verification.md | **关键** |
| 11 | Self-Review | 全部 Phase 0-10 证据 | selfreview-v19.md | 质量控制 |
| 12 | Final Report + Commit | 全部证据 | production-validation-report-v110-final.md | 收尾 |

### 拆解规则

1. **输入封闭**：每个模块的输入只允许来自（a）事实源文件（b）已通过审查的前序 Phase 产出。模块间**只通过产物文件传递状态**，绝不通过 sub-agent 的会话记忆传递。
2. **输出清单化**：每个模块的产出是逐文件清单，可被审查点逐项核对。
3. **粒度**：单模块工作量 = 单个 sub-agent 一次会话可完成（上下文预算内）；超出则继续拆分。
4. **优先级语义**：硬门槛 = 失败即整体判定失败；关键 = 失败进入高风险复核；中/辅助 = 失败记录不阻断。硬门槛模块已在总览表中显式标注。
5. **第一模块固定为基线采集**（指纹 + 环境确认），**倒数第二模块固定为独立复核**，**最后模块固定为汇总收尾**。

---

## 2. 各 Phase 详细规格

---

### Phase 0: Clean-Room + Git/SHA256 + 被测对象纳入 git

**前置条件**: 项目根目录 `d:\AI\Workspace\automatic\github-version-monitor` 存在且为 git 仓库

**输入参数**:
- 项目根目录: `d:\AI\Workspace\automatic\github-version-monitor`
- 测试目录: `.production-validation-v110-final/`
- 被测文件: `SKILL-v1.9.md`, `SKILL-v1.10.md`, `.output/GitHub更新监测列表.md`

**处理逻辑**:
1. 创建 `.production-validation-v110-final/` 目录树：
   ```
   .production-validation-v110-final/
   ├── lib/
   ├── T22/
   ├── T23/
   ├── T37/
   ├── T38-A/
   ├── T38-B/
   ├── T38-C/
   ├── T38-heartbeat/
   ├── T38-result-read/
   ├── T38-stats-items/
   ├── T39/
   ├── T43/
   ├── T46/
   ├── T02/  (预留，Prompt 未定义)
   ├── T04-PS7/
   ├── T04-PS5.1/
   ├── T05-PS7/
   ├── T05-PS5.1/
   ├── T08/  (预留，Prompt 未定义)
   ├── T14/  (预留，Prompt 未定义)
   ├── T15/  (预留，Prompt 未定义)
   ├── T16/  (预留，Prompt 未定义)
   ├── T17/  (预留，Prompt 未定义)
   ├── T18/
   ├── T19/  (预留，Prompt 未定义)
   ├── T26/
   ├── schema/
   ├── lock-concurrency/
   ├── lock-ownership/
   ├── lock-stale-alive/
   ├── lock-stale-dead/
   ├── runtime-error-contract/
   ├── process-kill/
   ├── invariant-verification/
   ├── .selfreview/
   └── phase-progress.json
   ```
   > **`.monitor/` 不在目录树中预创建**：由 Step 1 在每个测试的 base 目录下动态创建。

2. 禁止复用 `.production-validation/`、`.production-validation-v17-final/`、`.production-validation-v18-final/` 中的实际测试状态作为当前 PASS 证据（Prompt §1: `OLD_EVIDENCE_USED_AS_CURRENT_PASS = NO`）

3. 计算 3 个文件 SHA256（Prompt §3）：
   ```powershell
   Get-FileHash .\SKILL-v1.9.md -Algorithm SHA256
   Get-FileHash .\SKILL-v1.10.md -Algorithm SHA256
   Get-FileHash .\.output\GitHub更新监测列表.md -Algorithm SHA256
   ```
   保存为 `v19.sha256`、`v110.sha256`、`state.sha256`

4. **将被测对象纳入 git**：
   - 确认 `SKILL-v1.10.md` 的 git 跟踪状态（`git ls-files SKILL-v1.10.md`）
   - 若为 untracked，执行 `git add SKILL-v1.10.md` 将其纳入版本控制
   - Prompt §2 要求"从当前 Git repository 获取 SKILL-v1.10.md"，§27 要求"Git repository = 唯一事实源"
   - 此操作不修改文件内容，仅纳入版本跟踪

**输出结果**:
- `.production-validation-v110-final/v19.sha256`
- `.production-validation-v110-final/v110.sha256`
- `.production-validation-v110-final/state.sha256`
- `.production-validation-v110-final/phase-progress.json`
- `SKILL-v1.10.md` 已 `git add`（staged，如之前为 untracked）

**证据要求**:
- `.production-validation-v110-final/phase0-stdout.txt` — 创建目录 + SHA256 计算的完整 stdout
- `.production-validation-v110-final/phase0-stderr.txt`
- `.production-validation-v110-final/phase0-report.md` — 执行摘要

**主 agent 审查点**（全部满足才放行）:
- [ ] 确认 3 个 SHA256 文件存在且内容非空
- [ ] 确认目录树结构完整（与上方清单逐项核对）
- [ ] 确认 `git status` 显示 `SKILL-v1.10.md` 已 staged 或已 tracked
- [ ] 确认未复用旧测试目录的 fixture/stdout/结果文件

**失败处理**: 目录创建失败 → 检查磁盘空间与权限后重试；git add 失败 → 检查文件路径后重试。

---

### Phase 1: Diff Integrity + 代码提取 + 工具集

**前置条件**: Phase 0 完成，3 个 SHA256 文件存在

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- v1.9 SHA256: 从 Phase 0 产出读取
- v1.10 SHA256: 从 Phase 0 产出读取
- 源文件: `SKILL-v1.9.md`, `SKILL-v1.10.md`

**处理逻辑**:

#### Step 1: 生成 diff（Prompt §4）

```powershell
git diff --no-index SKILL-v1.9.md SKILL-v1.10.md > .production-validation-v110-final/v19-v110.diff; exit 0
```

> **退出码处理**：`git diff --no-index` 在存在差异时退出码为 1（属预期行为）。追加 `; exit 0` 归零退出码，避免 `-File` 模式下脚本进程退出码非零被误判为 Phase 1 失败。

#### Step 2: Diff 完整性分析

必须确认 v1.10 保留 v1.9 的全部关键能力（逐项显式核验，共 28 项，Prompt §4）：

```
versionJump
dateSuspicious
reviewReasons

schema validation
strict lowercase yes/no

404 -> not_found
rate_limited
network_error
auth_error
forbidden
server_error
invalid_response
metadata_incomplete

result.fetch.tmp
result.review.tmp

lock
heartbeat
ownership

atomic result persistence
atomic review persistence
atomic md commit

commitSucceeded
COMMIT_OK
RUN_STATUS|success|
RUN_STATUS|failed|

.output/GitHub更新监测列表.md
PS7 production baseline
PS5.1 compatibility
```

特别检查：不得因 v1.10 修复异常路径而删除任何 v1.9 已验证能力。

#### Step 3: 禁止项检查（Prompt §4）

确认以下内容不存在于 v1.10 diff 中：

```
mock URL
forced success
debug bypass
test-only branch
hardcoded token
hardcoded test repository
skip schema
skip lock
skip commit
```

#### Step 4: v1.10 新增/修改验证（Prompt §4）

核心应为：

```
Step 4 所有不可恢复错误出口
    ↓
cleanup
    ↓
lock release
    ↓
明确最终失败状态
```

尤其修复（Prompt §4）：

```
T38
review write failure
→ REVIEW_WRITE_ERROR
→ RUN_STATUS|failed|
```

以及同层其他提前 `return` 路径。

**逐路径核验**（基于 SKILL-v1.10.md 直接阅读）：

| 错误路径 | SKILL 行号 | v1.9 有 return? | v1.10 有 return? | v1.10 有 RUN_STATUS\|failed\|? |
|---|---|---|---|---|
| heartbeat 失败 | L477 | 是 | 是 | 是 |
| result.json 读取失败 | L478 | 无 try/catch | 是（新增） | 是（新增） |
| stats/items 完整性失败 | L480 | 是 | **否（移除）** | 是（新增） |
| review tmp 写入失败 | L487 | 是 | 是 | 是（新增） |
| review JSON 校验失败 | L496 | 是 | 是 | 是（新增） |
| review 原子替换失败 | L506 | 是 | 是 | 是（新增） |

> **L480 关键发现**：stats/items 完整性失败路径在 v1.10 中移除了 `return`。输出 `RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。` 后执行落入 L481 `try { $doc|ConvertTo-Json... }` 块。Phase 2 的 T38-stats-items 测试须验证此落入行为是否导致二次输出或异常。

#### Step 5: 从 SKILL-v1.10.md 提取 PowerShell 代码块

逐字提取，禁止修改被测代码。提取的脚本仅用于测试执行环境控制，不改变逻辑：

- `lib/step1.ps1` — Step 1（状态检查 + 锁 + 备份）
- `lib/step2.ps1` — Step 2（解析 + 查询 + 状态机 + 统计）
- `lib/step3.ps1` — Step 3（备份清理）
- `lib/step4.ps1` — Step 4（复核）
- `lib/step5-full.ps1` — Step 5 完整（提交 + 锁释放 + RUN_STATUS）

> **注意**：SKILL Step 6 是 agent 汇报模板，无 PowerShell 代码块，不需要提取。计划中"完整 Step 1→6"指 Step 1→5 代码执行 + Step 6 汇报模板。

#### Step 6: 创建 T39 专用 harness 脚本

- `lib/step5-t39-harness.ps1` — T39 同进程测试 harness

**设计原因**：SKILL Step 5 中 `$commitSucceeded`（L621/L627）和 `$lockReleased`（L638/L644）是同进程局部变量。若拆分为两个独立脚本通过 `pwsh -File` 执行，跨进程无法传递变量，导致测试失去区分度。

**实现方式**：仅内联复制（dot-source 不可行）

> dot-source `step5-full.ps1` 会一次性连续执行完整 Step 5（commit 段 + 锁释放段），不存在"执行至 Move-Item 成功后暂停"的注入点。唯一可行方式是**内联复制 Step 5 代码并注入**。

**注入点**：SKILL L636（`}` — if/else 块整体结束）与 L637（`# 释放锁前确认 ownership`）之间。此切分点在 if/else 块完全结束后、锁释放逻辑开始前，技术干净。

**注入内容**：在 L636 之后、L637 之前插入：
```powershell
# T39 注入：模拟锁被外来 PID 持有
Set-Content $lockPath -Value "pid=999999;ts=$(Get-Date -Format o)" -Force
```

**前置变量**：harness 须预置 `$conclusionText` / `$summaryText` / `$noteText`（SKILL L539-547 占位值），否则 Step 5 md 组装失败。

#### Step 7: 创建测试工具

- `lib/run-full-pipeline.ps1` — 串行执行 step1→step5-full
- `lib/mock-invoke-restmethod.ps1` — mock `Invoke-RestMethod` 覆盖函数库
- `lib/step2-mock-harness.ps1` — mock 测试包装脚本：定义 mock `Invoke-RestMethod` → dot-source `step2.ps1`
- `lib/create-fixture.ps1` — fixture 生成工具
  - **localVer 策略**：synced/versionJump 场景须运行时动态查询 `releases/latest` 获取最新 release 版本后生成 fixture（synced: localVer=最新版本；versionJump: localVer=低版本使 major 差 ≥2 或 minor 差 ≥10）；404 场景使用不存在的 repo 名称；normal/uninstalled/unsupported 使用固定 fixture。动态查询策略避免上游发版导致场景漂移。
- `lib/extract-code.ps1` — 代码提取工具

> **PS5.1 语法兼容要求**：`mock-invoke-restmethod.ps1` 和 `step2-mock-harness.ps1` 在 Phase 1（PS7 环境）创建，但被 Phase 8（PS5.1 环境）复用。这两个脚本须使用 PS5.1 兼容语法（禁用 PS7-only 运算符如 `??`、`<# #>` 内联等），否则 Phase 8 意外失败的原因与被测对象无关。Phase 1 对齐自检中须增加语法兼容检查。

#### Step 7.1: mock 对象 contract

`mock-invoke-restmethod.ps1` 须按场景返回仿真对象，成员形状与 SKILL 状态机访问路径一致（SKILL L341-367 直接核实）：

**成功路径**（`Invoke-RestMethod` 正常返回）：

| 场景 | mock 返回对象 | SKILL 访问路径 |
|---|---|---|
| normal / versionJump | `PSCustomObject` 含 `tag_name`(string) + `published_at`(ISO date) | L342 `$j.tag_name` / `$j.published_at` |
| metadata_incomplete | `PSCustomObject` 含 `tag_name`(string) 但无 `published_at` | L347-349 |
| invalid_response | `PSCustomObject` 含空 `tag_name` 或无 `tag_name` | L350-351 |

**异常路径**（`Invoke-RestMethod` 抛异常）：

| 场景 | mock 异常对象 | SKILL 访问路径 |
|---|---|---|
| 404 (not_found) | `Exception.Response.StatusCode = 404` | L362 |
| 401 (auth_error) | `Exception.Response.StatusCode = 401` | L361 |
| 429 (rate_limited) | `Exception.Response.StatusCode = 429` | L363 |
| 403+remaining=0 (rate_limited) | `StatusCode = 403` + `Headers['X-RateLimit-Remaining'] = '0'` | L364 |
| 403+remaining>0 (forbidden) | `StatusCode = 403` + `Headers['X-RateLimit-Remaining'] = '50'` | L364 |
| 5xx (server_error) | `StatusCode = 500` | L365 |
| 其他 HTTP (http_error) | `StatusCode = 302` | L366 |
| network_error | 异常无 `.Exception.Response`（如 timeout） | L367 else 分支 |

**PS5.1 兼容要求**：T04/T05-PS5.1 验证 `Get-ResponseHeaderValue` 对 `System.Net.WebHeaderCollection` 的兼容性。mock 的 `Headers` **必须是 `System.Net.WebHeaderCollection` 实例**（不可用 `Hashtable` 替代），否则兼容性验证无意义。

**类型规范**：

- `Exception.Response.StatusCode`：SKILL L355 以 `[int]$_.Exception.Response.StatusCode` 显式转换后做数值比较（L361-366），因此 mock 侧使用 `int`（如 `404`）或 `System.Net.HttpStatusCode` 枚举实例均可兼容；推荐枚举实例以贴近真实响应形状。
- `X-RateLimit-Remaining` 取值：SKILL L364 以字符串比较（`$rl -eq '0'`），mock Headers 返回值**必须为字符串** `'0'` / `'50'`（不得为 int）。
- `Exception.Response` 必须真实存在（`$_.Exception.Response` 为真值），network_error 场景则必须**无** `.Response` 或 `.Response.StatusCode` 为 null。
- **PS7 侧 `Headers` 类型选择**：二选一并记录于 `lib/mock-contract-selfcheck.txt`——
  a) `System.Net.WebHeaderCollection`（与 PS5.1 共用同一 mock 库，实现简单；但本轮 `Get-ResponseHeaderValue` 面向 PS7 真实响应的 `HttpResponseHeaders` 分支将无直接覆盖）；
  b) `System.Net.Http.Headers.HttpResponseHeaders` 形状对象（覆盖更完整，构造复杂度高）。
  无论选择哪种，最终报告 **J 节** 必须如实记录 PS7 header 分支的覆盖方式。

**对齐自检**：mock 函数库构造完成后、任何测试执行前，sub-agent 须做一次 "contract → SKILL 提取表达式" 对齐自检：按 SKILL L341-367 逐成员模拟访问，确认每个场景取值路径与 contract 表一致，结果记录于 `lib/mock-contract-selfcheck.txt`（含 PS7 Headers 类型选择记录）。

#### Step 8: 生成提取清单

生成 `lib/extraction-manifest.json`，记录每个提取脚本的源行号范围与 SHA256：

```json
{
  "source_file": "SKILL-v1.10.md",
  "source_sha256": "<v110.sha256 值>",
  "extractions": [
    {
      "file": "step1.ps1",
      "source_lines": "155-227",
      "sha256": "<提取文件 SHA256>"
    },
    {
      "file": "step2.ps1",
      "source_lines": "...",
      "sha256": "<提取文件 SHA256>"
    },
    ...
  ]
}
```

此清单供 Phase 11 self-review 验证提取脚本与原文一致性。

> **harness 逐字性验证**：`step5-t39-harness.ps1` 内联复制了 SKILL Step 5 代码并注入一段 PID 修改逻辑。Phase 11 第 4 项验证须对 harness 做受限 diff——与 SKILL 原文 Step 5 代码块仅允许存在一处注入差异（L636-L637 之间的 PID 修改），其余代码须逐字一致。

> **stdout 捕获策略**：Phase 1 代码提取完成后，由 sub-agent 独立运行 `run-full-pipeline.ps1` 一次，实际验证 stdout 透传行为并记录证据（`lib/stdout-verification.txt`）。
> - 如果独立验证确认 stdout 透传正常 → T37/T43 使用 `run-full-pipeline.ps1` 单次执行 + 捕获 stdout
> - 如果独立验证确认 stdout 透传异常 → T37/T43 改为逐 step 独立执行 + 拼接 stdout
> - 无论哪种结果，决策依据是本轮独立验证，而非旧报告声明

**输出结果**:
- `.production-validation-v110-final/v19-v110.diff`
- `.production-validation-v110-final/diff-integrity.md`
- `.production-validation-v110-final/lib/step1.ps1` ~ `step5-full.ps1`
- `.production-validation-v110-final/lib/step5-t39-harness.ps1`
- `.production-validation-v110-final/lib/step4-t38b-harness.ps1`
- `.production-validation-v110-final/lib/step4-t38-stats-items-harness.ps1`
- `.production-validation-v110-final/lib/run-full-pipeline.ps1`
- `.production-validation-v110-final/lib/mock-invoke-restmethod.ps1`
- `.production-validation-v110-final/lib/step2-mock-harness.ps1`
- `.production-validation-v110-final/lib/create-fixture.ps1`
- `.production-validation-v110-final/lib/extract-code.ps1`
- `.production-validation-v110-final/lib/extraction-manifest.json`
- `.production-validation-v110-final/lib/mock-contract-selfcheck.txt`
- `.production-validation-v110-final/lib/stdout-verification.txt`
- `.production-validation-v110-final/phase-progress.json`

**证据要求**:
- `.production-validation-v110-final/phase1-stdout.txt`
- `.production-validation-v110-final/phase1-stderr.txt`
- `.production-validation-v110-final/phase1-report.md`

**主 agent 审查点**:
- [ ] 确认 diff-integrity.md 中 28 项能力逐项核验完成
- [ ] 确认 10 项禁止项检查完成
- [ ] 确认 6 条 Step 4 错误路径逐路径核验表完成（含 L480 return 移除发现）
- [ ] 确认 5 个 step 脚本 + 4 个 harness + 4 个辅助工具全部按输出清单产出
- [ ] 确认 extraction-manifest.json 存在且非空
- [ ] 确认 stdout-verification.txt 与 mock-contract-selfcheck.txt 存在且记录了独立验证结果

**失败处理**: diff 生成失败 → 检查文件路径后重试；代码提取与原文不一致 → 立即中止并标 BLOCKED。

---

### Phase 2: T38 — 核心 P1 回归 + 多异常分支（硬门槛）

**前置条件**: Phase 1 完成，lib/step4.ps1 提取完成

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- 提取的脚本: `lib/step4.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

这是本轮验证的**最高优先级**（Prompt §5: "这是本轮最高优先级"）。

使用外部 fault injection，使 `.monitor/result.review.tmp` 无法正常写入。

#### T38-A: review tmp 创建/写入失败（Prompt §6 T38-A）

**目标**: SKILL L481 `Set-Content -Path $tmpPath -Encoding UTF8` 真实失败。

**构造方法**: 在 Step 4 执行前，使 `result.review.tmp` 无法被 `Set-Content` 写入。

方法选项（sub-agent 选择其一，不得修改 SKILL）：
- 预创建 `result.review.tmp` 文件并以 `[System.IO.File]::Open()` 独占锁定（`FileShare::None`），阻止 `Set-Content` 覆盖
- 通过 ACL deny 拒绝当前用户对 `.monitor` 目录的 CreateFiles 权限
- **注意**：Windows `ReadOnly` 属性**不阻止**文件创建/覆盖，不可作为构造方法
- **ACL 方案前置断言**：ACL deny CreateFiles 仅阻止**新文件创建**，不阻止对已存在文件的覆盖。若 `result.review.tmp` 因前次运行残留已存在，Set-Content 覆盖将成功 → 注入失败 → 测试假阴性。施加 ACL 前须确认 `result.review.tmp` 不存在（存在则先删除并记录）。

**ACL 恢复步骤**（如使用 ACL 方案）：
1. 构造前记录 `.monitor` 目录原始 ACL：`Get-Acl $monitorDir | Export-Clixml T38-A/acl-before.xml`
2. 施加 deny 规则
3. 测试执行
4. 测试后还原 ACL：`Import-Clixml T38-A/acl-before.xml | Set-Acl $monitorDir`
5. 验证还原成功：`Get-Acl $monitorDir` 确认 deny 规则已移除

**验证项**:
```
result.json unchanged       — SHA256 before vs after 不变
stats unchanged
items unchanged
lock released               — run.lock 不存在或 PID 不匹配
REVIEW_WRITE_ERROR|         — 输出中存在
RUN_STATUS|failed|          — 输出中存在
no COMMIT_OK                — 输出中不存在
no RUN_STATUS|success|      — 输出中不存在
```

**tmp 清理验证（按构造方法区分）**:
- ACL 方案：`result.review.tmp` 未创建（Set-Content 被 ACL 阻止），tmp 不存在
- 文件锁方案：catch 块执行了 `Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue`（L483），但外部进程持锁期间无法删除；**外部进程终止后**确认 tmp 已删除

**重点**: 异常必须经过明确错误分支（`REVIEW_WRITE_ERROR|` + `RUN_STATUS|failed|`），而不是直接退出脚本导致执行上下文异常终止。

#### T38-B: review JSON validation failure（Prompt §6 T38-B）

**目标**: SKILL L490-491 `Get-Content $tmpPath -Raw|ConvertFrom-Json` 校验失败。

**构造方法**: 使 `result.review.tmp` 内容写入成功但 JSON 结构无效，导致 `ConvertFrom-Json` 失败或后续校验不通过。

方法选项：
- 在 Set-Content 执行后、ConvertFrom-Json 执行前，通过外部进程将 `result.review.tmp` 内容替换为非法 JSON
- 此方案需同进程 harness（因 `-File` 模式下脚本不可暂停），在 `Set-Content` 与 `Get-Content` 之间注入文件篡改

> **同进程 harness 设计**：提取 Step 4 代码，在 L481（`Set-Content`）与 L490（`Get-Content $tmpPath`）之间注入：
> ```powershell
> # T38-B 注入：篡改 tmp 文件内容为非法 JSON
> Set-Content $tmpPath -Value '{invalid json' -Force
> ```
> 精确注入点：L489（第一个 try/catch 块结束 `}`）之后、L490（第二个 try 块开始 `try { $check=Get-Content $tmpPath...`）之前。此切分点在两个 try/catch 块之间，技术干净。

**验证项**:
```
result.json unchanged
tmp cleaned
lock released
REVIEW_WRITE_ERROR|review 临时 JSON 校验失败  — 输出中存在
RUN_STATUS|failed|review 临时 JSON 校验失败   — 输出中存在
no COMMIT_OK
no RUN_STATUS|success|
```

#### T38-C: review tmp → result.json atomic replacement failure（Prompt §6 T38-C）

**目标**: SKILL L500 `Move-Item $tmpPath $resultPath -Force` 真实失败。

**构造方法**: 使 Move-Item 无法替换 result.json。

方法选项：
- 对目标 `result.json` 设置外部文件锁：使用 `[System.IO.File]::Open()` 以 `FileShare::None` 锁住目标文件
- 文件锁通过 `Start-Process -WindowStyle Hidden` 在后台进程中持有，测试完成后终止

**验证项**:
```
result.json unchanged
tmp cleaned
lock released
REVIEW_WRITE_ERROR|review 原子替换失败  — 输出中存在
RUN_STATUS|failed|review 原子替换失败   — 输出中存在
no COMMIT_OK
no RUN_STATUS|success|
```

#### T38-heartbeat: heartbeat 失败终态验证

**目标**: SKILL L477 heartbeat 失败路径。

**构造方法**: 使 `[IO.File]::Open($lockPath,...)` 失败（如锁文件被外部进程独占）。

方法选项：
- 在 Step 4 执行前，通过外部进程以 `FileShare::None` 锁住 `run.lock` 文件
- Step 4 的 heartbeat 刷新尝试打开锁文件将失败

**验证项**:
```
RUNTIME_ERROR|步骤4 heartbeat 失败          — 输出中存在
RUN_STATUS|failed|步骤4 heartbeat 失败       — 输出中存在
no RUN_STATUS|success|
lock retained（因 heartbeat 失败后 return，锁未释放）  — 或按 SKILL 实际行为判断
```

> **条件化期望**：heartbeat 失败后直接 `return`（L477），未调用 `Release-LockSafely`。锁状态取决于 Step 1 创建的锁是否仍由当前 PID 持有。审查点须根据实际 stdout 判断，不得假设锁已释放。

#### T38-result-read: result.json 读取失败终态验证

**目标**: SKILL L478 新增的 result.json 读取 try/catch。

**构造方法**: 使 `Get-Content $resultPath -Raw` 失败（如 result.json 不存在或被外部进程锁住）。

方法选项：
- 在 Step 4 执行前删除 `result.json`（使 `Get-Content` 抛 `PathNotFound`）
- 或通过外部进程独占锁住 `result.json`

**验证项**:
```
RUNTIME_ERROR|读取 result.json 失败           — 输出中存在
lock released                                — Release-LockSafely 被调用
RUN_STATUS|failed|读取 result.json 失败      — 输出中存在
no RUN_STATUS|success|
no REVIEW_WRITE_ERROR|（此路径不涉及 review tmp）
```

#### T38-stats-items: stats/items 完整性失败终态验证

**目标**: SKILL L480 stats/items 完整性失败路径。**此路径在 v1.10 中移除了 `return`，是本轮关键发现。**

**构造方法**: 使 review 修改了 stats 或 items（`$newStats -ne $origStats` 或 `$newItems -ne $origItems`），触发完整性校验失败。

方法选项：
- 使用同进程 harness，在 review 逻辑执行后、完整性校验前，注入对 `$doc.stats` 或 `$doc.items` 的修改
- 注入点：SKILL L479（foreach 超长行，循环体全在此行）与 L480（$doc.review 赋值 + $newStats/$newItems 计算 + if 校验混合行）之间

> **同进程 harness 设计**：提取 Step 4 代码，在 L479 与 L480 之间注入：
> ```powershell
> # T38-stats-items 注入：篡改 stats 使完整性校验失败
> $doc.stats.total = 999
> ```
> 注入点在 foreach 循环后、$doc.review 赋值与完整性校验前，技术干净。
>
> **注入有效性依据**：`$origStats` 在 L478 行尾已固化为 JSON 字符串快照（`$doc.stats|ConvertTo-Json -Depth 8 -Compress`），注入修改 `$doc.stats.total` 后，L480 计算的 `$newStats` 序列化结果必然 ≠ `$origStats`（字符串比较，修改必然反映）→ 校验失败路径触发。
>
> **边界条件**：fixture result.json 的 `stats.total` 不得恰为 999，否则注入可能无效。

**验证项**:
```
REVIEW_WRITE_ERROR|review 修改了 stats/items     — 输出中存在
RUN_STATUS|failed|review 程序事实完整性校验失败   — 输出中存在
lock released                                      — Release-LockSafely 被调用
no COMMIT_OK
no RUN_STATUS|success|
```

**关键额外检查**（因 return 被移除）：
```
是否有二次 RUN_STATUS|failed|输出               — 检查 stdout 中 RUN_STATUS|failed| 出现次数
执行是否落入 L481 try 块                          — 检查 stdout 中是否出现 REVIEW_WRITE_OK| 或其他异常
tmp 是否被清理                                    — result.review.tmp 状态
```

> **判定规则**：如果 L480 路径输出 `RUN_STATUS|failed|` 后落入 L481 try 块并再次输出 `RUN_STATUS|failed|`（因 tmp 写入可能成功但后续校验会因 stats/items 不一致而失败），则违反 constraint #13"仅输出一次"。此情况判定为 **T38-stats-items FAIL + P1**。
>
> 如果 L480 路径输出 `RUN_STATUS|failed|` 后落入 L481 但后续因 `$doc.review` 已设置而正常完成 review 写入（输出 `REVIEW_WRITE_OK|`），则违反"不可恢复错误后不应继续执行"的语义。此情况同样判定为 **FAIL**。
>
> 如果 L480 路径行为正确（如落入 L481 后因某种原因安全终止），须在 test-report.md 中详细说明实际行为链。

**证据要求**（每个 T38 子测试均需）:
```
T38-*/before/
T38-*/after/
T38-*/stdout.txt
T38-*/stderr.txt
T38-*/test-report.md
T38-*/result-before.json
T38-*/result-after.json
T38-*/md-before.md            — 主 md before（确认未被修改）
T38-*/md-after.md             — 主 md after
T38-*/sha256-before.txt       — 含 main md + result.json + tmp 三者 SHA256
T38-*/sha256-after.txt        — 含 main md + result.json + tmp 三者 SHA256
T38-*/lock-before.txt
T38-*/lock-after.txt
```

涉及 ACL 的测试额外需: `acl-before.xml`（ACL 变更前快照）

涉及文件锁的测试额外需: `lock-holder-stdout.txt` / `lock-holder-stderr.txt`

**早期判定**: T38 任一子测试 FAIL → 立即标记 PRODUCTION_NOT_READY 倾向，但仍完成后续测试以保留完整证据（Prompt §5）。

**输出结果**:
- `.production-validation-v110-final/T38-A/` 目录及全部证据
- `.production-validation-v110-final/T38-B/` 目录及全部证据
- `.production-validation-v110-final/T38-C/` 目录及全部证据
- `.production-validation-v110-final/T38-heartbeat/` 目录及全部证据
- `.production-validation-v110-final/T38-result-read/` 目录及全部证据
- `.production-validation-v110-final/T38-stats-items/` 目录及全部证据
- `.production-validation-v110-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 逐个核验 6 个 T38 子测试的 stdout.txt 中是否出现预期的 `REVIEW_WRITE_ERROR|`/`RUN_STATUS|failed|` 且不出现 `RUN_STATUS|success|`
- [ ] 核验 SHA256 before/after 一致（result.json unchanged）
- [ ] 核验 lock-after 确认锁已释放（T38-heartbeat 除外，按条件化期望处理）
- [ ] 核验 sha256 文件覆盖 main md + result.json + tmp 三者
- [ ] T38-stats-items: 核验 stdout 中 `RUN_STATUS|failed|` 出现次数（约束 #13 要求"仅输出一次"）
- [ ] T38-stats-items: 核验是否落入 L481 try 块（检查后续输出）

**失败处理**: T38 任一子测试 FAIL → 立即标记 PRODUCTION_NOT_READY 倾向，但仍完成后续 Phase 以保留完整证据。如测试 harness 无法制造某一种异常（Prompt §6），标记 BLOCKED，不能推理 PASS。

---

### Phase 3: T22/T23 — md tmp 写入/原子替换失败回归（硬门槛）

**前置条件**: Phase 1 完成，lib/step5-full.ps1 提取完成

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- 提取的脚本: `lib/step5-full.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### T22 — md 临时文件写入失败（Prompt §7）

**目标**: SKILL Step 5 `Set-Content $tmp`（md.tmp 创建/写入）真实失败。

**构造方法**: 使 `$md.tmp`（即 `GitHub更新监测列表.md.tmp`）创建或写入失败。

方法选项：
- 通过 ACL deny 拒绝当前用户对 `.output` 目录的 CreateFiles 权限
- **注意 1**：Windows `ReadOnly` 属性**不阻止**文件创建，不可作为构造方法
- **注意 2**：`[System.IO.File]::Open()` 只能打开文件，目录不支持 FileShare 排他锁，不可作为构造方法
- **ACL 方案前置断言**：施加 ACL deny CreateFiles 前须确认 `GitHub更新监测列表.md.tmp` 不存在（存在则先删除并记录），否则 Set-Content 覆盖已存在文件将成功 → 测试假阴性

**ACL 恢复步骤**：
1. 构造前记录 `.output` 目录原始 ACL：`Get-Acl $outputDir | Export-Clixml T22/acl-before.xml`
2. 施加 deny 规则
3. 测试执行
4. 测试后还原 ACL：`Import-Clixml T22/acl-before.xml | Set-Acl $outputDir`
5. 验证还原成功：`Get-Acl $outputDir` 确认 deny 规则已移除

**验证项**:
```
主 md unchanged             — SHA256 before vs after 不变
tmp 不产生错误残留          — md.tmp 不残留
lock released               — run.lock 不存在或 PID 不匹配
RUN_STATUS|failed|          — 输出中存在
no COMMIT_OK                — 输出中不存在
no RUN_STATUS|success|      — 输出中不存在
```

**重点**: v1.10 须确认此路径（Step 5）的异常处理在 v1.9 基础上保持不变。

#### T23 — md 原子替换失败（Prompt §8）

**目标**: SKILL Step 5 `Move-Item $tmp -> $md` 真实失败。

**构造方法**: 先创建 `GitHub更新监测列表.md.tmp`，然后使 `Move-Item -Path $tmp -Destination $md -Force` 真实失败。

方法选项：
- 对目标 `GitHub更新监测列表.md` 设置外部文件锁：使用 `[System.IO.File]::Open()` 以 `FileShare::None` 锁住目标文件，使 Move-Item 无法替换
- 文件锁通过 `Start-Process -WindowStyle Hidden` 在后台进程中持有，测试完成后终止

**验证项**:
```
主 md unchanged             — SHA256 before vs after 不变
tmp cleaned                 — md.tmp 被清理
lock released               — run.lock 不存在或 PID 不匹配
COMMIT_OK absent            — 输出中不存在
RUN_STATUS|failed| present  — 输出中存在
RUN_STATUS|success| absent  — 输出中不存在
```

**特别注意**: 如果 v1.10 的具体错误策略明确允许 tmp 保留，必须严格按照 SKILL 实际 contract 判断，不能自行假设。

**证据要求**（T22/T23 均需）:
```
T2*/before/
T2*/after/
T2*/stdout.txt
T2*/stderr.txt
T2*/test-report.md
T2*/md-before.md
T2*/md-after.md
T2*/result-before.json
T2*/result-after.json
T2*/sha256-before.txt       — 含 main md + result.json + tmp 三者 SHA256
T2*/sha256-after.txt        — 含 main md + result.json + tmp 三者 SHA256
T2*/lock-before.txt
T2*/lock-after.txt
```

涉及 ACL 的测试额外需: `acl-before.xml`

涉及文件锁的测试额外需: `lock-holder-stdout.txt` / `lock-holder-stderr.txt`

**输出结果**:
- `.production-validation-v110-final/T22/` 目录及全部证据
- `.production-validation-v110-final/T23/` 目录及全部证据
- `.production-validation-v110-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 逐个核验 T22/T23 的 stdout.txt 中是否出现预期的 `RUN_STATUS|failed|` 且不出现 `RUN_STATUS|success|` / `COMMIT_OK|`
- [ ] 核验 SHA256 before/after 一致（主 md unchanged）
- [ ] 核验 lock-after 确认锁已释放
- [ ] 核验 sha256 文件覆盖 main md + result.json + tmp 三者

**失败处理**: T22/T23 任一 FAIL → 立即标记 PRODUCTION_NOT_READY 倾向，但仍完成后续测试以保留完整证据。

---

### Phase 4: T37 — 正常成功回归（硬门槛）

**前置条件**: Phase 1 完成，lib/step1-5.ps1 提取完成

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- 提取的脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向 T37 测试子目录

**处理逻辑**:

#### T37 — 正常提交 → RUN_STATUS|success|（Prompt §9）

在 PowerShell 7.x 运行完整流程（Step1→Step5 代码 + Step6 汇报模板）。

**Fixture**: 至少 2 个真实仓库（如 `microsoft/vscode` localVer=1.0.0 + `torvalds/linux` localVer=6.5.0），确保能触发 review 的仓库。

**执行**:
> **stdout 捕获策略**：根据 Phase 1 `lib/stdout-verification.txt` 的独立验证结果决定执行方式：
> - 如果验证确认 stdout 透传正常 → 使用 `run-full-pipeline.ps1` 单次执行，捕获 stdout
> - 如果验证确认 stdout 透传异常 → 逐 step 独立执行（`pwsh -File step1.ps1 *>&1 > T37/stdout-step1.txt` → ...），最终拼接为 `T37/stdout.txt`
> - sub-agent 须在 test-report.md 中记录实际采用的执行方式及依据

**验证项**:
```
BACKUP_OK|                  — 输出中存在
FETCH_COMPLETE|             — 输出中存在
SUMMARY|                    — 输出中存在
REVIEW_WRITE_OK|            — 输出中存在（仅当本轮触发 review 时）
COMMIT_OK|                  — 输出中存在
RUN_STATUS|success|         — 输出中存在
lock released               — run.lock 不存在
md updated                  — md-after 与 md-before 不同（版本号已刷新）
result.json valid           — JSON 结构完整、stats/items/review 字段存在
```

**硬门槛**: 如果出现 `COMMIT_OK|` + `RUN_STATUS|failed|` → FAIL + P1 + PRODUCTION_NOT_READY。这是必须 PASS 的生产核心测试（Prompt §9）。

**证据要求**:
```
T37/before/
T37/after/
T37/stdout.txt              — 完整 stdout（单次执行或拼接，取决于 Phase 1 验证结果）
T37/stdout-step1.txt ~ stdout-step5.txt   — 各 step 独立 stdout（仅当逐 step 方式时）
T37/stderr.txt
T37/test-report.md
T37/md-before.md
T37/md-after.md
T37/result-before.json
T37/result-after.json
T37/sha256-before.txt
T37/sha256-after.txt
T37/lock-before.txt
T37/lock-after.txt
```

**输出结果**:
- `.production-validation-v110-final/T37/` 目录及全部证据
- `.production-validation-v110-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 stdout.txt 中 `BACKUP_OK|` → `FETCH_COMPLETE|` → `SUMMARY|` → `COMMIT_OK|` → `RUN_STATUS|success|` 完整链
- [ ] 核验 lock-after 确认锁已释放
- [ ] `REVIEW_WRITE_OK|` 为条件性检查（仅当 fixture 触发 review 时验证）

**失败处理**: T37 FAIL → PRODUCTION_NOT_READY，但仍完成后续测试以保留完整证据。

---

### Phase 5: T39 — Commit 成功 + 锁释放失败（硬门槛）

**前置条件**: Phase 1 完成，lib/step5-t39-harness.ps1 提取完成

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- 提取的脚本: `lib/step5-t39-harness.ps1`（同进程 harness）
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向 T39 测试子目录

**处理逻辑**:

#### T39 — commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|（Prompt §10）

验证 v1.10 没有破坏上一版本已经正确的 invariant。

**构造方法**：

使用 `lib/step5-t39-harness.ps1` 在**同一进程**内执行以下步骤：
1. 正常执行 Step 1→4，确保 `result.json` 就绪
2. 执行 Step 5 代码至 Move-Item 成功 → `$commitSucceeded=$true` → 输出 `COMMIT_OK|`
3. 在同进程中修改锁文件 PID 为 999999（`Set-Content $lockPath -Value 'pid=999999;...'`）
4. 继续执行锁释放部分：锁内 PID (999999) ≠ 当前 PID → ownership 校验失败 → `$lockReleased=$false`
5. 最终判定：`$commitSucceeded=$true` AND `$lockReleased=$false` → `RUN_STATUS|failed|`

> **设计说明**：`pwsh -File` 模式下每脚本独立进程，`$commitSucceeded` 等局部变量无法跨进程传递。本计划改用同进程 harness，确保变量在 Step 5 的 commit 段和 lock-release 段之间正确传递。

**验证项**:
```
COMMIT_OK|                  — 输出中存在（提交本身成功）
RUNTIME_ERROR|              — 输出中存在（锁释放失败）
RUN_STATUS|failed|          — 输出中存在
no RUN_STATUS|success|      — 输出中不存在
```

**核心 invariant 验证**:
```
commitSucceeded = true
lockReleased = false
        ↓
RUN_STATUS|failed|
```

即：commit 成功但锁未释放时，绝不输出 `RUN_STATUS|success|`。

**证据要求**:
```
T39/before/
T39/after/
T39/stdout.txt
T39/stderr.txt
T39/test-report.md
T39/lock-before.txt           — 测试前锁状态
T39/lock-after-modify.txt     — PID 修改后、锁释放尝试前的锁状态
T39/lock-after.txt            — 最终锁状态（锁仍存在，未释放）
T39/result-before.json
T39/result-after.json
```

**输出结果**:
- `.production-validation-v110-final/T39/` 目录及全部证据
- `.production-validation-v110-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 stdout.txt 中 `COMMIT_OK|` 存在但 `RUN_STATUS|success|` 不存在
- [ ] 核验 `RUN_STATUS|failed|` 存在
- [ ] 核验 lock-after-modify.txt 中 PID=999999
- [ ] 核验 lock-after.txt 确认锁仍存在（未释放）

**失败处理**: T39 FAIL → PRODUCTION_NOT_READY，但仍完成后续测试以保留完整证据。

---

### Phase 6: T43 + T46 — 全管线 + 路径契约（关键）

**前置条件**: Phase 1 完成

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- 提取的脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`, `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### T43 — Full Extended Pipeline Regression（Prompt §11）

建立全新 fixture。至少 6 个场景（除 404 外 repo 必须真实存在）：

```
normal upgrade      — 真实仓库，localVer 低于最新 release
synced              — 真实仓库，localVer 等于最新 release
uninstalled         — 真实仓库，localVer=未安装
unsupported version — 真实仓库，版本格式不可比较
404                 — 不存在的仓库（如 test/nonexistent-repo-12345）
versionJump         — 真实仓库，版本跨越大（major 差 ≥2 或 minor 差 ≥10）
```

**执行**: PS7 完整 Step 1→5 代码 + Step 6 汇报模板。

> **stdout 捕获策略**：同 Phase 4，根据 Phase 1 `lib/stdout-verification.txt` 独立验证结果决定执行方式。

**验证项**:
```
BACKUP_OK|
FETCH_COMPLETE|
SUMMARY|
REVIEW_WRITE_OK|（有 review 时）
COMMIT_OK|
RUN_STATUS|success|
```

**数据一致性验证**:
```
result.json          — 结构完整、stats 与 items 一致
.output/...md        — 表格行与 result.json items 一致
backup               — backup 目录存在且含时间戳备份
fetch_run.log        — 日志行存在且统计数字一致
lock                 — 锁已释放
```

**证据要求**:
```
T43/before/
T43/after/
T43/stdout.txt
T43/stdout-step1.txt ~ stdout-step5.txt   — 各 step 独立 stdout（仅当逐 step 方式时）
T43/stderr.txt
T43/test-report.md
T43/md-before.md
T43/md-after.md
T43/result-before.json
T43/result-after.json
```

#### T46 — .output State Path Regression（Prompt §12）

**运行目录**: `.production-validation-v110-final/T46/`（通过 `GITHUB_VERSION_MONITOR_BASE` 指向此目录）

**验证项**:
```
.output/GitHub更新监测列表.md 是唯一生产状态文件
根目录不存在 GitHub更新监测列表.md
读取 .output/ 写回 .output/  — 由 T43 完整管线证据覆盖（T46 仅跑 Step 1+2，写回发生在 Step 5）
backup 基于 .output 状态文件  — 同上，由 T43 证据覆盖
```

**禁止**: 不得重新使用 `.\GitHub更新监测列表.md`（根目录）。

**检查方法**: 运行 Step 1 + Step 2 后，检查 T46 测试目录（非生产根目录）是否出现同名状态文件。如果测试目录根出现 → FAIL + P1。"写回 .output/" 与 "backup 基于 .output" 两个维度由 T43 完整管线（Step 1→5 全流程）证据覆盖，T46 不重复执行 Step 5。

**证据要求**:
```
T46/before/
T46/after/
T46/stdout.txt
T46/stderr.txt
T46/test-report.md
T46/md-before.md
T46/md-after.md
T46/directory-listing.txt
T46/root-md-check.txt
```

**输出结果**:
- `.production-validation-v110-final/T43/` 目录及全部证据
- `.production-validation-v110-final/T46/` 目录及全部证据
- `.production-validation-v110-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 T43 stdout.txt 中完整成功链
- [ ] 核验 T46 directory-listing.txt 中测试目录根无 `GitHub更新监测列表.md`

**失败处理**: T43/T46 FAIL → 记录并继续，不阻断后续 Phase（关键优先级）。

---

### Phase 7: T04 + T05-PS7 + T26 + T18 — 状态机 + Flag + 状态保留（中）

**前置条件**: Phase 1 完成

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- 提取的脚本: `lib/step2.ps1`, `lib/mock-invoke-restmethod.ps1`, `lib/step2-mock-harness.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### 7.1 T04 — rate_limited Regression（Prompt §13）

PowerShell 7：
```
403
X-RateLimit-Remaining=0
```

必须：
```
rate_limited
```

并且：
```
latest request = 1
review API = 0
HTML = 0
retry = 0
```

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / HTTP status / `X-RateLimit-Remaining` header / request count

#### 7.2 T05-PS7 — forbidden Regression（PS7）

PowerShell 7：
```
403
X-RateLimit-Remaining=50（remaining>0）
```

必须：
```
forbidden
```

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / HTTP status / `X-RateLimit-Remaining` header / request count

> **注**：T05-PS7 与 T18 的 forbidden 状态测试共享 mock 场景（403+remaining>0），但 T05-PS7 侧重状态机判定输出，T18 侧重状态保留（gitVer/gitDate/flag 不变）。两者证据独立采集。

#### 7.3 T26 — Strict Flag Regression（Prompt §15）

| 输入 | 期望 |
|---|---|
| `yes`（小写） | 有效 |
| `no`（小写） | 有效 |
| `YES` | `PARSE_ERROR|` |
| `Yes` | `PARSE_ERROR|` |
| `yEs` | `PARSE_ERROR|` |
| `NO` | `PARSE_ERROR|` |
| `No` | `PARSE_ERROR|` |
| `pending` | `PARSE_ERROR|` |
| `true` | `PARSE_ERROR|` |

**验证**: 非法输入时 main md unchanged + lock released。

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / `md-before.md` / `md-after.md` / `sha256-before.txt` / `sha256-after.txt`

#### 7.4 T18 — State Preservation Regression（Prompt §16）

至少验证以下状态（SKILL-v1.10 状态机非 ok 状态共 9 种）：

```
auth_error
forbidden
rate_limited
server_error
network_error
http_error
not_found
invalid_response
metadata_incomplete
```

一般失败状态：
```
gitVer unchanged
gitDate unchanged
flag unchanged
```

404：
```
gitVer=""
gitDate=""
flag=prevFlag
review=true
```

**T18 的 9 种非 ok 状态**：

```
1. not_found            — 404
2. rate_limited          — 429 或 403+remaining=0
3. server_error          — 5xx
4. network_error         — 超时/DNS/TLS（无 HTTP response）
5. invalid_response      — 200 但 tag_name 为空
6. metadata_incomplete   — 200 且 tag_name 有值但 published_at 缺失
7. auth_error            — 401
8. forbidden             — 403 且 remaining>0
9. http_error            — 其他明确 HTTP 状态码（如 302）
```

**每个测试证据**: `stdout.txt` / `stderr.txt` / `test-report.md`

T04 额外证据: `HTTP status` / `header metadata` / `request count`

T18 额外证据: 每种状态独立记录（9 种 error 状态 × before/after）

**输出结果**:
- 各测试子目录及全部证据
- `.production-validation-v110-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 T04-PS7 stdout 中 `rate_limited` 存在
- [ ] 核验 T05-PS7 stdout 中 `forbidden` 存在
- [ ] 核验 T26 的 9 项输入测试结果（2 合法 + 7 非法）
- [ ] 核验 T18 的 9 种状态保留测试结果

**失败处理**: 记录并继续，不阻断后续 Phase（中优先级）。

---

### Phase 8: PS5.1 兼容性回归（兼容）

**前置条件**: Phase 1 完成

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- 提取的脚本: `lib/mock-invoke-restmethod.ps1`, `lib/step2-mock-harness.ps1`
- PS5.1 路径: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### PS5.1 Header Compatibility Regression（Prompt §14）

如果系统存在 PowerShell 5.1：

重新验证：
```
403 + remaining=0
→ rate_limited

403 + remaining>0
→ forbidden
```

验证 `Get-ResponseHeaderValue`（SKILL L324-330）在 `System.Net.WebHeaderCollection` 上的行为。

**执行**: 使用 PS5.1 (`powershell.exe` 而非 `pwsh.exe`) 运行 mock harness。

**验证项**:
```
T04-PS5.1: 403 + remaining=0 → rate_limited
T05-PS5.1: 403 + remaining>0 → forbidden
```

PS5.1 FAIL：
```
记录 compatibility FAIL
但不自动阻塞 PS7 production gate
```

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / HTTP status / header metadata

**输出结果**:
- `.production-validation-v110-final/T04-PS5.1/` 目录及全部证据
- `.production-validation-v110-final/T05-PS5.1/` 目录及全部证据
- `.production-validation-v110-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 PS5.1 可用性（`powershell.exe` 存在）
- [ ] 核验 T04-PS5.1 和 T05-PS5.1 的 stdout 结果
- [ ] PS5.1 FAIL 不阻塞 PS7 production gate（仅记录 compatibility FAIL）

**失败处理**: PS5.1 FAIL → 记录 compatibility FAIL，不阻断后续 Phase。

---

### Phase 9: Lock 回归 + Process Kill（中）

**前置条件**: Phase 1 完成

**输入参数**:
- 测试目录: `.production-validation-v110-final/`
- 提取的脚本: `lib/step1.ps1`, `lib/step5-full.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### 9.1 Lock Regression（Prompt §17）

| 测试 | 验证内容 | 构造方法 | 期望 |
|---|---|---|---|
| lock-concurrency | 两进程争锁 | 两个 PS7 进程同时执行 Step 1 | one owner + one `LOCKED|` |
| lock-ownership | 外来 PID | 锁文件 PID 改为不匹配值 | `RUNTIME_ERROR|` + foreign lock retained |
| lock-stale-alive | 陈锁 + PID 活 | heartbeat 超 30 min + PID alive | `LOCKED|` |
| lock-stale-dead | 陈锁 + PID 死 | heartbeat 超 30 min + PID dead | takeover 成功，以 `BACKUP_OK|` 为判定标记 |

**lock-stale-alive 构造方法**: 创建锁文件，heartbeat 时间戳设为 31 分钟前，PID 设为当前 PowerShell 进程的 PID（alive）。

**lock-stale-dead 构造方法**: 创建锁文件，heartbeat 时间戳设为 31 分钟前，PID 设为不存在的进程 PID（如 999999）。

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / `lock-before.txt` / `lock-after.txt`

#### 9.2 Process Kill Regression（Prompt §18）

至少真实执行一次 `Stop-Process`。

选择 Step 2/3/4/5 之一。

**构造方法**: 启动完整管线运行，在指定 Step 执行中途 `Stop-Process` 终止。

重新运行后检查：
```
lock         — 不得出现锁滞留（或按陈锁机制接管）
backup       — 不得出现损坏的 backup
result.json  — 不得出现损坏的 result.json
main md      — 不得出现错误提交
```

不得出现错误提交。

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / `lock-before.txt` / `lock-after.txt` / `md-before.md` / `md-after.md` / `result-before.json` / `result-after.json`

**输出结果**:
- 各测试子目录及全部证据
- `.production-validation-v110-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 lock 4 项测试结果
- [ ] 核验 process-kill 测试结果（lock/backup/result.json/main md 均无损坏）

**失败处理**: 记录并继续，不阻断后续 Phase（中优先级）。

---

### Phase 10: Runtime Error Contract 静态审计 + Final Invariant Verification（关键）

**前置条件**: Phase 1-9 全部完成，全部证据可用

**输入参数**:
- SKILL-v1.10.md 全文
- 全部前序 Phase 证据

**处理逻辑**:

#### 10.1 Runtime Error Contract Static Audit（Prompt §19）

扫描 v1.10 中：

```
Set-Content
Move-Item
Add-Content
Get-Content
ConvertFrom-Json
ConvertTo-Json
File.Open
```

针对生产状态文件相关的关键操作，确认：

```
异常可控
tmp cleanup
lock handling
final status
```

特别搜索所有：

```
return
```

逐个确认：

> 是否有可能在整轮失败后提前 return，而没有输出 `RUN_STATUS|failed|`。

这个检查非常重要。本轮 P1 的本质就是"提前 return 导致最终状态缺失"，不能只检查已知 T38 行。

**额外检查**：搜索所有 `RUN_STATUS|failed|` 输出点，确认是否有可能**重复输出**（constraint #13 要求"仅输出一次"）。特别关注 L480 stats/items 完整性失败路径（return 被移除，执行可能落入后续 try 块导致二次输出）。

**输出**: `runtime-error-contract/early-return-final-status-audit.md`

#### 10.2 Final Invariant Verification（Prompt §20）

必须真实验证以下：

**I1**:
```
atomic md replacement success
→ commitSucceeded=true
```

**I2**:
```
commitSucceeded=true
+
lockReleased=true
→ RUN_STATUS|success|
```

**I3**:
```
commitSucceeded=true
+
lockReleased=false
→ RUN_STATUS|failed|
```

**I4**:
```
review write failure
→ no md commit
```

**I5**:
```
review write failure
→ RUN_STATUS|failed|
```

**I6**:
```
md replacement failure
→ main md unchanged
```

**I7**:
```
failure
→ safe cleanup
+
lock handling
+
terminal failed status
```

> I1-I7 的验证依据来自前序 Phase（2-5）的实际执行证据，不是重新运行。此 Phase 做的是证据汇总与一致性核对。

**输出结果**:
- `.production-validation-v110-final/runtime-error-contract/early-return-final-status-audit.md`
- `.production-validation-v110-final/invariant-verification/invariant-verification.md`
- `.production-validation-v110-final/phase-progress.json`

**证据要求**:
- `.production-validation-v110-final/phase10-stdout.txt`
- `.production-validation-v110-final/phase10-stderr.txt`
- `.production-validation-v110-final/phase10-report.md`

**主 agent 审查点**:
- [ ] 核验 early-return-final-status-audit.md 覆盖 Step 1-5 所有 `return` 语句
- [ ] 核验每个 `return` 是否有对应的 `RUN_STATUS|failed|`（或位于正常退出路径）
- [ ] 核验 L480 return 移除的落入行为是否被分析
- [ ] 核验 invariant-verification.md 中 I1-I7 逐项有证据指向

**失败处理**: 静态审计发现未覆盖的 return 路径 → 记录为 P1 发现；invariant 验证发现矛盾 → 记录并继续。

---

### Phase 11: Self-Review（质量控制）

**前置条件**: Phase 0-10 全部完成，全部证据可用

**输入参数**:
- 全部 Phase 0-10 证据
- SKILL-v1.10.md 原文
- Phase 0 SHA256 基线

**处理逻辑**:

独立 self-review（Prompt §22），至少检查 12 项：

```
1. 被测对象是否为真实 v1.10
2. 是否修改过 v1.10
3. 是否误用了旧 PASS
4. 是否存在旧 fixture
5. T38 是否真实命中失败分支
6. 每个 FAIL 是否有证据
7. 是否把 BLOCKED 写成 PASS
8. 是否把 FAIL 写成 BLOCKED
9. 报告数字是否一致
10. evidence 与结论是否一致
11. v1.9→v1.10 diff 是否真实
12. early return final status audit 是否完成
```

**检查方法**：

1. **被测对象真实性**：重算 `SKILL-v1.10.md` SHA256，与 Phase 0 的 `v110.sha256` 比对
2. **未修改被测对象**：`git status SKILL-v1.10.md` 确认无修改
3. **旧证据污染检查**：核对所有证据目录路径均在 `.production-validation-v110-final/` 下，不在旧目录（v17/v18/v19）
4. **旧 fixture 检查**：核对 fixture 内容为本轮新建
5. **T38 真实命中**：核对 T38-A/B/C/heartbeat/result-read/stats-items 的 stdout 中确实出现 `REVIEW_WRITE_ERROR|` / `RUNTIME_ERROR|`
6. **FAIL 证据**：每个标注 FAIL 的测试项有对应的 stdout/stderr/test-report 证据
7. **BLOCKED≠PASS**：逐项核对实际输出 vs 结论
8. **FAIL≠BLOCKED**：同上
9. **数字守恒**：`EXECUTED = PASS + FAIL + BLOCKED`
10. **证据与结论一致**：实际输出 vs 报告结论
11. **diff 真实性**：重算 v1.9/v1.10 SHA256，与 Phase 0 基线比对；核对 diff 内容
12. **early return audit 完整性**：核对 Phase 10 输出的 audit 文件覆盖所有 return 语句

**额外检查（基于模板 §6.3）**：

```
13. 操作对象是否被修改 — 重算指纹与基线比对
14. 输入/fixture 是否正确 — 逐项核实存在性与内容
15. 派生物是否被修改导致假结果 — 按 manifest 重算指纹；注入类派生物做受限 diff
16. 基线对象完整性 — 重算指纹与开工基线比对
```

> **Prompt §22 文件名说明**：Prompt 指定 self-review 文件名为 `.selfreview/selfreview-v19.md`。此名称引用 v19，疑似从 v1.9 prompt 复制时的遗留。按上游字面格式要求（§7.3 口径规则），本计划沿用此文件名，但在最终报告中注明此偏差。

**输出结果**:
- `.production-validation-v110-final/.selfreview/selfreview-v19.md`
- `.production-validation-v110-final/phase-progress.json`

**证据要求**:
- `.production-validation-v110-final/phase11-stdout.txt`
- `.production-validation-v110-final/phase11-stderr.txt`
- `.production-validation-v110-final/phase11-report.md`

**主 agent 审查点**:
- [ ] 核验 self-review 12+4 项检查全部完成
- [ ] 核验 SKILL-v1.10.md SHA256 与 Phase 0 基线一致（未被修改）
- [ ] 核验 `EXECUTED = PASS + FAIL + BLOCKED` 守恒式成立
- [ ] 核验无 BLOCKED 被改写为 PASS、无 FAIL 被改写为 BLOCKED

**失败处理**: self-review 发现问题 → 记录为发现项，不自动修复；严重问题（如被测对象被修改）→ 立即中止并标 BLOCKED。

---

### Phase 12: Final Report + Commit（收尾）

**前置条件**: Phase 0-11 全部完成

**输入参数**:
- 全部 Phase 0-11 证据
- self-review 报告

**处理逻辑**:

#### 12.1 生成最终报告（Prompt §23）

生成 `production-validation-report-v110-final.md`，必须包含以下章节（Prompt §23 固定清单）：

```
A. Environment
B. Version / SHA256
C. v1.9 → v1.10 Diff Integrity
D. Targeted Test Summary
E. T38 Detailed Validation
F. Critical Findings
G. Invariant Verification
H. State Path Verification
I. PS7 Production Assessment
J. PS5.1 Compatibility Assessment
K. Runtime Error Contract Audit
L. Self-Review Findings
M. Evidence Index
N. Production Gate
O. Execution Summary
P. Remaining Limitations
```

#### 12.2 最终计数（Prompt §24）

根据实际执行项目统计：

```
EXECUTED =
PASS =
FAIL =
BLOCKED =
```

必须：`PASS + FAIL + BLOCKED = EXECUTED`

#### 12.3 Production Gate（Prompt §25）

**PRODUCTION_READY** 必须同时：

```
P0 = 0
P1 = 0
FAIL = 0
BLOCKED = 0
```

并且必须：

```
T22 = PASS
T23 = PASS
T37 = PASS
T38 = PASS（含 T38-A/B/C/heartbeat/result-read/stats-items 全部 PASS）
T39 = PASS
T43 = PASS
T46 = PASS

T04-PS7 = PASS
Diff Integrity = PASS
Runtime Error Audit = PASS
Self-Review = PASS
```

**PRODUCTION_NOT_READY**：任意 `P0 > 0 / P1 > 0 / FAIL > 0`，特别是：

```
T38 FAIL
RUN_STATUS terminal state missing
主 md 被错误修改
lock ownership 错误
数据损坏
```

**PRODUCTION_BLOCKED**：仅当 `P0 = 0 / P1 = 0 / FAIL = 0 / BLOCKED > 0`。

#### 12.4 最终执行摘要（Prompt §26）

报告必须明确：

```
PS7 available:
PS7 executed:
PS5.1 available:
PS5.1 executed:

T22:
T23:
T37:
T38:
T39:
T43:
T46:

T04-PS7:
T04-PS5.1:
T05-PS7:
T05-PS5.1:

T26:
T18:
lock regression:
process kill:
runtime error audit:
diff integrity:
self-review:

FINAL_VERDICT:
```

> 模板中的每一项必须映射到计划中实际安排的工作；若某项本轮未安排（如上游模板遗留），在报告 P 节显式声明"本轮未安排，依据为 {{历史轮/不适用}}"，不得留空或编造。

#### 12.5 收尾动作

1. 汇总全部证据，生成最终报告
2. 基线对象完整性复核（SHA256 比对：SKILL-v1.10.md 开工 vs 收尾）
3. 入库：commit 文件范围显式列出——
   - `SKILL-v1.10.md`（如 Phase 0 新增 git add）
   - `.production-validation-v110-final/` 全部证据目录（含 `task-tracker.md`）
   - `.exec-plan/exec-plan-v1.10-c.md`（本执行计划）
   - `production-validation-report-v110-final.md`
   - `.selfreview/selfreview-v19.md`
   commit message 必含：终态判定、分类计数、P0/P1/P2 计数、新增发现、新增证据路径
4. 环境还原确认（ACL 还原、文件锁进程终止、临时目录清理）

**输出结果**:
- `.production-validation-v110-final/production-validation-report-v110-final.md`
- `.production-validation-v110-final/phase-progress.json`
- git commit（文件范围显式列出）

**主 agent 审查点**:
- [ ] 核验最终报告包含 A-P 全部 16 个章节
- [ ] 核验 `PASS + FAIL + BLOCKED = EXECUTED` 守恒式成立
- [ ] 核验 Production Gate 判定与测试结果一致
- [ ] 核验最终执行摘要模板每一项映射到实际工作
- [ ] 核验 SKILL-v1.10.md SHA256 收尾与开工一致
- [ ] 核验 commit 文件范围与计划声明一致

**失败处理**: 报告生成失败 → 检查证据完整性后重试；commit 失败 → 检查 git 状态后重试。

---

## 3. 禁止事项

```text
1. 禁止修改 SKILL-v1.10.md（被测对象）
2. 禁止触碰 .output/GitHub更新监测列表.md（生产状态文件）— 用 GITHUB_VERSION_MONITOR_BASE 隔离
3. 禁止复用 .production-validation/ / .production-validation-v17-final/ / .production-validation-v18-final/ 中的旧产物作为本轮 PASS 证据
4. 禁止修改上游事实源文件（.GPT/Production Validation Prompt — SKILL-v1.10 Targeted Validation.md）
5. 禁止输出 GITHUB_TOKEN / Authorization / Cookie / 完整 secrets
6. 禁止为使任务通过而修改被测 SKILL
7. 禁止多 sub-agent 并行执行
8. 禁止 Verdict/结论由预期结果而非实际证据决定
9. 禁止将 BLOCKED 改写为 PASS
10. 禁止将 FAIL 改写为 BLOCKED
11. 禁止使用 mock URL / forced success / debug bypass / test-only branch / hardcoded token / hardcoded test repository / skip schema / skip lock / skip commit
12. 禁止用"能力关键词仍存在"替代行为判断
```

---

## 4. 证据规则

| 情形 | 至少留存 |
|---|---|
| 每项执行 | stdout.txt、stderr.txt、test-report.md（或 work-report.md） |
| 涉及文件变更 | before/after 副本 + 指纹（sha256-before/after.txt，写明覆盖对象） |
| 涉及锁/状态/环境 | before/after 快照（额外中间态单独存档） |
| 涉及外部调用 | 实际响应、关键 header/字段、请求计数 |
| 涉及 ACL 变更 | 变更前快照 + 还原后验证记录 |

**禁止保存**：`GITHUB_TOKEN` / `Authorization` / `Cookie` / 完整 secrets。

---

## 5. 可追溯性机制

### 5.1 指纹与清单

1. **开工基线**：Phase 0 采集 `SKILL-v1.10.md` / `SKILL-v1.9.md` / `.output/GitHub更新监测列表.md` 的 SHA256 指纹。
2. **每个采集物必须有消费者**：Phase 0 的 3 个 SHA256 在 Phase 11 self-review 第 1/2/11 项中被复核比对；Phase 1 的 `extraction-manifest.json` 在 Phase 11 第 15 项中被复核。
3. **派生物必须有 manifest**：`lib/*.ps1` 提取脚本在 Phase 1 生成 `extraction-manifest.json`（源文件指纹 + 源行号范围 + 派生物指纹）；Phase 11 复核时按 manifest 重算。注入类派生物（`step5-t39-harness.ps1`、T38-B/stats-items harness）做**受限 diff**：与源原文对照，仅允许计划声明的注入差异。
4. **stdout 透传独立验证**：Phase 1 独立验证 `run-full-pipeline.ps1` 的 stdout 透传行为（`lib/stdout-verification.txt`），不依赖旧报告声明。

### 5.2 口径与引用规则

1. 所有数量词（"28 项""9 种""6 场景"）必须能指认事实源出处；枚举类判断必须读取完整原文表格后列全项。
2. 旧报告/旧轮次结论只作信息参考；作设计依据前必须本轮独立验证并留存验证证据。
3. 引用其他章节/文档的规则，修改时全文搜索所有引用点同步更新。
4. 计划与上游文档的格式要求冲突时（如 self-review 文件名 `selfreview-v19.md` 引用 v19），保持上游字面格式、以附注形式补充信息。

---

## 6. 判定与收尾

### 6.1 审查门流程

```text
sub-agent 完成 → 产出 phase-progress.json + 证据文件
→ 主 agent 审查（status=completed？证据逐项核对审查点？）
→ PASS → 启动下一 Phase
→ FAIL → 不启动下一 Phase；按该 Phase 失败处理规则：修复重试 / 回退 / 标 BLOCKED
```

### 6.2 审查规则

1. 主 agent 审查是**独立复核**，不是听取汇报：审查点要求核对的证据（stdout、指纹、清单），主 agent 亲自读取核对，不采信 sub-agent 的结论转述。
2. 审查点全部可判定；任一不满足 → 该 Phase 未通过。
3. 硬门槛 Phase 未通过 → 触发最终判定规则（但仍完成后续 Phase 以保留完整证据，除非失败处理声明立即中止）。
4. **数字一致性**：所有计数类结论必须满足守恒式（`EXECUTED = PASS + FAIL + BLOCKED`）；计划中同一数字只允许一个权威出处。

### 6.3 最终判定逻辑

**PRODUCTION_READY** 必须同时满足：

```
P0 = 0
P1 = 0
FAIL = 0
BLOCKED = 0

T22 = PASS
T23 = PASS
T37 = PASS
T38 = PASS（含全部 6 个子测试）
T39 = PASS
T43 = PASS
T46 = PASS
T04-PS7 = PASS
Diff Integrity = PASS
Runtime Error Audit = PASS
Self-Review = PASS
```

**PRODUCTION_NOT_READY**：任意 `P0 > 0 / P1 > 0 / FAIL > 0`，尤其 T38 任一子测试 FAIL / RUN_STATUS terminal state missing / 主 md 被错误修改 / lock ownership 错误 / 数据损坏。

**PRODUCTION_BLOCKED**：仅当 `P0 = 0 / P1 = 0 / FAIL = 0 / BLOCKED > 0`。

**判定规则**：
1. 上游文档存在规则冲突时（PS5.1 失败不阻塞 vs 任何 FAIL>0 即失败），定义**计数维度**：production-critical（PS7）vs compatibility（PS5.1）。PS5.1 FAIL 仅记录 compatibility FAIL，不阻塞 PS7 production gate。
2. FAIL 不得改写为 BLOCKED；BLOCKED 不得改写为 PASS；旧证据不得冒充新证据。

### 6.4 最终执行摘要模板

```text
PS7 available:
PS7 executed:
PS5.1 available:
PS5.1 executed:

T22:
T23:
T37:
T38:
T39:
T43:
T46:

T04-PS7:
T04-PS5.1:
T05-PS7:
T05-PS5.1:

T26:
T18:
lock regression:
process kill:
runtime error audit:
diff integrity:
self-review:

FINAL_VERDICT:
```

---

## 7. 最终原则（Prompt §27）

```text
Git repository = 唯一事实源

SKILL-v1.10.md = 唯一被测对象

PowerShell 7.x = 生产主运行环境

PowerShell 5.1 = 兼容性回归环境

旧版本 PASS ≠ 当前版本 PASS

代码存在 ≠ 行为正确

关键失败路径必须真实注入

BLOCKED ≠ PASS

FAIL ≠ BLOCKED

不得修改被测 SKILL 来消除测试失败

证据优先于结论
```

---

## 8. 质量控制：自我审查

本计划制定完成后，进行以下全面自我审查：

### A1 事实源与独立性
- [x] 唯一事实源已指定：`.GPT/Production Validation Prompt — SKILL-v1.10 Targeted Validation.md`
- [x] 每个设计决策能指认事实源出处（Prompt 章节号 + SKILL 行号）
- [x] 旧轮次结论仅作信息参考；引用处有独立性声明（§0.6）
- [x] 枚举/数量词全部来自完整原文阅读（28 项能力 / 10 项禁止 / 9 种状态 / 6 场景 / 7 个 invariant）

### A2 模块化与串行
- [x] 模块总览表完整（13 个 Phase）；每模块输入封闭、输出清单化
- [x] 模块间仅通过产物文件传递状态
- [x] 单模块工作量在单次 sub-agent 会话预算内
- [x] 硬门槛模块显式标注（Phase 2/3/4/5）；第一（Phase 0）/倒数第二（Phase 11）/最后（Phase 12）模块职能正确
- [x] 禁止并行 + 每 Phase 单 sub-agent 已声明（§0.3）

### A3 可接续
- [x] phase-progress.json 结构与恢复原则已定义（§0.4）
- [x] 中断类型 × 检测 × 恢复策略表完整（4 类）
- [x] 恢复不依赖会话记忆

### A4 分阶段验收
- [x] 每个 Phase 有审查点，全部可判定（存在/相等/包含/一致）
- [x] 条件化期望已标注（T37 `REVIEW_WRITE_OK|`、T38-heartbeat lock 状态）
- [x] 审查是独立复核（主 agent 亲读证据）
- [x] 独立复核模块检查集完整（Phase 11 含 12+4=16 项，含指纹复核、受限 diff、守恒核算）

### A5 可追溯
- [x] 开工基线指纹已安排（Phase 0 的 3 个 SHA256）；每个采集物有消费者（Phase 11）
- [x] 派生物有 manifest（Phase 1 extraction-manifest.json）；注入类派生物有受限 diff 规则（Phase 11 第 15 项）
- [x] 证据清单覆盖：输出/变更/外部调用/环境变更（§4）
- [x] 数字只有一个权威出处；守恒式已定义（`EXECUTED = PASS + FAIL + BLOCKED`）

### A6 技术可行性
- [x] 每个构造方法选项已评估平台可行性；证伪项显式排除（Windows ReadOnly 不阻止创建、File.Open 不能打开目录）
- [x] 环境变更类构造（ACL）带备份/还原步骤（T22/T38-A ACL 恢复 5 步）
- [x] 进程模型声明完整（§0.7）；同进程注入场景有 harness 设计（T39、T38-B、T38-stats-items）
- [x] 替换体（mock）有逐场景 contract（成员+取值+类型+消费方行号）+ 对齐自检

### A7 隔离与安全
- [x] 生产对象隔离机制明确（GITHUB_VERSION_MONITOR_BASE）且已写入禁止事项
- [x] 替换方案优先无系统级变更（函数覆盖 > ACL > 文件锁）；有变更则有还原验证
- [x] secret 输出禁止已列入（§3 第 5 条）

### A8 判定与收尾
- [x] 上游规则冲突已消解（PS5.1 compatibility vs PS7 production-critical 双维度）
- [x] 结论模板与上游格式对齐（§6.4 与 Prompt §26 一致）；补充信息用后置附注
- [x] 执行摘要模板每一项映射到实际安排的工作
- [x] commit 文件范围显式列出（§12.5）；commit message 要素完整
- [x] 修订日志格式就绪（§9）

---

## 9. 修订日志

### exec-plan-v1.10-c（2026-09-09，二轮审计修订版）

**审计来源**: `.exec-plan/exec-plan-v1.10-b-codebuddy-review.md`（CodeBuddy 二轮独立审计）

**审计结论**: CONDITIONAL_PASS_WITH_MANDATORY_FIXES（1 P1 + 1 P2 + 7 P3）

| 审计编号 | 严重性 | 发现 | 采纳/驳回 | 修订内容 | 理由 |
|---|---|---|---|---|---|
| P1-B1 | P1 | T38-B 精确注入点行号残留偏差 -1：L488=return（catch 内）非"块结束}"，L489=}`（块结束），L490=第二个 try 开始。按字面注入落入 catch 块，T38-B 无法触发目标失败路径 | 采纳 | 注入点 L488/L489→L489/L490；目标行号 L489-490→L490-491；harness 描述更新 | Grep 确认 L488=`return`、L489=`}`、L490=`try { $check=Get-Content $tmpPath...`。前轮 b 版修订时沿用了 a 审计报告中源自 read_file 偏移的行号 |
| P2-B1 | P2 | T38-C Move-Item 行号 L499→实际 L500（L499=`try {`） | 采纳 | L499→L500 | Grep 确认 L500=`Move-Item $tmpPath $resultPath -Force` |
| P3-B1 | P3 | §0.2 表 Changelog 行号 L765→实际 L766（标题），条目在 L768 | 采纳 | L765→L766，补充 L768 标注 | Grep 确认 L766=`## 15. Changelog`，L768=v1.10 条目 |
| P3-B2 | P3 | T38-stats-items 注入点描述"L480（if 校验）"不精确（实为混合行）；注入有效性本身成立 | 采纳 | 描述改为"L480（$doc.review 赋值 + $newStats/$newItems 计算 + if 校验混合行）"；补充注入有效性依据（$origStats 在 L478 固化为 JSON 字符串快照）与边界条件（fixture stats.total 不得为 999） | Grep 确认 L480 为混合行；L478 含 `$origStats=$doc.stats\|ConvertTo-Json -Depth 8 -Compress` |
| P3-B3 | P3 | T46"写回 .output"验证项与 Step1+2 执行方式不匹配 | 采纳 | 验证项处显式声明"由 T43 完整管线证据覆盖"；检查方法补注"写回维度由 T43 覆盖" | T46 仅跑 Step 1+2，写回发生在 Step 5；T43 完整管线可补足 |
| P3-B4 | P3 | synced/versionJump 场景 localVer 确定方式未定义 | 采纳 | Phase 1 Step 7 create-fixture.ps1 补充 localVer 策略（synced/versionJump 动态查询 releases/latest；404 用不存在 repo） | 固定值随上游发版失效导致场景漂移 |
| P3-B5 | P3 | Phase 8 复用 mock 库未声明 PS5.1 语法兼容要求 | 采纳 | Phase 1 Step 7 新增 PS5.1 语法兼容要求（禁用 PS7-only 运算符）；对齐自检增加语法兼容检查 | mock 库在 PS7 环境创建但被 PS5.1 复用 |
| P3-B6 | P3 | git diff --no-index 退出码 1 未处理 | 采纳 | Step 1 命令追加 `; exit 0`；补注"退出码 1 = 有差异，属预期" | `-File` 模式下非零退出码可能被误判为 Phase 1 失败 |
| P3-B7 | P3 | ACL deny CreateFiles 方案未声明"目标 tmp 必须不存在"前置断言 | 采纳 | T38-A 和 T22 各增加 ACL 方案前置断言 | ACL 仅阻止新文件创建，不阻止覆盖；残留 tmp 会导致假阴性 |

**驳回项**: 无（全部 9 项采纳）

**未采纳/冲突项**: 无

---

### exec-plan-v1.10-b（2026-09-09，审计修订版）

**审计来源**: `.exec-plan/exec-plan-v1.10-a-codebuddy-review.md`（CodeBuddy 独立审计）

**审计结论**: CONDITIONAL_PASS_WITH_MANDATORY_FIXES（1 P1 + 7 P2 + 4 P3）

| 审计编号 | 严重性 | 发现 | 采纳/驳回 | 修订内容 | 理由 |
|---|---|---|---|---|---|
| P1-1 | P1 | T39 注入点 L632/L633 描述与实际不符 | 采纳 | L632→L636, L633→L637，修正描述为"if/else 块整体结束"和"# 释放锁前确认 ownership" | Grep 确认 L632=`    }`(catch end), L633=`} else {`, L636=`}`(if/else end), L637=ownership comment |
| P2-1 | P2 | §0.2 diff 表 6 项行号全部 -1（引用 v1.9 行号标注为 v1.10） | 采纳 | L476→L477, L477→L478, L479→L480, L486→L487, L495→L496, L505→L506 | v1.10 新增 result.json try/catch 导致后续行整体 +1；Phase 1 表前 3 项同步修正 |
| P2-2 | P2 | T38-B 注入点 L480 偏差 -1，范围过宽 | 采纳 | L480→L481，注入点精确到 L488/L489 之间 | Set-Content 在 L481；第一个 try/catch 在 L488 结束，第二个 try 在 L489 开始 |
| P2-3 | P2 | T38-stats-items 注入点 L478/L479 偏差 -1 | 采纳 | L478→L479, L479→L480 | foreach 在 L479，if 校验在 L480 |
| P2-4 | P2 | Phase 1 输出清单未列出 T38-B/T38-stats-items harness | 采纳 | 新增 `lib/step4-t38b-harness.ps1` 和 `lib/step4-t38-stats-items-harness.ps1` 到输出清单；审查点 harness 计数 2→4 | Phase 2 T38-B/T38-stats-items 需要同进程 harness，但原计划未明确创建位置 |
| P2-5 | P2 | T38-A "tmp cleaned" 与文件锁方案矛盾 | 采纳 | 拆分验证项：ACL 方案="tmp 未创建"；文件锁方案="catch 执行了 Remove-Item，外部进程终止后确认删除" | 文件锁持有时 `Remove-Item -ErrorAction SilentlyContinue` 静默失败，tmp 必然残留 |
| P2-6 | P2 | T39 $commitSucceeded/$lockReleased/前置变量行号 -4 | 采纳 | L617/L623→L621/L627, L634/L640→L638/L644, L535-543→L539-547 | Grep 确认实际行号 |
| P2-7 | P2 | mock contract 行号系统性 -3 | 采纳 | L339→L342, L344-346→L347-349, L347-348→L350-351, L359→L362, L358→L361, L360→L363, L361→L364, L362→L365, L363→L366, L364→L367, L352→L355, L358-363→L361-366, L338-364→L341-367 | Grep 逐条确认 |
| P3-1 | P3 | GITHUB_VERSION_MONITOR_BASE 行号不统一偏差 | 采纳 | L156→L163, L238→L241, L429→L432, L473→L474, L521→L522 | Grep 确认每个 step 中该变量的实际行号 |
| P3-2 | P3 | API URL 行号偏差 | 采纳 | L338→L341, L478→L479 | Grep 确认 |
| P3-3 | P3 | Phase 0 目录树含 Prompt 未定义的测试目录 | 采纳 | T02/T08/T14/T15/T16/T17/T19 标注"预留，Prompt 未定义" | 违反 Clean-Room 最小化原则；保留目录但加标注以避免误导 sub-agent |
| P3-4 | P3 | T05-PS7 在执行摘要模板出现但计划未安排 | 采纳 | Phase 7 新增 7.2 T05-PS7（403+remaining>0→forbidden，PS7）；审查点新增 T05-PS7 核验项；T26 编号 7.2→7.3，T18 编号 7.3→7.4 | 最终报告 T05-PS7 需有值可填；与 T18 forbidden 共享 mock 场景但验证维度不同 |

**驳回项**: 无（全部 12 项采纳）

**未采纳/冲突项**: 无

---

### exec-plan-v1.10-a（2026-09-09，初版制定）

**审计来源**: 无（初版）

| 审计项 | 严重性 | 采纳/驳回 | 修订内容 | 理由 |
|---|---|---|---|---|
| — | — | — | 初版制定 | 基于 Prompt §1-§27 + SKILL-v1.10.md 直接阅读 + v1.9→v1.10 diff 分析 |

**驳回项**: 无

---

## 附录 A：上游文档逐节对照表

| Prompt 章节 | 对应 Phase | 覆盖说明 |
|---|---|---|
| §0 生产环境定义 | Phase 0 + 全局 | PS7 主环境 / PS5.1 兼容 / 状态文件路径 / 运行时目录 |
| §1 Clean-Room | Phase 0 | `.production-validation-v110-final/` 新目录 |
| §2 被测文件 | Phase 0 | 从 Git repository 获取 3 个文件 |
| §3 SHA256 | Phase 0 | v19.sha256 / v110.sha256 / state.sha256 |
| §4 Diff Integrity | Phase 1 | v19-v110.diff + 28 项能力核验 + 10 项禁止项 + 6 路径核验 |
| §5 T38 核心 P1 | Phase 2 | T38-A/B/C + heartbeat + result-read + stats-items |
| §6 T38 多异常分支 | Phase 2 | T38-A/B/C 三个子测试 |
| §7 T22 md tmp 写入失败 | Phase 3 | T22 |
| §8 T23 md 原子替换失败 | Phase 3 | T23 |
| §9 T37 正常成功路径 | Phase 4 | T37 |
| §10 T39 Commit + Lock release 失败 | Phase 5 | T39 |
| §11 T43 全管线回归 | Phase 6 | T43（6 场景） |
| §12 T46 .output 路径回归 | Phase 6 | T46 |
| §13 T04 rate_limited 回归 | Phase 7 | T04-PS7 / T05-PS7 |
| §14 PS5.1 Header 兼容性回归 | Phase 8 | T04-PS5.1 / T05-PS5.1 |
| §15 T26 Strict Flag 回归 | Phase 7 | T26（9 项输入） |
| §16 T18 状态保留回归 | Phase 7 | T18（9 种状态） |
| §17 Lock 回归 | Phase 9 | 4 项 lock 测试 |
| §18 Process Kill 回归 | Phase 9 | Stop-Process + 重运行检查 |
| §19 Runtime Error Contract 静态审计 | Phase 10 | early-return-final-status-audit.md |
| §20 Final Invariant Verification | Phase 10 | I1-I7 |
| §21 Evidence Rules | §4 全局 | 证据规则表 |
| §22 Self-Review | Phase 11 | selfreview-v19.md（12+4 项） |
| §23 Final Report | Phase 12 | production-validation-report-v110-final.md（A-P 16 章） |
| §24 Final Counting | Phase 12 | EXECUTED/PASS/FAIL/BLOCKED |
| §25 Production Gate | Phase 12 | PRODUCTION_READY / NOT_READY / BLOCKED |
| §26 最终执行摘要 | Phase 12 | 摘要模板 |
| §27 最终原则 | §7 | 12 条原则 |

---

## 附录 B：本计划关键设计决策

| 编号 | 决策 | 理由 |
|---|---|---|
| D1 | 新增 T38-heartbeat / T38-result-read / T38-stats-items 子测试 | Prompt §5 要求"不要只测试 Set-Content"；Prompt §19 要求搜索所有 return；L477 heartbeat 和 L478 result.json-read 是 v1.10 新增路径，必须独立验证 |
| D2 | L480 stats/items 路径 return 移除发现 | v1.9→v1.10 diff 显示 L480 的 `return` 被移除，执行落入 L481 try 块。此不一致性是本轮关键发现，T38-stats-items 子测试专门验证此行为 |
| D3 | 同进程 harness 用于 T39 / T38-B / T38-stats-items | `-File` 模式下跨进程无法传递局部变量；dot-source 无法实现注入点暂停。harness 内联复制 + 精确注入点是唯一可行方案 |
| D4 | self-review 文件名沿用 `selfreview-v19.md` | Prompt §22 字面指定此名称（疑似 v1.9 prompt 复制遗留）。按 §7.3 口径规则，保持上游字面格式，以附注补充 |
| D5 | Phase 10 合并静态审计 + invariant 验证 | 两者均属"证据汇总与一致性核对"性质，合并在一个 Phase 内提高 sub-agent 效率 |
| D6 | T38 子测试从 3 个扩展到 6 个 | Prompt §6 要求 T38-A/B/C；但 Prompt §19 要求搜索所有 return；L477 heartbeat / L478 result-read / L480 stats-items 是 v1.10 新增或修改路径，必须独立验证 |

---

## 附录 C：裁剪声明

本计划为 **L 型（大）**，依据：

- Phase 数：13（9+，符合 L 型）
- §0.6 独立性原则：保留全文
- §0.4 断点机制：完整 progress.json + 恢复原则
- 模块骨架：标准三段（Phase 0 基线 / Phase 11 复核 / Phase 12 收尾）+ 硬门槛分级
- Phase 11 独立复核：完整 16 项检查集
- §6.3 双维度计数：PS7 production-critical vs PS5.1 compatibility
- 独立审计轮：强制（每版修订后重审）

**裁剪红线确认**（以下均未裁剪）：
- 禁止事项（§3）：12 条，不为空
- 开工基线与指纹复核（Phase 0 + Phase 11）：完整
- 判定守恒式（§6.2/§6.3）：已定义
- 修订日志（§9）：初版已建