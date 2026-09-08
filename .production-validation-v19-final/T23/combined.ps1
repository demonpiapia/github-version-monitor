$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
& (Join-Path $lib 'step1.ps1')
& (Join-Path $lib 'step2.ps1')
& (Join-Path $lib 'step3.ps1')
# Wait for lock-holder to acquire the lock on main md
$signalPath = Join-Path $base 'lock-ready.flag'
while (-not (Test-Path $signalPath)) { Start-Sleep -Milliseconds 100 }
& (Join-Path $lib 'step5-full.ps1')
# Write done.flag to release the lock (lock-holder will close the file)
Set-Content -Path (Join-Path $base 'done.flag') -Value 'done'
