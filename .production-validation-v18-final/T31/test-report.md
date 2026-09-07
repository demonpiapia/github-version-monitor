# T31-v18 测试报告 — heartbeat

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T31/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：wrapper 脚本在同一进程内运行 step1 → 保存 lock-before → 运行 step2 → 保存 lock-after

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | lock-before 包含 `step=1` | ✅ | ✅（`HAS_STEP1_BEFORE=True`） | ✅ PASS |
| 2 | lock-after 包含 `step=2` | ✅ | ✅（`HAS_STEP2_AFTER=True`） | ✅ PASS |
| 3 | beat 时间戳更新 | ✅ | ✅（`BEAT_CHANGED=True`） | ✅ PASS |

**结论**：**T31-v18 PASS** ✅

---

## 2. 关键输出摘要

```
BEAT_BEFORE=2026-09-07T22:44:38.2380544+00:00
BEAT_AFTER=2026-09-07T22:44:38.3045693+00:00
HAS_STEP1_BEFORE=True
HAS_STEP2_AFTER=True
BEAT_CHANGED=True
LOCK_BEFORE_CONTENT=pid=36228;start=2026-09-07T22:44:38.2380544+00:00;step=1;beat=2026-09-07T22:44:38.2380544+00:00
LOCK_AFTER_CONTENT=pid=36228;start=2026-09-07T22:44:38.2380544+00:00;step=2;beat=2026-09-07T22:44:38.3045693+00:00
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **step1**：创建锁，内容包含 `step=1`，beat = `2026-09-07T22:44:38.2380544+00:00`
- **step2**：独占打开锁文件，刷新 heartbeat，内容变为 `step=2`，beat = `2026-09-07T22:44:38.3045693+00:00`
- **PID**：保持不变（`36228`，同一进程）
- **start**：保持不变（`2026-09-07T22:44:38.2380544+00:00`）

---

## 4. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | wrapper 完整输出 |
| `stderr.txt` | 空 |
| `lock-before.txt` | step1 后锁文件内容（step=1） |
| `lock-after.txt` | step2 后锁文件内容（step=2） |
| `wrapper.ps1` | wrapper 脚本 |
| `run-t31.ps1` | 测试执行脚本 |
| `.monitor/backups/` | step1 备份 |

---

## 5. 发现的问题 / 异常

无异常。heartbeat 刷新机制按预期工作：step2 独占打开锁文件，更新 `step=2` 和 `beat` 时间戳，PID 和 start 保持不变。

---

## 6. 结论

**T31-v18 PASS** ✅ — heartbeat 验证通过：锁 heartbeat 在 step1 → step2 之间正确刷新（step=1 → step=2，beat 时间戳更新）。
