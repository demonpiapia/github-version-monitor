# Phase 6.3 Lock Regression Test Report

## Purpose
验证 SKILL-v1.9 锁机制（SKILL L156-172, L200-229）：
- lock-concurrency: 两进程争锁 → one owner + one LOCKED
- lock-ownership: 外来 PID → RUNTIME_ERROR + foreign lock retained
- lock-stale-alive: 陈锁 + PID 活 → LOCKED（保守不抢）
- lock-stale-dead: 陈锁 + PID 死 → takeover 成功（BACKUP_OK）

## Lock Model
- 原子创建（FileMode.CreateNew）
- heartbeat + PID 存活检查
- 陈锁（heartbeat > 30 分钟）+ PID 死亡 → 接管
- 任何不确定 → 保守 LOCKED

## 注意
- lock-ownership 测试使用 step3.ps1（step3/4/5 验证 ownership，step2 不验证）
- step2 的 heartbeat 刷新不检查 PID 匹配，会覆盖外来 PID 锁

## Results

| Test | Verdict | Detail |
|---|---|---|
| lock-concurrency | PASS | proc1: BACKUP_OK=False LOCKED=True; proc2: BACKUP_OK=True LOCKED=False |
| lock-ownership | PASS | step2: RUNTIME_ERROR=False LOCKED=False FETCH_COMPLETE=True; step3: RUNTIME_ERROR=True LOCKED=False lockRetained=True |
| lock-stale-alive | PASS | LOCKED=True BACKUP_OK=False |
| lock-stale-dead | PASS | BACKUP_OK=True LOCKED=False |
## Summary
- PASS: 4 / 4
- FAIL: 0 / 4
