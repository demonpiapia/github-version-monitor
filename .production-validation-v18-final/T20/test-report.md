# T20-v18 测试报告 — result.json 原子性

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T20/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：phase1 step1+step2 生成 result.json → 删除锁 → 启动 lock-holder 进程独占 result.json（FileShare.None）→ phase2 step1+step2 触发 Move-Item 失败

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | stdout 包含 `RUNTIME_ERROR\|result.json 原子替换失败` | ✅ | ✅（`RUNTIME_ERROR\|result.json 原子替换失败：当文件已存在时，无法创建该文件。`） | ✅ PASS |
| 2 | 旧 result.json 未被损坏（SHA256 与 result-before 一致） | ✅ | ✅（before = after = `609711EF...`） | ✅ PASS |
| 3 | result.fetch.tmp 被清理（不存在） | ✅ | ✅（`TMP_EXISTS=False`） | ✅ PASS |
| 4 | 锁已释放（run.lock 不存在） | ✅ | ✅（`LOCK_STILL_PRESENT=False`） | ✅ PASS |

**结论**：**T20-v18 PASS** ✅

---

## 2. 关键输出摘要

```
PHASE1_DONE|result_json=True
LOCK_ACQUIRED=True
PHASE2_DONE
SHA_BEFORE=609711EF8B52D233A05B4D0DE087DC1B9CE1BC1CDF6AFFD2FD7A4690317F3626
SHA_AFTER=609711EF8B52D233A05B4D0DE087DC1B9CE1BC1CDF6AFFD2FD7A4690317F3626
SHA_SAME=True
HAS_RUNTIME_ERROR=True
TMP_EXISTS=False
LOCK_STILL_PRESENT=False
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **phase1**：step1 创建锁 + 备份，step2 生成 result.json（`609711EF...`）
- **phase2**：lock-holder 独占 result.json（FileShare.None）→ step1 创建新锁 + 备份 → step2 生成 result.fetch.tmp → Move-Item 失败 → catch 块清理 tmp + 释放锁 + 输出 `RUNTIME_ERROR|result.json 原子替换失败`
- **result.json**：未被覆盖（SHA256 与 before 一致）

---

## 4. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | phase2 完整输出 |
| `stderr.txt` | 空 |
| `phase1-output.txt` | phase1 step1+step2 输出 |
| `result-before.json` | phase1 后 result.json 副本 |
| `result-after.json` | phase2 后 result.json 副本（与 before 相同） |
| `sha256-before.txt` | `609711EF8B52D233A05B4D0DE087DC1B9CE1BC1CDF6AFFD2FD7A4690317F3626` |
| `sha256-after.txt` | 与 before 相同 |
| `lock-holder.ps1` | lock-holder 脚本 |
| `lock-holder-stdout.txt` | lock-holder 输出（`LOCKED\|PID=...`） |
| `lock-holder-stderr.txt` | 空 |
| `run-t20.ps1` | 测试执行脚本 |
| `.monitor/backups/` | step1 备份（2 个，phase1 + phase2） |

---

## 5. 发现的问题 / 异常

无异常。step2 的 `Move-Item` 失败路径按预期工作：catch 块清理 tmp、释放锁、输出 `RUNTIME_ERROR`，旧 result.json 未被损坏。

---

## 6. 结论

**T20-v18 PASS** ✅ — result.json 原子性验证通过：Move-Item 失败时旧 result.json 不被损坏，tmp 被清理，锁被释放。
