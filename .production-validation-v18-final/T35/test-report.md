# T35-v18 测试报告 — ownership 不匹配

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T35/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：step1+step2+step3+step4 生成 result.json → 修改锁 PID 为外部值（999998）→ step5-full

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | 输出包含 `COMMIT_OK`（提交成功） | ✅ | ✅（`HAS_COMMIT_OK=True`） | ✅ PASS |
| 2 | 输出包含 `RUNTIME_ERROR`（ownership 校验失败） | ✅ | ✅（`HAS_RUNTIME_ERROR=True`） | ✅ PASS |
| 3 | 输出包含 `RUN_STATUS\|failed` | ✅ | ✅（`HAS_RUN_STATUS_FAILED=True`） | ✅ PASS |
| 4 | 无 `RUN_STATUS\|success` | ✅ | ✅（`HAS_RUN_STATUS_SUCCESS=False`） | ✅ PASS |
| 5 | 锁文件仍存在（未删除） | ✅ | ✅（`LOCK_STILL_PRESENT=YES_LOCK_STILL_PRESENT`） | ✅ PASS |
| 6 | 锁文件 PID 仍为 999998（未覆盖） | ✅ | ✅（`LOCK_PID_AFTER=999998`，`LOCK_PID_UNCHANGED=True`） | ✅ PASS |

**结论**：**T35-v18 PASS** ✅

---

## 2. 关键输出摘要

```
PHASE1_DONE|result_json=True
LOCK_MODIFIED|pid=999998
HAS_COMMIT_OK=True
HAS_RUNTIME_ERROR=True
HAS_RUN_STATUS_FAILED=True
HAS_RUN_STATUS_SUCCESS=False
LOCK_STILL_PRESENT=YES_LOCK_STILL_PRESENT
LOCK_PID_AFTER=999998
LOCK_PID_UNCHANGED=True
SHA_CHANGED=True
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **phase1**：step1+step2+step3+step4 完成，result.json 生成，锁由 phase1 进程持有
- **phase2**：修改锁 PID 为 999998（外部 PID）
- **phase3**：step5-full 在子进程中运行 → 提交成功（`COMMIT_OK`）→ 锁释放时 ownership 校验失败（lockPid=999998 ≠ 子进程 PID）→ 输出 `RUNTIME_ERROR` + `RUN_STATUS|failed`
- **锁文件**：未被删除（仍包含 pid=999998）

---

## 4. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | phase3 step5-full 输出（`COMMIT_OK` + `RUNTIME_ERROR` + `RUN_STATUS|failed`） |
| `stderr.txt` | 空 |
| `phase1-output.txt` | phase1 step1+step2+step3+step4 输出 |
| `lock-before.txt` | phase1 后锁文件内容（phase1 进程 PID） |
| `lock-after-modify.txt` | 修改后锁文件内容（pid=999998） |
| `lock-after.txt` | phase3 后锁文件内容（仍为 pid=999998，未被删除） |
| `lock-still-present.txt` | `YES_LOCK_STILL_PRESENT` |
| `md-before.md` | fixture 副本 |
| `md-after.md` | 提交后主 md（SHA256 与 before 不同） |
| `sha256-before.txt` | fixture SHA256 |
| `sha256-after.txt` | 提交后 SHA256（与 before 不同） |
| `result-before.json` | phase1 后 result.json 副本 |
| `result-after.json` | phase3 后 result.json 副本 |
| `run-t35.ps1` | 测试执行脚本 |
| `.monitor/backups/` | 1 个备份文件（phase1 创建） |

---

## 5. 发现的问题 / 异常

无异常。ownership 校验机制按预期工作：提交成功后锁释放时，如果锁内 PID 与当前进程 PID 不一致，拒绝删除锁文件，输出 `RUNTIME_ERROR` + `RUN_STATUS|failed`。

---

## 6. 结论

**T35-v18 PASS** ✅ — ownership 不匹配验证通过：提交成功但锁释放时 ownership 校验失败，输出 `RUNTIME_ERROR` + `RUN_STATUS|failed`，锁文件未被删除，PID 未被覆盖。
