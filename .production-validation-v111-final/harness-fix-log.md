# Harness Fix Log — SKILL-v1.11 定向生产验证

> 依据: `.exec-plan/exec-plan-v1.11-c.md` §0.10 Test Harness Integrity 协议（Prompt §30）
> 规则: 每次 harness 修复必须记录 ①时间（ISO8601）②原因 ③说明修复对象不属于被测 SKILL ④重新执行受影响的测试
> 被测对象指纹不变性: `SKILL-v1.11.md` SHA256 全程 = `B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928`（Phase 0 基线，Phase 1/2 复核一致）

---

## H-001 — mock 异常构造形状错误（Phase 1）

| 项 | 值 |
|---|---|
| 时间 | 2026-09-09T17:00:00+08:00（Phase 1 第二实例执行期间） |
| 修复对象 | `.production-validation-v111-final/lib/mock-invoke-restmethod.ps1`（**测试 harness，非被测 SKILL**） |
| 原因 | `New-MockHttpException` 返回 `PSCustomObject`。实测（PS 7.6.4）：`throw $PSCustomObject` 时 PowerShell 将其包装为 `System.Management.Automation.RuntimeException`，原始对象所有自定义属性丢失 → `$_ .Exception.Response = $null` → SKILL L355/L357 的 `$code` 保持 `$null` → 全部 8 个异常场景（404/401/429/403×2/500/302/network_error）误判为 `network_error`。此为 harness 缺陷，与被测 SKILL 无关 |
| 修复内容 | 4 处：①`New-MockHttpException` 改返回 `New-Object WorkbuddyMock.MockHttpResponseException($Message,$Response)`（Add-Type 定义的 C# Exception 子类）；②`New-MockHttpResponse` 改返回 C# `MockHttpResponse` 类型（PSCustomObject 有内置 `Headers` 属性会 shadow 自定义 Headers）；③`New-MockResponseHeaders` 改 `Write-Output -NoEnumerate $h`（WebHeaderCollection 实现 ICollection，`return` 会被自动枚举展开为 string）；④文件行尾 LF→CRLF（PS5.1 解析 LF 行尾 here-string 内嵌 C# 报 Unexpected token '}'） |
| 影响范围 | T04-PS7 / T04-PS5.1 / T05-PS5.1 / T18（全部依赖 mock 的 Phase 8/9 测试） |
| 重新执行 | 修复后实测 8 场景 contract 自检：`lib/mock-contract-selfcheck.txt` PASS_COUNT=8 / FAIL_COUNT=0；`powershell.exe -File lib\ps51-syntax-check.ps1` → PS51_TOTAL_ERRORS=0 |
| 被测对象未修改 | 是 — `SKILL-v1.11.md` SHA256 复核 = `B6632680…C928`（与 Phase 0 基线一致） |

---

## H-002 — Phase 0 harness 脚本缺陷（Phase 0，主 agent 记录）

| 项 | 值 |
|---|---|
| 时间 | 2026-09-09T15:08:00–15:14:00+08:00 |
| 修复对象 | `.production-validation-v111-final/phase0-run.ps1`（**测试 harness，非被测 SKILL**） |
| 原因 | ①git 默认 `core.quotepath=true` 将中文路径输出为八进制转义，导致 staged 字符串精确比较误报 False（实际已 staged）；②pwsh 7.6.4 下 `& $git ...` 数组 splatting 解析异常；③初版用 `Write-Error` 报断言失败，`$ErrorActionPreference='Stop'` 下中止脚本并污染 stderr |
| 修复内容 | ①改用 `git -c core.quotepath=false`；②改用 `Invoke-Git` 函数封装；③改用 `Write-Output` + 标志位 |
| 影响范围 | 仅 Phase 0 自身执行脚本；首轮(15:08:46)与次轮(15:12:34)因此中止于 STEP5，第三轮(15:14:03)完整执行 exit=0 |
| 重新执行 | 第三轮完整重跑，`RESULT=COMPLETED`，3 个 SHA256 独立重算 3/3 一致 |
| 被测对象未修改 | 是 — 3 个 SHA256 与基线一致 |

---

## H-003 — T38 编排器 SENTINEL 输出逻辑错误 + 注入点行号修正 + T38-C 构造时机修正（Phase 2）

| 项 | 值 |
|---|---|
| 时间 | 2026-09-10T06:30:00+08:00（Phase 2 执行期间） |
| 修复对象 | `lib/t38-orchestrator-{stats-items,a,b,c,heartbeat,result-read}.ps1`（**测试 harness，非被测 SKILL**） |
| 原因 | ①全部 6 个编排器在 Step 4 执行后无条件输出 `SENTINEL\|AFTER_STEP4`，但规格要求所有 T38 子测试 SENTINEL **不出现**（因失败路径 return 阻止执行到达编排器 SENTINEL 行）。正确行为：编排器不应在 Step 4 return 后输出 SENTINEL。②`t38-orchestrator-stats-items.ps1` 注入点 `-AfterLine 7` 错误（在完整性校验+return 之后注入，注入代码永不执行）；修正为 `-AfterLine 6`（origStats 固化后、foreach 循环前）。③`t38-orchestrator-c.ps1` 原在 Step 4 执行前锁 result.json，导致 L478 读取失败（非 L500 Move-Item 失败）；修正为内联注入版，在 L18（JSON 校验后）与 L19（if 判断）之间启动 lock-holder。 |
| 修复内容 | ①6 个编排器注释掉 `Write-Output 'SENTINEL\|AFTER_STEP4'` 行；②stats-items 注入点改为 `-AfterLine 6`；③T38-C 改为内联注入版（splice-inline AfterLine=18），在 Move-Item 前启动 lock-holder |
| 影响范围 | T38 全部 6 个子测试 |
| 重新执行 | 修复后全部 6 个子测试重新执行，6/6 PASS（failed=1, success=0, SENTINEL 不出现） |
| 被测对象未修改 | 是 — `SKILL-v1.11.md` SHA256 复核 = `B6632680…C928`（与 Phase 0 基线一致） |
