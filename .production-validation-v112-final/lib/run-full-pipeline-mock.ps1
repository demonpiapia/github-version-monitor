#Requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$TestDir
)

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'   # F2

# =====================================================================
# run-full-pipeline-mock.ps1
# Purpose: Phase 4 Test 3 variant of run-full-pipeline.ps1 that dot-sources
#          lib/mock-invoke-restmethod.ps1 BEFORE any step runs, so that
#          the mock Invoke-RestMethod / Invoke-WebRequest overrides are
#          in effect for step2 and step4 within the same pwsh.exe session.
#
# OUTPUT CONTRACT:
#   - Emits PIPELINE_START / TESTDIR / GITHUB_VERSION_MONITOR_BASE /
#     GITHUB_TOKEN_SET / PID / step BEGIN/END markers / PIPELINE_END.
#   - NO harness-side annotations (no RUN_STATUS_OBSERVED, no PS_VERSION
#     marker). Downstream harness writes run-status-sidecar.txt derived
#     from this raw stdout.
#
# MOCK CONTRACT (three explicit decisions recorded in mock-config.txt):
#   1) MOCK_SCENARIO=server_500  -> latest endpoint returns 500 exception
#   2) MOCK_SCENARIO_LIST=list-success -> /releases?per_page=5 returns 2 items
#   3) HTML diagnostic Invoke-WebRequest -> 200 + fixed body with <title>
# =====================================================================

if (-not (Test-Path $TestDir)) { throw "TESTDIR_NOT_FOUND: $TestDir" }

$env:GITHUB_VERSION_MONITOR_BASE = $TestDir
$libDir = $PSScriptRoot
if (-not $libDir) { $libDir = (Resolve-Path '.').Path }

# ---- Load mocks FIRST (before ANY step script runs) --------------------
# The mock script emits a contract-summary banner on dot-source; that
# banner is HARNESS-side, so we suppress it and instead record the mock
# decisions in mock-config.txt (written by the harness) and here in
# stdout.txt only as MOCK_SCENARIO / MOCK_SCENARIO_LIST marker lines.
$mockPath = Join-Path $libDir 'mock-invoke-restmethod.ps1'
if (-not (Test-Path $mockPath)) { throw "MOCK_SCRIPT_MISSING: $mockPath" }
$null = . $mockPath

$steps = @(
    @{ Name = 'step1';    File = 'step1.ps1' },
    @{ Name = 'step2';    File = 'step2.ps1' },
    @{ Name = 'step3';    File = 'step3.ps1' },
    @{ Name = 'step4';    File = 'step4.ps1' },
    @{ Name = 'step5';    File = 'step5-full.ps1' }
)

Write-Output "PIPELINE_START"
Write-Output "TESTDIR=$TestDir"
Write-Output "GITHUB_VERSION_MONITOR_BASE=$env:GITHUB_VERSION_MONITOR_BASE"
Write-Output "GITHUB_TOKEN_SET=" + (Test-Path 'env:GITHUB_TOKEN')
Write-Output "PID=$PID"

foreach ($s in $steps) {
    $path = Join-Path $libDir $s.File
    if (-not (Test-Path $path)) { throw "STEP_FILE_MISSING: $path" }
    Write-Output ("--- {0} BEGIN ({1}) ---" -f $s.Name, $s.File)
    $output = & $path
    if ($null -ne $output) {
        if ($output -is [System.Collections.IEnumerable] -and -not ($output -is [string])) {
            foreach ($line in $output) { Write-Output $line }
        } else {
            Write-Output $output
        }
    }
    Write-Output ("--- {0} END ---" -f $s.Name)
}

Write-Output "PIPELINE_END"
