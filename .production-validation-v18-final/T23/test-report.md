# T23-v18 测试报告 — md 替换失败

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T23/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：phase1 step1+step2+step3+step4 生成 result.json → 删除锁 → 启动 lock-holder 进程独占主 md（FileShare.Read，允许读取但阻止 Move-Item）→ 手动创建锁 → phase2 step5-full 触发 Move-Item 失败

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | Move-Item 失败（异常） | ✅ | ✅（`Move-Item: ... 当文件已存在时，无法创建该文件。`） | ✅ PASS |
| 2 | 主 md SHA256 未变 | ✅ | ✅（before = after = `FF1976E9...`） | ✅ PASS |
| 3 | 无 `COMMIT_OK\|` | ✅ | ✅（`HAS_COMMIT_OK=False`） | ✅ PASS |
| 4 | 临时文件被清理（或不存在） | ❌ | ❌（`TMP_EXISTS=True`，tmp 文件残留） | ❌ FAIL |

**结论**：**T23-v18 PARTIAL** ⚠️ — 3/4 通过，1/4 失败（临时文件未被清理）

---

## 2. 关键输出摘要

```
PHASE1_DONE|result_json=True
LOCK_ACQUIRED=True
LOCK_CREATED_MANUALLY|pid=32796
PHASE2_DONE
SHA_BEFORE=FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D
SHA_AFTER=FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D
SHA_SAME=True
TMP_EXISTS=True
HAS_COMMIT_OK=False
HAS_MOVE_ERROR=True
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **phase1**：step1+step2+step3+step4 完成，result.json 生成
- **phase2**：lock-holder 独占主 md（FileShare.Read）→ 手动创建锁 → step5-full 生成 tmp 文件 → Move-Item 失败（`当文件已存在时，无法创建该文件`）→ 异常冒泡（`$ErrorActionPreference='Stop'`）→ 脚本终止
- **主 md**：未被修改（SHA256 与 before 一致）
- **tmp 文件**：残留（未被清理）

---

## 4. 发现的问题 / 异常

### 4.1 step5-full.ps1 缺陷（Move-Item 无 try/catch）

**位置**：`lib/step5-full.ps1` L87-L94

**问题描述**：
```powershell
if ($rows2.Count -eq $items.Count -and $badFlag.Count -eq 0 -and $repoMatch -and $headerOk -and $anchorsOk) {
    Move-Item -Path $tmp -Destination $md -Force  # ← 无 try/catch
    $commitSucceeded=$true
    Write-Output "COMMIT_OK|..."
} else {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Output "VALIDATE_ERROR|..."
}
```

当 `Move-Item` 因目标文件被锁定/权限不足等原因抛出异常时：
- 异常冒泡（`$ErrorActionPreference='Stop'`）
- 后续所有代码（包括锁释放逻辑）都不会执行
- **tmp 文件残留**（未被清理）
- 锁文件残留（未被释放）

**影响**：
- 主 md 不会被修改（✅ 安全）
- 但 tmp 文件和锁残留会导致下一轮运行异常（❌ 需要人工干预）

**建议修复**：将 `Move-Item -Path $tmp -Destination $md -Force` 包装在 `try/catch` 中，catch 块调用 `Remove-Item $tmp` 清理临时文件 + 调用锁释放逻辑 + 输出 `RUNTIME_ERROR`。

### 4.2 测试执行无异常

测试脚本 `run-t23.ps1` 正确捕获了 step5-full 的异常，所有验证步骤按预期执行。

---

## 5. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | phase2 完整输出（含 Move-Item 异常） |
| `stderr.txt` | 空 |
| `phase1-output.txt` | phase1 step1+step2+step3+step4 输出 |
| `md-before.md` | fixture 副本 |
| `md-after.md` | 运行后主 md（与 md-before 相同） |
| `sha256-before.txt` | `FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D` |
| `sha256-after.txt` | 与 before 相同 |
| `.output\GitHub更新监测列表.md.tmp` | 残留的临时文件（未被清理） |
| `lock-holder.ps1` | lock-holder 脚本 |
| `lock-holder-stdout.txt` | lock-holder 输出（`LOCKED\|PID=...`） |
| `lock-holder-stderr.txt` | 空 |
| `run-t23.ps1` | 测试执行脚本 |
| `.monitor/backups/` | step1 备份（phase1 1 个，phase2 无备份因为锁是手动创建的） |

---

## 6. 结论

**T23-v18 PARTIAL** ⚠️ — 测试成功复现了 md 替换失败场景，主 md 未被修改（安全），但发现 SKILL-v1.8.md step5-full 存在锁残留 + tmp 文件残留缺陷（`Move-Item` 无 try/catch 保护，异常路径不调用锁释放逻辑，也不清理 tmp 文件）。

**这是 SKILL 代码的真实缺陷，不是测试执行问题。** 建议在 SKILL-v1.9 中修复：将 `Move-Item -Path $tmp -Destination $md -Force` 包装在 `try/catch` 中，catch 块调用 `Remove-Item $tmp` + 锁释放逻辑 + 输出 `RUNTIME_ERROR`。
