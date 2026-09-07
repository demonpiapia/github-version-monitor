# Test wrapper: provide variable context for step5-lockrelease.ps1
# This does NOT modify the extracted production script
$ErrorActionPreference = 'Stop'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$monitorDir = Join-Path $base '.monitor'
$lockPath = Join-Path $monitorDir 'run.lock'
$commitSucceeded = $true  # step5-commit.ps1 already output COMMIT_OK
. (Join-Path (Split-Path $PSCommandPath) '..\lib\step5-lockrelease.ps1')
