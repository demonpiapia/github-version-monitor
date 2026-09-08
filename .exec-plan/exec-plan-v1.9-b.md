# SKILL-v1.9 定向最终验证 — 执行计划

> **版本**: exec-plan-v1.9-b（基于 exec-plan-v1.9-a 修订，纳入 CodeBuddy 独立审计结论）
> **制定日期**: 2026-09-08
> **依据**: `.GPT/Production Validation Prompt — SKILL-v1.9 Targeted Final Validation.md`（唯一事实源）
> **被测对象**: `SKILL-v1.9.md`
> **执行模式**: 单一子 agent 串行执行，禁止任何形式的多 sub agent 并行
> **生产主运行环境**: Windows + PowerShell 7.x
> **兼容性回归环境**: PowerShell 5.1（不作为当前生产准入主环境）
> **修订记录**: 见 §11 修订日志

---

## 0. 计划总览

### 0.1 核心目标

v1.8 已通过正常提交、PS7/PS5.1 header compatibility、核心状态机等测试，但发现 3 个 P2[^1]：

```
T38: Step 4 result.review.tmp 写入异常 → 异常冒泡 → lock 残留
T22: Step 5 md.tmp 创建/写入异常 → 异常冒泡 → lock 残留
T23: Step 5 Move-Item 原子替换异常 → tmp 残留 → lock 残留
```

[^1]: Prompt §0 列 3 个 P2。v1.8 报告 L.2 正式计数 P2=2（T38+T23），因 T22-v18 测试结论为 PASS。本计划沿用 Prompt 口径"3 个 P2"，但注明 v1.8 报告实际 P2=2。

v1.9 的唯一修复目标：上述异常不污染主状态 → 清理能够安全清理的 tmp → 正确处理 lock → 输出明确失败状态 → 不得伪装 success。

### 0.2 执行架构

```
Phase 0 (sub-agent) → 主 agent 审查 → Phase 1 (sub-agent) → 主 agent 审查 → ... → Phase 8 (sub-agent) → 主 agent self-review → Phase 9 (主 agent)
```

- **严格串行**：下一 Phase 仅在上一 Phase 的主 agent 审查通过后启动
- **单一 sub-agent**：每个 Phase 派遣且仅派遣一个 sub-agent 执行
- **禁止并行**：任何时刻最多一个 sub-agent 在运行

### 0.3 中断接续方案

| 中断类型 | 检测方式 | 恢复策略 |
|---|---|---|
| LLM API 调用失败 | sub-agent 无返回或返回错误 | 主 agent 重试同一 Phase，传入 `resume_from` 参数指向已完成的步骤 |
| 网络波动 | GitHub API 调用超时/失败 | 步骤内退避重试（max_retries=3），仍失败则标记 BLOCKED |
| 资源限制 | sub-agent 输出截断/不完整 | 主 agent 检查已产出证据文件，从断点继续 |
| 子 agent 上下文溢出 | sub-agent 返回不完整结果 | 主 agent 核验已生成证据，拆分剩余工作到新 sub-agent |

**断点保存机制**：每个 Phase 完成后，sub-agent 须在测试目录下生成 `phase-progress.json`，记录：

```json
{
  "phase": "Phase1",
  "start_time": "2026-09-08T12:00:00Z",
  "end_time": "2026-09-08T12:30:00Z",
  "status": "completed|partial|failed",
  "completed_steps": ["step1", "step2"],
  "pending_steps": [],
  "evidence_files": ["phase1-report.md", "v18.sha256"],
  "next_phase": "Phase2"
}
```

主 agent 在启动下一 Phase 前读取此文件，确认状态为 `completed` 后方可继续。若 `partial`，则向新 sub-agent 传入 `resume_from` 参数。

### 0.4 测试隔离机制 [M2 修订]

所有测试通过 `GITHUB_VERSION_MONITOR_BASE` 环境变量实现 fixture 隔离。SKILL-v1.9 每个 step 均支持此变量（SKILL L162/240/431/473/518）。

- 每个测试子目录作为独立 base 目录
- 通过 `$env:GITHUB_VERSION_MONITOR_BASE = '<test-dir>'` 指向测试目录
- `.monitor/` 由 Step 1 在 base 目录下动态创建（Prompt §2 要求运行态在测试目录重新生成）[M7 修订]
- `.output/GitHub更新监测列表.md` 使用 fixture 副本，不触碰生产文件

**Mock 重定向机制**（用于 T02/T04/T05/T08 状态机测试）[M2 修订]：

SKILL 中 API URL 硬编码为 `https://api.github.com`（SKILL L340/478），无 base 覆盖机制。测试采用 **PowerShell 函数覆盖** 方案：
1. 提取 step2.ps1 代码原样保存（不修改）
2. 测试 harness 在 dot-source step2.ps1 前，先定义 mock `Invoke-RestMethod` 函数覆盖内置 cmdlet
3. Mock 函数根据测试场景返回受控 HTTP 响应（状态码 + headers + body）
4. 此方案不修改被测代码，仅在运行时注入函数覆盖

**T46 运行目录**：T46 测试在 `.production-validation-v19-final/T46/` 目录下运行，通过 `GITHUB_VERSION_MONITOR_BASE` 指向该目录，不触碰生产根目录 [M2 修订]。

---

## 1. 模块分解

### 模块总览表

| Phase | 模块名 | 输入 | 输出 | 优先级 |
|---|---|---|---|---|
| 0 | Clean-Room + Git/SHA256 + 被测对象纳入 git | SKILL-v1.8.md, SKILL-v1.9.md, .output/...md | 目录树 + 3 个 SHA256 文件 + git staging | 基础 |
| 1 | Diff Integrity + 代码提取 + 提取清单 | v1.8/v1.9 SHA256 + 两文件 | diff-integrity.md + lib/*.ps1 + extraction-manifest.json | 基础 |
| 2 | T22/T23/T38 — 异常路径修复验证 | lib/step4.ps1, lib/step5-full.ps1, fixture | 3 个测试目录 + 证据 | **硬门槛** |
| 3 | T37 — 正常成功回归 | lib/step1-5.ps1, fixture | 测试目录 + 证据 | **硬门槛** |
| 4 | T39 — Commit 成功 + 锁释放失败 | lib/step5-t39-harness.ps1, fixture | 测试目录 + 证据 | **硬门槛** |
| 5 | T43 — 全管线 + T46 — 路径契约 | fixture（6 场景）| 2 个测试目录 + 证据 | **关键** |
| 6 | 状态机 + Schema + Lock 回归 | lib/step2.ps1, fixture | 多个测试目录 + 证据 | 中 |
| 7 | PS5.1 兼容性回归 | lib/mock-listener.ps1, PS5.1 | 2 个测试目录 + 证据 | 兼容 |
| 8 | Self-Review | 全部 Phase 0-7 证据 | selfreview.md | 质量控制 |
| 9 | Final Report + Commit | 全部证据 | production-validation-report-v19-final.md | 收尾 |

---

## 2. 各 Phase 详细规格

---

### Phase 0: Clean-Room + Git/SHA256 + 被测对象纳入 git

**子 agent 输入参数**:
- 项目根目录: `d:\AI\Workspace\automatic\github-version-monitor`
- 测试目录: `.production-validation-v19-final/`
- 被测文件: `SKILL-v1.8.md`, `SKILL-v1.9.md`, `.output/GitHub更新监测列表.md`

**处理逻辑**:
1. 创建 `.production-validation-v19-final/` 目录树：
   ```
   .production-validation-v19-final/
   ├── lib/
   ├── T22/
   ├── T23/
   ├── T37/
   ├── T38/
   ├── T39/
   ├── T43/
   ├── T46/
   ├── T02/
   ├── T04-PS7/
   ├── T04-PS5.1/
   ├── T05-PS7/
   ├── T05-PS5.1/
   ├── T08/
   ├── T14/
   ├── T15/
   ├── T16/
   ├── T17/
   ├── T18/
   ├── T19/
   ├── schema/
   ├── lock-concurrency/
   ├── lock-ownership/
   ├── lock-stale-alive/
   ├── lock-stale-dead/
   ├── runtime-error-contract/
   └── phase-progress.json
   ```
   > **`.monitor/` 不在目录树中预创建**：由 Step 1 在每个测试的 base 目录下动态创建。[M7]

2. 禁止复用 `.production-validation/`、`.production-validation-v17-final/`、`.production-validation-v18-final/` 中的实际测试状态作为当前 PASS 证据

3. 计算 3 个文件 SHA256：
   ```powershell
   Get-FileHash .\SKILL-v1.8.md -Algorithm SHA256
   Get-FileHash .\SKILL-v1.9.md -Algorithm SHA256
   Get-FileHash .\.output\GitHub更新监测列表.md -Algorithm SHA256
   ```
   保存为 `v18.sha256`、`v19.sha256`、`state.sha256`

4. **将被测对象纳入 git** [M5 修订]：
   - `SKILL-v1.9.md` 当前为 git untracked（`git ls-files` 无输出）
   - 执行 `git add SKILL-v1.9.md` 将其纳入版本控制
   - Prompt §2 要求"从当前 Git repository 获取 SKILL-v1.9.md"，§26 要求"Git repository = 唯一事实源"
   - 此操作不修改文件内容，仅纳入版本跟踪

**输出结果**:
- `.production-validation-v19-final/v18.sha256`
- `.production-validation-v19-final/v19.sha256`
- `.production-validation-v19-final/state.sha256`
- `.production-validation-v19-final/phase-progress.json`
- `SKILL-v1.9.md` 已 `git add`（staged）

**主 agent 审查点**: 确认 3 个 SHA256 文件存在且内容非空；确认目录树结构完整；确认 `git status` 显示 `SKILL-v1.9.md` 已 staged。

---

### Phase 1: Diff Integrity + 代码提取 + 提取清单

**子 agent 输入参数**:
- 测试目录: `.production-validation-v19-final/`
- v1.8 SHA256: 从 Phase 0 产出读取
- v1.9 SHA256: 从 Phase 0 产出读取
- 源文件: `SKILL-v1.8.md`, `SKILL-v1.9.md`

**处理逻辑**:

#### Step 1: 生成 diff

```powershell
git diff --no-index SKILL-v1.8.md SKILL-v1.9.md > .production-validation-v19-final/v18-v19.diff
```

#### Step 2: Diff 完整性分析

必须确认 v1.9 保留 v1.8 的全部关键能力（逐项显式核验，共 28 项）[L1 修订]：

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

特别检查：不得因 v1.9 修复异常路径而删除任何 v1.8 已验证能力。

#### Step 3: 禁止项检查

确认以下内容不存在于 v1.9 diff 中：

```
mock URL
forced success
test-only branch
debug bypass
hardcoded token
hardcoded test repo
skip lock
skip schema
skip review
skip commit
```

#### Step 4: 从 SKILL-v1.9.md 提取 PowerShell 代码块

逐字提取，禁止修改被测代码。提取的脚本仅用于测试执行环境控制，不改变逻辑：

- `lib/step1.ps1` — Step 1（状态检查 + 锁 + 备份）
- `lib/step2.ps1` — Step 2（解析 + 查询 + 状态机 + 统计）
- `lib/step3.ps1` — Step 3（备份清理）
- `lib/step4.ps1` — Step 4（复核）
- `lib/step5-full.ps1` — Step 5 完整（提交 + 锁释放 + RUN_STATUS）

> **注意**：SKILL Step 6 是 agent 汇报模板（SKILL L655），无 PowerShell 代码块，不需要提取。计划中"完整 Step 1→6"指 Step 1→5 代码执行 + Step 6 汇报模板。[L9]

#### Step 5: 创建 T39 专用 harness 脚本 [H1 修订]

- `lib/step5-t39-harness.ps1` — T39 同进程测试 harness

**设计原因**：SKILL Step 5 中 `$commitSucceeded`（L617/623）和 `$lockReleased`（L634/640）是同进程局部变量。若拆分为两个独立脚本通过 `pwsh -File` 执行，跨进程无法传递变量，导致测试失去区分度。

**harness 机制**：
1. 将 Step 5 代码嵌入单个脚本（dot-source 或内联）
2. 执行至 Move-Item 成功后（`$commitSucceeded=$true` + `COMMIT_OK|`）
3. 在同进程中修改锁文件 PID 为 999999
4. 继续执行锁释放部分（ownership 校验失败 → `RUNTIME_ERROR|` + `RUN_STATUS|failed|`）
5. 所有变量在同一进程作用域内可用

#### Step 6: 创建测试工具

- `lib/run-full-pipeline.ps1` — 串行执行 step1→step5-full
- `lib/mock-listener.ps1` — HTTP 模拟监听器（用于状态机测试的 mock `Invoke-RestMethod` 覆盖函数）
- `lib/create-fixture.ps1` — fixture 生成工具
- `lib/extract-code.ps1` — 代码提取工具

#### Step 7: 生成提取清单 [L8 修订]

生成 `lib/extraction-manifest.json`，记录每个提取脚本的源行号范围与 SHA256：

```json
{
  "source_file": "SKILL-v1.9.md",
  "source_sha256": "<v19.sha256 值>",
  "extractions": [
    {
      "file": "step1.ps1",
      "source_lines": "158-229",
      "sha256": "<提取文件 SHA256>"
    },
    ...
  ]
}
```

此清单供 Phase 8 self-review 验证提取脚本与原文一致性。

> **stdout 捕获策略** [M3 修订]：v1.8 报告 N.2 记录 `run-full-pipeline.ps1` 在 `-File` 模式下 stdout 未正确透传。T37/T43 不依赖 `run-full-pipeline.ps1` 单次执行捕获 stdout，改为逐 step 独立执行（`pwsh -File step1.ps1` → 捕获 stdout → `pwsh -File step2.ps1` → 捕获 stdout → ...），最终拼接为完整 stdout.txt。`run-full-pipeline.ps1` 仅作为便捷工具保留。

**输出结果**:
- `.production-validation-v19-final/v18-v19.diff`
- `.production-validation-v19-final/diff-integrity.md`
- `.production-validation-v19-final/lib/step1.ps1` ~ `step5-full.ps1`
- `.production-validation-v19-final/lib/step5-t39-harness.ps1`
- `.production-validation-v19-final/lib/run-full-pipeline.ps1`
- `.production-validation-v19-final/lib/mock-listener.ps1`
- `.production-validation-v19-final/lib/create-fixture.ps1`
- `.production-validation-v19-final/lib/extract-code.ps1`
- `.production-validation-v19-final/lib/extraction-manifest.json`
- `.production-validation-v19-final/phase-progress.json`

**主 agent 审查点**: 确认 diff-integrity.md 中 28 项能力逐项核验完成；确认 9 项禁止项检查完成；确认 5 个 step 脚本 + 1 个 harness + 4 个工具脚本提取完成且未修改原文；确认 extraction-manifest.json 存在且非空。

---

### Phase 2: T22/T23/T38 — 异常路径修复验证（硬门槛）

**子 agent 输入参数**:
- 测试目录: `.production-validation-v19-final/`
- 提取的脚本: `lib/step4.ps1`, `lib/step5-full.ps1`, `lib/step5-t39-harness.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### T38-v19 — review 写入失败（Step 4 result.review.tmp）

**构造方法**: 在 Step 4 执行前，使 `result.review.tmp` 无法被 `Set-Content` 写入或原子替换失败。[L4 修订]

方法选项（sub-agent 选择其一，不得修改 SKILL）：
- 预创建 `result.review.tmp` 文件并以 `[System.IO.File]::Open()` 独占锁定（`FileShare::None`），阻止 `Set-Content` 覆盖
- 通过 ACL deny 拒绝当前用户对 `.monitor` 目录的 CreateFiles 权限
- **注意**：Windows `ReadOnly` 属性**不阻止**文件创建/覆盖，不可作为构造方法

**验证项**:
```
result.json unchanged       — SHA256 before vs after 不变
stats unchanged
items unchanged
tmp cleaned                 — result.review.tmp 不残留
lock released               — run.lock 不存在或 PID 不匹配
REVIEW_WRITE_ERROR|         — 输出中存在
RUN_STATUS|failed|          — 输出中存在
no COMMIT_OK                — 输出中不存在
no RUN_STATUS|success|      — 输出中不存在
```

**重点**: 异常必须经过明确错误分支（`REVIEW_WRITE_ERROR|`），而不是直接退出脚本导致执行上下文异常终止。

**证据要求** [L10 修订]：
```
T38/before/
T38/after/
T38/stdout.txt
T38/stderr.txt
T38/test-report.md
T38/result-before.json
T38/result-after.json
T38/md-before.md            — 主 md before（确认未被修改）
T38/md-after.md             — 主 md after
T38/sha256-before.txt       — 含 main md + result.json + tmp 三者 SHA256
T38/sha256-after.txt        — 含 main md + result.json + tmp 三者 SHA256
T38/lock-before.txt
T38/lock-after.txt
```

#### T22-v19 — md 临时文件写入失败（Step 5 $md.tmp 创建/写入失败）

**构造方法**: 使 `$md.tmp`（即 `GitHub更新监测列表.md.tmp`）创建或写入失败。[L4 修订]

方法选项：
- 通过 ACL deny 拒绝当前用户对 `.output` 目录的 CreateFiles 权限
- 以 `[System.IO.File]::Open()` 独占锁定 `.output` 目录（`FileShare::None`）
- **注意**：Windows `ReadOnly` 属性**不阻止**文件创建，不可作为构造方法

**验证项**:
```
主 md unchanged             — SHA256 before vs after 不变
tmp 不产生错误残留          — md.tmp 不残留
lock released               — run.lock 不存在或 PID 不匹配
RUN_STATUS|failed|          — 输出中存在
no COMMIT_OK                — 输出中不存在
no RUN_STATUS|success|      — 输出中不存在
```

**重点**: 异常必须被捕获（`try/catch`），不能直接冒泡导致执行上下文异常终止。v1.9 的修复点在于 Step 5 写入失败后清理 tmp + 释放 lock + 输出 `RUN_STATUS|failed|`。

**证据要求** [L10 修订]：
```
T22/before/
T22/after/
T22/stdout.txt
T22/stderr.txt
T22/test-report.md
T22/md-before.md
T22/md-after.md
T22/result-before.json      — result.json before（确认未被修改）
T22/result-after.json       — result.json after
T22/sha256-before.txt       — 含 main md + result.json + tmp 三者 SHA256
T22/sha256-after.txt        — 含 main md + result.json + tmp 三者 SHA256
T22/lock-before.txt
T22/lock-after.txt
```

#### T23-v19 — md 原子替换失败（Step 5 Move-Item 失败）

**构造方法**: 先创建 `GitHub更新监测列表.md.tmp`，然后使 `Move-Item -Path $tmp -Destination $md -Force` 真实失败。

方法选项：
- 对目标 `GitHub更新监测列表.md` 设置外部文件锁：使用 PowerShell `[System.IO.File]::Open()` 以 `FileShare::None` 锁住目标文件，使 Move-Item 无法替换
- 文件锁通过 `Start-Process -WindowStyle Hidden` 在后台进程中持有，测试完成后终止

**验证项**:
```
主 md unchanged             — SHA256 before vs after 不变
tmp = cleaned               — md.tmp 被清理（如 v1.9 的错误策略明确允许保留则按 SKILL 实际 contract 判断）
lock = released             — run.lock 不存在或 PID 不匹配
COMMIT_OK = absent          — 输出中不存在
RUN_STATUS|failed| = present — 输出中存在
RUN_STATUS|success| = absent — 输出中不存在
```

**特别注意**: 如果 v1.9 的具体错误策略明确允许 tmp 保留，必须严格按照 SKILL 实际 contract 判断，不能自行假设。

**证据要求** [L10 修订]：
```
T23/before/
T23/after/
T23/stdout.txt
T23/stderr.txt
T23/test-report.md
T23/md-before.md
T23/md-after.md
T23/result-before.json      — result.json before（确认未被修改）
T23/result-after.json       — result.json after
T23/sha256-before.txt       — 含 main md + result.json + tmp 三者 SHA256
T23/sha256-after.txt        — 含 main md + result.json + tmp 三者 SHA256
T23/lock-before.txt
T23/lock-after.txt
```

**早期判定**: T22/T23/T38 任一 FAIL → 立即标记 PRODUCTION_NOT_READY 倾向，但仍完成后续测试以保留完整证据。

**输出结果**:
- `.production-validation-v19-final/T38/` 目录及全部证据
- `.production-validation-v19-final/T22/` 目录及全部证据
- `.production-validation-v19-final/T23/` 目录及全部证据
- `.production-validation-v19-final/phase-progress.json`

**主 agent 审查点**: 逐个核验 T22/T23/T38 的 stdout.txt 中是否出现预期的 `REVIEW_WRITE_ERROR|`/`RUN_STATUS|failed|` 且不出现 `RUN_STATUS|success|`；核验 SHA256 before/after 一致；核验 lock-after 确认锁已释放；核验 sha256 文件覆盖 main md + result.json + tmp 三者。

---

### Phase 3: T37 — 正常成功回归（硬门槛）

**子 agent 输入参数**:
- 测试目录: `.production-validation-v19-final/`
- 提取的脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向 T37 测试子目录

**处理逻辑**:

#### T37-v19 — 正常提交 → RUN_STATUS|success|

必须确认 v1.9 修复没有破坏正常成功路径。

**Fixture**: 至少 2 个真实仓库（如 `microsoft/vscode` localVer=1.0.0 + `torvalds/linux` localVer=6.5.0），确保能触发 review 的仓库。

**执行**: 在 PS7 中运行完整 Step 1→5 代码 + Step 6 汇报模板。[L9]

> **stdout 捕获策略** [M3 修订]：不依赖 `run-full-pipeline.ps1` 单次执行，改为逐 step 独立执行并捕获 stdout：
> 1. `pwsh -NoProfile -NonInteractive -File step1.ps1 *>&1 > T37/stdout-step1.txt`
> 2. `pwsh -NoProfile -NonInteractive -File step2.ps1 *>&1 > T37/stdout-step2.txt`
> 3. ... 以此类推
> 4. 最终拼接为 `T37/stdout.txt`

**验证项**:
```
BACKUP_OK|                  — 输出中存在
FETCH_COMPLETE|             — 输出中存在
SUMMARY|                    — 输出中存在
REVIEW_WRITE_OK|            — 输出中存在（仅当本轮触发 review 时）[L3]
COMMIT_OK|                  — 输出中存在
RUN_STATUS|success|         — 输出中存在
lock released               — run.lock 不存在
md updated                  — md-after 与 md-before 不同（版本号已刷新）
result.json valid           — JSON 结构完整、stats/items/review 字段存在
```

**硬门槛**: 如果出现 `COMMIT_OK|` + `RUN_STATUS|failed|` → FAIL + P1 + PRODUCTION_NOT_READY。

**证据要求**:
```
T37/before/
T37/after/
T37/stdout.txt              — 拼接的完整 stdout
T37/stdout-step1.txt ~ stdout-step5.txt  — 各 step 独立 stdout [M3]
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
- `.production-validation-v19-final/T37/` 目录及全部证据
- `.production-validation-v19-final/phase-progress.json`

**主 agent 审查点**: 核验 stdout.txt 中 `BACKUP_OK|` → `FETCH_COMPLETE|` → `SUMMARY|` → `COMMIT_OK|` → `RUN_STATUS|success|` 完整链；核验 lock-after 确认锁已释放；`REVIEW_WRITE_OK|` 为条件性检查（仅当 fixture 触发 review 时验证）。[L3]

---

### Phase 4: T39 — Commit 成功 + 锁释放失败（硬门槛）

**子 agent 输入参数**:
- 测试目录: `.production-validation-v19-final/`
- 提取的脚本: `lib/step5-t39-harness.ps1`（同进程 harness）[H1]
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向 T39 测试子目录

**处理逻辑**:

#### T39-v19 — commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|

**构造方法** [H1 修订]：

使用 `lib/step5-t39-harness.ps1` 在**同一进程**内执行以下步骤：
1. 正常执行 Step 1→4，确保 `result.json` 就绪
2. 执行 Step 5 代码至 Move-Item 成功 → `$commitSucceeded=$true` → 输出 `COMMIT_OK|`
3. 在同进程中修改锁文件 PID 为 999999（`Set-Content $lockPath -Value 'pid=999999;...'`）
4. 继续执行锁释放部分：锁内 PID (999999) ≠ 当前 PID → ownership 校验失败 → `$lockReleased=$false`
5. 最终判定：`$commitSucceeded=$true` AND `$lockReleased=$false` → `RUN_STATUS|failed|`

> **设计说明**：v1.8 计划使用 `step5-commit.ps1` + `step5-lockrelease.ps1` 两个独立脚本，但 `pwsh -File` 模式下每脚本独立进程，`$commitSucceeded` 等局部变量无法跨进程传递。本计划改用同进程 harness，确保变量在 Step 5 的 commit 段和 lock-release 段之间正确传递，测试才真正验证 invariant 4 的语义。

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

**证据要求** [L11 修订]：
```
T39/before/
T39/after/
T39/stdout.txt
T39/stderr.txt
T39/test-report.md
T39/lock-before.txt           — 测试前锁状态
T39/lock-after-modify.txt     — PID 修改后、锁释放尝试前的锁状态 [L11]
T39/lock-after.txt            — 最终锁状态（锁仍存在，未释放）
T39/result-before.json
T39/result-after.json
```

**输出结果**:
- `.production-validation-v19-final/T39/` 目录及全部证据
- `.production-validation-v19-final/phase-progress.json`

**主 agent 审查点**: 核验 stdout.txt 中 `COMMIT_OK|` 存在但 `RUN_STATUS|success|` 不存在；核验 `RUN_STATUS|failed|` 存在；核验 lock-after-modify.txt 中 PID=999999；核验 lock-after.txt 确认锁仍存在（未释放）。

---

### Phase 5: T43 — 全管线 + T46 — 路径契约（关键）

**子 agent 输入参数**:
- 测试目录: `.production-validation-v19-final/`
- 提取的脚本: `lib/step1.ps1` ~ `lib/step5-full.ps1`, `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### T43-v19 — 全场景全管线

**Fixture 场景**（除 404 外 repo 必须真实存在）：

```
normal upgrade      — 真实仓库，localVer 低于最新 release
synced              — 真实仓库，localVer 等于最新 release
uninstalled         — 真实仓库，localVer=未安装
unsupported version — 真实仓库，版本格式不可比较
404                 — 不存在的仓库（如 test/nonexistent-repo-12345）
versionJump         — 真实仓库，版本跨越大（major 差 ≥2 或 minor 差 ≥10）
```

**执行**: PS7 完整 Step 1→5 代码 + Step 6 汇报模板。[L9]

> **stdout 捕获策略**：同 Phase 3，逐 step 独立执行并拼接 stdout。[M3]

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
T43/stdout-step1.txt ~ stdout-step5.txt   [M3]
T43/stderr.txt
T43/test-report.md
T43/md-before.md
T43/md-after.md
T43/result-before.json
T43/result-after.json
```

#### T46-v19 — .output 状态路径回归

**运行目录**: `.production-validation-v19-final/T46/`（通过 `GITHUB_VERSION_MONITOR_BASE` 指向此目录）[M2]

**验证项**:
```
.output/GitHub更新监测列表.md 是唯一生产状态文件
根目录不存在 GitHub更新监测列表.md
读取 .output/ 写回 .output/
backup 基于 .output 状态文件
```

**禁止**: 不得重新使用 `.\GitHub更新监测列表.md`（根目录）。

**检查方法**: 运行 Step 1 + Step 2 后，检查 T46 测试目录（非生产根目录）是否出现同名状态文件。如果测试目录根出现 → FAIL + P1。[M2]

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
- `.production-validation-v19-final/T43/` 目录及全部证据
- `.production-validation-v19-final/T46/` 目录及全部证据
- `.production-validation-v19-final/phase-progress.json`

**主 agent 审查点**: 核验 T43 stdout.txt 中完整成功链；核验 T46 directory-listing.txt 中测试目录根无 `GitHub更新监测列表.md`。

---

### Phase 6: 状态机 + Schema + Lock 回归

**子 agent 输入参数**:
- 测试目录: `.production-validation-v19-final/`
- 提取的脚本: `lib/step2.ps1`, `lib/mock-listener.ps1`
- fixture 生成工具: `lib/create-fixture.ps1`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

#### 6.1 状态机回归（Prompt 第 16 节）[M6 修订]

SKILL-v1.9 状态机共有 9 种非 ok 状态（SKILL L132-140 直接核实）。v1.8 报告 N.4 明确记录 `metadata_incomplete` 与 `invalid_response` 未测。本轮 T18 覆盖全部 9 种。

| 测试 | 验证内容 | 构造方法 | 期望 queryStatus |
|---|---|---|---|
| T02 | 404 → not_found | mock `Invoke-RestMethod` 返回 404 | `not_found` |
| T04-PS7 | 403 + remaining=0 → rate_limited | mock 返回 403 + `X-RateLimit-Remaining: 0` | `rate_limited` |
| T05-PS7 | 403 + remaining>0 → forbidden | mock 返回 403 + `X-RateLimit-Remaining: 50` | `forbidden` |
| T08 | network_error | mock 抛出异常（无 HTTP response） | `network_error` |
| T14 | incomparable | 版本格式不可比较（如 `v1.2.3a` vs `v1.2.3`） | `ok` + `cmp=incomparable` + `review=true` |
| T15 | versionJump | major 差 ≥2 的真实仓库 | `ok` + `versionJump=true` + `review=true` |
| T16 | dateSuspicious | 新 publishedUtc 对应北京时间日期早于上轮 gitDate | `ok` + `dateSuspicious=true` + `review=true` |
| T17 | isFlip | 上轮 `flag=no` → 本轮 `flag=yes` | `ok` + `isFlip=true` |
| T18 | 状态保留（9 种非 ok 状态） | 9 种 error 状态下 gitVer/gitDate/flag 不变 | 各状态保留上轮状态 |
| T19 | uninstalled | localVer=未安装 → flag=no（但 GIT 列照常刷新） | `ok` + `flag=no` |

**T18 的 9 种非 ok 状态** [M6]：

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

**不需要重新建立完整历史测试矩阵，但必须真正运行关键路径。**

**每个测试证据**: `stdout.txt` / `stderr.txt` / `test-report.md`

T04/T05 额外证据: `HTTP status` / `header metadata` / `request count`

T18 额外证据: 每种状态独立记录（9 种 error 状态 × before/after）

#### 6.2 Schema 回归（Prompt 第 14 节）

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

#### 6.3 Lock 回归（Prompt 第 15 节）[L5 修订]

| 测试 | 验证内容 | 构造方法 | 期望 |
|---|---|---|---|
| lock-concurrency | 两进程争锁 | 两个 PS7 进程同时执行 Step 1 | one owner + one `LOCKED|` |
| lock-ownership | 外来 PID | 锁文件 PID 改为不匹配值 | `RUNTIME_ERROR|` + foreign lock retained |
| lock-stale-alive | 陈锁 + PID 活 | heartbeat 超 30 min + PID alive | `LOCKED|` |
| lock-stale-dead | 陈锁 + PID 死 | heartbeat 超 30 min + PID dead | takeover 成功，以 `BACKUP_OK|` 为判定标记 |

**证据**: `stdout.txt` / `stderr.txt` / `test-report.md` / `lock-before.txt` / `lock-after.txt`

#### 6.4 Runtime Error Contract 静态检查（Prompt 第 17 节）

重点检查所有异常路径（Step 1-5）是否存在：

```
try/catch
cleanup
lock release
final status
```

特别搜索以下关键操作，对每个会导致生产状态改变的关键文件操作检查异常是否被处理：

```
Set-Content
Move-Item
Add-Content
ConvertFrom-Json
ConvertTo-Json
Get-Content
File.Open
```

**声明**: 静态检查只能作为辅助，T22/T23/T38 必须实际执行（已在 Phase 2 完成）。

**输出**: `runtime-error-contract/static-analysis.md`

**输出结果**:
- 各测试子目录及全部证据
- `.production-validation-v19-final/runtime-error-contract/static-analysis.md`
- `.production-validation-v19-final/phase-progress.json`

**主 agent 审查点**: 核验状态机 10 项测试结果（含 T18 的 9 种状态）；核验 schema 9 项输入测试结果；核验 lock 4 项测试结果；核验 static-analysis.md 覆盖 Step 1-5 所有关键操作。

---

### Phase 7: PS5.1 兼容性回归

**子 agent 输入参数**:
- 测试目录: `.production-validation-v19-final/`
- 提取的脚本: `lib/mock-listener.ps1`
- PS5.1 路径: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
- 隔离环境变量: `GITHUB_VERSION_MONITOR_BASE` 指向各测试子目录

**处理逻辑**:

如果系统存在 `powershell.exe 5.1`，至少执行：

#### T04-PS5.1 — 403 + remaining=0 → rate_limited

- mock `Invoke-RestMethod` 返回 403 + `X-RateLimit-Remaining: 0`
- 在 PS5.1 中执行
- 验证: `queryStatus=rate_limited`
- 验证: `Get-ResponseHeaderValue` 在 `System.Net.WebHeaderCollection` 下仍然工作

#### T05-PS5.1 — 403 + remaining>0 → forbidden

- mock `Invoke-RestMethod` 返回 403 + `X-RateLimit-Remaining: 50`
- 在 PS5.1 中执行
- 验证: `queryStatus=forbidden`

> **PS5.1 语法注意事项** [L6 修订]：v1.8 报告 N.3 记录 PS5.1 无法解析 PS7 单行紧凑函数定义。SKILL-v1.9 提取的代码为紧凑单行风格。PS5.1 测试脚本需将紧凑代码展开为多行格式后再执行。不影响生产代码（SKILL 原文为多行格式）。

**判定规则**（Prompt 第 13 节）[M1 修订]:
- PS5.1 不存在 → BLOCKED（不影响 PS7 production gate）
- PS5.1 存在但失败 → 记录 compatibility FAIL，**不计入 production-critical FAIL 总数**（见 §8 计数口径）
- PS5.1 失败不隐藏，必须在报告中如实记录

**证据要求**:
```
T04-PS5.1/stdout.txt
T04-PS5.1/stderr.txt
T04-PS5.1/test-report.md
T05-PS5.1/stdout.txt
T05-PS5.1/stderr.txt
T05-PS5.1/test-report.md
```

额外证据: `HTTP status` / `header metadata` / `request count`

**输出结果**:
- `.production-validation-v19-final/T04-PS5.1/` 目录及全部证据
- `.production-validation-v19-final/T05-PS5.1/` 目录及全部证据
- `.production-validation-v19-final/phase-progress.json`

**主 agent 审查点**: 确认 PS5.1 可用性；核验 T04-PS5.1 和 T05-PS5.1 的 stdout.txt 中 queryStatus 分类正确。

---

### Phase 8: Self-Review（质量控制）

**子 agent 输入参数**:
- 全部 Phase 0-7 证据目录: `.production-validation-v19-final/`
- 被测文件: `SKILL-v1.9.md`
- 提取清单: `lib/extraction-manifest.json`
- Phase 0 SHA256 基线: `v18.sha256`, `v19.sha256`, `state.sha256`

**处理逻辑**:

测试完成后执行一次独立 self-review。必须检查：

```
1. 有没有测试对象修改
   — 重新计算 SKILL-v1.9.md SHA256，与 v19.sha256 比对
   — 重新计算 SKILL-v1.8.md SHA256，与 v18.sha256 比对

2. 有没有旧 evidence 被当作当前 PASS
   — 确认所有测试目录在 .production-validation-v19-final/ 下
   — 确认未引用 v17/v18 测试目录中的结果作为 PASS 证据

3. 有没有 fixture 错误
   — fixture 仓库是否真实存在（除 404 外）

4. 有没有测试脚本修改导致假 PASS
   — 按 extraction-manifest.json 逐文件重算 SHA256，与清单记录比对 [L8]
   — 确认提取脚本与 SKILL 原文代码块逐字一致

5. 有没有 FAIL 被写成 BLOCKED
   — 逐项核验每个测试的实际输出 vs 报告结论

6. 有没有 BLOCKED 被写成 PASS
   — 同上

7. 有没有报告数字不一致
   — PASS+FAIL+BLOCKED 是否等于 Executed

8. 有没有证据与结论矛盾
   — stdout.txt 中的实际输出是否与 test-report.md 结论一致
```

**生产状态文件完整性复核** [M4 修订]：

```
9. 生产 .output/GitHub更新监测列表.md 未被修改
   — 重新计算 SHA256，与 state.sha256 比对
   — 确认测试期间未触碰生产状态文件
```

**输出**: `.selfreview/selfreview-v19-20260909-014524.md` [L2]

> **目录说明**：`.selfreview/` 位于项目根目录（非测试目录），与 v1.8 selfreview 文件（`.selfreview/selfreview-v18-20260908-073000.md`）保持一致。[L2]

**输出结果**:
- `.selfreview/selfreview-v19-20260909-014524.md`
- `.production-validation-v19-final/phase-progress.json`

**主 agent 审查点**: 逐项核验 self-review 的 9 项检查结果；如有任一项不通过，标记对应测试为 FAIL 并在最终报告中披露。

---

### Phase 9: Final Report + Commit（主 agent 执行）

**输入**: 全部 Phase 0-8 证据

**处理逻辑**:

#### Step 1: 汇总全部证据

#### Step 2: 生成 `production-validation-report-v19-final.md`

必须包含以下章节（Prompt 第 22 节）：

```
A. Environment
B. Version / SHA256
C. v1.8 -> v1.9 Diff Integrity
D. Targeted Test Summary
E. Critical Findings
F. Evidence Index
G. Invariant Verification
H. State Path Verification
I. PS7 Production Assessment
J. PS5.1 Compatibility Assessment
K. Self-Review Findings
L. Production Gate
M. Execution Summary
N. Remaining Limitations
```

#### Step 3: 最终执行摘要（Prompt 第 25 节）

必须明确回答：

```
PS7 available:
PS7 executed:
PS5.1 available:
PS5.1 executed:

Real GitHub API:
Mock HTTP:

T04-PS7:
T04-PS5.1:
T05-PS7:
T05-PS5.1:

T22:
T23:
T37:
T38:
T39:
T43:
T46:

Concurrency:
Process Kill:
result atomicity:
review atomicity:
md atomicity:
lock release failure:
state path verification:
diff integrity:
self-review:
```

#### Step 4: 计数统计（Prompt 第 23 节）[M1 修订]

**双维度计数**：

```
Production-critical:
  Executed = N
  PASS = N
  FAIL = N
  BLOCKED = N

Compatibility (PS5.1):
  Executed = N
  PASS = N
  FAIL = N
  BLOCKED = N

Total:
  Executed = N
  PASS = N
  FAIL = N
  BLOCKED = N

PASS + FAIL + BLOCKED = Executed（每维度内）
```

不人为加入不存在的测试编号。

#### Step 5: Production Gate 判定（Prompt 第 24 节）[M1 修订]

**PRODUCTION_READY** 必须同时满足：
```
P0 = 0
P1 = 0
Production-critical FAIL = 0
Production-critical BLOCKED = 0

T22 PASS
T23 PASS
T38 PASS
T37 PASS
T39 PASS
T43 PASS
T46 PASS

Diff Integrity PASS
Self-Review PASS

PS7 primary runtime PASS
```

**PS5.1 兼容性 FAIL/BLOCKED 不计入 production-critical 计数**，不影响 PRODUCTION_READY 判定，但必须在报告中如实记录。

**PRODUCTION_NOT_READY**: 任意 P0 > 0 / P1 > 0 / production-critical FAIL > 0，尤其 T22/T23/T37/T38/T39/T43 任一 FAIL。

**PRODUCTION_BLOCKED**: 仅当 P0=0 / P1=0 / production-critical FAIL=0 / production-critical BLOCKED > 0。

#### Step 6: 最终结论（Prompt 第 26 节）

报告最后严格输出：

```
VERSION: v1.9

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
PRODUCTION_READY
```

（或 PRODUCTION_NOT_READY / PRODUCTION_BLOCKED）

并给出：
```
REPORT:
<production-validation-report-v19-final.md 完整路径>
```

#### Step 7: Git commit [M5 修订]

**Commit 文件范围**：
```
SKILL-v1.9.md                      — 被测对象（Phase 0 已 git add）
.production-validation-v19-final/  — 全部测试证据
production-validation-report-v19-final.md  — 最终报告
.selfreview/selfreview-v19-20260909-014524.md  — self-review
.exec-plan/exec-plan-v1.9-b.md     — 本执行计划
```

commit message 必须包含：
```
1. 最终 Verdict
2. Production-critical PASS / FAIL / BLOCKED 计数
3. Compatibility PASS / FAIL / BLOCKED 计数
4. P0 / P1 / P2 计数
5. 本轮新增或发现的关键问题（若有）
6. 新增的证据目录与报告路径
```

**输出结果**:
- `d:\AI\Workspace\automatic\github-version-monitor\production-validation-report-v19-final.md`

---

## 3. 子 agent 执行模型

### 3.1 执行流程

```
┌─────────────┐
│  Phase 0     │ sub-agent
│  Clean-Room  │
└──────┬───────┘
       │ 完成
       ▼
┌─────────────┐
│  主 agent    │ 审查 phase-progress.json + 证据
│  审查点 0    │
└──────┬───────┘
       │ PASS
       ▼
┌─────────────┐
│  Phase 1     │ sub-agent
│  Diff+Code   │
└──────┬───────┘
       │ 完成
       ▼
┌─────────────┐
│  主 agent    │ 审查 diff-integrity.md + 提取脚本 + extraction-manifest.json
│  审查点 1    │
└──────┬───────┘
       │ PASS
       ▼
       ...
       ▼
┌─────────────┐
│  Phase 8     │ sub-agent
│  Self-Review │
└──────┬───────┘
       │ 完成
       ▼
┌─────────────┐
│  主 agent    │ 审查 self-review 9 项检查
│  审查点 8    │
└──────┬───────┘
       │ PASS
       ▼
┌─────────────┐
│  Phase 9     │ 主 agent
│  Final Report│
└─────────────┘
```

### 3.2 子 agent 任务规范

每个 sub-agent 接收：
- 任务规格（本计划中对应 Phase 的完整描述）
- `SKILL-v1.9.md` 绝对路径
- 测试目录绝对路径
- 证据要求清单
- `GITHUB_VERSION_MONITOR_BASE` 隔离环境变量设置指令
- `resume_from` 参数（仅中断恢复时）

每个 sub-agent 产出：
- 测试证据文件（stdout.txt / stderr.txt / test-report.md / SHA256 等）
- 结构化结果摘要
- `phase-progress.json`（断点保存）

### 3.3 禁止事项

```
1. 禁止修改 SKILL-v1.9.md
2. 禁止修改生产 .output/GitHub更新监测列表.md — 用 fixture 副本测试（通过 GITHUB_VERSION_MONITOR_BASE 隔离）
3. 禁止复用 v17/v18 历史测试证据作为本轮 PASS 证据
4. 禁止修改 .GPT/ 下的 prompt 文件
5. 禁止输出 GITHUB_TOKEN / Authorization / Cookie / 完整 secret
6. 禁止为使测试通过而修改被测代码
7. 禁止多 sub-agent 并行执行
8. 禁止 Verdict 由预期结果而非实际证据决定
```

---

## 4. 证据规则（Prompt 第 19 节）

### 4.1 每项测试至少

```
stdout.txt
stderr.txt
test-report.md
```

### 4.2 涉及文件 [L10 修订]

```
before/
after/
SHA256（sha256-before.txt / sha256-after.txt，内容须覆盖所有涉及的文件：
  main md、result.json、tmp，每行格式 "<file>: <sha256>"）
```

### 4.3 涉及 lock

```
lock-before.txt
lock-after.txt
（T39 额外：lock-after-modify.txt）
```

### 4.4 涉及最终状态

```
actual final output
```

### 4.5 涉及 API

```
actual HTTP status
actual relevant headers
request count
```

### 4.6 绝对禁止保存

```
GITHUB_TOKEN
Authorization
Cookie
完整 secret
```

---

## 5. v1.9 必须证明的核心 Invariant（Prompt 第 18 节）

| # | Invariant | 验证测试 |
|---|---|---|
| 1 | 主 md 只有 atomic replacement 成功后才算提交成功 | T37, T23 |
| 2 | Move-Item success → commitSucceeded=true | T37, T39 |
| 3 | commitSucceeded=true AND lockReleased=true → RUN_STATUS\|success\| | T37 |
| 4 | commitSucceeded=true AND lockReleased=false → RUN_STATUS\|failed\| | T39 |
| 5 | review write failure → no md commit | T38 |
| 6 | md commit failure → main md remains unchanged | T22, T23 |
| 7 | failure → tmp cleanup where defined safe + lock release where ownership confirmed + RUN_STATUS\|failed\| | T22, T23, T38 |

如果 v1.9 中任何 invariant 与代码行为不一致 → FAIL。

---

## 6. 执行模式要求

### 6.1 后台静默模式

所有执行操作和测试流程必须采用后台静默模式运行：

- PowerShell 7 脚本通过 `pwsh -NoProfile -NonInteractive -File <script.ps1> *>&1 > <output.txt>` 执行
- PS5.1 脚本通过 `powershell.exe -NoProfile -NonInteractive -File <script.ps1> *>&1 > <output.txt>` 执行
- HTTP mock 通过 PowerShell 函数覆盖实现，不需要后台进程或系统 hosts 变更 [M2]
- 文件锁通过 `Start-Process -WindowStyle Hidden` 在后台进程中持有，测试完成后 `Stop-Process` 终止
- 所有输出重定向到文件（`stdout.txt` / `stderr.txt`），不输出到控制台

### 6.2 前台执行场景声明

**无必须使用前台执行模式的特殊场景。**

所有测试操作均可通过 PowerShell 非交互模式在后台完成。文件锁持有等辅助进程均通过 `Start-Process -WindowStyle Hidden` 启动。

---

## 7. 硬约束（违反即本轮无效）

1. **不得修改 `SKILL-v1.9.md`** — 发现问题只记录，不修复（Prompt 第 20 节）
2. **不得修改生产 `.output/GitHub更新监测列表.md`** — 用 fixture 副本测试（通过 `GITHUB_VERSION_MONITOR_BASE` 隔离）
3. **不得把修复写入 extracted production script 后再报告 PASS**（Prompt 第 20 节）
4. **不得复用 v1.7/v1.8 历史测试证据作为本轮 PASS 证据**（Prompt 第 1 节）
5. **不得修改 `.GPT/` 下的 prompt 文件**
6. **不得输出 `GITHUB_TOKEN` / `Authorization` / `Cookie` / 完整 secret**（Prompt 第 19 节）
7. **不得修改被测代码来消除测试失败**（Prompt 第 20 节）
8. **Verdict 必须由实际证据决定**，禁止按预期结果填写（Prompt 第 22 节）
9. **FAIL 不得改写为 BLOCKED**（Prompt 第 26 节）
10. **BLOCKED 不得改写为 PASS**（Prompt 第 26 节）
11. **旧版本证据不得冒充新版本证据**（Prompt 第 26 节）

---

## 8. 最终 Verdict 判定逻辑（Prompt 第 24 节）[M1 修订]

### 计数口径

为消解 Prompt §13（PS5.1 FAIL 不阻塞 PS7 gate）与 §24（FAIL>0 → NOT_READY）的表面矛盾，定义双维度计数：

| 维度 | 覆盖范围 | 影响 PRODUCTION_GATE |
|---|---|---|
| **Production-critical** | PS7 全部测试 + 结构性测试（T22/T23/T37/T38/T39/T43/T46 + Diff Integrity + Self-Review + 状态机 + Schema + Lock） | 是 |
| **Compatibility** | 仅 PS5.1 兼容性测试（T04-PS5.1 + T05-PS5.1） | 否 |

### PRODUCTION_READY

必须同时满足：
```
P0 = 0
P1 = 0
Production-critical FAIL = 0
Production-critical BLOCKED = 0

T22 PASS
T23 PASS
T38 PASS
T37 PASS
T39 PASS
T43 PASS
T46 PASS

Diff Integrity PASS
Self-Review PASS

PS7 primary runtime PASS
```

### PRODUCTION_NOT_READY

任意：
```
P0 > 0
P1 > 0
Production-critical FAIL > 0
```

尤其：
```
T22 FAIL
T23 FAIL
T37 FAIL
T38 FAIL
T39 FAIL
T43 FAIL
```

### PRODUCTION_BLOCKED

仅当：
```
P0 = 0
P1 = 0
Production-critical FAIL = 0
Production-critical BLOCKED > 0
```

### 非生产关键 BLOCKED 的处理

- PS5.1 兼容测试 BLOCKED: 显式列出，不影响 PS7 production gate
- 任何生产关键项 BLOCKED: Production Gate = CLOSED

---

## 9. 测试清单总览

| Phase | 测试 | 重点 | 优先级 |
|---|---|---|---|
| 0 | Clean-Room + SHA256 + git staging | 目录隔离 + 文件指纹 + 被测对象纳入 git | 基础 |
| 1 | Diff Integrity + 代码提取 + 提取清单 | v18→v19 diff，28 项能力保留，9 项禁止项 | 基础 |
| 2 | T22 | md tmp 写入失败 → tmp 清理 + lock 释放 + failed | **硬门槛** |
| 2 | T23 | md Move-Item 失败 → 主 md 不变 + tmp 清理 + lock 释放 + failed | **硬门槛** |
| 2 | T38 | review tmp 写入失败 → result.json 不变 + tmp 清理 + lock 释放 + failed | **硬门槛** |
| 3 | T37 | 正常提交 → COMMIT_OK + RUN_STATUS\|success\| | **硬门槛** |
| 4 | T39 | commit 成功 + 锁释放失败 → 绝不 success（同进程 harness） | **硬门槛** |
| 5 | T43 | 6 场景全管线 Step 1→5 + Step 6 模板 | **关键** |
| 5 | T46 | .output 路径契约，测试目录根不得出现同名文件 | **关键** |
| 6 | T02 | 404 → not_found | 中 |
| 6 | T04-PS7 | 403 + remaining=0 → rate_limited | 高 |
| 6 | T05-PS7 | 403 + remaining>0 → forbidden | 高 |
| 6 | T08 | network_error，PS7 实际无 HTTP response | 高 |
| 6 | T14 | incomparable version | 中 |
| 6 | T15 | versionJump | 中 |
| 6 | T16 | dateSuspicious | 中 |
| 6 | T17 | isFlip | 中 |
| 6 | T18 | 9 种非 ok 状态保留 | 中 |
| 6 | T19 | uninstalled | 中 |
| 6 | schema | 严格小写 yes/no 回归 | 中 |
| 6 | lock-concurrency | 两进程争锁 | 中 |
| 6 | lock-ownership | 外来 PID → `RUNTIME_ERROR\|` | 中 |
| 6 | lock-stale-alive | 陈锁 + PID 活 → `LOCKED\|` | 中 |
| 6 | lock-stale-dead | 陈锁 + PID 死 → takeover（`BACKUP_OK\|`） | 中 |
| 6 | runtime-error-contract | 静态异常路径分析 | 辅助 |
| 7 | T04-PS5.1 | PS5.1 403 + remaining=0 → rate_limited | 兼容 |
| 7 | T05-PS5.1 | PS5.1 403 + remaining>0 → forbidden | 兼容 |
| 8 | Self-Review | 9 项独立检查（含生产文件完整性复核） | 质量控制 |
| 9 | Final Report | 报告 A-N + verdict + commit | 收尾 |

---

## 10. 最终原则（Prompt 第 26 节）

```
Git repository = 唯一事实源
证据优先于结论
实际执行优先于静态推理
FAIL 不得改写为 BLOCKED
BLOCKED 不得改写为 PASS
旧版本证据不得冒充新版本证据
不得修改被测 SKILL 来消除测试失败
```

---

## 11. 修订日志

### exec-plan-v1.9-b（2026-09-08，基于 CodeBuddy 独立审计修订）

| 审计项 | 严重性 | 采纳/驳回 | 修订内容 | 理由 |
|---|---|---|---|---|
| H1 | 高 | **采纳** | T39 改用同进程 harness（`step5-t39-harness.ps1`）替代双脚本拆分 | [源码] SKILL L617/623/634/640 确认 `$commitSucceeded` 和 `$lockReleased` 是同进程局部变量；`pwsh -File` 独立进程无法传递变量，测试失去 invariant 4 区分度 |
| M1 | 中 | **采纳** | 定义双维度计数（production-critical vs compatibility） | [Prompt] §13"不阻塞"与 §24"FAIL>0→NOT_READY"存在表面矛盾；计划作为执行规范须给出裁决规则 |
| M2 | 中 | **采纳** | 新增 §0.4 测试隔离机制（GITHUB_VERSION_MONITOR_BASE + mock 函数覆盖 + T46 运行目录） | [源码] SKILL L162/240/431/473/518 确认 env var 支持；[Prompt] §2 要求 .monitor/ 在测试目录重新生成；mock 不需 hosts 劫持 |
| M3 | 中 | **采纳** | T37/T43 改为逐 step 独立执行 + 拼接 stdout | [文档] v1.8 报告 N.2 实测记录 run-full-pipeline.ps1 在 -File 模式下 stdout 未正确透传 |
| M4 | 中 | **采纳** | Phase 8 新增第 9 项检查：生产 .output 文件 SHA256 复核 | 逻辑缺口：state.sha256 有事前采集无事中/事后验证，硬约束 2 缺独立复核 |
| M5 | 中 | **采纳** | Phase 0 新增 git add SKILL-v1.9.md；Phase 9 定义 commit 文件范围 | [实测] `git ls-files` 确认 SKILL-v1.9.md untracked；[Prompt] §2/§26 要求"Git repository = 唯一事实源" |
| M6 | 中 | **采纳** | T18 从"6 种"改为 9 种非 ok 状态，显式列出全部 | [源码] SKILL L132-140 确认 9 种非 ok 状态（含 http_error）；[文档] v1.8 报告 N.4 确认 metadata_incomplete + invalid_response 未测 |
| M7 | 中 | **采纳** | Phase 0 目录树注明 .monitor/ 由 Step 1 动态创建 | [Prompt] §2 L112-118 要求 .monitor/ 在测试目录重新生成 |
| L1 | 低 | **采纳** | "27 项"改为"28 项" | 逐行点数确认 28 行 |
| L2 | 低 | **采纳** | 明确 .selfreview/ 位于项目根目录 | 与 v1.8 selfreview 文件路径一致 |
| L3 | 低 | **采纳** | T37 审查点 REVIEW_WRITE_OK 改为条件性 | 验证项已标"（有 review 时）"，审查点须一致 |
| L4 | 低 | **采纳** | 构造方法替换"read-only directory"为 ACL deny / file lock | Windows ReadOnly 属性不阻止文件创建，实测确认 |
| L5 | 低 | **采纳** | lock-ownership 期望加 `|`；lock-stale-dead 指定 `BACKUP_OK\|` 为判定标记 | [源码] SKILL 输出带竖线；v1.8 以 BACKUP_OK 判定 takeover |
| L6 | 低 | **采纳** | 新增 PS5.1 多行展开注意事项 | [文档] v1.8 报告 N.3 实测确认 PS5.1 无法解析紧凑单行函数 |
| L7 | 低 | **部分采纳** | 保留"3 个 P2"（Prompt 口径），新增脚注注明 v1.8 报告 P2=2 | [Prompt] §0 明确列 3 个 P2；[文档] v1.8 报告 L.2 计 P2=2（T22-v18 PASS）。计划沿用唯一事实源口径，脚注注明差异 |
| L8 | 低 | **采纳** | Phase 1 新增 extraction-manifest.json；Phase 8 第 4 项按清单验证 | self-review 第 4 项原无核验基准 |
| L9 | 低 | **采纳** | 新增 Step 6 为汇报模板的显式说明 | [源码] SKILL L655 确认 Step 6 无 PowerShell 代码块 |
| L10 | 低 | **采纳** | T22/T23 新增 result-before/after.json；定义 sha256 文件覆盖范围 | [Prompt] §8 L354-360 要求 main md + result.json + tmp 三者 SHA256 |
| L11 | 低 | **采纳** | T39 新增 lock-after-modify.txt | 三态证据（before → modify → after）比两态更完整 |
