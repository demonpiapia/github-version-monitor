# Test 4 - core write failure validation report

Test ID: **T4-write-failure**
Test dir: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T4-write-failure`
Injection: external lock-holder with FileShare::Read blocks Move-Item -Force
Executor: `lib/p4-run-T4.ps1`
Fixture repos: microsoft/vscode, PowerShell/PowerShell

## Verdict: **PASS** (18 PASS / 0 FAIL)

## stdout.txt key-marker independent counts (grep against RAW stdout)

| Marker | Count |
|---|---|
| `RUN_STATUS_SUCCESS` | 0 |
| `RUN_STATUS_FAILED` | 1 |
| `COMMIT_OK` | 0 |
| `BACKUP_OK` | 1 |
| `FETCH_COMPLETE` | 1 |
| `REVIEW_WRITE_OK` | 1 |
| `RUNTIME_ERROR` | 1 |
| `PARSE_ERROR` | 0 |
| `LOCKED` | 0 |
| `VALIDATE_ERROR` | 0 |
| `PS_VERSION_LINE` | 0 |
| `RUN_STATUS_OBSERVED` | 0 |
| `HARNESS_START_MARKER` | 0 |
| `HARNESS_END_MARKER` | 0 |
| `LOCKHOLDER_OPENED_OK_LINE` | 0 |
| `STEP4_DONE_TS_LINE` | 0 |
| `LOCK_STARTED_TS_LINE` | 0 |
| `LOCKHOLDER_PID_LINE` | 0 |
| RAW stdout total lines | 83 |

## Verification items

| # | Item | Expected | Actual | Verdict |
|---|---|---|---|---|
| 1 | `md_unchanged` | `SHA256 before == SHA256 after` | `before=1E78021C874C19BD8AF7D3FE62ED8F9673DC57998711E9E29FA4AD8847B5B5F7 / after=1E78021C874C19BD8AF7D3FE62ED8F9673DC57998711E9E29FA4AD8847B5B5F7 / equal=True` | PASS |
| 2 | `md_tmp_cleaned` | `False` | `False` | PASS |
| 3 | `backup_retained` | `>=1` | `1` | PASS |
| 4 | `RUN_STATUS_failed_count` | `1` | `1` | PASS |
| 5 | `RUN_STATUS_success_count` | `0` | `0` | PASS |
| 6 | `COMMIT_OK_count` | `0` | `0` | PASS |
| 7 | `lock_released_after_run` | `False` | `False` | PASS |
| 8 | `lockholder_process_stopped` | `False` | `False` | PASS |
| 9 | `lockholder_OPENED_OK_marker_written` | `OPENED_OK present` | `OPENED_OK pid=56456 target=D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T4-write-failure\.output\GitHub更新监测列表.md ts=2026-09-10T16:13:37.2247990+00:00` | PASS |
| 10 | `step1_backup_ok_observed` | `>=1` | `1` | PASS |
| 11 | `step2_fetch_complete_observed` | `>=1` | `1` | PASS |
| 12 | `step4_review_write_ok_observed` | `>=1` | `1` | PASS |
| 13 | `RUNTIME_ERROR_present_in_stdout` | `>=1` | `1` | PASS |
| 14 | `PARSE_ERROR_count` | `0` | `0` | PASS |
| 15 | `LOCKED_count` | `0` | `0` | PASS |
| 16 | `stdout_no_PS_VERSION_line` | `0` | `0` | PASS |
| 17 | `stdout_no_RUN_STATUS_OBSERVED_line` | `0` | `0` | PASS |
| 18 | `stdout_no_harness_markers` | `0` | `0` | PASS |

## Lock-holder evidence

- LOCKHOLDER_PID: `56456`
- LOCK_STARTED_TS: `2026-09-10T16:13:36.814Z`
- STEP4_DONE_TS: `2026-09-10T16:13:36.812Z` (must precede LOCK_STARTED_TS)
- open-marker.txt content: `OPENED_OK pid=56456 target=D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T4-write-failure\.output\GitHub更新监测列表.md ts=2026-09-10T16:13:37.2247990+00:00`
- lock-holder-stdout.txt: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T4-write-failure\lock-holder-stdout.txt`
- lock-holder-stderr.txt: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T4-write-failure\lock-holder-stderr.txt`
- lock-holder-pid.txt: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T4-write-failure\lock-holder-pid.txt`
- lock-holder-start-timestamp.txt: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T4-write-failure\lock-holder-start-timestamp.txt`

## SKILL integrity
- SKILL-v1.12.md / lib/stepX.ps1 read-only throughout; harness did NOT modify the SKILL or step scripts.

