# Handoff — SKILL-v1.11 定向生产验证（Phase 0/1 已完成，接续 Phase 2）

> **交接时间**: 2026-09-10 05:32:14 (Asia/Hong_Kong, +08:00)
> **交接来源**: TRAE IDE agent（主 agent 编排者，模型在原 IDE 频繁报错，用户更换 IDE 接续）
> **交接目标**: 新 IDE 的 agent（接任主 agent 编排者）
> **任务性质**: 接续（Clean-Room 已建立，Phase 0/1 已完成并通过审查，Phase 2 起步）

---

## TASK

严格执行 `.exec-plan/exec-plan-v1.11-c.md`（SKILL-v1.11 定向生产验证执行计划，2002 行），完成 Phase 2 至 Phase 13，最终产出 `production-validation-report-v111-final.md` 与 PRODUCTION_READY / NOT_READY / BLOCKED 终态判定。

**核心验证目标**：SKILL-v1.11 修复了 v1.10 的 P1（Step 4 stats/items 完整性失败路径 L480 补齐 `;return`）。本轮硬门槛 = T38-stats-items 路径 `RUN_STATUS|failed|` 计数**恰好为 1**（不是 0 不是 2），SENTINEL 不出现，且 30 项能力 + 全部回归测试不回归。

## INPUTS

- `.exec-plan/exec-plan-v1.11-c.md` — **执行计划（唯一工作规程）**，Phase 0-13 全部规格、判定规则、禁止事项都在这里。每个 Phase 开工前必须重读该 Phase 章节
- `.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md` — 上游事实源（39 节，1310 行）
- `SKILL-v1.11.md` — **被测对象，只读，禁止修改**（776 行）
- `SKILL-v1.10.md` — 基线对比（只读）
- `.output/GitHub更新监测列表.md` — 生产状态文件（**禁止触碰**，SHA256 = `7396981A2FBF019D3DAD0C906A2B6E9C05D36C4746F35E0C0063FD1F3EB19CD3`）
- `.production-validation-v111-final/task-tracker.md` — 主 agent 全局追踪表（**每 Phase 审查后由你更新**）
- `.production-validation-v111-final/phase-progress.json` — sub-agent 断点文件（当前 = Phase1 completed）
- `.production-validation-v111-final/harness-fix-log.md` — harness 修复日志（H-001/H-002 已记录，后续修复必须追加）
- `.production-validation-v111-final/lib/` — 全部测试工具（就绪，见 COMPLETED）
- `.handoff/00-handoff-format.md` — handoff 格式规范（本文件遵循它）

## CURRENT_STATE

- Git branch: `main`
- HEAD commit: `f7ec148` (docs(teamwork): add Zoo agent mapping to agent role table)
- 工作树: dirty（预期内）：
  - **已 staged（Phase 0 完成，勿动勿 commit）**: `A SKILL-v1.11.md`、`A ".GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md"`（commit 属 Phase 13）
  - untracked: `.exec-plan/exec-plan-v1.11-{a,b,b-zoo-review,c}.md`、`.production-validation-v111-final/`、`.workbuddy/` 等（Phase 13 commit 时按计划 §13.6 显式列范围）
- PowerShell 7: **7.6.4**（production 主环境）
- PowerShell 5.1: **5.1.22621.963**（`C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`，存在）
- Clean-Room: `.production-validation-v111-final/` 已建 26 个子目录（**无 `.monitor/` 预创建**，这是 Prompt §24 红线）
- 三个基线指纹（Phase 0 采集，Phase 12 复核要用）:
  - v110 = `4F7E1170B655F73C847B445570CB68DFDAEB5B4F2C6961AF19A946490123DA42`
  - v111 = `B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928`
  - state = `7396981A2FBF019D3DAD0C906A2B6E9C05D36C4746F35E0C0063FD1F3EB19CD3`
- 外部事件（非本轮 agent 操作，已记录于 task-tracker）：Phase 0 期间 HEAD 由 `2cef235` → `f7ec148`（外部行为）；出现 untracked `.workbuddy/`

## COMPLETED

- [x] **Phase 0 — Clean-Room + SHA256 + git add（审查 PASS）** — 证据: `.production-validation-v111-final/phase0-report.md`、`v110.sha256`、`v111.sha256`、`state.sha256`、`phase0-stdout.txt`、`phase0-run.ps1`、`phase-progress.json`。26/26 目录、3 SHA256 独立重算一致、两文件 staged、无旧证据复制
- [x] **Phase 1 — Diff Integrity + 代码提取 + 工具集（审查 PASS，两个 sub-agent 实例接力完成）** — 证据:
  - `v110-v111.diff` + `diff-integrity.md`：**恰好 3 hunk（3+/2-）**，L480 `;return` 逐字节确认（插入位置=字节 545，552→559），**30/30 能力 PASS**、**9/9 辅助禁止项 PASS** → Diff Integrity 总判定 PASS
  - `lib/step1.ps1`(L161-230) / `step2.ps1`(L240-422) / `step3.ps1`(L432-451) / `step4.ps1`(L473-509) / `step5-full.ps1`(L521-654)：5/5 受限 diff **零差异**，`lib/extraction-manifest.json` + `lib/extraction-verify.txt`
  - **14 个 harness 全部就绪**：`t38-orchestrator-{a,b,c,heartbeat,result-read,stats-items}.ps1`、`t22/t23-orchestrator.ps1`、`step5-t39-harness.ps1`、`runtime-artifact-pipeline.ps1`、`run-full-pipeline.ps1`、`lock-holder.ps1`、`watch-dir.ps1`、`step2-mock-harness.ps1`
  - mock 工具：`mock-invoke-restmethod.ps1`（修复后 8 场景 contract 自检 8/8 PASS）+ `create-fixture.ps1`（8 种场景）+ `splice-inline.ps1`（内联注入生成器）+ `ps51-syntax-check.ps1`（PS5.1 语法 0 errors）
  - `lib/mock-contract-selfcheck.txt`（含 PS7 Headers 类型选择 = WebHeaderCollection 及理由）
  - `lib/stdout-verification.txt`：**stdout 透传 PASS** → T37/T43 采用**单次执行捕获**（无需逐 step 拼接）；验证 base 保留在 `T37/stdout-verify-base/`
  - `phase1-report.md`、`phase1-stdout.txt`、`phase1-stderr.txt`

## FAILED

- [ ] Phase 1 第一实例 — 上下文耗尽，中断于 Step 7.1（Steps 1-6 产物完好）；已按计划 §0.4 断点机制用第二实例 `resume_from=Step7-fix` 接力完成。**教训**：Phase 1 这种大 Phase 的 dispatch prompt 要更精简，或拆成两个 sub-agent
- [ ] mock 异常构造形状（已修复，勿再踩）— `throw PSCustomObject` 会被 PowerShell 包装为 RuntimeException，自定义属性全丢 → 全部异常场景误判 network_error。修复 = 用 Add-Type C# Exception 子类（详见 `harness-fix-log.md` H-001）

## BLOCKED

（无）

## NEXT_ACTION

**立即派遣 Phase 2 sub-agent（T38 六子测试 + §12 统一计数，硬门槛，本轮最高优先级）**：

1. **重读计划 Phase 2 章节**（exec-plan-v1.11-c.md L583-793），确认规格无记忆偏差
2. **派遣 1 个 sub-agent**（用户规则：每 Phase 单一 sub-agent 串行，禁止并行；sub-agent prompt 需自包含——它看不到你的对话历史）。Phase 2 任务要点：
   - 对 6 个子测试目录（`T38-A/B/C/heartbeat/result-read/stats-items/`）各执行对应编排器 `lib/t38-orchestrator-*.ps1`（前置 fixture 场景 `t38` = 单个 404 repo，触发 review=true）
   - 每个子测试收集完整证据：`before/`、`after/`、`stdout.txt`、`stderr.txt`、`test-report.md`、`result-before/after.json`、`md-before/after.md`、`sha256-before/after.txt`、`lock-before/after.txt`；涉及文件锁的加 `lock-holder-stdout/stderr.txt`
   - **T38-stats-items 是核心硬门槛**：期望 `REVIEW_WRITE_ERROR|review 修改了 stats/items` ×1 + `RUN_STATUS|failed|review 程序事实完整性校验失败` ×1 + `SENTINEL|AFTER_STEP4` 不出现 + 无 `REVIEW_WRITE_OK|`/`COMMIT_OK|`/`RUN_STATUS|success|` + result.json/主 md SHA256 不变 + run.lock 释放
   - 六子测试统一要求：`RUN_STATUS|failed|` count = 1，`RUN_STATUS|success|` count = 0
   - 产出汇总矩阵 `.production-validation-v111-final/t38-unified-count.md`（6 行 × 5 列：success/failed/REVIEW_WRITE_ERROR/RUNTIME_ERROR/COMMIT_OK + 判定列）+ 更新 `phase-progress.json`（next_phase=Phase3）
   - **SENTINEL 期望**：T38 全部 6 个子测试 SENTINEL **不出现**；对照：T22 不出现 / T23 出现 / T39 出现（Phase 3/5 用）
3. **主 agent 独立审查**（不采信 sub-agent 转述，亲自读 stdout/计数/SHA256）：核对计划 Phase 2 的 6 个审查点；通过后更新 `task-tracker.md`（Phase 2 行 + 审查记录），再进入 Phase 3
4. **后续 Phase 顺序**：3(T22/T23) → 4(T37) → 5(T39) → 6(T43+T46) → 7(runtime-artifact) → 8(T04-PS7+T26+T18) → 9(PS5.1) → 10(Lock+ProcessKill) → 11(静态审计三合一) → 12(self-review 19 项) → 13(最终报告+commit)。每个 Phase 都是"派遣 sub-agent → 主 agent 亲读证据审查 → 更新 task-tracker → 下一 Phase"

## IMPORTANT_FACTS

**执行模式（用户规则，违反即违规）**
- 单一 sub-agent 串行执行，禁止并行、禁止 sub-agent 递归派遣；主 agent 保留编排、审查、最终核实
- 审查 = 主 agent **亲自读取证据文件**核对，不采信 sub-agent 结论转述
- 恢复不依赖会话记忆：只依据产物文件 + `phase-progress.json` + dispatch prompt 里的 `resume_from`
- 所有执行后台静默：`pwsh -NoProfile -NonInteractive -File <script> *>&1 > <output.txt>`；常驻辅助进程 `Start-Process -WindowStyle Hidden`，测试后 `Stop-Process`；**不弹前台窗口**
- 每次更新 task-tracker 后建议 mem_save 关键节点（若新 IDE 配置了同一 Engram MCP；project=github-version-monitor）

**15 条禁止事项速记（计划 §3 全文必读）**
1. 禁止修改 `SKILL-v1.11.md`（被测对象）；2. 禁止触碰生产 `.output/GitHub更新监测列表.md`（用 `GITHUB_VERSION_MONITOR_BASE` 隔离）；3. 禁止复用 v17/v18/v19/v110 旧 validation 目录产物作 PASS 证据；4. 禁止修改 `.GPT/` 上游事实源；5. 禁止输出任何 secret；6. 禁止为通过而改 SKILL；7. 禁止多 sub-agent 并行；8. 禁止预期决定 Verdict；9. 禁止 BLOCKED→PASS；10. 禁止 FAIL→BLOCKED；11. 禁止旧 PASS 当本轮 PASS；12. 禁止 harness 预创建 `.monitor/`；13. 禁止改测试逻辑掩盖失败；14. 禁止改 harness 后不重跑受影响测试（修复记录 → `harness-fix-log.md`，§0.10 协议）；15. 禁止"关键词还在"替代行为验证

**环境坑（实测踩过，勿重复）**
- git 中文路径：加 `-c core.quotepath=false`；`git diff --no-index` 有差异退出码 1 属预期，追加 `; exit 0`
- pwsh 7.6.4：`& $git ...` 数组 splatting 解析异常 → 用函数封装；`$ErrorActionPreference='Stop'` 下用 `Write-Output`+标志位，别用 `Write-Error`
- PowerShell 字符串：双引号中 `` `\$ `` 会把 `$` 吃掉留 `\`；单引号内单引号用 `''` 转义
- PS5.1：here-string 内嵌 C# 若文件是 LF 行尾会报 Unexpected token → mock 文件已转 CRLF，别改回
- `return` 会枚举展开 ICollection（WebHeaderCollection 被拆成 string 集合）→ 需要保对象时用 `Write-Output -NoEnumerate`
- Windows `ReadOnly` 属性**不阻止**文件创建/覆盖（T38-A/T22 禁用作故障构造）；`[IO.File]::Open` 打不开目录；同进程对同一文件持 `FileShare::None` 后无法再次打开 → 文件锁类故障必须独立后台进程
- T38 stats-items 边界条件：fixture 的 `stats.total` 不得恰为 999（执行前断言并记录）

**注入点行号映射（已实测验证，Phase 12 复核要用）**
| 场景 | 提取脚本行 | SKILL-v1.11.md 行 | 注入 |
|---|---|---|---|
| T38-B | step4.ps1 L17/L18 | L489/L490 | `Set-Content $tmpPath -Value '{invalid json' -Force` |
| T38-stats-items | step4.ps1 L7/L8 | L479/L480 | `$doc.stats.total = 999` |
| T39 | step5-full.ps1 L116/L117 | L636/L637 | 锁 PID 重写为 999999 |

**锁 PID 一致性机制**（计划 §0.5）：单进程编排器 `& stepN.ps1` 顺序调用天然满足 ownership 校验；独立执行单个 step 时须先把 `run.lock` 的 `pid=` 重写为编排器自身 PID（保留 `start=`）。stdout 透传已验证正常 → T37/T43 用 `run-full-pipeline.ps1` 单次执行捕获即可。

**当前判定环境**：一切测试判定只认本轮 `.production-validation-v111-final/` 下实际证据；旧报告结论仅供参考。硬门槛失败（如 T38-stats-items FAIL）→ 倾向 PRODUCTION_NOT_READY，但**仍要完成后续 Phase 保留完整证据**。
