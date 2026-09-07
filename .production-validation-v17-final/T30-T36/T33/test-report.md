# T33 — Stale + alive

**Focus:** Heartbeat > 30 minutes, PID alive → LOCKED (no takeover).

## Scenario
1. Pre-create `.monitor/run.lock` with `pid=<current PID>` (alive).
2. Set the lock file's `LastWriteTime` to 31 minutes ago via `(Get-Item $lockPath).LastWriteTime = (Get-Date).AddMinutes(-31)`.
3. Run `common/step1.ps1` in a child pwsh process.
4. Child's `CreateNew` fails → it reads the lock, sees age > 30 min but PID is alive → no takeover.

## Expected
- Output contains `LOCKED|`.
- No `BACKUP_OK` (no takeover).
- Lock file content unchanged.

## Result: PASS

## Evidence
- Pre-created lock with live PID=18332, LastWriteTime=31 min ago.
- Step 1 output: `LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。`
- Got LOCKED: True
- No takeover: True
- Lock PID still matches: True
- Lock content after: `pid=18332;start=2026-09-07T08:04:49.8728474+00:00;step=1;beat=2026-09-07T08:04:49.8728474+00:00`

## Files
- `stdout.txt` — Step 1 output + evidence block
