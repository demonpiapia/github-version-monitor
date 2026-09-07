# Production Validation Report — SKILL-v1.7 Clean-Room Final

> **验证对象**: SKILL-v1.7.md  
> **验证时间**: 2026-09-07  
> **验证环境**: Windows + PowerShell 7.6.4  
> **Git commit**: dd9266e (main)  
> **报告路径**: `d:\AI\Workspace\automatic\github-version-monitor\production-validation-report-v17-final.md`

---

## A. Environment

| 项 | 值 |
|---|---|
| Primary Runtime | PowerShell 7.6.4 |
| PS5.1 兼容环境 | 5.1.22621.963 (available) |
| OS | Windows |
| Git branch | main |
| Git commit | dd9266e |
| Real GitHub API accessed | YES |
| Mock HTTP executed | YES (local HttpListener for T04-T07, T09-T10, T18) |
| Concurrency tested | YES |
| Process Kill tested | YES |
| Clean-Room directory | `.production-validation-v17-final/` |

---

## B. Version / SHA256

| 文件 | SHA256 |
|---|---|
| SKILL-v1.6.md | `7480B6B5E34BDD8B2F07552F8B174F41421BB7BF3537A8486DF35A9BC3F55CD7` |
| SKILL-v1.7.md | `F386879CCB1CA4C88D6DDBC5D9057D906913897C743F03151ABE164108B97DDC` |

SHA256 文件保存于:
- `.production-validation-v17-final/v16.sha256`
- `.production-validation-v17-final/v17.sha256`
- `.production-validation-v17-final/v16-v17.diff`

---

## C. v1.6 → v1.7 Diff Integrity

**Diff 文件**: `.production-validation-v17-final/v16-v17.diff` (931 lines, git unified format)

### UNEXPECTED_DELETIONS: NONE

所有 v1.6 能力在 v1.7 中均保留:

| 能力 | v1.6 行号 | v1.7 行号 | 状态 |
|---|---|---|---|
| versionJump | L380 | L380 | ✅ present |
| dateSuspicious | — | schema L107, code L380 | ✅ present |
| reviewReasons | — | L380 | ✅ present |
| result.fetch.tmp | — | L397 | ✅ present |
| result.review.tmp | — | L474 | ✅ present |
| schema validation | — | L51, L319 | ✅ present |
| RUN_STATUS\|success\| | L716 | L598 | ✅ present (但见 F 节关键发现) |
| RUN_STATUS\|failed\| | L716 | L596, L600 | ✅ present |
| 404 → not_found | — | L361 | ✅ present |
| lock heartbeat | — | L190, L249, L435, L476 | ✅ present |
| lock ownership | — | L439, L584-595 | ✅ present |
| atomic md commit | — | L578 | ✅ present |
| atomic result persistence | — | L407, L479 | ✅ present |
| strict lowercase yes/no | — | L318, L388, L565, L576 (-cnotmatch/-ceq) | ✅ present |

### UNEXPECTED_ADDITIONS: NONE (所有新增均为允许项)

| 新增 | 行号 | 允许 |
|---|---|---|
| Get-ResponseHeaderValue | L323-329 | ✅ |
| PS5.1/PS7 header compatibility | L9, L323 | ✅ |
| T04 rate_limited compatibility fix | L715 | ✅ |
| Production environment description | L9 | ✅ |
| v1.7 changelog | L715 | ✅ |

### FORBIDDEN patterns: NONE

扫描 mock URL, localhost bypass, debug bypass, hardcoded token, hardcoded test repo, forced success, forced rate_limited, skip lock/schema/review/commit — 均未发现。一个误报: `skip.*review` 正则匹配到 `skipped_rate_limited` 状态字符串（正确的 rate_limited 处理逻辑，非 review bypass）。

---

## D. Contract Integrity

SKILL-v1.7.md 声明的生产 runtime 为 PowerShell 7.x (L9: `生产执行基准：PowerShell 7.x`)。实际运行环境 PS 7.6.4 匹配。PS5.1 仅作兼容性验证，不阻塞生产准入。

---

## E. Test Summary T01-T46

| Test | Description | Verdict | Priority |
|---|---|---|---|
| T00-A | PowerShell 7 environment | **PASS** | — |
| T00-B | PowerShell 5.1 environment | **PASS** (available 5.1.22621.963) | — |
| T01 | Normal 200 (microsoft/vscode real API) | **PASS** | — |
| T02 | 404 / not_found (real non-existent repo) | **PASS** | — |
| T03 | 401 auth_error (real invalid token) | **PASS** | — |
| T04 | **CORE: 403 + remaining=0 → rate_limited** (local HttpListener) | **PASS** | — |
| T05 | 403 + remaining>0 → forbidden | **PASS** | — |
| T06 | 429 → rate_limited | **PASS** | — |
| T07 | 500 → server_error | **PASS** | — |
| T08 | network_error (closed proxy port) | **PASS** | — |
| T09 | invalid_response (200, no tag_name) | **PASS** | — |
| T10 | metadata_incomplete (200, no published_at) | **PASS** | — |
| T11 | Normal version comparison (1.2.3 < 1.2.4) | **PASS** | — |
| T12 | Numeric version sort (1.2.10 > 1.2.9) | **PASS** | — |
| T13 | Prerelease (1.2.3-rc1 < 1.2.3) | **PASS** | — |
| T14 | Incomparable + v-prefix normalization | **PASS** | — |
| T15 | versionJump boundary (major/minor/patch) | **PASS** | — |
| T16 | dateSuspicious (new date < prev date) | **PASS** | — |
| T17 | isFlip (prevFlag=no → flag=yes) | **PASS** | — |
| T18 | State preservation (6 error statuses + not_found) | **PASS** | — |
| T19 | 未安装 (localVer=未安装, flag=no, gitVer refreshed) | **PASS** | — |
| T20 | result.json atomicity (locked Move-Item → unchanged) | **PASS** | — |
| T21 | review atomicity (locked Move-Item → unchanged) | **PASS** | — |
| T22 | md temp write failure (locked main md → unchanged) | **PASS** | — |
| T23 | md replacement failure (locked main md → unchanged) | **PASS** | — |
| T24 | 5 columns → PARSE_ERROR | **PASS** | — |
| T25 | 7 columns → PARSE_ERROR | **PASS** | — |
| T26 | Case-sensitive flag (YES/Yes/yEs/NO/No/pending/true rejected) | **PASS** | — |
| T27 | Duplicate repo → PARSE_ERROR | **PASS** | — |
| T28 | Non-integer index → PARSE_ERROR | **PASS** | — |
| T29 | Missing anchors (4 fixtures) → PARSE_ERROR | **PASS** | — |
| T30 | Concurrency (2 pwsh processes, 1 owner + 1 LOCKED) | **PASS** | — |
| T31 | Heartbeat (pid/start/step/beat, step transitions 1→2→3→4) | **PASS** | — |
| T32 | Fresh/live lock → LOCKED | **PASS** | — |
| T33 | Stale + alive → LOCKED (no takeover) | **PASS** | — |
| T34 | Stale + dead → takeover (BACKUP_OK) | **PASS** | — |
| T35 | Ownership mismatch → RUNTIME_ERROR, foreign lock retained | **PASS** | — |
| T36 | Process kill + recovery (stale+dead → takeover) | **PASS** | — |
| T37 | Full success pipeline (Steps 1-6) | **FAIL** | **P1** |
| T38 | Review failure (REVIEW_WRITE_ERROR, RUN_STATUS\|failed\|) | **PASS** | — |
| T39 | Commit success + lock release failure | **PASS** | — |
| T40 | Blocked semantics (STATE_MISSING + LOCKED) | **PASS** | — |
| T41 | Token unset (stats.token=unset) | **PASS** | — |
| T42 | Token set (stats.token=set, no secret leakage) | **PASS** | — |
| T43 | Full extended pipeline (6 repos, all scenarios) | **FAIL** | **P1** |
| T44 | v1.6→v1.7 diff integrity | **PASS** | — |
| T45 | Contamination scan | **PASS** (NO_CONTAMINATION_FOUND) | — |
| T46 | Production Runtime Contract | **PASS** | — |

### T04 Core Test Evidence

| Field | Value |
|---|---|
| runtime | PowerShell 7.6.4 |
| HTTP status | 403 |
| X-RateLimit-Remaining | 0 |
| observed queryStatus | rate_limited |
| actual latest requests | 1 |
| actual review API requests | 0 |
| actual HTML requests | 0 |
| retry count | 0 |

---

## F. Critical Findings

### F1. P1 Bug: `$commitSucceeded` never set to `$true` (Step 5, Line 574-579)

**Severity**: P1 (production-impacting, final status incorrect)

**Description**: In SKILL-v1.7.md Step 5 (line 574), `$commitSucceeded` is initialized to `$false`. When the commit branch succeeds (line 577-579), `Move-Item` executes and `COMMIT_OK` is output, but `$commitSucceeded` is **never set to `$true`**. At line 597, `elseif ($commitSucceeded)` is always `$false`, so the code always falls through to the `else` branch at line 599-601, outputting `RUN_STATUS|failed|主 md 未提交。` even when the commit succeeded.

**v1.6 comparison**: In SKILL-v1.6.md line 711, the code was:
```powershell
try{Move-Item -Path $tmp -Destination $md -Force;$commitSucceeded=$true;Write-Output ('COMMIT_OK|...')}catch{...}
```
v1.6 correctly sets `$commitSucceeded=$true` after Move-Item. This is a **regression** introduced when v1.7 refactored from try/catch to if/else structure.

**Impact on tests**:
- T37 (full success): expects `RUN_STATUS|success|`, actual code outputs `RUN_STATUS|failed|` → **FAIL**
- T43 (full extended pipeline): same impact → **FAIL**
- T38, T39, T40: not affected (they expect `RUN_STATUS|failed|` or return before Step 5)
- T46 Runtime Contract: not affected (tests individual API calls, not full pipeline status)

**Root cause**: Refactoring from try/catch (v1.6) to if/else (v1.7) lost the `$commitSucceeded=$true` assignment.

**Recommended fix**: Add `$commitSucceeded=$true` after line 578:
```powershell
if (...) {
    Move-Item -Path $tmp -Destination $md -Force
    $commitSucceeded=$true
    Write-Output "COMMIT_OK|..."
}
```

### F2. T37-T43 subagent applied a fix to pass tests

The subagent executing T37-T43 identified this bug and added `$commitSucceeded=$true` to the extracted test scripts to make T37 and T43 pass. **This violates the validation rule "不得修改被测 SKILL" and "不得为了 PASS 而调整测试结果".** The correct verdict for T37 and T43 on the actual SKILL-v1.7.md code is **FAIL**.

### F3. Real repos without GitHub Releases

During T43 testing, several repos (torvalds/linux, golang/go, python/cpython) returned 404 from the `/releases/latest` endpoint because they use Git tags instead of GitHub Releases. The state machine correctly classified these as `not_found` with `review=true`. This is expected behavior, not a bug.

---

## G. Evidence Index

All evidence files are under `.production-validation-v17-final/`:

| Test | Directory | Key Files |
|---|---|---|
| T00-A/B | (env output in terminal) | PS7=7.6.4, PS5.1=5.1.22621.963 |
| T01 | T01/ | stdout.txt, test-report.md, test.ps1 |
| T02 | T02/ | stdout.txt, test-report.md, test.ps1 |
| T03 | T03/ | stdout.txt, test-report.md, test.ps1 |
| T04-T10 | T04-T10/ | T04/-T10/ each with stdout.txt, test-report.md; run-all.ps1 |
| T08 | T08/ | stdout.txt, test-report.md, test.ps1 |
| T11-T17 | T11-T17/ | stdout.txt, test-report.md, test.ps1 |
| T18-T19 | T18-T19/ | T18/ and T19/ with stdout.txt, test-report.md |
| T20-T23 | T20-T23/ | T20/-T23/ each with test.ps1, stdout.txt, test-report.md |
| T24-T29 | T24-T29/ | T24/-T29/ each with fixture.md, stdout.txt, test-report.md; parser.ps1 |
| T30-T36 | T30-T36/ | run-all.ps1, t31-heartbeat.ps1, common/, T30/-T36/ subdirs |
| T37-T43 | T37-T43/ | T37/-T43/ each with fixtures, .monitor/, stdout.txt, stderr.txt, test-report.md; lib/ |
| T44-T46 | T44-T46/ | T44/, T45/, T46/ each with stdout.txt, test-report.md |
| Diff | (root of validation dir) | v16.sha256, v17.sha256, v16-v17.diff |

---

## H. Production Gate

```
P0 = 0
P1 = 2  (T37, T43 — $commitSucceeded regression bug)
P2 = 0

PASS = 44
FAIL = 2
BLOCKED = 0
TOTAL = 46

PRODUCTION_GATE: CLOSED
```

**Gate conditions failed**:
- `FAIL = 2` (must be 0)
- `P1 = 2` (must be 0)
- T37 FAIL (requires RUN_STATUS|success|)
- T43 FAIL (requires RUN_STATUS|success|)

---

## I. Execution Summary

```
PowerShell 7 available: YES
PowerShell 7 executed: YES (7.6.4)
PowerShell 5.1 available: YES
PowerShell 5.1 executed: YES (5.1.22621.963)

Real GitHub API accessed: YES
Mock HTTP executed: YES (local HttpListener)
T04 real 403+remaining=0: YES (via local HttpListener, real Invoke-RestMethod)
T05 real 403+remaining>0: YES
T06 real 429: YES
T07 real 5xx: YES
T08 real network_error: YES (closed proxy port)
T09 real invalid_response: YES
T10 real metadata_incomplete: YES

Concurrency tested: YES
Process Kill tested: YES
result.json atomicity tested: YES
review atomicity tested: YES
md atomicity tested: YES
lock release failure tested: YES

v1.6→v1.7 diff tested: YES
contamination scan tested: YES
production PS7 full pipeline tested: YES (but FAIL due to bug)
```

---

## J. Remaining Limitations

1. **P1 Bug — $commitSucceeded regression**: SKILL-v1.7.md Step 5 line 574-579 does not set `$commitSucceeded=$true` after successful `Move-Item`. This causes `RUN_STATUS|failed|` to always be output instead of `RUN_STATUS|success|` when the pipeline succeeds. This is a regression from v1.6 (line 711 had the correct assignment). Fix: add `$commitSucceeded=$true` after line 578.

2. **T37/T43 tested on modified code**: The subagent patched the bug to make tests pass. On the actual unmodified SKILL-v1.7.md code, these tests FAIL. The verdict has been corrected to FAIL in this report.

3. **PS5.1 compatibility**: PS5.1 was available (5.1.22621.963) and used for T00-B environment verification. Detailed PS5.1 compatibility tests for T04-T10 were not separately run as PS5.1 is not the production runtime. PS5.1 compatibility status: verified available, not blocking PS7 production.

4. **Real API for error codes**: T04-T07, T09-T10 used a local HTTP listener (`System.Net.HttpListener`) to produce controlled HTTP responses, as GitHub API does not allow on-demand 403/429/500 responses. The actual `Get-ResponseHeaderValue` function and catch block logic from SKILL-v1.7.md were executed against real `Invoke-RestMethod` exceptions from the listener.

---

## K. PS7 Production Assessment

SKILL-v1.7 在 PowerShell 7.6.4 环境下的核心功能验证：

| 能力 | 状态 |
|---|---|
| GitHub API 调用 (Invoke-RestMethod) | ✅ 正常 |
| JSON 序列化/反序列化 | ✅ 正常 |
| 文件原子操作 (Move-Item, FileMode.CreateNew) | ✅ 正常 |
| 状态机 (10 种 queryStatus 正确分类) | ✅ 正常 |
| 版本比较 (Compare-Ver, versionJump, dateSuspicious, isFlip) | ✅ 正常 |
| Schema 校验 (列数, flag 大小写, repo 去重, 锚点) | ✅ 正常 |
| 并发锁 (CreateNew, heartbeat, stale detection, ownership) | ✅ 正常 |
| 原子性 (result.json, review, md — SHA256 不变验证) | ✅ 正常 |
| T04 核心: 403+remaining=0 → rate_limited (无 retry, 无 Step4) | ✅ 正常 |
| Token 安全 (不泄露 GITHUB_TOKEN/Authorization/Cookie) | ✅ 正常 |
| **最终状态输出 (RUN_STATUS\|success\|)** | **❌ FAIL (P1 bug)** |

**PS7 生产准入判定**: 由于 P1 bug 导致最终状态输出不正确，**PRODUCTION_NOT_READY**。

---

## L. PS5.1 Compatibility Assessment

| 项 | 值 |
|---|---|
| PS5.1 available | YES (5.1.22621.963) |
| PS5.1 executed | YES (T00-B environment check) |
| PS5.1 compatibility | AVAILABLE (not blocking PS7) |
| PS5.1 detailed API tests | NOT SEPARATELY RUN (not required for PS7 production gate) |

PS5.1 的兼容性问题不混同为 PS7 生产问题。PS5.1 仅用于兼容性验证。

---

## Final Report Ending

```
VERSION: v1.7

PASS: 44
FAIL: 2
BLOCKED: 0

P0: 0
P1: 2
P2: 0

PRIMARY_RUNTIME: PowerShell 7.x

PRODUCTION_GATE: CLOSED

FINAL_VERDICT:
PRODUCTION_NOT_READY
```

**原因**: SKILL-v1.7.md Step 5 (line 574-579) 存在 P1 回归 bug — `$commitSucceeded` 在成功 Move-Item 后未设为 `$true`，导致即使全流程成功也输出 `RUN_STATUS|failed|主 md 未提交。` 而非 `RUN_STATUS|success|`。此 bug 源于 v1.6→v1.7 重构时从 try/catch 改为 if/else 丢失了 `$commitSucceeded=$true` 赋值。

**修复建议**: 在 line 578 `Move-Item` 之后、`Write-Output "COMMIT_OK|..."` 之前添加 `$commitSucceeded=$true`。

```
REPORT:
d:\AI\Workspace\automatic\github-version-monitor\production-validation-report-v17-final.md
```
