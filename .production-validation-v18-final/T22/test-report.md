# T22-v18 测试报告 — md 临时文件失败

**执行时间**：2026-09-08 (Asia/Hong_Kong)
**测试目录**：`.production-validation-v18-final/T22/`
**Fixture**：2 个真实仓库（microsoft/vscode localVer=1.0.0 / torvalds/linux localVer=6.5.0）
**执行方式**：phase1 step1+step2+step3+step4 生成 result.json → 删除锁 → 预创建只读 `.output\GitHub更新监测列表.md.tmp` → phase2 step1+step5-full 触发 Set-Content 失败

---

## 1. 验证结果

| # | 断言 | 期望 | 实际 | 结果 |
|---|---|---|---|---|
| 1 | Set-Content 创建临时文件失败（异常） | ✅ | ✅（`Set-Content: ... is denied.`） | ✅ PASS |
| 2 | 主 md SHA256 未变 | ✅ | ✅（before = after = `FF1976E9...`） | ✅ PASS |
| 3 | 无 `COMMIT_OK\|` | ✅ | ✅（`HAS_COMMIT_OK=False`） | ✅ PASS |

**结论**：**T22-v18 PASS** ✅

---

## 2. 关键输出摘要

```
PHASE1_DONE|result_json=True
TMP_MD_READONLY=True
PHASE2_DONE
SHA_BEFORE=FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D
SHA_AFTER=FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D
SHA_SAME=True
HAS_SET_CONTENT_ERROR=True
HAS_COMMIT_OK=False
```

---

## 3. 数据流摘要

- **fixture**：microsoft/vscode + torvalds/linux
- **phase1**：step1+step2+step3+step4 完成，result.json 生成
- **phase2**：step1 创建锁 + 备份 → step5-full 在 L70 `Set-Content -Path $tmp` 因 tmp 文件只读抛出 `UnauthorizedAccessException` → 异常冒泡（`$ErrorActionPreference='Stop'`）→ 脚本终止
- **主 md**：未被修改（SHA256 与 before 一致）

---

## 4. 发现的问题 / 异常

### 4.1 step5-full.ps1 缺陷（与 T38 同类问题）

**位置**：`lib/step5-full.ps1` L70

**问题描述**：
```powershell
$tmp = "$md.tmp"
Set-Content -Path $tmp -Value $newText -Encoding UTF8 -NoNewline  # ← 无 try/catch
```

当 `Set-Content` 因文件只读/权限不足/磁盘满等原因抛出异常时：
- 异常冒泡（`$ErrorActionPreference='Stop'`）
- 后续所有代码（包括锁释放逻辑）都不会执行
- 锁文件残留，导致下一轮运行 LOCKED

**影响**：
- 主 md 不会被修改（✅ 安全）
- 但锁残留会导致下一轮 LOCKED（❌ 需要人工干预）

**建议修复**：将 `Set-Content -Path $tmp` 包装在 `try/catch` 中，catch 块调用锁释放逻辑并输出 `RUNTIME_ERROR`。

---

## 5. 证据文件清单

| 文件 | 说明 |
|---|---|
| `stdout.txt` | phase2 完整输出（含 Set-Content 异常） |
| `stderr.txt` | 空 |
| `phase1-output.txt` | phase1 step1+step2+step3+step4 输出 |
| `md-before.md` | fixture 副本 |
| `md-after.md` | 运行后主 md（与 md-before 相同） |
| `sha256-before.txt` | `FF1976E9431F18D2E54809702395F51779412298CE9446770E9C3D58F57F860D` |
| `sha256-after.txt` | 与 before 相同 |
| `.output\GitHub更新监测列表.md.tmp` | 只读文件（测试阻塞用，内容 `BLOCKED`） |
| `run-t22.ps1` | 测试执行脚本 |
| `.monitor/backups/` | step1 备份（2 个，phase1 + phase2） |

---

## 6. 结论

**T22-v18 PASS** ✅ — 测试成功复现了 md 临时文件创建失败场景，主 md 未被修改（安全）。但发现 SKILL-v1.8.md step5-full 存在与 T38 同类的锁残留缺陷（`Set-Content` 无 try/catch 保护，异常路径不调用锁释放逻辑）。
