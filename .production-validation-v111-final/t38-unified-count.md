# Phase 2 — T38 六子测试统一计数矩阵（§12）

> 生成时间: 2026-09-10 06:36 (Asia/Hong_Kong, +08:00)
> 数据来源: 各子测试 stdout.txt 实际计数（主 agent 亲读）

| 子测试 | RUN_STATUS\|success\| | RUN_STATUS\|failed\| | REVIEW_WRITE_ERROR | RUNTIME_ERROR | COMMIT_OK | SENTINEL | 判定 |
|---|---|---|---|---|---|---|---|
| T38-stats-items | 0 | 1 | 1 | 0 | 0 | 不出现 | **PASS** |
| T38-A | 0 | 1 | 1 | 0 | 0 | 不出现 | **PASS** |
| T38-B | 0 | 1 | 1 | 0 | 0 | 不出现 | **PASS** |
| T38-C | 0 | 1 | 1 | 0 | 0 | 不出现 | **PASS** |
| T38-heartbeat | 0 | 1 | 0 | 1 | 0 | 不出现 | **PASS** |
| T38-result-read | 0 | 1 | 0 | 1 | 0 | 不出现 | **PASS** |

## 统一要求核对

- **每项 failed count = 1**: ✅ 6/6 满足
- **每项 success count = 0**: ✅ 6/6 满足
- **SENTINEL 全部不出现**: ✅ 6/6 满足
- **错误路径不能发生重复 final status**: ✅ 6/6 满足（无第二个 RUN_STATUS|failed|）

## T38-stats-items 核心硬门槛详细核对

| 验证项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| REVIEW_WRITE_ERROR\|review 修改了 stats/items | count = 1 | 1 | ✅ |
| RUN_STATUS\|failed\|review 程序事实完整性校验失败 | count = 1 | 1 | ✅ |
| SENTINEL\|AFTER_STEP4 | 不出现 | 不出现 | ✅ |
| RUN_STATUS\|success\| | count = 0 | 0 | ✅ |
| COMMIT_OK\| | count = 0 | 0 | ✅ |
| REVIEW_WRITE_OK\| | count = 0 | 0 | ✅ |
| 第二次 RUN_STATUS\|failed\| | count = 0 | 0 | ✅ |

## Harness 修复记录

### H-003 — T38 编排器 SENTINEL 输出逻辑错误 + 注入点行号修正

| 项 | 值 |
|---|---|
| 时间 | 2026-09-10T06:30:00+08:00（Phase 2 执行期间） |
| 修复对象 | `lib/t38-orchestrator-{stats-items,a,b,c,heartbeat,result-read}.ps1`（**测试 harness，非被测 SKILL**） |
| 原因 | ①全部 6 个编排器在 Step 4 执行后无条件输出 `SENTINEL\|AFTER_STEP4`，但规格要求所有 T38 子测试 SENTINEL **不出现**（因失败路径 return 阻止执行到达编排器 SENTINEL 行）。正确行为：编排器不应在 Step 4 return 后输出 SENTINEL。②`t38-orchestrator-stats-items.ps1` 注入点 `-AfterLine 7` 错误（在完整性校验+return 之后注入，注入代码永不执行）；修正为 `-AfterLine 6`（origStats 固化后、foreach 循环前）。③`t38-orchestrator-c.ps1` 原在 Step 4 执行前锁 result.json，导致 L478 读取失败（非 L500 Move-Item 失败）；修正为内联注入版，在 L18（JSON 校验后）与 L19（if 判断）之间启动 lock-holder。 |
| 修复内容 | ①6 个编排器注释掉 `Write-Output 'SENTINEL\|AFTER_STEP4'` 行（Step 4 return 后不应到达）；②stats-items 注入点改为 `-AfterLine 6`；③T38-C 改为内联注入版（splice-inline AfterLine=18），在 Move-Item 前启动 lock-holder |
| 影响范围 | T38 全部 6 个子测试 |
| 重新执行 | 修复后全部 6 个子测试重新执行，结果见上方矩阵 |
| 被测对象未修改 | 是 — `SKILL-v1.11.md` SHA256 复核 = `B6632680…C928`（与 Phase 0 基线一致） |
