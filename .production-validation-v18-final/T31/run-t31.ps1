# T31: heartbeat — 锁 heartbeat 在 step1 → step2 之间正确刷新
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T31'
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

# Wrapper script: run step1, save lock-before, run step2, save lock-after (all in same PID)
$wrapperScript = @'
$ErrorActionPreference = 'Continue'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
$lockPath = Join-Path $base '.monitor\run.lock'

Write-Output "===== EXECUTING step1 ====="
& (Join-Path $lib 'step1.ps1') 2>&1 | Out-String -Width 4096 | Write-Output
Write-Output "===== END step1 ====="

if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-before.txt')
    Write-Output "LOCK_BEFORE_SAVED"
} else {
    Write-Output "LOCK_BEFORE_MISSING"
}

Write-Output "===== EXECUTING step2 ====="
& (Join-Path $lib 'step2.ps1') 2>&1 | Out-String -Width 4096 | Write-Output
Write-Output "===== END step2 ====="

if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after.txt')
    Write-Output "LOCK_AFTER_SAVED"
} else {
    Write-Output "LOCK_AFTER_MISSING"
}
'@
$wrapperPath = Join-Path $base 'wrapper.ps1'
Set-Content -Path $wrapperPath -Value $wrapperScript -Encoding UTF8

# Run wrapper
$wrapperOut = & pwsh -NoProfile -File $wrapperPath 2>&1
$wrapperOut | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8

# Assertions
$lockBeforeContent = Get-Content (Join-Path $base 'lock-before.txt') -Raw
$lockAfterContent = Get-Content (Join-Path $base 'lock-after.txt') -Raw
$beatBefore = if ($lockBeforeContent -match 'beat=([^;\r\n]+)') { $Matches[1] } else { '' }
$beatAfter = if ($lockAfterContent -match 'beat=([^;\r\n]+)') { $Matches[1] } else { '' }

$hasStep1Before = $lockBeforeContent -match 'step=1;'
$hasStep2After = $lockAfterContent -match 'step=2;'
$beatChanged = ($beatBefore -ne $beatAfter)

Write-Host "BEAT_BEFORE=$beatBefore"
Write-Host "BEAT_AFTER=$beatAfter"
Write-Host "HAS_STEP1_BEFORE=$hasStep1Before"
Write-Host "HAS_STEP2_AFTER=$hasStep2After"
Write-Host "BEAT_CHANGED=$beatChanged"
Write-Host "LOCK_BEFORE_CONTENT=$lockBeforeContent"
Write-Host "LOCK_AFTER_CONTENT=$lockAfterContent"
