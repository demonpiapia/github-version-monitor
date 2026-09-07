# T30: 并发 — 两个 pwsh 进程同时运行 step1.ps1，恰好一个 BACKUP_OK，一个 LOCKED
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T30'
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

# Launch two pwsh processes simultaneously
$p1 = Start-Process pwsh -ArgumentList '-NoProfile', '-Command', "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'" -PassThru -RedirectStandardOutput (Join-Path $base 'proc1.txt') -RedirectStandardError (Join-Path $base 'proc1_err.txt')
$p2 = Start-Process pwsh -ArgumentList '-NoProfile', '-Command', "`$env:GITHUB_VERSION_MONITOR_BASE='$base'; & '$lib\step1.ps1'" -PassThru -RedirectStandardOutput (Join-Path $base 'proc2.txt') -RedirectStandardError (Join-Path $base 'proc2_err.txt')

$p1 | Wait-Process
$p2 | Wait-Process

# Read outputs
$proc1Out = Get-Content (Join-Path $base 'proc1.txt') -Raw
$proc2Out = Get-Content (Join-Path $base 'proc2.txt') -Raw
$combined = "=== proc1 ===`n$proc1Out`n=== proc2 ===`n$proc2Out"
$combined | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File (Join-Path $base 'stderr.txt') -Encoding UTF8

# Save lock state
$lockPath = Join-Path $base '.monitor\run.lock'
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after.txt')
} else {
    Set-Content -Path (Join-Path $base 'lock-after.txt') -Value 'LOCK_MISSING'
}

# Count backups
$backupCount = @(Get-ChildItem (Join-Path $base '.monitor\backups') -Filter 'GitHub更新监测列表.backup.*.md' -ErrorAction SilentlyContinue).Count

# Assertions
$proc1HasBackupOk = $proc1Out -match 'BACKUP_OK\|'
$proc2HasBackupOk = $proc2Out -match 'BACKUP_OK\|'
$proc1HasLocked = $proc1Out -match 'LOCKED\|'
$proc2HasLocked = $proc2Out -match 'LOCKED\|'

$backupOkCount = 0
if ($proc1HasBackupOk) { $backupOkCount++ }
if ($proc2HasBackupOk) { $backupOkCount++ }
$lockedCount = 0
if ($proc1HasLocked) { $lockedCount++ }
if ($proc2HasLocked) { $lockedCount++ }

Write-Host "PROC1_BACKUP_OK=$proc1HasBackupOk"
Write-Host "PROC2_BACKUP_OK=$proc2HasBackupOk"
Write-Host "PROC1_LOCKED=$proc1HasLocked"
Write-Host "PROC2_LOCKED=$proc2HasLocked"
Write-Host "BACKUP_OK_COUNT=$backupOkCount"
Write-Host "LOCKED_COUNT=$lockedCount"
Write-Host "BACKUP_FILE_COUNT=$backupCount"
Write-Host "SHA_BEFORE=$shaBefore"
