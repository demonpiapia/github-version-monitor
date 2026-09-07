# T33: 陈锁 + PID 活 — 锁 heartbeat 超 30 分钟但 PID 存活 → 不接管（LOCKED）
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T33'
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

# Phase 2: modify lock to simulate stale heartbeat (31 min ago) but PID is alive
# Use a long-running sleep process PID as the "alive" PID
$sleepProc = Start-Process pwsh -ArgumentList '-NoProfile', '-Command', 'Start-Sleep -Seconds 300' -PassThru
Start-Sleep -Milliseconds 500  # wait for sleep process to start
$livePid = $sleepProc.Id

$oldContent = Get-Content $lockPath -Raw
# Parse start token
$startTok = if ($oldContent -match 'start=([^;\r\n]+)') { $Matches[1] } else { [DateTimeOffset]::UtcNow.ToString('o') }
$staleBeat = ([DateTimeOffset]::UtcNow.AddMinutes(-31)).ToString('o')
$newContent = "pid=$livePid;start=$startTok;step=1;beat=$staleBeat"
Set-Content -Path $lockPath -Value $newContent -Encoding UTF8
# Set LastWriteTime to 31 minutes ago
(Get-Item $lockPath).LastWriteTime = (Get-Date).AddMinutes(-31)

# Save modified lock state
Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-modified.txt')
Write-Host "LIVE_PID=$livePid"
Write-Host "LIVE_PID_ALIVE=$(-not $sleepProc.HasExited)"
Write-Host "LOCK_MODIFIED|beat=$staleBeat"

# Phase 3: run step1 in a NEW child process (different PID from $livePid)
$step1AgainOut = & pwsh -NoProfile -Command "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'" 2>&1
$step1AgainOut | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8

# Kill sleep process
if (-not $sleepProc.HasExited) { Stop-Process -Id $sleepProc.Id -Force -ErrorAction SilentlyContinue; $sleepProc.WaitForExit(5000) | Out-Null }

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

Write-Host "HAS_LOCKED=$hasLocked"
Write-Host "HAS_BACKUP_OK=$hasBackupOk"
Write-Host "LOCK_STILL_PRESENT=$(Get-Content (Join-Path $base 'lock-still-present.txt'))"
