$ErrorActionPreference = 'Stop'
$path = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.output\GitHub更新监测列表.md'
$fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
Write-Output "LOCKED|PID=$PID"
Start-Sleep -Seconds 300
$fs.Close()
