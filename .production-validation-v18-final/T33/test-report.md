# T33-v18 测试报告 — 陈锁 + PID 活

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T33/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：step1 创建锁 → 修改锁（beat=31 分钟前，PID=活进程）→ 新进程运行 step1

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | 输出 `LOCKED`（不接管，因为 PID 存活） | ✅ | ✅（`HAS_LOCKED=True`） | ✅ PASS |
| 2 | 无 `BACKUP_OK`（未接管） | ✅ | ✅（`HAS_BACKUP_OK=False`） | ✅ PASS |
| 3 | 锁文件未被删除 | ✅ | ✅（`LOCK_STILL_PRESENT=YES_LOCK_STILL_PRESENT`） | ✅ PASS |

**结论**：**T33-v18 PASS** ✅

---

## 2. 关键输出摘要

```
LIVE_PID=29612
LIVE_PID_ALIVE=True
LOCK_MODIFIED|beat=2026-09-07T22:14:50.4835247+00:00
HAS_LOCKED=True
HAS_BACKUP_OK=False
LOCK_STILL_PRESENT=YES_LOCK_STILL_PRESENT
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **phase1**：step1 创建锁（step=1，beat=当前时间）
- **phase2**：修改锁文件：beat=31 分钟前，PID=活进程 PID（`29612`），LastWriteTime=31 分钟前
- **phase3**：新进程运行 step1 → CreateNew 失败 → 陈锁判定：ageMin > 30 但 PID 存活（Get-Process 返回非 null）→ 不接管 → 输出 `LOCKED|...`
- **锁文件**：未被删除（仍包含修改后的内容）

---

## 4. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | phase3 step1 输出（`LOCKED|...`） |
| `stderr.txt` | 空 |
| `step1-output.txt` | phase1 step1 输出（`BACKUP_OK|...`） |
| `lock-before.txt` | phase1 后锁文件内容（step=1，beat=当前） |
| `lock-modified.txt` | 修改后锁文件内容（step=1，beat=31 分钟前，PID=活进程） |
| `lock-after.txt` | phase3 后锁文件内容（与 lock-modified 相同，未被删除） |
| `lock-still-present.txt` | `YES_LOCK_STILL_PRESENT` |
| `md-before.md` | fixture 副本 |
| `sha256-before.txt` | fixture SHA256 |
| `run-t33.ps1` | 测试执行脚本 |
| `.monitor/backups/` | 1 个备份文件（phase1 创建） |

---

## 5. 发现的问题 / 异常

无异常。陈锁接管逻辑按预期工作：heartbeat 超 30 分钟但 PID 存活时，保守不接管，输出 LOCKED。

---

## 6. 结论

**T33-v18 PASS** ✅ — 陈锁 + PID 活验证通过：锁 heartbeat 超 30 分钟但 PID 存活时，不接管（LOCKED），锁文件未被删除。
