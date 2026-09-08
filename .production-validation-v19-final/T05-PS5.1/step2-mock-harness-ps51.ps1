param([string]$Scenario, [string]$Base, [string]$LibDir)
if ($Base) { $env:GITHUB_VERSION_MONITOR_BASE = $Base }
$env:MOCK_SCENARIO = $Scenario
. (Join-Path $LibDir 'mock-invoke-restmethod-ps51.ps1')
. (Join-Path $env:GITHUB_VERSION_MONITOR_BASE 'step2.utf8bom.ps1')
