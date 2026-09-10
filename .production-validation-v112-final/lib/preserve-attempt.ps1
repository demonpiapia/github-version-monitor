param([string]$From, [string]$To)
$ErrorActionPreference = 'Stop'
if (Test-Path $To) { Remove-Item $To -Recurse -Force }
Move-Item -Path $From -Destination $To -Force
Write-Output "PRESERVED $From -> $To"
