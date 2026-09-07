# T38-v18 测试报告 — review 写回失败

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T38/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：step1 + step2 获取 result.json → 创建只读 `result.review.tmp` → 运行 step4

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | 输出包含错误信息（异常） | ✅ | ✅（`STEP4_EXCEPTION: Access to the path '...result.review.tmp' is denied.`） | ✅ PASS |
| 2 | 无 `COMMIT_OK\|` | ✅ | ✅（stdout 中无 `COMMIT_OK`） | ✅ PASS |
| 3 | 主 md SHA256 不变（未被修改） | ✅ | ✅（before = after = `FF1976E9...`） | ✅ PASS |
| 4 | 锁已释放（run.lock 不存在） | ✅ | ❌（`lock-released.txt` = `NO_LOCK_STILL_PRESENT`） | ❌ FAIL |

**结论**：**T38-v18 PARTIAL** ⚠️ — 3/4 通过，1/4 失败（锁未释放）

---

## 2. 关键输出摘要

```
===== EXECUTING step1 =====
BACKUP_OK|20260908-060348442
===== END step1 =====
===== EXECUTING step2 =====
FETCH_COMPLETE|apiOk=1 apiErr=1 total=2
SUMMARY|total=2 apiOK=1 apiErr=1 synced=0 yes=1 uninstalled=0 pendingReview=2 newReleases=1 flips=1 token=set
===== END step2 =====
===== EXECUTING step4 (with blocked tmp) =====
STEP4_EXCEPTION: Access to the path 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T38\.monitor\result.review.tmp' is denied.
===== END step4 =====
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode (v1.0.0 → 1.136.1, flag=no→yes, isFlip=true, versionJump=true) + torvalds/linux (v6.5.0 → not_found, flag=no 保留)
- **step1**：备份成功，锁创建
- **step2**：API 查询完成（1 ok / 1 not_found），result.json 写入
- **step4**：`Set-Content -Path $tmpPath` 因 tmp 文件只读抛出 `UnauthorizedAccessException`，异常冒泡
- **锁状态**：step4 异常路径无 `try/finally` 保护，`Release-LockSafely` 未被调用，run.lock 残留

---

## 4. 发现的问题 / 异常

### 4.1 SKILL-v1.8.md step4 缺陷（真实代码缺陷）

**位置**：`SKILL-v1.8.md` L472-L479（提取为 `lib/step4.ps1`）

**问题描述**：

step4.ps1 的核心逻辑结构为：
```
try { heartbeat } catch { ...; return }
...
$doc | ConvertTo-Json -Depth 8 | Set-Content -Path $tmpPath -Encoding UTF8   # ← 无 try/catch
try { check = Get-Content $tmpPath ... } catch { $check = $null }
if ($null -eq $check -or ...) { Remove-Item ...; Write-Output 'REVIEW_WRITE_ERROR|...'; Release-LockSafely; return }
try { Move-Item ... } catch { Remove-Item ...; Write-Output 'REVIEW_WRITE_ERROR|...'; Release-LockSafely; return }
Write-Output 'REVIEW_WRITE_OK|...'
```

当 `Set-Content -Path $tmpPath` 因文件只读/权限不足/磁盘满等原因抛出异常时：
- 异常冒泡（`$ErrorActionPreference='Stop'`）
- 后续所有代码（包括 `Release-LockSafely`）都不会执行
- 锁文件残留，导致下一轮运行 LOCKED

**影响**：
- 主 md 不会被修改（✅ 安全）
- result.json 不会被修改（✅ 安全）
- 但锁残留会导致下一轮 LOCKED（❌ 需要人工干预）

**建议修复**：将 `Set-Content -Path $tmpPath` 包装在 `try/catch` 中，catch 块调用 `Release-LockSafely` 并输出 `REVIEW_WRITE_ERROR`。

### 4.2 测试执行无异常

测试脚本 `run-t38.ps1` 正确捕获了 step4 的异常，所有验证步骤按预期执行。

---

## 5. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | 完整输出（72 行） |
| `stderr.txt` | 空 |
| `md-before.md` | fixture 副本 |
| `md-after.md` | 运行后主 md（与 md-before 相同） |
| `sha256-before.txt` | `FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D` |
| `sha256-after.txt` | `FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D`（与 before 相同） |
| `result-before.json` | step2 后 result.json 副本 |
| `result-after.json` | step4 失败后 result.json 副本（与 before 相同，未被修改） |
| `lock-before.txt` | step2 后锁文件内容 |
| `lock-after.txt` | step4 失败后锁文件内容（残留） |
| `lock-released.txt` | `NO_LOCK_STILL_PRESENT` |
| `lock-before-status.txt` | `LOCK_PRESENT` |
| `run-t38.ps1` | 测试执行脚本 |
| `.monitor/backups/GitHub更新监测列表.backup.20260908-060348442.md` | step1 备份 |
| `.monitor/fetch_run.log` | step2 运行日志 |
| `.monitor/result.review.tmp` | 只读文件（测试阻塞用，内容 `BLOCKED`） |

---

## 6. 结论

**T38-v18 PARTIAL** ⚠️ — 测试成功复现了 review 写回失败场景，主 md 和 result.json 均未被修改（安全），但发现 SKILL-v1.8.md step4 存在锁残留缺陷（`Set-Content` 无 try/catch 保护，异常路径不调用 `Release-LockSafely`）。

**这是 SKILL 代码的真实缺陷，不是测试执行问题。** 建议在 SKILL-v1.9 中修复：将 `Set-Content -Path $tmpPath` 包装在 `try/catch` 中，catch 块调用 `Release-LockSafely` 并输出 `REVIEW_WRITE_ERROR`。
