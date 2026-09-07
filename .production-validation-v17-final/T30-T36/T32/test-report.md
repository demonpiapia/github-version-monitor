# T32 — Fresh/live lock

**Focus:** Live PID + fresh heartbeat → LOCKED (no takeover).

## Scenario
1. Pre-create `.monitor/run.lock` with `pid=<current PID>` and a fresh `beat` timestamp.
2. Run `common/step1.ps1` in a child pwsh process.
3. Child's `CreateNew` fails → it reads the lock, sees fresh heartbeat (< 30 min) → no takeover.

## Expected
- Output contains `LOCKED|`.
- No `BACKUP_OK` (no takeover).
- Lock file content unchanged (still has the original PID).

## Result: PASS

## Evidence
- Pre-created lock with live PID=18332 and fresh heartbeat.
- Step 1 output: `LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。`
- Got LOCKED: True
- No takeover (no BACKUP_OK): True
- Lock PID still matches: True
- Lock content after: `pid=18332;start=2026-09-07T08:04:49.1298141+00:00;step=1;beat=2026-09-07T08:04:49.1298141+00:00`

## Files
- `stdout.txt` — Step 1 output + evidence block
