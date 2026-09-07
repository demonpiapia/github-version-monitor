# T35: ownership 不匹配 — 锁 PID ≠ 当前进程 PID → step5 释放锁时 RUNTIME_ERROR
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T35'
$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.output\GitHub更新监测列表.md.tmp')) { Remove-Item (Join-Path $base '.output\GitHub更新监测列表.md.tmp') -Force -ErrorAction SilentlyContinue }
if (-not (Test-Path (Join-Path $base '.output'))) { New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null }

# Fixture
$rows = @(
    [PSCustomObject]@{Id=1;Name='VS Code';Owner='microsoft';Repo='vscode';GitVer='v1.0.0';GitDate='2026-01-01';LocalVer='1.0.0';Flag='no'},
    [PSCustomObject]@{Id=2;Name='Linux';Owner='torvalds';Repo='linux';GitVer='v6.5.0';GitDate='2026-01-01';LocalVer='6.5.0';Flag='no'}
)
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Rows $rows | Out-Null

# Save md-before
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-before.md')
$shaBefore = (Get-FileHash (Join-Path $base 'md-before.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

# Phase 1: run step1 + step2 + step3 + step4 in child to generate result.json
$phase1Out = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'; & '$lib\step2.ps1'; & '$lib\step3.ps1'; & '$lib\step4.ps1'" 2>&1
$phase1Out | Out-File (Join-Path $base 'phase1-output.txt') -Encoding UTF8
Write-Host "PHASE1_DONE|result_json=$(Test-Path (Join-Path $base '.monitor\result.json'))"

# Save lock-before and result-before
$lockPath = Join-Path $base '.monitor\run.lock'
Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-before.txt')
Copy-Item (Join-Path $base '.monitor\result.json') (Join-Path $base 'result-before.json')

# Phase 2: modify lock PID to external value (999998)
$lockContent = Get-Content $lockPath -Raw
$modifiedLock = $lockContent -replace 'pid=\d+', 'pid=999998'
Set-Content -Path $lockPath -Value $modifiedLock -Encoding UTF8
Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after-modify.txt')
Write-Host "LOCK_MODIFIED|pid=999998"

# Phase 3: run step5-full in child (commit should succeed, lock release should fail)
$phase2Out = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step5-full.ps1'" 2>&1
$phase2Out | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8

# Save after state
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash (Join-Path $base 'md-after.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after.txt')
    Set-Content -Path (Join-Path $base 'lock-still-present.txt') -Value 'YES_LOCK_STILL_PRESENT'
} else {
    Set-Content -Path (Join-Path $base 'lock-still-present.txt') -Value 'NO_LOCK_REMOVED'
}

Copy-Item (Join-Path $base '.monitor\result.json') (Join-Path $base 'result-after.json')

# Assertions
$stdoutContent = Get-Content (Join-Path $base 'stdout.txt') -Raw
$hasCommitOk = $stdoutContent -match 'COMMIT_OK\|'
$hasRuntimeError = $stdoutContent -match 'RUNTIME_ERROR\|'
$hasRunStatusFailed = $stdoutContent -match 'RUN_STATUS\|failed\|'
$hasRunStatusSuccess = $stdoutContent -match 'RUN_STATUS\|success\|'

# Check lock PID is still 999998 (not overwritten)
$lockPidAfter = if (Test-Path $lockPath) {
    $lc = Get-Content $lockPath -Raw
    if ($lc -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
} else { -1 }

Write-Host "HAS_COMMIT_OK=$hasCommitOk"
Write-Host "HAS_RUNTIME_ERROR=$hasRuntimeError"
Write-Host "HAS_RUN_STATUS_FAILED=$hasRunStatusFailed"
Write-Host "HAS_RUN_STATUS_SUCCESS=$hasRunStatusSuccess"
Write-Host "LOCK_STILL_PRESENT=$(Get-Content (Join-Path $base 'lock-still-present.txt'))"
Write-Host "LOCK_PID_AFTER=$lockPidAfter"
Write-Host "LOCK_PID_UNCHANGED=$($lockPidAfter -eq 999998)"
Write-Host "SHA_CHANGED=$($shaBefore -ne $shaAfter)"
