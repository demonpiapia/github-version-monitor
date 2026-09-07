# T35 — Ownership mismatch

**Focus:** Foreign PID in lock → RUNTIME_ERROR at release, foreign lock retained.

## Scenario
1. Copy `result.json` fixture into `.monitor/`.
2. Pre-create `.monitor/run.lock` with `pid=999998` (foreign/dead) and `step=4`.
3. Run `common/step5.ps1` in a child pwsh process.
4. Step 5 body runs (commit succeeds because data is valid), then at release time the ownership check finds `lockPid != current PID` → no deletion.

## Expected
- Output contains `RUNTIME_ERROR|...ownership...`.
- Output contains `RUN_STATUS|failed|...`.
- Lock file still exists (not deleted).
- Lock content still has the foreign PID (not overwritten).

## Result: PASS

## Evidence
- Pre-created lock with foreign PID=999998, step=4.
- PID 999998 is dead: YES.
- Step 5 output:
  - `COMMIT_OK|已原子替换主 md（数据行 1，yes/no 校验通过，repo 集合一致）。`
  - `RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。`
  - `RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。`
- Has RUNTIME_ERROR (ownership): True
- Has RUN_STATUS|failed: True
- Lock file still exists: True
- Lock still has foreign PID: True
- Lock content after: `pid=999998;start=2026-09-07T08:04:51.2452607+00:00;step=4;beat=2026-09-07T08:04:51.2452607+00:00`

## Notes
- The commit itself succeeds (data is valid), but the release guard correctly refuses to delete a lock it does not own. This is the intended safety property: never delete a foreign lock.
- `RUN_STATUS|failed` is emitted because the lock was not released, even though the commit went through. This matches SKILL-v1.7 §"锁释放" semantics.

## Files
- `stdout.txt` — Step 5 output + evidence block
