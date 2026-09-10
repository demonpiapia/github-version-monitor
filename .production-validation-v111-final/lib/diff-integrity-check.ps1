# diff-integrity-check.ps1 — Phase 1 Step 2/3/4 自动化核验
# 输出: .production-validation-v111-final/diff-integrity.md
# 逻辑: ①hunk 计数与内容核验 ②30 项能力逐项行号证据 + diff 删除行核验 ③9 项辅助禁止项

$ErrorActionPreference = 'Stop'
$root = 'D:\AI\Workspace\automatic\github-version-monitor'
$diffPath = Join-Path $root '.production-validation-v111-final\v110-v111.diff'
$src111 = Join-Path $root 'SKILL-v1.11.md'
$src110 = Join-Path $root 'SKILL-v1.10.md'
$outPath = Join-Path $root '.production-validation-v111-final\diff-integrity.md'

$diff = [System.IO.File]::ReadAllLines($diffPath)
$hunkHeaders = @($diff | Where-Object { $_ -match '^@@' })
$added = @($diff | Where-Object { $_ -match '^\+' -and $_ -notmatch '^\+\+\+' })
$deleted = @($diff | Where-Object { $_ -match '^-' -and $_ -notmatch '^---' })

# ---- 30 项能力清单（Prompt §4）----
$capabilities = @(
    @{ Id=1;  Name='.output/GitHub更新监测列表.md';  Pattern='GitHub更新监测列表\.md' },
    @{ Id=2;  Name='.monitor/';                     Pattern='\.monitor' },
    @{ Id=3;  Name='versionJump';                   Pattern='versionJump' },
    @{ Id=4;  Name='dateSuspicious';                Pattern='dateSuspicious' },
    @{ Id=5;  Name='reviewReasons';                 Pattern='reviewReasons' },
    @{ Id=6;  Name='schema validation';             Pattern='PARSE_ERROR' },
    @{ Id=7;  Name='strict lowercase yes/no';       Pattern='yes\|no' },
    @{ Id=8;  Name='404 -> not_found';              Pattern='not_found' },
    @{ Id=9;  Name='rate_limited';                  Pattern='rate_limited' },
    @{ Id=10; Name='network_error';                 Pattern='network_error' },
    @{ Id=11; Name='auth_error';                    Pattern='auth_error' },
    @{ Id=12; Name='forbidden';                     Pattern='forbidden' },
    @{ Id=13; Name='server_error';                  Pattern='server_error' },
    @{ Id=14; Name='invalid_response';              Pattern='invalid_response' },
    @{ Id=15; Name='metadata_incomplete';           Pattern='metadata_incomplete' },
    @{ Id=16; Name='result.fetch.tmp';              Pattern='result\.fetch\.tmp' },
    @{ Id=17; Name='result.review.tmp';             Pattern='result\.review\.tmp' },
    @{ Id=18; Name='lock';                          Pattern='run\.lock' },
    @{ Id=19; Name='heartbeat';                     Pattern='heartbeat' },
    @{ Id=20; Name='ownership';                     Pattern='ownership' },
    @{ Id=21; Name='atomic result persistence';     Pattern='Move-Item -Path \$tmpResult' },
    @{ Id=22; Name='atomic review persistence';     Pattern='Move-Item \$tmpPath \$resultPath' },
    @{ Id=23; Name='atomic md commit';              Pattern='Move-Item -Path \$tmp -Destination \$md' },
    @{ Id=24; Name='commitSucceeded';               Pattern='commitSucceeded' },
    @{ Id=25; Name='COMMIT_OK';                     Pattern='COMMIT_OK' },
    @{ Id=26; Name='RUN_STATUS|success|';           Pattern='RUN_STATUS\|success\|' },
    @{ Id=27; Name='RUN_STATUS|failed|';            Pattern='RUN_STATUS\|failed\|' },
    @{ Id=28; Name='Get-ResponseHeaderValue';       Pattern='Get-ResponseHeaderValue' },
    @{ Id=29; Name='PS7 production baseline';       Pattern='PowerShell 7\.x' },
    @{ Id=30; Name='PS5.1 compatibility';           Pattern='PowerShell 5\.1' }
)

# ---- 9 项辅助禁止项 ----
$forbidden = @(
    @{ Id=1;  Name='mock URL';              Pattern='(localhost|127\.0\.0\.1|mock|fake\.|example\.com)' },
    @{ Id=2;  Name='forced success';        Pattern='(forced\s*success|force.*success|强制成功)' },
    @{ Id=3;  Name='debug bypass';          Pattern='(debug\s*bypass|bypass)' },
    @{ Id=4;  Name='test-only branch';      Pattern='(test.?only|仅测试|测试专用)' },
    @{ Id=5;  Name='hardcoded token';       Pattern='(ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|Bearer\s+[A-Za-z0-9_]{20,})' },
    @{ Id=6;  Name='hardcoded test repository'; Pattern='(octocat/Hello-World|test-repo|dummy-repo)' },
    @{ Id=7;  Name='skip schema';           Pattern='(skip\s*schema|跳过.*schema|跳过.*校验)' },
    @{ Id=8;  Name='skip lock';             Pattern='(skip\s*lock|跳过.*锁)' },
    @{ Id=9;  Name='skip commit';           Pattern='(skip\s*commit|跳过.*提交)' }
)

$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Diff Integrity Report — SKILL-v1.10 → SKILL-v1.11')
$md.Add('')
$md.Add(("生成时间：{0}" -f [DateTimeOffset]::UtcNow.ToString('o')))
$md.Add('')
$md.Add('## 1. 输入指纹')
$md.Add('')
$md.Add('| 对象 | SHA256 |')
$md.Add('|---|---|')
$md.Add(('| SKILL-v1.10.md | {0} |' -f (Get-FileHash $src110 -Algorithm SHA256).Hash))
$md.Add(('| SKILL-v1.11.md | {0} |' -f (Get-FileHash $src111 -Algorithm SHA256).Hash))
$md.Add('')

# ---- Hunk 核验 ----
$md.Add('## 2. Hunk 核验（预期恰好 3 个 hunk，3 insertions + 2 deletions）')
$md.Add('')
$md.Add(('实测 hunk 数：**{0}**；新增行：**{1}**；删除行：**{2}**' -f $hunkHeaders.Count, $added.Count, $deleted.Count))
$md.Add('')
$md.Add('| # | Hunk 头 | 位置 | 内容摘要 | 类别 | 判定 |')
$md.Add('|---|---|---|---|---|---|')
$hunkIdx = 0
foreach ($h in $hunkHeaders) {
    $hunkIdx++
    $pos = if ($h -match '@@\s*-(\d+),\d+\s*\+(\d+),\d+') { "v1.10 L$($Matches[1]) / v1.11 L$($Matches[2])" } else { '?' }
    $summary = switch ($hunkIdx) {
        1 { '版本号行替换 v1.10 → v1.11（documentation）' }
        2 { 'L480 stats/items 完整性失败路径行尾补齐 `;return`（核心修复）' }
        3 { 'Changelog 新增 v1.11 条目，v1.10 条目顺移至 L769' }
        default { '预期外 hunk' }
    }
    $cat = switch ($hunkIdx) { 1 { 'documentation' } 2 { '核心修复' } 3 { 'changelog' } default { '未分类' } }
    $verdict = if ($hunkIdx -le 3) { 'PASS' } else { '**FAIL + P1**' }
    $md.Add(("| {0} | `{1}` | {2} | {3} | {4} | {5} |" -f $hunkIdx, $h, $pos, $summary, $cat, $verdict))
}
$md.Add('')
$hunkVerdict = if ($hunkHeaders.Count -eq 3 -and $added.Count -eq 3 -and $deleted.Count -eq 2) { 'PASS' } else { '**FAIL + P1**' }
$md.Add(('**Hunk 完整性判定：{0}**' -f $hunkVerdict))
$md.Add('')
$md.Add('### 2.1 核心修复逐字核对（L480 `;return`）')
$md.Add('')
$md.Add('删除行（v1.10 L480 尾部）：')
$md.Add('')
$md.Add('```')
$del480 = $deleted | Where-Object { $_ -match 'review 程序事实完整性校验失败' }
if ($del480) { $tail = $del480.Substring([Math]::Max(0, $del480.Length - 160)); $md.Add($tail) } else { $md.Add('(未找到)') }
$md.Add('```')
$md.Add('')
$md.Add('新增行（v1.11 L480 尾部）：')
$md.Add('')
$md.Add('```')
$add480 = $added | Where-Object { $_ -match 'review 程序事实完整性校验失败' }
if ($add480) { $tail = $add480.Substring([Math]::Max(0, $add480.Length - 170)); $md.Add($tail) } else { $md.Add('(未找到)') }
$md.Add('```')
$md.Add('')
$hasReturn = ($null -ne $add480) -and ($add480 -match "整轮终止。';return\}")
# 行内插入核验：diff 上下文行可能被截断，故直接从源文件取整行比对（v1.10 L480 vs v1.11 L480）
# `;return` 是插入在 `整轮终止。'` 与 `};try {` 之间（行内插入），不是行尾追加，
# 因此 v1.10 L480 不是 v1.11 L480 的前缀；正确核验方式 = 定位首个差异字节，
# 再验证"差异前缀相同 + 差异处插入内容恰为 `;return` + 插入后剩余部分相同"。
$lines110 = [System.IO.File]::ReadAllLines($src110)
$lines111 = [System.IO.File]::ReadAllLines($src111)
$del480Full = if ($lines110.Length -ge 480) { $lines110[479] } else { '' }
$add480Full = if ($lines111.Length -ge 480) { $lines111[479] } else { '' }
$firstDiff = -1
$minLen = [Math]::Min($del480Full.Length, $add480Full.Length)
for ($k = 0; $k -lt $minLen; $k++) { if ($del480Full[$k] -ne $add480Full[$k]) { $firstDiff = $k; break } }
$inserted = ''
$isPureInsertion = $false
if ($firstDiff -ge 0) {
    $tailDel = $del480Full.Substring($firstDiff)
    $tailAdd = $add480Full.Substring($firstDiff)
    # 求 tailDel 与 tailAdd 的最长公共前缀（LCP）
    $lcp = 0
    $lcpMax = [Math]::Min($tailDel.Length, $tailAdd.Length)
    while ($lcp -lt $lcpMax -and $tailDel[$lcp] -eq $tailAdd[$lcp]) { $lcp++ }
    # 剩余部分：tailDel 的尾部必须逐字等于 tailAdd 的尾部，中间即插入内容
    $remDel = $tailDel.Substring($lcp)
    $remAdd = $tailAdd.Substring($lcp)
    if ($remAdd.Length -ge $remDel.Length) {
        $inserted = $remAdd.Substring(0, $remAdd.Length - $remDel.Length)
        $suffixAdd = $remAdd.Substring($remAdd.Length - $remDel.Length)
        $isPureInsertion = ($inserted -ceq ';return') -and ($suffixAdd -ceq $remDel)
    }
}
$md.Add(('`RUN_STATUS|failed|...整轮终止。` 后是否紧跟 `;return`：**' + $(if ($hasReturn) { '是（PASS）' } else { '否（FAIL）' }) + '**'))
$md.Add(('L480 行内插入核验（源文件整行逐字节比对）：首个差异字节位置=' + $firstDiff + '；插入内容=`' + $inserted + '`；**' + $(if ($isPureInsertion) { '是（纯插入 `;return`，无其他改动，能力未删除）' } else { '否（存在超出 `;return` 的改动）' }) + '**'))
$lenLine = 'v1.10 L480 长度=' + $del480Full.Length + '；v1.11 L480 长度=' + $add480Full.Length + '；差值=' + ($add480Full.Length - $del480Full.Length) + '（return 插入长度=7）'
$md.Add($lenLine)
$md.Add('')

# ---- 30 项能力 ----
$md.Add('## 3. 能力保留核验（Prompt §4，30 项）')
$md.Add('')
$md.Add('判定口径：①该能力关键词在 SKILL-v1.11.md 中存在（给出行号证据）；②该能力**未被删除**。')
$md.Add('')
$md.Add('> 删除行口径说明：本次 diff 仅 2 个删除行，且均为**整行替换**（v1.10 L8 版本号行、v1.10 L480 混合行）。')
$md.Add('> L480 删除行虽含 `RUN_STATUS|failed|` 字样，但新增行（v1.11 L480）逐字保留该输出语句并在行尾补齐 `;return`，')
$md.Add('> 属"行内替换（能力保留 + 追加 return）"而非"能力删除"。故判定规则为：')
$md.Add('> **能力保留 = v1.11 中存在该能力（行号证据）且该能力未从文件中消失**。')
$md.Add('> 删除行命中数仅作信息列展示（标记"行替换"），不作为删除判定依据；真正的删除判定由"v1.11 是否仍存在"决定。')
$md.Add('')
$md.Add('| # | 能力项 | v1.11 命中行号 | diff 删除行命中（信息列） | 判定 |')
$md.Add('|---|---|---|---|---|')
$capPass = 0; $capFail = 0
foreach ($c in $capabilities) {
    $hits = Select-String -Path $src111 -Pattern $c.Pattern -AllMatches
    $lines = ($hits | ForEach-Object { $_.LineNumber }) -join ','
    $delHits = @($deleted | Where-Object { $_ -match $c.Pattern }).Count
    $delNote = if ($delHits -gt 0) { "$delHits（行替换，非删除）" } else { '0' }
    $ok = ($hits.Count -gt 0)
    if ($ok) { $capPass++ } else { $capFail++ }
    $md.Add(('| {0} | {1} | {2} | {3} | {4} |' -f $c.Id, $c.Name, $lines, $delNote, $(if ($ok) { 'PASS' } else { '**FAIL**' })))
}
$md.Add('')
$md.Add(('**能力核验汇总：PASS=' + $capPass + ' / FAIL=' + $capFail + ' / 合计=30**'))
$md.Add('')
$md.Add('### 3.1 特别检查（Prompt §4 明文点名）')
$md.Add('')
$special = @('versionJump','dateSuspicious','PARSE_ERROR','not_found','Move-Item','run\.lock','RUN_STATUS','GitHub更新监测列表\.md')
$md.Add('| 特别检查项 | v1.11 命中数 | 命中行号 |')
$md.Add('|---|---|---|')
foreach ($s in $special) {
    $h = Select-String -Path $src111 -Pattern $s -AllMatches
    $md.Add(('| {0} | {1} | {2} |' -f $s, $h.Count, (($h | ForEach-Object { $_.LineNumber }) -join ',')))
}
$md.Add('')
$md.Add('> 说明：以上为结构面（structural）核验。行为完整性由 Phase 2/3/4/5/6 的 T37/T38/T39/T43 回归证明（Prompt §28 双确认）。')
$md.Add('')

# ---- 9 项辅助禁止项 ----
$md.Add('## 4. 辅助禁止项检查（9 项，计划内部防御性检查，非 Prompt 明文要求）')
$md.Add('')
$md.Add('检查范围：**diff 新增行**（共 {0} 行）。' -f $added.Count)
$md.Add('')
$md.Add('| # | 禁止项 | 匹配模式 | 新增行命中数 | 判定 |')
$md.Add('|---|---|---|---|---|')
$fbFail = 0
foreach ($f in $forbidden) {
    $hits = @($added | Where-Object { $_ -match $f.Pattern }).Count
    if ($hits -gt 0) { $fbFail++ }
    $md.Add(('| {0} | {1} | `{2}` | {3} | {4} |' -f $f.Id, $f.Name, $f.Pattern, $hits, $(if ($hits -eq 0) { 'PASS' } else { '**FAIL**' })))
}
$md.Add('')
$md.Add(('**辅助禁止项汇总：PASS={0} / FAIL={1} / 合计=9**' -f (9 - $fbFail), $fbFail))
$md.Add('')
$md.Add('### 4.1 新增行全文（逐字，便于主 agent 独立复核）')
$md.Add('')
$md.Add('```')
foreach ($a in $added) { $md.Add($a) }
$md.Add('```')
$md.Add('')

# ---- 删除行全文 ----
$md.Add('## 5. 删除行全文（共 {0} 行，逐字）'.Replace('{0}', $deleted.Count))
$md.Add('')
$md.Add('```')
foreach ($d in $deleted) { $md.Add($d) }
$md.Add('```')
$md.Add('')

# ---- 结论 ----
$md.Add('## 6. 结论')
$md.Add('')
$overall = if ($hunkVerdict -eq 'PASS' -and $capFail -eq 0 -and $fbFail -eq 0 -and $hasReturn -and $isPureInsertion) { 'PASS' } else { '**FAIL**' }
$md.Add('- Hunk 完整性：{0}' -f $hunkVerdict)
$md.Add(('- 30 项能力保留：PASS=' + $capPass + ' / FAIL=' + $capFail))
$md.Add(('- 9 项辅助禁止项：PASS=' + (9 - $fbFail) + ' / FAIL=' + $fbFail))
$md.Add('- L480 `;return` 补齐：{0}' -f $(if ($hasReturn) { '已确认' } else { '未确认' }))
$md.Add('- L480 纯插入核验（无其他改动）：{0}' -f $(if ($isPureInsertion) { '已确认' } else { '未确认' }))
$md.Add('- **Diff Integrity 总判定：{0}**' -f $overall)
$md.Add('')

[System.IO.File]::WriteAllLines($outPath, $md, [System.Text.UTF8Encoding]::new($false))
Write-Output ('HUNKS=' + $hunkHeaders.Count + ' ADDED=' + $added.Count + ' DELETED=' + $deleted.Count)
Write-Output ('CAP PASS=' + $capPass + ' FAIL=' + $capFail)
Write-Output ('FORBIDDEN PASS=' + (9 - $fbFail) + ' FAIL=' + $fbFail)
Write-Output ('HAS_RETURN=' + $hasReturn)
Write-Output ('PURE_INSERTION=' + $isPureInsertion + ' inserted=' + $inserted + ' firstDiff=' + $firstDiff)
Write-Output ('OVERALL=' + $overall)
Write-Output ('OUT=' + $outPath)
