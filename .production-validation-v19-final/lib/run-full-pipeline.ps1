param([string]$Base)
if ($Base) { $env:GITHUB_VERSION_MONITOR_BASE = $Base }
. (Join-Path $PSScriptRoot 'step1.ps1')
. (Join-Path $PSScriptRoot 'step2.ps1')
. (Join-Path $PSScriptRoot 'step3.ps1')
. (Join-Path $PSScriptRoot 'step4.ps1')
. (Join-Path $PSScriptRoot 'step5-full.ps1')
