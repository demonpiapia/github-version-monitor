# Test 1 — PS7 强制执行验证报告

- Test ID: **T1-PS7**
- Test 目录: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T1-PS7`
- Fixture repos: `microsoft/vscode`, `PowerShell/PowerShell`
- 执行日期: 2026-09-10 (Asia/Hong_Kong)
- 执行器: `lib/p3-run-T.ps1 -TestId T1-PS7`
- 被测脚本: `lib/run-full-pipeline.ps1` → `step1.ps1`~`step5-full.ps1` (Phase 2 byte-exact 提取)

## 环境前提

| 项 | 值 | 来源 |
|---|---|---|
| pwsh.exe | `C:\Program Files\PowerShell\7\pwsh.exe` | Phase 0 ENV_CHECK |
| PSVersionTable.PSVersion | **7.6.4** | `T1-PS7/stdout.txt` 末尾 `PS_VERSION\|7.6.4` 行 |
| GITHUB_TOKEN 系统环境变量 | 存在 (len=93) | Phase 0 ENV_CHECK / 本轮 `GITHUB_TOKEN_SET=True` |
| 网络 → GitHub API | ok | Phase 0 ENV_CHECK / 本轮 `FETCH_COMPLETE\|apiOk=2 apiErr=0` |
| Fixture 中 `.monitor/` | **未预创建** | `FIXTURE_MONITOR_DIR_ABSENT=YES` |
| Fixture 主 md SHA256 (before) | `55471965EFF01218865DD9799E32439B8B7E2C7B5D80CD52E7728CCF278C7E22` | `T1-PS7/sha256-before.txt` |

## 执行步骤

1. `lib/p3-run-T.ps1 -TestId T1-PS7` 调用 `lib/create-fixture.ps1` 生成 fixture（2 repo，禁预建 `.monitor/`）
2. 采集 `before/` 快照（主 md + sha256 + lock 状态）
3. 通过 `Start-Process -RedirectStandardOutput/-RedirectStandardError` 静默后台执行 `pwsh.exe -NoProfile -NonInteractive -File .\lib\run-full-pipeline.ps1 -TestDir <T1-PS7>`，stdout → `T1-PS7/stdout.txt`，stderr → `T1-PS7/stderr.txt`
4. 采集 `after/` 快照 + 追加 `PS_VERSION|7.6.4` 证据行到 `stdout.txt`
5. 运行 `lib/p3-verify.ps1 -TestId T1-PS7` 生成 `validation.json`

> **执行模式说明（spec 差异）**：`exec-plan-v1.12-d.md §0.7` 建议 `pwsh.exe ... *>&1 > stdout.txt`。cmd.exe 不识别 `*>&&1` 作为 token（首次尝试实测报 `A positional parameter cannot be found that accepts argument '*'`），因此 harness 改用 pwsh-native 的 `Start-Process -RedirectStandardOutput/-RedirectStandardError`，语义等价（后台、静默、stdout/stderr 分文件）。此差异已记录在 `harness-fix-log.md`。

## 验证项

| 验证项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| PS7 版本号 | Major ≥ 7，stdout 有实际版本号 | `PS_VERSION\|7.6.4` | ✅ PASS |
| pwsh.exe 正常执行 | 无解析错误 | pipeline exit=0, stderr bytes=0 | ✅ PASS |
| SKILL 执行说明明确绝对路径 | Phase 1 P1-c 已确认 | 引用 [`diff-integrity.md`](../diff-integrity.md)：Hunk 2 = `@@ -43,0 +44,6 @@` P1-c §2 执行上下文（+6 line insertion，含绝对路径声明与"五个步骤代码块必须在同一 pwsh 7 会话中顺序执行"契约） | ✅ PASS（Phase 1 已核实） |
| 正常启动（`BACKUP_OK\|`） | 存在 ≥ 1 | count=1，`BACKUP_OK\|20260910-225759687` | ✅ PASS |
| 正常启动（`FETCH_COMPLETE\|`） | 存在 ≥ 1 | count=1，`FETCH_COMPLETE\|apiOk=2 apiErr=0 total=2` | ✅ PASS |

### T1 PASS 条件判定

- **PS7** ✅ (`PS_VERSION|7.6.4`)
- **明确路径** ✅ (Phase 1 `diff-integrity.md` Hunk 2 P1-c)
- **正常启动** ✅ (`BACKUP_OK|` + `FETCH_COMPLETE|`)

**Verdict: PASS**

## PS<7 拒绝行为验证（T16 修订，可选）

- **测试工具**：`lib/p3-ps5-reject.ps1`，由 `powershell.exe` (PS 5.1.22621.963) 执行 `lib/step1.ps1`
- **证据文件**：
  - `T1-PS7/ps5-stdout.txt` — step1 原始 stdout（PS5.1 环境下为空）
  - `T1-PS7/ps5-stderr.txt` — 判定摘要（`MARKER_MATCHED` / `PARSER_ERROR_COUNT` / `REJECTION_KIND` / `PS5_REJECT_VERDICT`）
  - `T1-PS7/ps5-parse-errors.txt` — Parser.ParseFile 报告的具体语法错误条目
- **观察结果**：PS5.1 parser 层拒绝 step1.ps1（parser errors 8 条，脚本未启动）
  - `MARKER_MATCHED=False`（stdout 中未出现 `RUNTIME_ERROR|PowerShell 7.x required`，因为 L3-6 版本检查代码未执行到）
  - `PARSER_ERROR_COUNT=8`（`Parser.ParseFile` 直接读取脚本报告 8 条语法错误，涉及 L24 `.env` 解析正则的 char class 语法、L66 `[TimeSpan]::FromHours(8)` 等 PS7-only 写法）
  - `REJECTION_KIND=PARSER_REJECTION`
- **判定**：`PS5_REJECT_VERDICT=PASS` — PS<7 拒绝行为成立（**更强形式**：脚本根本未被加载）
- **判定规则（T16 修订扩展）**：三种拒绝路径任一即视为 PASS：
  1. `EXPLICIT_MARKER` — SKILL L3-6 输出 `RUNTIME_ERROR|PowerShell 7.x required`（若脚本能加载到该分支）
  2. `PARSER_REJECTION` — parser 层拒绝，脚本未启动（**本轮实测此路径**）
  3. `NONZERO_EXIT` — 脚本执行但非零退出
- SKILL 内的显式版本检查代码路径（step1.ps1 L3-6 `if ($PSVersionTable.PSVersion.Major -lt 7) { Write-Output ('RUNTIME_ERROR|PowerShell 7.x required, current: {0}' ...) }`）在 PS7 环境下由 `#Requires -Version 7.0` 属性 + parser 层拒绝共同前置保护。

## 附加观察

- `RUN_STATUS|success|` count=1，完整成功链在 T1 环境下亦完整执行（本 Task 只关注启动，此处不作为 T1 PASS 依据，仅记录）
- `COMMIT_OK|` 存在，md 已原子替换
- `LOCK_AFTER_EXISTS=False`，锁已释放
- md SHA256 changed (True)
- 主 md 表格行数 before=2 / after=2，repo 集合一致，flag 全部合法（`yes`/`no`）

## 证据索引

| 文件 | 内容 |
|---|---|
| `T1-PS7/stdout.txt` | 完整 pipeline stdout（含 `PS_VERSION|7.6.4` marker 行） |
| `T1-PS7/stderr.txt` | pipeline stderr（空，0 bytes） |
| `T1-PS7/fixture-stdout.txt` | fixture 生成日志 |
| `T1-PS7/before/` / `after/` | 状态文件快照 |
| `T1-PS7/md-before.md` / `md-after.md` | 主 md 副本 |
| `T1-PS7/result-before.json`（空） / `result-after.json` | `.monitor/result.json` 副本 |
| `T1-PS7/sha256-before.txt` / `sha256-after.txt` | 主 md SHA256 |
| `T1-PS7/lock-before.txt` / `lock-after.txt` | 锁存在性记录 |
| `T1-PS7/validation.json` | 结构化验证指标 |
| `T1-PS7/ps5-stdout.txt` / `ps5-stderr.txt` | PS<7 拒绝行为证据 |
| `T1-PS7/test-report.md` | 本报告 |
