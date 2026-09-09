# step5-t39-harness.ps1 - T39 同进程 harness
# 设计原因：SKILL Step 5 中 $commitSucceeded (L621/L627) 与 $lockReleased (L638/L644) 是同进程局部变量。
# pwsh -File 模式下跨脚本无法传递变量。dot-source step5-full.ps1 会一次性连续执行完整 Step 5，
# 不存在"执行至 Move-Item 成功后暂停"的注入点。因此采用内联复制 + 精确注入方式。
#
# 注入点：SKILL L636 (`}` — if/else 块整体结束) 与 L637 (`# 释放锁前确认 ownership`) 之间。
# 注入内容：模拟锁被外来 PID 持有，使后续锁释放段 ownership 校验失败。
#
# 前置变量：$conclusionText / $summaryText / $noteText（SKILL L539-547 占位值），
#           由本 harness 在 dot-source 前预置，否则 Step 5 md 组装失败。
#
# 受限 diff 规则（Phase 11 复核）：与 SKILL Step 5 代码块仅允许存在一处注入差异
# （L636/L637 之间的 PID 修改），其余代码须逐字一致。

$ErrorActionPreference = 'Stop'
$base = if ($env:GITHUB_VERSION_MONITOR_BASE) { $env:GITHUB_VERSION_MONITOR_BASE }
        elseif ($PSScriptRoot) { $PSScriptRoot }
        else { 'D:\AI\Workspace\automatic\github-version-monitor' }
$md = Join-Path (Join-Path $base '.output') 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'
$lockPath = Join-Path $monitorDir 'run.lock'

# 前置变量：$conclusionText / $summaryText / $noteText（SKILL L539-547 占位值）
$conclusionText = @"
（结论段：T39 同进程 harness 占位）
"@
$summaryText = @"
（更新摘要段：T39 同进程 harness 占位）
"@
$noteText = @"
（备注段：T39 同进程 harness 占位）
"@

# 锁存在性验证 + heartbeat 保活（SKILL L527-L534 等价）
if (-not (Test-Path $lockPath)) { Write-Output 'RUNTIME_ERROR|运行锁不存在（步骤1未执行或锁已丢失），本轮终止。'; return }
try {
    $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $fs.Close()
    (Get-Item $lockPath).LastWriteTime = Get-Date
} catch [System.IO.IOException] { Write-Output 'LOCKED|运行锁被另一进程独占持有（异常并发），本轮退出。'; return }
$result = Get-Content (Join-Path $monitorDir 'result.json') -Raw | ConvertFrom-Json
$items = @($result.items); $stats = $result.stats

# 元信息行
$beijingNow = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd HH:mm')
$metaLine = ('> 最近核对时间：{0}（北京时间，本轮 {1} 项：latest API 成功 {2} / 失败 {3} / 待核 {4}；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）' -f
    $beijingNow, $stats.total, $stats.apiOk, $stats.apiErr, $stats.pendingReview)

# 表格行程序改写 + 三节正文替换
$lines = Get-Content $md
$outLines = New-Object System.Collections.Generic.List[string]
$skip = $false; $pending = $null
foreach ($ln in $lines) {
    if ($ln -match '^##\s*(?<t>.+)$') {
        if ($skip) { $outLines.Add(''); $outLines.AddRange(($pending -split "`r?`n")); $outLines.Add(''); $skip = $false; $pending = $null }
        $t = $Matches['t'].Trim()
        $outLines.Add($ln)
        switch ($t) {
            '结论'     { $skip = $true; $pending = $conclusionText }
            '更新摘要' { $skip = $true; $pending = $summaryText }
            '备注'     { $skip = $true; $pending = $noteText }
        }
        continue
    }
    if ($skip) { continue }
    if ($ln -match '^\s*\|' -and $ln -match '\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)') {
        $repoKey = '{0}/{1}' -f $Matches[1], $Matches[2]
        $it = $items | Where-Object { $_.repo -eq $repoKey }
        if ($it) {
            $c = ($ln.Trim().Trim('|') -split '\|') | ForEach-Object { $_.Trim() }
            $outLines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} |' -f $c[0], $c[1], $it.gitVer, $it.gitDate, $c[4], $it.flag))
        } else { $outLines.Add($ln) }
        continue
    }
    if ($ln -match '最近核对时间') { $outLines.Add($metaLine); continue }
    $outLines.Add($ln)
}
if ($skip) { $outLines.Add(''); $outLines.AddRange(($pending -split "`r?`n")); $outLines.Add('') }
$newText = ($outLines -join "`r`n") + "`r`n"

# 事务式写入：临时文件 → 结构校验 → 原子替换
$tmp = "$md.tmp"
try {
    Set-Content -Path $tmp -Value $newText -Encoding UTF8 -NoNewline
    $check = Get-Content $tmp -Raw -ErrorAction Stop
} catch {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Output ('RUNTIME_ERROR|主 md 临时文件写入/读取失败：{0}' -f $_.Exception.Message)
    $lockReleased = $false
    try {
        $lockRaw = Get-Content $lockPath -Raw -ErrorAction Stop
        $lockPid = if ($lockRaw -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
        if ($lockPid -eq $PID) {
            Remove-Item $lockPath -Force -ErrorAction Stop
            $lockReleased = -not (Test-Path $lockPath)
        }
    } catch { $lockReleased = $false }
    if (-not $lockReleased) { Write-Output 'RUNTIME_ERROR|主 md 临时文件失败后锁释放失败，保留锁供陈锁机制接管。' }
    Write-Output 'RUN_STATUS|failed|主 md 未提交。'
    return
}
$rows2 = @(($check -split "`r?`n") | Where-Object { $_ -match '^\s*\|\s*\d+\s*\|' })
$badFlag = @($rows2 | Where-Object {
    $cells = @($_.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
    $cells.Count -ne 6 -or $cells[5] -cnotmatch '^(yes|no)$'
})
$mdRepos = @($rows2 | ForEach-Object {
    if ($_ -match '\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)') { '{0}/{1}' -f $Matches[1], $Matches[2] }
}) | Sort-Object
$jsonRepos = @($items | ForEach-Object { $_.repo }) | Sort-Object
$repoMatch=($mdRepos.Count -eq $jsonRepos.Count)-and(-not(Compare-Object $mdRepos $jsonRepos))
$anchorsOk=($check -match '## 监测列表')-and($check -match '## 结论')-and($check -match '## 更新摘要')-and($check -match '## 备注')-and($check -match '## 核对方法')
$commitSucceeded=$false
$header='| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$headerOk=($check -split "`r?`n"|Where-Object{$_.Trim() -ceq $header}).Count -eq 1
if ($rows2.Count -eq $items.Count -and $badFlag.Count -eq 0 -and $repoMatch -and $headerOk -and $anchorsOk) {
    try {
        Move-Item -Path $tmp -Destination $md -Force
        $commitSucceeded=$true
        Write-Output "COMMIT_OK|已原子替换主 md（数据行 $($rows2.Count)，yes/no 校验通过，repo 集合一致）。"
    } catch {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        Write-Output ('RUNTIME_ERROR|主 md 原子替换失败：{0}' -f $_.Exception.Message)
    }
} else {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Output ("VALIDATE_ERROR|临时文件结构校验未过（数据行 {0} vs 应有 {1}，非法 flag 行 {2}，repo 集合一致={3}），不替换主 md；主 md 与备份保持原状。" -f $rows2.Count, $items.Count, $badFlag.Count, $repoMatch)
}

# ==== T39 注入：模拟锁被外来 PID 持有 ====
Set-Content $lockPath -Value "pid=999999;ts=$(Get-Date -Format o)" -Force
# ==== T39 注入结束 ====

# 释放锁前确认 ownership：锁内 PID 必须等于当前进程 PID
$lockReleased = $false
try {
    $lockRaw = Get-Content $lockPath -Raw -ErrorAction Stop
    $lockPid = if ($lockRaw -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
    if ($lockPid -eq $PID) {
        Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
        $lockReleased = $true
    }
} catch { $lockReleased = $false }
if (-not $lockReleased) {
    Write-Output 'RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。'
    Write-Output 'RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。'
} elseif ($commitSucceeded) {
    Write-Output 'RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。'
} else {
    Write-Output 'RUN_STATUS|failed|主 md 未提交。'
}
