# PS5.1 wrapper: reads step2.ps1 (UTF-8 no BOM) and re-saves with UTF-8 BOM
# so that PS5.1's default parser can read the Chinese characters correctly.
#
# This is a test-harness-only workaround. The original lib/step2.ps1 is NOT modified.
# A BOM'd copy is written to the test directory for execution.
param([string]$Scenario, [string]$Base)
if ($Base) { $env:GITHUB_VERSION_MONITOR_BASE = $Base }
$env:MOCK_SCENARIO = $Scenario

$lib = $PSScriptRoot
$base = $env:GITHUB_VERSION_MONITOR_BASE

# Dot-source the PS5.1-compatible mock
. (Join-Path $lib 'mock-invoke-restmethod-ps51.ps1')

# Read step2.ps1 as UTF-8 (no BOM) and re-save with UTF-8 BOM
$step2Path = Join-Path $lib 'step2.ps1'
$step2Content = [System.IO.File]::ReadAllText($step2Path, [System.Text.Encoding]::UTF8)
$step2BomPath = Join-Path $base 'step2.utf8bom.ps1'
[System.IO.File]::WriteAllText($step2BomPath, $step2Content, (New-Object System.Text.UTF8Encoding $true))

# Execute the BOM'd copy
. $step2BomPath
