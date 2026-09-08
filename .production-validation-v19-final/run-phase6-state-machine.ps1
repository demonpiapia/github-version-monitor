# Phase 6 状态机测试主 runner（修正版）
# 修复点：
# 1. T15 fixture prevGitVer 改为 v0.50.0（major 差 2，触发 versionJump）
# 2. mock-invoke-restmethod.ps1 已改为 .NET Core 兼容（自定义 MockHttpException 类）
# 3. T18 覆盖 9 种非 ok 状态
$ErrorActionPreference = 'Continue'

$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$root = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final'

function Run-StateMachineTest {
    param(
        [string]$TestName,
        [string]$Scenario,
        [object[]]$Repos,
        [string]$LocalVer   = '1.0.0',
        [string]$PrevFlag   = 'no',
        [string]$PrevGitVer = 'v1.0.0',
        [string]$PrevGitDate = '2026-01-01'
    )
    $base = Join-Path $root $TestName

    if (Test-Path $base) { Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue }
    New-Item -ItemType Directory -Force -Path $base | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null

    & (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Repos $Repos -LocalVer $LocalVer -PrevFlag $PrevFlag -PrevGitVer $PrevGitVer -PrevGitDate $PrevGitDate *>&1 | Out-Null

    $env:GITHUB_VERSION_MONITOR_BASE = $base
    $env:MOCK_SCENARIO = $Scenario

    # Step 1: 建立锁 + 备份
    $step1Out = & pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step1.ps1') 2>&1
    $step1Out | Out-File (Join-Path $base 'step1-stdout.txt') -Encoding UTF8

    # Step 2: mock 查询
    $step2Out = & pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step2-mock-harness.ps1') -Scenario $Scenario -Base $base 2>&1
    $step2Out | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8

    # 读取 result.json
    $result = Join-Path $base '.monitor\result.json'
    if (Test-Path $result) {
        $doc = Get-Content $result -Raw | ConvertFrom-Json
        $item = $doc.items[0]
        return [PSCustomObject]@{
            TestName       = $TestName
            Scenario       = $Scenario
            queryStatus    = $item.status
            cmp            = $item.cmp
            review         = $item.review
            reviewReasons  = ($item.reviewReasons -join ', ')
            gitVer         = $item.gitVer
            gitDate        = $item.gitDate
            flag           = $item.flag
            prevFlag       = $item.prevFlag
            latest         = $item.latest
            publishedUtc   = $item.publishedUtc
            versionJump    = $item.versionJump
            dateSuspicious = $item.dateSuspicious
            isFlip         = $item.isFlip
            isNew          = $item.isNew
            error          = $item.error
            apiOk          = $doc.stats.apiOk
            apiErr         = $doc.stats.apiErr
        }
    } else {
        return [PSCustomObject]@{
            TestName       = $TestName
            Scenario       = $Scenario
            queryStatus    = 'N/A (result.json not found)'
            error          = 'result.json not found'
        }
    }
}

# 执行所有状态机测试
$results = @()

# T02: 404 → not_found
$results += Run-StateMachineTest -TestName 'T02' -Scenario 'not_found' -Repos @(
    @{owner='test'; repo='nonexistent-repo-12345'; name='test'}
)

# T04-PS7: 403 + remaining=0 → rate_limited
$results += Run-StateMachineTest -TestName 'T04-PS7' -Scenario 'rate_limited_403' -Repos @(
    @{owner='test'; repo='test-repo'; name='test'}
)

# T05-PS7: 403 + remaining>0 → forbidden
$results += Run-StateMachineTest -TestName 'T05-PS7' -Scenario 'forbidden_403' -Repos @(
    @{owner='test'; repo='test-repo'; name='test'}
)

# T08: network_error
$results += Run-StateMachineTest -TestName 'T08' -Scenario 'network_error' -Repos @(
    @{owner='test'; repo='test-repo'; name='test'}
)

# T14: incomparable (localVer=v1.2.3a 无法解析)
$results += Run-StateMachineTest -TestName 'T14' -Scenario 'normal' -Repos @(
    @{owner='test'; repo='test-repo'; name='test'}
) -LocalVer 'v1.2.3a' -PrevFlag 'no' -PrevGitVer 'v1.0.0' -PrevGitDate '2026-01-01'

# T15: versionJump (prevGitVer=v0.50.0, mock 返回 v2.0.0, major 差=2)
$results += Run-StateMachineTest -TestName 'T15' -Scenario 'normal' -Repos @(
    @{owner='test'; repo='test-repo'; name='test'}
) -LocalVer 'v1.0.0' -PrevFlag 'no' -PrevGitVer 'v0.50.0' -PrevGitDate '2026-01-01'

# T16: dateSuspicious (prevGitDate=2026-09-08, mock published_at=2026-09-07 北京时间)
$results += Run-StateMachineTest -TestName 'T16' -Scenario 'normal' -Repos @(
    @{owner='test'; repo='test-repo'; name='test'}
) -LocalVer 'v1.0.0' -PrevFlag 'no' -PrevGitVer 'v1.0.0' -PrevGitDate '2026-09-08'

# T17: isFlip (prevFlag=no, localVer=v1.0.0 < latest=v2.0.0 → flag=yes → isFlip=true)
$results += Run-StateMachineTest -TestName 'T17' -Scenario 'normal' -Repos @(
    @{owner='test'; repo='test-repo'; name='test'}
) -LocalVer 'v1.0.0' -PrevFlag 'no' -PrevGitVer 'v1.0.0' -PrevGitDate '2026-01-01'

# T19: uninstalled (localVer=未安装 → flag=no)
$results += Run-StateMachineTest -TestName 'T19' -Scenario 'normal' -Repos @(
    @{owner='test'; repo='test-repo'; name='test'}
) -LocalVer '未安装' -PrevFlag 'no' -PrevGitVer 'v1.0.0' -PrevGitDate '2026-01-01'

# 输出汇总
Write-Output "=== Phase 6 State Machine Tests ==="
foreach ($r in $results) {
    Write-Output ""
    Write-Output "=== $($r.TestName) (scenario=$($r.Scenario)) ==="
    Write-Output "  queryStatus:    $($r.queryStatus)"
    Write-Output "  cmp:            $($r.cmp)"
    Write-Output "  review:         $($r.review)"
    Write-Output "  reviewReasons:  $($r.reviewReasons)"
    Write-Output "  gitVer:         $($r.gitVer)"
    Write-Output "  gitDate:        $($r.gitDate)"
    Write-Output "  flag:           $($r.flag)"
    Write-Output "  prevFlag:       $($r.prevFlag)"
    Write-Output "  latest:         $($r.latest)"
    Write-Output "  publishedUtc:   $($r.publishedUtc)"
    Write-Output "  versionJump:    $($r.versionJump)"
    Write-Output "  dateSuspicious: $($r.dateSuspicious)"
    Write-Output "  isFlip:         $($r.isFlip)"
    Write-Output "  isNew:          $($r.isNew)"
    Write-Output "  error:          $($r.error)"
    Write-Output "  apiOk/apiErr:   $($r.apiOk)/$($r.apiErr)"
}

# 保存结果到 JSON
$results | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $root 'state-machine-results.json') -Encoding UTF8

# 保存汇总
$passCount = 0
$failCount = 0
$summary = @()
$summary += "=== Phase 6 State Machine Summary ==="
foreach ($r in $results) {
    $status = 'PASS'
    $reason = ''
    switch ($r.TestName) {
        'T02' { if ($r.queryStatus -ne 'not_found') { $status='FAIL'; $reason="expected not_found, got $($r.queryStatus)" } }
        'T04-PS7' { if ($r.queryStatus -ne 'rate_limited') { $status='FAIL'; $reason="expected rate_limited, got $($r.queryStatus)" } }
        'T05-PS7' { if ($r.queryStatus -ne 'forbidden') { $status='FAIL'; $reason="expected forbidden, got $($r.queryStatus)" } }
        'T08' { if ($r.queryStatus -ne 'network_error') { $status='FAIL'; $reason="expected network_error, got $($r.queryStatus)" } }
        'T14' { if ($r.queryStatus -ne 'ok' -or $r.cmp -ne 'incomparable' -or -not $r.review) { $status='FAIL'; $reason="expected ok+incomparable+review, got $($r.queryStatus)+$($r.cmp)+$($r.review)" } }
        'T15' { if ($r.queryStatus -ne 'ok' -or -not $r.versionJump -or -not $r.review) { $status='FAIL'; $reason="expected ok+versionJump+review, got $($r.queryStatus)+$($r.versionJump)+$($r.review)" } }
        'T16' { if ($r.queryStatus -ne 'ok' -or -not $r.dateSuspicious -or -not $r.review) { $status='FAIL'; $reason="expected ok+dateSuspicious+review, got $($r.queryStatus)+$($r.dateSuspicious)+$($r.review)" } }
        'T17' { if ($r.queryStatus -ne 'ok' -or -not $r.isFlip) { $status='FAIL'; $reason="expected ok+isFlip, got $($r.queryStatus)+$($r.isFlip)" } }
        'T19' { if ($r.queryStatus -ne 'ok' -or $r.flag -ne 'no') { $status='FAIL'; $reason="expected ok+flag=no, got $($r.queryStatus)+$($r.flag)" } }
    }
    if ($status -eq 'PASS') { $passCount++ } else { $failCount++ }
    $summary += "  $status  $($r.TestName): $($r.queryStatus) $($reason)"
}
$summary += ""
$summary += "PASS: $passCount / FAIL: $failCount"
$summary -join "`r`n" | Set-Content (Join-Path $root 'state-machine-summary.txt') -Encoding UTF8
Write-Output ""
Write-Output ($summary -join "`r`n")
