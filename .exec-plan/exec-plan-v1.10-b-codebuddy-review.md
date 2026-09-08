# exec-plan-v1.10-b 独立审计报告

> **审计对象**: `.exec-plan/exec-plan-v1.10-b.md`（v1.10-b 审计修订版执行计划）
> **审计依据**: `.GPT/Production Validation Prompt — SKILL-v1.10 Targeted Validation.md`（唯一事实源）
> **交叉核实对象**: `SKILL-v1.10.md` 原文、`exec-plan-v1.10-a-codebuddy-review.md`（前轮审计）
> **审计日期**: 2026-09-09
> **审计方法**: 修订落实逐项对照 + 行号三源直接核实（不采信计划自述）
> **审计人**: CodeBuddy（主代理）

---

## 1. 审计方法说明

1. **修订落实不采信自述**: b 版 §9 修订日志声称 12 项审计发现全部采纳。本次审计将前轮审计（exec-plan-v1.10-a-codebuddy-review.md）的 1 P1 + 7 P2 + 4 P3 逐项与 b 版正文比对，确认修订是否真实落实到文本，而非采信修订日志的声明。
2. **行号三源核实**: b 版引用的全部 SKILL-v1.10.md 行号，以 `search_content`（ripgrep）为权威行号源，并用 PowerShell `Get-Content` 数组索引直接读取目标行区间做独立第二源确认（`355..367 / 484..493 / 498..502 / 539..548 / 763..770`）。`read_file` 未用于 Step 4 超长行区域（前轮已实证其在该区域存在 +1 折行偏移）。
3. **枚举完整读取**: 状态机表（L132-141）、mock contract 访问路径（L341-367）、错误输出文本均读取完整原文后比对。
4. **后果推演单独标注**: 涉及测试有效性的结论区分"直接核实"（行号内容）与"逻辑推演"（注入行为后果）。

---

## 2. 前轮审计 12 项修订落实核实

| 前轮编号 | b 版修订声明 | 直接核实结果 | 判定 |
|---|---|---|---|
| P1-1 | T39 注入点改为 L636/L637；$commitSucceeded L621/L627；$lockReleased L638/L644；前置变量 L539-547 | L636=`}`（if/else 块整体结束）、L637=`# 释放锁前确认 ownership：锁内 PID 必须等于当前进程 PID`；L621=`$commitSucceeded=$false`、L627=`$commitSucceeded=$true`；L638=`$lockReleased = $false`、L644=`$lockReleased = $true`；L539-547=$conclusionText/$summaryText/$noteText here-string 占位段 | ✓ 完全落实 |
| P2-1 | §0.2 表 6 项行号 +1（L477/L478/L480/L487/L496/L506）；Phase 1 表前 3 项同步 | 6 项行号与 SKILL-v1.10.md 实际全部一致（见 §3 表） | ✓ 完全落实 |
| P2-2 | T38-B 目标改 L481（Set-Content）；注入点"精确到 L488/L489 之间" | L481 正确 ✓；**注入点仍偏差 -1**（实际块结束在 L489、第二个 try 在 L490，见 §4.1） | ✗ 部分落实 → 新 P1 |
| P2-3 | T38-stats-items 注入点改 L479/L480 | L479=foreach 行（循环体全在此超长行）、L480=混合行（$doc.review 赋值 + $newStats/$newItems 计算 + if 校验）。注入位置有效（见 §4.4 推演）；"L480（if 校验）"描述不精确 | ✓ 落实（描述精度 P3） |
| P2-4 | Phase 1 输出清单新增 `lib/step4-t38b-harness.ps1`、`lib/step4-t38-stats-items-harness.ps1`；审查点 harness 计数 2→4（5 step + 4 harness + 4 辅助工具，计数自洽） | 文本已落实，Phase 2 消费关系闭合 | ✓ 完全落实 |
| P2-5 | T38-A 验证项按构造方法拆分：ACL 方案="tmp 未创建"；文件锁方案="catch 执行 Remove-Item（L483），外部进程终止后确认删除" | L483=`Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue` 确认；拆分后验证项与构造方法不再矛盾 | ✓ 完全落实 |
| P2-6 | $commitSucceeded/$lockReleased/前置变量行号修正 | 同 P1-1，L621/L627、L638/L644、L539-547 全部确认 | ✓ 完全落实 |
| P2-7 | mock contract 行号系统性修正（L342/L347-349/L350-351/L355/L361-367 等） | L342=`if ($j.tag_name -and $j.published_at)`；L347-349=elseif 分支+metadata_incomplete；L351=`$status = 'invalid_response'`；L355=`[int]$_.Exception.Response.StatusCode` 显式转换；L361(401)/L362(404)/L363(429)/L364(403+`$rl -eq '0'` 字符串比较)/L365(-ge 500)/L366(elseif $code→http_error)/L367(else→network_error) 全部确认 | ✓ 完全落实 |
| P3-1 | GITHUB_VERSION_MONITOR_BASE 行号改为 L163/L241/L432/L474/L522 | 五处全部确认（L163/L241/L432/L474/L522） | ✓ 完全落实 |
| P3-2 | API URL 行号改为 L341/L479 | L341=`Invoke-RestMethod ... releases/latest`（Step 2）；L479=foreach 内 `releases?per_page=5`（Step 4） | ✓ 完全落实 |
| P3-3 | 目录树 T02/T08/T14/T15/T16/T17/T19 标注"（预留，Prompt 未定义）" | 文本已落实 | ✓ 完全落实 |
| P3-4 | Phase 7 新增 7.2 T05-PS7（403+remaining>0→forbidden）；T26/T18 编号顺延；审查点与附录 A §13 行同步 | 文本已落实；附录 A §13 行更新为"T04-PS7 / T05-PS7"；执行摘要模板 T05-PS7 项有测试可填 | ✓ 完全落实 |

**结论**: 12 项中 11 项完全落实；P2-2 部分落实（L481 正确，注入点行号残留 -1 偏差且升级为 P1，见 §4.1）。

---

## 3. b 版 SKILL 行号引用全面复核

| 引用位置 | b 版行号 | 实际行号与内容（search_content + PowerShell 双源） | 偏差 | 判定 |
|---|---|---|---|---|
| constraint #13（§0.1） | L81 | L81: "步骤 4 的不可恢复错误路径必须在清理/锁处理之后输出且仅输出一次 `RUN_STATUS\|failed\|`，不得以裸 `return` 作为最终状态。" | 0 | ✓ |
| heartbeat 失败（§0.2 + Phase 1 + Phase 2） | L477 | L477: catch{`RUNTIME_ERROR\|步骤4 heartbeat 失败` + `RUN_STATUS\|failed\|步骤4 heartbeat 失败，整轮终止。`; return}，**catch 内无 Release-LockSafely** | 0 | ✓ |
| result.json 读取失败 | L478 | L478: try/catch{`RUNTIME_ERROR\|读取 result.json 失败` + Release-LockSafely + 锁释放失败提示 + `RUN_STATUS\|failed\|读取 result.json 失败，整轮终止。`; return} | 0 | ✓ |
| stats/items 完整性失败 | L480 | L480: `REVIEW_WRITE_ERROR\|review 修改了 stats/items，拒绝覆盖 result.json。` + Release-LockSafely + `RUN_STATUS\|failed\|review 程序事实完整性校验失败，整轮终止。`，**无 return**，行尾直接接 `try {`（落入 L481） | 0 | ✓ |
| review tmp 写入失败 | L487 | L487: `RUN_STATUS\|failed\|review 写入失败，整轮终止。`（L488=return） | 0 | ✓ |
| review JSON 校验失败 | L496 | L496: `RUN_STATUS\|failed\|review 临时 JSON 校验失败，整轮终止。`（L497=return） | 0 | ✓ |
| review 原子替换失败 | L506 | L506: `RUN_STATUS\|failed\|review 原子替换失败，整轮终止。`（L507=return） | 0 | ✓ |
| Changelog（§0.2 表） | L765 | L766=`## 15. Changelog`（章节标题），**L768=v1.10 变更条目**（L765 为空行） | -3 | ⚠ P3 |
| T38-A 目标 Set-Content | L481 | L481: `$doc\|ConvertTo-Json -Depth 8\|Set-Content -Path $tmpPath -Encoding UTF8` | 0 | ✓ |
| T38-A 文件锁方案 catch 清理 | L483 | L483: `Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue` | 0 | ✓ |
| T38-B 目标读取+校验 | L489-490 | L490: `try { $check=Get-Content $tmpPath -Raw\|ConvertFrom-Json } catch { $check=$null }`；结构校验在 L491 | -1 | ✗ P2（连带） |
| **T38-B 精确注入点** | **L488（"第一个 try/catch 块结束 }"）之后、L489（"第二个 try 块开始"）之前** | **L488=`return`（catch 块内最后一行）；L489=`}`（第一个 try/catch 块结束）；L490=第二个 try 开始** | **-1** | **✗ P1** |
| T38-C 目标 Move-Item | L499 | L500: `Move-Item $tmpPath $resultPath -Force`（L499=`try {`，L501=`} catch {`） | -1 | ✗ P2 |
| T38-stats-items 注入点 | L479（foreach 结束后）/L480（if 校验） | L479=foreach 超长行（循环体全在此行）；L480=混合行（$doc.review 赋值 + $newStats 计算 + if 校验）。注入位于 L479 与 L480 之间 | 0（位置）/ 描述不精确 | ✓ + P3 |
| $commitSucceeded（Phase 1 Step 6） | L621/L627 | L621/L627 | 0 | ✓ |
| $lockReleased | L638/L644 | L638/L644 | 0 | ✓ |
| T39 注入点 | L636/L637 | L636=`}`（if/else 结束）、L637=ownership 注释 | 0 | ✓ |
| T39 前置变量 | L539-547 | L539-547（三个 here-string 占位段） | 0 | ✓ |
| GITHUB_VERSION_MONITOR_BASE（§0.5） | L163/L241/L432/L474/L522 | 五处全部一致 | 0 | ✓ |
| API URL 硬编码（§0.5） | L341/L479 | L341/L479 | 0 | ✓ |
| Get-ResponseHeaderValue（Phase 8） | L324-330 | L324=function 定义行 | 0 | ✓ |
| mock contract 成功路径 | L342/L347-349/L350-351 | 全部一致 | 0 | ✓ |
| mock contract 类型规范 | L355 + L361-366 | L355=[int] 显式转换；L361-366 数值比较链 | 0 | ✓ |
| mock contract 异常路径 | L361-L367 | L361(401)/L362(404)/L363(429)/L364(403, `$rl -eq '0'` 字符串比较)/L365(5xx)/L366(http_error)/L367(else network_error) | 0 | ✓ |
| 9 种非 ok 状态（Phase 7 T18） | 状态机表 | L132-141: ok + 9 种（含 L141 http_error、L137 invalid_response、L138 metadata_incomplete），b 的 9 种枚举与原文一致 | 0 | ✓ |

**汇总**: b 版约 30 处行号引用，26 处准确（含前轮全部 P2/P3 行号修正），4 处偏差（1 P1 + 1 P2 + 1 P2 连带 + 1 P3）。

---

## 4. 新发现详情

### 4.1 P1-B1: T38-B 注入点行号残留偏差，按字面执行将使测试完全失效

**b 版原文**（Phase 2 T38-B）:
> 精确注入点：L488（第一个 try/catch 块结束 `}`）之后、L489（第二个 try 块开始）之前。此切分点在两个 try/catch 块之间，技术干净。

**直接核实结果**（search_content + PowerShell Get-Content 双源一致）:

```484:491:SKILL-v1.10.md
484:     $released=Release-LockSafely
485:     Write-Output ('REVIEW_WRITE_ERROR|review 临时文件写入失败：{0}' -f $_.Exception.Message)
486:     if (-not $released) { Write-Output 'RUNTIME_ERROR|review 写入失败后锁释放失败，保留锁供陈锁机制接管。' }
487:     Write-Output 'RUN_STATUS|failed|review 写入失败，整轮终止。'
488:     return
489: }
490: try { $check=Get-Content $tmpPath -Raw|ConvertFrom-Json } catch { $check=$null }
491: if($null-eq $check-or $null-eq $check.review-or ...
```

- L488 = `return`（第一个 try/catch 的 **catch 块内**最后一行），不是"块结束 `}`"
- L489 = `}`（第一个 try/catch 块结束）
- L490 = `try { $check=Get-Content ... }`（第二个 try 块开始）

**后果推演**（逻辑推演，非运行验证）: 若 sub-agent 按计划字面在"L488 之后、L489 之前"注入 `Set-Content $tmpPath -Value '{invalid json' -Force`，注入代码将落入 **catch 块内部**（return 与 `}` 之间）。T38-B 的场景是"tmp 写入成功 + JSON 内容非法"——该场景不产生异常、不进入 catch，因此**注入代码永远不会执行**，目标失败路径（L493/L496 `REVIEW_WRITE_ERROR|review 临时 JSON 校验失败` + `RUN_STATUS|failed|`）无法触发。测试将得到假阴性，或迫使 sub-agent 按 Prompt §6 判 BLOCKED（本可避免的 BLOCKED）。

**根因**: 前轮审计报告 §2.4.2 自身的"Get-Content 实际在 L489"继承了 read_file 对 Step 4 超长行区域的 +1 折行偏移（该报告 §2.2 表格用 search_content 核实的行号是对的，但 §2.4 注入点核实的行号来自 read_file 偏移源），b 版修订时沿用了这一偏差且未用 search_content 独立复核。这正是前轮审计附录"工具行为差异记录"所警告的模式在修订环节的复发。

**修订建议**: 注入点改为——

> 精确注入点：L489（第一个 try/catch 块结束 `}`）之后、L490（第二个 try 块开始 `try { $check=Get-Content $tmpPath ...`）之前。

同步将 T38-B 目标行号改为：L490（`Get-Content $tmpPath -Raw|ConvertFrom-Json` 读取+转换）与 L491（`$check.review`/`$check.stats`/`$check.items` 结构校验）。

### 4.2 P2-B1: T38-C 目标行号 Move-Item 偏差 -1

b 版 Phase 2 T38-C："目标: SKILL L499 `Move-Item $tmpPath $resultPath -Force` 真实失败"。实际 Move-Item 在 **L500**（L499 = `try {`，L501 = `} catch {`）。此引用前轮审计未覆盖、b 版修订未含。影响较轻（错误码文本搜索可自行定位），但与前轮"行号必须直接核实"的要求不一致。

**修订建议**: L499 → L500。

### 4.3 P3-B1: §0.2 表 Changelog 行号偏差

b 版 §0.2 表："Changelog | L765 | 不存在 | 新增 v1.10 变更条目"。实际: L766 = `## 15. Changelog`（章节标题），**L768 = v1.10 变更条目**（`- **v1.10（2026-09-09 review 失败终态闭环修复轮）**：...`），L765 为空行。不影响执行（Phase 1 diff integrity 不依赖该行号），P3。

### 4.4 P3-B2: T38-stats-items 注入点描述不精确（注入有效性本身成立）

b 版描述"注入点：SKILL L479（foreach 循环结束后）与 L480（if 校验）之间"。实际 L480 不是纯"if 校验"行，而是混合行：`$doc.review=...; $newStats=$doc.stats|ConvertTo-Json...; $newItems=...; if($newStats-ne $origStats-or ...){...}`。

**注入有效性推演**（代码阅读推演，建议执行时以实测确认）: $origStats 在 L478 行尾固化（`$origStats=$doc.stats|ConvertTo-Json -Depth 8 -Compress`，早于注入点），注入 `$doc.stats.total = 999` 后 L480 计算的 $newStats 序列化结果必然 ≠ $origStats（字符串比较而非引用比较，修改必然反映）→ 校验失败路径触发 ✓。注入位置在 L479 与 L480 之间位于 `$doc.review` 赋值之前，与 stats 修改无依赖冲突，技术可行。

两点补充建议: ① 描述改为"L479（foreach 超长行，循环体全在此行）与 L480（$doc.review 赋值 + $newStats/$newItems 计算 + if 校验混合行）之间"；② 补注有效性依据（$origStats 在 L478 已固化为 JSON 字符串快照）及边界条件（fixture result.json 的 stats.total 不得恰为 999）。

### 4.5 P3-B3: T46 验证项"写回 .output"与执行方式（Step 1+2）不匹配

b 版 T46 验证项含"读取 .output/ 写回 .output/ backup 基于 .output 状态文件"，但检查方法为"运行 Step 1 + Step 2 后检查"——写回发生在 Step 5，仅跑 Step 1+2 时"写回来自 .output"维度无证据。T43 完整管线实际可补足此维度，但计划未显式声明引用关系。

**修订建议**: T46 补跑 Step 5 或在验证项处显式声明"写回维度由 T43 完整管线证据覆盖"。

### 4.6 P3-B4: create-fixture.ps1 对 synced/versionJump 场景的 localVer 确定方式未定义

T43 要求 synced 场景（localVer 等于最新 release）与 versionJump 场景（major 差 ≥2 或 minor 差 ≥10）。synced 场景的 localVer 需动态查询最新 release 后写入 fixture，否则固定值随上游发版失效导致场景漂移为 normal upgrade。计划未说明 create-fixture.ps1 如何确定这些 localVer（动态查询 / 硬编码策略）。

**修订建议**: Phase 1 Step 7 补充 create-fixture.ps1 的 localVer 策略（建议: synced/versionJump 场景运行时动态查询 `releases/latest` 后生成 fixture；404 场景用不存在 repo）。

### 4.7 P3-B5: Phase 8 复用 mock 库未声明 PS5.1 语法兼容要求

Phase 8 用 `powershell.exe` 运行 `lib/step2-mock-harness.ps1` + `lib/mock-invoke-restmethod.ps1`，但这两个文件在 Phase 1（PS7 环境）创建，计划未要求其脚本语法 PS5.1 兼容（如 PS7-only 运算符会导致 Phase 8 意外失败，且失败原因与被测对象无关）。

**修订建议**: Phase 1 Step 7 补充"mock 库与 harness 须使用 PS5.1 兼容语法（因 Phase 8 复用）"，并在 Phase 1 对齐自检中增加语法兼容检查。

### 4.8 P3-B6: git diff --no-index 退出码未处理

Phase 1 Step 1 直接执行 `git diff --no-index SKILL-v1.9.md SKILL-v1.10.md > ...diff`。存在差异时 git 退出码为 1，在 `-File` 脚本模式下脚本进程退出码非零，可能被执行框架/审查点误判为 Phase 1 失败。

**修订建议**: Step 1 命令后追加退出码归零（如 `; exit 0`）或加注"退出码 1 = 有差异，属预期"。

### 4.9 P3-B7: ACL deny CreateFiles 构造的前置条件未显式声明

T22/T38-A 的 ACL deny CreateFiles 方案只阻止**新文件创建**，不阻止对已存在文件的覆盖写入。若 md.tmp / result.review.tmp 因前次运行残留已存在，Set-Content 覆盖将成功 → 注入失败 → 测试假阴性。

**修订建议**: T22/T38-A 构造前置增加断言"目标 tmp 文件不存在（存在则先删除并记录）"。

---

## 5. Prompt 覆盖复核

附录 A 27 节对照表与前轮一致，无章节删减；§13 行已同步更新为"T04-PS7 / T05-PS7"（对应 P3-4 修订）。抽查确认:
- Prompt §5/§6（T38 核心+多分支）→ Phase 2 六个子测试 ✓
- Prompt §19（所有 return 扫描 + early-return audit）→ Phase 10.1，含 L480 落入行为的重复输出检查 ✓
- Prompt §20（I1-I7）→ Phase 10.2，验证依据显式声明来自前序证据汇总 ✓
- Prompt §22（selfreview-v19.md 文件名）→ Phase 11 沿用字面格式 + 附注说明偏差（D4 决策保持）✓
- Prompt §25/§26（Production Gate + 执行摘要）→ §6.3/§12.3/§6.4/§12.4，T05-PS7 缺口已补 ✓
- Prompt §27（12 条最终原则）→ §7 逐条对应 ✓

**覆盖完整性**: PASS（27 节无遗漏）。

---

## 6. 值得肯定的修订

| 编号 | 内容 | 评价 |
|---|---|---|
| — | P1-1 修订后的 T39 注入点（L636/L637）经双源核实**完全正确**，且 §9 修订日志记录了 Grep 核实依据 | 修复质量高 ✓ |
| — | P2-1/P2-6/P2-7/P3-1/P3-2 的行号批量修正后，b 版约 30 处引用中 26 处准确 | 前轮发现的系统性行号偏差已消除 ✓ |
| — | P2-5 的 T38-A 验证项拆分与 L483 实际代码一致，文件锁方案"外部进程终止后确认 tmp 已删除"的时序描述准确 | ✓ |
| — | T38-stats-items 判定规则三分支（二次输出→FAIL+P1 / 落入后完成写入→FAIL / 安全终止→详细说明）对 L480 return 移除行为的验证设计完整 | ✓ |
| — | T38-heartbeat 的条件化期望（"heartbeat 失败后 return，未调用 Release-LockSafely"）与 L477 实际代码（catch 内无锁释放，直接 return）完全一致 | 行为级描述准确 ✓ |
| — | T39 注入内容 `pid=999999;ts=...` 与锁格式兼容性成立: Release-LockSafely（L476）与 ownership 校验均只匹配 `pid=<当前PID>;` 前缀，ts= 字段不影响判定 | ✓ |
| — | T38-B 注入内容有效性（正确位置注入时）: `'{invalid json'` 使 L490 ConvertFrom-Json 异常 → catch 置 $check=$null → L491 结构校验命中 → L493/L496 预期输出，与验证项一致 | ✓ |

---

## 7. 发现汇总

### P1 — 严重（须修订后方可执行）

| 编号 | 发现 | 位置 | 影响 |
|---|---|---|---|
| P1-B1 | T38-B 精确注入点行号残留偏差 -1: b 写"L488（第一个 try/catch 结束 }）之后、L489（第二个 try 开始）之前"，实际 L488=return（catch 内）、L489=}（第一个 try/catch 结束）、L490=第二个 try 开始。按字面注入落入 catch 块内部，正常路径不执行注入，T38-B 无法触发目标失败路径 | Phase 2 T38-B（连带目标行号 L489-490 → 应为 L490/L491） | 测试失效（假阴性 / 不必要 BLOCKED） |

### P2 — 中等（建议修订）

| 编号 | 发现 | 位置 | 影响 |
|---|---|---|---|
| P2-B1 | T38-C 目标 Move-Item 行号 L499 → 实际 L500（L499 = `try {`） | Phase 2 T38-C | 行号误导（文本搜索可自行纠正） |

### P3 — 轻微（记录，不阻断）

| 编号 | 发现 | 位置 |
|---|---|---|
| P3-B1 | §0.2 表 Changelog 行号 L765 → 实际章节标题 L766、v1.10 条目 L768 | §0.2 |
| P3-B2 | T38-stats-items 注入点描述"L480（if 校验）"不精确（实为混合行）；注入有效性本身成立，建议补注依据（$origStats 在 L478 固化）与边界条件 | Phase 2 T38-stats-items |
| P3-B3 | T46"写回 .output"验证项与 Step1+2 执行方式不匹配，未声明由 T43 证据补足 | Phase 6 T46 |
| P3-B4 | synced/versionJump 场景 localVer 确定方式未定义（synced 需动态查询最新 release） | Phase 1 Step 7 |
| P3-B5 | Phase 8 复用的 mock 库/harness 未声明 PS5.1 语法兼容要求 | Phase 1 Step 7 + Phase 8 |
| P3-B6 | git diff --no-index 退出码 1 未处理，-File 模式下可能被误判失败 | Phase 1 Step 1 |
| P3-B7 | ACL deny CreateFiles 方案未声明"目标 tmp 必须不存在"前置断言 | Phase 2 T38-A + Phase 3 T22 |

---

## 8. 审计结论

| 维度 | 评价 |
|---|---|
| 前轮 12 项修订落实 | 11 项完全落实 + P2-2 部分落实（残留偏差升级 P1） |
| 行号准确性 | 大幅改善（26/30 准确），残留 4 处（1 P1 + 1 P2 + 1 连带 + 1 P3） |
| Prompt 覆盖完整性 | PASS（27 节无遗漏，T05-PS7 缺口已补） |
| 测试构造技术可行性 | 6 个 T38 子测试 + T22/T23/T39 构造方法经核实可行；T38-B 因注入点行号错误暂不可行 |
| 判定逻辑 / 证据规则 | PASS（与前轮一致，未回退） |
| 修订日志真实性 | PASS（12 项声明与正文一致，无虚报） |

**审计 verdict**: **CONDITIONAL_PASS_WITH_MANDATORY_FIXES**

b 版对前轮审计的修订整体高质量——11/12 项完全落实，前轮的系统性行号偏差（P2-1/P2-6/P2-7，共 20+ 处）已全部消除，P1-1（T39 注入点）修复准确。但修订过程暴露了新的流程风险：**b 修订时对注入点行号采信了前轮审计报告中源自 read_file 偏移的行号（L489），未按该报告自身警示用 search_content 独立复核**，导致 P1-B1。P1-B1 与 P2-B1 修订后方可执行；P3-B2~B7 建议一并修订（工作量小），P3-B1 可仅记录。

**建议执行前必改项**: P1-B1（必须，否则 T38-B 子测试无效）+ P2-B1（必须，与 P1-B1 同批一行改动）。

---

## 附录: 审计核实工具与方法记录

| 核实项 | 工具 | 说明 |
|---|---|---|
| Step 4 区域全部行号（L475-507，超长行密集） | search_content（ripgrep） | 权威行号源；关键错误文本（heartbeat/result-read/stats-items/写入失败/JSON 校验/原子替换）逐条定位 |
| L355-367 / L484-493 / L498-502 / L539-548 / L763-770 | PowerShell `Get-Content` 数组索引 | 独立第二源，直接输出"行号: 原文"，排除 read_file 折行偏移与搜索截断 |
| T38-B 注入点结构（L488/L489/L490） | 双源交叉 | search_content（`$tmpPath` 命中 L490）+ PowerShell（L488=return、L489=}、L490=try）一致后定论 |
| 修订落实对照 | read_file（b 版全文 + 前轮审计报告） | 12 项逐项比对正文 |
| 后果推演（P1-B1 catch 内注入不执行、T38-stats-items 注入有效性） | 代码阅读逻辑推演 | 已在报告中标注"推演"属性，未运行验证 |
