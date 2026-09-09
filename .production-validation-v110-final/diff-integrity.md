# Diff Integrity Report — SKILL-v1.9 → SKILL-v1.10

> Phase 1 产出 | 2026-09-09
> v1.9 SHA256: `23B4CA59540F69A20A29AC38AF2B70A350C4B4CAEEC27B4A200F98CDE1D89BB1`
> v1.10 SHA256: `4F7E1170B655F73C847B445570CB68DFDAEB5B4F2C6961AF19A946490123DA42`
> Diff 文件: `v19-v110.diff` (11257 bytes, 66 lines)

---

## 1. Diff 概要

v1.9 → v1.10 共 66 行 diff，涉及 4 个变更区域：

| 变更区域 | v1.9 行号 | v1.10 行号 | 变更类型 |
|---|---|---|---|
| 版本号更新 | L8 | L8 | 修改 |
| Constraint #13 新增 | — | L81 | 新增 |
| Step 4 错误路径修复 | L475-L503 | L477-L507 | 修改 |
| Changelog v1.10 条目 | — | L768 | 新增 |

---

## 2. 28 项能力核验

| # | 能力项 | v1.9 位置 | v1.10 位置 | 状态 | 备注 |
|---|---|---|---|---|---|
| 1 | versionJump | L116-118, L381 | L116-118, L381 | 保留 | 状态机触发器 + 比较逻辑 |
| 2 | dateSuspicious | L116-118, L381 | L116-118, L381 | 保留 | 状态机触发器 + 比较逻辑 |
| 3 | reviewReasons | L108, L381 | L108, L381 | 保留 | schema 字段 + 状态机赋值 |
| 4 | schema validation | L92-100, L317-320 | L92-100, L317-320 | 保留 | md schema + 解析校验 |
| 5 | strict lowercase yes/no | L74, L319, L612 | L74, L319, L612 | 保留 | `-cnotmatch '^(yes\|no)$'` 大小写敏感 |
| 6 | 404 → not_found | L133, L362 | L133, L362 | 保留 | 状态机 + 异常处理 |
| 7 | rate_limited | L134, L363-364 | L134, L363-364 | 保留 | 429 + 403+remaining=0 |
| 8 | network_error | L136, L367 | L136, L367 | 保留 | 无 HTTP 响应 |
| 9 | auth_error | L139, L361 | L139, L361 | 保留 | 401 |
| 10 | forbidden | L140, L364 | L140, L364 | 保留 | 403+remaining>0 |
| 11 | server_error | L135, L365 | L135, L365 | 保留 | 5xx |
| 12 | invalid_response | L137, L350-351 | L137, L350-351 | 保留 | 200 + 空 tag_name |
| 13 | metadata_incomplete | L138, L347-349 | L138, L347-349 | 保留 | 200 + tag_name 无 published_at |
| 14 | result.fetch.tmp | L398-400, L408-412 | L398-400, L408-412 | 保留 | Step 2 原子写入 |
| 15 | result.review.tmp | L473, L480-481, L499-500 | L475, L480-481, L499-500 | 保留 | Step 4 原子写入 |
| 16 | lock | L194-222, L248-269, L436-444 | L194-222, L248-269, L436-444 | 保留 | 创建 + heartbeat + 释放 |
| 17 | heartbeat | L199, L261, L443, L477, L533 | L199, L261, L443, L477, L533 | 保留 | 各 step 刷新 beat |
| 18 | ownership | L208-211, L248, L440, L476, L637-646 | L208-211, L248, L440, L476, L637-646 | 保留 | PID 匹配校验 |
| 19 | atomic result persistence | L398-412 | L398-412 | 保留 | tmp + 校验 + Move-Item |
| 20 | atomic review persistence | L480-503 | L480-507 | 保留 | tmp + 校验 + Move-Item |
| 21 | atomic md commit | L589-636 | L589-636 | 保留 | tmp + 校验 + Move-Item |
| 22 | commitSucceeded | L621, L627, L650 | L621, L627, L650 | 保留 | 变量 + 赋值 + 条件判断 |
| 23 | COMMIT_OK | L628 | L628 | 保留 | 成功信号输出 |
| 24 | RUN_STATUS\|success\| | L651 | L651 | 保留 | 最终成功终态 |
| 25 | RUN_STATUS\|failed\| | L475, L485, L493, L502, L606, L649, L653 | L477, L487, L496, L506, L606, L649, L653 | 修改 | v1.10 新增 4 处 failed 输出 |
| 26 | .output/GitHub更新监测列表.md | L85, L166, L245, L525 | L85, L166, L245, L525 | 保留 | 状态文件路径 |
| 27 | PS7 production baseline | L9 | L9 | 保留 | "生产执行基准：PowerShell 7.x" |
| 28 | PS5.1 compatibility | L9, L324-330 | L9, L324-330 | 保留 | "PS5.1 仅作兼容性验证" + Get-ResponseHeaderValue |

**统计**: 保留 27 项，修改 1 项（RUN_STATUS|failed| 新增 4 处输出），缺失 0 项。

---

## 3. 9 项禁止项检查

| # | 禁止项 | 检查结果 | 备注 |
|---|---|---|---|
| 1 | mock URL | ✅ 不存在 | diff 中无 mock URL |
| 2 | forced success | ✅ 不存在 | diff 中无强制成功逻辑 |
| 3 | debug bypass | ✅ 不存在 | diff 中无 debug bypass |
| 4 | test-only branch | ✅ 不存在 | diff 中无测试专用分支 |
| 5 | hardcoded token | ✅ 不存在 | diff 中无硬编码 token |
| 6 | hardcoded test repository | ✅ 不存在 | diff 中无硬编码测试仓库 |
| 7 | skip schema | ✅ 不存在 | diff 中无跳过 schema 校验 |
| 8 | skip lock | ✅ 不存在 | diff 中无跳过锁逻辑 |
| 9 | skip commit | ✅ 不存在 | diff 中无跳过提交逻辑 |

**结论**: 9 项禁止项全部通过，diff 中不存在任何禁止内容。

---

## 4. Step 4 错误路径逐路径核验表

| 错误路径 | SKILL-v1.10 行号 | v1.9 有 return? | v1.10 有 return? | v1.10 有 RUN_STATUS\|failed\|? | 备注 |
|---|---|---|---|---|---|
| heartbeat 失败 | L477 | 是（裸 return） | 是 | 是（新增） | v1.10 新增 `Write-Output 'RUN_STATUS\|failed\|步骤4 heartbeat 失败，整轮终止。'` |
| result.json 读取失败 | L478 | 无 try/catch | 是（新增） | 是（新增） | v1.10 新增 try/catch + Release-LockSafely + RUN_STATUS\|failed\| |
| stats/items 完整性失败 | L480 | 是 | **否（移除）** | 是（新增） | **关键发现**：v1.10 移除了 return，执行落入 L481 try 块 |
| review tmp 写入失败 | L487 | 是 | 是 | 是（新增） | v1.10 新增 `Write-Output 'RUN_STATUS\|failed\|review 写入失败，整轮终止。'` |
| review JSON 校验失败 | L496 | 是 | 是 | 是（新增） | v1.10 新增 `Write-Output 'RUN_STATUS\|failed\|review 临时 JSON 校验失败，整轮终止。'` |
| review 原子替换失败 | L506 | 是 | 是 | 是（新增） | v1.10 新增 `Write-Output 'RUN_STATUS\|failed\|review 原子替换失败，整轮终止。'` |

### 4.1 L480 关键发现

**stats/items 完整性失败路径在 v1.10 中移除了 `return`**。输出 `RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。` 后，执行落入 L481 `try { $doc|ConvertTo-Json -Depth 8|Set-Content -Path $tmpPath -Encoding UTF8 }` 块。

**影响分析**：
- 如果 L481 Set-Content 成功，执行继续到 L490 `Get-Content $tmpPath -Raw|ConvertFrom-Json`
- L491 校验 `$check.stats` 与 `$origStats` 不一致（因 $doc.stats.total 已被篡改）→ 触发 L492-L497 JSON 校验失败路径
- L492-L497 再次输出 `REVIEW_WRITE_ERROR|review 临时 JSON 校验失败，不替换 result.json。` + `RUN_STATUS|failed|review 临时 JSON 校验失败，整轮终止。`
- **违反 constraint #13 "仅输出一次"**：RUN_STATUS|failed| 输出 2 次

**Phase 2 T38-stats-items 测试须验证此落入行为是否导致二次输出**。

### 4.2 行号偏差记录

计划文档中的行号引用基于 v1.9 行号，实际 v1.10 行号因新增 result.json try/catch 导致后续行整体 +1。偏差记录：

| 计划行号 | 实际 v1.10 行号 | 偏差 |
|---|---|---|
| L477 (heartbeat) | L477 | 0 |
| L478 (result.json) | L478 | 0 |
| L480 (stats/items) | L480 | 0 |
| L487 (review tmp) | L487 | 0 |
| L496 (JSON 校验) | L496 | 0 |
| L506 (原子替换) | L506 | 0 |

**结论**: 计划文档中的行号与实际 v1.10 行号完全一致，无偏差。

---

## 5. 代码提取验证

| 文件 | 源行号范围 | SHA256 | 状态 |
|---|---|---|---|
| step1.ps1 | L161-L230 | F07C486AF3FCE83E24904041CD1D471466FE27DDE3DB38416553DFB864A1A689 | ✅ 提取成功 |
| step2.ps1 | L240-L422 | EF851690C516BB85EA00232864ECD868E8BEE92BA2794E46E8654C27784522D0 | ✅ 提取成功 |
| step3.ps1 | L432-L451 | F8CE8F248BFDA24884AD1092392A4199861DB3AE55E41C1AD292C4511449DBFF | ✅ 提取成功 |
| step4.ps1 | L473-L509 | 731C224183828BD8A69074443F111B0CC091B1B7931DEA319BCBAA0A4ECCBC22 | ✅ 提取成功 |
| step5-full.ps1 | L521-L654 | 81C4D352AF2C5C6A5926453E4F7A81BE3B0E4A6EAB7A572542F77053A1721AA9 | ✅ 提取成功 |

**验证方法**: 提取脚本与原文逐字一致，SHA256 已记录于 `extraction-manifest.json`。

---

## 6. Harness 注入点验证

| Harness | 注入点 | 注入内容 | 状态 |
|---|---|---|---|
| step5-t39-harness.ps1 | L636/L637 之间 | `Set-Content $lockPath -Value "pid=999999;..."` | ✅ 注入成功 |
| step4-t38b-harness.ps1 | L489/L490 之间 | `Set-Content $tmpPath -Value '{invalid json' -Force` | ✅ 注入成功 |
| step4-t38-stats-items-harness.ps1 | L479/L480 之间 | `$doc.stats.total = 999` | ✅ 注入成功 |

**受限 diff 规则**: 每个 harness 与 SKILL 原文仅允许存在一处注入差异，其余代码须逐字一致。Phase 11 复核时按此规则验证。

---

## 7. 结论

- **28 项能力**: 27 项保留，1 项修改（RUN_STATUS|failed| 新增 4 处输出），0 项缺失
- **9 项禁止项**: 全部通过
- **6 条错误路径**: 5 条新增 RUN_STATUS|failed|，1 条（L480）移除 return 导致执行落入后续 try 块
- **代码提取**: 5 个 step 脚本全部提取成功，SHA256 已记录
- **Harness 注入**: 3 个 harness 全部注入成功，注入点精确

**Phase 1 状态**: ✅ PASS
