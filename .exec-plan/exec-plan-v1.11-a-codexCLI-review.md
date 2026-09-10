# exec-plan-v1.11-a 独立审计报告（Codex CLI）

> **审计对象**: `.exec-plan/exec-plan-v1.11-a.md`（SKILL-v1.11 定向生产验证执行计划，初版）
> **审计工具**: `codex exec`（OpenAI Codex CLI v0.153.4，read-only sandbox，reasoning effort xhigh，model `new-api:my550b`）
> **审计时间**: 2026-09-09
> **事实源**:
> 1. `.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md`（上游规范，39 节）
> 2. `SKILL-v1.11.md`（被测对象）
> 3. `SKILL-v1.10.md`（对比基线）
> **审计方式**: 审计员独立读取 4 个事实源文件 + 实测 `git diff --no-index SKILL-v1.10.md SKILL-v1.11.md`；主 agent 对审计结论做了二次复核，推翻 1 项、修正 1 项引用节号（见 §5）

---

## 1. 严重问题（P1：需修订后方可执行）

### [P1-001] Self-Review 项数表述误导

| 项 | 内容 |
|---|---|
| **位置** | 计划 L203（§0.9 追踪表）、L244（§1 模块总览表）、L1935（附录 C） |
| **问题** | 三处均只写"19 项"，未标注构成。Prompt §31（L1017-1047）原文**仅固定 15 项**（编号 1-15）。计划 Phase 12 正文（L1439-1470）已正确分列"Prompt §31 固定 15 项 + 模板补充 4 项"，但三处摘要未同步，易误导执行者认为 Prompt 要求 19 项 |
| **事实源依据** | Prompt §31 L1031-1047：`1. 被测对象是否真实为 v1.11` … `15. final-status uniqueness audit 是否完成`（编号 1-15，共 15 项） |
| **建议修正** | 三处改为"15 Prompt + 4 模板 = 19 项" |

### [P1-002] "9 项辅助禁止"来源自相矛盾

| 项 | 内容 |
|---|---|
| **位置** | 计划 L1781（§8 A1 自我审查） |
| **问题** | §8 声称"枚举/数量词全部来自完整原文阅读（30 项能力 / **9 项辅助禁止** / 9 种状态 / 9 项 T26 输入 / 6 场景 / 6 子测试 / 15+4=19 项 self-review / 16 章报告）"，但 Prompt §4（L118-173）原文**只有 30 项能力清单，无任何禁止项清单**。计划自身附录 B D9（L1924）已承认"v1.11 Prompt §4 无该清单（v1.10 轮实践提炼）"，构成自相矛盾 |
| **事实源依据** | Prompt §4 L128-172：`## v1.11 保留 v1.10 的关键能力` 下仅列 30 项能力，无禁止项；计划附录 B D9 L1924 自述来源 |
| **建议修正** | §8 删除"9 项辅助禁止"，或明确标注"非 Prompt 要求，计划内部防御性检查" |

---

## 2. 中等问题（P2：不影响执行但会导致证据不完整或审查困难）

### [P2-001] 文件锁/ACL 测试的进程模型未明确

| 项 | 内容 |
|---|---|
| **位置** | 计划 Phase 2（T38-heartbeat L714、T38-A L649）、Phase 3（T22 L809）、Phase 10 |
| **问题** | 计划 §0.5（L131-133）声明"单进程编排器天然满足锁 PID 一致性"，但 T38-heartbeat 需"外部进程以 `FileShare::None` 锁住 `run.lock`"、T38-A 需让 `Set-Content $tmpPath` 失败、T22 需 ACL deny。同一进程无法对同一文件持有 `FileShare::None` 独占锁并同时尝试打开/写入，必须用**独立进程**。§0.5 的锁 PID 重写机制只解决 ownership 校验，**不解决**文件锁竞争的物理阻塞 |
| **事实源依据** | SKILL-v1.11.md L477：`$fs=[IO.File]::Open($lockPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)` — 独占锁，同进程二次打开抛 `IOException` |
| **建议修正** | 在 Phase 2/3/10 相关测试设计中显式声明"需独立进程持锁/改 ACL"，并给出 `Start-Process -WindowStyle Hidden` 启动模板 |

### [P2-002] Phase 计数口径不一致

| 项 | 内容 |
|---|---|
| **位置** | 计划 §0.1 L45、§0.9 追踪表、§1 模块总览表、附录 C L1931 |
| **问题** | §0.1 DoD 与 §0.9/§1 均称"14 个 Phase"（Phase 0-13），但 Phase 13 拆分为 13.1-13.5 五个子阶段，实质有 18 个执行单元。附录 C 以"Phase 数：14（9+，符合 L 型）"判型，统计口径不清 |
| **建议修正** | 全文统一为"14 个主 Phase（Phase 0-13），Phase 13 含 5 个子任务" |

### [P2-003] §0.2 行号基线 L487 描述不精确

| 项 | 内容 |
|---|---|
| **位置** | 计划 §0.2 L84-85（行号基线说明） |
| **问题** | 基线说明写"L487 tmp-write RUN_STATUS"，但实际 L487 是 tmp 写入**失败**后的终态输出，tmp 写入动作本身在 L481 |
| **事实源依据** | SKILL-v1.11.md L481：`$doc|ConvertTo-Json -Depth 8|Set-Content -Path $tmpPath -Encoding UTF8`（tmp 写入）；L487：`Write-Output 'RUN_STATUS\|failed\|review 写入失败，整轮终止。'`（失败终态） |
| **建议修正** | 改为"L481 tmp 写入 / L487 tmp 写入失败 RUN_STATUS" |

### [P2-004] PS5.1 双维度计数为计划自设裁决，非 Prompt 明文

| 项 | 内容 |
|---|---|
| **位置** | 计划 §6.3 L1740、Phase 13.3、附录 B D8 L1923 |
| **问题** | 计划引入"production-critical (PS7) vs compatibility (PS5.1)"双维度计数，使 PS5.1 FAIL 不阻塞 Production Gate。Prompt §20 说"PS5.1 仅做兼容性回归，不作为 production gate 主环境"，§35 说"FAIL > 0 → PRODUCTION_NOT_READY"，**两条规则字面冲突**。计划裁决合理，但属计划层面的解释性决策 |
| **事实源依据** | Prompt §20 L855-857：`PS5.1：仅做兼容性回归 / 不作为 production gate 主环境`；Prompt §35 L1135-1137：`FAIL > 0 → PRODUCTION_NOT_READY` |
| **建议修正** | 在最终报告模板（Phase 13.1 O 节）显式记录此裁决依据，避免被误读为 Prompt 原文要求 |

---

## 3. 轻微问题（P3：表述不清、冗余、可优化）

### [P3-001] §0.2 表格内代码片段转义不标准

| 项 | 内容 |
|---|---|
| **位置** | 计划 §0.2 表格第 2 行（stats/items 完整性失败 return 补齐） |
| **问题** | 单元格内 PowerShell 代码 `...整轮终止。';return};try {` 中的竖线被 Markdown 管道符转义为 `RUN_STATUS\|failed\|`，不影响阅读但非标准代码呈现 |
| **建议修正** | 用反引号包裹代码片段，或将 `|` 替换为文字"管道符" |

### [P3-003] "9 种状态"来源模糊

| 项 | 内容 |
|---|---|
| **位置** | 计划 §8 L1781 |
| **问题** | §8 将"9 种状态"列为数量词核验项，但 Prompt 仅在 §21 标题写"T18 — 9 种状态保留"，SKILL 实际 queryStatus 有 10 个值。计划未说明"9 种"具体指哪 9 种（是否含 ok、不含 http_error），仅作计数核验缺乏可操作性 |
| **事实源依据** | Prompt §21 标题：`# 22. T18 — state preservation regression`（计划正文称 9 种）；SKILL-v1.11.md L361-367 实际分支：ok / not_found / rate_limited / auth_error / forbidden / server_error / invalid_response / metadata_incomplete / network_error / http_error = 10 种 |
| **建议修正** | 删除"9 种状态"，或改为"T18 状态保留场景（Prompt 标题称 9 种，SKILL 实测 10 种 queryStatus，以 SKILL 代码为准）" |

---

## 4. 核验通过项

| 核验项 | 结果 | 证据 |
|---|---|---|
| **A. 行号准确性**（L8/L163/L241/L341/L361-367/L397-400/L404/L410/L415-418/L432/L439-447/L444/L471-517/L474/L475-510/L477/L478/L479/L480/L481/L483/L487/L489/L490/L496/L500/L506/L521-655/L522/L539-547/L591/L604/L607/L621/L626/L627/L630/L636/L637/L638/L647-648/L649/L650-653/L651/L655/L766/L768/L769） | ✅ 全部准确 | 逐条对照 SKILL-v1.11.md 实测行号，无偏移 |
| **B. diff 声明**（3 hunks，3 insertions + 2 deletions） | ✅ 完全一致 | 实测 `git diff --no-index SKILL-v1.10.md SKILL-v1.11.md`：Hunk1 L5 版本号 / Hunk2 L477 return 补齐 / Hunk3 L765 changelog 新增 |
| **C1. Prompt §4 能力清单 30 项** | ✅ 完整匹配 | 逐项对照 Prompt §4 L132-172 列表，共 30 项无增减 |
| **C2. Prompt §19-§22 无 T05-PS7** | ✅ 确认无此项 | Prompt §19-§22 原文均无 T05-PS7，仅 §20 有 T04/T05-PS5.1 |
| **C3. Prompt §25 仅要求 Step 2/4/5** | ✅ 完全一致 | Prompt §25 原文：`Step 2 / Step 4 / Step 5 三个步骤的实际 kill 点` |
| **C4. Prompt §26/§27 描述** | ✅ 匹配 | §26: return 三分类 + exactly once；§27: fatal test 全矩阵 |
| **C5. Prompt §31 Self-Review 15 项** | ✅ 计划 Phase 12 正确列出 15 项 | Prompt §31 编号 1-15 与计划 Phase 12 第 1-15 项一一对应 |
| **C6. Prompt §32 报告 A-P 16 章** | ✅ 匹配 | Prompt §32 L1061-1078 列出 A-P 共 16 章 |
| **C7. Prompt §34 Production Gate 清单** | ✅ 计划 §6.3 / Phase 13.3 完整覆盖 | 4 个计数器 + 15 项测试 PASS 要求均含 |
| **D1. T38-stats-items 注入点（L479/L480 间）可行性** | ✅ 技术可行 | `$origStats` 在 L478 固化（`$doc.stats|ConvertTo-Json -Depth 8 -Compress`），L480 重新序列化比较，注入 `$doc.stats.total=999` 必触发不等 |
| **D2. T38-B 注入点（L489/L490 间）可行性** | ✅ 技术可行 | tmp 已写入（L481），L490 读取前篡改 tmp 内容即触发 JSON 校验失败 |
| **D3. T39 注入点（L636/L637 间）可行性** | ✅ 技术可行 | `$commitSucceeded` 已置 true，篡改 lock PID 导致 ownership 校验失败 → L649 failed |
| **D4. 锁 PID 一致性机制与 SKILL 代码一致** | ✅ 完全一致 | Step 1-5 均验证 `pid=$PID`，`Release-LockSafely`（L476）同；计划 §0.5 描述准确 |
| **D5. mock contract（L341-367）访问路径** | ✅ 完全匹配 | 逐成员对照 SKILL L341-367，mock 返回形状与访问路径一致 |
| **F1. §3 禁止事项 15 条均有 Prompt 依据** | ✅ 全部可追溯 | 逐条对应 Prompt §1/§24/§29/§30/§39 开篇禁令 |
| **F2. §4 证据规则表与 Prompt §29 一致** | ✅ 完全一致 | 表格各行情形与最少留存文件完全对应 |
| **G1. §6.3 判定逻辑与 Prompt §33/§34/§35/§36 一致** | ✅ 核心规则一致 | P0/P1/FAIL/BLOCKED 阈值、三种判定条件均匹配 |

---

## 5. 主 agent 对审计结论的二次复核

审计员（codex）的以下 2 项结论经主 agent 复核后**修正/推翻**：

### 5.1 推翻：[P3-002] "附录 A §18 错标为 T46，应为 T04"

- **审计员结论**：称计划附录 A 中 §16 与 §18 均指向 T46，Prompt 实际 §16 是 T46、§18 是 T04，要求将 §18 改为 T04。
- **复核结果**：**审计员读取错误，计划正确。** 实测 Prompt 章节标题：
  - `# 16. T39 — commit success + lock release failure`（L514）
  - `# 17. T43 — full extended pipeline`（L536）
  - `# 18. T46 — .output path regression`（L576）
  - `# 19. T04 — rate_limited regression`（L602）
- 计划附录 A L1887-1890 的映射（§16→T39 / §17→T43 / §18→T46 / §19→T04）与 Prompt 原文完全一致。**此项不成立，无需修订。**

### 5.2 修正引用节号：[P1-001] 中"Prompt §30"应为"Prompt §31"

- 审计员写"Prompt §30（Self-Review）原文仅固定 15 项"。实测 Prompt §30 是 `Test Harness Integrity`（L980），Self-Review 在 **Prompt §31**（L1017）。结论不变，引用节号已在本报告更正。

---

## 6. 未能核验项

| 项 | 原因 |
|---|---|
| T22 ACL 方案在目标 Windows 环境的实际可写性 | 需在真实测试机验证 `Set-Acl` 权限变更是否生效、是否需要管理员权限，当前无环境无法实测 |
| T38-A 文件锁方案在独立进程下的物理可行性 | 需实测 `Start-Process -WindowStyle Hidden` 启动的锁持有进程能否在测试进程释放前持有锁 |
| PS5.1 环境是否真实存在于执行机器 | 计划假设 PS5.1 可用，但未在环境上下文中确认；若缺失会导致 Phase 9 BLOCKED |
| `.GPT/` 与 `.exec-plan/` 的 git 追踪状态 | 计划 D10 声称两文件 untracked，需 `git status` 实测确认 |

---

## 7. 总体结论

**该计划需要修订后方可执行。** 但所有问题均为**表述/口径层面**，核心逻辑无缺陷：行号引用、diff 分析、注入设计、判定规则、Prompt 39 节覆盖度全部与事实源一致。

### 必须修订（P1，2 项）

1. **Self-Review 项数表述统一**：§0.9、§1、附录 C 必须标注"15 Prompt + 4 模板"，消除"Prompt 要求 19 项"的误导。
2. **删除或标注"9 项辅助禁止"**：§8 自我审查不得声称其来自"完整原文阅读"。

### 建议修订（P2，4 项）

3. **文件锁/ACL 测试进程模型明确化**：Phase 2/3/10 显式声明"需独立进程持锁/改 ACL"，给出 `Start-Process` 启动模板。
4. **Phase 计数口径统一**：全文统一为"14 个主 Phase（Phase 0-13），Phase 13 含 5 子任务"。
5. **§0.2 行号基线 L487 描述修正**为"L481 tmp 写入 / L487 tmp 写入失败 RUN_STATUS"。
6. **最终报告模板增加 PS5.1 双维度计数裁决声明**（O 节）。

### 可选修订（P3，2 项）

7. §0.2 表格代码片段转义规范化。
8. "9 种状态"改为"Prompt 标题称 9 种，SKILL 实测 10 种 queryStatus，以 SKILL 代码为准"。

### 不成立项（0 项需修订）

- 附录 A §16/§18 映射（审计员误读，计划正确）。

---

## 附录：审计执行元信息

| 项 | 值 |
|---|---|
| 工具 | `codex exec`（OpenAI Codex CLI v0.153.4） |
| 沙箱 | `read-only` |
| 审批策略 | `never` |
| reasoning effort | `xhigh` |
| model | `new-api:my550b`（provider: cherry-gateway） |
| session id | `01a0848d-f0e8-76a1-997f-9922a5a4e708` |
| 审计员读取的事实源 | 执行计划 + Prompt + SKILL-v1.11.md + SKILL-v1.10.md |
| 审计员实测命令 | `git diff --no-index SKILL-v1.10.md SKILL-v1.11.md` |
| 主 agent 复核项 | 推翻 1 项（P3-002）、修正引用 1 项（P1-001 节号） |
