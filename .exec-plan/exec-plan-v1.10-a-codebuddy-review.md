# exec-plan-v1.10-a 独立审计报告

> **审计对象**: `.exec-plan/exec-plan-v1.10-a.md`（v1.10-a 初版执行计划）
> **审计依据**: `.GPT/Production Validation Prompt — SKILL-v1.10 Targeted Validation.md`（唯一事实源）
> **交叉核实对象**: `SKILL-v1.10.md`、`SKILL-v1.9.md`
> **审计日期**: 2026-09-09
> **审计方法**: 逐项直接核实（read_file + search_content 交叉确认行号；不采信计划自述行号）
> **审计人**: CodeBuddy（主代理）

---

## 1. 审计方法说明

本次审计遵循以下原则：

1. **行号直接核实**：计划引用的所有 SKILL 行号均通过 `search_content`（ripgrep）在 `SKILL-v1.10.md` 原文中逐一定位确认，不采信计划自述。
2. **diff 交叉核实**：v1.9→v1.10 的 diff 分析通过同时读取 `SKILL-v1.9.md` 和 `SKILL-v1.10.md` 对应行交叉确认。
3. **工具行为差异教训**：read_file 对含超长行（单行 >2000 字符）的文件存在行号偏移问题，审计中以 search_content 的行号为准。此偏差在 Step 4 区域（L475-L510 超长行密集）尤为明显。
4. **枚举完整读取**：状态机表格、能力清单、禁止项等枚举类判断均读取完整原文表格后核实。

---

## 2. 逐项核实结果

### 2.1 Prompt 逐节覆盖（附录 A 对照表核实）

逐节核对 Prompt §0-§27 与计划附录 A 的映射，**27 个章节全部有对应 Phase 覆盖**，映射关系正确。未发现遗漏的 Prompt 章节。

**覆盖准确性确认**：
- Prompt §5（T38 核心 P1）→ Phase 2 ✓
- Prompt §6（T38 多异常分支）→ Phase 2（扩展为 6 个子测试）✓
- Prompt §19（Runtime Error Contract 静态审计）→ Phase 10 ✓
- Prompt §20（Final Invariant I1-I7）→ Phase 10 ✓
- Prompt §22（Self-Review 12 项）→ Phase 11（扩展为 12+4=16 项）✓
- Prompt §25（Production Gate 三档判定）→ Phase 12 + §6.3 ✓

### 2.2 SKILL-v1.10.md 行号核实（核心审计项）

以下为计划引用行号与 `SKILL-v1.10.md` 实际行号（search_content 确认）的逐项对比：

| 引用位置 | 计划引用行号 | 实际行号（search_content） | 偏差 | 判定 |
|---|---|---|---|---|
| constraint #13（§0.1） | L81 | L81 | 0 | ✓ |
| heartbeat 失败（§0.2 表格） | L476 | L477 | -1 | ⚠ P2 |
| result.json 读取失败（§0.2 表格） | L477 | L478 | -1 | ⚠ P2 |
| stats/items 完整性失败（§0.2 表格） | L479 | L480 | -1 | ⚠ P2 |
| review tmp 写入失败（§0.2 表格） | L486 | L487（RUN_STATUS 行） | -1 | ⚠ P2 |
| review JSON 校验失败（§0.2 表格） | L495 | L496（RUN_STATUS 行） | -1 | ⚠ P2 |
| review 原子替换失败（§0.2 表格） | L505 | L506（RUN_STATUS 行） | -1 | ⚠ P2 |
| heartbeat 失败（Phase 1 表格） | L476 | L477 | -1 | ⚠ P2 |
| result.json 读取失败（Phase 1 表格） | L477 | L478 | -1 | ⚠ P2 |
| stats/items 完整性失败（Phase 1 表格） | L479 | L480 | -1 | ⚠ P2 |
| review tmp 写入失败（Phase 1 表格） | L487 | L487 | 0 | ✓ |
| review JSON 校验失败（Phase 1 表格） | L496 | L496 | 0 | ✓ |
| review 原子替换失败（Phase 1 表格） | L506 | L506 | 0 | ✓ |
| T39 注入点 L632 描述 | "if/else 块结束" | L632 = try/catch 结束（`    }`） | 描述错误 | ✗ P1 |
| T39 注入点 L633 描述 | "`# 释放锁前确认 ownership`" | L633 = `} else {` | 描述错误 | ✗ P1 |
| T39 注入点正确位置 | 未标注 | L636（if/else 结束 `}`）与 L637（`# 释放锁前确认 ownership`）之间 | — | ✗ P1 |
| `$commitSucceeded`（Phase 1 Step 6） | L617/L623 | L621（定义）/L627（赋值 true） | -4 | ⚠ P2 |
| `$lockReleased`（Phase 1 Step 6） | L634/L640 | L638（定义）/L644（赋值 true） | -4/-4 | ⚠ P2 |
| T39 前置变量 `$conclusionText` 等（Phase 1 Step 6） | L535-543 | L539-547 | -4 | ⚠ P2 |
| GITHUB_VERSION_MONITOR_BASE（§0.5） | L156/L238/L429/L473/L521 | L163/L241/L432/L474/L522 | -7/-3/-3/-1/-1 | ⚠ P3 |
| API URL 硬编码（§0.5） | L338/L478 | L341（Step2）/L479（Step4 foreach 内） | -3/+1 | ⚠ P3 |
| mock contract 访问路径行号（Step 7.1） | L339/L344-346/L347-348/L359/L358/L360/L361/L362/L363/L364 | L342/L347-349/L350-351/L362/L361/L363/L364/L365/L366/L367 | -3 系统性 | ⚠ P2 |
| Get-ResponseHeaderValue（Phase 8） | L324-328 | L324-330 | 0（范围微扩） | ✓ |

**行号偏差根因分析**：

§0.2 表格的 6 项全部偏差 -1。经交叉核实 `SKILL-v1.9.md`，确认这些行号实际对应 v1.9 的行号（v1.9 L476=heartbeat, L477=result.json 读取, L479=stats/items），但表格标题标注为"SKILL-v1.10 行号"。v1.10 在 result.json 读取处新增 try/catch 导致后续行整体 +1，计划未同步更新行号。

Phase 1 表格前 3 项同样偏差 -1（引用 v1.9 行号），后 3 项正确（L487/L496/L506 与 v1.10 实际一致）。

T39 相关行号（$commitSucceeded/$lockReleased/前置变量）偏差 -4，推测基于更早版本行号或推算误差。

### 2.3 v1.9 → v1.10 Diff 分析核实

通过同时读取 `SKILL-v1.9.md` 和 `SKILL-v1.10.md` 的 Step 4 区域，交叉确认计划的 diff 分析：

| 路径 | v1.9 实际行为（行号） | v1.10 实际行为（行号） | 计划描述 | 判定 |
|---|---|---|---|---|
| heartbeat 失败 | L476: `RUNTIME_ERROR` + `return`（**无** `RUN_STATUS\|failed\|`） | L477: `RUNTIME_ERROR` + `RUN_STATUS\|failed\|` + `return` | "新增 RUN_STATUS\|failed\|" | ✓ |
| result.json 读取 | L477: `$doc=Get-Content $resultPath -Raw\|ConvertFrom-Json`（**裸读取，无 try/catch**） | L478: `try { $doc=Get-Content... } catch { lock release + RUN_STATUS\|failed\| + return }` | "v1.9 无 try/catch，v1.10 新增 try/catch" | ✓ |
| stats/items 完整性 | L479: `...;Release-LockSafely;return`（**有 return**） | L480: `...;RUN_STATUS\|failed\|...`（**无 return**，执行落入后续 try 块） | "v1.9 有 return，v1.10 移除 return 并新增 RUN_STATUS\|failed\|" | ✓ |
| review tmp 写入失败 | L484: `REVIEW_WRITE_ERROR` + `return`（**无** `RUN_STATUS\|failed\|`） | L487: `REVIEW_WRITE_ERROR` + `RUN_STATUS\|failed\|` + `return` | "新增 RUN_STATUS\|failed\|" | ✓ |
| review JSON 校验失败 | v1.9: `REVIEW_WRITE_ERROR` + `return`（**无** `RUN_STATUS\|failed\|`） | L496: `REVIEW_WRITE_ERROR` + `RUN_STATUS\|failed\|` + `return` | "新增 RUN_STATUS\|failed\|" | ✓ |
| review 原子替换失败 | v1.9: `REVIEW_WRITE_ERROR` + `return`（**无** `RUN_STATUS\|failed\|`） | L506: `REVIEW_WRITE_ERROR` + `RUN_STATUS\|failed\|` + `return` | "新增 RUN_STATUS\|failed\|" | ✓ |

**Diff 分析结论**：计划对 v1.9→v1.10 的 6 条路径变化分析**方向全部正确**。v1.9 的 Step 4 中完全没有 `RUN_STATUS|failed|` 输出（search_content 在 v1.9 中搜索 `RUN_STATUS|failed|` + heartbeat/review 关键词返回 0 匹配），v1.10 为所有 6 条不可恢复错误路径新增了 `RUN_STATUS|failed|`。

**L479/L480 stats/items return 移除发现**：已直接核实。v1.9 L479 确实有 `Release-LockSafely;return`，v1.10 L480 移除了 `return`，输出 `RUN_STATUS|failed|` 后执行落入 L481 `try { $doc|ConvertTo-Json|Set-Content... }` 块。计划对此不一致性的发现是**正确的**，T38-stats-items 子测试的设计依据成立。

### 2.4 技术可行性评估

#### 2.4.1 T39 同进程 harness（P1 发现）

计划 Phase 1 Step 6 设计 T39 harness，注入点描述为"SKILL L632（`}` — if/else 块结束）与 L633（`# 释放锁前确认 ownership`）之间"。

**直接核实结果**：
- L632 实际内容：`    }`（4 空格缩进，try/catch 块结束符）
- L633 实际内容：`} else {`（if/else 结构的 else 分支开始）
- L636 实际内容：`}`（if/else 块整体结束）
- L637 实际内容：`# 释放锁前确认 ownership：锁内 PID 必须等于当前进程 PID`

**问题**：
1. L632 被描述为"if/else 块结束"，实际是 **try/catch 块结束**。if/else 块结束在 L636。
2. L633 被描述为"`# 释放锁前确认 ownership`"，实际是 `} else {`。`# 释放锁前确认 ownership` 在 L637。
3. 计划声称"此切分点在 try/catch 块外，技术干净"，但 L632/L633 之间位于 **if 块内部**（校验通过分支），不是 if/else 块外。

**正确注入点**：L636（if/else 块结束 `}`）与 L637（`# 释放锁前确认 ownership`）之间。此处才是 if/else 完全结束后、锁释放逻辑开始前的干净切分点。

**影响评估**：如果 sub-agent 按计划的错误描述在 L632/L633 之间注入，注入代码会落入 if 块内（校验通过分支），语法上可行（缩进正确时），但语义上不如 L636/L637 干净——Move-Item 失败时注入代码仍会执行（在 catch 之后）。这不会破坏 T39 目标场景验证（Move-Item 成功时注入代码正确执行），但存在误导 sub-agent 的风险。

#### 2.4.2 T38-B harness 注入点（P2 发现）

计划 Phase 2 T38-B 说"在 L480（Set-Content）与 L489（Get-Content $tmpPath）之间注入"。

**直接核实**：
- Set-Content 实际在 L481（`$doc|ConvertTo-Json -Depth 8|Set-Content -Path $tmpPath -Encoding UTF8`），计划写 L480 偏差 -1
- Get-Content 实际在 L489（`try { $check=Get-Content $tmpPath -Raw|ConvertFrom-Json } catch {...}`），计划写 L489 正确
- L481-L488 之间包含 try/catch 块（tmp 写入 try + catch 处理）

计划说"注入点在 try/catch 块外，技术干净"。实际注入点应为 L488（第一个 try/catch 结束 `}`）之后、L489（第二个 try 开始）之间。计划描述的"L480 与 L489 之间"范围过宽，未精确指明在 L488/L489 之间。意图正确但行号不精确。

#### 2.4.3 T38-stats-items harness 注入点（P2 发现）

计划 Phase 2 T38-stats-items 说"注入点：SKILL L478（foreach 循环结束后）与 L479（if 校验）之间"。

**直接核实**：
- v1.10 中 foreach 在 L479，stats/items 校验在 L480。计划写 L478/L479 对应的是 **v1.9 行号**（v1.9 L478=foreach, L479=if 校验），标注为 v1.10 但实际偏差 -1。
- v1.10 正确行号：L479（foreach 结束）与 L480（if 校验）之间

注入逻辑正确（在 foreach 后、if 校验前注入 `$doc.stats.total = 999`），仅行号偏差 -1。

#### 2.4.4 T38-A 验证项与构造方法矛盾（P2 发现）

计划 T38-A 提供两种构造方法：
- 方法一：预创建 result.review.tmp + `[System.IO.File]::Open()` 独占锁定（FileShare::None）
- 方法二：ACL deny CreateFiles

验证项包含"tmp cleaned — result.review.tmp 不残留"。

**矛盾分析**：
- 方法一（文件锁）：外部进程持有独占锁，Step 4 catch 块的 `Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue`（L483）会因文件被锁定而失败（SilentlyContinue 静默吞错），result.review.tmp **会残留**直到外部进程终止。验证项"tmp cleaned"与文件锁方案矛盾。
- 方法二（ACL）：result.review.tmp 可能从未被创建（Set-Content 被 ACL 阻止），tmp 不存在，"cleaned"自然成立。验证项与 ACL 方案不矛盾。

**建议**：计划应区分两种构造方法的验证项，或将"tmp cleaned"改为"tmp 按 contract 清理（catch 块执行了 Remove-Item，无论是否成功）"，并补充"外部进程终止后确认 tmp 已删除"。

#### 2.4.5 ACL / 文件锁 / ReadOnly 证伪（值得肯定）

计划正确排除了以下不可行方案：
- Windows ReadOnly 属性不阻止文件创建/覆盖（T22/T38-A 均排除）✓
- `[System.IO.File]::Open()` 不能打开目录（T22 排除目录文件锁方案）✓
- ACL deny CreateFiles 仅影响新文件创建，不影响已有文件打开（heartbeat 锁刷新不受影响）✓

ACL 恢复步骤完整（T22/T38-A 各 5 步：记录 → 施加 → 执行 → 还原 → 验证）✓

### 2.5 证据规则核实

| 审计项 | 计划覆盖 | 判定 |
|---|---|---|
| 每项执行：stdout/stderr/test-report | §4 证据规则表 + 每 Phase 证据要求 | ✓ |
| 涉及文件变更：before/after + sha256 | §4 + T38/T22/T23 证据要求含 sha256-before/after | ✓ |
| 涉及锁/状态：before/after 快照 | §4 + 每 Phase 含 lock-before/after | ✓ |
| 涉及外部调用：实际响应 + header + 请求计数 | §4 + T04 证据要求含 HTTP status/header/request count | ✓ |
| 涉及 ACL：变更前快照 + 还原验证 | §4 + T22/T38-A ACL 恢复步骤含 acl-before.xml | ✓ |
| 禁止保存 GITHUB_TOKEN/Authorization/Cookie/secrets | §3 第 5 条 + §4 | ✓ |
| sha256-before/after 覆盖 main md + result.json + tmp 三者 | T38/T22/T23 证据要求明确"含三者 SHA256" | ✓ |

### 2.6 判定逻辑核实

| 审计项 | 计划处理 | 判定 |
|---|---|---|
| PRODUCTION_READY 四零 + 硬门槛全 PASS | §6.3 + Phase 12 §12.3 | ✓ |
| PRODUCTION_NOT_READY 条件 | §6.3 | ✓ |
| PRODUCTION_BLOCKED 条件 | §6.3 | ✓ |
| PS5.1 FAIL 不阻塞 PS7 gate（双维度计数） | §6.3 判定规则 1 | ✓ |
| FAIL 不得改写 BLOCKED | §3 第 10 条 + §6.3 判定规则 2 | ✓ |
| BLOCKED 不得改写 PASS | §3 第 9 条 + §6.3 判定规则 2 | ✓ |
| 守恒式 EXECUTED = PASS + FAIL + BLOCKED | §6.2 + Phase 12 §12.2 | ✓ |
| T38 扩展为 6 子测试后的 PASS 判定 | Phase 12 §12.3"T38 = PASS（含全部 6 个子测试）" | ✓ |

### 2.7 内部一致性核实

#### 2.7.1 Phase 1 输出清单与 Phase 2 消费关系（P2 发现）

计划 Phase 1 输出清单列出：
- `lib/step5-t39-harness.ps1`（T39 harness）

但 Phase 2 的 T38-B 和 T38-stats-items 也需要同进程 harness（计划在 Phase 2 描述了"提取 Step 4 代码，在 L480/L489 之间注入"和"在 L478/L479 之间注入"），却**未在 Phase 1 输出清单中列出**对应的 harness 脚本文件。

Phase 2 的输入参数列为 `lib/step4.ps1`（提取的 Step 4 代码），但未包含 T38-B harness 和 T38-stats-items harness。这两个 harness 在哪个 Phase 创建、由谁创建，计划未明确。

**建议**：在 Phase 1 输出清单中补充 `lib/step4-t38b-harness.ps1` 和 `lib/step4-t38-stats-items-harness.ps1`，或在 Phase 2 处理逻辑开头明确增加"创建 harness"步骤。

#### 2.7.2 T05-PS7 覆盖缺口（P3 发现）

Prompt §26 最终执行摘要模板包含 `T05-PS7:` 和 `T05-PS5.1:` 两项。

计划 Phase 7 安排了 T04-PS7（rate_limited），Phase 8 安排了 T04-PS5.1 和 T05-PS5.1（forbidden-PS5.1），但**未明确安排 T05-PS7**（403+remaining>0→forbidden 在 PS7 下的回归）。

Phase 12 §12.4 和 §6.4 的执行摘要模板包含 T05-PS7，但计划未在 Phase 7/8 中为其安排具体测试。如果 T05-PS7 未执行，最终报告的 T05-PS7 项将无值可填。

**建议**：在 Phase 7 中补充 T05-PS7 测试（403+remaining>0→forbidden，PS7），或明确声明"T05-PS7 由 T18 的 forbidden 状态测试覆盖"（若如此设计）。

#### 2.7.3 Phase 0 目录树多余目录（P3 发现）

Phase 0 目录树包含 T02/T08/T14/T15/T16/T17/T19 等子目录，但 Prompt 中未定义这些测试。这些目录可能是从旧版本计划复制遗留。

**影响**：空目录不影响执行，但违反 Clean-Room 最小化原则，且可能误导 sub-agent 认为需要执行这些测试。

**建议**：移除 Prompt 未定义的测试目录，或在目录树注释中标注"预留/不使用"。

### 2.8 值得肯定的设计

| 编号 | 设计决策 | 评价 |
|---|---|---|
| D1 | T38 从 3 个扩展到 6 个子测试 | 有 Prompt §5（"不要只测试 Set-Content"）和 §19（搜索所有 return）的明确依据。heartbeat/result-read/stats-items 是 v1.10 新增或修改的路径，独立验证合理。✓ |
| D2 | L479 stats/items return 移除发现 | 经直接核实确认正确（v1.9 L479 有 return，v1.10 L480 移除）。T38-stats-items 子测试专门验证此落入行为，设计精准。✓ |
| D3 | 同进程 harness 用于 T39/T38-B/T38-stats-items | `-File` 模式下跨进程无法传递局部变量，dot-source 无法实现注入点暂停。harness 内联复制 + 精确注入点是唯一可行方案。技术判断正确。✓ |
| D4 | selfreview 文件名沿用 `selfreview-v19.md` | Prompt §22 字面指定此名称。按 §7.3 口径规则（保持上游字面格式 + 附注补充），处理正确。✓ |
| — | 独立性原则（§0.6） | 切断旧报告继承链（v1.8→v1.9→v1.10 的链式继承风险），要求旧结论只作信息参考、本轮独立验证。✓ |
| — | stdout 透传独立验证 | Phase 1 独立验证 `run-full-pipeline.ps1` 的 stdout 行为，不依赖旧报告声明。符合 §0.6 独立性原则。✓ |
| — | mock contract PS5.1 WebHeaderCollection 要求 | 要求 mock Headers 必须是 `System.Net.WebHeaderCollection` 实例，否则 PS5.1 兼容性验证无意义。技术判断正确。✓ |
| — | X-RateLimit-Remaining 字符串类型要求 | SKILL L364 以字符串比较（`$rl -eq '0'`），mock Headers 返回值必须为字符串。contract 对齐正确。✓ |
| — | Diff Integrity 28 项能力逐项核验 | 覆盖 Prompt §4 全部能力关键词，且声明"不得用能力关键词仍存在替代行为判断"。✓ |

---

## 3. 发现汇总（按严重性分级）

### P1 — 严重（需修订后方可执行）

| 编号 | 发现 | 位置 | 影响 |
|---|---|---|---|
| P1-1 | T39 harness 注入点行号和描述双重错误：L632 实为 try/catch 结束（非 if/else 块结束），L633 实为 `} else {`（非 `# 释放锁前确认 ownership`）。正确注入点为 L636/L637 之间 | Phase 1 Step 6 + Phase 5 | sub-agent 按错误描述注入可能落入 if 块内而非 if/else 块外，语义偏差 |

### P2 — 中等（建议修订，不阻断执行但影响准确性）

| 编号 | 发现 | 位置 | 影响 |
|---|---|---|---|
| P2-1 | §0.2 diff 表格 6 项行号全部偏差 -1（引用 v1.9 行号标注为 v1.10） | §0.2 | 行号误导；Phase 1 表格前 3 项同样偏差 |
| P2-2 | T38-B harness 注入点行号偏差 -1（Set-Content L480→实际 L481），且注入点描述范围过宽未精确到 L488/L489 | Phase 2 T38-B | sub-agent 可能定位错误注入行 |
| P2-3 | T38-stats-items harness 注入点行号偏差 -1（L478/L479→实际 L479/L480） | Phase 2 T38-stats-items | 同上 |
| P2-4 | Phase 1 输出清单未列出 T38-B 和 T38-stats-items 的 harness 脚本，未明确创建 Phase | Phase 1 输出清单 + Phase 2 | 消费关系断裂；sub-agent 可能不知道何时创建 harness |
| P2-5 | T38-A 验证项"tmp cleaned"与文件锁构造方法矛盾（文件锁持有时 tmp 无法清理） | Phase 2 T38-A | 使用文件锁方案时验证项不可能通过 |
| P2-6 | $commitSucceeded/$lockReleased/前置变量行号偏差 -4 | Phase 1 Step 6 | 行号误导 |
| P2-7 | mock contract 行号系统性偏差 -3 | Phase 1 Step 7.1 | 对齐自检时行号不匹配 |

### P3 — 轻微（记录，不阻断）

| 编号 | 发现 | 位置 | 影响 |
|---|---|---|---|
| P3-1 | GITHUB_VERSION_MONITOR_BASE 行号偏差 -7/-3/-3/-1/-1（不统一） | §0.5 | 行号误导，但每 step 确实支持该变量 |
| P3-2 | API URL 硬编码行号偏差（L338→L341, L478→L479） | §0.5 | 行号误导，但 URL 确实硬编码 |
| P3-3 | Phase 0 目录树含 Prompt 未定义的测试目录（T02/T08/T14/T15/T16/T17/T19） | Phase 0 目录树 | 空目录不影响执行，违反最小化原则 |
| P3-4 | T05-PS7 在执行摘要模板中出现但计划未安排具体测试 | Phase 7/8 + §6.4 | 最终报告 T05-PS7 项无值可填 |

---

## 4. 修订建议

### 4.1 P1 修订（必须）

**P1-1 T39 注入点修正**：

将 Phase 1 Step 6 和 Phase 5 中的注入点描述修改为：

> 注入点：SKILL L636（if/else 块整体结束 `}`）与 L637（`# 释放锁前确认 ownership`）之间。此切分点在 if/else 块完全结束后、锁释放逻辑开始前，技术干净。

同步修正 Phase 1 Step 6 中 $commitSucceeded（L621/L627）和 $lockReleased（L638/L644）的行号引用。

### 4.2 P2 修订（建议）

1. **P2-1/P2-2/P2-3 行号修正**：将 §0.2 表格和 Phase 1/2 表格中的 Step 4 行号统一 +1（对齐 v1.10 实际行号），或在表格标题注明"行号基于 v1.9，v1.10 实际 +1"。

2. **P2-4 harness 输出清单补充**：在 Phase 1 输出清单中增加：
   - `lib/step4-t38b-harness.ps1`（T38-B 同进程 harness）
   - `lib/step4-t38-stats-items-harness.ps1`（T38-stats-items 同进程 harness）
   
   或在 Phase 2 处理逻辑开头增加"Step 0: 创建 T38-B/T38-stats-items harness"步骤。

3. **P2-5 T38-A 验证项修正**：将"tmp cleaned — result.review.tmp 不残留"修改为：
   - ACL 方案："tmp 未创建（Set-Content 被 ACL 阻止）"
   - 文件锁方案："catch 块执行了 Remove-Item（ErrorAction SilentlyContinue）；外部进程终止后确认 tmp 已删除"

4. **P2-6/P2-7 行号修正**：修正 $commitSucceeded/$lockReleased/前置变量/mock contract 的行号引用。

### 4.3 P3 修订（可选）

1. **P3-3 目录树清理**：移除 Prompt 未定义的测试目录，或标注"预留"。
2. **P3-4 T05-PS7 补充**：在 Phase 7 增加 T05-PS7 测试，或声明由 T18 forbidden 状态覆盖。

---

## 5. 总体评价

### 5.1 核心优点

1. **Diff 分析方向正确**：v1.9→v1.10 的 6 条路径变化分析经交叉核实全部正确。L479 stats/items return 移除发现是本轮计划最有价值的发现，T38-stats-items 子测试设计精准。
2. **Prompt 覆盖完整**：27 个章节全部有对应 Phase 覆盖，无遗漏。
3. **独立性原则到位**：§0.6 切断旧报告继承链，stdout 透传独立验证不依赖旧报告。
4. **技术可行性判断准确**：ReadOnly/File.Open 证伪排除正确，ACL 恢复步骤完整，同进程 harness 设计判断正确。
5. **证据规则完整**：sha256 三者覆盖、ACL 快照、文件锁证据、secret 禁止均到位。
6. **判定逻辑正确**：三档判定 + 双维度计数（PS7/PS5.1）+ 守恒式 + FAIL≠BLOCKED 均正确。

### 5.2 核心问题

1. **行号系统性偏差**：§0.2 表格 6 项全部偏差 -1（引用 v1.9 行号标注为 v1.10），T39 相关偏差 -4，mock contract 偏差 -3。根因是计划制定时基于 v1.9 行号推算 v1.10 行号，未实际读取 v1.10 原文确认。违反"行号必须直接核实"原则。
2. **T39 注入点描述错误**（P1）：L632/L633 的描述与实际内容不符，可能导致 sub-agent 在错误位置注入。
3. **harness 输出清单不完整**：T38-B/T38-stats-items harness 未列入 Phase 1 输出。

### 5.3 审计结论

| 维度 | 评价 |
|---|---|
| Prompt 覆盖完整性 | PASS |
| Diff 分析正确性 | PASS（方向正确，行号偏差） |
| 技术可行性 | CONDITIONAL（P1-1 注入点错误需修正） |
| 证据规则完整性 | PASS |
| 判定逻辑正确性 | PASS |
| 行号准确性 | FAIL（系统性偏差，需修正） |
| 内部一致性 | CONDITIONAL（P2-4 harness 清单 + P3-4 T05-PS7 缺口） |

**审计 verdict**：**CONDITIONAL_PASS_WITH_MANDATORY_FIXES**

计划的核心设计（diff 分析、测试覆盖、判定逻辑、证据规则）质量良好，但存在 1 项 P1（T39 注入点描述错误）和 7 项 P2（行号偏差 + harness 清单 + 验证项矛盾）需修订后方可执行。P3 项为轻微问题，可在执行过程中修正或记录。

**建议执行前修订项**：P1-1（必须）+ P2-4（必须，否则 Phase 2 无法启动）+ P2-5（必须，否则 T38-A 文件锁方案验证项不可能通过）。其余 P2/P3 项可在执行过程中由 sub-agent 自行核实行号时修正，但建议在执行前统一修正以减少 sub-agent 的行号核实负担。

---

## 附录：审计核实工具与方法记录

| 核实项 | 工具 | 方法 |
|---|---|---|
| SKILL-v1.10.md 行号 | search_content（ripgrep） | 逐条搜索关键字符串定位行号 |
| SKILL-v1.9.md 行号 | search_content + read_file | 交叉确认 v1.9 Step 4 区域 |
| v1.9→v1.10 diff | read_file（v1.9 L474-485） + search_content（v1.10 关键路径） | 逐路径对比行为差异 |
| v1.9 RUN_STATUS|failed| 缺失 | search_content（v1.9 搜索 `RUN_STATUS\|failed\|` + heartbeat/review 关键词） | 确认 v1.9 Step 4 无 RUN_STATUS|failed| |
| T39 注入点代码结构 | read_file（v1.10 L624-638） + search_content（L637 定位） | 确认 if/else/try/catch 嵌套结构 |
| 文件存在性 | execute_command（Test-Path） | 确认 SKILL-v1.9.md 存在 |

**工具行为差异记录**：read_file 对 SKILL-v1.10.md Step 4 区域（L475-L510，含超长行）的行号显示与 search_content 不一致（偏移约 +1）。根因是超长行（单行 >2000 字符）在 read_file 输出中的折行处理导致行号偏移。本次审计以 search_content 行号为准。此差异在 Step 5 区域（L520+，无超长行）不存在。建议后续审计 SKILL 类文件时，对含超长行的代码块优先使用 search_content 确认行号。
