# T36 — Process kill

**Focus:** Kill the SKILL pipeline mid-run, verify lock/backup/main-md state, then re-run.

## Scenario
1. Start a `pwsh` process running `common/step1-and-hold.ps1` (creates lock + backup, then sleeps 60s to simulate Step 2 work).
2. Poll for lock creation (up to 5s).
3. `Stop-Process -Force` the process.
4. Verify: lock exists, backup exists, main md unchanged.
5. Re-run `common/step1.ps1` with the fresh (killed) lock → expect `LOCKED` (heartbeat < 30 min, so no takeover even though PID is dead).
6. Manually set lock `LastWriteTime` to 31 min ago.
7. Re-run `common/step1.ps1` again → expect `BACKUP_OK` (stale + dead → takeover).

## Expected
- After kill: lock exists, backup exists, main md unchanged.
- Fresh re-run: `LOCKED`, no takeover, lock still has dead PID.
- Stale re-run: `BACKUP_OK`, lock has new PID (takeover).

## Result: PASS

## Evidence
- Killed process PID: 29272
- Lock exists after kill: True
- Backup exists after kill: True
- Main md unchanged: True
- Re-run with fresh heartbeat got LOCKED: True
- No takeover with fresh heartbeat: True
- Lock still has dead PID after fresh re-run: True
- Re-run after stale got BACKUP_OK: `BACKUP_OK|20260907-160454729`
- Lock has new PID after stale re-run (takeover): True
- Hold output:
  - `BACKUP_OK|20260907-160452507`
  - `PID=29272`
  - `STEP1_DONE|Lock created, now holding (sleeping to simulate Step 2 work)...`

## Files
- `stdout.txt` — re-run outputs + evidence block
- `hold_out.txt` — captured stdout of the killed hold process
- `hold_err.txt` — captured stderr of the killed hold process (empty)
