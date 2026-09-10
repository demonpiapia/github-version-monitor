# Test 5 - housekeeping failure validation report (Phase 5)

Test ID: **T5-housekeeping**
Test dir: `D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T5-housekeeping`
Injection: **Scheme B** - delete `.monitor\backups` between Step 2 and Step 3
Executor: `lib/p5-run-T5.ps1`
Fixture repos: microsoft/vscode, PowerShell/PowerShell

## Verdict: **PASS** (18 PASS / 0 FAIL)

## Scheme B construction detail (from t5-construction-log.txt)

| Field | Value |
|---|---|
| pre-backups-dir-existed | `True` |
| pre-backups-content-count | `1` |
| pre-backups-files | `GitHub更新监测列表.backup.20260911-003357998.md` |
| delete-begin-ts (UTC) | `2026-09-10T16:33:59.749Z` |
| delete-end-ts (UTC) | `2026-09-10T16:33:59.756Z` |
| delete-result | `True` |
| delete-exception-type | `` |
| delete-exception-msg | `` |
| backups-absent-before-step3 | `True` |
| step3-begin-ts (UTC) | `2026-09-10T16:33:59.781Z` |
| step3-end-ts (UTC) | `2026-09-10T16:33:59.801Z` |
| step3-terminated-by-harness-exception | `False` |
| step3-exception-type | `` |
| backups-dir-exists-after-run | `False` |

## stdout.txt key-marker independent counts (grep against RAW stdout)

| Marker | Count | Expected |
|---|---|---|
| `RUN_STATUS_SUCCESS` | 1 | 1 |
| `RUN_STATUS_FAILED` | 0 | 0 |
| `COMMIT_OK` | 1 | 1 |
| `BACKUP_OK` | 1 | 1 |
| `FETCH_COMPLETE` | 1 | 1 |
| `REVIEW_WRITE_OK` | 1 | >=0 (if review triggered) |
| `HOUSEKEEPING_WARNING` | 1 | 1 |
| `RUNTIME_ERROR` | 0 | 0 |
| `PARSE_ERROR` | 0 | 0 |
| `LOCKED` | 0 | 0 |
| `PS_VERSION_LINE` | 0 | 0 |
| `RUN_STATUS_OBSERVED` | 0 | 0 |
| RAW stdout total lines | 83 | n/a |

### HOUSEKEEPING_WARNING| raw line (P2-a effect evidence)

```
HOUSEKEEPING_WARNING|backup/trash cleanup failed: Cannot find path 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T5-housekeeping\.monitor\backups' because it does not exist.
```

## Verification items

| # | Item | Expected | Actual | Verdict |
|---|---|---|---|---|
| 1 | `HOUSEKEEPING_WARNING_count` | `1` | `1` | PASS |
| 2 | `RUN_STATUS_success_count` | `1` | `1` | PASS |
| 3 | `RUN_STATUS_failed_count` | `0` | `0` | PASS |
| 4 | `COMMIT_OK_count` | `1` | `1` | PASS |
| 5 | `BACKUP_OK_count` | `1` | `1` | PASS |
| 6 | `FETCH_COMPLETE_count` | `1` | `1` | PASS |
| 7 | `REVIEW_WRITE_OK_count_or_zero (triggered)` | `>=0` | `1` | PASS |
| 8 | `RUNTIME_ERROR_count` | `0` | `0` | PASS |
| 9 | `PARSE_ERROR_count` | `0` | `0` | PASS |
| 10 | `LOCKED_count` | `0` | `0` | PASS |
| 11 | `stdout_no_PS_VERSION_line` | `0` | `0` | PASS |
| 12 | `stdout_no_RUN_STATUS_OBSERVED_line` | `0` | `0` | PASS |
| 13 | `md_updated` | `True` | `True` | PASS |
| 14 | `lock_released_after_run` | `False` | `False` | PASS |
| 15 | `step3_not_terminated_by_harness_exception` | `False` | `False` | PASS |
| 16 | `scheme_b_delete_result` | `True` | `True` | PASS |
| 17 | `backups_absent_before_step3` | `True` | `True` | PASS |
| 18 | `pre_backup_dir_existed_with_content` | `True` | `True (files=1)` | PASS |

## md sha256 diff

- SHA256 BEFORE: `457D852E5AE1DD001B5016D3D271F639472A2C28E7C254F13F9838ED19E0E74F`
- SHA256 AFTER : `3458F02697A8AEE698BA2E6493EB3FE368976E9F05E8DBA7625403DD224739CB`
- md_changed  : `True`

## lock state

- lock-before: `LOCK_EXISTS=False`
- lock-after : `LOCK_EXISTS=False`

## heartbeat integrity (Phase 1 diff-integrity.md citation)

- Step 3 heartbeat code lives at `SKILL-v1.12.md` L447-455 (post-shift line numbers).
- Phase 1 diff-integrity.md hunk 4 (`@@ -444,11 +455,16 @@`) starts wrapping at `$backupDir` L456+; heartbeat region is NOT modified by P2-a.
- Phase 1 review explicitly cites L444→L455 heartbeat as "**不修改**（heartbeat 代码未被 P2 触碰，diff hunk 4 从 `$backupDir` L456 开始）".**
- This T5 run did not observe any `LOCKED|` or `RUNTIME_ERROR|` from heartbeat; heartbeat remained effective.

## SKILL integrity

- SKILL-v1.12.md and lib/step1..step5-full.ps1 were NOT modified by this runner.
- P2-a modification at SKILL L458-466 (try/catch + HOUSEKEEPING_WARNING) is what caused the pass.

