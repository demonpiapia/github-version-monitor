param([string]$Scenario, [string]$Base)
if ($Base) { $env:GITHUB_VERSION_MONITOR_BASE = $Base }
$env:MOCK_SCENARIO = $Scenario
. (Join-Path $PSScriptRoot 'mock-invoke-restmethod.ps1')
. (Join-Path $PSScriptRoot 'step2.ps1')
