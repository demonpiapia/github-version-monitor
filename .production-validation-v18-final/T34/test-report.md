# T34-v18 测试报告 — 陈锁 + PID 死

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T34/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：step1 创建锁 → 修改锁（beat=31 分钟前，PID=死进程 99999999）→ 新进程运行 step1

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | 输出 `BACKUP_OK`（接管成功） | ✅ | ✅（`HAS_BACKUP_OK=True`） | ✅ PASS |
| 2 | 无 `LOCKED`（成功接管） | ✅ | ✅（`HAS_LOCKED=False`） | ✅ PASS |
| 3 | 锁文件 PID 更新为新进程 PID（非死进程 PID） | ✅ | ✅（`NEW_LOCK_PID=24912`，`NEW_PID_DIFFERENT_FROM_DEAD=True`） | ✅ PASS |

**结论**：**T34-v18 PASS** ✅

---

## 2. 关键输出摘要

```
DEAD_PID=99999999
LOCK_MODIFIED|beat=2026-09-07T22:15:32.8516835+00:00
HAS_LOCKED=False
HAS_BACKUP_OK=True
LOCK_STILL_PRESENT=YES_LOCK_STILL_PRESENT
NEW_LOCK_PID=24912
NEW_PID_DIFFERENT_FROM_DEAD=True
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **phase1**：step1 创建锁（step=1，beat=当前时间）
- **phase2**：修改锁文件：beat=31 分钟前，PID=死进程 PID（`99999999`），LastWriteTime=31 分钟前
- **phase3**：新进程运行 step1 → CreateNew 失败 → 陈锁判定：ageMin > 30 且 PID 死亡（Get-Process 返回 null）→ 接管 → 删除旧锁 → 创建新锁 → 备份成功 → 输出 `BACKUP_OK|...`
- **锁文件**：PID 更新为新进程 PID（`24912`）

---

## 4. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | phase3 step1 输出（`BACKUP_OK|...`） |
| `stderr.txt` | 空 |
| `step1-output.txt` | phase1 step1 输出（`BACKUP_OK|...`） |
| `lock-before.txt` | phase1 后锁文件内容（step=1，beat=当前） |
| `lock-modified.txt` | 修改后锁文件内容（step=1，beat=31 分钟前，PID=99999999） |
| `lock-after.txt` | phase3 后锁文件内容（新 PID=24912） |
| `lock-still-present.txt` | `YES_LOCK_STILL_PRESENT` |
| `md-before.md` | fixture 副本 |
| `sha256-before.txt` | fixture SHA256 |
| `run-t34.ps1` | 测试执行脚本 |
| `.monitor/backups/` | 2 个备份文件（phase1 + phase3 接管后） |

---

## 5. 发现的问题 / 异常

无异常。陈锁接管逻辑按预期工作：heartbeat 超 30 分钟且 PID 死亡时，成功接管（BACKUP_OK），锁文件 PID 更新为新进程 PID。

---

## 6. 结论

**T34-v18 PASS** ✅ — 陈锁 + PID 死验证通过：锁 heartbeat 超 30 分钟且 PID 死亡时，接管成功（BACKUP_OK），锁文件 PID 更新为新进程 PID。
