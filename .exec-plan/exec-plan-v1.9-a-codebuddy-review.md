# 执行计划 exec-plan-v1.9-a 独立审计报告（codebuddy-review）

> **审计对象**: `d:\AI\Workspace\automatic\github-version-monitor\.exec-plan\exec-plan-v1.9-a.md`（SKILL-v1.9 定向最终验证 — 执行计划）
> **审计日期**: 2026-09-08
> **审计执行**: CodeBuddy 独立审计（三轮事实核实：环境/文件、Prompt 事实源、被测 SKILL 代码）
> **审计性质**: 只读审计，未修改被审计文件与被测对象

---

## 1. 审计范围与方法

对计划本身（1206 行）做三维审计：

1. 计划 ↔ 唯一事实源（`.GPT/Production Validation Prompt — SKILL-v1.9 Targeted Final Validation.md`，1097+ 行）
2. 计划 ↔ 被测对象实际 contract（`SKILL-v1.9.md` 关键代码段）
3. 计划 ↔ 执行环境与历史基线（PS 环境、git 状态、v1.8 验证报告）

全部结论基于审计时点的实际读取/命令核验，非转述。

**环境核实快照（审计时点）**:

| 项 | 核实结果 |
|---|---|
| `.GPT/Production Validation Prompt — SKILL-v1.9 Targeted Final Validation.md` | 存在 |
| `SKILL-v1.8.md` / `SKILL-v1.9.md` / `.output/GitHub更新监测列表.md` | 均存在 |
| PowerShell 7 | 7.6.4 可用 |
| PowerShell 5.1 | 存在 |
| git 跟踪状态 | `SKILL-v1.9.md` untracked；`SKILL-v1.8.md` tracked |
| `.production-validation-v19-final` 的 .gitignore 状态 | 未被忽略（check-ignore exit 1） |
| 生产 `.output/GitHub更新监测列表.md` SHA256 | `7396981A2FBF019D3DAD0C906A2B6E9C05D36C4746F35E0C0063FD1F3EB19CD3`（与 v1.8 报告 B 节基线一致） |
| 旧验证目录 v17-final / v18-final | 均仍存在（Clean-Room 禁复用条款有现实意义） |

---

## 2. 核实通过项（直接核实）

| # | 项 | 证据 |
|---|---|---|
| P-1 | 计划引用的 Prompt 节号（第 1、13-20、22-26 节）全部与 Prompt 实际章节对应 | Prompt 标题结构逐节比对 |
| P-2 | T22/T23/T38 验证项与 SKILL-v1.9 实际修复代码逐项匹配：tmp 写失败 → 清理 + 锁释放 + `RUN_STATUS\|failed\|`（SKILL L586-604）；Move-Item 失败 → 清理 tmp（L621-628）；ownership 失败 → `RUNTIME_ERROR\|` + failed（L643-645）；`REVIEW_WRITE_ERROR\|` 分支含清理 + 释放（L479-503） | SKILL 原文比对 |
| P-3 | 7 个硬门槛测试（T22/T23/T37/T38/T39/T43/T46）与 Prompt 测试节一一对应，无遗漏无添加 | Prompt #5-#12 |
| P-4 | 状态机 10 项、schema 9 输入、lock 4 项、静态检查 7 个关键操作，均与 Prompt #14-#17 一致 | Prompt L563-701 |
| P-5 | 报告章节 A-N、计数规则（PASS+FAIL+BLOCKED=Executed）、gate 三态判定、最终输出模板与 Prompt #22-#26 逐字一致 | Prompt L878-1107 |
| P-6 | 环境前提成立：PS7 7.6.4、PS5.1 存在、3 个被测文件均存在；生产状态文件指纹与 v1.8 报告基线一致 | 本轮 Test-Path / $PSVersionTable / Get-FileHash |
| P-7 | Invariant 表 7 条与 Prompt #18（Invariant 1-7）对应；invariant 4 与 SKILL L643-650 实现一致 | 比对 |
| P-8 | 中断接续（phase-progress.json + resume_from）与禁止事项（8 条）内部自洽 | 计划 0.3、3.3 |

---

## 3. 发现项

### 高严重性

**H1 — T39 分段脚本设计与 `-File` 独立进程模式冲突，invariant 4 测试失去区分度**

计划 Phase 4 将 Step 5 拆为 `step5-commit.ps1` + `step5-lockrelease.ps1`（计划 L232-233），而 6.1 强制所有脚本经 `pwsh -File` 执行（计划 L1068）= 每脚本独立进程。SKILL Step 5 中 `$commitSucceeded`（L617/623）与 `$lockReleased`（L634/640）是**同进程局部变量**，跨进程无法传递；`$md`/`$items`/`$rows2` 同理。

后果：独立进程运行 `step5-lockrelease.ps1` 时，无论 commit 真值如何，`$commitSucceeded` 为未定义 → 终态恒为 failed → 测试通过与否**不再依赖 invariant 4 的语义**（假 PASS 风险）。且新进程 `$PID` 天然不等于锁内 PID，构造步骤 3 “修改 PID 为 999999”（计划 L458）实际冗余，掩盖了跨进程问题。计划未定义同进程 dot-source / harness 注入等桥接机制。v1.8 报告 T39-v18 曾 PASS，但其证据含 `lock-after-modify.txt`，方法未沉淀入本计划。

### 中严重性

**M1 — PS5.1 FAIL 计数口径矛盾未消解（继承自 Prompt，但计划是执行规范，应给出裁决规则）**

Prompt #13（L549-559）：“PS5.1 失败 → 记录 compatibility FAIL，但不自动阻塞 PS7 production gate”；Prompt #24（L967-990）：“FAIL > 0 → 必须 PRODUCTION_NOT_READY”。若 PS5.1 FAIL 计入 #23 的 FAIL 总数，两条必然冲突；若不计入，计划未定义 "production-critical FAIL" 与 "compatibility FAIL" 的区分维度。计划 7 节（L712）与 8 节（L1154）照搬了两条款但未给出统一裁决规则。BLOCKED 同理（PS5.1 BLOCKED vs PRODUCTION_READY 要求 BLOCKED=0）。

**M2 — fixture 隔离与 mock 重定向机制未定义**

- SKILL 5 个 step 均支持 `GITHUB_VERSION_MONITOR_BASE` 环境变量重定向 base 目录（SKILL L162/240/431/473/518，直接核实），这是 fixture 隔离的技术前提，但计划全文未提及该机制，未规定各 step 从哪个目录、以何种 base 运行；
- API URL 硬编码 `https://api.github.com`（SKILL L340/L478），无 base 覆盖机制。T02/T04/T05 的 mock listener 需网络层重定向（如 hosts 劫持，需管理员权限 + TLS 证书处理），计划 Phase 1 仅写 “mock-listener.ps1 — HTTP 模拟监听器”，机制缺失；hosts 属系统级变更，计划无变更/恢复要求；
- T46 “检查根目录是否出现同名状态文件”（计划 L565）未写明运行目录，若在生产根执行即违反硬约束 2。

**M3 — v1.8 已记录的工具缺陷未纳入计划**

v1.8 报告 N.2（L480）明确记录 `run-full-pipeline.ps1` 在 `-File` 模式下 stdout 未正确透传。计划 T37/T43 恰恰依赖该工具产出完整成功链 stdout 证据（计划 L400/L519），且 6.1 强制 `-File` 模式。计划未列入应对（如逐 step 独立执行后拼接、或改用调用运算符捕获）。

**M4 — `state.sha256` 采集后无任何消费者，硬约束 2 缺独立复核**

Phase 0 对生产 `.output` 文件计算 SHA256（计划 L131-134），但 Phase 1-9 与 self-review 8 项检查（计划 L746-755）均无 “生产状态文件未被修改” 的复核步骤。硬约束 2（L1085）因此只有事前禁止、无事中/事后独立验证。

**M5 — 被测对象未纳入 git + Phase 9 commit 范围未定义**

直接核实：`SKILL-v1.9.md` 当前为 git untracked（`git ls-files` 无输出）。Prompt #2 要求 “从当前 Git repository 获取 SKILL-v1.9.md”、第 10 节最终原则 “Git repository = 唯一事实源”，与被测文件不在版本库中存在张力。同时 `.production-validation-v19-final/` 未被 .gitignore 覆盖（check-ignore exit 1），计划 Phase 9 Step 7（L902-911）未定义 commit 的文件范围（是否含 SKILL-v1.9.md、证据目录、报告）。

**M6 — T18 "6 种 error 状态" 口径无事实源出处，两个状态连续第三轮无测试安排**

Prompt #16 仅写 "T18 state preservation"（L652），未定义数量。SKILL-v1.9 非 ok 状态实为 **8 种**（not_found / rate_limited / server_error / network_error / invalid_response / metadata_incomplete / auth_error / forbidden，SKILL L132-138 直接核实）。计划的 "6 种"（计划 L610、L1180）未说明是哪 6 种；v1.8 报告 N.4（L482）明示 `metadata_incomplete` 与 `invalid_response` 未测——v1.9 计划 6.1 表仍无这两个状态的专项构造。

**M7 — Prompt #2 ".monitor/ 必须在测试目录重新生成" 未纳入 Phase 0**

Prompt L112-118 明确要求运行态 `.monitor/` 在测试目录重新生成；计划 Phase 0 目录树（L97-125）无 `.monitor/`，处理逻辑亦未提。

### 低严重性

| # | 发现 | 证据 |
|---|---|---|
| L1 | 计划称 "27 项能力"（L252/L1164），Phase 1 Step 2 清单实际为 **28 行**（逐行点数），Prompt 原文同为 28 行且未标数量——计数错误源自计划 | 计划 L167-201 |
| L2 | Phase 8 输出 `.selfreview/selfreview-v19-20260909-014524.md`（L757）基准目录歧义（项目根 or 测试目录），Phase 0 目录树无对应条目；Prompt #21 同样未指明（继承性歧义） | 计划 L757、Prompt L873 |
| L3 | T37 主 agent 审查点将 `REVIEW_WRITE_OK\|` 列为必查链（L438），与验证项 “（有 review 时）”（L408）条件化矛盾——fixture 未触发 review 时审查点无法满足 | 计划 L408 vs L438 |
| L4 | T38/T22 构造选项 “目录设为只读” 在 Windows 上 `ReadOnly` 属性**不阻止**创建文件，需 ACL deny 或文件锁；Prompt 原文即建议 read-only directory，计划照搬未做平台澄清 | 计划 L271/L308、Prompt L284 |
| L5 | 6.3 lock-ownership 期望写 `RUNTIME_ERROR`（L644）缺竖线（SKILL 实际输出带竖线，T39 处计划写对了）；lock-stale-dead 期望仅写 “takeover 成功”（L646），未指定判定标记（v1.8 以 `BACKUP_OK\|` 判定） | 计划 L644/646 |
| L6 | v1.8 报告 N.3 PS5.1 解析限制（测试脚本需多行展开）未纳入计划背景；v1.9 提取脚本为单行紧凑风格，PS5.1 下存在解析风险 | v1.8 报告 L481 |
| L7 | 计划 0.1 "3 个 P2" 采用 Prompt 口径；v1.8 报告正式计数 P2=2（L.2，L428）、K.2 列 3 个 P2 缺陷且 T22-v18 测试结论为 PASS（G 表 L263）——基线转述与正式报告存在口径差，计划未注明 | v1.8 报告 L428 / L381-403 / L263 |
| L8 | self-review 第 4 项 “提取脚本 SHA256 与原文一致”（L750）无核验基准——Phase 1 未要求生成提取清单（源行号范围 ↔ 提取文件 SHA256） | 计划 L750 vs L242-250 |
| L9 | "完整 Step 1→6"（L400/L519）与提取脚本止于 step5-full（L237）范围差未说明；SKILL 步骤 6 为 agent 汇报模板、无代码块（SKILL L655 直接核实），实际无碍但应显式说明，防 sub-agent 自行编造 step6 | 计划 L237/L400 |
| L10 | Prompt #8 要求 T22/T23/T38 保存 main md / **result.json** / **tmp** 三者 SHA256（Prompt L354-360）；计划 T22/T23 证据清单未列 result.json before/after 证据，sha256-before/after.txt 内容范围未定义 | 计划 L323-336 / L358-371 vs Prompt L342-367 |
| L11 | T39 证据清单无 `lock-after-modify.txt`（v1.8 同测试有此项，v1.8 报告 L345） | 计划 L478-488 |

---

## 4. 审计结论

- **结构与忠实度**：计划的 Phase 划分、测试集、验证项、报告模板、gate 逻辑与唯一事实源 Prompt 高度一致（P-1 ~ P-8），主干可执行。
- **关键风险**：H1（T39 分段 + 独立进程）会实质性削弱本轮唯一新增 invariant 测试的有效性，属**执行前必须解决的测试设计缺陷**；M1/M2/M3 决定 verdict 口径与两项硬门槛测试（T37/T43）证据链能否成立；M4-M7 为验证闭环完整性缺口。
- **口径提示**：M1 不消解的情况下，PS5.1 结果可能同时满足 “compatibility FAIL 不阻塞” 与 "FAIL>0 → NOT_READY" 两条规则，verdict 无法唯一确定。

**修订建议优先级**：

| 优先级 | 项 | 动作 |
|---|---|---|
| 执行前必须 | H1 | 明确 T39 两段脚本的同进程执行机制（dot-source / harness 注入 `$commitSucceeded`） |
| 执行前必须 | M1 | 定义 FAIL/BLOCKED 计数口径（production-critical 与 compatibility 分维） |
| 执行前必须 | M2 | 写入 `GITHUB_VERSION_MONITOR_BASE` 隔离机制与 mock 重定向方案；明确 T46 运行目录 |
| 执行前建议 | M3/M7 | Phase 0 补 `.monitor/`；为 T37/T43 制定 pipeline 工具 stdout 对策 |
| 执行中处理 | M4/M5/M6 + L1-L11 | 由 sub-agent 按 SKILL 实际 contract 处理，或修订计划文本 |
