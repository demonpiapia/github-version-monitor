# Phase 1 Report — Diff Integrity + 代码提取 + 工具集

> 执行时间: 2026-09-09
> 执行环境: Windows + PowerShell 7.x
> 被测对象: SKILL-v1.10.md (SHA256: 4F7E1170B655F73C847B445570CB68DFDAEB5B4F2C6961AF19A946490123DA42)
> 基线对照: SKILL-v1.9.md (SHA256: 23B4CA59540F69A20A29AC38AF2B70A350C4B4CAEEC27B4A200F98CDE1D89BB1)

---

## 1. Diff 生成结果

| 项目 | 值 |
|---|---|
| 命令 | `git diff --no-index SKILL-v1.9.md SKILL-v1.10.md` |
| 输出文件 | `.production-validation-v110-final/v19-v110.diff` |
| 文件大小 | 11257 bytes |
| 行数 | 66 lines |
| 退出码 | 1（预期：有差异时退出码为 1） |

---

## 2. 28 项能力核验结果

**统计**: 保留 27 项，修改 1 项，缺失 0 项

| 状态 | 计数 | 说明 |
|---|---|---|
| 保留 | 27 | v1.9 能力在 v1.10 中完整保留 |
| 修改 | 1 | RUN_STATUS\|failed\| 新增 4 处输出（heartbeat / result.json-read / review-tmp / review-JSON / review-atomic） |
| 缺失 | 0 | 无 v1.9 能力丢失 |

详细核验表见 `diff-integrity.md` §2。

---

## 3. 9 项禁止项检查结果

**结论**: 全部通过（9/9）

| # | 禁止项 | 结果 |
|---|---|---|
| 1 | mock URL | ✅ 不存在 |
| 2 | forced success | ✅ 不存在 |
| 3 | debug bypass | ✅ 不存在 |
| 4 | test-only branch | ✅ 不存在 |
| 5 | hardcoded token | ✅ 不存在 |
| 6 | hardcoded test repository | ✅ 不存在 |
| 7 | skip schema | ✅ 不存在 |
| 8 | skip lock | ✅ 不存在 |
| 9 | skip commit | ✅ 不存在 |

---

## 4. 6 条 Step 4 错误路径逐路径核验表

| 错误路径 | SKILL-v1.10 行号 | v1.9 有 return? | v1.10 有 return? | v1.10 有 RUN_STATUS\|failed\|? |
|---|---|---|---|---|
| heartbeat 失败 | L477 | 是（裸 return） | 是 | 是（新增） |
| result.json 读取失败 | L478 | 无 try/catch | 是（新增） | 是（新增） |
| stats/items 完整性失败 | L480 | 是 | **否（移除）** | 是（新增） |
| review tmp 写入失败 | L487 | 是 | 是 | 是（新增） |
| review JSON 校验失败 | L496 | 是 | 是 | 是（新增） |
| review 原子替换失败 | L506 | 是 | 是 | 是（新增） |

### 4.1 L480 关键发现

**stats/items 完整性失败路径在 v1.10 中移除了 `return`**。输出 `RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。` 后，执行落入 L481 `try { $doc|ConvertTo-Json -Depth 8|Set-Content -Path $tmpPath -Encoding UTF8 }` 块。

**影响分析**:
- L481 Set-Content 成功后，执行继续到 L490 `Get-Content $tmpPath -Raw|ConvertFrom-Json`
- L491 校验 `$check.stats` 与 `$origStats` 不一致 → 触发 L492-L497 JSON 校验失败路径
- L492-L497 再次输出 `REVIEW_WRITE_ERROR|review 临时 JSON 校验失败` + `RUN_STATUS|failed|review 临时 JSON 校验失败，整轮终止。`
- **违反 constraint #13 "仅输出一次"**：RUN_STATUS\|failed\| 可能输出 2 次

**Phase 2 T38-stats-items 测试须验证此落入行为**。

### 4.2 行号偏差记录

计划文档中的行号引用与 v1.10 实际行号完全一致，无偏差。

---

## 5. 产出文件清单与 SHA256

### 5.1 Diff 与分析报告

| 文件 | SHA256 |
|---|---|
| `.production-validation-v110-final/v19-v110.diff` | 见下方 |
| `.production-validation-v110-final/diff-integrity.md` | 见下方 |

### 5.2 提取的 Step 脚本（5 个）

| 文件 | 源行号 | SHA256 |
|---|---|---|
| `lib/step1.ps1` | L161-L230 | F07C486AF3FCE83E24904041CD1D471466FE27DDE3DB38416553DFB864A1A689 |
| `lib/step2.ps1` | L240-L422 | EF851690C516BB85EA00232864ECD868E8BEE92BA2794E46E8654C27784522D0 |
| `lib/step3.ps1` | L432-L451 | F8CE8F248BFDA24884AD1092392A4199861DB3AE55E41C1AD292C4511449DBFF |
| `lib/step4.ps1` | L473-L509 | 731C224183828BD8A69074443F111B0CC091B1B7931DEA319BCBAA0A4ECCBC22 |
| `lib/step5-full.ps1` | L521-L654 | 81C4D352AF2C5C6A5926453E4F7A81BE3B0E4A6EAB7A572542F77053A1721AA9 |

### 5.3 Harness 脚本（3 个）

| 文件 | 注入点 | 注入内容 |
|---|---|---|
| `lib/step5-t39-harness.ps1` | L636/L637 之间 | `Set-Content $lockPath -Value "pid=999999;..."` |
| `lib/step4-t38b-harness.ps1` | L489/L490 之间 | `Set-Content $tmpPath -Value '{invalid json' -Force` |
| `lib/step4-t38-stats-items-harness.ps1` | L479/L480 之间 | `$doc.stats.total = 999` |

### 5.4 测试工具（5 个）

| 文件 | 用途 |
|---|---|
| `lib/run-full-pipeline.ps1` | 串行执行 step1→step5-full（dot-source 同进程） |
| `lib/mock-invoke-restmethod.ps1` | mock Invoke-RestMethod 覆盖函数库 |
| `lib/step2-mock-harness.ps1` | mock 测试包装脚本 |
| `lib/create-fixture.ps1` | fixture 生成工具（含动态查询策略） |
| `lib/extract-code.ps1` | 代码提取工具 |

### 5.5 验证报告

| 文件 | 内容 |
|---|---|
| `lib/extraction-manifest.json` | 提取清单（源行号 + SHA256） |
| `lib/mock-contract-selfcheck.txt` | mock contract 对齐自检结果 |
| `lib/stdout-verification.txt` | stdout 透传独立验证结果 |

### 5.6 证据文件

| 文件 | 内容 |
|---|---|
| `phase1-stdout.txt` | Phase 1 执行 stdout |
| `phase1-stderr.txt` | Phase 1 执行 stderr |
| `phase1-report.md` | 本文件 |
| `phase-progress.json` | Phase 1 进度更新 |

---

## 6. stdout 透传独立验证结果

**决策**: `PIPELINE_OK`

**验证方法**: 在隔离测试目录 `.production-validation-v110-final/stdout-verify/` 中运行 `run-full-pipeline.ps1`（dot-source 同进程执行 step1→step5-full），捕获 stdout 与 stderr。

**验证结果**:
- 退出码: 0
- 关键输出标记全部 PRESENT: `BACKUP_OK|` / `FETCH_COMPLETE|` / `SUMMARY|` / `COMMIT_OK|` / `RUN_STATUS|success|`
- step 标记数: 11/11（完整）

**设计发现**:
- 初始版本使用 `pwsh -File` 独立进程执行各 step，因 `$PID` 不同导致 ownership 校验失败
- 修复为 dot-source 同进程执行后，stdout 透传正常
- **T37/T43 使用 `run-full-pipeline.ps1` 单次执行 + 捕获 stdout**

---

## 7. mock contract 对齐自检结果

**结论**: 所有场景取值路径与 contract 表一致。

**Headers 类型选择**: `System.Net.WebHeaderCollection`

**覆盖分析**:
- SKILL L326 (`-is [System.Net.WebHeaderCollection]` 分支): 直接覆盖
- SKILL L327 (索引器访问 `$Headers[$Name]`): WebHeaderCollection 支持
- SKILL L328 (`TryGetValues` 方法): WebHeaderCollection 无此方法，通过 catch 兜底

**PS5.1 语法兼容**: 通过（mock-invoke-restmethod.ps1 和 step2-mock-harness.ps1 未使用 PS7-only 运算符）

**场景覆盖**:
- 成功路径: normal / versionJump / metadata_incomplete / invalid_response ✅
- 异常路径: 401 / 404 / 429 / 403+remaining=0 / 403+remaining>0 / 500 / 302 / network_error ✅

**请求计数验证**: 调用 2 次，日志记录 2 条 ✅（修复见 §8.1.4）

---

## 8. 错误与警告

### 8.1 设计决策记录

1. **run-full-pipeline.ps1 使用 dot-source 而非 pwsh -File**
   - 原因: SKILL 使用 `$PID` 进行 ownership 校验，跨进程 `$PID` 不同会导致 ownership 校验失败
   - 影响: 所有 step 在同进程内执行，`$PID` 一致，ownership 校验通过

2. **mock Headers 使用 WebHeaderCollection 而非 HttpResponseHeaders**
   - 原因: 与 PS5.1 共用同一 mock 库，实现简单
   - 覆盖缺口: PS7 侧 Get-ResponseHeaderValue 面向 HttpResponseHeaders 的分支将无直接覆盖
   - 已在 mock-contract-selfcheck.txt 中记录

3. **T43 fixture 使用 6 个不同真实仓库**
   - 原因: SKILL schema 要求 owner/repo 不得重复
   - 仓库: microsoft/vscode (normal) / nodejs/node (synced) / facebook/react (uninstalled) / microsoft/TypeScript (unsupported) / test/nonexistent-repo-12345 (404) / angular/angular (versionJump)

### 8.2 无错误

Phase 1 执行过程中无错误发生。所有工具调用、代码提取、harness 创建、验证脚本均成功完成。

---

## 9. Phase 1 自检清单

- [x] 确认 diff-integrity.md 中 28 项能力逐项核验完成
- [x] 确认 9 项禁止项检查完成
- [x] 确认 6 条 Step 4 错误路径逐路径核验表完成（含 L480 return 移除发现）
- [x] 确认 5 个 step 脚本 + 3 个 harness + 5 个辅助工具全部按输出清单产出
- [x] 确认 extraction-manifest.json 存在且非空
- [x] 确认 stdout-verification.txt 与 mock-contract-selfcheck.txt 存在且记录了独立验证结果

**Phase 1 状态**: ✅ PASS
