# t39-wrapper.ps1 - T39 同进程 wrapper（Step 1-4 + Step 5 harness 同进程）
# 在同进程内 dot-source Step 1-4 + Step 5 harness，确保 $PID 一致
# Step 5 harness 内部在 L636/L637 之间注入 pid=999999
param([string]$BaseDir)
$ErrorActionPreference = 'Stop'
$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
$libDir = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib'
$lockPath = Join-Path (Join-Path $BaseDir '.monitor') 'run.lock'

Write-Output "=== STEP 1 START ==="
. (Join-Path $libDir 'step1.ps1')
Write-Output "=== STEP 1 END ==="

# Capture lock state after Step 1 (before harness injection)
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content (Join-Path $BaseDir 'lock-after-step1.txt') -Encoding UTF8
} else {
    'LOCK_FILE_NOT_EXISTS' | Set-Content (Join-Path $BaseDir 'lock-after-step1.txt') -Encoding UTF8
}

Write-Output "=== STEP 2 START ==="
. (Join-Path $libDir 'step2.ps1')
Write-Output "=== STEP 2 END ==="

Write-Output "=== STEP 3 START ==="
. (Join-Path $libDir 'step3.ps1')
Write-Output "=== STEP 3 END ==="

Write-Output "=== STEP 4 START ==="
. (Join-Path $libDir 'step4.ps1')
Write-Output "=== STEP 4 END ==="

Write-Output "=== STEP 5 START (T39 harness) ==="
. (Join-Path $libDir 'step5-t39-harness.ps1')
Write-Output "=== STEP 5 END ==="