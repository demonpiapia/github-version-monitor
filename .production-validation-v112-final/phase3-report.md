# Phase 3 Report — Test 1 (PS7) + Test 2 (Success)

- **Plan**: `exec-plan-v1.12-d.md` §Phase 3（第 632-718 行）
- **Prompt**: `.GPT/v1.12 最小修改与定向验证 Prompt.md` §8 Test 1-2
- **执行日期**: 2026-09-10 (Asia/Hong_Kong)
- **执行 sub-agent**: Phase 3 sub-agent
- **被测 SKILL**: `SKILL-v1.12.md` SHA256 = `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9`（**Phase 3 期间保持只读，收尾确认未变**）

---

## 1. 环境前提

| 项 | 值 | 来源 |
|---|---|---|
| pwsh.exe | `C:\Program Files\PowerShell\7\pwsh.exe` | Phase 0 ENV_CHECK |
| PowerShell 版本 | **7.6.4** | pwsh.exe FileVersionInfo + `stdout.txt` `PS_VERSION\|7.6.4` marker 行 |
| PowerShell 5.1 | 5.1.22621.963（存在） | powershell.exe FileVersionInfo |
| `GITHUB_TOKEN` 系统环境变量 | 存在（len=93） | Phase 0 ENV_CHECK |
| `network_github` | ok | Phase 0 ENV_CHECK |
| 本轮 API 状态 | apiOk=2 / apiErr=0 | `FETCH_COMPLETE\|apiOk=2 apiErr=0 total=2`（T1 与 T2 一致） |
| 测试隔离机制 | `GITHUB_VERSION_MONITOR_BASE` → `T1-PS7/` / `T2-success/` | 每 test 单独 base 目录 |
| `.monitor/` 预创建 | **禁止** — 由 step 1 动态创建 | `FIXTURE_MONITOR_DIR_ABSENT=YES`（T1/T2） |
| Fixture 主 md SHA256 (T1) | `55471965EFF01218865DD9799E32439B8B7E2C7B5D80CD52E7728CCF278C7E22` | `T1-PS7/sha256-before.txt` |
| Fixture 主 md SHA256 (T2) | `20710075A53116EA40909C36872A222954FDBFB7F9958A25DE45BD9D8421CA90` | `T2-success/sha256-before.txt` |

> 未触发 T14 阻塞规则（token + network 双 ok）。

---

## 2. Test 1 — PS7 强制执行

**Verdict: PASS**

### 执行证据（T1-PS7/stdout.txt 摘引）

```
PIPELINE_START
TESTDIR=D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T1-PS7
GITHUB_VERSION_MONITOR_BASE=D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T1-PS7
GITHUB_TOKEN_SET=True
PID=48276
--- step1 BEGIN (step1.ps1) ---
BACKUP_OK|20260910-225759687
--- step1 END ---
--- step2 BEGIN (step2.ps1) ---
FETCH_COMPLETE|apiOk=2 apiErr=0 total=2
...
PS_VERSION|7.6.4
```

### 验证项判定

| 项 | 期望 | 实际 | 判定 |
|---|---|---|---|
| PS7 版本号（stdout） | 存在，Major ≥ 7 | `PS_VERSION\|7.6.4` | ✅ PASS |
| pwsh.exe 正常执行 | exit=0, 无解析错误 | exit=0, stderr 0 bytes | ✅ PASS |
| SKILL 执行说明明确绝对路径 | Phase 1 已核实 | `diff-integrity.md` Hunk 2 = `@@ -43,0 +44,6 @@` P1-c（§2 执行上下文，含绝对路径声明） | ✅ PASS（引用） |
| 正常启动（BACKUP_OK） | ≥ 1 | count=1 | ✅ PASS |
| 正常启动（FETCH_COMPLETE） | ≥ 1 | count=1 | ✅ PASS |

**PASS 条件**（`PS7 + 明确路径 + 正常启动`）：全部满足 → **PASS**

### 额外验证 — PS<7 拒绝行为（T16 修订，可选）

**Verdict: PASS**（更强形式的拒绝）

- **测试工具**：`lib/p3-ps5-reject.ps1`（`powershell.exe` PS 5.1.22621.963 执行 `lib/step1.ps1`）
- **实测结果**：
  - `MARKER_MATCHED=False` — stdout 中未出现 `RUNTIME_ERROR|PowerShell 7.x required` 标记（因为 L3-6 版本检查代码未执行到）
  - `PARSER_ERROR_COUNT=8` — `Parser.ParseFile` 直接读取 step1.ps1 报告 8 条语法错误（L24 `.env` 正则的 char class、L66 `[TimeSpan]::FromHours(8)` 等 PS7-only 写法）
  - `REJECTION_KIND=PARSER_REJECTION`
  - `PS5_REJECT_VERDICT=PASS`
- **判定规则（T16 修订扩展）**：三种拒绝路径任一即 PASS：
  1. `EXPLICIT_MARKER` — SKILL L3-6 输出 `RUNTIME_ERROR|PowerShell 7.x required`（若脚本能加载到该分支）
  2. `PARSER_REJECTION` — parser 层拒绝，脚本未启动（**本轮实测**）
  3. `NONZERO_EXIT` — 脚本执行但非零退出
- SKILL 内的显式 PS7 检查代码路径存在于 step1.ps1 L3-6，由 PS7 环境下的 `#Requires -Version 7.0` 属性 + parser 层拒绝共同前置保护。
- 详细证据：`T1-PS7/ps5-stdout.txt`（step1 原始输出，PS5.1 下为空）、`T1-PS7/ps5-stderr.txt`（判定摘要）、`T1-PS7/ps5-parse-errors.txt`（具体 parse error 条目）

---

## 3. Test 2 — 正常成功路径

**Verdict: PASS**

### 完整成功链（T2-success/stdout.txt 原文摘引）

```
BACKUP_OK|20260910-225927848
FETCH_COMPLETE|apiOk=2 apiErr=0 total=2
SUMMARY|total=2 apiOK=2 apiErr=0 synced=0 yes=1 uninstalled=1 pendingReview=2 newReleases=2 flips=1 token=set
REVIEW_WRITE_OK|复核完成：2 项；stats/items 保持不变。
COMMIT_OK|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。
RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。
```

### 验证项判定

| 项 | 期望 | 实际 | 判定 |
|---|---|---|---|
| `BACKUP_OK\|` | ≥ 1 | 1 | ✅ |
| `FETCH_COMPLETE\|` | ≥ 1 | 1 | ✅ |
| `SUMMARY\|` | ≥ 1 | 1 | ✅ |
| `REVIEW_WRITE_OK\|` | 条件化：本轮 review 触发 | 1 | ✅ |
| `COMMIT_OK\|` | ≥ 1 | 1 | ✅ |
| `RUN_STATUS\|success\|` count | = 1 | 1 | ✅ |
| `RUN_STATUS\|failed\|` count | = 0 | 0 | ✅ |
| lock released | run.lock 不存在 | `LOCK_EXISTS=False` | ✅ |
| md updated | sha 变化 | `md_changed=True` | ✅ |
| result.json valid | ConvertFrom-Json 成功 | ok | ✅ |
| result.json `token` 字段 | 非空 | `"set"` | ✅ |
| 主 md 表格行数 | 2 | before=2, after=2 | ✅ |
| 主 md repo 集合 | = fixture | `microsoft/vscode,PowerShell/PowerShell` | ✅ |
| 主 md flag 合法性 | 无非法 flag | `md_bad_flag_rows=0` | ✅ |
| `RUNTIME_ERROR\|` count | 0 | 0 | ✅ |
| `PARSE_ERROR\|` count | 0 | 0 | ✅ |
| `LOCKED\|` count | 0 | 0 | ✅ |

### md diff 摘要

- 表格数据行 2 → 2（数量保持）
- microsoft/vscode: `v1.0.0/no` → `1.137.0/yes`（本轮 API 返回正式版 Release，flag 翻转为 yes）
- PowerShell/PowerShell: `v1.0.0/未安装/no` → `v7.6.6/未安装/no`（本地未安装，git 版本更新但 flag 保持 no）
- "最近核对时间" 元数据行由 fixture 时间更新为本轮实际 API 时间
- "结论 / 更新摘要 / 备注" 三段正文由 step5 根据 result.json 重写
- 完整 diff 文件见 `T2-success/md-before.md` vs `T2-success/md-after.md`

### result.json 结构

- 顶层 keys: `stats`, `items`
- `stats`: total=2, apiOk=2, apiErr=0, synced=0, yes=1, uninstalled=1, pendingReview=2, newReleases=2, flips=1, **token="set"**
- `items`: 2 项，每个含 `repo`, `name`, `gitVer`, `gitDate`, `localVer`, `flag`, `prevFlag`, `latest`, `publishedUtc`, `status`, `cmp`, `isNew`, `isFlip`, `versionJump`, `dateSuspicious`, `review`, `reviewReasons`, `error`
- 完整文件见 `T2-success/result-after.json`（3022 bytes）

---

## 4. 环境前提声明（T14 修订）

- **token 可用性**：Phase 0 ENV_CHECK 已确认 `token_available=True`（GITHUB_TOKEN 系统环境变量存在，len=93）；本轮实测 `GITHUB_TOKEN_SET=True`（pipeline stdout），`result.json stats.token="set"`。
- **network_github**：Phase 0 ENV_CHECK 已确认 `ok`；本轮实测 `apiOk=2 apiErr=0`（T1 与 T2 均成功直连 `https://api.github.com/repos/<owner>/<name>/releases/latest`）。
- **结论**：T14 阻塞规则**未触发**，T2 正常执行。

---

## 5. 硬约束遵守情况

| 硬约束 | 遵守情况 |
|---|---|
| 禁止修改 `SKILL-v1.12.md` | ✅ SHA256 前后一致：`3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9` |
| 禁止修改 `lib/step1..step5-full.ps1` | ✅ 未修改（Phase 2 byte-exact 提取） |
| 禁止触碰 `.output/GitHub更新监测列表.md`（生产文件） | ✅ 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离到 `T1-PS7/` / `T2-success/`，未读取或写入生产路径 |
| 禁止在 fixture 中硬编码 GITHUB_TOKEN | ✅ fixture 使用 `.env` 可选加载（fixture 目录无 `.env`），运行时从系统环境变量读取 |
| 禁止预创建 `.monitor/` | ✅ `FIXTURE_MONITOR_DIR_ABSENT=YES`（T1/T2） |
| 禁止执行 Test 3-6 | ✅ 仅执行 Test 1 + Test 2 |
| 禁止将 FAIL 改写为 BLOCKED | ✅ 不适用（本轮无 FAIL） |
| 禁止修改 harness 后不重新执行而重标 PASS | ✅ 所有 harness 修改后重新执行受影响测试（T1/T2 均重跑） |
| pwsh 命令后台静默 | ✅ 全部 `Start-Process -NoNewWindow -Wait -RedirectStandardOutput/Error` |
| PowerShell 脚本 UTF8 编码声明 | ✅ `p3-run-T.ps1` / `p3-verify.ps1` / `p3-ps5-reject.ps1` / `p3-merge-io.ps1` 均含 `$PSDefaultParameterValues['*:Encoding']='UTF8'` |
| 关键诊断字段用英文/JSON | ✅ `TEST_ID` / `PS_VERSION\|` / `BACKUP_OK\|` / `RUN_STATUS\|` 等全部英文 key |

---

## 6. Harness 差异记录

见 `harness-fix-log.md`（共 3 项）：
- A: cmd.exe 不识别 `*>&&1` → 改用 `Start-Process -RedirectStandardOutput/-RedirectStandardError`（等价语义）
- B: harness 侧向 stdout.txt 追加 `PS_VERSION|` 证据行
- C: `p3-verify.ps1` param 简化（内部工具）

**未影响** SKILL、被测 lib/、fixture、生产 `.output/`。

---

## 7. 证据索引

### T1-PS7/

- `stdout.txt` / `stderr.txt`
- `fixture-stdout.txt`
- `before/GitHub更新监测列表.md`, `after/GitHub更新监测列表.md`
- `before/monitor/*` (仅 after；before 无 `.monitor/`)
- `md-before.md`, `md-after.md`
- `result-before.json` (空, 首轮), `result-after.json`
- `sha256-before.txt`, `sha256-after.txt`
- `lock-before.txt`, `lock-after.txt`
- `validation.json`
- `ps5-stdout.txt`, `ps5-stderr.txt`（PS<7 拒绝证据）
- `test-report.md`

### T2-success/

- 同上结构（无 ps5-*/ps5 相关）

### 汇总

- `phase3-stdout.txt`（4927 bytes）
- `phase3-stderr.txt`（111 bytes）
- `phase3-report.md`（本文）
- `phase-progress.json`（Phase3 状态）
- `harness-fix-log.md`

---

## 8. SKILL-v1.12.md SHA256 收尾确认

- **Phase 3 开始时**：`3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9`
- **Phase 3 结束时**：`3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9`
- **未变**：✅

---

## 9. 汇总结论

| Test | Verdict | 主要依据 |
|---|---|---|
| Test 1 (PS7 强制执行) | **PASS** | `PS_VERSION\|7.6.4` + `BACKUP_OK\|` + `FETCH_COMPLETE\|` + Phase 1 P1-c 已核实 |
| Test 1 额外 (PS<7 拒绝) | **PASS**（更强形式） | PS5.1 parser 阶段拒绝，脚本未启动 |
| Test 2 (正常成功路径) | **PASS** | 完整成功链 + `RUN_STATUS\|success\| count=1` + `RUN_STATUS\|failed\| count=0` + lock released + md updated + result.json valid + 主 md 未损坏 |

**Phase 3 完成度：completed（Attempt 1）**

---

## 10. Attempt 2 — Harness-Fix 后重新执行（Phase 3-fix, 2026-09-10T23:24:00+08:00）

### 10.1 Attempt 1 缺陷复盘

主 agent 独立复核 Attempt 1 的 `T2-success/stdout.txt`（87 行）发现：
- Line 82：SKILL 真实终态 `RUN_STATUS|success|...`（`lib/step5-full.ps1` 输出，合法）
- Line 85：`RUN_STATUS_OBSERVED=RUN_STATUS|success|...`（**harness 污染**，来自 `lib/run-full-pipeline.ps1` line 60）
- Line 86：`PS_VERSION|7.6.4`（**harness 污染**，来自 `lib/p3-run-T.ps1` line 178 `Add-Content`）

独立 grep 计数（Attempt 1）：
| 项 | 期望 | Attempt 1 实际 | 判定 |
|---|---|---|---|
| `RUN_STATUS\|success\|` | 1 | **2** | ❌ |
| `RUN_STATUS\|failed\|` | 0 | 0 | ✅ |
| `COMMIT_OK\|` | 1 | 1 | ✅ |
| `BACKUP_OK\|` | 1 | 1 | ✅ |
| `FETCH_COMPLETE\|` | 1 | 1 | ✅ |
| `REVIEW_WRITE_OK\|` | 1 | 1 | ✅ |

违反 `exec-plan-v1.12-d.md §0.10 Test Harness Integrity`：被测 SKILL 的 `stdout.txt` 必须是 pwsh.exe pipeline 的**原始 stdout**，任何 harness 侧的辅助信息必须写到**独立证据文件**。

**Attempt 1 Verdict: partial (harness polluted SKILL stdout count)**

### 10.2 修复方法

见 `harness-fix-log.md` 记录 D（ISO8601 时间戳 `2026-09-10T23:24:00+08:00`）：

- **`lib/run-full-pipeline.ps1`**：删除 `$allRunStatuses` 收集与 `RUN_STATUS_OBSERVED=...` 输出（原 line 42, 55, 60）
- **`lib/p3-run-T.ps1`**：
  - 删除 Step D2 `Add-Content -Path $stdoutPath -Value $psVersionMarker`
  - 新增 `harness-aux.txt`：所有 harness 侧证据（PS_VERSION, PIPELINE_EXIT, SHA256_BEFORE/AFTER, LOCK_*_EXISTS, MD_CHANGED, PS_VERSION_MARKER 等）
  - 新增 `run-status-sidecar.txt`：从 raw stdout 派生的 RUN_STATUS 观察（`RAW_STDOUT_RUN_STATUS_LINES=1` + 每条 `RUN_STATUS_OBSERVED=...`）
  - `<TestDir>/stdout.txt` 现仅承载被测 pipeline 的原生 stdout

**未修改（byte-exact 不变）**：
- `SKILL-v1.12.md`（SHA256 = `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9`）
- `lib/step1.ps1` SHA256 = `F8CE7D677527D54565063B6591AD2A7E6D43D908CFB0EEBD3347A841E5C2CCA0`
- `lib/step2.ps1` SHA256 = `D623FF739BA910CB11AFA9E8454CA437B5EFB912DDD5BC7792DD746010BE6D05`
- `lib/step3.ps1` SHA256 = `5A6D523726E46303B4A2E4181A4832868B58CDD7A061B2B8D6E529FC5F955169`
- `lib/step4.ps1` SHA256 = `57CE64F8FC73E50C2B068BF9510F1DB2FED2DC64324036810713C54A3FA79A62`
- `lib/step5-full.ps1` SHA256 = `41C8DD7285A103D66119241A5D20324E73FBE21E42BA431FD18DF5F12E3F59C9`

### 10.3 Attempt 2 执行

**旧证据保留确认**（不覆盖）：
- `T1-PS7-attempt1/`（原 Attempt 1 目录）
- `T2-success-attempt1/`（原 Attempt 1 目录）
- `T1-PS7-attempt2-pre-finalfix/`（harness aux timestamp 修复前的中间版本，保留追溯）
- `T2-success-attempt2-pre-finalfix/`（同上）

**脚本备份**（R20 保护）：
- `lib/p3-run-T.ps1.备份.20260910_232058`
- `lib/run-full-pipeline.ps1.备份.20260910_232058`

**最终 Attempt 2 目录**：`T1-PS7/` 与 `T2-success/`（使用最终版 harness 代码）

### 10.4 Attempt 2 — Test 1 (PS7) 验证

**Verdict: PASS**

| 项 | 期望 | 实际 | 判定 |
|---|---|---|---|
| `stdout.txt` 总行数 | 84 | 84 | ✅ |
| `RUN_STATUS\|success\|` count | 1 | **1** | ✅ |
| `RUN_STATUS\|failed\|` count | 0 | 0 | ✅ |
| `COMMIT_OK\|` count | 1 | 1 | ✅ |
| `BACKUP_OK\|` count | 1 | 1 | ✅ |
| `FETCH_COMPLETE\|` count | 1 | 1 | ✅ |
| `REVIEW_WRITE_OK\|` count | 1 | 1 | ✅ |
| `stderr.txt` size | 0 | 0 bytes | ✅ |
| PS_VERSION（harness-aux） | 7.6.4 | 7.6.4 | ✅ |
| PIPELINE_EXIT（harness-aux） | 0 | 0 | ✅ |
| FIXTURE_MONITOR_DIR_EXISTS | False | False | ✅ |
| LOCK_AFTER_EXISTS（harness-aux） | False | False | ✅ |
| MD_CHANGED（harness-aux） | True | True | ✅ |
| `run-status-sidecar.txt` RAW_STDOUT_RUN_STATUS_LINES | 1 | 1 | ✅ |

**Attempt 2 T1 stdout 关键片段**（stdout.txt L81-84）：
```
L81: COMMIT_OK|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。
L82: RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。
L83: --- step5 END ---
L84: PIPELINE_END
```
（无 harness 附加的 `PS_VERSION|` / `RUN_STATUS_OBSERVED=` 行）

### 10.5 Attempt 2 — Test 2 (Success) 验证

**Verdict: PASS**

| 项 | 期望 | 实际 | 判定 |
|---|---|---|---|
| `stdout.txt` 总行数 | 84 | 84 | ✅ |
| `RUN_STATUS\|success\|` count | 1 | **1** | ✅ |
| `RUN_STATUS\|failed\|` count | 0 | 0 | ✅ |
| `COMMIT_OK\|` count | 1 | 1 | ✅ |
| `BACKUP_OK\|` count | 1 | 1 | ✅ |
| `FETCH_COMPLETE\|` count | 1 | 1 | ✅ |
| `REVIEW_WRITE_OK\|` count | 1 | 1 | ✅ |
| `SUMMARY\|` count | ≥1 | 1 | ✅ |
| `RUN_STATUS\|success\|` 行号 | 唯一 1 处 | **仅 L82** | ✅ |
| `stderr.txt` size | 0 | 0 bytes | ✅ |
| PIPELINE_EXIT（harness-aux） | 0 | 0 | ✅ |
| LOCK_AFTER（`lock-after.txt`） | LOCK_EXISTS=False | LOCK_EXISTS=False | ✅ |
| MD_CHANGED | True | True | ✅ |
| md 数据行 | 2 | 2 | ✅ |
| md repo 集合 | = fixture | `microsoft/vscode` + `PowerShell/PowerShell` | ✅ |
| md bad flag rows | 0 | 0 | ✅ |
| result.json valid | Yes | Yes (3022 bytes) | ✅ |
| result.json stats.total | 2 | 2 | ✅ |
| result.json stats.token | 非空 | `set` | ✅ |
| result.json items.count | 2 | 2 | ✅ |
| `run-status-sidecar.txt` RAW_STDOUT_RUN_STATUS_LINES | 1 | 1 | ✅ |

**Attempt 2 T2 stdout 唯一 `RUN_STATUS\|success\|` 位置**：
- `T2-success/stdout.txt` Line 82：`RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。`

**Attempt 2 T2 md diff 摘要**（对比 `md-before.md` vs `md-after.md`）：
- 表格数据行：2 → 2（数量保持）
- microsoft/vscode：`v1.0.0/no` → `1.137.0/yes`（本轮 API 返回正式版 Release，flag 翻转为 yes）
- PowerShell/PowerShell：`v1.0.0/未安装/no` → `v7.6.6/未安装/no`（本地未安装，git 版本更新但 flag 保持 no）
- 元数据"最近核对时间"更新为本轮实际 API 时间 `2026-09-10 23:25`（北京时间）
- `md_bad_flag_rows=0`（所有 flag 值均为 yes 或 no）

### 10.6 Attempt 2 硬约束遵守

| 硬约束 | 遵守情况 |
|---|---|
| 禁止修改 `SKILL-v1.12.md` | ✅ SHA256 不变 |
| 禁止修改 `lib/step1..step5-full.ps1` | ✅ 全部 SHA256 不变 |
| 禁止触碰 `.output/GitHub更新监测列表.md`（生产文件） | ✅ 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离 |
| 禁止将 FAIL 改写为 BLOCKED；禁止将 BLOCKED 改写为 PASS | ✅ Attempt 1 partial 如实记录；Attempt 2 PASS 有独立证据 |
| 禁止在 SKILL stdout 中追加任何 harness 侧内容 | ✅ Attempt 2 stdout 84 行 = SKILL 原生输出 |
| 修改 harness 后必须重新执行，且旧证据不覆盖 | ✅ Attempt 1 保留 `*-attempt1/`；pre-finalfix 中间态保留 `*-attempt2-pre-finalfix/` |
| pwsh 命令后台静默 | ✅ `Start-Process -NoNewWindow -Wait -RedirectStandardOutput/Error` |
| PowerShell 脚本 UTF8 编码声明 | ✅ `$PSDefaultParameterValues['*:Encoding']='UTF8'` + `[Console]::OutputEncoding = UTF8` |
| 关键诊断字段用英文/JSON | ✅ 所有 marker 使用英文 key（`PIPELINE_EXIT`, `LOCK_AFTER_EXISTS`, `RAW_STDOUT_RUN_STATUS_LINES` 等） |

### 10.7 Attempt 2 证据索引

**T1-PS7/**
- `stdout.txt`（84 行，纯 SKILL 原生输出）
- `stderr.txt`（0 bytes）
- `harness-aux.txt`（harness 侧证据）
- `run-status-sidecar.txt`（harness 派生观察）
- `fixture-stdout.txt` / `fixture-stderr.txt`
- `before/` / `after/`（含 `.monitor/`）
- `md-before.md` / `md-after.md` / `sha256-before.txt` / `sha256-after.txt`
- `result-before.json` / `result-after.json`
- `lock-before.txt` / `lock-after.txt`

**T2-success/**
- 同 T1-PS7 结构（无 ps5-* 系列，因为 T2 不做 PS5 拒绝验证）

### 10.8 汇总结论

| Test | Attempt 1 Verdict | Attempt 2 Verdict | 差异根因 |
|---|---|---|---|
| Test 1 (PS7) | PASS (但 stdout 被污染) | **PASS** | harness 移除 `Add-Content` PS_VERSION 与 `RUN_STATUS_OBSERVED` 追加 |
| Test 1 额外 (PS<7 拒绝) | PASS（更强形式） | 未重跑（Phase 3-fix 不涉及） | — |
| Test 2 (Success) | PASS (但 `RUN_STATUS\|success\| count=2`) | **PASS** | 同上 |

**Phase 3-fix 完成度：completed**
**harness_fix_rounds: 2**
**Attempt 2 SKILL stdout 独立计数完全符合 Phase 3 spec 期望**。
