# SKILL-v1.11 定向生产验证 — 执行计划

> **版本**: exec-plan-v1.11-a（初版）
> **制定日期**: 2026-09-09
> **依据**: `.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md`（唯一事实源，共 39 节）
> **被测对象**: `SKILL-v1.11.md`
> **执行模式**: 单一 sub-agent 串行执行，禁止任何形式的多 sub-agent 并行
> **生产主运行环境**: Windows + PowerShell 7.x
> **兼容性回归环境**: PowerShell 5.1（仅做兼容性回归，不作为 production gate 主环境）
> **修订记录**: 见 §9 修订日志

---

## 0. 计划总览

### 0.1 核心目标

v1.10 修复了 Step 4 六条不可恢复错误路径的 `RUN_STATUS|failed|` 终态输出，但 T38-stats-items 存在 P1：stats/items 完整性失败路径（SKILL-v1.10 L480）输出 `RUN_STATUS|failed|` 后 **return 被移除**，执行落入后续 JSON 校验 try 块，可能导致**第二次 `RUN_STATUS|failed|`**，违反 constraint #13（L81）"仅输出一次"要求。

v1.11 的唯一修复目标（Prompt §4 允许的核心变化）：

```
Step 4 stats/items integrity failure
    ↓
REVIEW_WRITE_ERROR|
    ↓
RUN_STATUS|failed|（输出且仅输出一次）
    ↓
立即 return（v1.11 于 L480 行尾补齐 ;return）
    ↓
Step 4 终止
```

本轮硬门槛（Prompt §5/§6）：

```
RUN_STATUS_COUNT = 1
```

即 T38-stats-items 路径 `RUN_STATUS|failed|` 计数**恰好为 1**（不是 0，不是 2），且不存在 `RUN_STATUS|success|`、不存在继续执行后续 review write。同时确认该修复未破坏 v1.10 已通过的关键能力（Prompt §4 能力清单 30 项 + T22/T23/T37/T39/T43 行为回归）。

### 0.1.1 目标与完成定义（DoD）

```
v1.10 → v1.11 diff 仅含 3 个 hunk（L8 版本号 / L480 return / L768 changelog）
        ↓
T38-stats-items 真实注入 stats 篡改 → 失败路径命中
        ↓
REVIEW_WRITE_ERROR| ×1 → RUN_STATUS|failed| ×1 → return → Step 4 终止（sentinel 不出现）
        ↓
T38 其余 5 子测试 failed=1 / success=0（§12 统一计数）
        ↓
T22/T23/T37/T39/T43/T46/T04-PS7/T26/T18 全部重新执行且 PASS
        ↓
.monitor 由 SKILL 自己初始化（run.lock/backups/result.json/fetch_run.log 真实生成，正常结束 run.lock 不存在）
        ↓
Early Return Audit + Final Status Uniqueness Audit + Diff Integrity + Self-Review 全部 PASS
        ↓
PRODUCTION_READY（P0=0, P1=0, FAIL=0, BLOCKED=0，Prompt §34 清单逐项 PASS）
        ↓
禁止出现的假成功：RUN_STATUS 重复被改写为 PASS / 旧证据冒充新证据 / 被测 SKILL 被修改以消除失败 / FAIL 被改写为 BLOCKED
```

### 0.1.2 输入基线

开工前采集以下关键对象的指纹（Phase 0 执行）：

| 对象 | 指纹类型 | 保存文件 | 消费者（复核环节） |
|---|---|---|---|
| `SKILL-v1.11.md` | SHA256 | `v111.sha256` | Phase 12 self-review 第 1/2 项 |
| `SKILL-v1.10.md` | SHA256 | `v110.sha256` | Phase 12 self-review 第 13 项 |
| `.output/GitHub更新监测列表.md` | SHA256 | `state.sha256` | Phase 12 self-review 基线完整性 |

### 0.2 v1.10 → v1.11 Diff 概要

以下为基于 `git diff --no-index SKILL-v1.10.md SKILL-v1.11.md` 的实测变更分析（制定计划时已实际执行，diff 规模 **3 insertions + 2 deletions，共 3 个 hunk**；Phase 1 须重新生成并复核无其他 hunk）：

| 变更点 | SKILL-v1.11 行号 | v1.10 行为 | v1.11 修复 | 类别 |
|---|---|---|---|---|
| 版本号 | L8 | `> 版本：v1.10` | `> 版本：v1.11` | documentation |
| stats/items 完整性失败 return 补齐 | L480 | if 块内输出 `RUN_STATUS\|failed\|review 程序事实完整性校验失败，整轮终止。` 后**无 return**，执行落入 L481 `try {`（tmp 写入 + JSON 校验路径） | 行尾补齐 `;return`：`...整轮终止。';return};try {`。return 位于 if 块内，stats/items 不匹配时 Step 4 立即终止 | **核心修复** |
| Changelog | L768 | 不存在 | 新增 v1.11 条目（L766 章节标题 `## 15. Changelog` 下第一条；v1.10 条目移至 L769） | changelog |

**行号基线说明**（制定时经 Select-String 双源核实，超长行区域不采信 read_file 行号）：L477 heartbeat / L478 result-read + `$origStats` 固化 / L479 foreach 超长行 / L480 混合行（$doc.review 赋值 + $newStats/$newItems 计算 + if 校验 + v1.11 新增 return）/ L481 Set-Content tmp / L487 tmp-write RUN_STATUS / L489 第一个 try/catch 结束 `}` / L490 第二个 try 开始 / L496 JSON-check RUN_STATUS / L500 Move-Item / L506 atomic-replace RUN_STATUS / L621 `$commitSucceeded=$false` / L627 `$commitSucceeded=$true` / L636 if/else 块结束 `}` / L637 ownership 注释 / L638 `$lockReleased=$false` / L651 `RUN_STATUS|success|` / L768 v1.11 changelog。v1.10 → v1.11 除 L768 后插入 1 行外行号无偏移（L480 为同行替换）。

### 0.3 执行架构

```
Phase 0 (sub-agent) → 主 agent 审查 → Phase 1 (sub-agent) → 主 agent 审查 → ... → Phase 12 (sub-agent) → 主 agent 审查 → Phase 13 (主 agent 收尾)
```

- **严格串行**：下一 Phase 仅在上一 Phase 的主 agent 审查通过后启动
- **单一 sub-agent**：每个 Phase 派遣且仅派遣一个 sub-agent 执行（sub-coding-agent，用户级全局）
- **禁止并行**：任何时刻最多一个 sub-agent 在运行；sub-agent 不递归派遣（其 task 工具未注入，行为级实证见项目记忆）
- 主 agent 保留编排、审查与最终核实职责；审查 = 亲自读取证据文件核对，不采信 sub-agent 结论转述

### 0.4 中断接续方案

| 中断类型 | 检测方式 | 恢复策略 |
|---|---|---|
| LLM API 调用失败（sub-agent 无返回/错误） | sub-agent 无返回或返回错误 | 主 agent 重试同一 Phase，传入 `resume_from` 参数指向已完成步骤 |
| 网络波动（GitHub API 超时/失败） | 测试 stdout 中 API 异常 | 步骤内退避重试（max_retries=3），仍失败则标 BLOCKED |
| 资源限制（sub-agent 输出截断） | 返回不完整 | 主 agent 核验已产出证据文件，从断点继续 |
| sub-agent 上下文溢出 | 返回不完整结果 | 主 agent 核验已生成证据，拆分剩余工作到新 sub-agent 实例（上下文经 prompt 自包含传入） |

**断点保存机制**：每个 Phase 完成后，sub-agent 在测试目录下生成/更新 `phase-progress.json`：

```json
{
  "phase": "Phase0",
  "start_time": "2026-09-09T10:00:00+08:00",
  "end_time": "2026-09-09T10:30:00+08:00",
  "status": "completed|partial|failed",
  "completed_steps": ["step1", "step2"],
  "pending_steps": [],
  "evidence_files": ["v110.sha256", "v111.sha256"],
  "next_phase": "Phase1"
}
```

主 agent 在启动下一 Phase 前读取此文件，确认状态为 `completed` 后方可继续；若 `partial`，向新 sub-agent 传入 `resume_from`。**恢复不依赖会话记忆，只依据产物文件 + progress 文件 + `resume_from`**（sub-agent 无状态调用契约：每子任务全新实例）。

### 0.5 测试隔离机制

所有测试通过 `GITHUB_VERSION_MONITOR_BASE` 环境变量实现 fixture 隔离。SKILL-v1.11 每个 step 均支持此变量（SKILL L163/L241/L432/L474/L522）。

- 每个测试子目录作为独立 base 目录，`$env:GITHUB_VERSION_MONITOR_BASE = '<test-dir>'`
- `.monitor/` 由 Step 1 在 base 目录下动态创建（Prompt §24：**不得由测试 harness 预先创建**）
- `.output/GitHub更新监测列表.md` 使用 fixture 副本，不触碰生产文件

**锁 PID 一致性机制**（本轮显式设计明确化）：

生产语义中 Step 1-5 由同一进程（agent 会话）连续执行，各 step heartbeat（Step 2/3/4）与锁释放（Step 5）的 ownership 校验要求锁内 PID == 当前进程 PID。测试中凡**单进程编排器**（`& stepN.ps1` 顺序调用，同进程同 PID）天然满足；凡**独立执行单个 step** 的场景，编排器须在执行该 step 前将 `run.lock` 的 `pid=` 字段重写为编排器自身 PID（保留 `start=` 字段）——此操作模拟"同进程连续持有"，作用于测试 fixture 运行态，**不属于修改被测 SKILL**，每次执行记录于对应 harness 说明与 test-report。

**Mock 重定向机制**（T04/T18 状态机测试）：

SKILL 中 API URL 硬编码 `https://api.github.com`（SKILL L341/L479），无 base 覆盖机制。测试采用 **PowerShell 函数覆盖**：mock harness 在执行 step2 代码前先定义 mock `Invoke-RestMethod` 覆盖内置 cmdlet，按场景返回受控响应；不修改被测代码，仅运行时注入函数覆盖。

**T46 运行目录**：`.production-validation-v111-final/T46/`，通过 `GITHUB_VERSION_MONITOR_BASE` 指向，不触碰生产根目录。

### 0.6 独立性原则

```
1. 所有测试设计决策必须基于以下两个事实源的直接阅读：
   - SKILL-v1.11.md 源码（行号 + 代码逻辑）
   - Production Validation Prompt — SKILL-v1.11 Targeted Validation 原文（39 节）

2. 旧版本验证报告（v17/v18/v19/v110）的结论不得作为本轮测试设计的依据。
   旧报告中的发现只能作为"待独立验证的声明"，不能作为已验证事实。

3. 如果在计划制定过程中引用了旧报告的发现，
   必须在执行阶段由 sub-agent 独立验证该发现是否成立。

4. 旧报告的"结论"（PASS/FAIL/计数）仅供信息参考，
   不得影响本轮任何测试的构造方法、验证项或判定逻辑。

5. 链式继承风险：最初版本的系统性偏差将沿版本链传播。
   本计划通过上述原则切断继承链。
```

> 信息参考（不作为设计依据）：v1.10 轮报告判定 T38-stats-items 为 P1（return 缺失导致落入后续 try 块）。本计划的 T38-stats-items 注入设计基于对 SKILL-v1.11 L478-L481 的直接阅读独立成立；v1.11 的修复（L480 `;return`）已经 `git diff --no-index` 实测确认。

### 0.7 执行模式

- 所有脚本经 `pwsh -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>` 执行（PS7）或 `powershell.exe -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>`（PS5.1 兼容性测试），后台静默，输出重定向到文件。
- **进程模型声明**：`-File` 模式下每个脚本独立进程，**脚本间无共享变量**。凡需"中途注入/同进程分段控制"的场景，必须设计同进程 harness（单进程编排器：`& stepN.ps1` 同进程顺序调用 + 注入版内联代码），并做受限 diff 验证。dot-source 单个 step 无法实现"执行到某行暂停注入"，注入类场景必须内联复制目标代码 + 精确注入点。
- 常驻辅助进程（文件锁持有者/并发锁竞争者/目录监视者）用 `Start-Process -WindowStyle Hidden` 启动、测试后 `Stop-Process` 终止。

### 0.8 正式汇报：执行模式声明

**后台静默模式覆盖范围**：本计划全部 14 个 Phase（Phase 0-13）的所有执行操作和测试流程均采用后台静默模式运行，不弹出任何前台窗口或对话框。

具体实现：
- PowerShell 脚本：`pwsh -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>`（PS7）/ `powershell.exe -NoProfile -NonInteractive -File ...`（PS5.1）
- 常驻辅助进程（文件锁持有者、并发锁竞争者、.monitor 目录监视者）：`Start-Process -WindowStyle Hidden` 启动，`Stop-Process` 终止
- 同进程 harness（T38 六子测试 / T39 / T22 / T23 / runtime-artifact）：`pwsh -NoProfile -NonInteractive -File <harness.ps1> *>&1 > <output.txt>`
- 进程终止测试（process kill）：对后台已启动的 pwsh 进程执行 `Stop-Process`，无窗口交互

**前台执行模式声明**：本计划**不存在**必须使用前台执行模式的特殊场景。

> 如执行过程中因环境限制（如 PS5.1 不存在、ACL 权限不足）导致某测试无法在后台静默模式完成，sub-agent 须标记 BLOCKED 并在 test-report.md 记录具体原因，不得自动切换至前台模式。

### 0.9 任务追踪机制

主 agent 维护全局任务追踪表，记录每个 Phase 的开始时间、结束时间、执行状态和关键节点。此表在主 agent 审查点更新，不依赖 sub-agent 会话记忆。

**追踪表模板**（主 agent 在每个 Phase 审查通过后更新）：

| Phase | 模块名 | 开始时间 | 结束时间 | 执行状态 | 关键节点 | 审查结果 |
|---|---|---|---|---|---|---|
| 0 | Clean-Room + SHA256 | {{ISO8601}} | {{ISO8601}} | completed | 3 SHA256 文件 / git add 完成 | PASS |
| 1 | Diff + 代码提取 + 工具集 | {{ISO8601}} | {{ISO8601}} | completed | 30 项能力核验 / 工具+harness 就绪 | PASS |
| 2 | T38 六子测试 + 统一计数 | {{ISO8601}} | {{ISO8601}} | {{status}} | stats-items RUN_STATUS=1 确认 | {{result}} |
| 3 | T22/T23 回归 | {{ISO8601}} | {{ISO8601}} | {{status}} | T22/T23 结果 | {{result}} |
| 4 | T37 成功回归 | {{ISO8601}} | {{ISO8601}} | {{status}} | RUN_STATUS\|success\| ×1 确认 | {{result}} |
| 5 | T39 回归 | {{ISO8601}} | {{ISO8601}} | {{status}} | commit+lock 失败终态确认 | {{result}} |
| 6 | T43+T46 | {{ISO8601}} | {{ISO8601}} | {{status}} | 全管线+路径契约确认 | {{result}} |
| 7 | Runtime artifact 初始化 | {{ISO8601}} | {{ISO8601}} | {{status}} | .monitor 生命周期工件确认 | {{result}} |
| 8 | T04+T26+T18 | {{ISO8601}} | {{ISO8601}} | {{status}} | 状态机+flag+保留确认 | {{result}} |
| 9 | PS5.1 兼容 | {{ISO8601}} | {{ISO8601}} | {{status}} | PS5.1 header 兼容确认 | {{result}} |
| 10 | Lock+ProcessKill | {{ISO8601}} | {{ISO8601}} | {{status}} | 并发/陈锁/ownership/kill 确认 | {{result}} |
| 11 | 静态审计+Invariant | {{ISO8601}} | {{ISO8601}} | {{status}} | early-return / uniqueness / I 系列确认 | {{result}} |
| 12 | Self-Review | {{ISO8601}} | {{ISO8601}} | {{status}} | 19 项复核完成 | {{result}} |
| 13 | Final Report + Commit | {{ISO8601}} | {{ISO8601}} | {{status}} | 报告生成 / commit 完成 | {{result}} |

**追踪表保存位置**：`.production-validation-v111-final/task-tracker.md`（主 agent 维护，每个 Phase 审查后更新）

**与 phase-progress.json 的关系**：`phase-progress.json` = sub-agent 生成，记录 Phase 内部步骤级进度（自动化恢复用）；`task-tracker.md` = 主 agent 维护，记录 Phase 级全局状态（审查与决策用）。恢复时先读 task-tracker.md 确定从哪个 Phase 继续，再读该 Phase 的 phase-progress.json 确定从哪个步骤继续。

### 0.10 Test Harness Integrity 协议（Prompt §30）

测试过程中允许修复 harness（orchestrator / wrapper / fixture / report generator），但每次修复必须：

1. 记录时间（ISO8601）
2. 记录原因
3. 说明修复对象不属于被测 SKILL（`SKILL-v1.11.md` 指纹不变，Phase 12 复核）
4. 重新执行受影响的测试（旧证据不覆盖新证据，新证据追加并存）

严禁：修改 `SKILL-v1.11.md`；修改 harness 后将原测试重新标记 PASS 而不重新执行。如果 harness 自身产生错误：先修 harness，再重新执行对应测试。

所有 harness 修复记录汇总于 `.production-validation-v111-final/harness-fix-log.md`（每次修复追加一条）。

---

## 1. 模块分解

### 模块总览表

| Phase | 模块名 | 输入 | 输出 | 优先级 |
|---|---|---|---|---|
| 0 | Clean-Room + Git/SHA256 + 被测对象纳入 git | SKILL-v1.10.md, SKILL-v1.11.md, .output/...md | 目录树 + 3 个 SHA256 文件 + git staging | 基础 |
| 1 | Diff Integrity + 代码提取 + 工具集 | v1.10/v1.11 SHA256 + 两文件 | v110-v111.diff + diff-integrity.md + lib/*.ps1 + extraction-manifest.json + mock 工具 | 基础 |
| 2 | T38 六子测试 + §12 统一计数 | lib/ 编排器 + harness, fixture | T38-A/B/C/heartbeat/result-read/stats-items 测试目录 + t38-unified-count.md | **硬门槛** |
| 3 | T22/T23 — md tmp 写入/原子替换失败回归 | lib/step5-full.ps1, fixture | T22 + T23 测试目录 + 证据 | **硬门槛** |
| 4 | T37 — 正常成功回归 | lib/step1-5.ps1, fixture | T37 测试目录 + 证据 | **硬门槛** |
| 5 | T39 — Commit 成功 + 锁释放失败 | lib/step5-t39-harness.ps1, fixture | T39 测试目录 + 证据 | **硬门槛** |
| 6 | T43 + T46 — 全管线 + 路径契约 | fixture（6 场景） | T43 + T46 测试目录 + 证据 | 关键 |
| 7 | Runtime Artifact Initialization | 全新 base + fixture | runtime-artifact 测试目录 + 生命周期快照链 | **硬门槛** |
| 8 | T04-PS7 + T26 + T18 — 状态机 + Flag + 状态保留 | lib/mock 工具, fixture | T04-PS7 + T26 + T18 测试目录 + 证据 | 中 |
| 9 | PS5.1 兼容性回归（T04-PS5.1 + T05-PS5.1） | lib/mock 工具, PS5.1 | 2 个测试目录 + 证据 | 兼容 |
| 10 | Lock 回归 + Process Kill | lib/step1.ps1, fixture | lock 4 项 + process-kill 测试目录 + 证据 | 中 |
| 11 | Early Return Audit + Final Status Uniqueness + Invariant | SKILL-v1.11.md 全文 + 全部前序证据 | 3 份审计报告 | **关键** |
| 12 | Self-Review | 全部 Phase 0-11 证据 | selfreview-v111-\<时间戳\>.md | 质量控制 |
| 13 | Final Report + Commit | 全部证据 | production-validation-report-v111-final.md | 收尾 |

### 拆解规则

1. **输入封闭**：每个模块的输入只允许来自（a）事实源文件（b）已通过审查的前序 Phase 产出。模块间**只通过产物文件传递状态**，绝不通过 sub-agent 的会话记忆传递。
2. **输出清单化**：每个模块的产出是逐文件清单，可被审查点逐项核对。
3. **粒度**：单模块工作量 = 单个 sub-agent 一次会话可完成（上下文预算内）；超出则继续拆分。
4. **优先级语义**：硬门槛 = 失败即整体判定 PRODUCTION_NOT_READY（仍完成后续 Phase 保留证据）；关键 = 失败进入高风险复核；中/辅助 = 失败记录不阻断。硬门槛模块已在总览表显式标注。
5. **第一模块固定为基线采集**（Phase 0），**倒数第二模块固定为独立复核**（Phase 12），**最后模块固定为汇总收尾**（Phase 13）。

---

## 2. 各 Phase 详细规格

---

### Phase 0: Clean-Room + Git/SHA256 + 被测对象纳入 git

**前置条件**: 项目根目录 `d:\AI\Workspace\automatic\github-version-monitor` 存在且为 git 仓库

**输入参数**:
- 项目根目录: `d:\AI\Workspace\automatic\github-version-monitor`
- 测试目录: `.production-validation-v111-final/`
- 被测文件: `SKILL-v1.10.md`, `SKILL-v1.11.md`, `.output/GitHub更新监测列表.md`

**处理逻辑**:
1. 创建 `.production-validation-v111-final/` 目录树：
   ```
   .production-validation-v111-final/
   ├── lib/
   ├── T22/  ├── T23/  ├── T37/
   ├── T38-A/  ├── T38-B/  ├── T38-C/
   ├── T38-heartbeat/  ├── T38-result-read/  ├── T38-stats-items/
   ├── T39/  ├── T43/  ├── T46/
   ├── T04-PS7/  ├── T04-PS5.1/  ├── T05-PS5.1/
   ├── T18/  ├── T26/
   ├── runtime-artifact/
   ├── lock-concurrency/  ├── lock-ownership/
   ├── lock-stale-alive/  ├── lock-stale-dead/
   ├── process-kill/
   ├── audit/
   ├── .selfreview/
   └── phase-progress.json
   ```
   > **`.monitor/` 不在目录树中预创建**（Prompt §24）：由 Step 1 在每个测试的 base 目录下动态创建。

2. 禁止复用以下目录中的任何实际测试状态作为当前 PASS 证据（Prompt §1: `OLD_EVIDENCE_USED_AS_CURRENT_PASS = NO`）：`.production-validation-v110-final/`、`.production-validation-v19-final/`、其他历史 validation 目录（v17/v18 等，存在性以 Test-Path 实测为准）。本轮所有 fixture、runtime state、result.json、lock、stdout、stderr 必须重新建立。

3. 计算 3 个文件 SHA256（Prompt §3）：
   ```powershell
   Get-FileHash .\SKILL-v1.10.md -Algorithm SHA256
   Get-FileHash .\SKILL-v1.11.md -Algorithm SHA256
   Get-FileHash .\.output\GitHub更新监测列表.md -Algorithm SHA256
   ```
   保存为 `v110.sha256`、`v111.sha256`、`state.sha256`

4. **将被测对象与事实源纳入 git**（Prompt §2"必须从当前 Git repository 获取"+ §39"Git repository = 唯一事实源"）：
   - `git ls-files SKILL-v1.11.md` 确认跟踪状态（当前为 untracked）
   - `git add SKILL-v1.11.md ".GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md"`（两文件当前均 untracked，纳入版本控制；不修改内容）

**输出结果**:
- `.production-validation-v111-final/v110.sha256`
- `.production-validation-v111-final/v111.sha256`
- `.production-validation-v111-final/state.sha256`
- `.production-validation-v111-final/phase-progress.json`
- `SKILL-v1.11.md` 与 v1.11 验证提示文件已 staged

**证据要求**:
- `.production-validation-v111-final/phase0-stdout.txt` — 目录创建 + SHA256 计算 + git add 的完整 stdout
- `.production-validation-v111-final/phase0-stderr.txt`
- `.production-validation-v111-final/phase0-report.md` — 执行摘要

**主 agent 审查点**（全部满足才放行）:
- [ ] 确认 3 个 SHA256 文件存在且内容非空
- [ ] 确认目录树结构完整（与上方清单逐项核对，无 `.monitor/` 预创建）
- [ ] 确认 `git status` 显示 `SKILL-v1.11.md` 与验证提示文件已 staged 或已 tracked
- [ ] 确认未复制旧测试目录的任何 fixture/stdout/结果文件（抽查 2-3 个子目录为空或仅含本轮产物）

**失败处理**: 目录创建失败 → 检查磁盘空间与权限后重试；git add 失败 → 检查文件路径（含空格与中文文件名须加引号）后重试。

---

### Phase 1: Diff Integrity + 代码提取 + 工具集

**前置条件**: Phase 0 完成，3 个 SHA256 文件存在

**输入参数**:
- 测试目录: `.production-validation-v111-final/`
- 源文件: `SKILL-v1.10.md`, `SKILL-v1.11.md`

**处理逻辑**:

#### Step 1: 生成 diff（Prompt §4）

```powershell
git diff --no-index SKILL-v1.10.md SKILL-v1.11.md > .production-validation-v111-final/v110-v111.diff; exit 0
```

> **退出码处理**：`git diff --no-index` 在存在差异时退出码为 1（属预期行为）。追加 `; exit 0` 归零退出码，避免 `-File` 模式下非零退出码被误判为 Phase 1 失败。

#### Step 2: Diff 完整性分析 — hunk 核验

逐 hunk 核对 diff 与 §0.2 概要表一致，**预期恰好 3 个 hunk（3 insertions + 2 deletions）**：
1. L8 版本号行替换（documentation）
2. L480 stats/items 完整性失败路径行内替换：`RUN_STATUS|failed|...整轮终止。` 后补齐 `;return`（核心修复）
3. L768 changelog 新增 v1.11 条目（v1.10 条目顺移至 L769）

如 diff 中出现**任何其他 hunk**（其他行的新增/删除/修改）→ Diff Integrity FAIL + P1（Prompt §4：核心变化只能是 stats/items 修复及直接相关的 documentation/invariant/changelog）。

#### Step 3: 能力保留核验（Prompt §4，共 30 项）

必须确认 v1.11 保留 v1.10 的全部关键能力（逐项显式核验，每项记录"diff 无删除 + 代码存在行号"）：

```
.output/GitHub更新监测列表.md
.monitor/

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

Get-ResponseHeaderValue
PS7 production baseline
PS5.1 compatibility
```

特别检查（Prompt §4）：versionJump / dateSuspicious / schema / not_found / atomicity / lock / RUN_STATUS / .output。**不得只检查"关键词还存在"**——行为完整性由 T37/T38/T39/T43 回归证明（Prompt §28，Phase 4/2/5/6）。

#### Step 4: 辅助禁止项检查（继承 v1.10-d 实践；非 v1.11 Prompt 明文要求，作为防御性检查）

确认以下内容不存在于 diff 新增行中（共 9 项，逐项点数）：

```
mock URL / forced success / debug bypass / test-only branch /
hardcoded token / hardcoded test repository /
skip schema / skip lock / skip commit
```

#### Step 5: 从 SKILL-v1.11.md 提取 PowerShell 代码块

逐字提取，禁止修改被测代码（提取工具 `lib/extract-code.ps1` 按代码块围栏定位）：

- `lib/step1.ps1` — Step 1（状态检查 + 锁 + 备份，约 L160-231）
- `lib/step2.ps1` — Step 2（解析 + 查询 + 状态机 + 统计，约 L240-423）
- `lib/step3.ps1` — Step 3（备份清理，约 L431-452）
- `lib/step4.ps1` — Step 4（复核，约 L471-517）
- `lib/step5-full.ps1` — Step 5 完整（提交 + 锁释放 + RUN_STATUS，约 L521-655）

> **注意**：SKILL Step 6 是 agent 汇报模板，无 PowerShell 代码块，不需要提取。本计划"完整 Step 1→6"（T37/T43）指 Step 1→5 代码执行 + Step 6 汇报模板结构（最终报告按其章节组织）。
>
> **超长行警告**：Step 4 区域（L475-510）含多个 >2000 字符单行。提取工具必须按 md 代码围栏整块提取，禁止按行号截取后手工拼接；提取后逐文件与源码块比对（受限 diff 零差异）。

#### Step 6: 创建 harness 与编排器

**统一编排器模式**（T38/T22/T23 共用）：单进程 pwsh 脚本内 `$env:GITHUB_VERSION_MONITOR_BASE = '<test-dir>'` 后顺序 `& step1.ps1; & step2.ps1; & step3.ps1`（同进程同 PID，锁 ownership 天然一致），再按测试构造执行被测 step（原样 `& step4.ps1` / `& step5-full.ps1`，或注入版内联代码），最后 `Write-Output 'SENTINEL|AFTER_<STEP>'`。

- `lib/t38-orchestrator-a.ps1` — Step1-3 前置 → 施加 tmp 写入故障 → `& step4.ps1` → SENTINEL
- `lib/t38-orchestrator-b.ps1` — Step1-3 前置 → 内联注入版 Step 4（L489/L490 之间注入 tmp 篡改）→ SENTINEL
- `lib/t38-orchestrator-c.ps1` — Step1-3 前置 → 外部进程锁 result.json → `& step4.ps1` → SENTINEL
- `lib/t38-orchestrator-heartbeat.ps1` — Step1-3 前置 → 外部进程锁 run.lock → `& step4.ps1` → SENTINEL
- `lib/t38-orchestrator-result-read.ps1` — Step1-3 前置 → 删除 result.json → `& step4.ps1` → SENTINEL
- `lib/t38-orchestrator-stats-items.ps1` — Step1-3 前置 → 内联注入版 Step 4（L479/L480 之间注入 `$doc.stats.total = 999`）→ SENTINEL（**本轮最高优先级**）
- `lib/t22-orchestrator.ps1` — Step1-4 前置 → ACL deny `.output` CreateFiles → try{`& step5-full.ps1`}finally{ACL 还原} → SENTINEL
- `lib/t23-orchestrator.ps1` — Step1-4 前置 → 外部进程锁主 md → `& step5-full.ps1` → SENTINEL
- `lib/step5-t39-harness.ps1` — T39 同进程 harness（见下）
- `lib/runtime-artifact-pipeline.ps1` — Phase 7 单进程管线（step 间插入 .monitor 快照，快照仅读取目录清单与文件内容，不修改任何状态）
- `lib/run-full-pipeline.ps1` — T37/T43 单进程完整管线（`& step1..5` 顺序调用）
- `lib/lock-holder.ps1` — 外部文件锁持有进程（`[System.IO.File]::Open(...,FileShare::None)` 保持打开直到信号文件出现；`Start-Process -WindowStyle Hidden` 启动）
- `lib/watch-dir.ps1` — .monitor 目录监视进程（50ms 间隔轮询记录出现的文件名清单；Phase 7 用）

**T38-B 注入设计**（内联复制 Step 4 代码，在 L489（第一个 try/catch 结束 `}`）与 L490（第二个 try `try { $check=Get-Content $tmpPath...`）之间注入）：
```powershell
# T38-B 注入：篡改 tmp 文件内容为非法 JSON
Set-Content $tmpPath -Value '{invalid json' -Force
```

**T38-stats-items 注入设计**（在 L479（foreach 超长行）与 L480（$doc.review 赋值 + $newStats/$newItems 计算 + if 校验混合行）之间注入）：
```powershell
# T38-stats-items 注入：篡改 stats 使完整性校验失败
$doc.stats.total = 999
```
> **注入有效性依据**（基于 L478-L480 直接阅读）：`$origStats` 在 L478 行尾固化为 JSON 字符串快照（`$doc.stats|ConvertTo-Json -Depth 8 -Compress`）；注入修改 `$doc.stats.total` 后，L480 计算的 `$newStats` 序列化结果必然 ≠ `$origStats`（字符串比较，修改必然反映）→ if 命中 → 失败路径触发。
>
> **边界条件**：fixture 经真实 Step 2 产生的 `result.json` 的 `stats.total` 不得恰为 999（Step 2 统计的 total = 监测项总数，fixture 用 1-2 项天然远离 999；执行前断言一次并记录）。

**T39 harness 注入设计**：内联复制 Step 5 代码，在 L636（if/else 块整体结束 `}`）与 L637（`# 释放锁前确认 ownership`）之间注入：
```powershell
# T39 注入：模拟锁被外来 PID 持有
Set-Content $lockPath -Value "pid=999999;ts=$(Get-Date -Format o)" -Force
```
> dot-source `step5-full.ps1` 会一次性连续执行完整 Step 5，不存在"执行至 Move-Item 成功后暂停"的注入点，唯一可行方式是内联复制 + 注入（§0.7 进程模型声明）。
>
> **前置变量**：harness 须预置 `$conclusionText` / `$summaryText` / `$noteText`（SKILL L539-547 占位值），否则 Step 5 md 组装失败。

**SENTINEL 机制与期望表**（行为链直接证明，Prompt §5-§11"不能继续执行"要求）：

| 测试 | 目标路径 return 位置 | SENTINEL 期望 | 依据 |
|---|---|---|---|
| T38-A | L487 catch 内 return | **不出现** | tmp 写入失败 → return |
| T38-B | L496 catch 内 return | **不出现** | JSON 校验失败 → return |
| T38-C | L506 catch 内 return | **不出现** | 原子替换失败 → return |
| T38-heartbeat | L477 catch 内 return | **不出现** | heartbeat 失败 → return |
| T38-result-read | L478 catch 内 return | **不出现** | result.json 读取失败 → return |
| T38-stats-items | **L480 if 块内 return（v1.11 修复）** | **不出现** | 完整性校验失败 → return（若出现 = 修复无效 = FAIL+P1） |
| T22 | L607 catch 内 return | **不出现** | md tmp 写入失败 → return |
| T23 | 无 return（L630 catch 后落入锁释放与终态输出） | **出现** | 替换失败 → 清理 → 锁释放 → RUN_STATUS\|failed\|（L653）→ 自然结束 |
| T39 | 无 return（失败终态 L649 后自然结束） | **出现** | commit 成功 + 锁释放失败 → RUN_STATUS\|failed\| → 自然结束 |

#### Step 7: 创建 mock 工具

- `lib/mock-invoke-restmethod.ps1` — mock `Invoke-RestMethod` 覆盖函数库
- `lib/step2-mock-harness.ps1` — mock 测试包装：定义 mock → 执行 step2 代码
- `lib/create-fixture.ps1` — fixture 生成工具
  - **localVer 策略**：synced/versionJump 场景须运行时动态查询 `releases/latest` 获取最新 release 版本后生成 fixture（synced: localVer=最新版本；versionJump: localVer=低版本使 major 差 ≥2 或 minor 差 ≥10）；404 场景使用不存在的 repo 名称；normal/uninstalled/unsupported 使用固定 fixture。动态查询策略避免上游发版导致场景漂移。

> **PS5.1 语法兼容要求**：`mock-invoke-restmethod.ps1` 和 `step2-mock-harness.ps1` 在 Phase 1（PS7 环境）创建，但被 Phase 9（PS5.1 环境）复用。这两个脚本须使用 PS5.1 兼容语法（禁用 PS7-only 运算符：`??`、`? :` 三元、`&&`/`||` 管道链），否则 Phase 9 意外失败的原因与被测对象无关。Phase 1 对齐自检中增加语法兼容检查（可用 `powershell.exe -NoProfile -Command` 语法解析实测）。

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
- `Exception.Response.StatusCode`：SKILL L355 以 `[int]$_.Exception.Response.StatusCode` 显式转换后数值比较（L361-366），mock 侧使用 `int` 或 `System.Net.HttpStatusCode` 枚举实例均可兼容；推荐枚举实例以贴近真实响应形状。
- `X-RateLimit-Remaining` 取值：SKILL L364 以字符串比较（`$rl -eq '0'`），mock Headers 返回值**必须为字符串** `'0'` / `'50'`（不得为 int）。
- `Exception.Response` 必须真实存在（真值），network_error 场景则必须**无** `.Response` 或 `.Response.StatusCode` 为 null。
- **PS7 侧 `Headers` 类型选择**：二选一并记录于 `lib/mock-contract-selfcheck.txt`——a) `System.Net.WebHeaderCollection`（与 PS5.1 共用同一 mock 库）；b) `System.Net.Http.Headers.HttpResponseHeaders` 形状对象（覆盖更完整，构造复杂度高）。无论选择哪种，最终报告 **K 节**必须如实记录 PS7 header 分支的覆盖方式。

**对齐自检**：mock 函数库构造完成后、任何测试执行前，做一次 "contract → SKILL 提取表达式" 对齐自检：按 SKILL L341-367 逐成员模拟访问，确认每个场景取值路径与 contract 表一致，结果记录于 `lib/mock-contract-selfcheck.txt`（含 PS7 Headers 类型选择记录）。

#### Step 8: 生成提取清单 + stdout 透传验证

生成 `lib/extraction-manifest.json`，记录每个提取脚本的源行号范围与 SHA256：

```json
{
  "source_file": "SKILL-v1.11.md",
  "source_sha256": "<v111.sha256 值>",
  "extractions": [
    { "file": "step1.ps1", "source_lines": "160-231", "sha256": "<提取文件 SHA256>" },
    { "file": "step2.ps1", "source_lines": "240-423", "sha256": "..." },
    { "file": "step3.ps1", "source_lines": "431-452", "sha256": "..." },
    { "file": "step4.ps1", "source_lines": "471-517", "sha256": "..." },
    { "file": "step5-full.ps1", "source_lines": "521-655", "sha256": "..." }
  ]
}
```
> source_lines 以实际代码围栏为准（上方数值为制定时估算，提取时实测修正并记录）。

此清单供 Phase 12 self-review 验证提取脚本与原文一致性。

> **harness 逐字性验证**：注入版 harness（`step5-t39-harness.ps1`、t38-orchestrator-b / t38-orchestrator-stats-items 的内联代码）做**受限 diff**——与 SKILL 原文对应代码块仅允许存在计划声明的注入差异（T39: L636/L637 之间 PID 重写；T38-B: L489/L490 之间 tmp 篡改；T38-stats-items: L479/L480 之间 stats 篡改），其余代码逐字一致。Phase 12 第 15 项复核。

> **stdout 捕获策略**：Phase 1 完成后，独立运行 `run-full-pipeline.ps1` 一次（隔离 base），实际验证 stdout 透传行为并记录证据（`lib/stdout-verification.txt`）。如透传正常 → T37/T43 单次执行捕获 stdout；如透传异常 → 逐 step 执行 + 拼接 stdout（此时逐 step 间须按 §0.5 锁 PID 一致性机制处理）。决策依据是本轮独立验证，而非旧报告声明。

**输出结果**:
- `.production-validation-v111-final/v110-v111.diff`
- `.production-validation-v111-final/diff-integrity.md`（hunk 核验 + 30 项能力表 + 9 项辅助检查 + 行号记录）
- `.production-validation-v111-final/lib/step1.ps1` ~ `step5-full.ps1`（5 个提取脚本）
- `.production-validation-v111-final/lib/t38-orchestrator-{a,b,c,heartbeat,result-read,stats-items}.ps1`（6 个）
- `.production-validation-v111-final/lib/t22-orchestrator.ps1` / `t23-orchestrator.ps1`
- `.production-validation-v111-final/lib/step5-t39-harness.ps1`
- `.production-validation-v111-final/lib/runtime-artifact-pipeline.ps1`
- `.production-validation-v111-final/lib/run-full-pipeline.ps1`
- `.production-validation-v111-final/lib/lock-holder.ps1` / `watch-dir.ps1`
- `.production-validation-v111-final/lib/mock-invoke-restmethod.ps1` / `step2-mock-harness.ps1` / `create-fixture.ps1` / `extract-code.ps1`
- `.production-validation-v111-final/lib/extraction-manifest.json`
- `.production-validation-v111-final/lib/mock-contract-selfcheck.txt`
- `.production-validation-v111-final/lib/stdout-verification.txt`
- `.production-validation-v111-final/phase-progress.json`

**证据要求**:
- `.production-validation-v111-final/phase1-stdout.txt` / `phase1-stderr.txt` / `phase1-report.md`

**主 agent 审查点**:
- [ ] 确认 diff 恰好 3 个 hunk（3+/2-），与 §0.2 表逐项一致，无其他变更
- [ ] 确认 diff-integrity.md 中 30 项能力逐项核验完成（含 `.monitor/` 与 `Get-ResponseHeaderValue` 两项）
- [ ] 确认 9 项辅助禁止项检查完成
- [ ] 确认 L480 修复行包含 `;return`（逐字核对 diff 输出）
- [ ] 确认 5 个 step 提取脚本 + 6 个 T38 编排器 + 2 个 T22/T23 编排器 + T39 harness + runtime-artifact 管线 + run-full-pipeline + lock-holder + watch-dir + 4 个 mock/fixture/extract 工具全部按清单产出
- [ ] 确认 extraction-manifest.json 存在且非空；mock-contract-selfcheck.txt 与 stdout-verification.txt 存在且记录了独立验证结果
- [ ] 确认注入版 harness 的注入点行号与本计划声明一致（抽查 t38-orchestrator-stats-items 的注入位于 L479/L480 之间）

**失败处理**: diff 出现预期外 hunk → Diff Integrity FAIL + P1，记录并继续后续 Phase 保留证据；代码提取与原文不一致 → 立即中止并标 BLOCKED。

---

### Phase 2: T38 六子测试 + §12 统一计数（硬门槛，本轮最高优先级）

**前置条件**: Phase 1 完成，lib/ 全部工具就绪

**输入参数**:
- 测试目录: `.production-validation-v111-final/T38-*/`（各子测试 base 目录）
- 编排器/harness: `lib/t38-orchestrator-*.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

**通用前置**（每个 T38 子测试相同）：
1. 各子测试 base 目录下 fixture：`.output/GitHub更新监测列表.md`（含 1 个触发 `review=true` 的仓库项，推荐用不存在的 repo（404 → not_found → review=true，稳定无版本漂移））；`.monitor/` 不存在（前置断言并记录）
2. 编排器单进程执行：`$env:GITHUB_VERSION_MONITOR_BASE='<dir>'` → `& step1.ps1`（建锁+备份）→ `& step2.ps1`（真实 API，产生 result.json，not_found 项 review=true）→ `& step3.ps1` → 按子测试构造故障 → 执行 Step 4（原样或注入版）→ SENTINEL
3. Step 4 执行中 review 项的 API 调用（L479 foreach：列表接口 + HTML 诊断）为真实调用（404 repo → 请求失败记入 finding，不影响流程推进，注入点仍可达；网络波动按 §0.4 退避重试）

#### T38-stats-items: stats/items 完整性失败终态验证（Prompt §5/§6，**核心硬门槛**）

**目标**: SKILL L480 stats/items 完整性失败路径。v1.10 该路径 return 缺失（P1），v1.11 于 L480 行尾补齐 `;return`。本测试直接证明修复生效。

**构造方法**: 同进程注入（Prompt §5 推荐"同进程 harness"）——`t38-orchestrator-stats-items.ps1` 内联 Step 4 代码，在 L479 与 L480 之间注入 `$doc.stats.total = 999`，使 `$newStats != $origStats`（注入有效性依据与边界条件见 Phase 1 Step 6）。

**期望行为链**（Prompt §6 精确行为链，逐环节证明）：

```
stats/items integrity failure（$doc.stats.total=999 → $newStats -ne $origStats）
        ↓ 证据: 注入断言记录、stdout 无中间报错
REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。（×1）
        ↓ 证据: stdout 计数
RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。（×1）
        ↓ 证据: stdout 计数
return（L480，v1.11 修复）
        ↓ 证据: SENTINEL|AFTER_STEP4 不出现
Step 4 终止（未落入 L481 try 块）
        ↓ 证据: stdout 无 REVIEW_WRITE_OK|、result.review.tmp 不存在、result.json unchanged
```

**验证项**:
```
REVIEW_WRITE_ERROR|review 修改了 stats/items          — count = 1
RUN_STATUS|failed|review 程序事实完整性校验失败       — count = 1（不是 0，不是 2）
SENTINEL|AFTER_STEP4                                   — 不出现
RUN_STATUS|success|                                    — count = 0
COMMIT_OK|                                             — count = 0
REVIEW_WRITE_OK|                                       — count = 0（未继续 review write）
第二次 RUN_STATUS|failed|（任何消息）                  — count = 0
result.json unchanged                                  — SHA256 before vs after 不变
stats/items unchanged                                  — result-after.json 内容比对
result.review.tmp                                      — 不存在（L481 Set-Content 未执行）
run.lock                                               — 不存在（Release-LockSafely 成功；锁 PID=编排器进程 PID）
主 md unchanged                                        — SHA256 before vs after 不变
```

**条件化期望**: `RUNTIME_ERROR|review stats/items 完整性失败后锁释放失败` 仅当 Release-LockSafely 失败时出现；正常期望不出现且 run.lock 已删除。若出现该输出且 run.lock 残留 → 记录实际行为，按 SKILL contract（保留锁供陈锁机制接管）判定，不判 FAIL（终态仍为 failed ×1）。

**判定规则**（Prompt §5/§6）:
- `RUN_STATUS|failed|` count = 1 且全部验证项满足 → T38-stats-items PASS
- count = 0（校验路径未命中，注入无效）→ FAIL + P1，须排查注入有效性（fixture stats.total=999 冲突 / 注入点错位）
- count = 2（出现第二个 RUN_STATUS，如落入 L490 JSON 校验失败路径）→ **FAIL + P1**（修复无效，行为链违反）
- SENTINEL 出现（return 未生效，执行继续）→ **FAIL + P1**
- 出现 REVIEW_WRITE_OK|（继续 review write）→ **FAIL + P1**

#### T38-A: review tmp 创建/写入失败（Prompt §7）

**目标**: SKILL L481 `Set-Content -Path $tmpPath -Encoding UTF8` 真实失败。

**构造方法**（sub-agent 选择其一，不得修改 SKILL）：
- 预创建 `result.review.tmp` 并以 `[System.IO.File]::Open()` 独占锁定（`FileShare::None`，`lock-holder.ps1` 后台持有），阻止 `Set-Content` 覆盖
- 或通过 ACL deny 拒绝当前用户对 `.monitor` 目录的 CreateFiles 权限
- **注意**：Windows `ReadOnly` 属性**不阻止**文件创建/覆盖，不可作为构造方法
- **ACL 方案前置断言**：ACL deny CreateFiles 仅阻止新文件创建，不阻止覆盖已存在文件。施加 ACL 前须确认 `result.review.tmp` 不存在（存在则先删除并记录），否则 Set-Content 覆盖成功 → 假阴性

**ACL 恢复步骤**（如使用 ACL 方案）:
1. 构造前记录 `.monitor` 目录原始 ACL：`Get-Acl $monitorDir | Export-Clixml T38-A/acl-before.xml`
2. 施加 deny 规则
3. 测试执行
4. 测试后还原：`Import-Clixml T38-A/acl-before.xml | Set-Acl $monitorDir`
5. 验证还原成功：`Get-Acl $monitorDir` 确认 deny 规则已移除

**验证项**:
```
REVIEW_WRITE_ERROR|                                    — 存在（tmp 写入失败消息）
RUN_STATUS|failed|                                     — count = 1
SENTINEL|AFTER_STEP4                                   — 不出现
no COMMIT_OK / no RUN_STATUS|success|
result.json unchanged / stats unchanged / items unchanged
主 md unchanged
```

**tmp 清理验证（按构造方法区分）**:
- ACL 方案：`result.review.tmp` 未创建，不存在
- 文件锁方案：catch 块执行 `Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue`（L483），外部进程持锁期间无法删除；**外部进程终止后**确认 tmp 已删除

#### T38-B: review JSON validation failure（Prompt §8）

**目标**: SKILL L490-491 `Get-Content $tmpPath -Raw|ConvertFrom-Json` 校验失败。

**构造方法**: 同进程注入（`t38-orchestrator-b.ps1`）——内联 Step 4，在 L489（第一个 try/catch 结束 `}`）与 L490（第二个 try 开始）之间注入 `Set-Content $tmpPath -Value '{invalid json' -Force`，使 tmp 写入成功但内容为非法 JSON。

**验证项**:
```
REVIEW_WRITE_ERROR|review 临时 JSON 校验失败            — count = 1
RUN_STATUS|failed|review 临时 JSON 校验失败             — count = 1
SENTINEL|AFTER_STEP4                                    — 不出现
no COMMIT_OK / no RUN_STATUS|success|
result.json unchanged
tmp cleaned                                              — result.review.tmp 不存在
lock released
不能继续执行到下一错误路径（无第二个 RUN_STATUS）
```

#### T38-C: review tmp → result.json atomic replacement failure（Prompt §9）

**目标**: SKILL L500 `Move-Item $tmpPath $resultPath -Force` 真实失败。

**构造方法**: 外部进程（`lock-holder.ps1`，`Start-Process -WindowStyle Hidden`）以 `FileShare::None` 锁住目标 `result.json`，使 Move-Item 无法替换；测试后终止持有进程。

**验证项**:
```
REVIEW_WRITE_ERROR|review 原子替换失败                  — count = 1
RUN_STATUS|failed|review 原子替换失败                   — count = 1
SENTINEL|AFTER_STEP4                                    — 不出现
no COMMIT_OK / no RUN_STATUS|success|
result.json unchanged（外部锁保护下未被替换）
tmp cleaned（外部进程终止后确认）
lock safe / lock released
```

#### T38-heartbeat: heartbeat 失败终态验证（Prompt §10）

**目标**: SKILL L477 heartbeat 失败路径。

**构造方法**: Step 3 执行后、Step 4 执行前，外部进程（`lock-holder.ps1`）以 `FileShare::None` 锁住 `run.lock` → Step 4 heartbeat 的 `[IO.File]::Open` 失败。

**验证项**:
```
RUNTIME_ERROR|步骤4 heartbeat 失败                      — 存在
RUN_STATUS|failed|步骤4 heartbeat 失败，整轮终止。      — count = 1
SENTINEL|AFTER_STEP4                                    — 不出现
no RUN_STATUS|success|
```

**条件化期望**: heartbeat 失败后直接 return（L477 catch），未调用 `Release-LockSafely`，锁状态 = 外部锁持有进程终止后 run.lock 文件仍存在（由 Step 1 创建、未被删除）。审查点根据实际输出判断，不假设锁已释放。

#### T38-result-read: result.json 读取失败终态验证（Prompt §11）

**目标**: SKILL L478 result.json 读取 try/catch。

**构造方法**: Step 3 执行后删除 `result.json`（使 L478 `Get-Content $resultPath -Raw` 抛 PathNotFound）；或外部进程独占锁住 result.json。

**验证项**:
```
RUNTIME_ERROR|读取 result.json 失败                     — 存在
RUN_STATUS|failed|读取 result.json 失败，整轮终止。     — count = 1
SENTINEL|AFTER_STEP4                                    — 不出现
lock released                                           — Release-LockSafely 被调用（锁 PID=编排器 PID）
no RUN_STATUS|success|
no REVIEW_WRITE_ERROR|（此路径不涉及 review tmp 写入）
```

#### §12 统一计数检查（Prompt §12）

对全部 6 个子测试，逐项分别统计（从各 stdout.txt 实际计数）：

```
T38-A / T38-B / T38-C / T38-heartbeat / T38-result-read / T38-stats-items
    × { RUN_STATUS|success| count
        RUN_STATUS|failed| count
        REVIEW_WRITE_ERROR count
        RUNTIME_ERROR count
        COMMIT_OK count }
```

统一要求：**每项 failed count = 1，success count = 0**；错误路径不能发生重复 final status。结果汇总为矩阵表 `t38-unified-count.md`（6 行 × 5 列 + 判定列）。

**证据要求**（每个 T38 子测试均需）:
```
T38-*/before/                       — fixture 与运行态前置快照
T38-*/after/
T38-*/stdout.txt                    — 编排器完整 stdout（含 SENTINEL 或其缺失）
T38-*/stderr.txt
T38-*/test-report.md                — 含构造方法记录、锁 PID 处理记录、计数结果
T38-*/result-before.json
T38-*/result-after.json
T38-*/md-before.md                  — 主 md before
T38-*/md-after.md
T38-*/sha256-before.txt             — 含 main md + result.json + tmp（如存在）SHA256
T38-*/sha256-after.txt
T38-*/lock-before.txt
T38-*/lock-after.txt
```

涉及 ACL 的测试额外需: `acl-before.xml`（+ 还原验证记录）
涉及文件锁的测试额外需: `lock-holder-stdout.txt` / `lock-holder-stderr.txt`

**输出结果**:
- `.production-validation-v111-final/T38-{A,B,C,heartbeat,result-read,stats-items}/` 目录及全部证据
- `.production-validation-v111-final/t38-unified-count.md`
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 逐个核验 6 个子测试 stdout.txt 中预期错误码存在且 `RUN_STATUS|failed|` count = 1、`RUN_STATUS|success|` count = 0
- [ ] 核验 T38-stats-items：`REVIEW_WRITE_ERROR|review 修改了 stats/items` ×1 + `RUN_STATUS|failed|review 程序事实完整性校验失败` ×1 + SENTINEL 不出现 + 无 REVIEW_WRITE_OK|
- [ ] 核验 SHA256 before/after 一致（result.json / 主 md unchanged）
- [ ] 核验 lock-after：T38-A/B/C/result-read/stats-items 锁已释放；T38-heartbeat 按条件化期望处理
- [ ] 核验 t38-unified-count.md 矩阵完整（6×5）且 failed 列全为 1、success 列全为 0
- [ ] 核验 sha256 文件覆盖 main md + result.json + tmp

**失败处理**: 任一子测试 FAIL → 立即标记 PRODUCTION_NOT_READY 倾向，但仍完成后续 Phase 保留完整证据（Prompt §5）。T38-stats-items FAIL 属 P1 硬门槛违反。如 harness 无法制造某种异常 → 标记 BLOCKED，不能推理 PASS（harness 修复按 §0.10 协议后重新执行）。

---

### Phase 3: T22/T23 — md tmp 写入/原子替换失败回归（硬门槛）

**前置条件**: Phase 1 完成，lib/step5-full.ps1 与编排器就绪

**输入参数**:
- 测试目录: `.production-validation-v111-final/T22/`, `T23/`
- 编排器: `lib/t22-orchestrator.ps1`, `lib/t23-orchestrator.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### T22 — md 临时文件写入失败（Prompt §13）

**目标**: SKILL Step 5 L591 `Set-Content -Path $tmp -Value $newText`（`GitHub更新监测列表.md.tmp` 写入）真实失败。

**构造方法**: 通过 ACL deny 拒绝当前用户对 `.output` 目录的 CreateFiles 权限。
- **注意 1**：Windows `ReadOnly` 属性不阻止文件创建，不可作为构造方法
- **注意 2**：`[System.IO.File]::Open()` 只能打开文件，目录不支持 FileShare 排他锁，不可作为构造方法
- **ACL 前置断言**：施加前确认 `GitHub更新监测列表.md.tmp` 不存在（存在则先删除并记录），否则 Set-Content 覆盖已存在文件将成功 → 假阴性

**ACL 恢复步骤**:
1. 构造前记录 `.output` 目录原始 ACL：`Get-Acl $outputDir | Export-Clixml T22/acl-before.xml`
2. 施加 deny 规则
3. 测试执行（编排器 try/finally 包裹）
4. 测试后还原：`Import-Clixml T22/acl-before.xml | Set-Acl $outputDir`
5. 验证还原成功：`Get-Acl $outputDir` 确认 deny 规则已移除

**验证项**（Prompt §13）:
```
主 md unchanged                       — SHA256 before vs after 不变
tmp cleanup                           — md.tmp 不残留（未创建）
lock released                         — run.lock 不存在（L596-604 锁释放，PID=编排器 PID）
RUN_STATUS|failed|主 md 未提交。      — count = 1
SENTINEL|AFTER_STEP5                  — 不出现（L607 return）
no COMMIT_OK / no RUN_STATUS|success|
```

#### T23 — md 原子替换失败（Prompt §14）

**目标**: SKILL Step 5 L626 `Move-Item -Path $tmp -Destination $md -Force` 真实失败。

**构造方法**: 外部进程（`lock-holder.ps1`）以 `FileShare::None` 锁住目标主 md，使 Move-Item 无法替换；测试后终止持有进程。

**验证项**（Prompt §14）:
```
主 md unchanged                       — SHA256 before vs after 不变（外部锁保护）
tmp cleaned                           — md.tmp 被清理（L630 Remove-Item；外部进程终止后确认）
lock released                         — run.lock 不存在
RUN_STATUS|failed|主 md 未提交。      — count = 1（L653）
SENTINEL|AFTER_STEP5                  — 出现（T23 路径无 return，走完锁释放+终态输出后自然结束）
COMMIT_OK absent
RUN_STATUS|success| absent
```

**证据要求**（T22/T23 均需）:
```
T2*/before/ / after/ / stdout.txt / stderr.txt / test-report.md
md-before.md / md-after.md
result-before.json / result-after.json
sha256-before.txt / sha256-after.txt   — 含 main md + result.json + tmp
lock-before.txt / lock-after.txt
```

涉及 ACL 额外需: `acl-before.xml`；涉及文件锁额外需: `lock-holder-stdout.txt` / `lock-holder-stderr.txt`

**输出结果**:
- `.production-validation-v111-final/T22/`、`T23/` 目录及全部证据
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 T22/T23 stdout 中 `RUN_STATUS|failed|` count = 1、`RUN_STATUS|success|` / `COMMIT_OK|` 不存在
- [ ] 核验 T22 SENTINEL 不出现 / T23 SENTINEL 出现（行为链区分）
- [ ] 核验 SHA256 before/after 一致（主 md unchanged）
- [ ] 核验 lock-after 确认锁已释放
- [ ] 核验 ACL 还原验证记录存在（T22）

**失败处理**: T22/T23 任一 FAIL → PRODUCTION_NOT_READY 倾向，仍完成后续 Phase 保留证据。

---

### Phase 4: T37 — 正常成功回归（硬门槛）

**前置条件**: Phase 1 完成，lib/step1-5.ps1 + run-full-pipeline.ps1 就绪

**输入参数**:
- 测试目录: `.production-validation-v111-final/T37/`
- 提取脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`
- fixture: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向 T37

**处理逻辑**:

#### T37 — 正常提交 → RUN_STATUS|success|（Prompt §15）

PowerShell 7.x 运行完整流程（Step 1→5 代码 + Step 6 汇报模板结构）。

**Fixture**: 至少 2 个真实仓库（如 `microsoft/vscode` localVer=1.0.0 + `torvalds/linux` localVer=6.5.0），确保能触发 review 的仓库。

**执行**（stdout 捕获策略，依据 Phase 1 `lib/stdout-verification.txt` 独立验证结果）：
- 透传正常 → `run-full-pipeline.ps1` 单次执行捕获 stdout
- 透传异常 → 逐 step 执行（`pwsh -File stepN.ps1 *>&1 > T37/stdout-stepN.txt`）+ 拼接；逐 step 间按 §0.5 锁 PID 一致性机制处理
- 实际采用方式及依据记录于 test-report.md

**验证项**（Prompt §15）:
```
BACKUP_OK|                  — 存在
FETCH_COMPLETE|             — 存在
SUMMARY|                    — 存在
REVIEW_WRITE_OK|            — 存在（仅当本轮触发 review 时；条件化期望）
COMMIT_OK|                  — 存在
RUN_STATUS|success|         — count = 1
RUN_STATUS|failed|          — count = 0
lock released               — run.lock 不存在
md updated                  — md-after 与 md-before 不同（版本号已刷新）
result.json valid           — JSON 结构完整、stats/items/review 字段存在
```

**硬门槛**: 出现 `COMMIT_OK|` + `RUN_STATUS|failed|` → FAIL + P1 + PRODUCTION_NOT_READY。

**证据要求**:
```
T37/before/ / after/
T37/stdout.txt              — 完整 stdout（单次执行或拼接）
T37/stdout-step1.txt ~ stdout-step5.txt   — 各 step 独立 stdout（仅当逐 step 方式时）
T37/stderr.txt / test-report.md
T37/md-before.md / md-after.md
T37/result-before.json / result-after.json
T37/sha256-before.txt / sha256-after.txt
T37/lock-before.txt / lock-after.txt
```

**输出结果**:
- `.production-validation-v111-final/T37/` 目录及全部证据
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 stdout 中 `BACKUP_OK|` → `FETCH_COMPLETE|` → `SUMMARY|` → `COMMIT_OK|` → `RUN_STATUS|success|` 完整链
- [ ] 核验 `RUN_STATUS|failed|` count = 0、`RUN_STATUS|success|` count = 1
- [ ] 核验 lock-after 确认锁已释放
- [ ] `REVIEW_WRITE_OK|` 为条件性检查（仅当 fixture 触发 review 时验证）

**失败处理**: T37 FAIL → PRODUCTION_NOT_READY，仍完成后续测试保留证据。

---

### Phase 5: T39 — Commit 成功 + 锁释放失败（硬门槛）

**前置条件**: Phase 1 完成，lib/step5-t39-harness.ps1 就绪

**输入参数**:
- 测试目录: `.production-validation-v111-final/T39/`
- harness: `lib/step5-t39-harness.ps1`（同进程）
- fixture: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向 T39

**处理逻辑**:

#### T39 — commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|（Prompt §16）

验证 v1.11 没有破坏 v1.10 已通过的 invariant。

**构造方法**（同进程 harness）：
1. 正常执行 Step 1→4（harness 内 `& step1..4`，同进程锁 PID 一致），确保 `result.json` 就绪
2. 执行内联 Step 5 代码至 Move-Item 成功 → `$commitSucceeded=$true`（L627）→ 输出 `COMMIT_OK|`
3. 在同进程中（L636/L637 之间注入）修改锁文件 PID 为 999999
4. 继续执行锁释放部分：锁内 PID (999999) ≠ 当前 PID → ownership 校验失败（L647-648）→ `$lockReleased=$false`
5. 最终判定（L650-653）：`$commitSucceeded=$true` AND `$lockReleased=$false` → `RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。`

> **设计说明**：`pwsh -File` 模式下每脚本独立进程，`$commitSucceeded` 等局部变量无法跨进程传递；dot-source step5-full 无注入点。唯一可行 = 同进程内联复制 + 精确注入（§0.7 进程模型声明）。

**验证项**（Prompt §16）:
```
COMMIT_OK|                  — 存在（提交本身成功）
RUNTIME_ERROR|释放锁前 ownership 校验失败... — 存在
RUN_STATUS|failed|          — count = 1
RUN_STATUS|success|         — count = 0
SENTINEL|AFTER_STEP5        — 出现（T39 失败终态后自然结束）
```

**核心 invariant 验证**: `commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|`（绝不输出 success）。

**证据要求**:
```
T39/before/ / after/ / stdout.txt / stderr.txt / test-report.md
T39/lock-before.txt           — 测试前锁状态
T39/lock-after-modify.txt     — PID 修改后、锁释放尝试前的锁状态
T39/lock-after.txt            — 最终锁状态（锁仍存在，未释放）
T39/result-before.json / result-after.json
T39/md-before.md / md-after.md
```

**输出结果**:
- `.production-validation-v111-final/T39/` 目录及全部证据
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 stdout 中 `COMMIT_OK|` 存在但 `RUN_STATUS|success|` 不存在
- [ ] 核验 `RUN_STATUS|failed|` count = 1
- [ ] 核验 lock-after-modify.txt 中 PID=999999
- [ ] 核验 lock-after.txt 确认锁仍存在（未释放）

**失败处理**: T39 FAIL → PRODUCTION_NOT_READY，仍完成后续测试保留证据。

---

### Phase 6: T43 + T46 — 全管线 + 路径契约（关键）

**前置条件**: Phase 1 完成

**输入参数**:
- 测试目录: `.production-validation-v111-final/T43/`, `T46/`
- 脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`, `lib/run-full-pipeline.ps1`, `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### T43 — Full Extended Pipeline Regression（Prompt §17）

建立全新 fixture。至少 6 个场景（除 404 外 repo 必须真实存在）：

```
normal upgrade      — 真实仓库，localVer 低于最新 release
synced              — 真实仓库，localVer 等于最新 release（动态查询）
uninstalled         — 真实仓库，localVer=未安装
unsupported version — 真实仓库，版本格式不可比较
404                 — 不存在的仓库
versionJump         — 真实仓库，版本跨越大（major 差 ≥2 或 minor 差 ≥10，动态查询）
```

**执行**: PS7 完整 Step 1→5 代码 + Step 6 汇报模板结构（stdout 捕获策略同 Phase 4）。

**验证项**（Prompt §17）:
```
BACKUP_OK| / FETCH_COMPLETE| / SUMMARY|
REVIEW_WRITE_OK|（有 review 时；条件化）
COMMIT_OK| / RUN_STATUS|success|
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
T43/before/ / after/ / stdout.txt / stderr.txt / test-report.md
T43/stdout-step1.txt ~ stdout-step5.txt（仅当逐 step 方式时）
T43/md-before.md / md-after.md
T43/result-before.json / result-after.json
```

#### T46 — .output State Path Regression（Prompt §18）

**运行目录**: `.production-validation-v111-final/T46/`（`GITHUB_VERSION_MONITOR_BASE` 指向此目录）

**验证项**（Prompt §18）:
```
.output/GitHub更新监测列表.md 是唯一生产状态文件
根目录不存在 GitHub更新监测列表.md
读取 .output/ 写回 .output/   — 由 T43 完整管线证据覆盖（T46 仅跑 Step 1+2，写回发生在 Step 5）
backup 基于 .output 状态文件  — 同上，由 T43 证据覆盖
```

**检查方法**: 运行 Step 1 + Step 2 后，检查 T46 测试目录根是否出现同名状态文件。出现 → FAIL + P1。"写回 .output/"与"backup 基于 .output"两个维度由 T43 完整管线（Step 1→5 全流程）证据覆盖，T46 不重复执行 Step 5。

**同时确认**（Prompt §17 尾部）：生产根目录 `d:\...\github-version-monitor\.output\GitHub更新监测列表.md` 才是生产状态路径（本轮全程通过 `GITHUB_VERSION_MONITOR_BASE` 隔离，生产文件 SHA256 收尾复核不变，Phase 12/13）。

**证据要求**:
```
T46/before/ / after/ / stdout.txt / stderr.txt / test-report.md
T46/md-before.md / md-after.md
T46/directory-listing.txt     — 测试目录完整清单
T46/root-md-check.txt         — 测试目录根无同名状态文件的核验记录
```

**输出结果**:
- `.production-validation-v111-final/T43/`、`T46/` 目录及全部证据
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 T43 stdout 中完整成功链 + `RUN_STATUS|success|` count = 1
- [ ] 核验 T43 数据一致性四项（result.json / md 表格 / backup / fetch_run.log）
- [ ] 核验 T46 directory-listing.txt 中测试目录根无 `GitHub更新监测列表.md`

**失败处理**: T43/T46 FAIL → 记录并继续（关键优先级），但 T43/T46 在 Production Gate 清单中（§34），FAIL 即终态 NOT_READY。

---

### Phase 7: Runtime Artifact Initialization（硬门槛，Prompt §24）

**前置条件**: Phase 1 完成，lib/runtime-artifact-pipeline.ps1 + watch-dir.ps1 就绪

**输入参数**:
- 测试目录: `.production-validation-v111-final/runtime-artifact/`（全新 base 目录）
- 管线: `lib/runtime-artifact-pipeline.ps1`（单进程 `& step1..5` + step 间快照）
- 监视: `lib/watch-dir.ps1`
- fixture: `lib/create-fixture.ps1`（含 1 个触发 review=true 的项，使 Step 4 review 通道真实走通）

**处理逻辑**（Prompt §24，"这是之前的历史验证缺口，本轮必须保留真实证据"）：

1. **前置断言**：`Test-Path <base>\.monitor` = False（.monitor 不存在，记录证据 `monitor-absent-before.txt`）。**禁止预创建 `.monitor`**（不得由测试 harness 预先创建来掩盖 Skill 的初始化逻辑）

2. **单进程管线执行 + step 间快照**（快照 = 只读记录 .monitor 目录清单 + 关键文件内容，不修改任何状态）：
   - Step 1 前快照 S0：.monitor 不存在
   - Step 1 后快照 S1：`.monitor/` 已创建（SKILL L174 New-Item）；`run.lock` 存在且内容含 `pid=`/`start=`/`step=1`/`beat=`（L194-199）；`backups/` 目录存在（L226-227）且含 1 个 `GitHub更新监测列表.backup.<ts>.md`（L229）
   - Step 2 后快照 S2：`result.json` 存在且为 valid JSON（含 runAt/stats/items/review 字段，L397-400）；`fetch_run.log` 存在且含日志行（内容含 `items=`/`apiOK=`，L415-418）；`run.lock` 仍存在（heartbeat 刷新）
   - Step 3 后快照 S3：`backups/` 保留；trash 逻辑不破坏现有备份
   - Step 4 执行（fixture 含 review=true 项，review 通道真实执行）：执行前启动 `watch-dir.ps1` 后台监视进程（50ms 轮询 .monitor 目录，记录观察到的文件名序列）
   - Step 4 后快照 S4：`result.json` 的 `review.performed = true`（review 结构化写回生效）
   - Step 5 后快照 S5：**`run.lock` 不存在**（Prompt §24 关键终态："正常结束 run.lock 不存在"）；主 md 已更新

3. **result.review.tmp 真实出现验证**（Prompt §24"涉及 review 时 result.review.tmp 真实出现"）：
   - 主证据：watch-dir 监视记录中捕获 `result.review.tmp` 文件名（Step 4 执行窗口内）
   - **条件化补充**（仅当监视轮询错过瞬时窗口时）：以 T38-B harness 的注入篡改成功（能对 tmp 文件 Set-Content 即证明该文件在 L481-L500 之间真实存在）+ S4 的 `review.performed=true` 作为证据链，并在 test-report.md 声明监视未捕获的原因
   - 附带核对：Step 4 正常结束后 `result.review.tmp` 不残留（Move-Item 原子替换后 tmp 消失）

**验证项汇总**:
```
S0: .monitor 不存在（前置断言）
S1: .monitor/ + run.lock（内容契约）+ backups/<1 个备份>
S2: result.json（valid，4 字段）+ fetch_run.log（≥1 行）
S3: backups 保留
S4: review.performed=true + result.review.tmp 生命周期证据
S5: run.lock 不存在 + md updated
全程: 快照链完整保存于 runtime-artifact/snapshots/
```

**证据要求**:
```
runtime-artifact/monitor-absent-before.txt
runtime-artifact/snapshots/S0.txt ~ S5.txt     — 各 step 后 .monitor 清单 + 关键文件内容
runtime-artifact/watch-log.txt                 — 监视进程记录
runtime-artifact/stdout.txt / stderr.txt / test-report.md
runtime-artifact/md-before.md / md-after.md
runtime-artifact/result-after.json
```

**输出结果**:
- `.production-validation-v111-final/runtime-artifact/` 目录及全部证据
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 monitor-absent-before.txt 确认 .monitor 测试前不存在
- [ ] 核验 S1-S5 快照链逐项与验证项清单一致（run.lock 内容契约 / result.json 4 字段 / fetch_run.log 日志行）
- [ ] 核验 S5 中 run.lock 不存在
- [ ] 核验 result.review.tmp 出现证据（监视捕获 或 条件化补充链 + 声明）
- [ ] 核验无 harness 预创建 .monitor 的痕迹（快照 S0 与编排器代码双重确认）

**失败处理**: 任一快照验证项不满足 → Runtime artifact initialization FAIL（Production Gate 清单项）→ PRODUCTION_NOT_READY 倾向，仍完成后续 Phase 保留证据。监视进程未捕获 tmp 且 T38-B 证据链可用 → 不判 FAIL，按条件化补充处理。

---

### Phase 8: T04-PS7 + T26 + T18 — 状态机 + Flag + 状态保留（中）

**前置条件**: Phase 1 完成，mock 工具就绪

**输入参数**:
- 测试目录: `.production-validation-v111-final/T04-PS7/`, `T26/`, `T18/`
- 脚本: `lib/step2.ps1`, `lib/mock-invoke-restmethod.ps1`, `lib/step2-mock-harness.ps1`
- fixture: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### 8.1 T04-PS7 — rate_limited Regression（Prompt §19）

PowerShell 7（mock 403 + `X-RateLimit-Remaining=0`）：

```
必须: rate_limited
请求计数: latest=1 / review API=0 / HTML=0 / retry=0
```

**请求计数验证**：mock harness 统计 Invoke-RestMethod 调用次数（按 URI 分类：`releases/latest` =1；`/releases?per_page` =0；`Invoke-WebRequest` HTML =0），retry=0（无重试调用）。

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / mock 场景记录（HTTP status + header）/ request-count.txt

#### 8.2 T26 — Strict Flag Regression（Prompt §21）

| 输入 | 期望 |
|---|---|
| `yes`（小写） | 有效 |
| `no`（小写） | 有效 |
| `YES` / `Yes` / `yEs` / `NO` / `No` / `pending` / `true` | `PARSE_ERROR|` |

共 9 项输入（2 合法 + 7 非法）。验证：非法输入时 main md unchanged + lock released。

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / `md-before.md` / `md-after.md` / `sha256-before.txt` / `sha256-after.txt`

#### 8.3 T18 — State Preservation Regression（Prompt §22）

至少验证 9 种非 ok 状态（SKILL-v1.11 状态机，L130-141 状态表 + L361-367 代码分支，完整枚举）：

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

一般失败状态（除 not_found 外 8 种）：
```
gitVer unchanged / gitDate unchanged / flag unchanged
```

not_found：
```
gitVer="" / gitDate="" / flag=prevFlag / review=true
```

**证据**: 每种状态独立子目录（9 种 × before/after + stdout/test-report）

> **PS7 forbidden 判定覆盖说明**：v1.11 Prompt §19-§22 未要求独立的 T05-PS7（其 §37 摘要模板亦无此项）。PS7 侧 forbidden（403+remaining>0）状态机判定由 T18-forbidden 场景覆盖（同 mock 场景，T18 侧重状态保留）。最终报告 O 节如实说明覆盖方式，不虚构 T05-PS7 条目。

**输出结果**:
- 各测试子目录及全部证据
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 T04-PS7 stdout 中 `rate_limited` 存在且 request-count.txt 显示 latest=1/review API=0/HTML=0/retry=0
- [ ] 核验 T26 的 9 项输入测试结果（2 合法 + 7 PARSE_ERROR）
- [ ] 核验 T18 的 9 种状态保留测试结果（8 种 unchanged + not_found 特殊语义）

**失败处理**: 记录并继续（中优先级）；但 T04-PS7/T26/T18 均在 Production Gate 清单（§34），FAIL 即终态 NOT_READY。

---

### Phase 9: PS5.1 兼容性回归（兼容）

**前置条件**: Phase 1 完成，mock 工具就绪（PS5.1 兼容语法）

**输入参数**:
- 测试目录: `.production-validation-v111-final/T04-PS5.1/`, `T05-PS5.1/`
- 脚本: `lib/mock-invoke-restmethod.ps1`, `lib/step2-mock-harness.ps1`
- PS5.1 路径: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**（Prompt §20，"如果 PS5.1 存在"）：

#### T04-PS5.1
```
403 + remaining=0 → rate_limited
```

#### T05-PS5.1
```
403 + remaining>0 → forbidden
```

验证 `Get-ResponseHeaderValue`（SKILL L324-330 区域，以实际提取为准）在 `System.Net.WebHeaderCollection` 上的行为。使用 `powershell.exe -NoProfile -NonInteractive -File` 运行 mock harness。

PS5.1 不得阻塞 PS7 production gate（Prompt §20：PS5.1 仅做兼容性回归）。

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / HTTP status / header metadata

**输出结果**:
- `.production-validation-v111-final/T04-PS5.1/`、`T05-PS5.1/` 目录及全部证据
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 PS5.1 可用性（`powershell.exe` 存在；不存在则两项标 BLOCKED 并在报告 K 节声明）
- [ ] 核验 T04-PS5.1 → rate_limited、T05-PS5.1 → forbidden
- [ ] PS5.1 FAIL 仅记录 compatibility FAIL，不阻塞 PS7 production gate（双维度计数，§6.3）

**失败处理**: PS5.1 FAIL → 记录 compatibility FAIL，不阻断后续 Phase。

---

### Phase 10: Lock 回归 + Process Kill（中）

**前置条件**: Phase 1 完成

**输入参数**:
- 测试目录: `.production-validation-v111-final/lock-*/`, `process-kill/`
- 脚本: `lib/step1.ps1`, `lib/lock-holder.ps1`, `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### 10.1 Lock Regression（Prompt §23）

| 测试 | 验证内容 | 构造方法 | 期望 |
|---|---|---|---|
| lock-concurrency | 两进程争锁 | 两个 pwsh 后台进程（`Start-Process -WindowStyle Hidden`）同时执行 Step 1 | one owner（BACKUP_OK\|）+ one `LOCKED\|` |
| lock-ownership | 外来 PID | 锁文件 PID 改为不匹配值（如 999999），执行锁释放相关路径（Step 5 尾段或 T39 场景复用） | `RUNTIME_ERROR\|` + **foreign lock retained（不得删除 foreign lock）** |
| lock-stale-alive | 陈锁 + PID 活 | 锁文件 heartbeat 时间戳设为 31 分钟前，PID 设为存活进程（当前 pwsh PID） | `LOCKED\|`（保守不抢） |
| lock-stale-dead | 陈锁 + PID 死 | 锁文件 heartbeat 设为 31 分钟前，PID 设为不存在进程（999999） | takeover 成功，以 `BACKUP_OK\|` 为判定标记 |

**Prompt §23 特别三项**（与已有测试证据映射）：
- 一次正常 success → lock released：由 T37（Phase 4）lock-after 证据覆盖
- 一次 failure → lock safe：由 T38-A/B/C/result-read/stats-items + T22（Phase 2/3）lock-after 证据覆盖
- foreign ownership → 不得删除 foreign lock：由 lock-ownership 测试 + T39（Phase 5）lock-after 证据覆盖

要求与 v1.10 已验证行为一致（本轮重新执行留证，不继承旧 PASS）。

**证据**: 各子目录 `stdout.txt` / `stderr.txt` / `test-report.md` / `lock-before.txt` / `lock-after.txt`

#### 10.2 Process Kill Regression（Prompt §25）

至少一次，PowerShell 7.x，在 **Step 2 / Step 4 / Step 5** 至少一个实际执行点杀进程（v1.11 Prompt §25 明确清单；推荐 Step 4 执行期间）。

**构造方法**:
1. 启动完整管线后台运行（`Start-Process -WindowStyle Hidden pwsh -File run-full-pipeline.ps1`）
2. 在目标 Step 执行期间 `Stop-Process` 终止（时点判定：监视 .monitor 状态变化或 stdout 增量，如 Step 4 的 result.review.tmp 出现窗口）
3. 记录被杀时状态（lock-before / md / result.json 快照）
4. 重新运行一轮，验证：

```
lock         — 不出现锁滞留（或按陈锁机制接管：stale/dead lock takeover 验证）
backup       — 不得出现损坏的 backup
result.json  — 不得出现损坏的 result.json
main md      — 不得出现错误提交
```

**证据**: `process-kill/` 目录 `stdout.txt` / `stderr.txt` / `test-report.md` / `lock-before.txt` / `lock-after.txt` / `md-before.md` / `md-after.md` / `result-before.json` / `result-after.json` / 重运行 stdout

**输出结果**:
- 各测试子目录及全部证据
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 lock 4 项测试结果（concurrency / ownership / stale-alive / stale-dead）
- [ ] 核验 lock-ownership 的 foreign lock retained（lock-after.txt 确认外来锁未被删除）
- [ ] 核验 process-kill 在 Step 2/4/5 之一的实际执行点终止（时点证据）+ 重运行四项无损坏

**失败处理**: 记录并继续（中优先级）。

---

### Phase 11: Early Return Audit + Final Status Uniqueness + Invariant Verification（关键）

**前置条件**: Phase 1-10 全部完成，全部证据可用

**输入参数**:
- SKILL-v1.11.md 全文
- 全部前序 Phase 证据

**处理逻辑**:

#### 11.1 Early Return Audit（Prompt §26）

扫描 `SKILL-v1.11.md` 所有 `return`（Select-String 完整枚举，不遗漏），逐个分类：

```
正常控制流 return（如 STATE_MISSING / LOCKED 保守退出等非错误路径）
函数 return（如 Release-LockSafely 返回值路径）
fatal return（错误路径终止）
```

对于每个 **fatal return**，必须确认：terminal status already emitted **exactly once**（该 return 之前恰好输出一次最终状态标记）。

重点覆盖 Step 1-5 **全部** return（**不能只检查本次修复的 L480**，Prompt §26 明确）。制定时初扫框架（执行时须以完整枚举为准并逐一复核）：

| 位置 | 类型 | terminal status |
|---|---|---|
| Step 1 L172（STATE_MISSING） | 正常控制流 | `STATE_MISSING\|`（非 RUN_STATUS 契约路径） |
| Step 1 L222（LOCKED） | 正常控制流 | `LOCKED\|` |
| Step 2 L406（fetch tmp 校验失败） | fatal | `RUNTIME_ERROR\|`（L404）— **审计点：此路径是否缺 RUN_STATUS 终态**（按 SKILL 实际 contract 如实判定并记录） |
| Step 2 L412（result.json 替换失败） | fatal | `RUNTIME_ERROR\|`（L410）— 同上 |
| Step 3 L444（heartbeat 失败） | fatal | `RUNTIME_ERROR\|` — 同上 |
| Step 4 L477（heartbeat） | fatal | `RUN_STATUS\|failed\|` ×1 |
| Step 4 L478（result-read） | fatal | `RUNTIME_ERROR\|` + `RUN_STATUS\|failed\|` ×1 |
| Step 4 L480（stats/items，**v1.11 修复**） | fatal | `REVIEW_WRITE_ERROR\|` + `RUN_STATUS\|failed\|` ×1 + return |
| Step 4 L487/L496/L506（tmp 写入/JSON 校验/原子替换） | fatal | `REVIEW_WRITE_ERROR\|` + `RUN_STATUS\|failed\|` ×1 |
| Step 5 L607（md tmp 失败） | fatal | `RUN_STATUS\|failed\|主 md 未提交。` ×1 |
| Step 5 尾段（无 return，三分支终态） | — | L651 success / L649 + L653 failed |

> 上表为制定时基于直接阅读的初扫框架（行号经 Select-String 核实）；Phase 11 执行时须以完整枚举为准，每个 fatal return 的 "exactly once" 结论须引用行号 + 对应输出语句。

**输出**: `.production-validation-v111-final/audit/early-return-final-status-audit.md`

#### 11.2 Final Status Uniqueness Audit（Prompt §27）

对所有 fatal test（T38 六子测试 + T22 + T23 + T39 + lock-ownership + process-kill 重运行），逐项统计 stdout 中 `RUN_STATUS|success|` 与 `RUN_STATUS|failed|` 总数。

规则（Prompt §27）：
```
正常 success：success=1, failed=0
失败：success=0, failed=1

success>1 / failed>1 / success+failed != 1 → FAIL + P1
```

**输出**: `.production-validation-v111-final/audit/final-status-uniqueness-audit.md`（矩阵：每个 fatal test × success count / failed count / 判定）

#### 11.3 Invariant Verification（Prompt §28 + §32 报告 I 节）

以实际测试证据映射验证以下 invariant（每项指认 Prompt 节号 + 证据文件）：

```
I1: atomic md replacement success → commitSucceeded=true（Prompt §15；T37/T43 COMMIT_OK 证据）
I2: commitSucceeded=true + lockReleased=true → RUN_STATUS|success|（Prompt §15；T37/T43）
I3: commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|（Prompt §16；T39）
I4: review write failure → no md commit（Prompt §7-§9；T38-A/B/C/stats-items 主 md unchanged）
I5: review write failure → RUN_STATUS|failed|（Prompt §7-§9；T38 全部）
I6: md replacement failure → main md unchanged（Prompt §14；T23）
I7: 任何 fatal 路径 → RUN_STATUS 唯一终态（Prompt §27/§39；Phase 11.2 全矩阵）
```

> I1-I7 的验证依据来自前序 Phase 的实际执行证据，本 Phase 做证据汇总与一致性核对，不重新运行。

**Structural diff + Behavioral regression 双确认**（Prompt §28）：diff integrity（Phase 1）为结构面，T37/T38/T39/T43（Phase 4/2/5/6）为行为面——"代码关键词仍存在"不能证明行为没有回归，两者必须同时成立。

**输出结果**:
- `.production-validation-v111-final/audit/early-return-final-status-audit.md`
- `.production-validation-v111-final/audit/final-status-uniqueness-audit.md`
- `.production-validation-v111-final/audit/invariant-verification.md`
- `.production-validation-v111-final/phase-progress.json`

**证据要求**:
- `.production-validation-v111-final/phase11-stdout.txt` / `phase11-stderr.txt` / `phase11-report.md`

**主 agent 审查点**:
- [ ] 核验 early-return-final-status-audit.md 覆盖 Step 1-5 所有 `return`（枚举计数与 Select-String 结果一致）
- [ ] 核验每个 fatal return 有 "exactly once" 结论 + 行号引用；L480 修复路径被确认
- [ ] 核验 final-status-uniqueness-audit.md 矩阵覆盖全部 fatal test 且无违反规则项
- [ ] 核验 invariant-verification.md 中 I1-I7 逐项有证据指向
- [ ] 核验 Step 2/Step 3 的 RUNTIME_ERROR 路径（L404/L410/L444）审计结论如实记录（如发现缺 RUN_STATUS 终态，按 contract 判定并记录，不隐瞒）

**失败处理**: 静态审计发现未覆盖的 return 路径 → 补充枚举后重审；发现 terminal status 缺失/重复 → 记录为 P1 发现；invariant 验证发现矛盾 → 记录并继续。

---

### Phase 12: Self-Review（质量控制，Prompt §31）

**前置条件**: Phase 0-11 全部完成，全部证据可用

**输入参数**:
- 全部 Phase 0-11 证据
- SKILL-v1.11.md 原文
- Phase 0 SHA256 基线

**处理逻辑**:

独立 self-review。**文件名必须带实际时间戳**（Prompt §31）：`.selfreview/selfreview-v111-YYYYMMDD-HHMMSS.md`（执行时以实际时间生成）。

**Prompt §31 固定 15 项检查**：

```
1.  被测对象是否真实为 v1.11         — 重算 SHA256 与 v111.sha256 比对
2.  SHA256 是否一致                   — v110/v111/state 三指纹重算比对
3.  是否修改过 v1.11                  — git status SKILL-v1.11.md 确认无修改
4.  是否复用了旧 PASS                 — 证据目录路径均在本轮 .production-validation-v111-final/ 下
5.  T38-stats-items 是否真实命中      — stdout 中 REVIEW_WRITE_ERROR + RUN_STATUS|failed| 确认
6.  RUN_STATUS|failed| 是否恰好一次   — T38 六子测试逐个计数复核
7.  T22/T23/T37/T39/T43 是否重新执行  — 证据文件时间戳与内容为本轮新建
8.  .monitor 是否由 SKILL 自己创建    — Phase 7 S0-S1 快照链复核
9.  .output path 是否正确             — T46/T43 证据复核
10. 是否存在证据与结论矛盾            — 实际输出 vs 报告结论逐项核对
11. 是否存在 FAIL 被改写为 BLOCKED    — 同上
12. 是否存在 BLOCKED 被改写为 PASS    — 同上
13. diff 是否包含非预期删除           — 重算 v110/v111 SHA256 与基线比对；复核 v110-v111.diff hunk 数
14. early-return audit 是否完成       — Phase 11 产出覆盖所有 return
15. final-status uniqueness audit 是否完成 — Phase 11 产出矩阵完整
```

**模板补充 4 项**：

```
16. 操作对象是否被修改               — 重算指纹与基线比对（含 state.sha256 生产状态文件）
17. 输入/fixture 是否正确            — 逐项核实存在性与内容（本轮新建，非旧目录复制）
18. 派生物是否被修改导致假结果       — 按 extraction-manifest.json 重算指纹；注入类 harness 做受限 diff
    （T39: 仅 L636/L637 间 PID 注入；T38-B: 仅 L489/L490 间 tmp 篡改；
     T38-stats-items: 仅 L479/L480 间 stats 篡改；其余代码逐字一致）
19. 基线对象完整性                   — 重算 3 个 SHA256 与开工基线比对
```

共 **19 项**（15 Prompt + 4 模板）。

**证据要求**:
- `.production-validation-v111-final/phase12-stdout.txt` / `phase12-stderr.txt` / `phase12-report.md`

**输出结果**:
- `.production-validation-v111-final/.selfreview/selfreview-v111-<实际时间戳>.md`
- `.production-validation-v111-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 self-review 19 项检查全部完成（15+4）
- [ ] 核验 SKILL-v1.11.md SHA256 与 Phase 0 基线一致（未被修改）
- [ ] 核验 `EXECUTED = PASS + FAIL + BLOCKED` 守恒式成立
- [ ] 核验无 BLOCKED 被改写为 PASS、无 FAIL 被改写为 BLOCKED
- [ ] 核验 self-review 文件名带实际时间戳

**失败处理**: self-review 发现问题 → 记录为发现项，不自动修复；严重问题（如被测对象被修改）→ 立即中止并标 BLOCKED。

---

### Phase 13: Final Report + Commit（收尾）

**前置条件**: Phase 0-12 全部完成

**输入参数**:
- 全部 Phase 0-12 证据
- self-review 报告

**处理逻辑**:

#### 13.1 生成最终报告（Prompt §32，章节固定 A-P 共 16 章）

生成 `production-validation-report-v111-final.md`：

```
A. Environment
B. Version / SHA256
C. v1.10 → v1.11 Diff Integrity
D. T38 Detailed Validation（六子测试逐一 + 统一计数矩阵）
E. Targeted Regression Summary（T22/T23/T37/T39/T43/T46/T04/T26/T18）
F. Runtime Artifact Validation（Phase 7 快照链）
G. Final Status Uniqueness Audit
H. Early Return Audit
I. Invariant Verification（I1-I7）
J. PS7 Production Assessment
K. PS5.1 Compatibility Assessment
L. Self-Review
M. Evidence Index
N. Production Gate
O. Execution Summary
P. Remaining Limitations
```

#### 13.2 最终计数（Prompt §33，不预设总数）

按实际执行统计：
```
EXECUTED = / PASS = / FAIL = / BLOCKED =
必须: PASS + FAIL + BLOCKED = EXECUTED
每个测试项目只能有一个最终状态
```

#### 13.3 Production Gate（Prompt §34-§36）

**PRODUCTION_READY** 必须同时满足：
```
P0 = 0 / P1 = 0 / FAIL = 0 / BLOCKED = 0

T38-stats-items = PASS（硬门槛：RUN_STATUS|failed| count = 1）
T22 = PASS / T23 = PASS / T37 = PASS / T39 = PASS
T43 = PASS / T46 = PASS
T04-PS7 = PASS / T26 = PASS / T18 = PASS

Runtime artifact initialization = PASS
Early Return Audit = PASS
Final Status Uniqueness Audit = PASS
Diff Integrity = PASS
Self-Review = PASS
```
（T38-A/B/C/heartbeat/result-read 虽未在 §34 清单单独点名，但属 §12 统一检查必测项，任一 FAIL 即 FAIL>0 → NOT_READY）

**PRODUCTION_NOT_READY**（Prompt §35）：任意 `P0 > 0 / P1 > 0 / FAIL > 0`。尤其：RUN_STATUS 重复 / RUN_STATUS 缺失 / 正常成功输出 failed / 失败路径输出 success → 全部至少 P1。

**PRODUCTION_BLOCKED**（Prompt §36）：仅当 `P0 = 0 / P1 = 0 / FAIL = 0 / BLOCKED > 0`。

**判定规则**：
1. 双维度计数：production-critical（PS7）vs compatibility（PS5.1）。PS5.1 FAIL 仅记录 compatibility FAIL，不阻塞 PS7 production gate（Prompt §20 "PS5.1 不得阻塞 PS7 production gate"与 §35 "FAIL>0 即 NOT_READY"的规则冲突按此维度裁决）。
2. FAIL 不得改写为 BLOCKED；BLOCKED 不得改写为 PASS；旧证据不得冒充新证据。

#### 13.4 最终执行摘要（Prompt §37，逐项映射）

报告必须明确（每项映射到计划实际安排的工作；未安排项显式声明依据，不留空不编造）：

```
PS7 available: / PS7 executed:
PS5.1 available: / PS5.1 executed:

T38-stats-items: / T38-A: / T38-B: / T38-C:
T38-heartbeat: / T38-result-read:

T22: / T23: / T37: / T39: / T43: / T46:

T04-PS7: / T04-PS5.1: / T05-PS5.1:

T26: / T18:

lock regression: / process kill:
.monitor initialization: / .output path:
early-return audit: / final-status uniqueness audit:
diff integrity: / self-review:
```

#### 13.5 Final Output（Prompt §38）

最后输出：

```
VERSION: v1.11

EXECUTED: N
PASS: N
FAIL: N
BLOCKED: N

P0: N
P1: N
P2: N

PRIMARY_RUNTIME: PowerShell 7.x

PRODUCTION_GATE: OPEN | CLOSED

FINAL_VERDICT:
PRODUCTION_READY | PRODUCTION_NOT_READY | PRODUCTION_BLOCKED

REPORT:
<production-validation-report-v111-final.md>
```

> PRODUCTION_GATE 语义：PRODUCTION_READY → OPEN；PRODUCTION_NOT_READY / PRODUCTION_BLOCKED → CLOSED。

#### 13.6 收尾动作

1. 汇总全部证据，生成最终报告
2. 基线对象完整性复核（SHA256 比对：SKILL-v1.11.md / SKILL-v1.10.md / 生产状态文件 开工 vs 收尾）
3. 入库 commit（文件范围显式列出）：
   - `SKILL-v1.11.md` + `.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md`（Phase 0 staged）
   - `.production-validation-v111-final/` 全部证据目录（含 task-tracker.md、t38-unified-count.md、audit/、.selfreview/）
   - `.exec-plan/exec-plan-v1.11-a.md`（本执行计划）
   - `production-validation-report-v111-final.md`
   - commit message 必含：终态判定、分类计数、P0/P1/P2 计数、新增发现、新增证据路径
4. 环境还原确认（ACL 还原验证记录、文件锁/监视进程终止确认、临时状态清理）

**输出结果**:
- `.production-validation-v111-final/production-validation-report-v111-final.md`
- `.production-validation-v111-final/phase-progress.json`
- git commit（文件范围显式列出）

**主 agent 审查点**:
- [ ] 核验最终报告包含 A-P 全部 16 个章节
- [ ] 核验 `PASS + FAIL + BLOCKED = EXECUTED` 守恒式成立
- [ ] 核验 Production Gate 判定与测试结果一致（§34 清单逐项核对）
- [ ] 核验最终执行摘要模板每一项映射到实际工作（无留空无编造）
- [ ] 核验 SKILL-v1.11.md SHA256 收尾与开工一致（生产状态文件同）
- [ ] 核验 Final Output 格式与 Prompt §38 一致
- [ ] 核验 commit 文件范围与计划声明一致

**失败处理**: 报告生成失败 → 检查证据完整性后重试；commit 失败 → 检查 git 状态后重试。

---

## 3. 禁止事项

```text
1.  禁止修改 SKILL-v1.11.md（被测对象）
2.  禁止触碰 .output/GitHub更新监测列表.md（生产状态文件）— 用 GITHUB_VERSION_MONITOR_BASE 隔离
3.  禁止复用 .production-validation-v110-final/ / .production-validation-v19-final/ 及其他历史
    validation 目录中的旧产物作为本轮 PASS 证据
4.  禁止修改上游事实源文件（.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md）
5.  禁止输出 GITHUB_TOKEN / Authorization / Cookie / 完整 secrets
6.  禁止为使任务通过而修改被测 SKILL
7.  禁止多 sub-agent 并行执行
8.  禁止 Verdict/结论由预期结果而非实际证据决定
9.  禁止将 BLOCKED 改写为 PASS
10. 禁止将 FAIL 改写为 BLOCKED
11. 禁止继承旧 PASS 作为本轮 PASS（OLD_EVIDENCE_USED_AS_CURRENT_PASS = NO）
12. 禁止由测试 harness 预先创建 .monitor（掩盖 Skill 初始化逻辑，Prompt §24）
13. 禁止修改测试逻辑掩盖失败（Prompt 开篇三条禁令）
14. 禁止修改 harness 后不重新执行受影响测试而重标 PASS（Prompt §30）
15. 禁止用"能力关键词仍存在"替代行为判断（Prompt §4/§28）
```

---

## 4. 证据规则（Prompt §29）

| 情形 | 至少留存 |
|---|---|
| 每项测试 | stdout.txt、stderr.txt、test-report.md |
| 涉及状态 | md-before.md、md-after.md、result-before.json、result-after.json、lock-before.txt、lock-after.txt |
| 涉及 atomicity | sha256-before.txt、sha256-after.txt（写明覆盖对象：main md + result.json + tmp） |
| 涉及 API | status、relevant headers、request count |
| 涉及 ACL 变更 | 变更前快照（acl-before.xml）+ 还原后验证记录 |
| 涉及外部锁进程 | lock-holder-stdout.txt / lock-holder-stderr.txt |

**禁止保存**：`GITHUB_TOKEN` / `Authorization` / `Cookie` / 完整 secrets。

---

## 5. 可追溯性机制

### 5.1 指纹与清单

1. **开工基线**：Phase 0 采集 `SKILL-v1.11.md` / `SKILL-v1.10.md` / `.output/GitHub更新监测列表.md` 的 SHA256 指纹。
2. **每个采集物必须有消费者**：Phase 0 的 3 个 SHA256 在 Phase 12 self-review 第 1/2/13/16/19 项复核比对；Phase 1 的 `extraction-manifest.json` 在 Phase 12 第 18 项复核。
3. **派生物必须有 manifest**：`lib/*.ps1` 提取脚本在 Phase 1 生成 `extraction-manifest.json`（源指纹 + 行号范围 + 派生物指纹）；Phase 12 复核时按 manifest 重算。注入类派生物（`step5-t39-harness.ps1`、t38-orchestrator-b / t38-orchestrator-stats-items 内联代码）做**受限 diff**：与源原文对照，仅允许计划声明的注入差异（Phase 1 Step 6 三处注入点）。
4. **stdout 透传独立验证**：Phase 1 独立验证 `run-full-pipeline.ps1` 的 stdout 透传行为（`lib/stdout-verification.txt`），不依赖旧报告声明。

### 5.2 口径与引用规则

1. 所有数量词（"30 项""9 项""9 种""6 场景""6 子测试""19 项"）必须能指认事实源出处；枚举类判断必须读取完整原文表格后列全项。
2. 旧报告/旧轮次结论只作信息参考；作设计依据前必须本轮独立验证并留存验证证据。
3. 引用其他章节/文档的规则，修改时全文搜索所有引用点同步更新。
4. 计划与上游文档的格式要求冲突时，保持上游字面格式、以附注形式补充信息，并在修订日志声明该偏离。

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
3. 硬门槛 Phase 未通过 → 触发最终判定规则（但仍完成后续 Phase 保留完整证据，除非失败处理声明立即中止）。
4. **数字一致性**：所有计数类结论必须满足守恒式（`EXECUTED = PASS + FAIL + BLOCKED`）；计划中同一数字只允许一个权威出处（优先引用清单，而非手抄数字）。

### 6.3 最终判定逻辑

**PRODUCTION_READY** 必须同时满足（Prompt §34 完整清单）：

```
P0 = 0 / P1 = 0 / FAIL = 0 / BLOCKED = 0

T38-stats-items = PASS（RUN_STATUS|failed| count = 1 硬门槛）
T22 = PASS / T23 = PASS / T37 = PASS / T39 = PASS
T43 = PASS / T46 = PASS
T04-PS7 = PASS / T26 = PASS / T18 = PASS

Runtime artifact initialization = PASS
Early Return Audit = PASS
Final Status Uniqueness Audit = PASS
Diff Integrity = PASS
Self-Review = PASS
（T38-A/B/C/heartbeat/result-read 经 §12 统一检查全部 PASS，任一 FAIL → FAIL>0 → NOT_READY）
```

**PRODUCTION_NOT_READY**：任意 `P0 > 0 / P1 > 0 / FAIL > 0`，尤其 T38 任一子测试 FAIL / RUN_STATUS terminal state missing / RUN_STATUS 重复 / 主 md 被错误修改 / lock ownership 错误 / 数据损坏（Prompt §35）。

**PRODUCTION_BLOCKED**：仅当 `P0 = 0 / P1 = 0 / FAIL = 0 / BLOCKED > 0`（Prompt §36）。

**判定规则**：
1. 双维度计数：production-critical（PS7）vs compatibility（PS5.1）。PS5.1 FAIL 仅记录 compatibility FAIL，不阻塞 PS7 production gate（消解 Prompt §20 与 §35 的规则冲突）。
2. FAIL 不得改写为 BLOCKED；BLOCKED 不得改写为 PASS；旧证据不得冒充新证据。

### 6.4 最终执行摘要模板

见 Phase 13.4（与 Prompt §37 逐项一致，29 项）。

---

## 7. 最终原则（Prompt §39）

```text
Git repository = 唯一事实源
SKILL-v1.11.md = 唯一被测对象
PowerShell 7.x = 生产主运行环境
PS5.1 = 兼容性回归
.monitor = 必须由 SKILL 自己初始化
.output = 唯一生产状态路径

代码存在 != 行为正确
旧 PASS != 当前 PASS
BLOCKED != PASS
FAIL != BLOCKED

不修改被测 SKILL
不篡改旧证据
不隐藏失败
不允许重复 RUN_STATUS
不允许缺失 RUN_STATUS
```

---

## 8. 质量控制：自我审查

本计划制定完成后，进行以下全面自我审查：

### A1 事实源与独立性
- [x] 唯一事实源已指定：`.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md`
- [x] 每个设计决策能指认事实源出处（Prompt 章节号 + SKILL-v1.11.md 行号，行号经 Select-String 双源核实）
- [x] 旧轮次结论仅作信息参考；引用处有独立性声明（§0.6）
- [x] 枚举/数量词全部来自完整原文阅读（30 项能力 / 9 项辅助禁止 / 9 种状态 / 9 项 T26 输入 / 6 场景 / 6 子测试 / 15+4=19 项 self-review / 16 章报告）

### A2 模块化与串行
- [x] 模块总览表完整（14 个 Phase）；每模块输入封闭、输出清单化
- [x] 模块间仅通过产物文件传递状态
- [x] 单模块工作量在单次 sub-agent 会话预算内
- [x] 硬门槛模块显式标注（Phase 2/3/4/5/7）；第一（Phase 0）/倒数第二（Phase 12）/最后（Phase 13）模块职能正确
- [x] 禁止并行 + 每 Phase 单 sub-agent 已声明（§0.3）

### A3 可接续
- [x] phase-progress.json 结构与恢复原则已定义（§0.4）
- [x] 中断类型 × 检测 × 恢复策略表完整（4 类：LLM API 失败 / 网络波动 / 资源限制 / 上下文溢出）
- [x] 恢复不依赖会话记忆

### A4 分阶段验收
- [x] 每个 Phase 有审查点，全部可判定（存在/相等/包含/一致）
- [x] 条件化期望已标注（T37 `REVIEW_WRITE_OK|`、T38-heartbeat 锁状态、T38-stats-items 锁释放失败输出、Phase 7 tmp 监视补充链）
- [x] 审查是独立复核（主 agent 亲读证据）
- [x] 独立复核模块检查集完整（Phase 12 含 19 项，含指纹复核、受限 diff、守恒核算）

### A5 可追溯
- [x] 开工基线指纹已安排（Phase 0 的 3 个 SHA256）；每个采集物有消费者（Phase 12）
- [x] 派生物有 manifest（Phase 1 extraction-manifest.json）；注入类派生物有受限 diff 规则（三处注入点声明）
- [x] 证据清单覆盖：输出/变更/外部调用/环境变更（§4）
- [x] 数字只有一个权威出处；守恒式已定义（`EXECUTED = PASS + FAIL + BLOCKED`）

### A6 技术可行性
- [x] 每个构造方法选项已评估平台可行性；证伪项显式排除（Windows ReadOnly 不阻止创建、File.Open 不能打开目录）
- [x] 环境变更类构造（ACL）带备份/还原步骤（T38-A/T22 ACL 恢复 5 步 + 还原验证）
- [x] 进程模型声明完整（§0.7）；同进程注入场景有 harness 设计（T38 六子测试编排器、T39、SENTINEL 机制）+ dot-source 不可行性说明
- [x] 替换体（mock）有逐场景 contract（成员+取值+类型+消费方行号）+ 对齐自检
- [x] 锁 PID 一致性机制显式设计（§0.5，单进程编排器 + 独立 step 前重写锁 PID）

### A7 隔离与安全
- [x] 生产对象隔离机制明确（GITHUB_VERSION_MONITOR_BASE）且已写入禁止事项
- [x] 替换方案优先无系统级变更（函数覆盖 > 文件锁 > ACL）；有变更则有还原验证
- [x] secret 输出禁止已列入（§3 第 5 条、§4）
- [x] `.monitor` 不得预创建已列入禁止事项（§3 第 12 条）

### A8 判定与收尾
- [x] 上游规则冲突已消解（PS5.1 compatibility vs PS7 production-critical 双维度，§6.3）
- [x] 结论模板与上游格式对齐（Phase 13.5 Final Output 与 Prompt §38 一致；§6.4 摘要与 §37 一致）
- [x] 执行摘要模板每一项映射到实际安排的工作（29 项；PS7 forbidden 覆盖方式显式声明）
- [x] commit 文件范围显式列出（Phase 13.6）；commit message 要素完整
- [x] 修订日志格式就绪（§9）

### A9 存储路径与命名准确性
- [x] 本计划存储：`.exec-plan/exec-plan-v1.11-a.md`（项目版本 v1.11 + 计划版本 a，符合命名规范）
- [x] Clean-Room 目录：`.production-validation-v111-final/`（Prompt §1 字面）
- [x] 最终报告：`production-validation-report-v111-final.md`（Prompt §32 字面）
- [x] self-review：`.selfreview/selfreview-v111-YYYYMMDD-HHMMSS.md` 带实际时间戳（Prompt §31 字面）
- [x] early-return 审计：`early-return-final-status-audit.md`（Prompt §26 字面）
- [x] diff 产物：`v110-v111.diff` + `v110.sha256` / `v111.sha256` / `state.sha256`（Prompt §3/§4 字面）

### A10 静默执行合规性
- [x] 全部 14 Phase 后台静默模式执行声明（§0.8）
- [x] 前台场景声明：不存在；环境限制导致无法静默时标 BLOCKED 而非切换前台

---

## 9. 修订日志

### exec-plan-v1.11-a（2026-09-09，初版制定）

**审计来源**: 无（初版，待用户审核与独立审计）

| 审计项 | 严重性 | 采纳/驳回 | 修订内容 | 理由 |
|---|---|---|---|---|
| — | — | — | 初版制定 | 基于 v1.11 Prompt 39 节 + SKILL-v1.11.md 直接阅读（行号 Select-String 双源核实）+ v1.10→v1.11 diff 实测分析（3 hunk）+ `.Template/exec-plan-tmpl-v1.md` 模板 + exec-plan-v1.10-d 结构基线（四轮审计零发现版本） |

**驳回项**: 无

**与 v1.10-d 计划的结构差异说明**（均为 v1.11 Prompt 增量要求驱动）：
1. Phase 数 13 → 14：新增 Phase 7（Runtime Artifact Initialization，Prompt §24 新增节，Production Gate 清单项）
2. Phase 2 扩展：§12 统一计数检查（6 子测试 × 5 指标矩阵）+ SENTINEL 哨兵机制（行为链"不能继续执行"的直接证明）
3. 原 Phase 10（静态审计）扩展为 Phase 11 三合一：Early Return Audit（§26，return 三分类 + exactly once）+ Final Status Uniqueness Audit（§27 新增硬门槛）+ Invariant（I1-I7 重映射至 v1.11 Prompt 节号）
4. 新增 §0.10 Test Harness Integrity 协议（Prompt §30 新增节）+ harness-fix-log.md
5. 新增 §0.5 锁 PID 一致性机制显式设计（v1.10-d 隐含未明述，本轮明确化以避免执行陷阱）
6. 能力核验清单 28 → 30 项（v1.11 Prompt §4 新增 `.monitor/` 与 `Get-ResponseHeaderValue`）
7. Self-Review 16 → 19 项（Prompt §31 固定 15 项 + 模板补充 4 项）+ 文件名改为带时间戳
8. 报告章节结构更新为 v1.11 §32 的 A-P 新清单（D=T38 Detailed / F=Runtime Artifact / G=Final Status Uniqueness / H=Early Return）
9. T05-PS7 不再设独立测试（v1.11 Prompt 无此要求；PS7 forbidden 由 T18-forbidden 场景覆盖并声明）
10. Process Kill 目标点收窄为 Step 2/4/5（v1.11 Prompt §25 字面，v1.10 为 Step 2/3/4/5）

---

## 附录 A：上游文档逐节对照表（Prompt 39 节全覆盖）

| Prompt 章节 | 对应 Phase / 章节 | 覆盖说明 |
|---|---|---|
| §0 Production Runtime | 全局 + Phase 0 | PS7 主环境 / PS5.1 兼容 / 状态文件 / 运行时目录 |
| §1 Clean-Room | Phase 0 | `.production-validation-v111-final/` 新目录 + 禁复用清单 |
| §2 被测对象来源 | Phase 0 | git 仓库获取 3 文件 + git add |
| §3 Baseline SHA256 | Phase 0 | v110 / v111 / state 三指纹 |
| §4 Diff Integrity | Phase 1 | 3 hunk 核验 + 30 项能力 + 特别检查 + 9 项辅助 |
| §5 T38-stats-items 最高优先级 | Phase 2 | RUN_STATUS count=1 硬门槛 |
| §6 T38-stats-items 精确行为链 | Phase 2 | 五环节逐环节证明 + SENTINEL |
| §7 T38-A | Phase 2 | tmp 写入失败 |
| §8 T38-B | Phase 2 | JSON 校验失败（注入） |
| §9 T38-C | Phase 2 | 原子替换失败 |
| §10 T38-heartbeat | Phase 2 | heartbeat 失败 |
| §11 T38-result-read | Phase 2 | result.json 读取失败 |
| §12 T38 统一检查 | Phase 2 | t38-unified-count.md 6×5 矩阵 |
| §13 T22 | Phase 3 | md tmp 写入失败 |
| §14 T23 | Phase 3 | md 原子替换失败 |
| §15 T37 | Phase 4 | 正常成功（Step1-6） |
| §16 T39 | Phase 5 | commit 成功 + 锁释放失败 |
| §17 T43 | Phase 6 | 全管线 6 场景 |
| §18 T46 | Phase 6 | .output 路径契约 |
| §19 T04 | Phase 8 | rate_limited + 请求计数 |
| §20 T04/T05-PS5.1 | Phase 9 | PS5.1 兼容回归 |
| §21 T26 | Phase 8 | strict flag 9 项输入 |
| §22 T18 | Phase 8 | 9 种状态保留 |
| §23 Lock regression | Phase 10 | 4 项 + 特别三项映射 |
| §24 Runtime artifact initialization | Phase 7 | .monitor 生命周期快照链（新模块） |
| §25 Process Kill | Phase 10 | Step2/4/5 实际执行点 + 接管验证 |
| §26 Early Return Audit | Phase 11.1 | return 三分类 + exactly once |
| §27 Final Status Uniqueness | Phase 11.2 | fatal test 全矩阵（新硬门槛） |
| §28 Diff/Behavioral Integrity | Phase 1 + 11.3 | 结构面 + 行为面双确认 |
| §29 Evidence Rules | §4 全局 | 证据规则表 |
| §30 Test Harness Integrity | §0.10 | 修复协议 + harness-fix-log.md |
| §31 Self-Review | Phase 12 | 19 项 + 带时间戳文件名 |
| §32 Final Report | Phase 13.1 | A-P 16 章 |
| §33 Final Counting | Phase 13.2 | 守恒式 |
| §34 Production Gate | Phase 13.3 / §6.3 | 完整清单判定 |
| §35 PRODUCTION_NOT_READY | Phase 13.3 | P1 情形枚举 |
| §36 PRODUCTION_BLOCKED | Phase 13.3 | 唯一条件 |
| §37 Final Execution Summary | Phase 13.4 | 29 项摘要模板 |
| §38 Final Output | Phase 13.5 | 最终输出格式 |
| §39 Absolute Rules | §7 | 12 条原则 |

## 附录 B：本计划关键设计决策

| 编号 | 决策 | 理由 |
|---|---|---|
| D1 | SENTINEL 哨兵机制（编排器末尾输出标记，fatal return 路径期望标记缺失） | v1.11 核心是"return 是否真的阻止继续执行"（Prompt §5/§6"不存在继续执行"）；stdout 中 SENTINEL 缺失是 return 生效的直接行为证明，比"无后续输出"更强可判定 |
| D2 | 统一编排器模式（单进程 `& step1..3` + 构造 + 被测 step） | 同进程同 PID 天然满足锁 ownership 校验（生产语义 = 同一 agent 会话连续执行）；v1.10-d 的 T38 设计分散在各子测试中，本轮统一化并显式声明锁 PID 机制 |
| D3 | T38 前置用真实管线（Step1-3 真实执行产生 result.json）而非手工预置 | 生产语义保真：result.json 结构/stats/review 字段由 SKILL 真实产生；404 repo 触发 review=true 稳定无版本漂移 |
| D4 | Runtime artifact 独立 Phase（Phase 7）而非并入 T37 | Prompt §24 是 Production Gate 独立清单项；.monitor 生命周期需要 step 间快照链 + 监视进程，与 T37 的 stdout 链验证关注点不同；独立 base 目录保证".monitor 不存在"前置断言天然成立 |
| D5 | tmp 出现验证的主证据（watch-dir 监视）+ 条件化补充链（T38-B harness + review.performed） | tmp 存在窗口为纯本地操作（<10ms），轮询可能错过；T38-B 注入能对 tmp Set-Content 即证明文件真实存在（行为级证据）；条件化处理避免监视技术限制误判 FAIL |
| D6 | Step 2/Step 3 的 RUNTIME_ERROR 路径（L404/L410/L444）列入 early-return 审计而非新增动态测试 | Prompt §26 要求的是静态审计（return 分类 + exactly once 确认），这些路径的动态注入不在 §5-§14 必测清单；审计发现如实记录（如缺 RUN_STATUS 终态则按 contract 判定并记录），不隐瞒不扩大 |
| D7 | T05-PS7 不设独立测试 | v1.11 Prompt §19-§22/§34/§37 均无 T05-PS7（v1.10 Prompt 有）；PS7 forbidden 判定由 T18-forbidden 场景覆盖；报告 O 节声明覆盖方式（P-17：模板项映射实际工作） |
| D8 | PS5.1 双维度计数（production-critical vs compatibility） | 消解 Prompt §20（PS5.1 不阻塞 gate）与 §35（FAIL>0 即 NOT_READY）规则冲突；继承 v1.10-d 已验证的裁决方案 |
| D9 | 辅助禁止项检查（9 项）标注"非 Prompt 明文要求" | v1.11 Prompt §4 无该清单（v1.10 轮实践提炼）；保留为防御性检查但明确来源，避免 P-04（旧结论当事实） |
| D10 | git add 范围含 .GPT 验证提示文件 | Prompt §2"从当前 Git repository 获取"+ §39"Git repository = 唯一事实源"；两文件当前均 untracked（git status 实测），纳入跟踪保证事实源可追溯 |

## 附录 C：裁剪声明

本计划为 **L 型（大）**，依据：

- Phase 数：14（9+，符合 L 型）
- §0.6 独立性原则：保留全文
- §0.4 断点机制：完整 progress.json + 恢复原则
- 模块骨架：标准三段（Phase 0 基线 / Phase 12 复核 / Phase 13 收尾）+ 硬门槛分级（Phase 2/3/4/5/7）
- Phase 12 独立复核：完整 19 项检查集
- §6.3 双维度计数：PS7 production-critical vs PS5.1 compatibility
- 独立审计轮：强制（每版修订后重审）

**裁剪红线确认**（以下均未裁剪）：
- 禁止事项（§3）：15 条，不为空
- 开工基线与指纹复核（Phase 0 + Phase 12）：完整
- 判定守恒式（§6.2/§6.3）：已定义
- 修订日志（§9）：初版已建



