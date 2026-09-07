$ErrorActionPreference = 'Stop'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
& (Join-Path $lib 'step1.ps1')
Write-Output "STEP1_DONE|PID=$PID"
Start-Sleep -Seconds 60
