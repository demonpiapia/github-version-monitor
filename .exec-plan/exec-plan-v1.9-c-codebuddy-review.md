# 执行计划 exec-plan-v1.9-c 独立审计报告（codebuddy-review）

> **审计对象**: `d:\AI\Workspace\automatic\github-version-monitor\.exec-plan\exec-plan-v1.9-c.md`（SKILL-v1.9 定向最终验证 — 执行计划，1471 行，基于 v1.9-b 修订）
> **审计日期**: 2026-09-08
> **审计执行**: CodeBuddy 独立审计（第二轮；第一轮为 exec-plan-v1.9-a，见 `exec-plan-v1.9-a-codebuddy-review.md`）
> **审计性质**: 只读审计，未修改被审计文件与被测对象
> **版本链**: v1.9-a（初版）→ CodeBuddy 审计 → v1.9-b（TRAE 修订，采纳审计项）→ v1.9-c（TRAE 修订，消除旧报告结论链式继承偏差）

---

## 1. 审计范围与方法

1. **修复验证**：逐项核查 v1.9-a 审计报告的 19 项发现（H1、M1-M7、L1-L11）在 v1.9-c 中的修复状态与事实依据真实性；
2. **事实源再核对**：计划 ↔ Prompt ↔ SKILL-v1.9 源码（关键处重新直接核实，含上一轮未覆盖的 L139-140）；
3. **新问题扫描**：v1.9-c 修订引入的新设计（同进程 harness、mock 函数覆盖、双维度计数、独立性原则）的技术可行性与内部自洽性；
4. **git/环境复查**：被测对象 git 状态、版本链文件、.selfreview 目录存在性。

全部结论基于审计时点实际读取/命令核验。

**本轮关键核实快照**：

| 项 | 核实结果 |
|---|---|
| SKILL-v1.9.md L129-140 状态表 | **9 种非 ok 状态**（not_found / rate_limited / server_error / network_error / invalid_response / metadata_incomplete / auth_error / forbidden / http_error），行号引用 L132-140 准确 |
| SKILL-v1.9.md L360-366 状态机代码 | `elseif ($code) { $status = 'http_error' }`（L365）分支存在，与状态表一致 |
| SKILL-v1.9.md L229 | `BACKUP_OK|$ts` 输出确认（lock-stale-dead 判定标记依据成立） |
| `.selfreview/selfreview-v18-20260908-073000.md` | 存在（v1.9-c L2 修订理由属实） |
| git 状态 | `SKILL-v1.9.md` 仍 untracked；`.exec-plan/` 下存在 v1.9-a / v1.9-a-codebuddy-review / v1.9-b / v1.9-c（均 untracked，v1.9-a.md 同）；v1.9-c 尚未 staged |

---

## 2. 事实更正声明（针对第一轮审计）

**第一轮审计 M6 中"SKILL-v1.9 非 ok 状态为 8 种、`http_error` 已不存在"的断言是错误的。**

- 本轮直接读取 SKILL L129-140 确认：状态表共 9 种非 ok 状态，`http_error`（L140）存在；代码 L365 `elseif ($code) { $status = 'http_error' }` 亦确认。
- 错误原因：第一轮的状态枚举判断依赖搜索结果（pattern 未含 `http_error`，且 L365 行在搜索输出中被截断），未读取完整状态表——属核实手段不完整下的过度断言。
- **影响**：v1.9-c 的 M6 修订（T18 覆盖 9 种非 ok 状态，依据 SKILL L132-140 直接阅读）**事实依据成立**，其修订方向正确。第一轮审计报告中 M6 的"两个状态连续第三轮无测试安排"结论中，`metadata_incomplete` / `invalid_response` 无专项构造的部分仍然成立，但状态总数口径以本轮 9 种为准。
- v1.9-c L729 "SKILL-v1.9 状态机共有 9 种非 ok 状态（SKILL L132-140 直接核实）"——行号与数量均准确。

---

## 3. v1.9-a 审计发现项修复验证（19 项逐项）

| 项 | 严重性 | 修复状态 | 核实依据（v1.9-c 位置） |
|---|---|---|---|
| H1 T39 分段跨进程变量丢失 | 高 | **已修复（设计成立）**，残留规格缺口见 N1 | Phase 1 Step 5（L292-303）新增 `lib/step5-t39-harness.ps1` 同进程 harness；Phase 4（L557-616）整体改用 harness；L578 设计说明准确复述了问题成因 |
| M1 PS5.1 FAIL 计数口径矛盾 | 中 | **已修复** | §8（L1313-1379）定义双维度计数；Phase 9 Step 4/5（L1015-1070）落地；残留模板口径歧义见 N4 |
| M2 fixture 隔离/mock 机制未定义 | 中 | **已修复** | §0.4（L66-83）：`GITHUB_VERSION_MONITOR_BASE`（SKILL L162/240/431/473/518 依据属实，本轮复核一致）；mock 改为函数覆盖，不涉 hosts 系统变更；T46 运行目录明确（L681/693）；残留 mock 对象 contract 缺口见 N2 |
| M3 run-full-pipeline stdout 缺陷未纳入 | 中 | **已修复（以独立验证方式）** | Phase 1 L333-336：独立运行验证并记录 `stdout-verification.txt`，T37/T43 执行方式据验证结果分支（L511-514/644）；符合 §0.5 独立性原则 |
| M4 state.sha256 无复核消费者 | 中 | **已修复** | Phase 8 第 9 项（L929-935）：生产 .output SHA256 复核 |
| M5 被测对象未入 git + commit 范围未定义 | 中 | **已修复** | Phase 0 第 4 步 `git add SKILL-v1.9.md`（L186-190）；Phase 9 Step 7 commit 文件范围明确（L1104-1123） |
| M6 T18 状态数口径无出处 | 中 | **已修复且事实依据成立** | Phase 6.1（L729/744-756）：9 种状态逐项列出，本轮对照 SKILL L132-140 逐行核实一致；`http_error` 定义"其他明确 HTTP 状态码（如 302）"为示例性补充，与 SKILL L140 语义一致 |
| M7 `.monitor/` 未纳入 Phase 0 | 中 | **已修复** | Phase 0 L174：注明由 Step 1 在 base 目录动态创建 |
| L1 "27 项"计数错误 | 低 | **已修复**（28 项） | L221/351/1388 |
| L2 .selfreview/ 基准目录歧义 | 低 | **已修复**（项目根，理由属实） | L937-939；引用的 v1.8 selfreview 文件本轮 Test-Path 确认存在 |
| L3 T37 REVIEW_WRITE_OK 必查 vs 条件化矛盾 | 低 | **已修复** | 验证项 L521 + 审查点 L553 均为条件性 |
| L4 Windows 只读目录构造不可行 | 低 | **已修复**（ACL deny / 文件锁；明确禁用 ReadOnly 属性） | L370-372/411-413；残留 T22 目录锁选项问题见 N3 |
| L5 RUNTIME_ERROR 缺竖线 / stale-dead 判定标记 | 低 | **已修复** | L789（`RUNTIME_ERROR\|`）；L791（`BACKUP_OK\|`，SKILL L229 依据本轮核实属实） |
| L6 PS5.1 解析限制未纳入 | 低 | **已修复（改为先试后展开的独立验证）** | L856-860 |
| L7 "3 个 P2" 口径差 | 低 | **已修复**（脚注双口径，声明不影响设计决策） | L18/26 |
| L8 提取脚本核验无基准 | 低 | **已修复** | Phase 1 Step 7 `extraction-manifest.json`（L312-331）+ Phase 8 第 4 项（L912-914） |
| L9 Step 1→6 范围差未说明 | 低 | **已修复** | L290/509/642 |
| L10 T22/T23 缺 result.json/tmp SHA256 证据 | 低 | **已修复** | Phase 2 证据清单（L389-479）+ §4.2 sha256 覆盖范围定义（L1219-1226） |
| L11 T39 缺 lock-after-modify.txt | 低 | **已修复** | L606/616/1233 |

**修复率：19/19 响应，其中 17 项完全修复、2 项（H1/M2）修复成立但有残留规格缺口（见 N1/N2），1 项修订（M6）的事实依据经本轮核实成立。**

---

## 4. v1.9-c 新发现问题

### N1（中）— T39 harness 构造规格不完整，"dot-source" 选项不可行

Phase 1 Step 5（L299）写 "将 Step 5 代码嵌入单个脚本（dot-source 或内联）"。**dot-source 方案不可行**：dot-source `lib/step5-full.ps1` 会一次性连续执行完整 Step 5（commit 段 + 锁释放段），不存在"执行至 Move-Item 成功后暂停"（L300）的注入点，无法在 commit 与 release 之间插入"改锁 PID"动作。唯一可行方式是**内联复制 Step 5 代码并在锁释放段之前注入**（SKILL L632 VALIDATE_ERROR else 块之后、L633 `# 释放锁前确认 ownership` 之前，切分点在 try/catch 块外，技术上干净）。

由此产生两个未定义规格：

1. **harness 内被测代码的逐字性验证缺失**：注入后 harness 的 Step 5 代码部分不再是"逐字提取"，而 `extraction-manifest.json` 仅覆盖 step1~step5-full，Phase 8 第 4 项（提取脚本与原文逐字一致）无法覆盖 harness。计划未定义 harness 被测代码部分的逐字性要求与验证方法（如：Phase 8 对 harness 做受限 diff——与 SKILL 原文仅允许存在一处注入差异）。
2. **Step 5 前置变量未提**：SKILL Step 5 需要 `$conclusionText` / `$summaryText` / `$noteText` 三个变量（SKILL L512），harness 须预置占位值，计划未提（填变量属"使用"非"修改"，不违反硬约束，但应写明）。

### N2（中）— mock `Invoke-RestMethod` 的返回对象 contract 未定义

§0.4 用函数覆盖替代真实 HTTP。SKILL 状态机代码访问响应对象的成员路径固定（`$j.tag_name` / `$j.published_at`、`$_.Exception.Response.Headers`、`X-RateLimit-Remaining` 读取、StatusCode 提取等）。mock 返回对象必须仿真真实 `Invoke-RestMethod` 成功响应 / WebException 异常对象的成员形状，否则状态机走错分支 → 假 FAIL 或假 PASS。计划未定义各场景 mock 对象需包含哪些成员、何种类型。

尤其 T04/T05-PS5.1（L848）要验证 `Get-ResponseHeaderValue` 对 `System.Net.WebHeaderCollection` 的兼容性——该验证项只有在 mock 返回的 `Headers` **真实是 WebHeaderCollection 类型实例**时才有意义。建议在 Phase 1 `mock-listener.ps1` 规格中定义逐场景 mock 对象 contract。

### N3（低-中）— T22 "以 `[System.IO.File]::Open()` 独占锁定 `.output` 目录" 选项技术不可行

`[System.IO.File]::Open()` 只能打开文件；目录不支持 FileShare 语义的排他锁（打开目录句柄也不会阻止在其中创建文件）。该选项应从 T22 方法清单（L412）中删除，保留 ACL deny（可行）。另：ACL deny 构造后测试目录权限的**恢复步骤**未写明（若 sub-agent 无法还原 ACL，残留 deny 会影响后续测试），建议补充"构造前记录 ACL、测试后还原"。

### N4（低）— Phase 9 Step 6 最终结论模板的 FAIL: N 口径未指明

§9 Step 4 定义了 Total 计数，§8 gate 判定用 production-critical 口径。Step 6 模板（L1079-1082）的 `EXECUTED/PASS/FAIL/BLOCKED: N` 未说明填 Total 还是 production-critical。若填 Total，可能出现 "FAIL: 1 + FINAL_VERDICT: PRODUCTION_READY"（PS5.1 FAIL 但 gate open）的字面组合——不违反 Prompt（其自身两条款矛盾由 §8 裁决），但易误读。建议模板处注明口径。

### N5（低）— Phase 6 状态机各测试的 API 来源分配未定义

§0.4 mock 机制明确用于 T02/T04/T05/T08（L75）；T15（"major 差 ≥2 的真实仓库"，L738）、T16、T17、T19 未说明走真实 API 还是 mock。T16（dateSuspicious）需控制 `published_at`，真实仓库不可控，实际 mock 更可靠。执行摘要模板要求回答 "Real GitHub API: / Mock HTTP:"（L988-989），需要此分配。建议 Phase 6 表格增加 "API 来源" 列。

### N6（极轻）— 状态机测试的 harness 包装结构未写明 + mock-listener.ps1 定位模糊

mock 函数覆盖要求"dot-source step2.ps1 前定义 mock"（L79），而 6.1 规定 `-File` 模式执行——需要一个包装脚本（定义 mock → dot-source step2.ps1），该包装未列入 Phase 1 工具清单；`mock-listener.ps1` 的描述已改为 "mock Invoke-RestMethod 覆盖函数"（L308）但文件名仍叫 listener，名不副实。建议明确该文件即为 PS7/PS5.1 共用的 mock harness，或新增 `step2-mock-harness.ps1`。

---

## 5. 核实通过项（直接核实）

| # | 项 | 证据 |
|---|---|---|
| P-1 | 计划引用 Prompt 节号（§0/§1/§2/§8/§13-§20/§22-§26）全部对应 | 与第一轮核对的 Prompt 章节结构一致 |
| P-2 | T18 的 9 种非 ok 状态清单（L746-756）与 SKILL L132-140 逐行一致（含 http_error） | 本轮直接读取 SKILL L129-140 + L360-366 |
| P-3 | T22/T23/T38/T39 验证项与 SKILL-v1.9 修复代码持续匹配（与第一轮 P-2 相同的代码段，SKILL 未变） | SKILL L479-503 / L586-650 |
| P-4 | 双维度计数内部自洽：production-critical 覆盖 PS7 全部 + 结构性测试；compatibility 仅 T04/T05-PS5.1；三态 gate 判定改用 production-critical 口径，消解 Prompt §13/§24 表面矛盾 | §8 L1313-1379 |
| P-5 | §0.5 独立性原则与全计划自洽：M3（stdout 独立验证）、L6（PS5.1 先试后展开）、M6（直接读源码）均不再以旧报告结论为设计依据；脚注 [^1] 信息性引用且显式声明不影响设计决策 | L85-108 / L26 / §11 |
| P-6 | §11 修订日志完整记录 a→b→c 修订链、逐项采纳/驳回及理由（含源码行号依据），可追溯 | L1433-1471 |
| P-7 | 计数与审查点数字一致：状态机 10 项、schema 9 项、lock 4 项、self-review 9 项、28 项能力、9 项禁止项、5 step + 1 harness + 4 工具 | L827/945/1168/221/351 |
| P-8 | Invariant 表 7 条不变且与 Prompt §18 一致；T39 的 invariant 4 验证路径（同进程 harness）语义成立 | L1261-1273 / L569-578 |
| P-9 | 执行模式更新自洽：mock 不再需要后台 listener/hosts 变更（6.1 L1285 与 §0.4 一致）；文件锁后台进程 + Stop-Process 终止 | L1277-1293 |
| P-10 | 硬约束 11 条、禁止事项 8 条、证据规则与 v1.9-a 一致，且硬约束 2/禁止事项 2 已补充 GITHUB_VERSION_MONITOR_BASE 隔离方式 | L1194-1257/1297-1310 |

---

## 6. 审计结论

1. **修复完整性**：v1.9-a 审计的 19 项发现全部获得响应且 17 项完全修复；M6 修订的事实依据（9 种非 ok 状态）经本轮直接核实**成立**（第一轮审计自身在 http_error 上有误，已在 §2 更正）。
2. **新问题**：v1.9-c 新发现 6 项（N1-N6），**无高严重性/阻断级缺陷**。N1（T39 harness 规格缺口）与 N2（mock 对象 contract 缺口）建议在执行启动前澄清，否则 sub-agent 将在实现细节上自行决策：N1 若选 dot-source 路线将无法注入、测试退化为无效路径；N2 若 mock 对象形状错误将产生假 FAIL/假 PASS。
3. **独立性原则**：§0.5 切断旧报告结论继承链的做法在 M3/L6/M6 三处修订中落实到位，且以"独立验证/直接读源码"替代——本轮审计对其中两处（M6 的 SKILL L132-140、L2 的 selfreview 文件）做了独立复核，均属实。
4. **判定**：**exec-plan-v1.9-c 可进入执行**；建议将 N1（harness 内联切分 + 逐字性验证 + 变量预置）、N2（mock 对象 contract）、N3（删除目录锁选项 + ACL 还原步骤）、N4（模板口径注明）四项以小幅补丁或 sub-agent 指令补充的方式处理，N5/N6 可在执行中由 sub-agent 按 §0.4 机制自行落地并记录。

---

## 附：本轮审计的核实手段清单

- `read_file`: exec-plan-v1.9-c.md（全 1471 行）、SKILL-v1.9.md L128-145 / L355-370 / L223-234
- `execute_command`: git status / git ls-files / git log；Test-Path `.selfreview` 及目录列举
- 交叉引用：exec-plan-v1.9-a-codebuddy-review.md（第一轮审计）、production-validation-report-v18-final.md（第一轮已全文核实，本轮引用其 N.2/N.3/§L.2/F.4 等结论仅作信息对照）
