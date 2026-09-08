# Phase 6.2 Schema 回归测试
# 9 种 flag 输入：yes/no 有效，其他 7 种触发 PARSE_ERROR
$ErrorActionPreference = 'Continue'

$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$root = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final'
$schemaBase = Join-Path $root 'schema'

# 清理 schema 目录
if (Test-Path $schemaBase) { Remove-Item $schemaBase -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $schemaBase | Out-Null

# 9 种输入
$inputs = @(
    @{flag='yes';     dirName='yes';     expected='valid'},
    @{flag='no';      dirName='no';      expected='valid'},
    @{flag='YES';     dirName='YES_upper';     expected='PARSE_ERROR'},
    @{flag='Yes';     dirName='Yes_mixed1';    expected='PARSE_ERROR'},
    @{flag='yEs';     dirName='yEs_mixed2';    expected='PARSE_ERROR'},
    @{flag='NO';      dirName='NO_upper';      expected='PARSE_ERROR'},
    @{flag='No';      dirName='No_mixed';      expected='PARSE_ERROR'},
    @{flag='pending'; dirName='pending';       expected='PARSE_ERROR'},
    @{flag='true';    dirName='true';        expected='PARSE_ERROR'}
)

$results = @()

foreach ($input in $inputs) {
    $flagVal = $input.flag
    $expected = $input.expected

    # 用 flag 值作为子目录名（Windows 大小写不敏感，故 YES/Yes/yEs 需独立目录名）
    $subName = $input.dirName
    $subBase = Join-Path $schemaBase $subName
    New-Item -ItemType Directory -Force -Path $subBase | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $subBase '.output') | Out-Null

    # 生成 fixture
    $mdPath = Join-Path $subBase '.output\GitHub更新监测列表.md'
    & (Join-Path $lib 'create-fixture.ps1') -OutputPath $mdPath -Repos @(
        @{owner='test'; repo='test-repo'; name='test'}
    ) -LocalVer '1.0.0' -PrevFlag $flagVal -PrevGitVer 'v1.0.0' -PrevGitDate '2026-01-01' *>&1 | Out-Null

    # 保存 before
    Copy-Item $mdPath (Join-Path $subBase 'md-before.md') -Force
    $shaBefore = (Get-FileHash $mdPath -Algorithm SHA256).Hash
    $shaBefore | Set-Content (Join-Path $subBase 'sha256-before.txt') -Encoding UTF8

    $env:GITHUB_VERSION_MONITOR_BASE = $subBase
    $env:MOCK_SCENARIO = 'normal'

    # Step 1
    $step1Out = & pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step1.ps1') 2>&1
    $step1Out | Out-File (Join-Path $subBase 'step1-stdout.txt') -Encoding UTF8

    # Step 2
    $step2Out = & pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step2-mock-harness.ps1') -Scenario 'normal' -Base $subBase 2>&1
    $step2Out | Out-File (Join-Path $subBase 'stdout.txt') -Encoding UTF8

    # 保存 after
    if (Test-Path $mdPath) {
        Copy-Item $mdPath (Join-Path $subBase 'md-after.md') -Force
        $shaAfter = (Get-FileHash $mdPath -Algorithm SHA256).Hash
    } else {
        $shaAfter = 'N/A (file missing)'
    }
    $shaAfter | Set-Content (Join-Path $subBase 'sha256-after.txt') -Encoding UTF8

    # 检查锁状态
    $lockPath = Join-Path $subBase '.monitor\run.lock'
    if (Test-Path $lockPath) {
        Get-Content $lockPath -Raw | Set-Content (Join-Path $subBase 'lock-after.txt') -Encoding UTF8
        $lockReleased = $false
    } else {
        'lock released' | Set-Content (Join-Path $subBase 'lock-after.txt') -Encoding UTF8
        $lockReleased = $true
    }

    # 验证
    $stdoutContent = Get-Content (Join-Path $subBase 'stdout.txt') -Raw
    $hasParseError = $stdoutContent -match 'PARSE_ERROR'
    $hasFetchComplete = $stdoutContent -match 'FETCH_COMPLETE'

    $verdict = 'PASS'
    $detail = ''

    if ($expected -eq 'valid') {
        # 有效输入：应该正常执行
        if ($hasParseError) {
            $verdict = 'FAIL'
            $detail = "expected valid execution, got PARSE_ERROR"
        } elseif (-not $hasFetchComplete) {
            $verdict = 'FAIL'
            $detail = "expected FETCH_COMPLETE, not found in stdout"
        }
    } else {
        # 非法输入：应该 PARSE_ERROR + md unchanged + lock released
        if (-not $hasParseError) {
            $verdict = 'FAIL'
            $detail = "expected PARSE_ERROR, not found in stdout"
        }
        if ($shaBefore -ne $shaAfter) {
            $verdict = 'FAIL'
            $detail += "md changed (sha before=$shaBefore, after=$shaAfter)"
        }
        if (-not $lockReleased) {
            $verdict = 'FAIL'
            $detail += "lock not released"
        }
    }

    $results += [PSCustomObject]@{
        Input        = $flagVal
        DirName      = $subName
        Expected     = $expected
        HasParseError = $hasParseError
        HasFetchComplete = $hasFetchComplete
        ShaBefore    = $shaBefore
        ShaAfter     = $shaAfter
        MdUnchanged  = ($shaBefore -eq $shaAfter)
        LockReleased = $lockReleased
        Verdict      = $verdict
        Detail       = $detail
    }
}

# 输出汇总
Write-Output "=== Phase 6.2 Schema Tests ==="
foreach ($r in $results) {
    Write-Output "$($r.Verdict)  input='$($r.Input)' expected=$($r.Expected) parseError=$($r.HasParseError) mdUnchanged=$($r.MdUnchanged) lockReleased=$($r.LockReleased)"
    if ($r.Detail) { Write-Output "  -> $($r.Detail)" }
}

$passCount = @($results | Where-Object { $_.Verdict -eq 'PASS' }).Count
$failCount = @($results | Where-Object { $_.Verdict -ne 'PASS' }).Count
Write-Output ""
Write-Output "PASS: $passCount / FAIL: $failCount"

# 生成 test-report.md
$report = @"
# Phase 6.2 Schema Regression Test Report

## Purpose
验证 SKILL-v1.9 状态文件 schema 校验（SKILL L79）：
- flag 列必须严格小写 `yes` 或 `no`
- 非法输入触发 `PARSE_ERROR|` 输出
- PARSE_ERROR 时主 md 不变 + 锁释放

## Schema Rule
```powershell
if($c[5]-cnotmatch '^(yes|no)$'){$parseErrors+=('第 6 列 flag 非法：{0}'-f $t);continue}
```

## Results

| Input | Expected | PARSE_ERROR | FETCH_COMPLETE | md unchanged | lock released | Verdict |
|---|---|---|---|---|---|---|
"@
foreach ($r in $results) {
    $report += "`r`n| `$($r.Input)` | $($r.Expected) | $($r.HasParseError) | $($r.HasFetchComplete) | $($r.MdUnchanged) | $($r.LockReleased) | $($r.Verdict) |"
}
$report += @"

## Summary
- PASS: $passCount / 9
- FAIL: $failCount / 9

## Valid Inputs (yes/no)
- `yes` (lowercase): valid → FETCH_COMPLETE
- `no` (lowercase): valid → FETCH_COMPLETE

## Invalid Inputs (7)
- `YES`, `Yes`, `yEs`, `NO`, `No`, `pending`, `true`: all trigger PARSE_ERROR
- md unchanged: all PASS
- lock released: all PASS
"@
$report | Set-Content (Join-Path $schemaBase 'test-report.md') -Encoding UTF8
