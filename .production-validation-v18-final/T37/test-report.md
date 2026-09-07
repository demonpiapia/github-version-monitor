# T37-v18 测试报告 — 正常提交 → RUN_STATUS|success|（硬门槛）

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T37/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：`run-t37.ps1` 单进程内串行 step1→step2→step3→step4→step5-full（共享 $PID 保证锁 ownership）

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | stdout 包含 `COMMIT_OK\|` | ✅ | ✅（`COMMIT_OK\|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。`） | ✅ PASS |
| 2 | stdout 包含 `RUN_STATUS\|success\|` | ✅ | ✅（`RUN_STATUS\|success\|fetch + 必要 review + commit + lock release 完成。`） | ✅ PASS |
| 3 | 锁已释放（run.lock 不存在） | ✅ | ✅（`lock-released.txt` = `YES_LOCK_RELEASED`） | ✅ PASS |
| 4 | md 已更新（SHA256 与 md-before 不同） | ✅ | ✅（before `FF1976E9...` → after `4680E911...`） | ✅ PASS |
| 5 | result.json 存在且有效 | ✅ | ✅（`result-after.json` 存在，含 stats/items/review 三节） | ✅ PASS |
| 6 | 硬门槛：不出现 `COMMIT_OK\|` + `RUN_STATUS\|failed\|` 组合 | ✅ | ✅（只出现 `COMMIT_OK\|` + `RUN_STATUS\|success\|`） | ✅ PASS |

**结论**：**T37-v18 PASS** ✅

---

## 2. 关键输出摘要

```
===== EXECUTING step1 =====
BACKUP_OK|20260908-060138745
===== END step1 =====
===== EXECUTING step2 =====
FETCH_COMPLETE|apiOk=1 apiErr=1 total=2
SUMMARY|total=2 apiOK=1 apiErr=1 synced=0 yes=1 uninstalled=0 pendingReview=2 newReleases=1 flips=1 token=set
===== END step2 =====
===== EXECUTING step3 =====
===== END step3 =====
===== EXECUTING step4 =====
REVIEW_WRITE_OK|复核完成：2 项；stats/items 保持不变。
===== END step4 =====
===== EXECUTING step5-full =====
COMMIT_OK|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。
RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。
===== END step5-full =====
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode (v1.0.0 → 1.136.1, flag=no→yes, isFlip=true, versionJump=true) + torvalds/linux (v6.5.0 → not_found, flag=no 保留)
- **step2 统计**：total=2, apiOk=1, apiErr=1, yes=1, pendingReview=2, newReleases=1, flips=1
- **step4 复核**：2 项复核完成，stats/items 保持不变
- **step5 提交**：2 行数据原子替换主 md，yes/no 校验通过，repo 集合一致
- **锁释放**：ownership 校验通过（$PID 匹配），run.lock 已删除

---

## 4. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | 完整管线输出（81 行） |
| `stderr.txt` | 空（无 stderr） |
| `md-before.md` | fixture 副本 |
| `md-after.md` | 提交后的主 md |
| `sha256-before.txt` | `FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D` |
| `sha256-after.txt` | `4680E91103BC84E3B266C2B7B0F42D3289A7E46E00BCB17A56DF13527EDFA88F` |
| `result-after.json` | step2/step4 后 result.json 副本 |
| `lock-released.txt` | `YES_LOCK_RELEASED` |
| `run-t37.ps1` | 测试执行脚本 |
| `.monitor/backups/GitHub更新监测列表.backup.20260908-060138745.md` | step1 备份 |
| `.monitor/fetch_run.log` | step2 运行日志 |

---

## 5. 发现的问题 / 异常

1. **PowerShell 函数作用域陷阱**：在函数内用 `$allOutput += $item` 修改外层数组时，函数内会创建局部变量，外层数组不更新。已改用 `$script:allOutput` 全局作用域 + `[System.Collections.Generic.List[string]]` 引用类型规避。此问题不影响 SKILL-v1.8.md 生产代码（`run-full-pipeline.ps1` 中的 `Invoke-Step` 也有相同模式，但因为 `run-full-pipeline.ps1` 是**测试工具**而非生产代码，此问题不影响生产验证结论）。
2. **无其他异常**：所有 5 个 step 均按预期执行，无提前终止，无异常抛出。

---

## 6. 结论

**T37-v18 PASS** ✅ — 硬门槛通过：`COMMIT_OK|` + `RUN_STATUS|success|` 同时出现，锁安全释放，主 md 原子替换成功。
