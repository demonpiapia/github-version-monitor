#Requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$TestDir,
    [Parameter(Mandatory=$true)][string]$Scenario     # success|not_found|server_500|rate_429|network|forbidden|auth_error|metadata_incomplete|invalid_response
)

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'   # F2

# =====================================================================
# t3-mock-harness.ps1
# Purpose: T3 API-failure mock test. Uses mock-invoke-restmethod.ps1 to
#          override Invoke-RestMethod / Invoke-WebRequest for step2 and step4.
# Contract:
#   - Sets MOCK_SCENARIO env for the primary latest query.
#   - Sets MOCK_SCENARIO_LIST for the list endpoint in step 4 review.
#     Decision recorded in mock-contract-selfcheck.txt:
#       - If main scenario is 'success'/'not_found'/'metadata_incomplete'/'invalid_response',
#         list endpoint returns default 2-item mock list ('list-success').
#       - If main scenario is 'server_500'/'rate_429'/'network', the
#         item is already flagged review=true; step 4 list endpoint also
#         returns 'list-success' (deterministic) to isolate the review
#         branch behavior from the primary-failure branch.
#       - HTML diagnostic (Invoke-WebRequest) is always mocked to 200 +
#         fixed HTML body with a <title>. This decision is EXPLICITLY
#         recorded to avoid dependence on real network.
#   - Steps 1, 3, 5 are invoked as-is (they do not call API endpoints).
#   - Same-process `&` calls; GITHUB_VERSION_MONITOR_BASE set to $TestDir.
# =====================================================================

if (-not (Test-Path $TestDir)) { throw "TESTDIR_NOT_FOUND: $TestDir" }

$env:GITHUB_VERSION_MONITOR_BASE = $TestDir
$env:MOCK_SCENARIO         = $Scenario
# Deterministic list decision (see contract above)
$env:MOCK_SCENARIO_LIST    = 'list-success'
if (-not (Test-Path 'env:GITHUB_TOKEN')) {
    # Step 2 checks $env:GITHUB_TOKEN for auth header; mock still works without a real token
    $env:GITHUB_TOKEN = 'mock-token-not-used-for-auth-in-mock-mode'
}

$libDir = $PSScriptRoot
if (-not $libDir) { $libDir = (Resolve-Path '.').Path }

# Load mock overrides BEFORE invoking step2/step4 so the functions replace
# the built-in cmdlets in the same session scope.
$mockPath = Join-Path $libDir 'mock-invoke-restmethod.ps1'
. $mockPath

Write-Output "T3_HARNESS_START"
Write-Output "TESTDIR=$TestDir"
Write-Output "MOCK_SCENARIO=$env:MOCK_SCENARIO"
Write-Output "MOCK_SCENARIO_LIST=$env:MOCK_SCENARIO_LIST"
Write-Output "MOCK_HTML_DECISION=200+fixed_html_body_with_title"
Write-Output "PID=$PID"

$allOutput = @()
$allRunStatuses = @()

foreach ($name in @('step1','step2','step3','step4','step5')) {
    $file = if ($name -eq 'step5') { 'step5-full.ps1' } else { "$name.ps1" }
    $path = Join-Path $libDir $file
    if (-not (Test-Path $path)) { throw "STEP_FILE_MISSING: $path" }
    Write-Output ("--- {0} BEGIN ({1}) ---" -f $name, $file)
    $out = & $path
    if ($null -ne $out) {
        if ($out -is [System.Collections.IEnumerable] -and -not ($out -is [string])) {
            foreach ($line in $out) { Write-Output $line; $allOutput += $line }
        } else {
            Write-Output $out; $allOutput += $out
        }
    }
    $allRunStatuses += @($out | Where-Object { $_ -match '^RUN_STATUS\|' })
    Write-Output ("--- {0} END ---" -f $name)
}

Write-Output "T3_HARNESS_END"
$allRunStatuses | ForEach-Object { Write-Output ("RUN_STATUS_OBSERVED={0}" -f $_) }
