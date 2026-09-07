# T36-v18 测试报告 — 进程中断

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T36/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：启动 hold 进程（step1 + sleep 60）→ kill 进程 → 验证锁残留 → 新进程 step1（LOCKED）→ 手动设置锁 LastWriteTime=31 分钟前 → 新进程 step1（BACKUP_OK）

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | 锁创建成功（hold 进程） | ✅ | ✅（`LOCK_CREATED=True`） | ✅ PASS |
| 2 | 备份存在（hold 进程） | ✅ | ✅（`BACKUP_COUNT=1`） | ✅ PASS |
| 3 | 主 md 未变（hold 进程期间） | ✅ | ✅（`MD_UNCHANGED_AFTER_HOLD=True`） | ✅ PASS |
| 4 | kill 后锁仍存在 | ✅ | ✅（`LOCK_AFTER_KILL=True`） | ✅ PASS |
| 5 | 新进程 step1（heartbeat 新鲜）→ LOCKED | ✅ | ✅（`HAS_LOCKED_1=True`） | ✅ PASS |
| 6 | 新进程 step1（heartbeat 陈 + PID 死）→ BACKUP_OK | ✅ | ✅（`HAS_BACKUP_OK_2=True`） | ✅ PASS |
| 7 | 主 md 最终未变 | ✅ | ✅（`MD_UNCHANGED_FINAL=True`） | ✅ PASS |

**结论**：**T36-v18 PASS** ✅

---

## 2. 关键输出摘要

```
LOCK_CREATED=True
BACKUP_COUNT=1
MD_UNCHANGED_AFTER_HOLD=True
HOLD_PROCESS_KILLED|exit_code=-1
LOCK_AFTER_KILL=True
HAS_LOCKED_1=True
HAS_BACKUP_OK_2=True
HAS_LOCKED_2=False
MD_UNCHANGED_FINAL=True
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **hold 进程**：step1 创建锁 + 备份 → sleep 60 → 被 kill（exit_code=-1）
- **kill 后**：锁残留，备份存在，主 md 未变
- **phase2**：新进程 step1 → CreateNew 失败 → 陈锁判定：ageMin < 30（heartbeat 新鲜）→ 不接管 → 输出 `LOCKED`
- **phase3**：手动设置锁 LastWriteTime=31 分钟前 → 新进程 step1 → CreateNew 失败 → 陈锁判定：ageMin > 30 且 PID 死亡（hold 进程已死）→ 接管 → 删除旧锁 → 创建新锁 → 备份成功 → 输出 `BACKUP_OK`

---

## 4. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | phase4 step1 输出（`BACKUP_OK|...`） |
| `stderr.txt` | 空 |
| `hold-stdout.txt` | hold 进程输出（`BACKUP_OK` + `STEP1_DONE|PID=...`） |
| `hold-stderr.txt` | 空 |
| `lock-before.txt` | hold 进程创建后锁文件内容 |
| `lock-after-kill.txt` | kill 后锁文件内容（残留） |
| `lock-before-takeover.txt` | 手动设置 LastWriteTime 后锁文件内容 |
| `lock-after.txt` | phase4 接管后锁文件内容（新 PID） |
| `md-before.md` | fixture 副本 |
| `md-mid.md` | hold 进程 kill 后主 md（与 before 相同） |
| `md-after.md` | phase4 后主 md（与 before 相同） |
| `sha256-before.txt` | fixture SHA256 |
| `sha256-after.txt` | 最终 SHA256（与 before 相同） |
| `step1-and-hold.ps1` | hold 脚本 |
| `run-t36.ps1` | 测试执行脚本 |
| `.monitor/backups/` | 2 个备份文件（hold 进程 + phase4 接管后） |

---

## 5. 发现的问题 / 异常

无异常。进程中断处理机制按预期工作：
- 进程被 kill 后锁残留（符合预期，因为 step1 没有 try/finally 保护锁释放）
- 新进程运行时，heartbeat 新鲜 → LOCKED（不接管）
- 手动设置 heartbeat 陈 + PID 死 → BACKUP_OK（接管成功）

---

## 6. 结论

**T36-v18 PASS** ✅ — 进程中断验证通过：进程被 kill 后锁残留，下轮运行时正确处理（heartbeat 新鲜 → LOCKED，heartbeat 陈 + PID 死 → BACKUP_OK）。
