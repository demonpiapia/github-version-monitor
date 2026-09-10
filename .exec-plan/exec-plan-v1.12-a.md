# SKILL-v1.12 最小修改与定向验证 — 执行计划

> **版本**: exec-plan-v1.12-a（初版，待用户审核与独立审计）
> **制定日期**: 2026-09-10
> **依据**: `.GPT/v1.12 最小修改与定向验证 Prompt.md`（唯一事实源，共 13 节）
> **被操作对象**: `SKILL-v1.11.md` → 修改后产出 `SKILL-v1.12.md`
> **执行模式**: 单一 sub-agent 串行执行，禁止任何形式的多 sub-agent 并行
> **生产主运行环境**: Windows 11 + PowerShell 7.x（`pwsh.exe`）
> **兼容/次要环境**: 无（v1.12 Prompt §7 禁止 5：PS5.1 完全忽略，不作为 compatibility target）
> **修订记录**: 见 §9 修订日志

---

## 0. 计划总览

### 0.1 核心目标

v1.11 已可用。v1.12 的目标不是重构，而是在 v1.11 基础上做三类与未来自动升级软件集成直接相关的可靠性修正（Prompt §4）：

```
P1: 强制 PowerShell 7 + 显式执行路径
P2: Step 3 housekeeping 不得阻断核心业务
P3: 重新审查 RUN_STATUS fatal path，但禁止机械打补丁
```

然后进行压缩后的定向验证（Prompt §8，Test 1-6），不重复 v1.11 的完整 4-5 小时认证。

### 0.1.1 目标与完成定义（DoD）

```
SKILL-v1.11.md → SKILL-v1.12.md 最小 structural diff
        ↓
P1: PS7 强制检查 + 显式绝对路径写入执行契约
        ↓
P2: Step 3 housekeeping 失败不阻断核心流程（backup/trash 清理失败 → warning + 继续）
        ↓
P3: 6 条 fatal path 逐个审查分类，仅真正 fatal + 无明确终态者做最小修复
        ↓
Test 1-6 全部 PASS（PS7 强制 / 正常成功 / API failure / 核心写入 failure / housekeeping failure / final status）
        ↓
production-validation-report-v112-final.md 生成
        ↓
禁止出现的假成功：扩大修改范围 / 机械补丁所有 return / 新增 T47+ 测试 / 为 PS5.1 修改 Skill
```

### 0.1.2 输入基线

开工前采集以下关键对象的指纹（Phase 0 执行）：

| 对象 | 指纹类型 | 保存文件 | 消费者（复核环节） |
|---|---|---|---|
| `SKILL-v1.11.md` | SHA256 | `v111.sha256` | Phase 8 self-review 第 1/2 项 |
| `SKILL-v1.12.md`（修改后） | SHA256 | `v112.sha256` | Phase 8 self-review 第 1/2 项 |
| `.output/GitHub更新监测列表.md` | SHA256 | `state.sha256` | Phase 8 self-review 基线完整性 |

### 0.2 v1.11 → v1.12 Diff 预期概要

基于对 SKILL-v1.11.md 的直接阅读和 Prompt §4 三类允许修改的分析，预期变更点如下（Phase 1 须重新生成 diff 并复核无其他 hunk）：

#### P1 — 强制 PowerShell 7 + 显式执行路径

| 变更点 | SKILL-v1.11 行号 | v1.11 现状 | v1.12 修改 | 类别 |
|---|---|---|---|---|
| 版本号 | L8 | `> 版本：v1.11` | `> 版本：v1.12` | documentation |
| 生产基准声明 | L9 | `> 生产执行基准：PowerShell 7.x；PowerShell 5.1 仅作兼容性验证环境。` | 移除 PS5.1 兼容性表述，改为 `> 生产执行基准：PowerShell 7.x ONLY。禁止使用 Windows PowerShell 5.1。` | 契约修改 |
| 执行上下文 | §2 L36-43 | 通用上下文描述 | 添加显式绝对路径声明：Repository / Skill / pwsh.exe | 契约修改 |
| Step 1 代码块 | L160-161 区域 | `$ErrorActionPreference = 'Stop'` 后直接 `$base` 解析 | 在 `$ErrorActionPreference = 'Stop'` 后、`$base` 解析前插入 PS7 版本检查：`if ($PSVersionTable.PSVersion.Major -lt 7) { Write-Output 'RUNTIME_ERROR|PowerShell 7.x required, current: ' + $PSVersionTable.PSVersion; return }` | 核心修改 |
| Changelog | L768 区域 | v1.11 changelog 条目 | 新增 v1.12 changelog 条目 | changelog |

#### P2 — Step 3 housekeeping 不得阻断核心业务

| 变更点 | SKILL-v1.11 行号 | v1.11 现状 | v1.12 修改 | 类别 |
|---|---|---|---|---|
| Step 3 housekeeping | L447-451 | housekeeping 代码（trash 目录创建 + backup 清理）无异常保护，在 `$ErrorActionPreference = 'Stop'` 下任何失败产生未捕获终止性错误 → 脚本直接终止 → 核心业务被阻断 | 将 L447-451 全部包裹在独立 try/catch 中；catch 块输出 `HOUSEKEEPING_WARNING|...` 后继续（不 return） | 核心修改 |
| Step 3 heartbeat | L437-444 | heartbeat 失败 → LOCKED/RUNTIME_ERROR → return | **不修改**（heartbeat = lock ownership，不是 housekeeping） | 不修改 |

#### P3 — 重新审查 RUN_STATUS fatal path

v1.11 审计识别 6 条 fatal path 缺 RUN_STATUS 终态（L254 / L320 / L406 / L412 / L444 / L529）。逐个审查分类：

| 行号 | 路径描述 | 分类 | 处理 |
|---|---|---|---|
| L254 | Step 2 锁不存在 → `RUNTIME_ERROR|` → return | **第 4 类：validation audit 对 fatal path 分类过度**。L253 输出 `RUNTIME_ERROR|运行锁不存在...`，L254 return。此路径属"锁丢失"的运行时保护路径，`RUNTIME_ERROR|` 已是明确的错误信号；且该路径在生产中几乎不可达（Step 1 创建锁后同进程连续执行）。**不修改**。 | 不修改 |
| L320 | Step 2 PARSE_ERROR → return | **第 3 类：已由其他最终状态处理覆盖**。L320 输出 `PARSE_ERROR|` + 锁释放尝试后 return。`PARSE_ERROR|` 是 SKILL §9 机器运行状态协议中定义的 `failed` 判定标记。**不修改**。 | 不修改 |
| L406 | Step 2 result.fetch.tmp JSON 校验失败 → `RUNTIME_ERROR|` → return | **第 2 类：正常内部控制流**。L404 输出 `RUNTIME_ERROR|result.fetch.tmp JSON 结构校验失败`，L405 释放锁，L406 return。此路径在 result.json 未安全写入时保守终止，`RUNTIME_ERROR|` 已是错误信号。**不修改**。 | 不修改 |
| L412 | Step 2 result.json 替换失败 → `RUNTIME_ERROR|` → return | **第 2 类：正常内部控制流**。L410 输出 `RUNTIME_ERROR|result.json 原子替换失败`，L411 释放锁，L412 return。同上，`RUNTIME_ERROR|` 已是错误信号。**不修改**。 | 不修改 |
| L444 | Step 3 heartbeat 失败 → `RUNTIME_ERROR|` → return | **第 2 类：正常内部控制流**。L444 catch 通用块输出 `RUNTIME_ERROR|步骤3 heartbeat 失败`，return。heartbeat 失败 = lock ownership 问题，保守终止是安全行为。**不修改**。 | 不修改 |
| L529 | Step 5 锁不存在 → `RUNTIME_ERROR|` → return | **第 4 类：validation audit 对 fatal path 分类过度**。L529 输出 `RUNTIME_ERROR|运行锁不存在...`，return。同 L254 分析。**不修改**。 | 不修改 |

**P3 结论**：6 条 fatal path 经逐个审查，**均不需要修改**。

理由汇总：
1. L254/L529：锁不存在路径在生产中不可达（同进程连续执行），`RUNTIME_ERROR|` 已是明确错误信号
2. L320：`PARSE_ERROR|` 是 SKILL §9 协议中定义的 `failed` 判定标记
3. L406/L412：result.json 安全写入失败的保守终止路径，`RUNTIME_ERROR|` 已是错误信号
4. L444：heartbeat 失败 = lock ownership 问题，保守终止是安全行为

Prompt §6 明确要求："只有第 1 类（真正 fatal + 没有明确最终状态）才需要保证最终状态语义。" 上述 6 条路径均有明确的错误状态输出（`RUNTIME_ERROR|` 或 `PARSE_ERROR|`），不属于"没有明确最终状态"。

> **注意**：Phase 1 执行时须重新逐个审查上述 6 条路径（基于 SKILL-v1.12.md 修改后的行号），确认分类结论不变。如因 P1/P2 修改导致行号偏移，须以实际行号为准重新核对。

### 0.3 执行架构

```
Phase 0 (sub-agent) → 主 agent 审查 → Phase 1 (sub-agent) → 主 agent 审查 → ... → Phase 7 (sub-agent) → 主 agent 审查 → Phase 8 (主 agent 收尾)
```

- **严格串行**：下一 Phase 仅在上一 Phase 的主 agent 审查通过后启动
- **单一 sub-agent**：每个 Phase 派遣且仅派遣一个 sub-agent 执行
- **禁止并行**：任何时刻最多一个 sub-agent 在运行；sub-agent 不递归派遣
- 主 agent 保留编排、审查与最终核实职责；审查 = 亲自读取证据文件核对，不采信 sub-agent 结论转述

### 0.4 中断接续方案

| 中断类型 | 检测方式 | 恢复策略 |
|---|---|---|
| LLM API 调用失败（sub-agent 无返回/错误） | sub-agent 无返回或返回错误 | 主 agent 重试同一 Phase，传入 `resume_from` 参数指向已完成步骤 |
| 网络波动（GitHub API 超时/失败） | 测试 stdout 中 API 异常 | 步骤内退避重试（max_retries=3），仍失败则标 BLOCKED |
| 资源限制（sub-agent 输出截断） | 返回不完整 | 主 agent 核验已产出证据文件，从断点继续 |
| sub-agent 上下文溢出 | 返回不完整结果 | 主 agent 核验已生成证据，拆分剩余工作到新 sub-agent 实例 |

**断点保存机制**：每个 Phase 完成后，sub-agent 在测试目录下生成/更新 `phase-progress.json`：

```json
{
  "phase": "Phase0",
  "start_time": "2026-09-10T16:00:00+08:00",
  "end_time": "2026-09-10T16:30:00+08:00",
  "status": "completed|partial|failed",
  "completed_steps": ["step1", "step2"],
  "pending_steps": [],
  "evidence_files": ["v111.sha256", "v112.sha256"],
  "next_phase": "Phase1"
}
```

主 agent 在启动下一 Phase 前读取此文件，确认状态为 `completed` 后方可继续；若 `partial`，向新 sub-agent 传入 `resume_from`。**恢复不依赖会话记忆，只依据产物文件 + progress 文件 + `resume_from`**。

### 0.5 测试隔离机制

所有测试通过 `GITHUB_VERSION_MONITOR_BASE` 环境变量实现 fixture 隔离。SKILL 每个 step 均支持此变量（L163/L241/L432/L474/L522）。

- 每个测试子目录作为独立 base 目录，`$env:GITHUB_VERSION_MONITOR_BASE = '<test-dir>'`
- `.monitor/` 由 Step 1 在 base 目录下动态创建（**不得由测试 harness 预先创建**）
- `.output/GitHub更新监测列表.md` 使用 fixture 副本，不触碰生产文件

**Mock 重定向机制**（Test 3 API failure / Test 4 核心写入 failure）：
- API URL 硬编码 `https://api.github.com`（SKILL L341/L479），无 base 覆盖机制
- 测试采用 PowerShell 函数覆盖：mock harness 在执行 step2 代码前先定义 mock `Invoke-RestMethod` 覆盖内置 cmdlet，按场景返回受控响应
- 不修改被测代码，仅运行时注入函数覆盖

**进程模型声明**：`-File` 模式下每个脚本独立进程，脚本间无共享变量。凡需"中途注入/同进程分段控制"的场景，必须设计同进程 harness（单进程编排器：`& stepN.ps1` 同进程顺序调用 + 注入版内联代码），并做受限 diff 验证。

常驻辅助进程（文件锁持有者）用 `Start-Process -WindowStyle Hidden` 启动、测试后 `Stop-Process` 终止。

### 0.6 独立性原则

```
1. 所有设计决策必须基于以下两个事实源的直接阅读：
   - SKILL-v1.11.md 源码（行号 + 代码逻辑）
   - v1.12 最小修改与定向验证 Prompt 原文（13 节）

2. 旧版本验证报告（v17/v18/v19/v110/v111）的结论不得作为本轮设计依据。
   旧报告中的发现只能作为"待独立验证的声明"。

3. 引用旧发现的，必须在执行阶段由 sub-agent 独立验证后才能作为事实采纳。

4. 旧报告的结论（PASS/FAIL/计数）仅供信息参考，
   不得影响本轮任何构造方法、验证项或判定逻辑。
```

> 信息参考（不作为设计依据）：v1.11 报告判定 Final Status Uniqueness = FAIL / Early Return Audit = FAIL / I7 = PARTIALLY VERIFIED，识别 6 条 fatal path。本计划的 P3 审查基于对 SKILL-v1.11.md L254/L320/L406/L412/L444/L529 的直接阅读独立成立。

### 0.7 执行模式

- 所有脚本经 `pwsh.exe -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>` 执行（PS7 ONLY），后台静默，输出重定向到文件
- 常驻辅助进程（文件锁持有者）用 `Start-Process -WindowStyle Hidden` 启动，测试后 `Stop-Process` 终止
- 同进程 harness（Test 3/4/5 注入场景）：`pwsh.exe -NoProfile -NonInteractive -File <harness.ps1> *>&1 > <output.txt>`

### 0.8 正式汇报：执行模式声明

**后台静默模式覆盖范围**：本计划全部 9 个 Phase（Phase 0-8）的所有执行操作和测试流程均采用后台静默模式运行，不弹出任何前台窗口或对话框。

具体实现：
- PowerShell 脚本：`pwsh.exe -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>`
- 常驻辅助进程（文件锁持有者）：`Start-Process -WindowStyle Hidden` 启动，`Stop-Process` 终止
- 同进程 harness（Test 3/4/5）：`pwsh.exe -NoProfile -NonInteractive -File <harness.ps1> *>&1 > <output.txt>`

**前台执行模式声明**：本计划**不存在**必须使用前台执行模式的特殊场景。

> 如执行过程中因环境限制导致某测试无法在后台静默模式完成，sub-agent 须标记 BLOCKED 并在 test-report.md 记录具体原因，不得自动切换至前台模式。

### 0.9 任务追踪机制

主 agent 维护全局任务追踪表，记录每个 Phase 的开始时间、结束时间、执行状态和关键节点。此表在主 agent 审查点更新，不依赖 sub-agent 会话记忆。

**追踪表模板**（主 agent 在每个 Phase 审查通过后更新）：

| Phase | 模块名 | 开始时间 | 结束时间 | 执行状态 | 关键节点 | 审查结果 |
|---|---|---|---|---|---|---|
| 0 | 基线采集 + 环境准备 | {{ISO8601}} | {{ISO8601}} | completed | 3 SHA256 / git add | PASS |
| 1 | SKILL 修改 + Diff Integrity | {{ISO8601}} | {{ISO8601}} | {{status}} | SKILL-v1.12.md 生成 / diff hunk 核验 | {{result}} |
| 2 | 代码提取 + 工具集 | {{ISO8601}} | {{ISO8601}} | {{status}} | 5 step 提取 / harness 就绪 | {{result}} |
| 3 | Test 1 PS7 + Test 2 正常成功 | {{ISO8601}} | {{ISO8601}} | {{status}} | PS7 强制 / 成功链确认 | {{result}} |
| 4 | Test 3 API failure + Test 4 核心写入 failure | {{ISO8601}} | {{ISO8601}} | {{status}} | fail-safe 确认 | {{result}} |
| 5 | Test 5 housekeeping failure | {{ISO8601}} | {{ISO8601}} | {{status}} | housekeeping 不阻断确认 | {{result}} |
| 6 | Test 6 final status | {{ISO8601}} | {{ISO8601}} | {{status}} | RUN_STATUS 语义确认 | {{result}} |
| 7 | Self-Review | {{ISO8601}} | {{ISO8601}} | {{status}} | 复核完成 | {{result}} |
| 8 | Final Report + Commit | {{ISO8601}} | {{ISO8601}} | {{status}} | 报告 / commit | {{result}} |

**追踪表保存位置**：`.production-validation-v112-final/task-tracker.md`

### 0.10 Test Harness Integrity 协议

测试过程中允许修复 harness（orchestrator / wrapper / fixture / report generator），但每次修复必须：

1. 记录时间（ISO8601）
2. 记录原因
3. 说明修复对象不属于被测 SKILL（`SKILL-v1.12.md` 指纹不变，Phase 7 复核）
4. 重新执行受影响的测试（旧证据不覆盖新证据，新证据追加并存）

严禁：修改 `SKILL-v1.12.md`；修改 harness 后将原测试重新标记 PASS 而不重新执行。

所有 harness 修复记录汇总于 `.production-validation-v112-final/harness-fix-log.md`。

---

## 1. 模块分解

### 模块总览表

| Phase | 模块名 | 输入 | 输出 | 优先级 |
|---|---|---|---|---|
| 0 | 基线采集 + Git/SHA256 + 环境准备 | SKILL-v1.11.md, .output/...md | 目录树 + 3 个 SHA256 文件 + git staging | 基础 |
| 1 | SKILL 修改（P1+P2+P3）+ Diff Integrity | SKILL-v1.11.md, Prompt §4 | SKILL-v1.12.md + v111-v112.diff + diff-integrity.md | **硬门槛** |
| 2 | 代码提取 + 工具集 + harness | SKILL-v1.12.md, fixture | lib/*.ps1 + harness + mock 工具 + extraction-manifest.json | 基础 |
| 3 | Test 1 PS7 强制 + Test 2 正常成功路径 | lib/, fixture | T1 + T2 测试目录 + 证据 | **硬门槛** |
| 4 | Test 3 API failure + Test 4 核心写入 failure | lib/, mock, fixture | T3 + T4 测试目录 + 证据 | **硬门槛** |
| 5 | Test 5 housekeeping failure | lib/, fixture | T5 测试目录 + 证据 | **硬门槛** |
| 6 | Test 6 final status 语义 | 全部前序证据 | T6 审计报告 | 关键 |
| 7 | Self-Review | 全部 Phase 0-6 证据 | selfreview-v112-<时间戳>.md | 质量控制 |
| 8 | Final Report + Commit | 全部证据 | production-validation-report-v112-final.md | 收尾 |

### 拆解规则

1. **输入封闭**：每个模块的输入只允许来自（a）事实源文件（b）已通过审查的前序 Phase 产出。模块间只通过产物文件传递状态。
2. **输出清单化**：每个模块的产出是逐文件清单，可被审查点逐项核对。
3. **粒度**：单模块工作量 = 单个 sub-agent 一次会话可完成。
4. **优先级语义**：硬门槛 = 失败即整体判定失败（仍完成后续 Phase 保留证据）；关键 = 失败进入高风险复核；中/辅助 = 失败记录不阻断。
5. **第一模块固定为基线采集**（Phase 0），**倒数第二模块固定为独立复核**（Phase 7），**最后模块固定为汇总收尾**（Phase 8）。

---

## 2. 各 Phase 详细规格

---

### Phase 0: 基线采集 + Git/SHA256 + 环境准备

**前置条件**: 项目根目录 `d:\AI\Workspace\automatic\github-version-monitor` 存在且为 git 仓库

**输入参数**:
- 项目根目录: `d:\AI\Workspace\automatic\github-version-monitor`
- 测试目录: `.production-validation-v112-final/`
- 基线文件: `SKILL-v1.11.md`, `.output/GitHub更新监测列表.md`

**处理逻辑**:
1. 确认 PowerShell 版本：
   ```powershell
   $PSVersionTable.PSVersion
   ```
   要求 `Major >= 7`。不满足 → 立即停止，不执行后续任何操作。

2. 创建 `.production-validation-v112-final/` 目录树：
   ```
   .production-validation-v112-final/
   ├── lib/
   ├── T1-PS7/
   ├── T2-success/
   ├── T3-api-failure/
   ├── T4-write-failure/
   ├── T5-housekeeping/
   ├── T6-final-status/
   ├── audit/
   ├── .selfreview/
   └── phase-progress.json
   ```
   > `.monitor/` 不在目录树中预创建。

3. 计算 3 个文件 SHA256：
   ```powershell
   Get-FileHash .\SKILL-v1.11.md -Algorithm SHA256
   Get-FileHash .\.output\GitHub更新监测列表.md -Algorithm SHA256
   ```
   保存为 `v111.sha256`、`state.sha256`（`v112.sha256` 在 Phase 1 修改后生成）

4. `git status` + `git diff` 确认开工前仓库状态（Prompt §11）

5. 禁止复用历史 validation 目录中的任何产物作为本轮 PASS 证据

**输出结果**:
- `.production-validation-v112-final/v111.sha256`
- `.production-validation-v112-final/state.sha256`
- `.production-validation-v112-final/phase-progress.json`
- `.production-validation-v112-final/phase0-stdout.txt` / `phase0-stderr.txt` / `phase0-report.md`

**证据要求**:
- `phase0-stdout.txt` — PS 版本确认 + 目录创建 + SHA256 计算 + git status 的完整 stdout
- `phase0-report.md` — 执行摘要

**主 agent 审查点**（全部满足才放行）:
- [ ] 确认 `$PSVersionTable.PSVersion.Major >= 7`（stdout 中有实际版本号）
- [ ] 确认 2 个 SHA256 文件存在且内容非空
- [ ] 确认目录树结构完整（与上方清单逐项核对，无 `.monitor/` 预创建）
- [ ] 确认 `git status` 输出已记录（开工前仓库状态基线）

**失败处理**: PS 版本不满足 → 立即中止（Prompt §1）；目录创建失败 → 检查磁盘空间与权限后重试。

---

### Phase 1: SKILL 修改（P1+P2+P3）+ Diff Integrity（硬门槛）

**前置条件**: Phase 0 完成，PS7 已确认

**输入参数**:
- 源文件: `SKILL-v1.11.md`
- 事实源: `.GPT/v1.12 最小修改与定向验证 Prompt.md` §4（P1/P2/P3 三类允许修改）
- 测试目录: `.production-validation-v112-final/`

**处理逻辑**:

#### Step 1: 复制基线

```powershell
Copy-Item .\SKILL-v1.11.md .\SKILL-v1.12.md
```

#### Step 2: 执行 P1 修改 — 强制 PowerShell 7 + 显式执行路径

**P1-a：版本号行**（L8）
- `> 版本：v1.11` → `> 版本：v1.12`

**P1-b：生产基准声明**（L9）
- `> 生产执行基准：PowerShell 7.x；PowerShell 5.1 仅作兼容性验证环境。`
- → `> 生产执行基准：PowerShell 7.x ONLY。禁止使用 Windows PowerShell 5.1。`

**P1-c：执行上下文显式路径**（§2，L36-43 区域）
- 在 §2 执行上下文节末尾添加：
  ```
  - 生产执行必须使用 `pwsh.exe`（非 `powershell.exe`）。
  - 生产执行必须显式指定以下绝对路径：
    - Repository: `D:\AI\Workspace\automatic\github-version-monitor`
    - Skill: `D:\AI\Workspace\automatic\github-version-monitor\SKILL-v1.12.md`
  - Agent 不得根据当前 cwd、编辑器状态或默认 shell 推断路径。
  ```

**P1-d：Step 1 代码块 PS7 版本检查**（L160-161 区域）
- 在 `$ErrorActionPreference = 'Stop'` 之后、`$base` 解析之前，插入：
  ```powershell
  # PowerShell 7.x 强制检查
  if ($PSVersionTable.PSVersion.Major -lt 7) {
      Write-Output ("RUNTIME_ERROR|PowerShell 7.x required, current: {0}" -f $PSVersionTable.PSVersion.ToString())
      return
  }
  ```

> **注意**：SKILL 内部 `$base` / `$PSScriptRoot` 路径解析保留不变（Prompt §4 P1："如果 Skill 内部仍然需要 `$GITHUB_VERSION_MONITOR_BASE` / `$PSScriptRoot` 等路径解析，可以保留其内部实现"）。本次重点是生产执行契约必须显式指定路径和 shell。

#### Step 3: 执行 P2 修改 — Step 3 housekeeping 不得阻断核心业务

**P2-a：backup/trash 清理包裹独立 try/catch**（L447-451 区域）

v1.11 现状（L447-451，housekeeping 代码位于 heartbeat try/catch 块之外，无异常保护）：
```powershell
New-Item -ItemType Directory -Force -Path $trashDir | Out-Null
Get-ChildItem $backupDir -Filter 'GitHub更新监测列表.backup.*.md' |
  Sort-Object Name -Descending | Select-Object -Skip 1 |
  Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
  ForEach-Object { Move-Item $_.FullName (Join-Path $trashDir $_.Name) -Force }
```

> **v1.11 现状分析**：Step 3 代码块**未显式设置 `$ErrorActionPreference = 'Stop'`**（Step 1/2/4/5 均在开头设置，Step 3 未设置）。但在生产执行中，Step 1/2 设置的 `$ErrorActionPreference = 'Stop'` 在同会话中持续生效，故 housekeeping 代码在 `$ErrorActionPreference = 'Stop'` 下运行时，任何失败（如 `Get-ChildItem` 路径不存在 / `Move-Item` 权限不足 / `New-Item` 磁盘满）将产生未捕获的终止性错误，导致脚本直接终止 → 核心业务被阻断。

v1.12 修改为（将 L447-451 全部包裹在独立 try/catch 中，覆盖 trash 目录创建 + backup 清理）：
```powershell
# housekeeping: backup/trash 清理 — 失败不阻断核心业务
try {
    New-Item -ItemType Directory -Force -Path $trashDir | Out-Null
    Get-ChildItem $backupDir -Filter 'GitHub更新监测列表.backup.*.md' |
      Sort-Object Name -Descending | Select-Object -Skip 1 |
      Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } |
      ForEach-Object { Move-Item $_.FullName (Join-Path $trashDir $_.Name) -Force }
} catch {
    Write-Output ("HOUSEKEEPING_WARNING|backup/trash cleanup failed: {0}" -f $_.Exception.Message)
}
```

> **try/catch 范围说明**：Prompt §5 明确列出"创建 trash 失败""旧 backup 无法移动""清理某个旧 backup 失败"三类 housekeeping failure。L447（trash 目录创建）+ L448-451（backup 清理）全部纳入 try/catch 范围，确保所有 housekeeping 失败均被捕获。

> **heartbeat 不修改**（L437-444）：heartbeat = lock ownership，不是 housekeeping。heartbeat 失败必须继续保持安全优先级（Prompt §5）。

#### Step 4: 执行 P3 审查 — 重新审查 RUN_STATUS fatal path

P3 的审查结论已在 §0.2 P3 分析中给出：6 条 fatal path 均不需要修改。

Phase 1 执行时须重新逐个核对（基于 SKILL-v1.12.md 修改后的实际行号），确认分类结论不变。核对结果记录于 `diff-integrity.md` 的 P3 审查节。

如因 P1/P2 修改导致行号偏移，以实际行号为准。

#### Step 5: Changelog 新增 v1.12 条目

在 Changelog 区域（L768 附近）新增：
```
- **v1.12（2026-09-10 最小修改与定向验证轮）**：①P1：强制 PowerShell 7.x ONLY，移除 PS5.1 兼容性声明，Step 1 代码块新增 PS7 版本检查，执行契约显式指定绝对路径与 pwsh.exe ②P2：Step 3 backup/trash housekeeping 清理包裹独立 try/catch，失败时输出 HOUSEKEEPING_WARNING 并继续，不阻断核心业务流程；heartbeat 保持不变（lock ownership ≠ housekeeping） ③P3：逐个审查 v1.11 审计识别的 6 条 fatal path（L254/L320/L406/L412/L444/L529），结论为均不需要修改（均有明确错误状态输出） ④不扩展 SemVer / 不增加 API 请求 / 不扩大 review / 不重新设计 lock / 完全忽略 PS5.1。
```

#### Step 6: 生成 diff + Diff Integrity 核验

```powershell
git diff --no-index SKILL-v1.11.md SKILL-v1.12.md > .production-validation-v112-final/v111-v112.diff; exit 0
```

逐 hunk 核对 diff 与 §0.2 预期一致。预期 hunk：
1. L8 版本号行替换
2. L9 生产基准声明替换
3. §2 执行上下文新增路径声明
4. Step 1 代码块 PS7 检查插入
5. Step 3 代码块 housekeeping try/catch 包裹
6. Changelog 新增 v1.12 条目

如 diff 中出现**任何预期外 hunk** → Diff Integrity FAIL + P1。

#### Step 7: 能力保留核验

确认 v1.12 保留 v1.11 的全部关键能力（逐项核验，每项记录"diff 无删除 + 代码存在行号"）：

```
.output/GitHub更新监测列表.md
.monitor/
versionJump / dateSuspicious / reviewReasons
schema validation / strict lowercase yes/no
404 -> not_found / rate_limited / network_error / auth_error / forbidden
server_error / invalid_response / metadata_incomplete / http_error
result.fetch.tmp / result.review.tmp
lock / heartbeat / ownership
atomic result persistence / atomic review persistence / atomic md commit
commitSucceeded / COMMIT_OK / RUN_STATUS|success| / RUN_STATUS|failed|
Get-ResponseHeaderValue
Compare-Ver / ConvertTo-NormVer / ConvertTo-UtcIso
```

#### Step 8: 禁止项检查

确认以下内容不存在于 diff 新增行中：
```
mock URL / forced success / debug bypass / test-only branch
hardcoded token / hardcoded test repository
skip schema / skip lock / skip commit
完整 SemVer parser / 新增 API 请求 / 新增 review 来源 / lock 重写
```

#### Step 9: 计算 v1.12 SHA256

```powershell
Get-FileHash .\SKILL-v1.12.md -Algorithm SHA256
```
保存为 `v112.sha256`。

**输出结果**:
- `SKILL-v1.12.md`（修改后的 Skill 本体）
- `.production-validation-v112-final/v111-v112.diff`
- `.production-validation-v112-final/diff-integrity.md`（hunk 核验 + 能力表 + 禁止项 + P3 审查记录）
- `.production-validation-v112-final/v112.sha256`
- `.production-validation-v112-final/phase-progress.json`

**证据要求**:
- `phase1-stdout.txt` / `phase1-stderr.txt` / `phase1-report.md`

**主 agent 审查点**:
- [ ] 确认 `SKILL-v1.12.md` 已生成且 SHA256 已记录
- [ ] 确认 diff hunk 与 §0.2 预期表逐项一致，无预期外 hunk
- [ ] 确认 P1 修改：L8 版本号 / L9 PS7 ONLY / §2 显式路径 / Step 1 PS7 检查
- [ ] 确认 P2 修改：Step 3 housekeeping try/catch 包裹 + heartbeat 未修改
- [ ] 确认 P3 审查：6 条 fatal path 逐个核对结论记录于 diff-integrity.md
- [ ] 确认能力保留核验完成（逐项有行号证据）
- [ ] 确认禁止项检查完成（无 mock URL / 无 SemVer parser / 无新增 API 请求等）
- [ ] 确认 Changelog 新增 v1.12 条目

**失败处理**: diff 出现预期外 hunk → Diff Integrity FAIL + P1，记录并继续后续 Phase 保留证据；能力删除 → 立即中止并标 BLOCKED。

---

### Phase 2: 代码提取 + 工具集 + harness

**前置条件**: Phase 1 完成，SKILL-v1.12.md 已生成

**输入参数**:
- 源文件: `SKILL-v1.12.md`
- 测试目录: `.production-validation-v112-final/`

**处理逻辑**:

#### Step 1: 从 SKILL-v1.12.md 提取 PowerShell 代码块

逐字提取，禁止修改被测代码（提取工具 `lib/extract-code.ps1` 按代码围栏定位）：

- `lib/step1.ps1` — Step 1（状态检查 + PS7 检查 + 锁 + 备份）
- `lib/step2.ps1` — Step 2（解析 + 查询 + 状态机 + 统计）
- `lib/step3.ps1` — Step 3（housekeeping，含 v1.12 try/catch 修改）
- `lib/step4.ps1` — Step 4（复核）
- `lib/step5-full.ps1` — Step 5 完整（提交 + 锁释放 + RUN_STATUS）

#### Step 2: 创建 harness 与编排器

**统一编排器模式**：单进程 pwsh 脚本内 `$env:GITHUB_VERSION_MONITOR_BASE = '<test-dir>'` 后顺序 `& step1.ps1; & step2.ps1; & step3.ps1`（同进程同 PID，锁 ownership 天然一致），再按测试构造执行被测 step。

- `lib/run-full-pipeline.ps1` — T2 单进程完整管线（`& step1..5` 顺序调用）
- `lib/t3-mock-harness.ps1` — T3 API failure mock 测试包装
- `lib/t4-write-failure-harness.ps1` — T4 核心写入 failure 注入 harness
- `lib/t5-housekeeping-harness.ps1` — T5 housekeeping failure 注入 harness
- `lib/create-fixture.ps1` — fixture 生成工具
- `lib/lock-holder.ps1` — 外部文件锁持有进程（`Start-Process -WindowStyle Hidden` 启动）

#### Step 3: 创建 mock 工具

`lib/mock-invoke-restmethod.ps1` — mock `Invoke-RestMethod` 覆盖函数库

**mock 对象 contract**（按场景返回仿真对象，成员形状与 SKILL 状态机访问路径一致）：

| 场景 | mock 返回/异常 | SKILL 访问路径 |
|---|---|---|
| 正常成功 | `PSCustomObject` 含 `tag_name`(string) + `published_at`(ISO date) | L342 `$j.tag_name` / `$j.published_at` |
| API failure (404) | 异常 `Exception.Response.StatusCode = 404` | L362 |
| API failure (500) | 异常 `StatusCode = 500` | L365 |
| API failure (network) | 异常无 `.Exception.Response` | L367 else 分支 |

**对齐自检**：mock 函数库构造完成后，做一次 "contract → SKILL 提取表达式" 对齐自检，结果记录于 `lib/mock-contract-selfcheck.txt`。

#### Step 4: 生成提取清单

生成 `lib/extraction-manifest.json`，记录每个提取脚本的源行号范围与 SHA256。

**输出结果**:
- `.production-validation-v112-final/lib/step1.ps1` ~ `step5-full.ps1`（5 个提取脚本）
- `.production-validation-v112-final/lib/run-full-pipeline.ps1`
- `.production-validation-v112-final/lib/t3-mock-harness.ps1` / `t4-write-failure-harness.ps1` / `t5-housekeeping-harness.ps1`
- `.production-validation-v112-final/lib/create-fixture.ps1` / `lock-holder.ps1` / `mock-invoke-restmethod.ps1` / `extract-code.ps1`
- `.production-validation-v112-final/lib/extraction-manifest.json`
- `.production-validation-v112-final/lib/mock-contract-selfcheck.txt`
- `.production-validation-v112-final/phase-progress.json`

**证据要求**:
- `phase2-stdout.txt` / `phase2-stderr.txt` / `phase2-report.md`

**主 agent 审查点**:
- [ ] 确认 5 个 step 提取脚本 + harness + mock 工具全部按清单产出
- [ ] 确认 extraction-manifest.json 存在且非空
- [ ] 确认 mock-contract-selfcheck.txt 存在且记录了对齐验证结果
- [ ] 确认提取脚本与 SKILL-v1.12.md 原文一致（抽查 step1.ps1 含 PS7 检查 / step3.ps1 含 housekeeping try/catch）

**失败处理**: 代码提取与原文不一致 → 立即中止并标 BLOCKED。

---

### Phase 3: Test 1 PS7 强制 + Test 2 正常成功路径（硬门槛）

**前置条件**: Phase 2 完成，lib/ 全部工具就绪

**输入参数**:
- 测试目录: `.production-validation-v112-final/T1-PS7/`, `T2-success/`
- 脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`, `lib/run-full-pipeline.ps1`, `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### Test 1 — PS7 强制执行（Prompt §8 Test 1）

**目标**: 验证 `pwsh.exe` 能够正常执行 Skill，确认 PS7 版本检查生效，确认执行说明已明确绝对路径。

**执行**:
1. 使用 `pwsh.exe -NoProfile -NonInteractive -File lib/run-full-pipeline.ps1 *>&1 > T1-PS7/stdout.txt`（设置 `GITHUB_VERSION_MONITOR_BASE` 指向 T1-PS7 目录）
2. fixture：至少 2 个真实仓库

**验证项**:
```
$PSVersionTable.PSVersion.Major >= 7          — stdout 中有实际版本号
pwsh.exe 正常执行                              — 无解析错误
SKILL 执行说明明确绝对路径                     — diff-integrity.md 中 P1-c 已确认
正常启动                                      — BACKUP_OK| / FETCH_COMPLETE| 存在
```

**PASS 条件**（Prompt §8 Test 1）:
```
PS7 + 明确路径 + 正常启动
```

**额外验证**：PS7 版本检查在 PS < 7 时输出 `RUNTIME_ERROR|PowerShell 7.x required`（如环境允许，可选用 `powershell.exe` 执行 step1.ps1 验证拒绝行为；如 PS5.1 不可用则跳过此项并记录）

#### Test 2 — 正常成功路径（Prompt §8 Test 2）

**目标**: 使用真实生产结构执行一次正常成功流程。

**执行**:
1. 使用 `pwsh.exe -NoProfile -NonInteractive -File lib/run-full-pipeline.ps1 *>&1 > T2-success/stdout.txt`
2. fixture：至少 2 个真实仓库（如 `microsoft/vscode` + `torvalds/linux`）

**验证项**:
```
BACKUP_OK|                   — 存在
FETCH_COMPLETE|              — 存在
SUMMARY|                     — 存在
REVIEW_WRITE_OK|             — 存在（仅当本轮触发 review 时；条件化期望）
COMMIT_OK|                   — 存在
RUN_STATUS|success|          — count = 1
RUN_STATUS|failed|           — count = 0
lock released                 — run.lock 不存在
md updated                    — md-after 与 md-before 不同
result.json valid             — JSON 结构完整
主 md 没有损坏                — 表格行数 / repo 集合 / flag 合法
```

**证据要求**（T1/T2 均需）:
```
T*/before/ / after/ / stdout.txt / stderr.txt / test-report.md
md-before.md / md-after.md
result-before.json / result-after.json
sha256-before.txt / sha256-after.txt
lock-before.txt / lock-after.txt
```

**输出结果**:
- `.production-validation-v112-final/T1-PS7/`、`T2-success/` 目录及全部证据
- `.production-validation-v112-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 T1 stdout 中 PS7 版本号 >= 7 + 正常启动（BACKUP_OK| / FETCH_COMPLETE|）
- [ ] 核验 T2 stdout 中完整成功链 + `RUN_STATUS|success|` count = 1 + `RUN_STATUS|failed|` count = 0
- [ ] 核验 T2 lock-after 确认锁已释放
- [ ] 核验 T2 md-after 表格完整（行数 / repo 集合 / flag 合法）
- [ ] `REVIEW_WRITE_OK|` 为条件性检查（仅当 fixture 触发 review 时验证）

**失败处理**: T1/T2 任一 FAIL → 立即标记 PRODUCTION_NOT_READY 倾向，仍完成后续 Phase 保留证据。

---

### Phase 4: Test 3 API failure + Test 4 核心写入 failure（硬门槛）

**前置条件**: Phase 2 完成，mock 工具就绪

**输入参数**:
- 测试目录: `.production-validation-v112-final/T3-api-failure/`, `T4-write-failure/`
- 脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`, `lib/t3-mock-harness.ps1`, `lib/t4-write-failure-harness.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### Test 3 — API failure（Prompt §8 Test 3）

**目标**: 制造一个可控 API failure，验证 fail-safe 行为。

**构造方法**: mock harness 定义 mock `Invoke-RestMethod` 返回 404 异常（或 500 / network error），执行 step2 代码。

**期望行为链**:
```
API failure
    ↓
不能伪装 success
    ↓
保留上一轮有效状态（gitVer / gitDate / flag unchanged）
    ↓
明确 failed / appropriate status（review=true, RUN_STATUS|failed| 或正常流程中标注失败项）
```

**验证项**:
```
queryStatus != ok                              — mock 场景命中
gitVer unchanged / gitDate unchanged / flag unchanged
review=true                                    — API 失败项标记
RUN_STATUS|success|                             — count = 0（不能伪装成功）
主 md unchanged                                 — API 失败不写回
```

> **注意**：API failure 项保留上轮状态后，如其他仓库成功，整轮仍可 `RUN_STATUS|success|`（API 失败项保留状态是正常行为，不是整轮 failed）。Test 3 的重点是"不能伪装 success"——即 API 失败项的 gitVer/gitDate/flag 不被篡改为成功值。

**修正验证项**：
```
API 失败项 gitVer/gitDate/flag unchanged       — 核心 fail-safe
API 失败项 review=true                         — 如实标注
result.json 中失败项 status != ok              — 状态机正确分类
主 md 中失败项保持上轮值                        — 未被篡改
```

#### Test 4 — 核心写入 failure（Prompt §8 Test 4）

**目标**: 制造一个可控的核心写入失败，验证不产生半写主 md。

**构造方法**: 外部进程（`lock-holder.ps1`，`Start-Process -WindowStyle Hidden`）以 `FileShare::None` 锁住目标主 md，使 Step 5 `Move-Item` 无法替换；测试后终止持有进程。

**期望行为链**:
```
核心事务失败（Move-Item 被外部锁阻止）
    ↓
不产生半写主 md
    ↓
backup 保留
    ↓
不能伪装 success
    ↓
RUN_STATUS|failed|（明确失败终态）
```

**验证项**:
```
主 md unchanged                       — SHA256 before vs after 不变
tmp cleaned                           — md.tmp 被清理（外部进程终止后确认）
backup 保留                           — .monitor/backups/ 中备份存在
RUN_STATUS|failed|                    — count = 1
RUN_STATUS|success|                   — count = 0
COMMIT_OK|                             — count = 0
lock released                         — run.lock 不存在（锁释放路径正常）
```

**证据要求**（T3/T4 均需）:
```
T*/before/ / after/ / stdout.txt / stderr.txt / test-report.md
md-before.md / md-after.md
result-before.json / result-after.json
sha256-before.txt / sha256-after.txt
lock-before.txt / lock-after.txt
```
涉及文件锁额外需: `lock-holder-stdout.txt` / `lock-holder-stderr.txt`

**输出结果**:
- `.production-validation-v112-final/T3-api-failure/`、`T4-write-failure/` 目录及全部证据
- `.production-validation-v112-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 T3 API 失败项 gitVer/gitDate/flag unchanged + review=true + status != ok
- [ ] 核验 T4 stdout 中 `RUN_STATUS|failed|` count = 1 + `RUN_STATUS|success|` / `COMMIT_OK|` 不存在
- [ ] 核验 T4 SHA256 before/after 一致（主 md unchanged）
- [ ] 核验 T4 backup 保留
- [ ] 核验 T4 lock-after 确认锁已释放

**失败处理**: T3/T4 任一 FAIL → PRODUCTION_NOT_READY 倾向，仍完成后续 Phase 保留证据。

---

### Phase 5: Test 5 housekeeping failure（硬门槛，v1.12 新增重点）

**前置条件**: Phase 2 完成

**输入参数**:
- 测试目录: `.production-validation-v112-final/T5-housekeeping/`
- 脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`, `lib/t5-housekeeping-harness.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向 T5-housekeeping

**处理逻辑**:

#### Test 5 — housekeeping failure（Prompt §8 Test 5，v1.12 新增重点）

**目标**: 制造 backup/trash cleanup 失败，验证 housekeeping 失败不阻断核心版本监测。

**构造方法**: 在 Step 3 housekeeping 执行前，通过以下方式之一制造清理失败：
- 方案 A：将 `.monitor/trash/` 目录设为只读（`Set-ItemProperty -Path $trashDir -Name IsReadOnly -Value $true`），使 `Move-Item` 无法写入 trash 目录
- 方案 B：删除 `.monitor/backups/` 目录（使 `Get-ChildItem $backupDir` 失败）
- 方案 C：通过 ACL deny 拒绝对 `.monitor/backups/` 的写入权限

> **方案可行性评估**：
> - 方案 A：Windows 目录 ReadOnly 属性**不阻止**文件移动到目录内（`Move-Item` 需要对目标目录的写入权限，ReadOnly 属性不等于 ACL deny）——**不可行**
> - 方案 B：删除 backups 目录 → `Get-ChildItem` 抛 PathNotFound → v1.12 try/catch 捕获 → `HOUSEKEEPING_WARNING|` 输出 → 继续 ——**可行**
> - 方案 C：ACL deny → `Move-Item` 失败 → v1.12 try/catch 捕获 → `HOUSEKEEPING_WARNING|` 输出 → 继续 ——**可行，但需 ACL 还原**

**推荐方案 B**（最小副作用，无需 ACL 还原）：
1. 正常执行 Step 1-2（产生 result.json + backups）
2. Step 3 执行前：删除 `.monitor/backups/` 目录（记录操作）
3. 执行 Step 3（housekeeping try/catch 应捕获异常，输出 `HOUSEKEEPING_WARNING|`，继续执行）
4. 正常执行 Step 4-5
5. 验证整轮 `RUN_STATUS|success|`

**期望行为链**:
```
housekeeping failure（backups 目录不存在 → Get-ChildItem 失败）
    ↓
HOUSEKEEPING_WARNING|backup/trash cleanup failed: ...（v1.12 新增 try/catch 输出）
    ↓
继续核心流程（不 return）
    ↓
Step 4 / Step 5 正常执行
    ↓
RUN_STATUS|success|（核心业务未阻断）
```

**验证项**:
```
HOUSEKEEPING_WARNING|                    — 存在（v1.12 新增输出）
Step 3 未终止                              — 无 return / 无 RUNTIME_ERROR 因 housekeeping 失败
核心流程继续                              — FETCH_COMPLETE| / COMMIT_OK| 存在
RUN_STATUS|success|                       — count = 1（核心业务未阻断）
RUN_STATUS|failed|                        — count = 0
主 md updated                              — md-after 与 md-before 不同
lock released                              — run.lock 不存在
```

**同时验证 lock ownership / heartbeat 保护未被削弱**:
```
Step 3 heartbeat 正常执行                  — L437-444 heartbeat 代码未被修改
heartbeat 失败仍会终止整轮                 — P2 修改未触碰 heartbeat 逻辑
```

> heartbeat 未被削弱验证方法：确认 diff 中 Step 3 heartbeat 区域（L437-444）无修改（Phase 1 diff-integrity.md 已核验）；如需动态验证，可在独立测试中锁住 run.lock 验证 heartbeat 失败仍输出 `RUNTIME_ERROR|` + return。

**ACL 恢复步骤**（如使用方案 C）:
1. 构造前记录 `.monitor/backups/` 目录原始 ACL：`Get-Acl $backupDir | Export-Clixml T5/acl-before.xml`
2. 施加 deny 规则
3. 测试执行
4. 测试后还原：`Import-Clixml T5/acl-before.xml | Set-Acl $backupDir`
5. 验证还原成功

**证据要求**:
```
T5/before/ / after/ / stdout.txt / stderr.txt / test-report.md
md-before.md / md-after.md
result-before.json / result-after.json
sha256-before.txt / sha256-after.txt
lock-before.txt / lock-after.txt
```

**输出结果**:
- `.production-validation-v112-final/T5-housekeeping/` 目录及全部证据
- `.production-validation-v112-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 stdout 中 `HOUSEKEEPING_WARNING|` 存在（v1.12 新增输出）
- [ ] 核验 `RUN_STATUS|success|` count = 1（核心业务未阻断）
- [ ] 核验 `RUN_STATUS|failed|` count = 0
- [ ] 核验主 md updated（md-after ≠ md-before）
- [ ] 核验 lock-after 确认锁已释放
- [ ] 核验 heartbeat 区域未被修改（diff-integrity.md P2 审查确认）

**失败处理**: T5 FAIL → PRODUCTION_NOT_READY（housekeeping 仍阻断核心业务 = P2 修改无效 = P1 硬门槛违反）。

---

### Phase 6: Test 6 final status 语义（关键）

**前置条件**: Phase 1-5 全部完成，全部证据可用

**输入参数**:
- SKILL-v1.12.md 全文
- 全部前序 Phase 证据

**处理逻辑**:

#### Test 6 — final status 语义（Prompt §8 Test 6）

**目标**: 只验证核心执行路径的 `RUN_STATUS` 语义。不再执行大型 audit。

**6a. 正常路径**:
- 从 Test 2（Phase 3）stdout 中确认：
  ```
  RUN_STATUS|success| — 只出现一次
  ```

**6b. 一个真实 fatal path**:
- 从 Test 4（Phase 4）stdout 中确认：
  ```
  RUN_STATUS|failed| — 只出现一次
  ```

**6c. P3 审查结论确认**:
- 确认 Phase 1 diff-integrity.md 中 P3 审查节已逐个核对 6 条 fatal path
- 确认结论为"均不需要修改"（均有明确错误状态输出）
- 不再为覆盖所有历史静态路径重新执行大型 audit

**输出**:
- `.production-validation-v112-final/audit/final-status-audit.md`（仅正常路径 + 一个 fatal path 的 RUN_STATUS 计数 + P3 审查结论确认）

**主 agent 审查点**:
- [ ] 核验 T2 stdout 中 `RUN_STATUS|success|` count = 1
- [ ] 核验 T4 stdout 中 `RUN_STATUS|failed|` count = 1
- [ ] 核验 P3 审查结论已记录（6 条 fatal path 逐个核对）
- [ ] 确认未执行大型 audit（Prompt §8 Test 6："不要再为了覆盖所有历史静态路径重新执行大型 audit"）

**失败处理**: RUN_STATUS 重复/缺失 → 记录为 P1 发现。

---

### Phase 7: Self-Review（质量控制，Prompt §10）

**前置条件**: Phase 0-6 全部完成，全部证据可用

**输入参数**:
- 全部 Phase 0-6 证据
- SKILL-v1.12.md 原文
- Phase 0 SHA256 基线

**处理逻辑**:

独立 self-review。文件名带实际时间戳：`.selfreview/selfreview-v112-YYYYMMDD-HHMMSS.md`

**检查清单（12 项）**：

```
1.  被测对象是否真实为 v1.12               — 重算 SHA256 与 v112.sha256 比对
2.  SHA256 是否一致                         — v111/v112/state 三指纹重算比对
3.  是否修改过 v1.12                        — git status SKILL-v1.12.md 确认无意外修改
4.  是否复用了旧 PASS                       — 证据目录路径均在本轮 .production-validation-v112-final/ 下
5.  P1 修改是否生效                          — SKILL-v1.12.md 中 PS7 检查 / 显式路径 / PS7 ONLY 声明确认
6.  P2 修改是否生效                          — Step 3 housekeeping try/catch 包裹确认
7.  P3 审查是否完成                          — 6 条 fatal path 逐个核对结论确认
8.  Test 1-6 是否全部执行                   — 证据文件时间戳与内容为本轮新建
9.  是否存在证据与结论矛盾                  — 实际输出 vs 报告结论逐项核对
10. 是否存在 FAIL 被改写为 BLOCKED          — 同上
11. diff 是否包含非预期修改                 — 重算 v111/v112 SHA256 与基线比对；复核 v111-v112.diff hunk
12. 基线对象完整性                           — 重算 3 个 SHA256 与开工基线比对
```

**输出结果**:
- `.production-validation-v112-final/.selfreview/selfreview-v112-<实际时间戳>.md`
- `.production-validation-v112-final/phase-progress.json`

**主 agent 审查点**:
- [ ] 核验 self-review 12 项检查全部完成
- [ ] 核验 SKILL-v1.12.md SHA256 与 Phase 1 产出一致（未被修改）
- [ ] 核验 `EXECUTED = PASS + FAIL + BLOCKED` 守恒式成立
- [ ] 核验 self-review 文件名带实际时间戳

**失败处理**: self-review 发现问题 → 记录为发现项，不自动修复；严重问题 → 立即中止并标 BLOCKED。

---

### Phase 8: Final Report + Commit（收尾）

**前置条件**: Phase 0-7 全部完成

**输入参数**:
- 全部 Phase 0-7 证据
- self-review 报告

**处理逻辑**:

#### 8.1 生成最终报告（Prompt §10）

生成 `production-validation-report-v112-final.md`，报告必须包含：

```
1. 实际执行环境（PS 版本 / pwsh.exe 路径 / OS）
2. 实际绝对路径（Repository / Skill / .output / .monitor）
3. 实际 pwsh.exe / PS7 版本
4. 修改摘要（P1 / P2 / P3 逐项）
5. structural diff（v111 → v112 hunk 清单）
6. Test 1-6 实际结果
7. 每项 PASS/FAIL 的实际证据
8. 未测试项目
9. Deferred 项
10. Agent 自审结论
```

> **Agent 不得自行宣布 Production Gate OPEN**（Prompt §10）。报告只能提交事实和证据。最终 Production Gate 由 GPT 根据 SKILL-v1.12 + validation report + 实际 diff 重新审查。

#### 8.2 最终计数

```
EXECUTED = / PASS = / FAIL = / BLOCKED =
必须: PASS + FAIL + BLOCKED = EXECUTED
```

#### 8.3 最终判定逻辑

**PASS 条件**（Prompt §12 最终停止条件）：
```
Test 1-6 全部通过
+
核心业务逻辑正常
+
核心 failure 不伪装 success
+
状态文件安全
+
housekeeping 不阻断核心流程
+
PS7 强制执行
+
路径明确
```

**停止条件**：Test 1-6 全部通过 → **停止继续优化**。不因理论 edge case / 旧 audit 项 / 静态代码形式问题 / PS5.1 不兼容继续开启 v1.13。

#### 8.4 收尾动作

1. 汇总全部证据，生成最终报告
2. 基线对象完整性复核（SHA256 比对：SKILL-v1.11.md / SKILL-v1.12.md / 生产状态文件 开工 vs 收尾）
3. 入库 commit（文件范围显式列出）：
   - `SKILL-v1.12.md`
   - `.GPT/v1.12 最小修改与定向验证 Prompt.md`
   - `.production-validation-v112-final/` 全部证据目录
   - `.exec-plan/exec-plan-v1.12-a.md`（本执行计划）
   - `production-validation-report-v112-final.md`
   - commit message: `feat: refine skill runtime contract and housekeeping failure handling`
4. 环境还原确认（ACL 还原验证记录、文件锁/辅助进程终止确认）
5. **不删除 v1.11**（Prompt §11）
6. **不覆盖历史 validation report**（Prompt §11）

**输出结果**:
- `.production-validation-v112-final/production-validation-report-v112-final.md`
- `.production-validation-v112-final/phase-progress.json`
- git commit（文件范围显式列出）

**主 agent 审查点**:
- [ ] 核验最终报告包含 10 项必含内容
- [ ] 核验 `PASS + FAIL + BLOCKED = EXECUTED` 守恒式成立
- [ ] 核验 Test 1-6 结果与测试证据一致
- [ ] 核验报告未自行宣布 Production Gate OPEN
- [ ] 核验 SKILL-v1.12.md SHA256 收尾与 Phase 1 一致
- [ ] 核验 commit 文件范围与计划声明一致
- [ ] 核验未删除 v1.11 / 未覆盖历史 validation report

**失败处理**: 报告生成失败 → 检查证据完整性后重试；commit 失败 → 检查 git 状态后重试。

---

## 3. 禁止事项

```text
1.  禁止修改 .GPT/v1.12 最小修改与定向验证 Prompt.md（上游事实源）
2.  禁止触碰 .output/GitHub更新监测列表.md（生产状态文件）— 用 GITHUB_VERSION_MONITOR_BASE 隔离
3.  禁止复用历史 validation 目录中的旧产物作为本轮 PASS 证据
4.  禁止修改 SKILL-v1.11.md（基线文件，只读）
5.  禁止输出 GITHUB_TOKEN / Authorization / Cookie / 完整 secrets
6.  禁止为使任务通过而修改被测 SKILL 的测试逻辑
7.  禁止多 sub-agent 并行执行
8.  禁止 Verdict/结论由预期结果而非实际证据决定
9.  禁止将 BLOCKED 改写为 PASS
10. 禁止将 FAIL 改写为 BLOCKED
11. 禁止完整 SemVer 重写（Prompt §7 禁止 1）
12. 禁止增加 API 请求（Prompt §7 禁止 2）
13. 禁止扩大 review（Prompt §7 禁止 3）
14. 禁止重新设计 lock（Prompt §7 禁止 4）
15. 禁止为 PS5.1 修改 Skill（Prompt §7 禁止 5）
16. 禁止扩大 validation framework / 新增 T47+ 测试（Prompt §7 禁止 6）
17. 禁止由测试 harness 预先创建 .monitor
18. 禁止修改 harness 后不重新执行受影响测试而重标 PASS
19. 禁止机械补丁所有 return（Prompt §6："禁止机械补丁"）
20. 禁止删除 v1.11 / 禁止覆盖历史 validation report（Prompt §11）
```

---

## 4. 证据规则

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

1. **开工基线**：Phase 0 采集 `SKILL-v1.11.md` / `.output/GitHub更新监测列表.md` 的 SHA256 指纹。Phase 1 采集 `SKILL-v1.12.md` 的 SHA256。
2. **每个采集物必须有消费者**：Phase 0/1 的 SHA256 在 Phase 7 self-review 第 1/2/11/12 项复核比对。Phase 2 的 `extraction-manifest.json` 在 Phase 7 复核。
3. **派生物必须有 manifest**：`lib/*.ps1` 提取脚本在 Phase 2 生成 `extraction-manifest.json`。注入类派生物做受限 diff。

### 5.2 口径与引用规则

1. 所有数量词必须能指认事实源出处。
2. 旧报告/旧轮次结论只作信息参考；作设计依据前必须本轮独立验证。
3. 计划与上游文档的格式要求冲突时，保持上游字面格式、以附注形式补充信息。

---

## 6. 判定与收尾

### 6.1 审查门流程

```text
sub-agent 完成 → 产出 phase-progress.json + 证据文件
→ 主 agent 审查（status=completed？证据逐项核对审查点？）
→ PASS → 启动下一 Phase
→ FAIL → 不启动下一 Phase；按该 Phase 失败处理规则处理
```

### 6.2 审查规则

1. 主 agent 审查是**独立复核**：亲自读取证据文件核对，不采信 sub-agent 结论转述。
2. 审查点全部可判定；任一不满足 → 该 Phase 未通过。
3. 硬门槛 Phase 未通过 → 触发最终判定规则（仍完成后续 Phase 保留完整证据）。
4. **数字一致性**：`EXECUTED = PASS + FAIL + BLOCKED`。

### 6.3 最终判定逻辑

**PASS（Prompt §12 最终停止条件）**：

```
Test 1-6 全部通过
+
核心业务逻辑正常
+
核心 failure 不伪装 success
+
状态文件安全
+
housekeeping 不阻断核心流程
+
PS7 强制执行
+
路径明确
```

**FAIL**：Test 1-6 任一 FAIL。

**BLOCKED**：仅当 `FAIL = 0 / BLOCKED > 0`。

**判定规则**：
1. FAIL 不得改写为 BLOCKED；BLOCKED 不得改写为 PASS；旧证据不得冒充新证据。
2. Agent 不得自行宣布 Production Gate OPEN（Prompt §10）。最终 Production Gate 由 GPT 重新审查。

---

## 7. 最终原则（Prompt §13）

```text
Skill 是产品。
Validation 是验证手段。
不要让 Validation 反过来驱动 Skill 的复杂化。

本次目标不是：
  所有理论问题 PASS

而是：
  一个已经可用的 Skill
  + 少量真正有价值的可靠性修正
  + 足够证明这些修正有效的定向测试
  = v1.12

如果修改过程中发现某个问题实际上不影响：
  核心业务
  未来自动升级软件的可靠调用

则不要修。

优先停止，而不是继续增加工程量。
```

---

## 8. 质量控制：自我审查

本计划制定完成后，进行以下全面自我审查：

### A1 事实源与独立性
- [x] 唯一事实源已指定：`.GPT/v1.12 最小修改与定向验证 Prompt.md`
- [x] 每个设计决策能指认事实源出处（Prompt 章节号 + SKILL-v1.11.md 行号）
- [x] 旧轮次结论仅作信息参考；引用处有独立性声明（§0.6）
- [x] 枚举/数量词来自完整原文阅读（6 条 fatal path = v1.11 报告 G/H 节 + SKILL 行号直接阅读 / Test 1-6 = Prompt §8 / 3 类修改 = Prompt §4 P1/P2/P3）

### A2 模块化与串行
- [x] 模块总览表完整（9 个 Phase，Phase 0-8）；每模块输入封闭、输出清单化
- [x] 模块间仅通过产物文件传递状态
- [x] 单模块工作量在单次 sub-agent 会话预算内
- [x] 硬门槛模块显式标注（Phase 1/3/4/5）；第一（Phase 0）/倒数第二（Phase 7）/最后（Phase 8）模块职能正确
- [x] 禁止并行 + 每 Phase 单 sub-agent 已声明（§0.3）

### A3 可接续
- [x] phase-progress.json 结构与恢复原则已定义（§0.4）
- [x] 中断类型 × 检测 × 恢复策略表完整（4 类：LLM API 失败 / 网络波动 / 资源限制 / 上下文溢出）
- [x] 恢复不依赖会话记忆

### A4 分阶段验收
- [x] 每个 Phase 有审查点，全部可判定（存在/相等/包含/一致）
- [x] 条件化期望已标注（T2 `REVIEW_WRITE_OK|`、T1 PS5.1 验证拒绝行为）
- [x] 审查是独立复核（主 agent 亲读证据）
- [x] 独立复核模块检查集完整（Phase 7 含 12 项检查，含指纹复核、守恒核算）

### A5 可追溯
- [x] 开工基线指纹已安排（Phase 0 的 2 个 + Phase 1 的 1 个 SHA256）；每个采集物有消费者（Phase 7）
- [x] 派生物有 manifest（Phase 2 extraction-manifest.json）；注入类派生物有受限 diff 规则
- [x] 证据清单覆盖：输出/变更/外部调用/环境变更（§4）
- [x] 数字只有一个权威出处；守恒式已定义

### A6 技术可行性
- [x] 每个构造方法选项已评估平台可行性（T5 方案 A 不可行已标注 + 原因；方案 B/C 可行）
- [x] 环境变更类构造（ACL）带备份/还原步骤（T5 方案 C ACL 恢复 5 步）
- [x] 进程模型声明完整（§0.5）；同进程注入场景有 harness 设计
- [x] 替换体（mock）有逐场景 contract + 对齐自检

### A7 隔离与安全
- [x] 生产对象隔离机制明确（GITHUB_VERSION_MONITOR_BASE）且已写入禁止事项
- [x] 替换方案优先无系统级变更（函数覆盖 > 文件锁 > ACL）；有变更则有还原验证
- [x] secret 输出禁止已列入（§3 第 5 条、§4）
- [x] `.monitor` 不得预创建已列入禁止事项（§3 第 17 条）

### A8 判定与收尾
- [x] 无上游规则冲突（v1.12 Prompt 无 PS5.1 兼容性要求，无双维度计数问题）
- [x] 结论模板与上游格式对齐（Phase 8 报告 10 项与 Prompt §10 一致）
- [x] 执行摘要模板每一项映射到实际安排的工作
- [x] commit 文件范围显式列出（Phase 8.4）；commit message 要素完整
- [x] 修订日志格式就绪（§9）

### A9 存储路径与命名准确性
- [x] 本计划存储：`.exec-plan/exec-plan-v1.12-a.md`（项目版本 v1.12 + 计划版本 a，符合命名规范 exec-plan-{项目版本号}-{执行计划版本号}.md）
- [x] Clean-Room 目录：`.production-validation-v112-final/`
- [x] 最终报告：`production-validation-report-v112-final.md`
- [x] self-review：`.selfreview/selfreview-v112-YYYYMMDD-HHMMSS.md` 带实际时间戳
- [x] diff 产物：`v111-v112.diff` + `v111.sha256` / `v112.sha256` / `state.sha256`

### A10 静默执行合规性
- [x] 全部 9 Phase 后台静默模式执行声明（§0.8）
- [x] 前台场景声明：不存在；环境限制导致无法静默时标 BLOCKED 而非切换前台

---

## 9. 修订日志

### exec-plan-v1.12-a（2026-09-10，初版制定）

**审计来源**: 无（初版，待用户审核与独立审计）

| 审计项 | 严重性 | 采纳/驳回 | 修订内容 | 理由 |
|---|---|---|---|---|
| — | — | — | 初版制定 | 基于 v1.12 Prompt 13 节 + SKILL-v1.11.md 直接阅读（行号 Select-String 双源核实）+ v1.11 验证报告（信息参考）+ `.Template/exec-plan-tmpl-v1.md` 模板 + exec-plan-v1.11-c 结构基线 |

**驳回项**: 无

---

## 附录 A：上游文档逐节对照表（Prompt 13 节全覆盖）

| Prompt 章节 | 对应 Phase / 章节 | 覆盖说明 |
|---|---|---|
| §0 任务定位 | 全局 + Phase 0 | v1.11 基线 / 最小修改 / 不扩展 |
| §1 强制执行环境 | Phase 0 + §0.7 | PS7 ONLY / pwsh.exe / 版本检查 |
| §2 强制路径 | Phase 1 P1-c + §0.5 | 绝对路径 / GITHUB_VERSION_MONITOR_BASE 隔离 |
| §3 修改前必做 | Phase 0 | 读取 SKILL-v1.11 / v111 report / readme |
| §4 P1 PS7 + 显式路径 | Phase 1 Step 2 | 版本号 / PS7 ONLY / §2 路径 / Step 1 PS7 检查 |
| §5 P2 housekeeping | Phase 1 Step 3 | Step 3 try/catch / heartbeat 不修改 |
| §6 P3 RUN_STATUS 审查 | Phase 1 Step 4 + §0.2 P3 | 6 条 fatal path 逐个审查 / 禁止机械补丁 |
| §7 禁止的修改 | §3 禁止事项 | 6 项禁止（SemVer / API / review / lock / PS5.1 / validation framework） |
| §8 定向测试计划 | Phase 3-6 | Test 1-6 逐项 |
| §9 Validation 禁止行为 | §3 + Phase 6 | 不扩大任务 / Known/Deferred 记录 |
| §10 Agent 自审 | Phase 7-8 | 报告 10 项 / 不得宣布 Production Gate |
| §11 Git 要求 | Phase 0 + Phase 8 | git status / git diff / commit message / 不删 v1.11 |
| §12 最终停止条件 | Phase 8.3 | Test 1-6 全通过 → 停止 |
| §13 核心原则 | §7 | Skill 是产品 / 优先停止 |

---

## 附录 B：本计划关键设计决策

| 编号 | 决策 | 理由 |
|---|---|---|
| D1 | P3 结论为 6 条 fatal path 均不修改 | 逐个直接阅读 SKILL-v1.11.md L254/L320/L406/L412/L444/L529，均有明确错误状态输出（`RUNTIME_ERROR|` 或 `PARSE_ERROR|`），不属于"没有明确最终状态"；Prompt §6 要求"只有第 1 类才需要保证最终状态语义" |
| D2 | Test 5 推荐方案 B（删除 backups 目录） | 方案 A（ReadOnly）不可行（Windows 目录 ReadOnly 不阻止文件移动）；方案 B 最小副作用，无需 ACL 还原；v1.12 try/catch 捕获 `Get-ChildItem` PathNotFound 异常 |
| D3 | 不设 PS5.1 兼容性测试 | v1.12 Prompt §7 禁止 5："PS5.1 完全忽略"；不作为 compatibility target / Production Gate |
| D4 | Test 6 不执行大型 audit | Prompt §8 Test 6："不要再为了覆盖所有历史静态路径重新执行大型 audit"；仅验证正常路径 success=1 + 一个 fatal path failed=1 |
| D5 | Phase 数 9 个（vs v1.11 的 14 个） | v1.12 是最小修改 + 定向验证（Prompt §0："不重复 v1.11 的完整 4-5 小时认证"）；Test 1-6 仅 6 项测试 vs v1.11 的 T38 六子测试 + T22/T23/T37/T39/T43/T46/T04/T26/T18 等 |
| D6 | Agent 不得宣布 Production Gate OPEN | Prompt §10 明确要求；报告只提交事实和证据；最终由 GPT 重新审查 |

---

## 附录 C：裁剪声明

本计划为 **M 型（中）**，依据：

- Phase 数：9 个（Phase 0-8；M 型 6-8 范围，略超因 Test 1-6 需独立 Phase）
- §0.6 独立性原则：保留全文
- §0.4 断点机制：完整 progress.json + 恢复原则
- 模块骨架：标准三段（Phase 0 基线 / Phase 7 复核 / Phase 8 收尾）+ 硬门槛分级（Phase 1/3/4/5）
- Phase 7 独立复核：简化检查集（12 项，M 型 4-6 项标准，因 P1/P2/P3 三类修改需逐项验证故扩展至 12）
- §6.3 双维度计数：不适用（v1.12 无 PS5.1 兼容性要求，无双维度冲突）
- 独立审计轮：建议

**裁剪红线确认**（以下均未裁剪）：
- 禁止事项（§3）：20 条，不为空
- 开工基线与指纹复核（Phase 0 + Phase 7）：完整
- 判定守恒式（§6.2/§6.3）：已定义
- 修订日志（§9）：初版已建
