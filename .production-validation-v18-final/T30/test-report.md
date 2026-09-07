# T30-v18 测试报告 — 并发

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T30/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：同时启动两个 pwsh 进程运行 step1.ps1，验证锁互斥

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | 恰好一个进程包含 `BACKUP_OK` | ✅ | ✅（proc1 有，proc2 无） | ✅ PASS |
| 2 | 恰好一个进程包含 `LOCKED` | ✅ | ✅（proc2 有，proc1 无） | ✅ PASS |
| 3 | 备份文件数量 = 1 | ✅ | ✅（`BACKUP_FILE_COUNT=1`） | ✅ PASS |

**结论**：**T30-v18 PASS** ✅

---

## 2. 关键输出摘要

```
PROC1_BACKUP_OK=True
PROC2_BACKUP_OK=False
PROC1_LOCKED=False
PROC2_LOCKED=True
BACKUP_OK_COUNT=1
LOCKED_COUNT=1
BACKUP_FILE_COUNT=1
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **proc1**：成功创建锁（FileMode.CreateNew）→ 备份成功 → 输出 `BACKUP_OK|...`
- **proc2**：CreateNew 失败（锁已存在）→ 陈锁判定（heartbeat 新鲜）→ 不接管 → 输出 `LOCKED|...`
- **备份**：仅 1 个（proc1 创建）

---

## 4. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | 合并输出（proc1 + proc2） |
| `stderr.txt` | 空 |
| `proc1.txt` | proc1 输出（`BACKUP_OK|...`） |
| `proc1_err.txt` | 空 |
| `proc2.txt` | proc2 输出（`LOCKED|...`） |
| `proc2_err.txt` | 空 |
| `lock-after.txt` | 最终锁文件内容（proc1 持有） |
| `md-before.md` | fixture 副本 |
| `sha256-before.txt` | fixture SHA256 |
| `run-t30.ps1` | 测试执行脚本 |
| `.monitor/backups/` | 1 个备份文件 |

---

## 5. 发现的问题 / 异常

无异常。锁互斥机制按预期工作：FileMode.CreateNew 原子创建保证并发下只有一个进程能成功创建锁，失败者输出 LOCKED。

---

## 6. 结论

**T30-v18 PASS** ✅ — 并发验证通过：两个进程同时运行 step1，恰好一个成功（BACKUP_OK），一个失败（LOCKED），备份文件数量 = 1。
