# T34 — Stale + dead

**Focus:** Heartbeat > 30 minutes, PID dead → takeover allowed.

## Scenario
1. Pre-create `.monitor/run.lock` with `pid=999999` (non-existent / dead).
2. Set the lock file's `LastWriteTime` to 31 minutes ago.
3. Run `common/step1.ps1` in a child pwsh process.
4. Child's `CreateNew` fails → it reads the lock, sees age > 30 min AND PID dead → `Remove-Item` + retry `New-LockOnce` → takeover.

## Expected
- Output contains `BACKUP_OK|`.
- No `LOCKED`.
- Lock file now contains the child process's PID (not 999999).

## Result: PASS

## Evidence
- Pre-created lock with dead PID=999999, LastWriteTime=31 min ago.
- PID 999999 is dead: YES.
- Step 1 output: `BACKUP_OK|20260907-160451077` + `PID=28468`.
- Got BACKUP_OK (takeover): True
- Not LOCKED: True
- Lock has new PID (takeover happened): True
- Lock content after: `pid=28468;start=2026-09-07T08:04:51.0656164+00:00;step=1;beat=2026-09-07T08:04:51.0656164+00:00`

## Files
- `stdout.txt` — Step 1 output + evidence block
