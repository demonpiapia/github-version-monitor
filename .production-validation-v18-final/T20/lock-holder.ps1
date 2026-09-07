$ErrorActionPreference = 'Stop'
$path = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.monitor\result.json'
$fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
Write-Output "LOCKED|PID=$PID"
Start-Sleep -Seconds 300
$fs.Close()
