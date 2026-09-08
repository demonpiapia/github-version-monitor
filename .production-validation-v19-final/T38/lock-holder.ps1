param([string]$File, [string]$SignalPath)
$fs = [System.IO.File]::Open($File, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
Set-Content -Path $SignalPath -Value 'ready'
$done = Join-Path $PSScriptRoot 'done.flag'
while (-not (Test-Path $done)) { Start-Sleep -Milliseconds 100 }
$fs.Close()
