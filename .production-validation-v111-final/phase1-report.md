# Phase 1 Report — SKILL-v1.11 定向生产验证

**执行时间**：2026-09-09 15:14 – 17:21 (Asia/Hong_Kong)
**执行者**：sub-agent instance 1（Steps 1-6）+ instance 2（Steps 7-fix / 7.1 / 8 / 报告补齐）
**被测文件**：`SKILL-v1.11.md`（SHA256 = `B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928`，全程未变）
**状态**：completed

---

## 1. Step 1 — Diff 生成

- 命令：`git diff --no-color -U0 SKILL-v1.10.md SKILL-v1.11.md > v110-v111.diff`
- 输出：`.production-validation-v111-final/v110-v111.diff`
- 实测 hunk 数：**3**；新增行：**3**；删除行：**2**（与计划 §0.2 表一致）

## 2. Step 2 — Hunk 核验

- 输出：`.production-validation-v111-final/diff-integrity.md` §2
- 3 个 hunk 逐项核验：
  1. L5 版本号行 v1.10 → v1.11（documentation）— PASS
  2. L480 stats/items 完整性失败路径行尾补齐 `;return`（核心修复）— PASS
  3. L765 Changelog 新增 v1.11 条目 — PASS
- **L480 `;return` 逐字节确认**：v1.10 L480 长度=552；v1.11 L480 长度=559；差值=7（return 插入长度=7）；首个差异字节位置=545；插入内容=`;return`；纯插入，无其他改动。

## 3. Step 3 — 30 项能力保留核验

- 输出：`.production-validation-v111-final/diff-integrity.md` §3
- 30 项能力逐项核验：**30/30 PASS**
- 判定口径：能力在 v1.11 中存在（行号证据）且未从文件中消失；L480 删除行属"行内替换（能力保留 + 追加 return）"，非能力删除。

## 4. Step 4 — 9 项辅助禁止项检查

- 输出：`.production-validation-v111-final/diff-integrity.md` §4
- 9 项辅助禁止项（计划内部防御性检查，非 Prompt 明文要求）：**9/9 PASS**

## 5. Step 5 — 代码提取

- 输出：`.production-validation-v111-final/lib/step1.ps1` ~ `step5-full.ps1` + `extraction-manifest.json` + `extraction-verify.txt`
- 5 个提取脚本 source_lines 实测值（与计划估算值对比）：

| 脚本 | source_lines（实测） | fence_lines | code_lines | SHA256 |
|---|---|---|---|---|
| step1.ps1 | 161-230 | 160-231 | 70 | F07C486AF3FCE83E24904041CD1D471466FE27DDE3DB38416553DFB864A1A689 |
| step2.ps1 | 240-422 | 239-423 | 183 | EF851690C516BB85EA00232864ECD868E8BEE92BA2794E46E8654C27784522D0 |
| step3.ps1 | 432-451 | 431-452 | 20 | F8CE8F248BFDA24884AD1092392A4199861DB3AE55E41C1AD292C4511449DBFF |
| step4.ps1 | 473-509 | 472-510 | 37 | A7825A39C3D844951AFB4C6774CFDF75F45F7705951F51AC641645654462E159 |
| step5-full.ps1 | 521-654 | 520-655 | 134 | 81C4D352AF2C5C6A5926453E4F7A81BE3B0E4A6EAB7A572542F77053A1721AA9 |

- 零差异验证（`extraction-verify.txt`）：**5/5 PASS**（bytes=2988/14137/1571/5866/6439，全部 zero-diff）

## 6. Step 6 — 14 个 harness 产出

清单（全部位于 `lib/`）：

| # | 文件 | 用途 |
|---|---|---|
| 1 | t38-orchestrator-a.ps1 | T38-A 编排器 |
| 2 | t38-orchestrator-b.ps1 | T38-B 编排器（注入点 L17/L18 = SKILL L489/L490，tmp 篡改） |
| 3 | t38-orchestrator-c.ps1 | T38-C 编排器 |
| 4 | t38-orchestrator-heartbeat.ps1 | T38-heartbeat 编排器 |
| 5 | t38-orchestrator-result-read.ps1 | T38-result-read 编排器 |
| 6 | t38-orchestrator-stats-items.ps1 | T38-stats-items 编排器（注入点 L7/L8 = SKILL L479/L480，stats 篡改） |
| 7 | t22-orchestrator.ps1 | T22 编排器 |
| 8 | t23-orchestrator.ps1 | T23 编排器 |
| 9 | step5-t39-harness.ps1 | T39 harness（注入点 L116/L117 = SKILL L636/L637，PID 重写） |
| 10 | runtime-artifact-pipeline.ps1 | Runtime artifact 管线 |
| 11 | run-full-pipeline.ps1 | T37/T43 单进程完整管线 |
| 12 | lock-holder.ps1 | 外部锁持有进程 |
| 13 | watch-dir.ps1 | 目录监视进程 |
| 14 | （辅助）create-fixture.ps1 / extract-code.ps1 / splice-inline.ps1 / verify-extraction.ps1 / diff-integrity-check.ps1 / ps51-syntax-check.ps1 | fixture / 提取 / 内联注入 / 验证 / 语法检查 |

- 注入点验证：T38-B = step4.ps1 L17/L18（SKILL L489/L490）；T38-stats-items = step4.ps1 L7/L8（SKILL L479/L480）；T39 = step5-full.ps1 L116/L117（SKILL L636/L637）— 全部与计划声明一致。

## 7. Step 7 — Mock 工具创建

- 产出：`lib/mock-invoke-restmethod.ps1`、`lib/step2-mock-harness.ps1`、`lib/create-fixture.ps1`
- localVer 策略：synced/versionJump 运行时动态查询 releases/latest；404 使用不存在的 repo；normal/uninstalled/unsupported 固定 fixture；t38 单个 404 repo；t43 6 场景。

### 7-fix. Mock 异常构造修复（instance 2 执行）

**已知缺陷**：原 `New-MockHttpException` 返回 `PSCustomObject`，但 `throw $PSCustomObject` 会被 PowerShell 包装为 `RuntimeException`，原始自定义属性全部丢失 → `$_ .Exception.Response = $null` → 所有异常场景误判为 `network_error`。

**修复内容**（`lib/mock-invoke-restmethod.ps1`）：

1. `New-MockHttpException`：`return PSCustomObject` → `return New-Object WorkbuddyMock.MockHttpResponseException($Message, $Response)`
2. `New-MockHttpResponse`：`return PSCustomObject` → `return New-Object WorkbuddyMock.MockHttpResponse(...)`（PSCustomObject 有内置 Headers 属性会 shadow 自定义 Headers）
3. `New-MockResponseHeaders`：`return $h` → `Write-Output -NoEnumerate $h`（WebHeaderCollection 实现 ICollection，return 会被自动枚举展开为 string）
4. Add-Type 类型定义：新增 `WorkbuddyMock.MockHttpResponse` 类（StatusCode + Headers 属性）；`MockHttpResponseException` 保留
5. 文件行尾从 LF 修正为 CRLF（PS5.1 解析 LF 行尾的 here-string 内嵌 C# 代码块会报 Unexpected token '}'）

**修复前 vs 修复后**：

| 场景 | 修复前 | 修复后 |
|---|---|---|
| 404 | EXCEPTION_TYPE=RuntimeException, RESPONSE_TYPE=<null>, STATE_MACHINE=network_error | EXCEPTION_TYPE=MockHttpResponseException, RESPONSE_TYPE=MockHttpResponse, STATE_MACHINE=not_found |
| 401 | 同上 → network_error | auth_error |
| 429 | 同上 → network_error | rate_limited |
| 403+0 | 同上 → network_error | rate_limited |
| 403+50 | 同上 → network_error | forbidden |
| 500 | 同上 → network_error | server_error |
| 302 | 同上 → network_error | http_error |
| network_error | EXCEPTION_TYPE=RuntimeException, RESPONSE_TYPE=<null>, STATE_MACHINE=network_error | EXCEPTION_TYPE=MockHttpResponseException, RESPONSE_TYPE=<null>, STATE_MACHINE=network_error |

### 7-fix. 8 场景实测验证

命令：`pwsh -NoProfile -NonInteractive -File lib\mock-contract-selfcheck.ps1`
结果：**PASS_COUNT=8, FAIL_COUNT=0**

| 场景 | EXCEPTION_TYPE | RESPONSE_TYPE | STATUSCODE | HEADERS_TYPE | RL | STATE_MACHINE | 判定 |
|---|---|---|---|---|---|---|---|
| 404 | MockHttpResponseException | MockHttpResponse | NotFound(int=404) | WebHeaderCollection | 50(string) | not_found | PASS |
| 401 | MockHttpResponseException | MockHttpResponse | Unauthorized(int=401) | WebHeaderCollection | 50(string) | auth_error | PASS |
| 429 | MockHttpResponseException | MockHttpResponse | TooManyRequests(int=429) | WebHeaderCollection | 0(string) | rate_limited | PASS |
| 403+0 | MockHttpResponseException | MockHttpResponse | Forbidden(int=403) | WebHeaderCollection | 0(string) | rate_limited | PASS |
| 403+50 | MockHttpResponseException | MockHttpResponse | Forbidden(int=403) | WebHeaderCollection | 50(string) | forbidden | PASS |
| 500 | MockHttpResponseException | MockHttpResponse | InternalServerError(int=500) | WebHeaderCollection | 50(string) | server_error | PASS |
| 302 | MockHttpResponseException | MockHttpResponse | Found(int=302) | WebHeaderCollection | 50(string) | http_error | PASS |
| network_error | MockHttpResponseException | <null> | — | — | — | network_error | PASS |

### 7-fix. PS5.1 语法检查

命令：`powershell.exe -NoProfile -NonInteractive -File lib\ps51-syntax-check.ps1`
结果：**PS51_TOTAL_ERRORS=0**
- mock-invoke-restmethod.ps1: PS51_SYNTAX_OK
- step2-mock-harness.ps1: PS51_SYNTAX_OK

## 7.1. Mock contract 对齐自检

- 输出：`.production-validation-v111-final/lib/mock-contract-selfcheck.txt`
- 按 SKILL-v1.11.md L341-367 逐成员模拟访问，8 个异常场景 + 4 个成功路径场景（normal/versionJump/metadata_incomplete/invalid_response 未在本轮实测中展开，但 mock 库已实现）
- **PS7 Headers 类型选择**：`System.Net.WebHeaderCollection`
  - 理由：与 PS5.1 共用同一 mock 库；WebHeaderCollection 支持索引器访问与 `.Get(name)` 方法，SKILL L357-358 通过 `Get-ResponseHeaderValue` 函数封装访问（先 `.Get()`，再索引器，再 `TryGetValues`），两者兼容
  - 未选 `HttpResponseHeaders` 形状对象：构造复杂度高，且 PS5.1 环境下不可用（.NET Framework 4.5+ 才有）
- **X-RateLimit-Remaining 类型**：`System.String`（SKILL L364 用 `-eq '0'` 字符串比较，故 mock 侧必须为 string 类型）
- **StatusCode 类型**：`System.Net.HttpStatusCode` 枚举实例（SKILL L355 用 `[int]` 显式转换，枚举实例可无损转换）
- **Exception 类型**：`WorkbuddyMock.MockHttpResponseException`（真实 Exception 子类，非 PSCustomObject）
- **Response 类型**：`WorkbuddyMock.MockHttpResponse`（C# 类型，非 PSCustomObject，因 PSCustomObject 内置 Headers 属性会 shadow）
- **Headers 返回类型修复**：`New-MockResponseHeaders` 使用 `Write-Output -NoEnumerate` 而非 `return`，因 WebHeaderCollection 实现 ICollection，return 会被 PowerShell 自动枚举展开为 string

## 8. stdout 透传验证

- 输出：`.production-validation-v111-final/lib/stdout-verification.txt`
- 命令：`pwsh -NoProfile -NonInteractive -File lib\run-full-pipeline.ps1 -BaseDir T37\stdout-verify-base -Scenario normal`
- 隔离 base：`.production-validation-v111-final/T37/stdout-verify-base/`（`.monitor/` 未预创建，由 SKILL 自身初始化）
- EXIT_CODE=0；PIPELINE_PID=44692
- stdout 标记链：

| 行号 | 标记 |
|---|---|
| L1 | PIPELINE |
| L2 | FIXTURE_OK |
| L3 | BACKUP_OK |
| L4 | FETCH_COMPLETE |
| L5 | SUMMARY |
| L6-40 | RESULT_JSON_BLOCK |
| L41 | REVIEW_WRITE_OK |
| L42 | COMMIT_OK |
| L43 | RUN_STATUS\|success |
| L44 | PIPELINE_DONE |

- 必需链 `BACKUP_OK → FETCH_COMPLETE → SUMMARY → COMMIT_OK → RUN_STATUS|success`：**完整透传**
- STDERR_SIZE_BYTES=0
- **结论**：stdout 透传正常 → **T37/T43 采用单次执行捕获 stdout**（`run-full-pipeline.ps1` 一次执行），无需逐 step 执行 + 拼接，也无需按 §0.5 锁 PID 一致性机制处理 step 间锁
- 决策依据：本轮独立验证结果（非旧报告声明）
- 清理策略：保留 `T37/stdout-verify-base/` 作为证据（含 `.output/`、`.monitor/`、`result.json`、`run.lock` 释放后状态），供 Phase 12 self-review 独立复核 stdout 链完整性

## 9. Harness 修复记录（§0.10 协议）

| 时间 (ISO8601) | 修复对象 | 原因 | 说明 |
|---|---|---|---|
| 2026-09-09T17:16:00+08:00 | `lib/mock-invoke-restmethod.ps1` | `New-MockHttpException` 返回 PSCustomObject 导致 `throw` 后 `$_ .Exception.Response = $null`，所有异常场景误判为 network_error | 修复对象为 mock 工具（harness），不属于被测 SKILL；`SKILL-v1.11.md` SHA256 全程未变（`B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928`） |
| 2026-09-09T17:16:30+08:00 | `lib/mock-invoke-restmethod.ps1` | `New-MockHttpResponse` 返回 PSCustomObject，其内置 Headers 属性 shadow 自定义 Headers 属性 | 同上 |
| 2026-09-09T17:17:00+08:00 | `lib/mock-invoke-restmethod.ps1` | `New-MockResponseHeaders` 使用 `return $h`，WebHeaderCollection 实现 ICollection 被自动枚举展开为 string | 同上 |
| 2026-09-09T17:12:00+08:00 | `lib/mock-invoke-restmethod.ps1` / `lib/step2-mock-harness.ps1` / `lib/mock-contract-selfcheck.ps1` / `lib/ps51-syntax-check.ps1` | 文件行尾为 LF，PS5.1 解析 LF 行尾的 here-string 内嵌 C# 代码块报 Unexpected token '}' | 同上 |

> 注：所有 harness 修复均发生在 Phase 1 内部，未执行任何 Phase 2+ 测试，故无需重新执行受影响测试。Phase 2+ 测试将在 harness 修复后首次执行。

## 10. 证据文件清单

| 文件 | 说明 |
|---|---|
| `v110-v111.diff` | 3 hunk / 3+ / 2- |
| `diff-integrity.md` | 30/30 能力 PASS、9/9 辅助禁止项 PASS、L480 `;return` 逐字节确认 |
| `lib/extraction-manifest.json` | 5 个提取脚本 source_lines + SHA256 |
| `lib/extraction-verify.txt` | 5/5 zero-diff PASS |
| `lib/mock-contract-selfcheck.txt` | 8 场景实测验证 PASS、PS7 Headers 类型选择记录 |
| `lib/stdout-verification.txt` | stdout 透传验证 PASS、T37/T43 捕获策略决策 |
| `phase1-stdout.txt` | Step 1-6 提取日志 + Step 7-fix/7.1/8 追加日志 |
| `phase1-stderr.txt` | Step 7-fix/7.1/8 追加日志（空） |
| `phase1-report.md` | 本文件 |
| `phase-progress.json` | Phase 1 进度（覆盖 Phase 0 内容） |

## 11. SKILL-v1.11.md SHA256 复核

- 实测：`B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928`
- 期望：`B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928`
- **MATCH=YES**（全程未变）

## 12. 未验证 / 待续

- Phase 2+ 测试（T38/T22/T23/T37/T39/T43 等）未执行（本轮任务范围外）
- mock 成功路径场景（normal/versionJump/metadata_incomplete/invalid_response）未在本轮实测中展开，但 mock 库已实现，将在 Phase 8（T04-PS7）执行
- Phase 9（PS5.1 兼容性回归）将复用本 mock 库，PS5.1 语法检查已通过（0 errors）
