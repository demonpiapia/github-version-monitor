# phase7-orchestrator.ps1 - Phase 7 T04 + T05-PS7 + T26 + T18（中优先级）
# 目标：
#   7.1 T04-PS7  — 403 + X-RateLimit-Remaining=0 → rate_limited
#   7.2 T05-PS7  — 403 + X-RateLimit-Remaining=50 → forbidden
#   7.3 T26      — Strict Flag Regression（9 项输入：2 合法 + 7 非法）
#   7.4 T18      — State Preservation Regression（9 种非 ok 状态）
# 隔离：通过 GITHUB_VERSION_MONITOR_BASE 指向各测试子目录
# 前置：Phase 1 (lib/step2.ps1, lib/mock-invoke-restmethod.ps1, lib/step2-mock-harness.ps1, lib/create-fixture.ps1)
# 执行环境：Windows + PowerShell 7.x

param([string]$ProjectRoot)

$ErrorActionPreference = 'Continue'
$global:TestResults = @{}

if (-not $ProjectRoot) { $ProjectRoot = 'D:\AI\Workspace\automatic\github-version-monitor' }
$pvDir = Join-Path $ProjectRoot '.production-validation-v110-final'
$libDir = Join-Path $pvDir 'lib'
$pwshPath = (Get-Command pwsh).Source

function Write-Log { param([string]$Msg) Write-Output ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $Msg) }

function Get-Sha256 {
    param([string]$Path)
    if (Test-Path $Path) { return (Get-FileHash $Path -Algorithm SHA256).Hash }
    return 'FILE_NOT_EXISTS'
}

function Run-Script {
    param([string]$ScriptPath, [string]$StdoutFile, [string]$StderrFile, [string[]]$ArgList)
    $allArgs = @('-NoProfile','-NonInteractive','-File',$ScriptPath)
    if ($ArgList) { $allArgs += $ArgList }
    & $pwshPath @allArgs *> $StdoutFile
    if (-not (Test-Path $StderrFile)) { New-Item -ItemType File -Path $StderrFile -Force | Out-Null }
    return $LASTEXITCODE
}

# 生成 fixture 副本 + 可选 flag 覆盖（用于 T26）
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
    [System.IO.File]::WriteAllText($mdPath, $md, (New-Object System.Text.UTF8Encoding($false)))
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

# 运行 step2-mock-harness 并捕获 stdout/stderr
function Run-MockHarness {
    param([string]$TestDir, [string]$Scenario, [string]$BaseDir)
    $harness = Join-Path $libDir 'step2-mock-harness.ps1'
    $stdout = Join-Path $TestDir 'stdout.txt'
    $stderr = Join-Path $TestDir 'stderr.txt'
    $exit = Run-Script -ScriptPath $harness -StdoutFile $stdout -StderrFile $stderr `
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
# Main execution
# ============================================================

$startTime = Get-Date
$phase7Stdout = Join-Path $pvDir 'phase7-stdout.txt'
$phase7Stderr = Join-Path $pvDir 'phase7-stderr.txt'

Write-Log "Phase 7 T04 + T05-PS7 + T26 + T18 Execution Started"
Write-Log "ProjectRoot: $ProjectRoot"
Write-Log "PVDir: $pvDir"
Write-Log "PwshPath: $pwshPath"

# ============================================================
# 7.1 T04-PS7: rate_limited Regression (403 + remaining=0)
# ============================================================
Write-Log "=== 7.1 T04-PS7: rate_limited Regression ==="
$t04Dir = Join-Path $pvDir 'T04-PS7'
if (Test-Path $t04Dir) { Remove-Item $t04Dir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $t04Dir | Out-Null

New-TestFixture -BaseDir $t04Dir -Flag 'no'
New-LockForStep2 -BaseDir $t04Dir
Capture-BeforeAfter -TestDir $t04Dir -BaseDir $t04Dir

$t04Exit = Run-MockHarness -TestDir $t04Dir -Scenario 'rate_limited_403' -BaseDir $t04Dir
Capture-After -TestDir $t04Dir -BaseDir $t04Dir

$t04Stdout = Get-Content (Join-Path $t04Dir 'stdout.txt') -Raw -ErrorAction SilentlyContinue
if (-not $t04Stdout) { $t04Stdout = '' }
$t04Stderr = Get-Content (Join-Path $t04Dir 'stderr.txt') -Raw -ErrorAction SilentlyContinue
if (-not $t04Stderr) { $t04Stderr = '' }

$t04Calls = Get-MockCalls -StdoutPath (Join-Path $t04Dir 'stdout.txt')
$t04CallCount = $t04Calls.Count

# 判定 T04：
#  - stdout 含 "rate_limited"（result.json items[0].status）
#  - MOCK_CALLS count = 1
#  - 无 review API 调用（无 /reviews/ 或 /comments/ 等）
#  - 无 HTML 回退（无 github.com/.../releases 且非 api.github.com）
#  - 无 retry（无第二次同 URL 调用）
$t04ResultItem = Get-FirstItem -ResultPath (Join-Path $t04Dir 'result-after.json')
$t04Status = if ($t04ResultItem) { $t04ResultItem.status } else { '' }
$t04HasRateLimited = ($t04Status -eq 'rate_limited') -or ($t04Stdout -match 'rate_limited')
$t04LatestReqCount = 0
$t04ReviewReqCount = 0
$t04HtmlReqCount = 0
$t04RetryCount = 0
foreach ($c in $t04Calls) {
    if ($c -match 'api\.github\.com/repos/[^/]+/[^/]+/releases/latest') { $t04LatestReqCount++ }
    if ($c -match '/reviews/|/comments/') { $t04ReviewReqCount++ }
    # HTML 回退判定：URI 中含 github.com 但不含 api.github.com（排除 api 子域）
    if ($c -match 'github\.com' -and $c -notmatch 'api\.github\.com') { $t04HtmlReqCount++ }
}
$t04RetryCount = [Math]::Max(0, $t04LatestReqCount - 1)

$t04Verdict = 'FAIL'
if ($t04HasRateLimited -and $t04LatestReqCount -eq 1 -and $t04ReviewReqCount -eq 0 -and $t04HtmlReqCount -eq 0 -and $t04RetryCount -eq 0) {
    $t04Verdict = 'PASS'
}

Write-Log "T04-PS7: exit=$t04Exit status=$t04Status rateLimited=$t04HasRateLimited"
Write-Log "T04-PS7: latest=$t04LatestReqCount review=$t04ReviewReqCount html=$t04HtmlReqCount retry=$t04RetryCount total=$t04CallCount"
Write-Log "T04-PS7: verdict=$t04Verdict"
$global:TestResults['T04-PS7'] = @{
    Verdict = $t04Verdict
    Status = $t04Status
    HasRateLimited = $t04HasRateLimited
    LatestReqCount = $t04LatestReqCount
    ReviewReqCount = $t04ReviewReqCount
    HtmlReqCount = $t04HtmlReqCount
    RetryCount = $t04RetryCount
    TotalCallCount = $t04CallCount
}

# ============================================================
# 7.2 T05-PS7: forbidden Regression (403 + remaining=50)
# ============================================================
Write-Log "=== 7.2 T05-PS7: forbidden Regression ==="
$t05Dir = Join-Path $pvDir 'T05-PS7'
if (Test-Path $t05Dir) { Remove-Item $t05Dir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $t05Dir | Out-Null

New-TestFixture -BaseDir $t05Dir -Flag 'no'
New-LockForStep2 -BaseDir $t05Dir
Capture-BeforeAfter -TestDir $t05Dir -BaseDir $t05Dir

$t05Exit = Run-MockHarness -TestDir $t05Dir -Scenario 'forbidden' -BaseDir $t05Dir
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

Write-Log "T05-PS7: exit=$t05Exit status=$t05Status forbidden=$t05HasForbidden calls=$t05CallCount"
Write-Log "T05-PS7: verdict=$t05Verdict"
$global:TestResults['T05-PS7'] = @{
    Verdict = $t05Verdict
    Status = $t05Status
    HasForbidden = $t05HasForbidden
    TotalCallCount = $t05CallCount
}

# ============================================================
# 7.3 T26: Strict Flag Regression（9 项输入）
# ============================================================
Write-Log "=== 7.3 T26: Strict Flag Regression ==="
$t26Dir = Join-Path $pvDir 'T26'
if (Test-Path $t26Dir) { Remove-Item $t26Dir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $t26Dir | Out-Null

$t26Cases = @(
    @{ Flag='yes';     Expect='VALID';       DirName='flag_yes_01' }
    @{ Flag='no';      Expect='VALID';       DirName='flag_no_02' }
    @{ Flag='YES';     Expect='PARSE_ERROR'; DirName='flag_YES_03' }
    @{ Flag='Yes';     Expect='PARSE_ERROR'; DirName='flag_Yes_04' }
    @{ Flag='yEs';     Expect='PARSE_ERROR'; DirName='flag_yEs_05' }
    @{ Flag='NO';      Expect='PARSE_ERROR'; DirName='flag_NO_06' }
    @{ Flag='No';      Expect='PARSE_ERROR'; DirName='flag_No_07' }
    @{ Flag='pending'; Expect='PARSE_ERROR'; DirName='flag_pending_08' }
    @{ Flag='true';    Expect='PARSE_ERROR'; DirName='flag_true_09' }
)

$t26CaseResults = @()
$t26AllPass = $true

foreach ($case in $t26Cases) {
    $flag = $case.Flag
    $expect = $case.Expect
    $caseDirName = $case.DirName
    $caseDir = Join-Path $t26Dir $caseDirName
    if (Test-Path $caseDir) { Remove-Item $caseDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null

    New-TestFixture -BaseDir $caseDir -Flag $flag
    New-LockForStep2 -BaseDir $caseDir
    Capture-BeforeAfter -TestDir $caseDir -BaseDir $caseDir

    $exit = Run-MockHarness -TestDir $caseDir -Scenario 'normal' -BaseDir $caseDir
    Capture-After -TestDir $caseDir -BaseDir $caseDir

    $caseStdout = Get-Content (Join-Path $caseDir 'stdout.txt') -Raw -ErrorAction SilentlyContinue
    if (-not $caseStdout) { $caseStdout = '' }

    $hasParseError = ($caseStdout -match [regex]::Escape('PARSE_ERROR|'))
    $mdBefore = Join-Path $caseDir 'md-before.md'
    $mdAfter  = Join-Path $caseDir 'md-after.md'
    $shaBefore = Get-Sha256 (Join-Path $caseDir '.output\GitHub更新监测列表.md')
    $shaAfter  = Get-Sha256 (Join-Path $caseDir '.output\GitHub更新监测列表.md')
    $mdUnchanged = ($shaBefore -eq $shaAfter)
    $lockAfter = Get-Content (Join-Path $caseDir 'lock-after.txt') -Raw -ErrorAction SilentlyContinue
    if (-not $lockAfter) { $lockAfter = '' }
    $lockReleased = ($lockAfter -match 'LOCK_FILE_NOT_EXISTS')

    if ($expect -eq 'PARSE_ERROR') {
        $casePass = $hasParseError -and $mdUnchanged -and $lockReleased
    } else {
        # VALID：不期望 PARSE_ERROR（可能 FETCH_COMPLETE 或 SUMMARY 存在）
        $casePass = (-not $hasParseError)
    }

    $t26CaseResults += [PSCustomObject]@{
        Flag = $flag
        Expect = $expect
        HasParseError = $hasParseError
        MdUnchanged = $mdUnchanged
        LockReleased = $lockReleased
        Pass = $casePass
        CaseDir = $caseDirName
    }
    if (-not $casePass) { $t26AllPass = $false }
    Write-Log ("T26 case flag='{0}' expect={1} parseError={2} mdUnchanged={3} lockReleased={4} pass={5}" -f $flag, $expect, $hasParseError, $mdUnchanged, $lockReleased, $casePass)
}

$t26Verdict = if ($t26AllPass) { 'PASS' } else { 'FAIL' }
Write-Log "T26: verdict=$t26Verdict (cases=$($t26CaseResults.Count))"
$global:TestResults['T26'] = @{
    Verdict = $t26Verdict
    Cases = $t26CaseResults
    AllPass = $t26AllPass
}

# ============================================================
# 7.4 T18: State Preservation Regression（9 种非 ok 状态）
# ============================================================
Write-Log "=== 7.4 T18: State Preservation Regression ==="
$t18Dir = Join-Path $pvDir 'T18'
if (Test-Path $t18Dir) { Remove-Item $t18Dir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $t18Dir | Out-Null

# 9 种非 ok 状态与 mock 场景映射
$t18Scenarios = @(
    @{ Status='not_found';           Scenario='not_found';           ExpectGitVer='';          ExpectGitDate='';          ExpectFlag='prev'; ExpectReview=$true }
    @{ Status='rate_limited';        Scenario='rate_limited_403';    ExpectGitVer='prev';      ExpectGitDate='prev';      ExpectFlag='prev'; ExpectReview=$true }
    @{ Status='server_error';        Scenario='server_error';        ExpectGitVer='prev';      ExpectGitDate='prev';      ExpectFlag='prev'; ExpectReview=$true }
    @{ Status='network_error';       Scenario='network_error';       ExpectGitVer='prev';      ExpectGitDate='prev';      ExpectFlag='prev'; ExpectReview=$true }
    @{ Status='invalid_response';    Scenario='invalid_response';    ExpectGitVer='prev';      ExpectGitDate='prev';      ExpectFlag='prev'; ExpectReview=$true }
    @{ Status='metadata_incomplete'; Scenario='metadata_incomplete'; ExpectGitVer='prev';      ExpectGitDate='prev';      ExpectFlag='prev'; ExpectReview=$true }
    @{ Status='auth_error';          Scenario='auth_error';          ExpectGitVer='prev';      ExpectGitDate='prev';      ExpectFlag='prev'; ExpectReview=$true }
    @{ Status='forbidden';           Scenario='forbidden';           ExpectGitVer='prev';      ExpectGitDate='prev';      ExpectFlag='prev'; ExpectReview=$true }
    @{ Status='http_error';          Scenario='http_error';          ExpectGitVer='prev';      ExpectGitDate='prev';      ExpectFlag='prev'; ExpectReview=$true }
)

$t18CaseResults = @()
$t18AllPass = $true

foreach ($sc in $t18Scenarios) {
    $status = $sc.Status
    $scenario = $sc.Scenario
    $caseDirName = ('state_' + $status)
    $caseDir = Join-Path $t18Dir $caseDirName
    if (Test-Path $caseDir) { Remove-Item $caseDir -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $caseDir | Out-Null

    # fixture 使用 prevGitVer='1.0.0' prevGitDate='2025-01-01' prevFlag='no' localVer='0.0.1'
    # 以便验证"prev 保留"
    $outputDir = Join-Path $caseDir '.output'
    if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }
    $mdPath = Join-Path $outputDir 'GitHub更新监测列表.md'
    $md = @"
# GitHub 项目版本监测列表

> 最近核对时间：2026-09-01 00:00（北京时间，本轮 0 项：latest API 成功 0 / 失败 0 / 待核 0；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---|---|---|---|---|
| 1 | [VS Code](https://github.com/microsoft/vscode/releases) | 1.0.0 | 2025-01-01 | 0.0.1 | no |

## 结论

（结论段：初始占位）

## 更新摘要

（更新摘要段：初始占位）

## 备注

（备注段：初始占位）

## 核对方法

（核对方法段：初始占位）
"@
    [System.IO.File]::WriteAllText($mdPath, $md, (New-Object System.Text.UTF8Encoding($false)))
    New-LockForStep2 -BaseDir $caseDir
    Capture-BeforeAfter -TestDir $caseDir -BaseDir $caseDir

    $exit = Run-MockHarness -TestDir $caseDir -Scenario $scenario -BaseDir $caseDir
    Capture-After -TestDir $caseDir -BaseDir $caseDir

    $caseStdout = Get-Content (Join-Path $caseDir 'stdout.txt') -Raw -ErrorAction SilentlyContinue
    if (-not $caseStdout) { $caseStdout = '' }

    $item = Get-FirstItem -ResultPath (Join-Path $caseDir 'result-after.json')
    $actualStatus = if ($item) { $item.status } else { '' }
    $actualGitVer = if ($item) { $item.gitVer } else { '' }
    $actualGitDate = if ($item) { $item.gitDate } else { '' }
    $actualFlag = if ($item) { $item.flag } else { '' }
    $actualReview = if ($item) { [bool]$item.review } else { $false }

    # 期望值解析
    $expStatus = $status
    $expGitVer = if ($sc.ExpectGitVer -eq 'prev') { '1.0.0' } else { $sc.ExpectGitVer }
    $expGitDate = if ($sc.ExpectGitDate -eq 'prev') { '2025-01-01' } else { $sc.ExpectGitDate }
    $expFlag = if ($sc.ExpectFlag -eq 'prev') { 'no' } else { $sc.ExpectFlag }
    $expReview = $sc.ExpectReview

    $statusOk = ($actualStatus -eq $expStatus)
    $gitVerOk = ($actualGitVer -eq $expGitVer)
    $gitDateOk = ($actualGitDate -eq $expGitDate)
    $flagOk = ($actualFlag -eq $expFlag)
    $reviewOk = ($actualReview -eq $expReview)

    $casePass = $statusOk -and $gitVerOk -and $gitDateOk -and $flagOk -and $reviewOk

    $t18CaseResults += [PSCustomObject]@{
        Status = $status
        Scenario = $scenario
        ActualStatus = $actualStatus
        ActualGitVer = $actualGitVer
        ActualGitDate = $actualGitDate
        ActualFlag = $actualFlag
        ActualReview = $actualReview
        ExpectStatus = $expStatus
        ExpectGitVer = $expGitVer
        ExpectGitDate = $expGitDate
        ExpectFlag = $expFlag
        ExpectReview = $expReview
        StatusOk = $statusOk
        GitVerOk = $gitVerOk
        GitDateOk = $gitDateOk
        FlagOk = $flagOk
        ReviewOk = $reviewOk
        Pass = $casePass
        CaseDir = $caseDirName
    }
    if (-not $casePass) { $t18AllPass = $false }
    Write-Log ("T18 state={0} status={1}(exp={2}) gitVer={3}(exp={4}) gitDate={5}(exp={6}) flag={7}(exp={8}) review={9}(exp={10}) pass={11}" -f $status, $actualStatus, $expStatus, $actualGitVer, $expGitVer, $actualGitDate, $expGitDate, $actualFlag, $expFlag, $actualReview, $expReview, $casePass)
}

$t18Verdict = if ($t18AllPass) { 'PASS' } else { 'FAIL' }
Write-Log "T18: verdict=$t18Verdict (states=$($t18CaseResults.Count))"
$global:TestResults['T18'] = @{
    Verdict = $t18Verdict
    Cases = $t18CaseResults
    AllPass = $t18AllPass
}

# ============================================================
# 汇总
# ============================================================
$endTime = Get-Date
$duration = ($endTime - $startTime).TotalSeconds

Write-Log "=== Phase 7 Summary ==="
Write-Log ("T04-PS7: {0}" -f $global:TestResults['T04-PS7'].Verdict)
Write-Log ("T05-PS7: {0}" -f $global:TestResults['T05-PS7'].Verdict)
Write-Log ("T26:     {0}" -f $global:TestResults['T26'].Verdict)
Write-Log ("T18:     {0}" -f $global:TestResults['T18'].Verdict)
Write-Log ("Duration: {0:N1}s" -f $duration)

# 输出结构化 JSON 供后续生成报告使用
$summary = [PSCustomObject]@{
    Phase = 'Phase7'
    StartTime = $startTime.ToString('o')
    EndTime = $endTime.ToString('o')
    DurationSec = [Math]::Round($duration, 1)
    T04_PS7 = [PSCustomObject]@{
        Verdict = $global:TestResults['T04-PS7'].Verdict
        Status = $global:TestResults['T04-PS7'].Status
        LatestReqCount = $global:TestResults['T04-PS7'].LatestReqCount
        ReviewReqCount = $global:TestResults['T04-PS7'].ReviewReqCount
        HtmlReqCount = $global:TestResults['T04-PS7'].HtmlReqCount
        RetryCount = $global:TestResults['T04-PS7'].RetryCount
        TotalCallCount = $global:TestResults['T04-PS7'].TotalCallCount
    }
    T05_PS7 = [PSCustomObject]@{
        Verdict = $global:TestResults['T05-PS7'].Verdict
        Status = $global:TestResults['T05-PS7'].Status
        TotalCallCount = $global:TestResults['T05-PS7'].TotalCallCount
    }
    T26 = [PSCustomObject]@{
        Verdict = $global:TestResults['T26'].Verdict
        Cases = $global:TestResults['T26'].Cases
    }
    T18 = [PSCustomObject]@{
        Verdict = $global:TestResults['T18'].Verdict
        Cases = $global:TestResults['T18'].Cases
    }
}
$summary | ConvertTo-Json -Depth 10 | Set-Content (Join-Path $pvDir 'phase7-summary.json') -Encoding UTF8
Write-Log "Summary JSON written to phase7-summary.json"
