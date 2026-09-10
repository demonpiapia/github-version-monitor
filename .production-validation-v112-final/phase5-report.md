# Phase 5 Report - Test 5 housekeeping failure (v1.12 P2 hard gate)

**Phase**: Phase 5 of SKILL-v1.12 production validation
**Exec Plan**: `.exec-plan/exec-plan-v1.12-d.md` §Phase 5 (L856-951)
**Prompt**: `.GPT/v1.12 最小修改与定向验证 Prompt.md` §8 Test 5
**Runner**: `.production-validation-v112-final/lib/p5-run-T5.ps1`
**Harness**: `.production-validation-v112-final/lib/t5-housekeeping-harness.ps1` (Phase 2, EAP=Stop L8 confirmed)
**Test dir**: `.production-validation-v112-final/T5-housekeeping/`
**Start (UTC)**: 2026-09-10T16:33:57.885Z
**End   (UTC)**: 2026-09-10T16:34:06.664Z
**Wall time**: ~8.78 s

---

## 0. Verdict

**PASS** — 18/18 verification items passed; 0 failed.

The v1.12 P2-a housekeeping try/catch (`SKILL-v1.12.md` L458-466) was proven to:
1. Catch the `ItemNotFoundException` raised by `Get-ChildItem` on the missing `backups` directory,
2. Emit `HOUSEKEEPING_WARNING|...` **without** terminating Step 3,
3. Allow the core pipeline (Step 4 review + Step 5 commit + lock release) to complete,
4. Produce exactly one `RUN_STATUS|success|` and zero `RUN_STATUS|failed|`.

**This is the P1 hard gate for v1.12**: housekeeping failure no longer blocks the core version monitor.

---

## 1. Injection scheme

**Scheme B** (recommended in exec-plan D2, L883): delete `.monitor\backups` between Step 2 and Step 3.

- Rationale: `Get-ChildItem` on a nonexistent path raises a terminating exception under `$ErrorActionPreference='Stop'` (which the runner and all steps set). The P2-a try/catch catches it. No ACL restore required (unlike Scheme C), and Windows directory `ReadOnly` flag does NOT block `Move-Item` (Scheme A is infeasible per exec-plan L877).
- EAP=Stop prerequisite (F2/D7): confirmed at runner L8 and step1..step5 all set EAP=Stop. Without EAP=Stop, `Get-ChildItem` would emit a non-terminating error that would NOT enter the P2-a try/catch, producing a false FAIL.

### Scheme B construction record (from `t5-construction-log.txt`)

| Field | Value |
|---|---|
| pre-backups-dir-existed | `True` |
| pre-backups-content-count | `1` |
| pre-backups-files | `GitHub更新监测列表.backup.20260911-003357998.md` |
| pre-backup-snapshot-ts (UTC) | `2026-09-10T16:33:58.005Z` |
| delete-begin-ts (UTC) | `2026-09-10T16:33:59.749Z` |
| delete-end-ts (UTC) | `2026-09-10T16:33:59.756Z` |
| delete-result | `True` |
| delete-exception-type | *(empty — clean delete)* |
| backups-absent-before-step3 | `True` |
| step3-begin-ts (UTC) | `2026-09-10T16:33:59.781Z` |
| step3-end-ts (UTC) | `2026-09-10T16:33:59.801Z` |
| step3-terminated-by-harness-exception | `False` |
| step3-exception-type | *(empty — Step 3 completed normally)* |
| backups-dir-exists-after-run | `False` |

**Timing sequence**: Step 2 END (16:33:59.748Z) → DELETE BEGIN (16:33:59.749Z) → DELETE END (16:33:59.756Z) → STEP3 BEGIN (16:33:59.781Z) → STEP3 END (16:33:59.801Z). The delete precedes Step 3 execution by 25 ms.

**Exception class caught by P2-a try/catch**: `System.IO.IOException` with message `Cannot find path '...T5-housekeeping\.monitor\backups' because it does not exist.` (semantically `ItemNotFoundException` / `PathNotFound`). This matches the v1.12 housekeeping design.

---

## 2. stdout.txt key-marker independent counts (grep against RAW stdout)

Command used for independent verification (separate PowerShell session, not the runner):

```powershell
$lines = Get-Content 'T5-housekeeping\stdout.txt' -Encoding UTF8
@($lines | ?{$_ -match '^HOUSEKEEPING_WARNING\|'}).Count
# ... etc.
```

| # | Marker | Count | Expected | Verdict |
|---|---|---|---|---|
| 1 | `RUN_STATUS_SUCCESS` (`^RUN_STATUS\|success\|`) | **1** | 1 | PASS |
| 2 | `RUN_STATUS_FAILED`  (`^RUN_STATUS\|failed\|`)  | **0** | 0 | PASS |
| 3 | `COMMIT_OK`          (`^COMMIT_OK\|`)            | **1** | 1 | PASS |
| 4 | `BACKUP_OK`          (`^BACKUP_OK\|`)            | **1** | 1 | PASS |
| 5 | `FETCH_COMPLETE`     (`^FETCH_COMPLETE\|`)       | **1** | 1 | PASS |
| 6 | `REVIEW_WRITE_OK`    (`^REVIEW_WRITE_OK\|`)      | **1** | >=0 (triggered) | PASS |
| 7 | `HOUSEKEEPING_WARNING` (`^HOUSEKEEPING_WARNING\|`) | **1** | 1 | PASS |
| 8 | `RUNTIME_ERROR`      (`^RUNTIME_ERROR\|`)        | **0** | 0 | PASS |
| 9 | `PARSE_ERROR`        (`^PARSE_ERROR\|`)          | **0** | 0 | PASS |
| 10 | `LOCKED` (`^LOCKED\|`)                           | **0** | 0 | PASS |
| 11 | `PS_VERSION_LINE` (`^PS_VERSION\|`)               | **0** | 0 | PASS |
| 12 | `RUN_STATUS_OBSERVED` (`^RUN_STATUS_OBSERVED=`)  | **0** | 0 | PASS |

RAW stdout total lines: **83**.

---

## 3. HOUSEKEEPING_WARNING| full raw line (P2-a effect evidence)

```
HOUSEKEEPING_WARNING|backup/trash cleanup failed: Cannot find path 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\T5-housekeeping\.monitor\backups' because it does not exist.
```

Located at `T5-housekeeping/stdout.txt` line 74, between `--- step3 BEGIN (housekeeping failure expected) ---` and `--- step3 END ---`.

This exact line format is defined at `SKILL-v1.12.md` L466 inside the P2-a catch block:

```powershell
} catch {
    Write-Output ("HOUSEKEEPING_WARNING|backup/trash cleanup failed: {0}" -f $_.Exception.Message)
}
```

The line is the **direct and unambiguous evidence** that:
1. Step 3's housekeeping block ran,
2. An exception was raised by `Get-ChildItem $backupDir`,
3. The P2-a try/catch (L459-467) caught it,
4. `Write-Output` emitted the warning,
5. Step 3 continued to return normally (no `return` on the catch path).

---

## 4. md sha256 diff

| Field | Value |
|---|---|
| SHA256 BEFORE | `457D852E5AE1DD001B5016D3D271F639472A2C28E7C254F13F9838ED19E0E74F` |
| SHA256 AFTER  | `3458F02697A8AEE698BA2E6493EB3FE368976E9F05E8DBA7625403DD224739CB` |
| md_changed    | `True` |
| Before line count | 28 |
| After  line count | 28 |
| Diff line count (Compare-Object) | 12 |

Confirmed: housekeeping failure did not prevent Step 5 from atomically committing the updated markdown.

---

## 5. lock state

| Snapshot | Value |
|---|---|
| lock-before | `LOCK_EXISTS=False` |
| lock-after  | `LOCK_EXISTS=False` |

Lock was properly acquired by Step 1 (in-process, PID 48164, same as runner) and released by Step 5's cleanup path. No stale lock remained.

---

## 6. heartbeat integrity (Phase 1 diff-integrity.md citation)

The heartbeat code (SKILL L447-455, previously L437-444 in v1.11) was NOT touched by P2-a. Phase 1 diff-integrity evidence:

- `diff-integrity.md` L34-35, hunk 4: `@@ -444,11 +455,16 @@` — v1.11 L444-454 → v1.12 L455-470. The hunk header indicates the wrap starts at post-shift L455 (which is where `$backupDir = ...` sits, not heartbeat).
- `diff-integrity.md` L98 (P3 review table): for the v1.11 L444→v1.12 L455 heartbeat line — decision recorded as `**不修改**（heartbeat 代码未被 P2 触碰，diff hunk 4 从 $backupDir L456 开始）`.
- This T5 run observed `LOCKED|` count = 0 and `RUNTIME_ERROR|` count = 0, confirming the heartbeat code path did not fire any fatal path (as expected — heartbeat was healthy).
- Note: dynamic validation of "heartbeat failure still terminates the round" would require a separate lock-poison test; not attempted in Phase 5. Static evidence via Phase 1 diff-integrity + absence of heartbeat failures in this run is sufficient per exec-plan L920.

---

## 7. SKILL and step scripts integrity

| File | SHA256 (post-Phase 5) | Baseline | Match |
|---|---|---|---|
| `SKILL-v1.12.md` | `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9` | `3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9` | ✅ |
| `lib/step1.ps1` | `F8CE7D677527D54565063B6591AD2A7E6D43D908CFB0EEBD3347A841E5C2CCA0` | `F8CE7D677527D54565063B6591AD2A7E6D43D908CFB0EEBD3347A841E5C2CCA0` | ✅ |
| `lib/step2.ps1` | `D623FF739BA910CB11AFA9E8454CA437B5EFB912DDD5BC7792DD746010BE6D05` | `D623FF739BA910CB11AFA9E8454CA437B5EFB912DDD5BC7792DD746010BE6D05` | ✅ |
| `lib/step3.ps1` | `5A6D523726E46303B4A2E4181A4832868B58CDD7A061B2B8D6E529FC5F955169` | `5A6D523726E46303B4A2E4181A4832868B58CDD7A061B2B8D6E529FC5F955169` | ✅ |
| `lib/step4.ps1` | `57CE64F8FC73E50C2B068BF9510F1DB2FED2DC64324036810713C54A3FA79A62` | `57CE64F8FC73E50C2B068BF9510F1DB2FED2DC64324036810713C54A3FA79A62` | ✅ |
| `lib/step5-full.ps1` | `41C8DD7285A103D66119241A5D20324E73FBE21E42BA431FD18DF5F12E3F59C9` | `41C8DD7285A103D66119241A5D20324E73FBE21E42BA431FD18DF5F12E3F59C9` | ✅ |

SKILL and all step scripts are byte-identical to Phase 2 baseline. The runner did NOT modify any SKILL or step script.

---

## 8. Expected-behavior chain confirmation

```
Step 1 completes: BACKUP_OK|20260911-003357998        ✅ (stdout.txt L7)
Step 2 completes: FETCH_COMPLETE|apiOk=2 apiErr=0 ...   ✅ (stdout.txt L10)
                    SUMMARY|total=2 apiOK=2 ...          ✅ (stdout.txt L11)
                    result.json written (2 items)        ✅ (stdout.txt L12-71)
[injection]        Remove-Item .monitor\backups          ✅ (delete_result=True)
                    backups-absent-before-step3=True     ✅
Step 3 begins (housekeeping failure expected)            ✅ (stdout.txt L73)
Step 3 emits HOUSEKEEPING_WARNING|backup/trash ...      ✅ (stdout.txt L74, P2-a effect)
Step 3 does NOT return early                             ✅ (STEP3_TERMINATED_BY_EXCEPTION=False)
Step 3 ends                                              ✅ (stdout.txt L75)
Step 4 completes: REVIEW_WRITE_OK|复核完成：2 项 ...     ✅ (stdout.txt L77)
Step 5 completes: COMMIT_OK|已原子替换主 md ...          ✅ (stdout.txt L80)
                    RUN_STATUS|success| ...              ✅ (stdout.txt L81, count=1)
Pipeline ends                                            ✅ (stdout.txt L83)
lock-after : LOCK_EXISTS=False                          ✅
md_changed  : True                                      ✅ (sha256 diff)
```

All 12 key markers + 6 side conditions verified. Full 18-check list in `T5-housekeeping/validation.json`.

---

## 9. Evidence files

Under `.production-validation-v112-final/T5-housekeeping/`:

- `stdout.txt` (83 lines, raw pipeline output only — no harness annotations)
- `stderr.txt` (0 lines — pipeline produced no stderr)
- `harness-aux.txt` (41 lines — all harness-side metadata; NOT part of SKILL stdout)
- `t5-construction-log.txt` (18 lines — Scheme B delete detail)
- `fixture-stdout.txt` (fixture generator output)
- `md-before.md` / `md-after.md`
- `result-before.json` / `result-after.json`
- `sha256-before.txt` / `sha256-after.txt`
- `lock-before.txt` / `lock-after.txt`
- `before/` and `after/` (snapshot dirs)
- `validation.json` (18 checks, all PASS)
- `test-report.md` (per-test report)

Under `.production-validation-v112-final/`:

- `phase5-stdout.txt` (copy of T5 stdout.txt)
- `phase5-stderr.txt` (copy of T5 stderr.txt)
- `phase5-run-runner-stdout.txt` (harness console output: `PHASE5_T5_DONE=T5-housekeeping OVERALL=PASS PASS=18 FAIL=0`)
- `phase5-run-runner-stderr.txt` (empty — no runner-level errors)
- `phase5-report.md` (this file)
- `phase-progress.json` (updated with Phase5 entry)
- `lib/p5-run-T5.ps1` (newly created runner; not a modification of SKILL or stepX)

---

## 10. Harness integrity

- `stdout.txt` is written ONCE via `[System.IO.File]::WriteAllLines` after all steps complete; no `Add-Content` to stdout.txt at any point in `p5-run-T5.ps1`.
- All harness-side evidence (timestamps, PID, delete operation log, snapshots, counts) is written to `harness-aux.txt` and `t5-construction-log.txt`.
- PS_VERSION and RUN_STATUS_OBSERVED pollution counts are both 0 in stdout.txt — evidence-isolation pattern preserved from Phase 3 fix.
- Pipeline ran IN-PROCESS (single pwsh.exe session) so the heartbeat PID chain in `run.lock` was consistent across Step 1-5. No external pwsh spawn needed for the injection (the delete happens between steps within the same process).

---

## 11. Failure handling note

Exec-plan L951 says: `T5 FAIL → PRODUCTION_NOT_READY (housekeeping 仍阻断核心业务 = P2 修改无效 = P1 硬门槛违反)`. This T5 PASSED, so the P1 hard gate is cleared. Phase 6 (Test 6 final status semantics) may proceed.

---

## 12. Runner fixes during Phase 5

Two bugs were found and fixed in the runner during execution (both were harness-only, SKILL untouched):

1. **BUG A** (attempt 1): used `Set-Content -Append` which doesn't exist; fixed to `[System.IO.File]::WriteAllLines`.
2. **BUG B** (attempt 2): used `& $add '...' (if ($x -eq 1) { 'PASS' } else { 'FAIL' })` inside a script-block call, which caused `(if ...)` to be parsed as `cmdlet if` at argument-position. Fixed by pre-computing each verdict into a scalar variable before `Add-Check`.

Both are harness-code issues; no SKILL or stepX.ps1 change was made. No record added to `harness-fix-log.md` because no prior harness script was modified; the new `p5-run-T5.ps1` is a fresh file.
