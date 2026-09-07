# T39-v18 测试报告 — 提交成功 + 锁释放失败

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T39/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：step1 + step2 + step3 + step4 → step5-commit.ps1 → 修改锁 PID → step5-lockrelease-test.ps1（wrapper 加载 step5-lockrelease.ps1）

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | 输出包含 `COMMIT_OK\|`（来自 step5-commit.ps1） | ✅ | ✅（`COMMIT_OK\|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。`） | ✅ PASS |
| 2 | 输出包含 `RUNTIME_ERROR\|`（来自 step5-lockrelease-test.ps1） | ✅ | ✅（`RUNTIME_ERROR\|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。`） | ✅ PASS |
| 3 | 输出包含 `RUN_STATUS\|failed\|` | ✅ | ✅（`RUN_STATUS\|failed\|主 md 提交状态不可否认，但运行锁未安全释放。`） | ✅ PASS |
| 4 | **绝不出现** `RUN_STATUS\|success\|` | ✅ | ✅（stdout 中无 `RUN_STATUS\|success\|`） | ✅ PASS |
| 5 | 锁文件残留（未释放） | ✅ | ✅（`lock-released.txt` = `NO_LOCK_STILL_PRESENT`） | ✅ PASS |
| 6 | md 已更新（提交成功） | ✅ | ✅（SHA256 与 md-before 不同） | ✅ PASS |

**结论**：**T39-v18 PASS** ✅

---

## 2. 关键输出摘要

```
===== EXECUTING step5-commit =====
COMMIT_OK|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。
===== END step5-commit =====
===== EXECUTING step5-lockrelease-test =====
RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。
RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。
===== END step5-lockrelease-test =====
```

---

## 3. 数据流摘要

- **step1-step4**：正常执行，result.json 含 2 项 review 数据（version_jump + not_found）
- **step5-commit.ps1**：主 md 原子替换成功，`$commitSucceeded=$true`，输出 `COMMIT_OK|`
- **锁修改**：将 `pid=<实际PID>` 替换为 `pid=999999`（模拟锁 ownership 不一致）
- **step5-lockrelease-test.ps1**：wrapper 设置 `$commitSucceeded=$true`，dot-source 加载 `step5-lockrelease.ps1`
- **step5-lockrelease.ps1 逻辑**：读取锁文件 → `$lockPid=999999 ≠ $PID` → `$lockReleased=$false` → 输出 `RUNTIME_ERROR|` + `RUN_STATUS|failed|`

---

## 4. v1.8 修复验证

**v1.8 关键修复点**（见 phase1-report.md §4）：
> `$commitSucceeded` 状态遗漏修复 + `COMMIT_OK` / `RUN_STATUS` invariant 加固：`RUN_STATUS|success|` 必须同时满足 `$commitSucceeded=$true` 与 `$lockReleased=$true`。

**T39 验证结果**：
- `$commitSucceeded=$true`（提交成功）+ `$lockReleased=$false`（锁释放失败）→ 输出 `RUN_STATUS|failed|`（**不是** `RUN_STATUS|success|`）
- ✅ **invariant 加固生效**：即使提交成功，只要锁未安全释放，就不会输出 `RUN_STATUS|success|`

**对比 v1.7 行为**（预期）：
- v1.7 中 `$commitSucceeded` 未在 `Move-Item` 成功后置 `$true`，导致即使提交成功，`$commitSucceeded` 仍为 `$false`
- v1.7 中 invariant 未加固，可能出现 `COMMIT_OK|` + `RUN_STATUS|failed|` 的"提交成功但状态失败"矛盾组合
- v1.8 修复后，`COMMIT_OK|` 严格对应 `$commitSucceeded=$true`，`RUN_STATUS|success|` 严格要求双条件满足

---

## 5. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | 完整输出（84 行） |
| `stderr.txt` | 空 |
| `md-before.md` | fixture 副本 |
| `md-after.md` | 提交后的主 md |
| `sha256-before.txt` | `FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D` |
| `sha256-after.txt` | 与 before 不同（提交成功） |
| `result-before.json` | step4 后 result.json 副本 |
| `result-after.json` | step5 后 result.json 副本（未变） |
| `lock-before.txt` | step5-commit 前锁文件内容（`pid=<实际PID>`） |
| `lock-before-status.txt` | `LOCK_PRESENT` |
| `lock-after-modify.txt` | 修改后锁文件内容（`pid=999999`） |
| `lock-after.txt` | 最终锁文件状态（残留，未释放） |
| `lock-released.txt` | `NO_LOCK_STILL_PRESENT` |
| `run-t39.ps1` | 测试执行脚本 |
| `step5-lockrelease-test.ps1` | 测试包装器（提供 `$lockPath` / `$commitSucceeded` 变量上下文） |
| `.monitor/backups/GitHub更新监测列表.backup.20260908-060626475.md` | step1 备份 |
| `.monitor/fetch_run.log` | step2 运行日志 |

---

## 6. 发现的问题 / 异常

1. **测试包装器路径问题**：初版 `run-t39.ps1` 用 `Invoke-Step` 调用 `step5-lockrelease-test.ps1`，但 `Invoke-Step` 内部用 `Join-Path $lib $Script` 拼接路径，导致找不到 wrapper（wrapper 在 `$base` 而非 `$lib`）。已修正为直接调用 `& (Join-Path $base 'step5-lockrelease-test.ps1')`。此问题不影响 SKILL-v1.8.md 生产代码。
2. **无其他异常**：所有 5 个断言 + 2 个额外验证全部通过。

---

## 7. 结论

**T39-v18 PASS** ✅ — v1.8 的 `COMMIT_OK` / `RUN_STATUS` invariant 加固验证通过：提交成功 + 锁释放失败 → `RUN_STATUS|failed|`（绝不出现 `RUN_STATUS|success|`）。
