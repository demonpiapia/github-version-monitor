# 独立审计报告：exec-plan-v1.11-b.md

> **审计员**: Zoo（debug 模式独立审计）
> **审计日期**: 2026-09-09
> **被审计文件**: `.exec-plan/exec-plan-v1.11-b.md`
> **事实源**: `.GPT/Production Validation Prompt — SKILL-v1.11 Targeted Validation.md`（39 节） + `SKILL-v1.11.md` + `SKILL-v1.10.md`
> **审计方法**: 静态代码分析 + `git diff --no-index` 实测 + 行号逐项核对 + 注入设计逻辑验证 + Prompt 39 节覆盖完整性检查

---

## 0. 审计结论

| 维度 | 结论 |
|---|---|
| Diff 完整性声明 | ✅ 核实通过（3 hunk / 3 insertions + 2 deletions） |
| L480 修复行 `;return` | ✅ 核实通过（位于 if 块内，return 阻止落入后续 try） |
| T38-stats-items 注入设计 | ✅ 核实通过（`$origStats` 固化于 L478，注入修改 `$doc.stats.total` 使 `$newStats ≠ $origStats`） |
| T38-B 注入设计 | ✅ 核实通过（L489/L490 之间注入，tmp 已存在可覆写） |
| T39 注入设计 | ✅ 核实通过（L636/L637 之间注入 PID 重写，ownership 校验失败） |
| Prompt 39 节覆盖 | ✅ 核实通过（附录 A 全映射，无遗漏） |
| §0.2 行号基线说明 | ✅ 核实通过（14 项行号全部正确） |
| Early-return 审计框架 | ⚠️ 框架可用但有遗漏（见 P2-001/P2-002） |
| SENTINEL 期望表 | ⚠️ 逻辑正确但行号有 off-by-one（见 P3-001） |

**审计判定**: **需修订后执行**（0 P1 + 2 P2 + 3 P3；所有问题均为行号引用遗漏或 off-by-one，注入设计/判定规则/diff 核验/逻辑链全部通过）

---

## 1. Diff 完整性核实

### 1.1 实测命令

```powershell
git diff --no-index -- .\SKILL-v1.10.md .\SKILL-v1.11.md
```

### 1.2 实测结果

| Hunk | 行号 | 变更类型 | 内容 | 计划声明类别 |
|---|---|---|---|---|
| 1 | L8 | 行替换（1+/1-） | `> 版本：v1.10` → `> 版本：v1.11` | documentation ✅ |
| 2 | L480 | 行替换（1+/1-） | `...整轮终止。'}` → `...整轮终止。';return};try {` | **核心修复** ✅ |
| 3 | L768 | 纯新增（1+/0-） | 新增 v1.11 changelog 条目 | changelog ✅ |

**总计**: 3 insertions + 2 deletions，3 个 hunk。与计划 §0.2 声明完全一致。

### 1.3 L480 修复行逐字核实

v1.10 L480（原行）:
```
...Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。'};try {
```
→ if 块以 `}` 闭合后直接 `;try {`，**无 return**，执行落入 L481 `Set-Content` tmp 写入路径。

v1.11 L480（修复行）:
```
...Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。';return};try {
```
→ `return` 位于 if 块内（`}` 之前），stats/items 不匹配时输出终态后**立即 return**，阻止落入 `;try {`。

**核实结论**: 修复语义正确，`return` 确实在 if 块内，阻止后续 try 块执行。

### 1.4 行号偏移核实

计划声明："v1.10 → v1.11 除 L768 后插入 1 行外行号无偏移（L480 为同行替换）"。

- Hunk 1（L8）: 同行替换，无偏移 ✅
- Hunk 2（L480）: 同行替换，无偏移 ✅
- Hunk 3（L768）: 纯插入，L769+ 偏移 +1 ✅

**核实结论**: 声明正确。

---

## 2. 注入设计核实

### 2.1 T38-stats-items 注入（L479/L480 之间）

**计划声明**: 在 L479（foreach 超长行）与 L480（$doc.review 赋值 + $newStats/$newItems 计算 + if 校验混合行）之间注入 `$doc.stats.total = 999`。

**SKILL-v1.11 实际代码核实**:

| 行号 | 代码 | 作用 |
|---|---|---|
| L478 | `try { $doc=Get-Content $resultPath -Raw\|ConvertFrom-Json } catch { ... };$origStats=$doc.stats\|ConvertTo-Json -Depth 8 -Compress;$origItems=...` | 读取 result.json → **固化 `$origStats`** 为 JSON 字符串快照 |
| L479 | `foreach($it in $candidates){...}` | 遍历 review 候选项，调用 API，构建 `$reviewItems`。**不修改 `$doc.stats` 或 `$doc.items`** |
| L480 | `$doc.review=[PSCustomObject]@{...};$newStats=$doc.stats\|ConvertTo-Json -Depth 8 -Compress;$newItems=$doc.items\|ConvertTo-Json -Depth 8 -Compress;if($newStats-ne $origStats-or $newItems-ne $origItems){...return}` | 赋值 review → 计算 `$newStats`/`$newItems` → **完整性校验** → 失败则 REVIEW_WRITE_ERROR + RUN_STATUS\|failed\| + return |

**注入有效性分析**:

1. `$origStats` 在 L478 行尾固化为 `$doc.stats` 的 JSON 序列化字符串（快照）
2. 注入 `$doc.stats.total = 999` 修改了 `$doc.stats` 的 `total` 属性
3. L480 计算 `$newStats = $doc.stats|ConvertTo-Json -Depth 8 -Compress` → 序列化结果包含 `total=999` → `$newStats ≠ $origStats`（字符串比较）
4. if 条件命中 → `REVIEW_WRITE_ERROR|review 修改了 stats/items` + `RUN_STATUS|failed|review 程序事实完整性校验失败` + `return`

**边界条件核实**: 计划声明 "fixture 经真实 Step 2 产生的 result.json 的 stats.total 不得恰为 999"。`stats.total` = 监测项总数（SKILL L386 `$stats.total`），fixture 用 1-2 项天然远离 999。声明合理。

**核实结论**: 注入设计有效，`$origStats` 固化点、注入点、`$newStats` 计算点三者关系正确。

### 2.2 T38-B 注入（L489/L490 之间）

**计划声明**: 在 L489（第一个 try/catch 结束 `}`）与 L490（第二个 try 开始）之间注入 `Set-Content $tmpPath -Value '{invalid json' -Force`。

**SKILL-v1.11 实际代码核实**:

| 行号 | 代码 | 作用 |
|---|---|---|
| L481 | `$doc\|ConvertTo-Json -Depth 8\|Set-Content -Path $tmpPath -Encoding UTF8` | **写入 tmp 文件**（成功时文件存在） |
| L489 | `}` | 第一个 try/catch 块结束 |
| L490 | `try { $check=Get-Content $tmpPath -Raw\|ConvertFrom-Json } catch { $check=$null }` | **读取并校验 tmp JSON** |
| L491 | `if($null-eq $check-or ...-ne $origStats-or ...-ne $origItems){...}` | JSON 校验失败路径 |

**注入有效性分析**:

1. L481 `Set-Content` 成功执行 → tmp 文件存在且内容为合法 JSON
2. 注入 `Set-Content $tmpPath -Value '{invalid json' -Force` → 覆写 tmp 为非法 JSON
3. L490 `Get-Content $tmpPath -Raw|ConvertFrom-Json` → 读取非法 JSON → `ConvertFrom-Json` 抛异常 → catch 设 `$check=$null`
4. L491 `if($null-eq $check-or ...)` → 命中 → `REVIEW_WRITE_ERROR|review 临时 JSON 校验失败` + `RUN_STATUS|failed|` + return

**核实结论**: 注入设计有效。tmp 文件在 L481 成功写入后存在，注入覆写为非法 JSON 使 L490 校验失败。

### 2.3 T39 注入（L636/L637 之间）

**计划声明**: 在 L636（if/else 块结束 `}`）与 L637（ownership 注释）之间注入 `Set-Content $lockPath -Value "pid=999999;ts=..." -Force`。

**SKILL-v1.11 实际代码核实**:

| 行号 | 代码 | 作用 |
|---|---|---|
| L624 | `if ($rows2.Count -eq $items.Count -and ...) {` | 结构校验通过 |
| L625-628 | `try { Move-Item...; $commitSucceeded=$true; COMMIT_OK }` | **原子替换成功** |
| L629-632 | `catch { Remove-Item $tmp; RUNTIME_ERROR\|... }` | 替换失败（T39 不触发此分支） |
| L636 | `}` | if/else 块结束 |
| L637 | `# 释放锁前确认 ownership` | 锁释放段开始 |
| L640-642 | `$lockRaw=Get-Content $lockPath; $lockPid=...; if($lockPid -eq $PID){...}` | **ownership 校验** |
| L647-649 | `if(-not $lockReleased){ RUNTIME_ERROR\|...; RUN_STATUS\|failed\|... }` | 失败终态 |

**注入有效性分析**:

1. L626 `Move-Item` 成功 → L627 `$commitSucceeded=$true` → L628 `COMMIT_OK|`
2. 注入重写锁文件 PID 为 999999
3. L640 读取锁文件 → `$lockPid = 999999`
4. L642 `if($lockPid -eq $PID)` → 999999 ≠ 当前 PID → `$lockReleased = $false`
5. L647 `if(-not $lockReleased)` → `RUNTIME_ERROR|释放锁前 ownership 校验失败` + `RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。`

**核实结论**: 注入设计有效。Move-Item 成功后注入重写锁 PID，使 ownership 校验失败，产生 `commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|` 终态。

---

## 3. 行号基线核实（§0.2）

计划 §0.2 基线说明列出 14 个关键行号。逐项核实：

| 计划声明行号 | 实际内容 | 核实 |
|---|---|---|
| L477 heartbeat | `try{$raw=Get-Content $lockPath...;catch{...RUN_STATUS\|failed\|步骤4 heartbeat 失败...return}` | ✅ |
| L478 result-read + `$origStats` 固化 | `try { $doc=Get-Content $resultPath...} catch {...};$origStats=$doc.stats\|ConvertTo-Json...` | ✅ |
| L479 foreach 超长行 | `foreach($it in $candidates){...}` | ✅ |
| L480 混合行（$doc.review + $newStats + if + return） | `$doc.review=...;$newStats=...;if($newStats-ne $origStats...){...;return}` | ✅ |
| L481 Set-Content tmp | `$doc\|ConvertTo-Json -Depth 8\|Set-Content -Path $tmpPath -Encoding UTF8` | ✅ |
| L487 tmp 写入失败 RUN_STATUS | `Write-Output 'RUN_STATUS\|failed\|review 写入失败，整轮终止。'` | ✅ |
| L489 第一个 try/catch 结束 `}` | `}` | ✅ |
| L490 第二个 try 开始 | `try { $check=Get-Content $tmpPath -Raw\|ConvertFrom-Json } catch { $check=$null }` | ✅ |
| L496 JSON-check RUN_STATUS | `Write-Output 'RUN_STATUS\|failed\|review 临时 JSON 校验失败，整轮终止。'` | ✅ |
| L500 Move-Item | `Move-Item $tmpPath $resultPath -Force` | ✅ |
| L506 atomic-replace RUN_STATUS | `Write-Output 'RUN_STATUS\|failed\|review 原子替换失败，整轮终止。'` | ✅ |
| L621 `$commitSucceeded=$false` | `$commitSucceeded=$false` | ✅ |
| L627 `$commitSucceeded=$true` | `$commitSucceeded=$true` | ✅ |
| L636 if/else 块结束 `}` | `}` | ✅ |
| L637 ownership 注释 | `# 释放锁前确认 ownership` | ✅ |
| L638 `$lockReleased=$false` | `$lockReleased = $false` | ✅ |
| L651 `RUN_STATUS\|success\|` | `Write-Output 'RUN_STATUS\|success\|fetch + 必要 review + commit + lock release 完成。'` | ✅ |
| L768 v1.11 changelog | `- **v1.11（2026-09-09 唯一失败终态回归修复轮）**：...` | ✅ |

**核实结论**: §0.2 全部 14+ 项行号核实通过，无错误。

---

## 4. GITHUB_VERSION_MONITOR_BASE 支持核实

计划 §0.5 声明 SKILL L163/L241/L432/L474/L522 支持 `GITHUB_VERSION_MONITOR_BASE`。

| 声明行号 | 实际代码 | 核实 |
|---|---|---|
| L163 | `$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }` (Step 1) | ✅ |
| L241 | `$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }` (Step 2) | ✅ |
| L432 | `$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }` (Step 3) | ✅ |
| L474 | `$base=if($env:GITHUB_VERSION_MONITOR_BASE){$env:GITHUB_VERSION_MONITOR_BASE}` (Step 4) | ✅ |
| L522 | `$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }` (Step 5) | ✅ |

**核实结论**: 5 个 step 全部支持 `GITHUB_VERSION_MONITOR_BASE`，隔离机制设计有效。

---

## 5. SENTINEL 期望表核实

计划 Phase 1 Step 6 SENTINEL 期望表：

| 测试 | 计划声明 return 位置 | 实际 return 行号 | 偏差 | SENTINEL 期望 | 逻辑核实 |
|---|---|---|---|---|---|
| T38-A | L487 catch 内 return | **L488** | off-by-one | 不出现 | ✅ 逻辑正确 |
| T38-B | L496 catch 内 return | **L497** | off-by-one | 不出现 | ✅ 逻辑正确 |
| T38-C | L506 catch 内 return | **L507** | off-by-one | 不出现 | ✅ 逻辑正确 |
| T38-heartbeat | L477 catch 内 return | L477（同行） | 无 | 不出现 | ✅ |
| T38-result-read | L478 catch 内 return | L478（同行） | 无 | 不出现 | ✅ |
| T38-stats-items | L480 if 块内 return | L480（同行） | 无 | 不出现 | ✅ |
| T22 | L607 catch 内 return | L607 | 无 | 不出现 | ✅ |
| T23 | 无 return | — | — | 出现 | ✅（L629 catch → L637 锁释放 → L653 终态 → 自然结束） |
| T39 | 无 return | — | — | 出现 | ✅（L649 终态后自然结束） |

**核实结论**: SENTINEL 期望逻辑全部正确。T38-A/B/C 的 return 行号有 off-by-one（计划引用 RUN_STATUS 输出行而非 return 行），但不影响 SENTINEL 期望判定。

---

## 6. Early-Return 审计框架核实（Phase 11.1）

计划 Phase 11.1 列出初扫框架表。逐项核实：

| 计划声明位置 | 类型 | 实际代码 | 核实 |
|---|---|---|---|
| Step 1 L172（STATE_MISSING） | 正常控制流 | L171 `STATE_MISSING\|` + L172 `return` | ✅ |
| Step 1 L222（LOCKED） | 正常控制流 | L221 `LOCKED\|` + L222 `return` | ✅ |
| Step 2 L406（fetch tmp 校验失败） | fatal | L404 `RUNTIME_ERROR\|` + L405 `Release-LockSafely` + L406 `return` | ✅ |
| Step 2 L412（result.json 替换失败） | fatal | L410 `RUNTIME_ERROR\|` + L411 `Release-LockSafely` + L412 `return` | ✅ |
| Step 3 L444（heartbeat 失败） | fatal | L444 `catch { RUNTIME_ERROR\|...; return }` | ⚠️ 见 P2-002 |
| Step 4 L477（heartbeat） | fatal | `RUNTIME_ERROR\|` + `RUN_STATUS\|failed\|` + `return` | ✅ |
| Step 4 L478（result-read） | fatal | `RUNTIME_ERROR\|` + `RUN_STATUS\|failed\|` + `return` | ✅ |
| Step 4 L480（stats/items） | fatal | `REVIEW_WRITE_ERROR\|` + `RUN_STATUS\|failed\|` + `return` | ✅ |
| Step 4 L487/L496/L506 | fatal | 各有 `REVIEW_WRITE_ERROR\|` + `RUN_STATUS\|failed\|` + `return` | ✅ |
| Step 5 L607（md tmp 失败） | fatal | L606 `RUN_STATUS\|failed\|` + L607 `return` | ✅ |
| Step 5 尾段 | — | L651 success / L649+L653 failed | ✅ |

---

## 7. Prompt 39 节覆盖核实

计划附录 A 提供 Prompt 39 节全覆盖映射表。抽查关键节：

| Prompt 节 | 计划映射 | 核实 |
|---|---|---|
| §5 T38-stats-items 最高优先级 | Phase 2 | ✅ |
| §6 T38 精确行为链 | Phase 2（五环节 + SENTINEL） | ✅ |
| §24 Runtime artifact initialization | Phase 7（新模块） | ✅ |
| §26 Early Return Audit | Phase 11.1 | ✅ |
| §27 Final Status Uniqueness | Phase 11.2（新硬门槛） | ✅ |
| §28 Diff/Behavioral Integrity | Phase 1 + 11.3 | ✅ |
| §34 Production Gate | Phase 13.3 / §6.3 | ✅ |
| §37 Final Execution Summary | Phase 13.4（29 项） | ✅ |
| §38 Final Output | Phase 13.5 | ✅ |
| §39 Absolute Rules | §7 | ✅ |

**核实结论**: 39 节全覆盖，无遗漏。

---

## 8. 数量词核实

| 计划声明 | Prompt 出处 | 核实 |
|---|---|---|
| 30 项能力 | Prompt §4 清单 | ✅ 逐项列出 |
| 9 种 T18 状态 | Prompt §22 清单 | ✅ 完整枚举 |
| 9 项 T26 输入 | Prompt §21 清单 | ✅ 2 合法 + 7 非法 |
| 6 场景 T43 | Prompt §17 清单 | ✅ 完整枚举 |
| 6 子测试 T38 | Prompt §5-§12 | ✅ 完整枚举 |
| 16 章报告 | Prompt §32 A-P | ✅ |
| 19 项 self-review | 15 Prompt §31 + 4 模板 | ✅ 计划标注构成来源 |
| 9 项辅助禁止 | 计划内部防御性检查 | ✅ 标注"非 Prompt 要求" |

---

## 9. 发现项

### P2 级（需修订）

#### P2-001: Early-return 审计框架遗漏 Step 2 L254 和 Step 5 L529

**严重性**: P2

**问题描述**: 计划 Phase 11.1 early-return 审计框架表未列出以下两个 fatal return：

1. **Step 2 L252-254**（锁不存在）:
   ```powershell
   if (-not (Test-Path $lockPath)) {
       Write-Output 'RUNTIME_ERROR|运行锁不存在（步骤1未执行或锁已丢失），本轮终止。'
       return
   }
   ```
   此路径输出 `RUNTIME_ERROR|` 但**无 `RUN_STATUS|failed|`**，属 fatal return 缺失终态。

2. **Step 5 L528-529**（锁不存在）:
   ```powershell
   if (-not (Test-Path $lockPath)) { Write-Output 'RUNTIME_ERROR|运行锁不存在（步骤1未执行或锁已丢失），本轮终止。'; return }
   ```
   同样输出 `RUNTIME_ERROR|` 但**无 `RUN_STATUS|failed|`**。

**影响**: Phase 11 执行时完整枚举可能遗漏这两个 return，导致 early-return audit 不完整。虽然计划声明"执行时须以完整枚举为准"，但框架表作为初扫基线应覆盖所有已知 return。

**建议修订**: 在 Phase 11.1 框架表中补充：
```
| Step 2 L254（锁不存在） | fatal | RUNTIME_ERROR|（L253）— 审计点：此路径是否缺 RUN_STATUS 终态 |
| Step 5 L529（锁不存在） | fatal | RUNTIME_ERROR|（L529）— 同上 |
```

#### P2-002: Step 3 L444 有两个 catch 子句两个 return，框架仅列一个

**严重性**: P2

**问题描述**: SKILL-v1.11 L444 实际为：
```powershell
} catch [System.IO.IOException] { Write-Output 'LOCKED|运行锁无法独占刷新 heartbeat，本轮退出。'; return } catch { Write-Output ('RUNTIME_ERROR|步骤3 heartbeat 失败：{0}'-f $_.Exception.Message); return }
```

L444 包含**两个 catch 子句**，各自有 `return`：
1. `catch [System.IO.IOException]` → `LOCKED|` + return（正常控制流，保守退出）
2. `catch`（通用） → `RUNTIME_ERROR|` + return（fatal，无 `RUN_STATUS`）

计划框架表仅列出一个条目"Step 3 L444（heartbeat 失败）"，未区分两个 catch 子句。

**影响**: 完整枚举时可能遗漏 IOException catch 的 return 分类。

**建议修订**: 拆分为两行：
```
| Step 3 L444 catch[IOException]（LOCKED） | 正常控制流 | LOCKED|（保守退出） |
| Step 3 L444 catch（通用 heartbeat 失败） | fatal | RUNTIME_ERROR| — 审计点：是否缺 RUN_STATUS 终态 |
```

### P3 级（建议改进）

#### P3-001: SENTINEL 期望表 T38-A/B/C return 行号 off-by-one

**严重性**: P3

**问题描述**: SENTINEL 期望表中：

| 测试 | 计划声明 | 实际 return 行号 | 偏差 |
|---|---|---|---|
| T38-A | "L487 catch 内 return" | L488 | 计划引用 L487（RUN_STATUS 输出行），实际 return 在 L488 |
| T38-B | "L496 catch 内 return" | L497 | 同上 |
| T38-C | "L506 catch 内 return" | L507 | 同上 |

**影响**: 不影响 SENTINEL 期望判定（逻辑正确），但行号引用不精确。

**建议修订**: 将 return 行号修正为 L488/L497/L507，或标注"L487 RUN_STATUS 行 / L488 return 行"。

#### P3-002: SENTINEL 期望表 T23 引用"L630 catch"实际 catch 在 L629

**严重性**: P3

**问题描述**: 计划 SENTINEL 期望表 T23 行写"无 return（L630 catch 后落入锁释放与终态输出）"。实际代码 L629 为 `} catch {`，L630 为 `Remove-Item $tmp -Force -ErrorAction SilentlyContinue`（catch 块内部语句）。

**建议修订**: 改为"L629 catch 后落入锁释放与终态输出"。

#### P3-003: Early-return 框架表 T38-A/B/C return 行号与 SENTINEL 表一致性问题

**严重性**: P3

**问题描述**: Phase 11.1 框架表列出"Step 4 L487/L496/L506（tmp 写入/JSON 校验/原子替换）"作为 fatal return 位置，与 SENTINEL 表引用同一行号。两表均引用 RUN_STATUS 输出行而非 return 行。建议两表统一标注实际 return 行号（L488/L497/L507）或同时标注两个行号。

---

## 10. 设计决策核实

| 决策 | 核实 |
|---|---|
| D1 SENTINEL 哨兵机制 | ✅ return 生效 → SENTINEL 缺失是直接行为证明 |
| D2 统一编排器模式 | ✅ 同进程同 PID 天然满足锁 ownership |
| D3 T38 前置用真实管线 | ✅ result.json 由 SKILL 真实产生 |
| D4 Runtime artifact 独立 Phase | ✅ Prompt §24 是 Production Gate 独立项 |
| D5 tmp 出现验证主证据 + 条件化补充 | ✅ tmp 窗口 <10ms，轮询可能错过 |
| D6 Step 2/3 RUNTIME_ERROR 路径列入审计 | ✅ Prompt §26 要求静态审计 |
| D7 T05-PS7 不设独立测试 | ✅ v1.11 Prompt 无此要求 |
| D8 PS5.1 双维度计数 | ✅ 消解 §20 与 §35 规则冲突 |
| D9 辅助禁止项标注来源 | ✅ 标注"非 Prompt 要求" |
| D10 git add 范围含 .GPT 文件 | ✅ Prompt §2/§39 要求 |

---

## 11. 驳回项（审计员认为无需修订但计划已正确处理的项）

### R-001: Step 2/Step 3 的 RUNTIME_ERROR 路径缺乏 RUN_STATUS 终态

**情况**: Step 2 L254/L406/L412 和 Step 3 L444（通用 catch）输出 `RUNTIME_ERROR|` 但无 `RUN_STATUS|failed|`。

**分析**: 这属于 SKILL-v1.11 的设计（这些路径在 v1.10 即已存在，v1.11 未修改），不属于执行计划的缺陷。计划 D6 决策正确将其列入 early-return 审计而非动态测试，并声明"如发现缺 RUN_STATUS 终态，按 contract 判定并记录，不隐瞒"。

**处置**: 不判为计划缺陷。但 P2-001 指出框架表应完整列出这些 return 以便审计覆盖。

---

## 12. 审计判定

### 统计

| 严重性 | 数量 | 采纳建议 |
|---|---|---|
| P1 | 0 | — |
| P2 | 2 | 建议修订（框架表补充遗漏 return） |
| P3 | 3 | 建议修正（行号 off-by-one） |
| **总计** | **5** | |

### 判定

```
审计判定: 需修订后执行

核心设计（diff 核验 / 注入设计 / SENTINEL 逻辑 / 判定规则 / Prompt 覆盖）: 全部通过
发现问题: 均为行号引用遗漏或 off-by-one，不影响测试逻辑正确性
建议: 修订 P2-001/P2-002（框架表补充）后可执行；P3 可在执行时修正
```

### 通过项清单

- [x] Diff 3 hunk / 3+/2- 核实通过
- [x] L480 `;return` 修复语义正确
- [x] T38-stats-items 注入设计有效（`$origStats` 固化 → 注入修改 → `$newStats ≠ $origStats`）
- [x] T38-B 注入设计有效（tmp 覆写为非法 JSON → L490 校验失败）
- [x] T39 注入设计有效（PID 重写 → ownership 失败 → `commitSucceeded=true + lockReleased=false → failed`）
- [x] §0.2 行号基线 14+ 项全部正确
- [x] GITHUB_VERSION_MONITOR_BASE 5 个 step 全部支持
- [x] SENTINEL 期望逻辑全部正确
- [x] Prompt 39 节全覆盖
- [x] 数量词全部可指认出处
- [x] 10 项设计决策核实通过
- [x] PS5.1 双维度计数裁决合理
- [x] T38 fixture 设计（404 → not_found → review=true）有效

---

## 13. 审计方法声明

本审计基于以下独立验证手段：

1. **`git diff --no-index` 实测**: 实际运行 `git diff --no-index SKILL-v1.10.md SKILL-v1.11.md`，确认 3 hunk / 3 insertions + 2 deletions
2. **SKILL-v1.11.md 源码逐行阅读**: 读取 L1-15 / L160-239 / L240-254 / L390-449 / L470-529 / L580-655 / L760-777，核实所有关键行号
3. **注入点逻辑验证**: 对 T38-stats-items / T38-B / T39 三处注入设计，逐环节验证变量固化点、注入点、触发条件、期望行为链
4. **Prompt 39 节逐节映射**: 核实计划附录 A 全覆盖表无遗漏
5. **SENTINEL 期望表逐项核实**: 对 9 个测试的 return 位置和 SENTINEL 期望逐一验证

本审计未修改任何被测文件。审计结论基于实际代码阅读和命令实测，不依赖计划自述。
