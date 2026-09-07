# T36: 进程中断 — 进程被 kill 后锁残留，下轮运行时正确处理
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T36'
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

# Create hold script
$holdScript = @'
$ErrorActionPreference = 'Stop'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
& (Join-Path $lib 'step1.ps1')
Write-Output "STEP1_DONE|PID=$PID"
Start-Sleep -Seconds 60
'@
$holdPath = Join-Path $base 'step1-and-hold.ps1'
Set-Content -Path $holdPath -Value $holdScript -Encoding UTF8

# Launch hold process
$holdProc = Start-Process pwsh -ArgumentList '-NoProfile', '-File', $holdPath -PassThru -RedirectStandardOutput (Join-Path $base 'hold-stdout.txt') -RedirectStandardError (Join-Path $base 'hold-stderr.txt')

# Wait for lock creation (max 5 seconds)
$lockPath = Join-Path $base '.monitor\run.lock'
$lockCreated = $false
for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Milliseconds 100
    if (Test-Path $lockPath) { $lockCreated = $true; break }
}
Write-Host "LOCK_CREATED=$lockCreated"
if (-not $lockCreated) { Write-Host "FATAL: lock not created"; exit 1 }

# Save lock-before
Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-before.txt')

# Verify backup exists
$backupCount = @(Get-ChildItem (Join-Path $base '.monitor\backups') -Filter 'GitHub更新监测列表.backup.*.md' -ErrorAction SilentlyContinue).Count
Write-Host "BACKUP_COUNT=$backupCount"

# Verify main md unchanged
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-mid.md')
$shaMid = (Get-FileHash (Join-Path $base 'md-mid.md') -Algorithm SHA256).Hash
Write-Host "MD_UNCHANGED_AFTER_HOLD=$($shaBefore -eq $shaMid)"

# Kill hold process
Stop-Process -Id $holdProc.Id -Force -ErrorAction SilentlyContinue
$holdProc.WaitForExit(5000) | Out-Null
Write-Host "HOLD_PROCESS_KILLED|exit_code=$($holdProc.ExitCode)"

# Verify lock still exists
$lockStillPresent1 = Test-Path $lockPath
if ($lockStillPresent1) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after-kill.txt')
}
Write-Host "LOCK_AFTER_KILL=$lockStillPresent1"

# Phase 2: run step1 in new process (lock heartbeat < 30 min, should LOCKED)
$step1AgainOut = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'" 2>&1
$step1AgainOut | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8

$stdoutContent = Get-Content (Join-Path $base 'stdout.txt') -Raw
$hasLocked1 = $stdoutContent -match 'LOCKED\|'
Write-Host "HAS_LOCKED_1=$hasLocked1"

# Phase 3: manually set lock LastWriteTime to 31 min ago (heartbeat stale, PID dead)
(Get-Item $lockPath).LastWriteTime = (Get-Date).AddMinutes(-31)
Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-before-takeover.txt')

# Phase 4: run step1 again (should takeover)
$step1TakeoverOut = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'" 2>&1
$step1TakeoverOut | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8

$stdoutContent = Get-Content (Join-Path $base 'stdout.txt') -Raw
$hasBackupOk = $stdoutContent -match 'BACKUP_OK\|'
$hasLocked2 = $stdoutContent -match 'LOCKED\|'
Write-Host "HAS_BACKUP_OK_2=$hasBackupOk"
Write-Host "HAS_LOCKED_2=$hasLocked2"

# Save final lock state
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after.txt')
}

# Save final md state
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash (Join-Path $base 'md-after.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

Write-Host "MD_UNCHANGED_FINAL=$($shaBefore -eq $shaAfter)"
