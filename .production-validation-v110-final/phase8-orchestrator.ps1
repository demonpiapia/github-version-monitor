# phase8-orchestrator.ps1 - Phase 8 PS5.1 Compatibility Regression
# 目标：
#   T04-PS5.1 - 403 + X-RateLimit-Remaining=0  → rate_limited
#   T05-PS5.1 - 403 + X-RateLimit-Remaining>0  → forbidden
# 验证 Get-ResponseHeaderValue (SKILL L323-330) 在 System.Net.WebHeaderCollection 上的 PS5.1 行为。
# 执行环境：Windows + PowerShell 5.1（powershell.exe）
# 前置：Phase 1 (lib/step2.ps1, lib/mock-invoke-restmethod.ps1, lib/step2-mock-harness.ps1)
# 说明：PS5.1 FAIL 记录为 compatibility FAIL，不阻塞 PS7 production gate。

param([string]$ProjectRoot)

$ErrorActionPreference = 'Continue'
$global:TestResults = @{}

if (-not $ProjectRoot) { $ProjectRoot = 'D:\AI\Workspace\automatic\github-version-monitor' }
$pvDir = Join-Path $ProjectRoot '.production-validation-v110-final'
$libDir = Join-Path $pvDir 'lib'
$ps51Path = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

function Write-Log { param([string]$Msg) Write-Output ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $Msg) }

function Get-Sha256 {
    param([string]$Path)
    if (Test-Path $Path) { return (Get-FileHash $Path -Algorithm SHA256).Hash }
    return 'FILE_NOT_EXISTS'
}

# 使用 PS5.1 执行脚本，捕获 stdout 与 stderr
function Run-ScriptPS51 {
    param([string]$ScriptPath, [string]$StdoutFile, [string]$StderrFile, [string[]]$ArgList)
    $allArgs = @('-NoProfile','-NonInteractive','-File',$ScriptPath)
    if ($ArgList) { $allArgs += $ArgList }
    # PS5.1 与 PS7 兼容的 stderr→stdout 合并重定向
    & $ps51Path @allArgs 2>&1 > $StdoutFile
    $exit = $LASTEXITCODE
    if (-not (Test-Path $StderrFile)) { New-Item -ItemType File -Path $StderrFile -Force | Out-Null }
    return $exit
}

# 生成 fixture 副本（与 Phase 7 T04/T05 保持一致）
function New-TestFixture {
    param([string]$BaseDir, [string]$Flag = 'no')
    $outputDir = Join-Path $BaseDir '.output'
    if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }
    $mdPath = Join-Path $outputDir 'GitHub更新监测列表.md'
    $md = @"
# GitHub 项目版本监测列表

> 最近核对时间：2026-09-01 00:00（北京时间，本轮 0 项：latest API 成功 0 / 失败 0 / 待核 0；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---|---|---|---|---|
| 1 | [VS Code](https://github.com/microsoft/vscode/releases) |  |  | 0.0.1 | $Flag |

## 结论

（结论段：初始占位）

## 更新摘要

（更新摘要段：初始占位）

## 备注

（备注段：初始占位）

## 核对方法

（核对方法段：初始占位）
"@
    # PS5.1 兼容：使用 UTF-8 with BOM（PS5.1 Get-Content -Raw 默认 ANSI，无 BOM 时中文乱码）
    # 生产文件为 UTF-8 无 BOM，PS7 默认 UTF-8 可正常解析；PS5.1 需 BOM 才能正确读取
    $utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($mdPath, $md, $utf8Bom)
}

# 预置锁文件（step2 需要锁存在，否则 RUNTIME_ERROR）
function New-LockForStep2 {
    param([string]$BaseDir)
    $monitorDir = Join-Path $BaseDir '.monitor'
    if (-not (Test-Path $monitorDir)) { New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null }
    $lockPath = Join-Path $monitorDir 'run.lock'
    $nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
    Set-Content -Path $lockPath -Value ("pid={0};start={1};step=1;beat={2}" -f $PID, $nowUtc, $nowUtc) -Encoding UTF8
}

# 抓取 before/after 快照
function Capture-BeforeAfter {
    param([string]$TestDir, [string]$BaseDir)
    $mdPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md'
    $lockPath = Join-Path $BaseDir '.monitor\run.lock'
    $resultPath = Join-Path $BaseDir '.monitor\result.json'

    $mdBefore = Join-Path $TestDir 'md-before.md'
    $lockBefore = Join-Path $TestDir 'lock-before.txt'
    $resultBefore = Join-Path $TestDir 'result-before.json'
    if (Test-Path $mdPath) { Copy-Item $mdPath $mdBefore -Force } else { 'MD_FILE_NOT_EXISTS' | Set-Content $mdBefore -Encoding UTF8 }
    if (Test-Path $lockPath) { Get-Content $lockPath -Raw | Set-Content $lockBefore -Encoding UTF8 } else { 'LOCK_FILE_NOT_EXISTS' | Set-Content $lockBefore -Encoding UTF8 }
    if (Test-Path $resultPath) { Copy-Item $resultPath $resultBefore -Force } else { '{"note":"result.json not exists before run"}' | Set-Content $resultBefore -Encoding UTF8 }

    $shaBefore = Join-Path $TestDir 'sha256-before.txt'
    $sb = @()
    $sb += ("main_md: {0}" -f (Get-Sha256 $mdPath))
    $sb += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
    $sb += ("result.json: {0}" -f (Get-Sha256 $resultPath))
    $sb | Set-Content $shaBefore -Encoding UTF8
}

function Capture-After {
    param([string]$TestDir, [string]$BaseDir)
    $mdPath = Join-Path $BaseDir '.output\GitHub更新监测列表.md'
    $lockPath = Join-Path $BaseDir '.monitor\run.lock'
    $resultPath = Join-Path $BaseDir '.monitor\result.json'

    $mdAfter = Join-Path $TestDir 'md-after.md'
    $lockAfter = Join-Path $TestDir 'lock-after.txt'
    $resultAfter = Join-Path $TestDir 'result-after.json'
    if (Test-Path $mdPath) { Copy-Item $mdPath $mdAfter -Force } else { 'MD_FILE_NOT_EXISTS' | Set-Content $mdAfter -Encoding UTF8 }
    if (Test-Path $lockPath) { Get-Content $lockPath -Raw | Set-Content $lockAfter -Encoding UTF8 } else { 'LOCK_FILE_NOT_EXISTS' | Set-Content $lockAfter -Encoding UTF8 }
    if (Test-Path $resultPath) { Copy-Item $resultPath $resultAfter -Force } else { '{"note":"result.json not exists after run"}' | Set-Content $resultAfter -Encoding UTF8 }

    $shaAfter = Join-Path $TestDir 'sha256-after.txt'
    $sa = @()
    $sa += ("main_md: {0}" -f (Get-Sha256 $mdPath))
    $sa += ("run.lock: {0}" -f (Get-Sha256 $lockPath))
    $sa += ("result.json: {0}" -f (Get-Sha256 $resultPath))
    $sa | Set-Content $shaAfter -Encoding UTF8
}

# 运行 step2-mock-harness（PS5.1 环境）
function Run-MockHarnessPS51 {
    param([string]$TestDir, [string]$Scenario, [string]$BaseDir)
    $harness = Join-Path $libDir 'step2-mock-harness.ps1'
    $stdout = Join-Path $TestDir 'stdout.txt'
    $stderr = Join-Path $TestDir 'stderr.txt'
    $exit = Run-ScriptPS51 -ScriptPath $harness -StdoutFile $stdout -StderrFile $stderr `
        -ArgList @('-Scenario', $Scenario, '-BaseDir', $BaseDir)
    return $exit
}

# 从 stdout 提取 mock 调用日志
function Get-MockCalls {
    param([string]$StdoutPath)
    $log = @()
    if (Test-Path $StdoutPath) {
        $lines = Get-Content $StdoutPath
        foreach ($l in $lines) {
            if ($l -match '^MOCK_CALL\|') { $log += $l }
        }
    }
    return $log
}

# 从 result.json 提取首个 item 的字段
function Get-FirstItem {
    param([string]$ResultPath)
    if (-not (Test-Path $ResultPath)) { return $null }
    try {
        $doc = Get-Content $ResultPath -Raw | ConvertFrom-Json
        $items = @($doc.items)
        if ($items.Count -gt 0) { return $items[0] }
        return $null
    } catch {
        return $null
    }
}

# ============================================================
# PS5.1 可用性核验
# ============================================================
$startTime = Get-Date
$phase8Stdout = Join-Path $pvDir 'phase8-stdout.txt'
$phase8Stderr = Join-Path $pvDir 'phase8-stderr.txt'

Write-Log "Phase 8 PS5.1 Compatibility Regression Started"
Write-Log "ProjectRoot: $ProjectRoot"
Write-Log "PVDir: $pvDir"
Write-Log "PS5.1 Path: $ps51Path"

$ps51Available = Test-Path $ps51Path
$ps51Version = 'NOT_AVAILABLE'
if ($ps51Available) {
    $ps51Version = (& $ps51Path -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()')
    Write-Log "PS5.1 version: $ps51Version"
} else {
    Write-Log "PS5.1 NOT FOUND at $ps51Path"
}

# ============================================================
# T04-PS5.1: rate_limited Regression (403 + remaining=0)
# ============================================================
Write-Log "=== T04-PS5.1: rate_limited Regression (403 + remaining=0) ==="
$t04Dir = Join-Path $pvDir 'T04-PS5.1'
if (Test-Path $t04Dir) { Remove-Item $t04Dir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $t04Dir | Out-Null

$t04Verdict = 'BLOCKED'
$t04Status = ''
$t04HasRateLimited = $false
$t04Exit = -1
$t04LatestReqCount = 0
$t04ReviewReqCount = 0
$t04HtmlReqCount = 0
$t04RetryCount = 0
$t04CallCount = 0

if ($ps51Available) {
    New-TestFixture -BaseDir $t04Dir -Flag 'no'
    New-LockForStep2 -BaseDir $t04Dir
    Capture-BeforeAfter -TestDir $t04Dir -BaseDir $t04Dir

    $t04Exit = Run-MockHarnessPS51 -TestDir $t04Dir -Scenario 'rate_limited_403' -BaseDir $t04Dir
    Capture-After -TestDir $t04Dir -BaseDir $t04Dir

    $t04Stdout = Get-Content (Join-Path $t04Dir 'stdout.txt') -Raw -ErrorAction SilentlyContinue
    if (-not $t04Stdout) { $t04Stdout = '' }

    $t04Calls = Get-MockCalls -StdoutPath (Join-Path $t04Dir 'stdout.txt')
    $t04CallCount = $t04Calls.Count

    $t04ResultItem = Get-FirstItem -ResultPath (Join-Path $t04Dir 'result-after.json')
    $t04Status = if ($t04ResultItem) { $t04ResultItem.status } else { '' }
    $t04HasRateLimited = ($t04Status -eq 'rate_limited') -or ($t04Stdout -match 'rate_limited')

    foreach ($c in $t04Calls) {
        if ($c -match 'api\.github\.com/repos/[^/]+/[^/]+/releases/latest') { $t04LatestReqCount++ }
        if ($c -match '/reviews/|/comments/') { $t04ReviewReqCount++ }
        if ($c -match 'github\.com' -and $c -notmatch 'api\.github\.com') { $t04HtmlReqCount++ }
    }
    $t04RetryCount = [Math]::Max(0, $t04LatestReqCount - 1)

    # 判定 T04-PS5.1：与 T04-PS7 一致
    $t04Verdict = 'FAIL'
    if ($t04HasRateLimited -and $t04LatestReqCount -eq 1 -and $t04ReviewReqCount -eq 0 -and $t04HtmlReqCount -eq 0 -and $t04RetryCount -eq 0) {
        $t04Verdict = 'PASS'
    }
} else {
    Write-Log "T04-PS5.1: BLOCKED - PS5.1 not available"
}

Write-Log "T04-PS5.1: exit=$t04Exit status=$t04Status rateLimited=$t04HasRateLimited"
Write-Log "T04-PS5.1: latest=$t04LatestReqCount review=$t04ReviewReqCount html=$t04HtmlReqCount retry=$t04RetryCount total=$t04CallCount"
Write-Log "T04-PS5.1: verdict=$t04Verdict"
$global:TestResults['T04-PS5.1'] = @{
    Verdict = $t04Verdict
    Status = $t04Status
    HasRateLimited = $t04HasRateLimited
    LatestReqCount = $t04LatestReqCount
    ReviewReqCount = $t04ReviewReqCount
    HtmlReqCount = $t04HtmlReqCount
    RetryCount = $t04RetryCount
    TotalCallCount = $t04CallCount
    ExitCode = $t04Exit
}

# ============================================================
# T05-PS5.1: forbidden Regression (403 + remaining>0)
# ============================================================
Write-Log "=== T05-PS5.1: forbidden Regression (403 + remaining=50) ==="
$t05Dir = Join-Path $pvDir 'T05-PS5.1'
if (Test-Path $t05Dir) { Remove-Item $t05Dir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $t05Dir | Out-Null

$t05Verdict = 'BLOCKED'
$t05Status = ''
$t05HasForbidden = $false
$t05Exit = -1
$t05CallCount = 0

if ($ps51Available) {
    New-TestFixture -BaseDir $t05Dir -Flag 'no'
    New-LockForStep2 -BaseDir $t05Dir
    Capture-BeforeAfter -TestDir $t05Dir -BaseDir $t05Dir

    $t05Exit = Run-MockHarnessPS51 -TestDir $t05Dir -Scenario 'forbidden' -BaseDir $t05Dir
    Capture-After -TestDir $t05Dir -BaseDir $t05Dir

    $t05Stdout = Get-Content (Join-Path $t05Dir 'stdout.txt') -Raw -ErrorAction SilentlyContinue
    if (-not $t05Stdout) { $t05Stdout = '' }

    $t05Calls = Get-MockCalls -StdoutPath (Join-Path $t05Dir 'stdout.txt')
    $t05CallCount = $t05Calls.Count

    $t05ResultItem = Get-FirstItem -ResultPath (Join-Path $t05Dir 'result-after.json')
    $t05Status = if ($t05ResultItem) { $t05ResultItem.status } else { '' }
    $t05HasForbidden = ($t05Status -eq 'forbidden') -or ($t05Stdout -match 'forbidden')

    $t05Verdict = 'FAIL'
    if ($t05HasForbidden) { $t05Verdict = 'PASS' }
} else {
    Write-Log "T05-PS5.1: BLOCKED - PS5.1 not available"
}

Write-Log "T05-PS5.1: exit=$t05Exit status=$t05Status forbidden=$t05HasForbidden calls=$t05CallCount"
Write-Log "T05-PS5.1: verdict=$t05Verdict"
$global:TestResults['T05-PS5.1'] = @{
    Verdict = $t05Verdict
    Status = $t05Status
    HasForbidden = $t05HasForbidden
    TotalCallCount = $t05CallCount
    ExitCode = $t05Exit
}

# ============================================================
# 汇总
# ============================================================
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Log "=== Phase 8 Summary ==="
Write-Log "PS5.1 available: $ps51Available (version: $ps51Version)"
Write-Log ("T04-PS5.1: {0}" -f $global:TestResults['T04-PS5.1'].Verdict)
Write-Log ("T05-PS5.1: {0}" -f $global:TestResults['T05-PS5.1'].Verdict)
Write-Log ("Duration: {0:N1}s" -f $duration)

# 输出结构化 JSON 供后续生成报告使用
$summary = [PSCustomObject]@{
    Phase = 'Phase8'
    StartTime = $startTime.ToString('o')
    EndTime = $endTime.ToString('o')
    DurationSec = [Math]::Round($duration, 1)
    PS51Available = $ps51Available
    PS51Version = $ps51Version
    PS51Path = $ps51Path
    T04_PS51 = [PSCustomObject]@{
        Verdict = $global:TestResults['T04-PS5.1'].Verdict
        Status = $global:TestResults['T04-PS5.1'].Status
        HasRateLimited = $global:TestResults['T04-PS5.1'].HasRateLimited
        LatestReqCount = $global:TestResults['T04-PS5.1'].LatestReqCount
        ReviewReqCount = $global:TestResults['T04-PS5.1'].ReviewReqCount
        HtmlReqCount = $global:TestResults['T04-PS5.1'].HtmlReqCount
        RetryCount = $global:TestResults['T04-PS5.1'].RetryCount
        TotalCallCount = $global:TestResults['T04-PS5.1'].TotalCallCount
        ExitCode = $global:TestResults['T04-PS5.1'].ExitCode
    }
    T05_PS51 = [PSCustomObject]@{
        Verdict = $global:TestResults['T05-PS5.1'].Verdict
        Status = $global:TestResults['T05-PS5.1'].Status
        HasForbidden = $global:TestResults['T05-PS5.1'].HasForbidden
        TotalCallCount = $global:TestResults['T05-PS5.1'].TotalCallCount
        ExitCode = $global:TestResults['T05-PS5.1'].ExitCode
    }
    CompatibilityFailBlocksPS7Gate = $false
}
$summary | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $pvDir 'phase8-summary.json') -Encoding UTF8
Write-Log "Summary JSON written to phase8-summary.json"
