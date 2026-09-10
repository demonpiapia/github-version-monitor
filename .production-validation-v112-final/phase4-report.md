# Phase 4 Report — Test 3 API failure + Test 4 core write failure

- Phase: **Phase 4**
- Start time: 2026-09-10T16:02:29+08:00
- End time: 2026-09-10T16:14:00+08:00
- Executor: Phase 4 sub-agent (Zoo)
- Tests: **T3-api-failure** + **T4-write-failure** (Test 5/6 NOT executed per Phase 5/6 scope)

## Summary

| Test | Verdict | PASS | FAIL | Scenario |
|---|---|---|---|---|
| T3-api-failure | **PASS** | 35 | 0 | server_500 (mock /releases/latest -> StatusCode=500) |
| T4-write-failure | **PASS** | 18 | 0 | External FileShare::Read lock blocks Move-Item -Force |

Overall Phase 4 verdict: **PASS** (0 hard failures)

## T3-api-failure — key metrics (from T3-api-failure/validation.json + stdout.txt)

- stdout.txt total lines: 85
- `RUN_STATUS|success|` count: 1
- `RUN_STATUS|failed|` count: 0
- `COMMIT_OK|` count: 1
- `BACKUP_OK|` count: 1
- `FETCH_COMPLETE|` count: 1
- `REVIEW_WRITE_OK|` count: 1
- `RUNTIME_ERROR|` count: 0
- `PARSE_ERROR|` count: 0
- `LOCKED|` count: 0
- `VALIDATE_ERROR|` count: 0
- `PS_VERSION|` pollution lines: 0
- `RUN_STATUS_OBSERVED=` pollution lines: 0
- `T3_HARNESS_START` / `T3_HARNESS_END` markers: 0
- MD_CHANGED: True (metadata line + conclusion/summary/notes sections were rewritten even though data rows preserved)
- LOCK_AFTER_EXISTS: False
- TMP_EXISTS_AFTER: False
- Backup count under .monitor/backups/: 1

### Corrected verification items (F11 revised, 500/network_error main scenario)

| # | Item | Expected | Actual | Verdict |
|---|---|---|---|---|
| 1 | API 失败项 gitVer/gitDate/flag unchanged | all items' gitVer/gitDate/flag identical to fixture (v1.0.0 / 2026-01-15 / no) | both repos: gitVer=v1.0.0, gitDate=2026-01-15, flag=no | PASS |
| 2 | API 失败项 review=true | review==True for both repos | both True | PASS |
| 3 | result.json 中失败项 status != ok | status ∈ {server_error, network_error, ...} | both = "server_error" | PASS |
| 4 | 主 md 中失败项保持上轮值 | md-after rows identical to md-before rows | identical | PASS |

### 404 补充场景

- **NOT EXECUTED**. Per exec-plan F1/D8 and main agent task text, 500 is the sole main scenario. Rationale recorded in `mock-config.txt` (line `Rationale_500_over_404_F1_D8=...`).

### mock-config.txt (3 explicit decisions)

- `SCENARIO_MAIN_LATEST=server_500` — /releases/latest -> mock throws Exception with `Response.StatusCode=500` (via `PSCustomObject` NoteProperty)
- `SCENARIO_LIST_ENDPOINT=list-success` — /releases?per_page=5 -> returns 2-item deterministic list
- `SCENARIO_HTML_DIAGNOSTIC=200+fixed_html_with_title` — Invoke-WebRequest -> 200 + `<html><head><title>…</title></head>` fixed body

## T4-write-failure — key metrics (from T4-write-failure/validation.json + stdout.txt)

- stdout.txt total lines: 84
- `RUN_STATUS|failed|` count: **1**
- `RUN_STATUS|success|` count: 0
- `COMMIT_OK|` count: 0
- `BACKUP_OK|` count: 1
- `FETCH_COMPLETE|` count: 1
- `REVIEW_WRITE_OK|` count: 1
- `RUNTIME_ERROR|` count: 1 (Move-Item IOException caught by step5 L109 catch)
- `PARSE_ERROR|` count: 0
- `LOCKED|` count: 0
- `VALIDATE_ERROR|` count: 0
- Harness-side pollution markers (`PS_VERSION|` / `RUN_STATUS_OBSERVED=` / `T4_HARNESS_START` / `T4_HARNESS_END` / `LOCKHOLDER_OPENED_OK` / `STEP4_DONE_TS=` / `LOCK_STARTED_TS=` / `LOCKHOLDER_PID=`): **0**
- SHA256 before: `1E78021C874C19BD8AF7D3FE62ED8F9673DC57998711E9E29FA4AD8847B5B5F7`
- SHA256 after: `1E78021C874C19BD8AF7D3FE62ED8F9673DC57998711E9E29FA4AD8847B5B5F7` (equal → md unchanged)
- TMP_EXISTS_AFTER: False
- LOCK_AFTER_EXISTS: False
- Backup count under .monitor/backups/: 1
- LOCKHOLDER_STILL_RUNNING: False

### Orchestration order (verified)

1. Step 1-4 executed successfully in-process (BACKUP_OK + FETCH_COMPLETE + REVIEW_WRITE_OK all observed)
2. `STEP4_DONE_TS=2026-09-10T16:13:36.812Z`
3. `LOCK_STARTED_TS=2026-09-10T16:13:36.814Z` (≥ STEP4_DONE_TS, F3/D9 compliant)
4. `OPEN_MARKER_CONTENT=OPENED_OK pid=56456 target=...GitHub更新监测列表.md ts=...` (lock-holder confirmed 4-arg FileShare::Read acquisition, B1/D11 compliant)
5. Step 5 executed in-process while lock held; `Move-Item -Force` threw `IOException: 当文件已存在时，无法创建该文件。`
6. `RUNTIME_ERROR|主 md 原子替换失败：...` + `RUN_STATUS|failed|主 md 未提交。`
7. `Stop-Process` terminated lock-holder; `LOCKHOLDER_STILL_RUNNING=False`
8. `.monitor\run.lock` released by step5 ownership check (same-process PID match)

### Verification items (18 total, 18 PASS)

| # | Item | Expected | Actual | Verdict |
|---|---|---|---|---|
| 1 | md_unchanged | SHA256 before == after | both 1E78021C... | PASS |
| 2 | md_tmp_cleaned | False | False | PASS |
| 3 | backup_retained | ≥1 | 1 | PASS |
| 4 | RUN_STATUS_failed_count | 1 | 1 | PASS |
| 5 | RUN_STATUS_success_count | 0 | 0 | PASS |
| 6 | COMMIT_OK_count | 0 | 0 | PASS |
| 7 | lock_released_after_run | False | False | PASS |
| 8 | lockholder_process_stopped | False | False | PASS |
| 9 | lockholder_OPENED_OK_marker_written | OPENED_OK present | OPENED_OK pid=56456 target=... | PASS |
| 10 | step1_backup_ok_observed | ≥1 | 1 | PASS |
| 11 | step2_fetch_complete_observed | ≥1 | 1 | PASS |
| 12 | step4_review_write_ok_observed | ≥1 | 1 | PASS |
| 13 | RUNTIME_ERROR_present_in_stdout | ≥1 | 1 | PASS |
| 14 | PARSE_ERROR_count | 0 | 0 | PASS |
| 15 | LOCKED_count | 0 | 0 | PASS |
| 16 | stdout_no_PS_VERSION_line | 0 | 0 | PASS |
| 17 | stdout_no_RUN_STATUS_OBSERVED_line | 0 | 0 | PASS |
| 18 | stdout_no_harness_markers | 0 | 0 | PASS |

## Harness-side stdout integrity check (Phase 3 lesson applied)

Independent grep against RAW stdout.txt:
- `T3-api-failure/stdout.txt`: `PS_VERSION|` = 0, `RUN_STATUS_OBSERVED=` = 0, `T3_HARNESS_START` = 0, `T3_HARNESS_END` = 0
- `T4-write-failure/stdout.txt`: `PS_VERSION|` = 0, `RUN_STATUS_OBSERVED=` = 0, `T4_HARNESS_START` = 0, `T4_HARNESS_END` = 0, `LOCKHOLDER_OPENED_OK` = 0, `STEP4_DONE_TS=` = 0, `LOCK_STARTED_TS=` = 0, `LOCKHOLDER_PID=` = 0

## Harness fix during Phase 4

- **记录 P4-E** (mock StatusCode property silently null → network_error instead of server_error): logged in `harness-fix-log.md`. Modified `lib/mock-invoke-restmethod.ps1` (Phase 2 mock utility). Fix: replaced `New-Object System.Net.WebResponse` + setter with PSCustomObject + NoteProperty StatusCode/Headers. SKILL + step scripts NOT modified. T3 attempt 1 evidence preserved in `T3-api-failure-attempt1/`.

## SKILL integrity (收尾 SHA256 确认)

- `SKILL-v1.12.md` SHA256 = `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9` (matches task text) — **unmodified**
- `lib/step1.ps1` / `lib/step2.ps1` / `lib/step3.ps1` / `lib/step4.ps1` / `lib/step5-full.ps1` — **unmodified** (byte-exact, Phase 2 extracted)

## Evidence index

- `.production-validation-v112-final/T3-api-failure/` — full evidence
- `.production-validation-v112-final/T3-api-failure-attempt1/` — pre-fix attempt 1 preserved
- `.production-validation-v112-final/T4-write-failure/` — full evidence
- `.production-validation-v112-final/harness-fix-log.md` — Phase 4 records appended
- `.production-validation-v112-final/phase-progress.json` — updated to Phase 4 completed
- `.production-validation-v112-final/phase4-report.md` — this document
- `.production-validation-v112-final/phase4-stdout.txt` — concatenated T3+T4 raw stdout
- `.production-validation-v112-final/phase4-stderr.txt` — concatenated T3+T4 raw stderr
