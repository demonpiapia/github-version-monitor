# T18: 9 种非 ok 状态测试
# 验证每种 error 状态下 gitVer/gitDate/flag 保留上轮状态
$ErrorActionPreference = 'Continue'

$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$root = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final'
$base = Join-Path $root 'T18'

# 清理 base
if (Test-Path $base) { Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null

# 9 种非 ok 状态
$scenarios = @(
    @{name='not_found';           scenario='not_found'},
    @{name='rate_limited_429';    scenario='rate_limited_429'},
    @{name='server_error';        scenario='server_error'},
    @{name='network_error';       scenario='network_error'},
    @{name='invalid_response';    scenario='invalid_response'},
    @{name='metadata_incomplete'; scenario='metadata_incomplete'},
    @{name='auth_error';          scenario='auth_error'},
    @{name='forbidden_403';       scenario='forbidden_403'},
    @{name='http_error';          scenario='http_error'}
)

# 期望的 queryStatus
$expectedMap = @{
    'not_found'           = 'not_found'
    'rate_limited_429'    = 'rate_limited'
    'server_error'        = 'server_error'
    'network_error'       = 'network_error'
    'invalid_response'    = 'invalid_response'
    'metadata_incomplete' = 'metadata_incomplete'
    'auth_error'          = 'auth_error'
    'forbidden_403'       = 'forbidden'
    'http_error'          = 'http_error'
}

# 上轮状态（用于验证保留）
$prevGitVer  = 'v1.0.0'
$prevGitDate = '2026-01-01'
$prevFlag    = 'no'

$results = @()

foreach ($s in $scenarios) {
    $subName = $s.name
    $subBase = Join-Path $base $subName
    New-Item -ItemType Directory -Force -Path $subBase | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $subBase '.output') | Out-Null

    # 生成 fixture
    & (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $subBase '.output\GitHub更新监测列表.md') -Repos @(
        @{owner='test'; repo='test-repo'; name='test'}
    ) -LocalVer '1.0.0' -PrevFlag $prevFlag -PrevGitVer $prevGitVer -PrevGitDate $prevGitDate *>&1 | Out-Null

    # 保存 before 状态
    Copy-Item (Join-Path $subBase '.output\GitHub更新监测列表.md') (Join-Path $subBase 'md-before.md') -Force

    $env:GITHUB_VERSION_MONITOR_BASE = $subBase
    $env:MOCK_SCENARIO = $s.scenario

    # Step 1
    $step1Out = & pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step1.ps1') 2>&1
    $step1Out | Out-File (Join-Path $subBase 'step1-stdout.txt') -Encoding UTF8

    # Step 2
    $step2Out = & pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step2-mock-harness.ps1') -Scenario $s.scenario -Base $subBase 2>&1
    $step2Out | Out-File (Join-Path $subBase 'stdout.txt') -Encoding UTF8

    # 读取 result.json
    $resultPath = Join-Path $subBase '.monitor\result.json'
    $queryStatus = 'N/A'
    $gitVer = ''
    $gitDate = ''
    $flag = ''
    $review = $false
    $reviewReasons = ''
    $error = ''
    $lockReleased = $false

    if (Test-Path $resultPath) {
        $doc = Get-Content $resultPath -Raw | ConvertFrom-Json
        $item = $doc.items[0]
        $queryStatus = $item.status
        $gitVer = $item.gitVer
        $gitDate = $item.gitDate
        $flag = $item.flag
        $review = $item.review
        $reviewReasons = ($item.reviewReasons -join ', ')
        $error = $item.error
    }

    # 检查锁状态
    $lockPath = Join-Path $subBase '.monitor\run.lock'
    if (-not (Test-Path $lockPath)) { $lockReleased = $true }

    # 保存 after 状态
    if (Test-Path (Join-Path $subBase '.output\GitHub更新监测列表.md')) {
        Copy-Item (Join-Path $subBase '.output\GitHub更新监测列表.md') (Join-Path $subBase 'md-after.md') -Force
    }
    if (Test-Path $lockPath) {
        Get-Content $lockPath -Raw | Set-Content (Join-Path $subBase 'lock-after.txt') -Encoding UTF8
    } else {
        'lock released' | Set-Content (Join-Path $subBase 'lock-after.txt') -Encoding UTF8
    }

    # 验证
    $expected = $expectedMap[$subName]
    $statusOk = ($queryStatus -eq $expected)
    # not_found 特例：gitVer/gitDate 应为空
    if ($subName -eq 'not_found') {
        $stateOk = ($gitVer -eq '') -and ($gitDate -eq '') -and ($flag -eq $prevFlag)
    } else {
        $stateOk = ($gitVer -eq $prevGitVer) -and ($gitDate -eq $prevGitDate) -and ($flag -eq $prevFlag)
    }
    $reviewOk = ($review -eq $true)

    $pass = $statusOk -and $stateOk -and $reviewOk

    $results += [PSCustomObject]@{
        Scenario     = $subName
        Expected     = $expected
        QueryStatus  = $queryStatus
        StatusOk     = $statusOk
        GitVer       = $gitVer
        GitDate      = $gitDate
        Flag         = $flag
        StateOk      = $stateOk
        Review       = $review
        ReviewReasons = $reviewReasons
        ReviewOk     = $reviewOk
        LockReleased = $lockReleased
        Error        = $error
        Pass         = $pass
    }
}

# 输出汇总
Write-Output "=== T18: 9 Non-OK State Tests ==="
foreach ($r in $results) {
    $verdict = if ($r.Pass) { 'PASS' } else { 'FAIL' }
    Write-Output "$verdict  $($r.Scenario): queryStatus=$($r.QueryStatus) (expected $($r.Expected)), gitVer=$($r.GitVer), gitDate=$($r.GitDate), flag=$($r.Flag), review=$($r.Review), lockReleased=$($r.LockReleased)"
    if (-not $r.Pass) {
        Write-Output "  -> statusOk=$($r.StatusOk) stateOk=$($r.StateOk) reviewOk=$($r.ReviewOk)"
        if ($r.Error) { Write-Output "  -> error: $($r.Error)" }
    }
}

$passCount = @($results | Where-Object { $_.Pass }).Count
$failCount = @($results | Where-Object { -not $_.Pass }).Count
Write-Output ""
Write-Output "PASS: $passCount / FAIL: $failCount"

# 保存结果
$results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $base 'results.json') -Encoding UTF8

# 生成 test-report.md
$report = @"
# T18 Test Report: 9 Non-OK State Tests

## Purpose
验证 SKILL-v1.9 状态机 9 种非 ok 状态（SKILL L132-140）下：
- queryStatus 正确分类
- gitVer/gitDate/flag 保留上轮状态（not_found 特例：gitVer/gitDate 清空）
- review=true

## Pre-state
- prevGitVer: $prevGitVer
- prevGitDate: $prevGitDate
- prevFlag: $prevFlag

## Results

| Scenario | Expected | Actual queryStatus | gitVer | gitDate | flag | review | lockReleased | Verdict |
|---|---|---|---|---|---|---|---|---|
"@
foreach ($r in $results) {
    $verdict = if ($r.Pass) { 'PASS' } else { 'FAIL' }
    $report += "`r`n| $($r.Scenario) | $($r.Expected) | $($r.QueryStatus) | $($r.GitVer) | $($r.GitDate) | $($r.Flag) | $($r.Review) | $($r.LockReleased) | $verdict |"
}
$report += @"

## Summary
- PASS: $passCount / 9
- FAIL: $failCount / 9

## Notes
- not_found 特例：gitVer/gitDate 清空（SKILL L131），flag 保留
- 其他 8 种状态：gitVer/gitDate/flag 全部保留上轮状态
- review=true 对所有 9 种状态强制
"@
$report | Set-Content (Join-Path $base 'test-report.md') -Encoding UTF8
