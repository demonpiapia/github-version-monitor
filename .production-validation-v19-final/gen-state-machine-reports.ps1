# 为 Phase 6 状态机测试生成 test-report.md
$ErrorActionPreference = 'Continue'

$root = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final'
$results = Get-Content (Join-Path $root 'state-machine-results.json') -Raw | ConvertFrom-Json

$expectedMap = @{
    'T02'      = @{queryStatus='not_found';   desc='404 -> not_found'}
    'T04-PS7'  = @{queryStatus='rate_limited'; desc='403 + remaining=0 -> rate_limited'}
    'T05-PS7'  = @{queryStatus='forbidden';    desc='403 + remaining>0 -> forbidden'}
    'T08'      = @{queryStatus='network_error'; desc='network_error'}
    'T14'      = @{queryStatus='ok'; cmp='incomparable'; review=$true; desc='incomparable version'}
    'T15'      = @{queryStatus='ok'; versionJump=$true; review=$true; desc='versionJump (major diff >=2)'}
    'T16'      = @{queryStatus='ok'; dateSuspicious=$true; review=$true; desc='dateSuspicious'}
    'T17'      = @{queryStatus='ok'; isFlip=$true; desc='isFlip (no->yes)'}
    'T19'      = @{queryStatus='ok'; flag='no'; desc='uninstalled -> flag=no'}
}

foreach ($r in $results) {
    $base = Join-Path $root $r.TestName
    $exp = $expectedMap[$r.TestName]
    $verdict = 'PASS'
    $checks = @()

    # 检查 queryStatus
    $checks += "queryStatus = $($r.queryStatus) (expected $($exp.queryStatus))"
    if ($r.queryStatus -ne $exp.queryStatus) { $verdict = 'FAIL' }

    # 检查其他字段
    if ($exp.ContainsKey('cmp') -and $r.cmp -ne $exp.cmp) {
        $checks += "cmp = $($r.cmp) (expected $($exp.cmp))"
        $verdict = 'FAIL'
    }
    if ($exp.ContainsKey('review') -and $r.review -ne $exp.review) {
        $checks += "review = $($r.review) (expected $($exp.review))"
        $verdict = 'FAIL'
    }
    if ($exp.ContainsKey('versionJump') -and $r.versionJump -ne $exp.versionJump) {
        $checks += "versionJump = $($r.versionJump) (expected $($exp.versionJump))"
        $verdict = 'FAIL'
    }
    if ($exp.ContainsKey('dateSuspicious') -and $r.dateSuspicious -ne $exp.dateSuspicious) {
        $checks += "dateSuspicious = $($r.dateSuspicious) (expected $($exp.dateSuspicious))"
        $verdict = 'FAIL'
    }
    if ($exp.ContainsKey('isFlip') -and $r.isFlip -ne $exp.isFlip) {
        $checks += "isFlip = $($r.isFlip) (expected $($exp.isFlip))"
        $verdict = 'FAIL'
    }
    if ($exp.ContainsKey('flag') -and $r.flag -ne $exp.flag) {
        $checks += "flag = $($r.flag) (expected $($exp.flag))"
        $verdict = 'FAIL'
    }

    # 检查锁状态
    $lockPath = Join-Path $base '.monitor\run.lock'
    $lockReleased = -not (Test-Path $lockPath)

    # 生成 report
    $report = @"
# $($r.TestName) Test Report

## Description
$($exp.desc)

## Scenario
MOCK_SCENARIO=$($r.Scenario)

## Expected
- queryStatus: $($exp.queryStatus)
"@
    if ($exp.ContainsKey('cmp')) { $report += "- cmp: $($exp.cmp)`r`n" }
    if ($exp.ContainsKey('review')) { $report += "- review: $($exp.review)`r`n" }
    if ($exp.ContainsKey('versionJump')) { $report += "- versionJump: $($exp.versionJump)`r`n" }
    if ($exp.ContainsKey('dateSuspicious')) { $report += "- dateSuspicious: $($exp.dateSuspicious)`r`n" }
    if ($exp.ContainsKey('isFlip')) { $report += "- isFlip: $($exp.isFlip)`r`n" }
    if ($exp.ContainsKey('flag')) { $report += "- flag: $($exp.flag)`r`n" }

    $report += @"

## Actual Results
- queryStatus: $($r.queryStatus)
- cmp: $($r.cmp)
- review: $($r.review)
- reviewReasons: $($r.reviewReasons)
- gitVer: $($r.gitVer)
- gitDate: $($r.gitDate)
- flag: $($r.flag)
- prevFlag: $($r.prevFlag)
- latest: $($r.latest)
- publishedUtc: $($r.publishedUtc)
- versionJump: $($r.versionJump)
- dateSuspicious: $($r.dateSuspicious)
- isFlip: $($r.isFlip)
- isNew: $($r.isNew)
- error: $($r.error)
- apiOk/apiErr: $($r.apiOk)/$($r.apiErr)
- lockReleased: $lockReleased

## Verdict
$verdict
"@
    $report | Set-Content (Join-Path $base 'test-report.md') -Encoding UTF8
    Write-Output "$verdict  $($r.TestName): $($exp.desc)"
}
