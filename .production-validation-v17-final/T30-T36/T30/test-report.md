# T30 — Concurrency

**Focus:** Two real PowerShell 7 processes try to create the lock file simultaneously.

## Scenario
1. Test base directory with `GitHub更新监测列表.md` fixture (octocat/Hello-World).
2. Two `pwsh` processes started via `Start-Process -PassThru` run `common/step1.ps1` concurrently.
3. Wait for both to complete, capture outputs.

## Expected
- Exactly one `BACKUP_OK` (winner).
- Exactly one `LOCKED` (loser).
- No double commit, no double success, no mutual lock deletion.
- Exactly one backup file produced.

## Result: PASS

## Evidence
- Process 1: `LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。`
- Process 2: `BACKUP_OK|20260907-160447719` + `PID=4820`
- Exactly one BACKUP_OK: True
- Exactly one LOCKED: True
- No double BACKUP_OK: True
- Backup count: 1 (expected 1)
- Lock file exists: True

## Files
- `stdout.txt` — combined stdout of both processes + evidence block
- `proc1.txt` / `proc2.txt` — raw per-process stdout
- `proc1_err.txt` / `proc2_err.txt` — raw per-process stderr (empty)
