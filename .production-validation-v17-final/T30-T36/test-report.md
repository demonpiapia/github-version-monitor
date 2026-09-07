# Production Validation v1.7 Final - Test Report (T30-T36)

**Generated:** 2026-09-07 16:04:54 +08:00
**Focus:** Concurrency and lock mechanism

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 7 |
| PASS | 7 |
| FAIL | 0 |
| Overall | ALL PASS |

## Test Details

### T30

| Field | Value |
|-------|-------|
| Test ID | T30 |
| Description | Concurrency: one BACKUP_OK, one LOCKED, no double commit |
| Verdict | **PASS** |

#### Evidence

```
Process 1: LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。
Process 2: BACKUP_OK|20260907-160447719
PID=4820
Exactly one BACKUP_OK: True
Exactly one LOCKED: True
No double BACKUP_OK: True
Backup count: 1 (expected 1)
Lock file exists: True
```

### T31

| Field | Value |
|-------|-------|
| Test ID | T31 |
| Description | Heartbeat: lock fields (pid/start/step/beat) present and step changes 1->2->3->4 |
| Verdict | **PASS** |

#### Evidence

```
=== T31 Step 1: Create lock ===
  BACKUP_OK|20260907-160448435
  [Step1] PASS | pid=2652 step=1 (expected step=1) allFields=True pidMatch=True stepMatch=True
    raw=pid=2652;start=2026-09-07T08:04:48.4270872+00:00;step=1;beat=2026-09-07T08:04:48.4270872+00:00

=== T31 Step 2: Heartbeat refresh ===
  [Step2] PASS | pid=2652 step=2 (expected step=2) allFields=True pidMatch=True stepMatch=True
    raw=pid=2652;start=2026-09-07T08:04:48.4270872+00:00;step=2;beat=2026-09-07T08:04:48.6157341+00:00
=== T31 Step 3: Heartbeat refresh with ownership check ===
  [Step3] PASS | pid=2652 step=3 (expected step=3) allFields=True pidMatch=True stepMatch=True
    raw=pid=2652;start=2026-09-07T08:04:48.4270872+00:00;step=3;beat=2026-09-07T08:04:48.7418080+00:00
=== T31 Step 4: Heartbeat refresh with ownership check ===
  [Step4] PASS | pid=2652 step=4 (expected step=4) allFields=True pidMatch=True stepMatch=True
    raw=pid=2652;start=2026-09-07T08:04:48.4270872+00:00;step=4;beat=2026-09-07T08:04:48.8469866+00:00
=== T31 Step 5: Heartbeat + release ===
  [Step5-pre-release] PASS | pid=2652 step=4 (expected step=4) allFields=True pidMatch=True stepMatch=True
    raw=pid=2652;start=2026-09-07T08:04:48.4270872+00:00;step=4;beat=2026-09-07T08:04:48.8469866+00:00
  [Step5-release] PASS: lock released (deleted)
  [Step5-verify] PASS: lock file deleted after release

=== T31 SUMMARY ===
Step1=True Step2=True Step3=True Step4=True Step5PreRelease=True LockReleased=True LockGone=True
OVERALL=PASS
```

### T32

| Field | Value |
|-------|-------|
| Test ID | T32 |
| Description | Fresh/live lock: live PID + fresh heartbeat -> LOCKED |
| Verdict | **PASS** |

#### Evidence

```
Pre-created lock with live PID=18332 and fresh heartbeat
Step 1 output: LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。
Got LOCKED: True
No takeover (no BACKUP_OK): True
Lock PID still matches: True
Lock content after: pid=18332;start=2026-09-07T08:04:49.1298141+00:00;step=1;beat=2026-09-07T08:04:49.1298141+00:00

```

### T33

| Field | Value |
|-------|-------|
| Test ID | T33 |
| Description | Stale + alive: heartbeat >30min, PID alive -> LOCKED |
| Verdict | **PASS** |

#### Evidence

```
Pre-created lock with live PID=18332, LastWriteTime=31min ago
Step 1 output: LOCKED|另一轮监测持有运行锁（或陈锁判定不确定，保守不抢），本轮直接退出。
Got LOCKED: True
No takeover: True
Lock PID still matches: True
Lock content after: pid=18332;start=2026-09-07T08:04:49.8728474+00:00;step=1;beat=2026-09-07T08:04:49.8728474+00:00

```

### T34

| Field | Value |
|-------|-------|
| Test ID | T34 |
| Description | Stale + dead: heartbeat >30min, PID dead -> takeover |
| Verdict | **PASS** |

#### Evidence

```
Pre-created lock with dead PID=999999, LastWriteTime=31min ago
PID 999999 is dead: YES
Step 1 output: BACKUP_OK|20260907-160451077 PID=28468
Got BACKUP_OK (takeover): BACKUP_OK|20260907-160451077
Not LOCKED: True
Lock has new PID (takeover happened): True
Lock content after: pid=28468;start=2026-09-07T08:04:51.0656164+00:00;step=1;beat=2026-09-07T08:04:51.0656164+00:00

```

### T35

| Field | Value |
|-------|-------|
| Test ID | T35 |
| Description | Ownership mismatch: foreign PID -> RUNTIME_ERROR, lock retained |
| Verdict | **PASS** |

#### Evidence

```
Pre-created lock with foreign PID=999998, step=4
PID 999998 is dead: YES
Step 5 output: COMMIT_OK|已原子替换主 md（数据行 1，yes/no 校验通过，repo 集合一致）。 RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。 RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。
Has RUNTIME_ERROR (ownership): RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。
Has RUN_STATUS|failed: RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。
Lock file still exists: True
Lock still has foreign PID: True
Lock content after: pid=999998;start=2026-09-07T08:04:51.2452607+00:00;step=4;beat=2026-09-07T08:04:51.2452607+00:00

```

### T36

| Field | Value |
|-------|-------|
| Test ID | T36 |
| Description | Process kill: lock left behind, fresh=LOCKED, stale+dead=takeover |
| Verdict | **PASS** |

#### Evidence

```
Killed process PID: 29272
Lock exists after kill: True
Backup exists after kill: True
Main md unchanged: True
Re-run with fresh heartbeat got LOCKED: True
No takeover with fresh heartbeat: True
Lock still has dead PID after fresh re-run: True
Re-run after stale got BACKUP_OK: BACKUP_OK|20260907-160454729
Lock has new PID after stale re-run (takeover): True
Hold output: BACKUP_OK|20260907-160452507
PID=29272
STEP1_DONE|Lock created, now holding (sleeping to simulate Step 2 work)...

```

## Tests Overview

| Test | Description | Verdict |
|------|-------------|---------|
| T30 | Concurrency: one BACKUP_OK, one LOCKED, no double commit | **PASS** |
| T31 | Heartbeat: lock fields (pid/start/step/beat) present and step changes 1->2->3->4 | **PASS** |
| T32 | Fresh/live lock: live PID + fresh heartbeat -> LOCKED | **PASS** |
| T33 | Stale + alive: heartbeat >30min, PID alive -> LOCKED | **PASS** |
| T34 | Stale + dead: heartbeat >30min, PID dead -> takeover | **PASS** |
| T35 | Ownership mismatch: foreign PID -> RUNTIME_ERROR, lock retained | **PASS** |
| T36 | Process kill: lock left behind, fresh=LOCKED, stale+dead=takeover | **PASS** |


