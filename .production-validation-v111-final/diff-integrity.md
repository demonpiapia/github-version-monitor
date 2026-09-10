# Diff Integrity Report — SKILL-v1.10 → SKILL-v1.11

生成时间：2026-09-09T07:57:09.6904990+00:00

## 1. 输入指纹

| 对象 | SHA256 |
|---|---|
| SKILL-v1.10.md | 4F7E1170B655F73C847B445570CB68DFDAEB5B4F2C6961AF19A946490123DA42 |
| SKILL-v1.11.md | B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928 |

## 2. Hunk 核验（预期恰好 3 个 hunk，3 insertions + 2 deletions）

实测 hunk 数：**3**；新增行：**3**；删除行：**2**

| # | Hunk 头 | 位置 | 内容摘要 | 类别 | 判定 |
|---|---|---|---|---|---|
| 1 | @@ -5,7 +5,7 @@ description: GitHub 项目版本监测（自动化版·纯 PowerShell）—— | v1.10 L5 / v1.11 L5 | 版本号行替换 v1.10 → v1.11（documentation） | documentation | PASS |
| 2 | @@ -477,7 +477,7 @@ function Release-LockSafely { try{$raw=Get-Content $lockPath -Raw -ErrorAction S | v1.10 L477 / v1.11 L477 | L480 stats/items 完整性失败路径行尾补齐 `;return`（核心修复） | 核心修复 | PASS |
| 3 | @@ -765,6 +765,7 @@ FETCH_COMPLETE | v1.10 L765 / v1.11 L765 | Changelog 新增 v1.11 条目，v1.10 条目顺移至 L769 | changelog | PASS |

**Hunk 完整性判定：PASS**

### 2.1 核心修复逐字核对（L480 `;return`）

删除行（v1.10 L480 尾部）：

```
ely;if(-not $released){Write-Output 'RUNTIME_ERROR|review stats/items 完整性失败后锁释放失败，保留锁供陈锁机制接管。'};Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。'};try {
```

新增行（v1.11 L480 尾部）：

```
Safely;if(-not $released){Write-Output 'RUNTIME_ERROR|review stats/items 完整性失败后锁释放失败，保留锁供陈锁机制接管。'};Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。';return};try {
```

`RUN_STATUS|failed|...整轮终止。` 后是否紧跟 `;return`：**是（PASS）**
L480 行内插入核验（源文件整行逐字节比对）：首个差异字节位置=545；插入内容=`;return`；**是（纯插入 `;return`，无其他改动，能力未删除）**
v1.10 L480 长度=552；v1.11 L480 长度=559；差值=7（return 插入长度=7）

## 3. 能力保留核验（Prompt §4，30 项）

判定口径：①该能力关键词在 SKILL-v1.11.md 中存在（给出行号证据）；②该能力**未被删除**。

> 删除行口径说明：本次 diff 仅 2 个删除行，且均为**整行替换**（v1.10 L8 版本号行、v1.10 L480 混合行）。
> L480 删除行虽含 `RUN_STATUS|failed|` 字样，但新增行（v1.11 L480）逐字保留该输出语句并在行尾补齐 `;return`，
> 属"行内替换（能力保留 + 追加 return）"而非"能力删除"。故判定规则为：
> **能力保留 = v1.11 中存在该能力（行号证据）且该能力未从文件中消失**。
> 删除行命中数仅作信息列展示（标记"行替换"），不作为删除判定依据；真正的删除判定由"v1.11 是否仍存在"决定。

| # | 能力项 | v1.11 命中行号 | diff 删除行命中（信息列） | 判定 |
|---|---|---|---|---|
| 1 | .output/GitHub更新监测列表.md | 3,37,85,92,166,171,245,525,678,681,757,771 | 0 | PASS |
| 2 | .monitor/ | 37,156,167,237,246,435,445,446,475,526,714,716 | 0 | PASS |
| 3 | versionJump | 77,108,118,119,381,734,772 | 0 | PASS |
| 4 | dateSuspicious | 77,108,118,120,381,734,772 | 0 | PASS |
| 5 | reviewReasons | 108,381,479,772 | 0 | PASS |
| 6 | schema validation | 92,237,320,425,691,712 | 0 | PASS |
| 7 | strict lowercase yes/no | 74,97,108,319,612 | 0 | PASS |
| 8 | 404 -> not_found | 71,117,133,362,380,381,733,755,772,774 | 0 | PASS |
| 9 | rate_limited | 42,76,115,134,237,363,364,427,466,479,772 | 0 | PASS |
| 10 | network_error | 136,367 | 0 | PASS |
| 11 | auth_error | 139,361,427 | 0 | PASS |
| 12 | forbidden | 140,364,427 | 0 | PASS |
| 13 | server_error | 135,365 | 0 | PASS |
| 14 | invalid_response | 137,351 | 0 | PASS |
| 15 | metadata_incomplete | 138,348 | 0 | PASS |
| 16 | result.fetch.tmp | 398,404,772 | 0 | PASS |
| 17 | result.review.tmp | 469,475,724,769,770,774 | 0 | PASS |
| 18 | lock | 194,251,437,470,475,528,695,720,774 | 0 | PASS |
| 19 | heartbeat | 158,191,192,237,250,268,436,444,477,527,692,712,720,749,769,776 | 0 | PASS |
| 20 | ownership | 436,440,477,637,648,692,772,774 | 0 | PASS |
| 21 | atomic result persistence | 408 | 0 | PASS |
| 22 | atomic review persistence | 500 | 0 | PASS |
| 23 | atomic md commit | 626 | 0 | PASS |
| 24 | commitSucceeded | 79,124,621,627,650,770,771 | 0 | PASS |
| 25 | COMMIT_OK | 79,124,628,697,705,771 | 0 | PASS |
| 26 | RUN_STATUS|success| | 79,124,651,771 | 0 | PASS |
| 27 | RUN_STATUS|failed| | 81,124,477,478,480,487,496,506,606,649,653,768,769,770 | 1（行替换，非删除） | PASS |
| 28 | Get-ResponseHeaderValue | 324,358,772 | 0 | PASS |
| 29 | PS7 production baseline | 9,772 | 0 | PASS |
| 30 | PS5.1 compatibility | 9,772 | 0 | PASS |

**能力核验汇总：PASS=30 / FAIL=0 / 合计=30**

### 3.1 特别检查（Prompt §4 明文点名）

| 特别检查项 | v1.11 命中数 | 命中行号 |
|---|---|---|
| versionJump | 7 | 77,108,118,119,381,734,772 |
| dateSuspicious | 7 | 77,108,118,120,381,734,772 |
| PARSE_ERROR | 6 | 92,237,320,425,691,712 |
| not_found | 10 | 71,117,133,362,380,381,733,755,772,774 |
| Move-Item | 19 | 216,248,320,403,408,409,451,476,480,483,492,500,502,594,601,626,630,634,643 |
| run\.lock | 9 | 194,251,437,470,475,528,695,720,774 |
| RUN_STATUS | 19 | 79,81,124,477,478,480,487,496,506,606,649,651,653,697,768,769,770,771,772 |
| GitHub更新监测列表\.md | 12 | 3,37,85,92,166,171,245,525,678,681,757,771 |

> 说明：以上为结构面（structural）核验。行为完整性由 Phase 2/3/4/5/6 的 T37/T38/T39/T43 回归证明（Prompt §28 双确认）。

## 4. 辅助禁止项检查（9 项，计划内部防御性检查，非 Prompt 明文要求）

检查范围：**diff 新增行**（共 3 行）。

| # | 禁止项 | 匹配模式 | 新增行命中数 | 判定 |
|---|---|---|---|---|
| 1 | mock URL | `(localhost|127\.0\.0\.1|mock|fake\.|example\.com)` | 0 | PASS |
| 2 | forced success | `(forced\s*success|force.*success|强制成功)` | 0 | PASS |
| 3 | debug bypass | `(debug\s*bypass|bypass)` | 0 | PASS |
| 4 | test-only branch | `(test.?only|仅测试|测试专用)` | 0 | PASS |
| 5 | hardcoded token | `(ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|Bearer\s+[A-Za-z0-9_]{20,})` | 0 | PASS |
| 6 | hardcoded test repository | `(octocat/Hello-World|test-repo|dummy-repo)` | 0 | PASS |
| 7 | skip schema | `(skip\s*schema|跳过.*schema|跳过.*校验)` | 0 | PASS |
| 8 | skip lock | `(skip\s*lock|跳过.*锁)` | 0 | PASS |
| 9 | skip commit | `(skip\s*commit|跳过.*提交)` | 0 | PASS |

**辅助禁止项汇总：PASS=9 / FAIL=0 / 合计=9**

### 4.1 新增行全文（逐字，便于主 agent 独立复核）

```
+> 版本：v1.11
+$doc.review=[PSCustomObject]@{performed=$true;items=@($reviewItems)};$newStats=$doc.stats|ConvertTo-Json -Depth 8 -Compress;$newItems=$doc.items|ConvertTo-Json -Depth 8 -Compress;if($newStats-ne $origStats-or $newItems-ne $origItems){Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue;Write-Output 'REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。';$released=Release-LockSafely;if(-not $released){Write-Output 'RUNTIME_ERROR|review stats/items 完整性失败后锁释放失败，保留锁供陈锁机制接管。'};Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。';return};try {
+- **v1.11（2026-09-09 唯一失败终态回归修复轮）**：①修复 v1.10 T38-stats-items P1：Step 4 `stats/items` 程序事实完整性失败分支在输出 `RUN_STATUS|failed|` 后补齐 `return`，阻止落入后续 JSON 校验路径 ②确保该失败路径只输出一次 `RUN_STATUS|failed|`，满足 constraint #13 的唯一最终终态要求 ③其余 v1.10 行为与生产路径保持不变。
```

## 5. 删除行全文（共 2 行，逐字）

```
-> 版本：v1.10
-$doc.review=[PSCustomObject]@{performed=$true;items=@($reviewItems)};$newStats=$doc.stats|ConvertTo-Json -Depth 8 -Compress;$newItems=$doc.items|ConvertTo-Json -Depth 8 -Compress;if($newStats-ne $origStats-or $newItems-ne $origItems){Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue;Write-Output 'REVIEW_WRITE_ERROR|review 修改了 stats/items，拒绝覆盖 result.json。';$released=Release-LockSafely;if(-not $released){Write-Output 'RUNTIME_ERROR|review stats/items 完整性失败后锁释放失败，保留锁供陈锁机制接管。'};Write-Output 'RUN_STATUS|failed|review 程序事实完整性校验失败，整轮终止。'};try {
```

## 6. 结论

- Hunk 完整性：PASS
- 30 项能力保留：PASS=30 / FAIL=0
- 9 项辅助禁止项：PASS=9 / FAIL=0
- L480 `;return` 补齐：已确认
- L480 纯插入核验（无其他改动）：已确认
- **Diff Integrity 总判定：PASS**

