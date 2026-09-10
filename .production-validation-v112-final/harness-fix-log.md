# Phase 3 — Harness Fix Log

## Phase 4 Records

## 记录 P4-E: Mock `New-MockHttpException` StatusCode property silently null -> T3 api failure lands in `network_error` instead of `server_error`

**修复时间戳 (ISO8601)**: `2026-09-11T00:05:29+08:00`

**发现时机**: Phase 4 Test 3 attempt 1 执行完成后，验证项 `api_item_status[microsoft/vscode]` 与 `api_item_status[PowerShell/PowerShell]` 期望 `server_error`，实际得到 `network_error`（PASS=33 / FAIL=2）。

**根因**: Phase 2 版 `lib/mock-invoke-restmethod.ps1` 使用 `New-Object System.Net.WebResponse` 构造 mock response，然后写 `$response.StatusCode = [HttpStatusCode]500`。在 .NET 8 / PS 7.6.4 下 `System.Net.WebResponse` 是 virtual 类而非 abstract，但 `StatusCode` 属性 setter 只在具体子类里 override，基类 setter 不生效（或抛 `ArgumentException` 被 try/catch 吞掉）。SKILL step2.ps1 L116 读取 `$_.Exception.Response.StatusCode` 得到 `null` -> `$code=$null` -> 走 step2 L128 else 分支 -> `status='network_error'`。

**契约影响**: 主 agent 任务文本明确要求 T3 主场景为 500 或 network_error（F1 决策"500 或 network_error 均可接受"），但 exec-plan 与任务文本默认预期 `server_error`。为对齐 SKILL 状态机分类验证，需 mock 能可靠投递 StatusCode=500。

**修复对象**: `lib/mock-invoke-restmethod.ps1`（Phase 2 产出的 mock 工具；不是被测 SKILL）。

**未修改（byte-exact 不变）**: `SKILL-v1.12.md`；`lib/step1.ps1` ~ `lib/step5-full.ps1`。

**修复方法**:
- 用 `Add-Type` 定义 `MockHttp.MockHttpResponse` 类，继承 `System.Net.WebResponse`，override 虚拟 `StatusCode` / `Headers` 属性。
- `New-MockHttpException` 改为传入 int StatusCode，用 `MockHttpResponse` 构造函数注入。
- 保留原有 scenario 分支（success/not_found/server_500/server_503/rate_429/rate_403_remaining_0/network/auth_error/forbidden/metadata_incomplete/invalid_response/list-*）语义不变。
- 打印额外 marker `MOCK_HTTP_RESPONSE_CLASS=MockHttp.MockHttpResponse (overrides StatusCode + Headers)` 供 harness 观察（stdout 中会被 suppress，因为 `$null = . $mockPath`）。

**验证**: 修复后 T3 attempt 2 的 result-after.json 应显示 `items[].status = "server_error"`；`stats.apiOk=0 / apiErr=2`。

**兼容性**: 其他 Phase 2 harness（t3-mock-harness.ps1, t4-write-failure-harness.ps1）不直接依赖 mock-invoke-restmethod.ps1，无回归风险。

**重新执行**: 修复后必须重跑 T3（旧证据不覆盖：attempt 1 目录已保留，本次运行会 Reset base 目录，但 harness-fix-log 记录 attempt 1 结果以便追溯）。

## 记录 D: SKILL `stdout.txt` 被 harness 污染 → 独立证据流分离（Phase 3-fix, attempt 2）

**修复时间戳 (ISO8601)**：`2026-09-10T23:24:00+08:00`

**发现时机**：主 agent 独立复核 Phase 3 attempt 1 的 `T2-success/stdout.txt`。

**问题定性**：
- `T2-success/stdout.txt` Line 82：SKILL 真实终态 `RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。`（`lib/step5-full.ps1` 通过 pwsh pipeline 输出，合法）
- `T2-success/stdout.txt` Line 85：`RUN_STATUS_OBSERVED=RUN_STATUS|success|...`（**harness 污染**）
  - 来源 A：`lib/run-full-pipeline.ps1` line 60 `$allRunStatuses | ForEach-Object { Write-Output ("RUN_STATUS_OBSERVED={0}" -f $_) }`
- `T2-success/stdout.txt` Line 86：`PS_VERSION|7.6.4`（**harness 污染**）
  - 来源 B：`lib/p3-run-T.ps1` line 178 `Add-Content -Path $stdoutPath -Value $psVersionMarker -Encoding UTF8`（记录 B 引入）

**独立 grep 复核（attempt 1, 主 agent）**：
- `RUN_STATUS|success|` 计数 = **2**（预期 1）→ 破坏字面独立计数
- 其余计数（`COMMIT_OK|` / `BACKUP_OK|` / `FETCH_COMPLETE|` / `REVIEW_WRITE_OK|`）均正常
- T1-PS7/stdout.txt 同样受污染（Line 85 = harness 附加的 RUN_STATUS_OBSERVED）

**违反 §0.10 Test Harness Integrity**：修改 harness 后必须重新执行受影响测试，且旧证据不覆盖新证据；被测 SKILL 的 stdout 必须是 pwsh.exe pipeline 的**原始 stdout**，任何 harness 侧的辅助信息（PS_VERSION、RUN_STATUS_OBSERVED、时间戳等）必须写到**独立证据文件**。

**修复对象**（**不属于被测 SKILL**）：
- `lib/run-full-pipeline.ps1`（harness orchestrator，Phase 3 新增）
- `lib/p3-run-T.ps1`（harness test runner，Phase 3 新增）

**未修改（byte-exact 不变）**：
- `SKILL-v1.12.md`（SHA256 = `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9`）
- `lib/step1.ps1` / `lib/step2.ps1` / `lib/step3.ps1` / `lib/step4.ps1` / `lib/step5-full.ps1`（Phase 2 byte-exact 提取）

**修复方法**：

1. `lib/run-full-pipeline.ps1`：
   - **删除** `$allRunStatuses = @()` 声明与 foreach 内的 `$allRunStatuses += @(...)` 收集
   - **删除** `Write-Output "RUN_STATUS_OBSERVED={0}" -f $_` 循环
   - 保留 pipeline 本身所有 step-by-step 的 stdout 输出（`PIPELINE_START` / `--- stepN BEGIN/END ---` / step 输出 / `PIPELINE_END`）
2. `lib/p3-run-T.ps1`：
   - **删除** Step D2 中 `Add-Content -Path $stdoutPath -Value $psVersionMarker -Encoding UTF8`（原 line 178）
   - **新增** `harness-aux.txt`：所有 harness 侧证据（`PS_VERSION`、`GITHUB_TOKEN_SET`、`PIPELINE_EXIT`、`PIPELINE_PID`、`RUN_MODE`、`CMD_TARGET`、`CMD_ARGS`、`BEFORE/AFTER_SNAPSHOT_OK`、`SHA256_BEFORE/AFTER`、`LOCK_*_EXISTS`、`MD_CHANGED`、`FIXTURE_EXIT`、`FIXTURE_MONITOR_DIR_EXISTS`、`PS_VERSION_MARKER`、`AUX_BEGIN/END` 时间戳）写入此文件
   - **新增** `run-status-sidecar.txt`：harness 从 raw stdout **派生**（不追加）观察到的 `RUN_STATUS|` 行；`RAW_STDOUT_RUN_STATUS_LINES` 计数 + 每条 `RUN_STATUS_OBSERVED=` 记录
   - 所有 harness 自己的 `Write-Output` 仍打印到**harness 控制台**（即 p3-run-T.ps1 进程的 stdout），但这些**不会**写入被测 SKILL 的 `<TestDir>/stdout.txt`（后者由 `Start-Process -RedirectStandardOutput` 捕获，仅包含 pipeline 子进程的原生 stdout）

**修复语义**：
- `<TestDir>/stdout.txt` ≡ 被测 pipeline 的原生 stdout（不含任何 harness 追加行）
- `<TestDir>/stderr.txt` ≡ 被测 pipeline 的原生 stderr
- `<TestDir>/harness-aux.txt` ≡ 所有 harness 侧证据（PS_VERSION、PIPELINE_EXIT、SHA256_BEFORE/AFTER 等）
- `<TestDir>/run-status-sidecar.txt` ≡ harness 从 stdout 派生的 RUN_STATUS 观察

**重新执行**：修改后必须重跑 T1-PS7 与 T2-success（**旧证据不覆盖**：attempt 1 保留在 `T1-PS7-attempt1/` 与 `T2-success-attempt1/`）。

**attempt 1 证据保留确认**：
- `T1-PS7-attempt1/`（原 `T1-PS7/` 完整目录）
- `T2-success-attempt1/`（原 `T2-success/` 完整目录）

**脚本备份**（R20 保护）：
- `lib/p3-run-T.ps1.备份.20260910_232058`
- `lib/run-full-pipeline.ps1.备份.20260910_232058`

---

## 记录 A: `pwsh.exe ... *>&1 > stdout.txt` 语法在 cmd.exe 下不可用

**发现时机**：T1-PS7 首次执行

**spec 来源**：`exec-plan-v1.12-d.md §0.7` 明文要求所有脚本经 `pwsh.exe -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>` 执行。

**首次尝试**（cmd.exe 包装）：
```
cmd.exe /c ""C:\Program Files\PowerShell\7\pwsh.exe" -NoProfile -NonInteractive -File ... *>&1 > stdout.txt 2> stderr.txt"
```

**实际结果**：pipeline exit=1，`stdout.txt` 为空，`stderr.txt` 报 `A positional parameter cannot be found that accepts argument '*'`。cmd.exe 不识别 `*>&&1` 作为 token，将其作为字面量传给 pwsh.exe，导致参数解析失败。

**修复方式**：改用 pwsh-native `Start-Process -RedirectStandardOutput/-RedirectStandardError`，语义等价（后台、静默、stdout/stderr 分文件）：
```powershell
Start-Process -FilePath 'C:\Program Files\PowerShell\7\pwsh.exe' `
    -ArgumentList @('-NoProfile','-NonInteractive','-File',$pipelineScript,'-TestDir',$base) `
    -NoNewWindow -Wait -PassThru `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError  $stderrPath
```

**影响范围**：`lib/p3-run-T.ps1`（Phase 3 harness）
**未改动**：`lib/run-full-pipeline.ps1`、`step1..step5`（Phase 2 byte-exact 提取的被测代码），`SKILL-v1.12.md`。

**验证**：修复后 T1 与 T2 pipeline 均以 exit=0 完成，`BACKUP_OK|` / `FETCH_COMPLETE|` / `COMMIT_OK|` / `RUN_STATUS|success|` 均按预期产出，`stderr.txt` 为 0 bytes。

---

## 记录 B: `PS_VERSION` 证据行由 harness 附加

**发现时机**：`lib/run-full-pipeline.ps1` 未输出 PS 版本号（脚本内部使用 `$PID`、`$PSScriptRoot` 等，但没有主动 emit PS 版本）。

**处理方式**：`lib/p3-run-T.ps1` 在完成 after 快照后，用 `Add-Content` 向 pipeline stdout 追加一行 `PS_VERSION|<version>`，用于满足 T1 验证项"stdout 中有实际版本号"。

**影响**：仅追加证据行到 harness 侧 stdout.txt，不影响 SKILL 本身行为，不修改被测代码。

---

## 记录 C: `p3-verify.ps1` param 参数（内部工具）

**发现时机**：首次运行 `p3-verify.ps1 -TestId T1-PS7` 报 `A parameter cannot be found that matches parameter name 'and'`。

**排查**：`Parser.ParseFile` 显示 PARSE_OK；手工检查文件字节正常；`p3-min.ps1` / `p3-min2.ps1` 使用相同 `[Parameter(Mandatory=$true)][ValidateSet(...)]` 装饰器调用正常。**未定位根因**（可能是 pwsh 7.6.4 CLI 参数解析器对嵌套 attribute + 复杂 regex pattern 组合的兼容问题，或是 `#Requires` 与 `param` 之间空行处理差异）。

**修复**：将 param 简化为 `[Parameter(Mandatory=$true)][string]$TestId`，将 `ValidateSet` 迁移到脚本体内用 `if ($TestId -notmatch '^(T1-PS7|T2-success)$') { throw ... }` 显式校验。

**影响**：仅影响验证工具，不涉及 SKILL 或 pipeline。
