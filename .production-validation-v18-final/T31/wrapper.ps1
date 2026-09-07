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
