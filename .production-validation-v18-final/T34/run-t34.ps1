# T34: 陈锁 + PID 死 — 锁 heartbeat 超 30 分钟且 PID 死亡 → 接管成功
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T34'
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

# Phase 1: run step1 in child to create lock
$step1Out = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'" 2>&1
$step1Out | Out-File (Join-Path $base 'step1-output.txt') -Encoding UTF8

$lockPath = Join-Path $base '.monitor\run.lock'
if (-not (Test-Path $lockPath)) { Write-Host "FATAL: lock not created by step1"; exit 1 }

# Save lock-before
Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-before.txt')

# Phase 2: modify lock to simulate stale heartbeat (31 min ago) with DEAD PID
# Find a PID that is NOT alive
$deadPid = 99999999
# Verify it's dead
if (Get-Process -Id $deadPid -ErrorAction SilentlyContinue) {
    # Find another dead PID
    $deadPid = 99999998
    if (Get-Process -Id $deadPid -ErrorAction SilentlyContinue) { $deadPid = 99999997 }
}

$oldContent = Get-Content $lockPath -Raw
$startTok = if ($oldContent -match 'start=([^;\r\n]+)') { $Matches[1] } else { [DateTimeOffset]::UtcNow.ToString('o') }
$staleBeat = ([DateTimeOffset]::UtcNow.AddMinutes(-31)).ToString('o')
$newContent = "pid=$deadPid;start=$startTok;step=1;beat=$staleBeat"
Set-Content -Path $lockPath -Value $newContent -Encoding UTF8
(Get-Item $lockPath).LastWriteTime = (Get-Date).AddMinutes(-31)

Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-modified.txt')
Write-Host "DEAD_PID=$deadPid"
Write-Host "DEAD_PID_ALIVE=$(Get-Process -Id $deadPid -ErrorAction SilentlyContinue -ne $null)"
Write-Host "LOCK_MODIFIED|beat=$staleBeat"

# Phase 3: run step1 in a NEW child process (should takeover)
$step1AgainOut = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'" 2>&1
$step1AgainOut | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8

# Save lock-after
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after.txt')
    Set-Content -Path (Join-Path $base 'lock-still-present.txt') -Value 'YES_LOCK_STILL_PRESENT'
} else {
    Set-Content -Path (Join-Path $base 'lock-still-present.txt') -Value 'NO_LOCK_REMOVED'
}

# Assertions
$stdoutContent = Get-Content (Join-Path $base 'stdout.txt') -Raw
$hasLocked = $stdoutContent -match 'LOCKED\|'
$hasBackupOk = $stdoutContent -match 'BACKUP_OK\|'

# Check new lock PID
$newLockPid = if (Test-Path $lockPath) {
    $newContent = Get-Content $lockPath -Raw
    if ($newContent -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
} else { -1 }

Write-Host "HAS_LOCKED=$hasLocked"
Write-Host "HAS_BACKUP_OK=$hasBackupOk"
Write-Host "LOCK_STILL_PRESENT=$(Get-Content (Join-Path $base 'lock-still-present.txt'))"
Write-Host "NEW_LOCK_PID=$newLockPid"
Write-Host "NEW_PID_DIFFERENT_FROM_DEAD=$($newLockPid -ne $deadPid)"
