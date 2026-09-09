# Runtime Error Contract Static Audit — Early Return / Final Status

> **Phase**: 10.1
> **被测对象**: `SKILL-v1.10.md`
> **SHA256**: `4F7E1170B655F73C847B445570CB68DFDAEB5B4F2C6961AF19A946490123DA42`
> **审计时间**: 2026-09-09 09:18 +08:00
> **依据**: exec-plan-v1.10-d §2 Phase 10.1 + Prompt §19

---

## 1. 审计范围与约束

### 1.1 约束 #13（SKILL L81）

> 步骤 4 的不可恢复错误路径必须在清理/锁处理之后输出且仅输出一次 `RUN_STATUS|failed|`，不得以裸 `return` 作为最终状态。

**范围界定**：constraint #13 字面仅覆盖 **Step 4**（SKILL L472-L510）的不可恢复错误路径。Step 1-3 与 Step 5 的 `return` 语句不在 constraint #13 的字面范围内，但仍在本审计中列出以供完整覆盖。

### 1.2 审计方法

- 全文扫描 `return` 关键字（41 处匹配）
- 全文扫描 `RUN_STATUS|failed|`（13 处匹配）与 `RUN_STATUS|success|`（4 处匹配）
- 逐条分类：控制流退出 vs 函数返回值 vs 注释/文档引用
- 对每条控制流退出，确认是否伴随 `RUN_STATUS|failed|` 输出

---

## 2. 关键字扫描结果

### 2.1 `return` 语句分类（41 处）

| 类别 | 数量 | 说明 |
|---|---|---|
| 控制流退出（Step 1-5 顶层） | 13 | 整轮终止，需审计 RUN_STATUS 输出 |
| 函数返回值（`return $value`） | 22 | 非控制流退出，无需 RUN_STATUS |
| 注释/文档中的 `return` 引用 | 2 | 非代码，无需审计 |
| 内联函数定义中的 `return` | 4 | `Release-LockSafely` / `Compare-Ver` / `ConvertTo-UtcIso` / `Get-ResponseHeaderValue` |

### 2.2 `RUN_STATUS|failed|` 输出点（13 处）

| 行号 | 所在步骤 | 触发条件 | 伴随 `return`? |
|---|---|---|---|
| L477 | Step 4 | heartbeat 失败 | 是 |
| L478 | Step 4 | result.json 读取失败 | 是 |
| L480 | Step 4 | stats/items 完整性失败 | **否（移除）** |
| L487 | Step 4 | review tmp 写入失败 | 是 |
| L496 | Step 4 | review JSON 校验失败 | 是 |
| L506 | Step 4 | review 原子替换失败 | 是 |
| L606 | Step 5 | md tmp 写入/读取失败 | 是 |
| L648 | Step 5 | 锁释放失败（ownership 不匹配） | 否（if/else 末分支） |
| L653 | Step 5 | commitSucceeded=false（VALIDATE_ERROR 或 Move-Item 失败后） | 否（if/else 末分支） |
| L81 | 文档 | constraint #13 描述 | N/A |
| L124 | 文档 | §5.4 协议描述 | N/A |
| L768 | Changelog | v1.10 变更条目 | N/A |
| L769 | Changelog | v1.10 变更条目 | N/A |
| L770 | Changelog | v1.10 变更条目 | N/A |

> 注：13 处匹配含 5 处文档/Changelog 引用，实际代码中 `RUN_STATUS|failed|` 输出点为 **9 处**（L477/L478/L480/L487/L496/L506/L606/L648/L653）。

### 2.3 `RUN_STATUS|success|` 输出点（4 处）

| 行号 | 所在步骤 | 触发条件 |
|---|---|---|
| L651 | Step 5 | `$commitSucceeded=$true` 且 `$lockReleased=$true` |
| L79 | 文档 | constraint #11 描述 |
| L124 | 文档 | §5.4 协议描述 |
| L768 | Changelog | v1.10 变更条目 |

> 实际代码中 `RUN_STATUS|success|` 输出点为 **1 处**（L651）。

---

## 3. 逐条 `return` 审计

### 3.1 Step 1（L160-L231）— 2 处控制流退出

| 行号 | 上下文 | 前置输出 | 有 RUN_STATUS\|failed\|? | 判定 |
|---|---|---|---|---|
| L172 | `if (-not (Test-Path $md))` → STATE_MISSING | `STATE_MISSING\|状态文件不存在...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 1；SKILL L170 注释明确"不创建空清单"，此路径不建锁、不留副作用，无需 RUN_STATUS） |
| L222 | `if (-not $lockAcquired)` → LOCKED | `LOCKED\|另一轮监测持有运行锁...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 1；SKILL L233 明确"输出 LOCKED 时，本轮到此为止"） |

**结论**：Step 1 的 2 处 `return` 均为正常退出路径，不属于 constraint #13 覆盖范围。

### 3.2 Step 2（L239-L423）— 6 处控制流退出

| 行号 | 上下文 | 前置输出 | 有 RUN_STATUS\|failed\|? | 判定 |
|---|---|---|---|---|
| L254 | `if (-not (Test-Path $lockPath))` → 锁不存在 | `RUNTIME_ERROR\|运行锁不存在...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 2；锁不存在意味着 Step 1 未执行，无锁可释放） |
| L266 | `catch [System.IO.IOException]` → heartbeat 被独占 | `LOCKED\|运行锁被另一进程独占持有...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 2） |
| L269 | `catch` → heartbeat 其他失败 | `RUNTIME_ERROR\|锁 heartbeat 刷新失败...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 2） |
| L320 | `if($parseErrors.Count -gt 0 -or $repos.Count -eq 0)` → PARSE_ERROR | `PARSE_ERROR\|状态文件 schema 校验失败...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 2；SKILL L320 内联释放锁后 return） |
| L406 | `if($null -eq $check ...)` → result.fetch.tmp JSON 校验失败 | `RUNTIME_ERROR\|result.fetch.tmp JSON 结构校验失败...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 2；L405 调用 `Release-LockSafely` 释放锁） |
| L412 | `catch` → result.json 原子替换失败 | `RUNTIME_ERROR\|result.json 原子替换失败...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 2；L411 调用 `Release-LockSafely` 释放锁） |

**结论**：Step 2 的 6 处 `return` 均为正常退出路径，不属于 constraint #13 覆盖范围。

### 3.3 Step 3（L431-L452）— 2 处控制流退出（同一行 L444）

| 行号 | 上下文 | 前置输出 | 有 RUN_STATUS\|failed\|? | 判定 |
|---|---|---|---|---|
| L444 (catch IOException) | heartbeat 被独占 | `LOCKED\|运行锁无法独占刷新 heartbeat...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 3） |
| L444 (catch) | heartbeat 其他失败 | `RUNTIME_ERROR\|步骤3 heartbeat 失败...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 3） |

**结论**：Step 3 的 2 处 `return` 均为正常退出路径，不属于 constraint #13 覆盖范围。

### 3.4 Step 4（L472-L510）— 6 处控制流退出（constraint #13 覆盖范围）

| 行号 | 上下文 | 前置输出 | 有 RUN_STATUS\|failed\|? | 有 `return`? | 判定 |
|---|---|---|---|---|---|
| L477 | heartbeat 失败 | `RUNTIME_ERROR\|步骤4 heartbeat 失败...` + `RUN_STATUS\|failed\|步骤4 heartbeat 失败，整轮终止。` | 是 | 是 | **PASS** |
| L478 | result.json 读取失败 | `RUNTIME_ERROR\|读取 result.json 失败...` + `RUN_STATUS\|failed\|读取 result.json 失败，整轮终止。` | 是 | 是 | **PASS** |
| L480 | stats/items 完整性失败 | `REVIEW_WRITE_ERROR\|review 修改了 stats/items...` + `RUN_STATUS\|failed\|review 程序事实完整性校验失败，整轮终止。` | 是 | **否（移除）** | **FAIL — P1** |
| L488 | review tmp 写入失败 | `REVIEW_WRITE_ERROR\|review 临时文件写入失败...` + `RUN_STATUS\|failed\|review 写入失败，整轮终止。` | 是 | 是 | **PASS** |
| L497 | review JSON 校验失败 | `REVIEW_WRITE_ERROR\|review 临时 JSON 校验失败...` + `RUN_STATUS\|failed\|review 临时 JSON 校验失败，整轮终止。` | 是 | 是 | **PASS** |
| L507 | review 原子替换失败 | `REVIEW_WRITE_ERROR\|review 原子替换失败...` + `RUN_STATUS\|failed\|review 原子替换失败，整轮终止。` | 是 | 是 | **PASS** |

### 3.5 Step 5（L519-L654）— 3 处控制流退出

| 行号 | 上下文 | 前置输出 | 有 RUN_STATUS\|failed\|? | 判定 |
|---|---|---|---|---|
| L528 | `if (-not (Test-Path $lockPath))` → 锁不存在 | `RUNTIME_ERROR\|运行锁不存在...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 5；锁不存在意味着 Step 1 未执行） |
| L533 | `catch [System.IO.IOException]` → heartbeat 被独占 | `LOCKED\|运行锁被另一进程独占持有...` | 否 | **正常退出路径**（constraint #13 不覆盖 Step 5） |
| L606 | `catch` → md tmp 写入/读取失败 | `RUNTIME_ERROR\|主 md 临时文件写入/读取失败...` + `RUN_STATUS\|failed\|主 md 未提交。` | 是 | **PASS**（Step 5 的失败路径有终态输出） |

> 注：Step 5 的 L648/L651/L653 是 if/else 末分支（非 `return` 语句），但同样输出 RUN_STATUS 终态。

---

## 4. L480 落入行为分析（关键发现）

### 4.1 代码结构

```
L480: $doc.review=[PSCustomObject]@{...};
      $newStats=$doc.stats|ConvertTo-Json -Depth 8 -Compress;
      $newItems=$doc.items|ConvertTo-Json -Depth 8 -Compress;
      if($newStats -ne $origStats -or $newItems -ne $origItems){
          Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue
          Write-Output 'REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。'
          $released=Release-LockSafely
          if(-not $released){ Write-Output 'RUNTIME_ERROR|review stats/items 完整性失败后锁释放失败，保留锁供陈锁机制接管。' }
          Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。'
      }
      try {                              ← L480 的 if 块结束（无 return）
          $doc|ConvertTo-Json -Depth 8|Set-Content -Path $tmpPath -Encoding UTF8  ← L481
      } catch {
          ...
          Write-Output 'RUN_STATUS|failed|review 写入失败，整轮终止。'  ← L487
          return
      }
      try { $check=Get-Content $tmpPath -Raw|ConvertFrom-Json } catch { $check=$null }  ← L490
      if($null-eq $check -or ... -ne $origStats -or ... -ne $origItems){  ← L491
          ...
          Write-Output 'RUN_STATUS|failed|review 临时 JSON 校验失败，整轮终止。'  ← L496
          return
      }
      ...
      Move-Item $tmpPath $resultPath -Force  ← L500
      ...
```

### 4.2 落入行为链

当 L480 的完整性校验失败时：

1. **L480 执行**：输出 `REVIEW_WRITE_ERROR|` + `RUN_STATUS|failed|review 程序事实完整性校验失败`
2. **无 `return`**：执行落入 L481 `try { $doc|ConvertTo-Json ...|Set-Content -Path $tmpPath }`
3. **L481 执行**：`$doc` 此时已包含被注入修改的 stats/items，`Set-Content` 将修改后的 `$doc` 写入 `result.review.tmp`
4. **L490 执行**：`Get-Content $tmpPath -Raw|ConvertFrom-Json` 读取刚写入的 tmp 文件
5. **L491 执行**：检查 `$check.stats -ne $origStats` 或 `$check.items -ne $origItems`
   - 由于 `$doc.stats`/`$doc.items` 已被注入修改，`$check.stats`/`$check.items` 必然 ≠ `$origStats`/`$origItems`
   - 校验失败，进入 L492-L497 分支
6. **L492-L497 执行**：输出 `REVIEW_WRITE_ERROR|review 临时 JSON 校验失败` + `RUN_STATUS|failed|review 临时 JSON 校验失败`
7. **L497 `return`**：整轮终止

### 4.3 实际证据

T38-stats-items 测试的 stdout.txt 确认了此落入行为：

```
L40: REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。
L41: RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。
L42: REVIEW_WRITE_ERROR|review 临时 JSON 校验失败，不替换 result.json。
L43: RUNTIME_ERROR|review 失败后锁释放失败，保留锁供陈锁机制接管。
L44: RUN_STATUS|failed|review 临时 JSON 校验失败，整轮终止。
```

**`RUN_STATUS|failed|` 出现次数：2 次**（L41 + L44）

### 4.4 判定

**P1 发现 — constraint #13 违反**

- constraint #13 要求"仅输出一次 `RUN_STATUS|failed|`"
- L480 路径输出 2 次 `RUN_STATUS|failed|`（L41 完整性校验失败 + L44 JSON 校验失败）
- 根因：L480 的 `if` 块缺少 `return` 语句，导致执行落入后续 try 块
- 修复建议：在 L480 的 `Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。'` 之后添加 `return`

---

## 5. `RUN_STATUS|failed|` 重复输出审计

### 5.1 静态分析：所有 `RUN_STATUS|failed|` 输出点

| 输出点 | 可达路径 | 是否可能与其他输出点重复 | 分析 |
|---|---|---|---|
| L477 (heartbeat) | Step 4 入口 | 否 | `return` 终止，不可达后续输出点 |
| L478 (result-read) | Step 4 入口 | 否 | `return` 终止，不可达后续输出点 |
| L480 (stats-items) | Step 4 中段 | **是** | **无 `return`，落入 L481→L491→L496** |
| L487 (review-write) | Step 4 L481 catch | 否 | `return` 终止，不可达后续输出点 |
| L496 (review-json) | Step 4 L491 if | 否 | `return` 终止，不可达后续输出点 |
| L506 (review-move) | Step 4 L500 catch | 否 | `return` 终止，不可达后续输出点 |
| L606 (md-tmp) | Step 5 L592 catch | 否 | `return` 终止，不可达后续输出点 |
| L648 (lock-release) | Step 5 L646 if | 否 | if/else 互斥分支 |
| L653 (commit-fail) | Step 5 L651 else | 否 | if/else 互斥分支 |

### 5.2 重复输出风险矩阵

| 场景 | 输出点 A | 输出点 B | 是否可达 | 实际证据 |
|---|---|---|---|---|
| stats/items 完整性失败 | L480 | L496 | **是** | T38-stats-items stdout L41+L44 |
| heartbeat 失败 | L477 | 其他 | 否 | T38-heartbeat stdout 仅 L41 |
| result-read 失败 | L478 | 其他 | 否 | T38-result-read stdout 仅 L41 |
| review-write 失败 | L487 | 其他 | 否 | T38-A stdout 仅 L41 |
| review-json 失败 | L496 | 其他 | 否 | T38-B stdout 仅 L41 |
| review-move 失败 | L506 | 其他 | 否 | T38-C stdout 仅 L41 |
| md-tmp 失败 | L606 | 其他 | 否 | T22 stdout 仅 L42 |
| md-move 失败 | L630→L648/L653 | 其他 | 否 | T23 stdout 仅 L43 |

### 5.3 结论

**唯一重复输出风险**：L480（stats/items 完整性失败）→ L496（review JSON 校验失败）

- 静态分析：L480 无 `return`，执行必然落入 L481→L490→L491→L496
- 动态验证：T38-stats-items 测试确认 `RUN_STATUS|failed|` 出现 2 次
- **判定：P1 — constraint #13 违反**

---

## 6. 关键操作异常可控性审计

### 6.1 生产状态文件相关操作

| 操作 | 行号 | 异常处理 | tmp cleanup | lock handling | final status |
|---|---|---|---|---|---|
| `Set-Content` (result.fetch.tmp) | L400 | 无 try/catch（异常冒泡） | N/A | N/A | N/A |
| `Get-Content` (result.fetch.tmp) | L401 | `try/catch` → `$check=$null` | L403 `Remove-Item` | L405 `Release-LockSafely` | 无 RUN_STATUS（Step 2 正常退出） |
| `Move-Item` (result.fetch.tmp→result.json) | L408 | `try/catch` | L409 `Remove-Item` | L411 `Release-LockSafely` | 无 RUN_STATUS（Step 2 正常退出） |
| `Get-Content` (result.json) | L478 | `try/catch` | N/A | `Release-LockSafely` | `RUN_STATUS\|failed\|` ✓ |
| `Set-Content` (result.review.tmp) | L481 | `try/catch` | L483 `Remove-Item` | L484 `Release-LockSafely` | `RUN_STATUS\|failed\|` ✓ |
| `Get-Content` (result.review.tmp) | L490 | `try/catch` → `$check=$null` | N/A | N/A | N/A |
| `Move-Item` (result.review.tmp→result.json) | L500 | `try/catch` | L502 `Remove-Item` | L504 `Release-LockSafely` | `RUN_STATUS\|failed\|` ✓ |
| `Set-Content` (md.tmp) | L590 | `try/catch` | L593 `Remove-Item` | L596-L603 手动释放 | `RUN_STATUS\|failed\|` ✓ |
| `Move-Item` (md.tmp→md) | L625 | `try/catch` | L629 `Remove-Item` | L637-L645 手动释放 | `RUN_STATUS\|failed\|` ✓ (via L648/L653) |
| `[IO.File]::Open` (run.lock heartbeat) | L477 | `try/catch` | N/A | 不释放（heartbeat 失败即终止） | `RUN_STATUS\|failed\|` ✓ |
| `[IO.File]::Open` (run.lock heartbeat) | L530 | `try/catch` | N/A | 不释放（LOCKED 即终止） | 无 RUN_STATUS（Step 5 正常退出） |

### 6.2 异常可控性总结

- **Step 4 所有不可恢复错误路径**（6 条）均有 `RUN_STATUS|failed|` 输出 ✓
- **Step 4 L480 路径**缺少 `return`，导致落入后续 try 块 → 二次 `RUN_STATUS|failed|` 输出 ✗
- **Step 5 md 写入失败路径**有完整的 tmp cleanup + lock handling + `RUN_STATUS|failed|` ✓
- **Step 5 md 原子替换失败路径**通过 if/else 末分支输出 `RUN_STATUS|failed|` ✓

---

## 7. 审计结论

### 7.1 覆盖统计

| 指标 | 数量 |
|---|---|
| `return` 语句总数 | 41 |
| 控制流退出 `return` | 13 |
| 函数返回值 `return` | 22 |
| 注释/文档引用 | 2 |
| 内联函数定义 `return` | 4 |
| Step 4 控制流退出（constraint #13 范围） | 6 |
| Step 4 有 RUN_STATUS\|failed\| 的退出 | 6 |
| Step 4 有 `return` 的退出 | 5 |
| Step 4 缺少 `return` 的退出 | 1（L480） |
| `RUN_STATUS\|failed\|` 代码输出点 | 9 |
| 可能重复输出的路径 | 1（L480→L496） |

### 7.2 P1 发现

**P1-1：L480 stats/items 完整性失败路径缺少 `return`**

- **位置**：SKILL-v1.10.md L480
- **问题**：`if` 块输出 `RUN_STATUS|failed|` 后无 `return`，执行落入 L481 try 块
- **后果**：`RUN_STATUS|failed|` 输出 2 次（违反 constraint #13"仅输出一次"）
- **实际证据**：T38-stats-items stdout.txt L41+L44
- **严重性**：P1
- **修复建议**：在 L480 的 `Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。'` 之后添加 `return`

### 7.3 总体判定

**Runtime Error Contract Audit = FAIL**

- 5/6 Step 4 错误路径正确输出 `RUN_STATUS|failed|` 且有 `return` ✓
- 1/6 Step 4 错误路径（L480）输出 `RUN_STATUS|failed|` 但缺少 `return`，导致二次输出 ✗
- 所有 Step 5 错误路径正确输出 `RUN_STATUS|failed|` ✓
- 所有 Step 1-3 退出路径为正常退出，不受 constraint #13 约束 ✓
