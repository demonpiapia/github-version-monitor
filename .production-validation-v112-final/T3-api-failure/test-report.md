# Test 3 - API failure validation report (500 / server_error main scenario)

Test ID: **T3-api-failure**
Test dir: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T3-api-failure`
Main scenario: **server_500** (mock /releases/latest throws StatusCode=500)
Supplementary 404 scenario: **NOT EXECUTED** (per exec-plan F1/D8, 500 is the sole main scenario)
Executor: `lib/p4-run-T3.ps1`
Fixture repos: microsoft/vscode, PowerShell/PowerShell

## Verdict: **PASS** (35 PASS / 0 FAIL)

## stdout.txt key-marker independent counts (grep against RAW stdout)

| Marker | Count |
|---|---|
| `RUN_STATUS_SUCCESS` | 1 |
| `RUN_STATUS_FAILED` | 0 |
| `COMMIT_OK` | 1 |
| `BACKUP_OK` | 1 |
| `FETCH_COMPLETE` | 1 |
| `REVIEW_WRITE_OK` | 1 |
| `RUNTIME_ERROR` | 0 |
| `PARSE_ERROR` | 0 |
| `LOCKED` | 0 |
| `VALIDATE_ERROR` | 0 |
| `PS_VERSION_LINE` | 0 |
| `RUN_STATUS_OBSERVED` | 0 |
| `HARNESS_START_MARKER` | 0 |
| `HARNESS_END_MARKER` | 0 |
| RAW stdout total lines | 84 |

## Corrected verification items (500 / network_error main scenario, 4 items)

| # | Item | Expected | Actual | Verdict |
|---|---|---|---|---|
| 1 | `api_item_status[microsoft/vscode]` | `server_error` | `server_error` | PASS |
| 2 | `api_item_status[PowerShell/PowerShell]` | `server_error` | `server_error` | PASS |
| 3 | `api_item_gitVer_unchanged[microsoft/vscode]` | `v1.0.0` | `v1.0.0` | PASS |
| 4 | `api_item_gitDate_unchanged[microsoft/vscode]` | `2026-01-15` | `2026-01-15` | PASS |
| 5 | `api_item_flag_unchanged[microsoft/vscode]` | `no` | `no` | PASS |
| 6 | `api_item_gitVer_unchanged[PowerShell/PowerShell]` | `v1.0.0` | `v1.0.0` | PASS |
| 7 | `api_item_gitDate_unchanged[PowerShell/PowerShell]` | `2026-01-15` | `2026-01-15` | PASS |
| 8 | `api_item_flag_unchanged[PowerShell/PowerShell]` | `no` | `no` | PASS |
| 9 | `api_item_review_true[microsoft/vscode]` | `True` | `True` | PASS |
| 10 | `api_item_review_true[PowerShell/PowerShell]` | `True` | `True` | PASS |
| 11 | `api_item_reason_api_failure[microsoft/vscode]` | `api_failure in reviewReasons` | `api_failure` | PASS |
| 12 | `api_item_reason_api_failure[PowerShell/PowerShell]` | `api_failure in reviewReasons` | `api_failure` | PASS |
| 13 | `md_after_gitVer_unchanged[PowerShell/PowerShell]` | `v1.0.0` | `v1.0.0` | PASS |
| 14 | `md_after_gitDate_unchanged[PowerShell/PowerShell]` | `2026-01-15` | `2026-01-15` | PASS |
| 15 | `md_after_flag_unchanged[PowerShell/PowerShell]` | `no` | `no` | PASS |
| 16 | `md_after_gitVer_unchanged[microsoft/vscode]` | `v1.0.0` | `v1.0.0` | PASS |
| 17 | `md_after_gitDate_unchanged[microsoft/vscode]` | `2026-01-15` | `2026-01-15` | PASS |
| 18 | `md_after_flag_unchanged[microsoft/vscode]` | `no` | `no` | PASS |
| 19 | `stats.apiOk` | `0` | `0` | PASS |
| 20 | `stats.apiErr` | `2` | `2` | PASS |
| 21 | `stats.pendingReview` | `2` | `2` | PASS |
| 22 | `RUN_STATUS_success_count` | `>=1` | `1` | PASS |
| 23 | `RUN_STATUS_failed_count` | `0` | `0` | PASS |
| 24 | `COMMIT_OK_count` | `>=1` | `1` | PASS |
| 25 | `BACKUP_OK_count` | `>=1` | `1` | PASS |
| 26 | `FETCH_COMPLETE_count` | `>=1` | `1` | PASS |
| 27 | `REVIEW_WRITE_OK_count` | `>=1` | `1` | PASS |
| 28 | `RUNTIME_ERROR_count` | `0` | `0` | PASS |
| 29 | `PARSE_ERROR_count` | `0` | `0` | PASS |
| 30 | `stdout_no_PS_VERSION_line` | `0` | `0` | PASS |
| 31 | `stdout_no_RUN_STATUS_OBSERVED_line` | `0` | `0` | PASS |
| 32 | `stdout_no_harness_start_end_marker` | `0` | `0` | PASS |
| 33 | `lock_released_after_run` | `False` | `False` | PASS |
| 34 | `md_tmp_cleaned` | `False` | `False` | PASS |
| 35 | `backup_exists_under_monitor_backups` | `>=1` | `1` | PASS |

## Mock decisions (mock-config.txt summary)

- MOCK_SCENARIO = server_500 (latest endpoint -> 500 exception)
- MOCK_SCENARIO_LIST = list-success (list endpoint -> 2-item deterministic list)
- HTML diagnostic = 200 + html-with-title-body

## Evidence index

| File | Content |
|---|---|
| stdout.txt | RAW pipeline stdout (no harness pollution) |
| stderr.txt | RAW pipeline stderr |
| harness-aux.txt | All harness-side evidence |
| mock-config.txt | 3-item mock decision declaration |
| run-status-sidecar.txt | Harness-derived RUN_STATUS observation |
| md-before.md / md-after.md | Main md snapshots |
| result-before.json / result-after.json | result.json snapshots |
| sha256-before.txt / sha256-after.txt | Main md SHA256 |
| lock-before.txt / lock-after.txt | Lock existence |
| before/ / after/ | Full state directory snapshots |
| validation.json | Structured verification metrics |
| fixture-stdout.txt | Fixture generation log |

## SKILL integrity
- SKILL-v1.12.md / lib/stepX.ps1 read-only throughout; harness did NOT modify the SKILL or step scripts.

