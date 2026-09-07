# Full pipeline runner: executes Steps 1-5(full) in a single PowerShell process
# This ensures $PID is shared across all steps for lock ownership
param(
    [string]$TestDir,
    [string]$LibDir,
    [bool]$SkipStep4 = $false
)
$ErrorActionPreference = 'Continue'
$base = $TestDir
if (-not $base) { $base = $env:GITHUB_VERSION_MONITOR_BASE }
if (-not $base) { throw 'GITHUB_VERSION_MONITOR_BASE not set' }
$env:GITHUB_VERSION_MONITOR_BASE = $base

if (-not $LibDir) { $LibDir = Join-Path $base 'lib' }

$allOutput = @()
$shouldStop = $false

# Step 1
$allOutput += "===== EXECUTING step1 ====="
try {
    $step1Output = & (Join-Path $LibDir 'step1.ps1') 2>&1
    $allOutput += $step1Output
    $combined1 = ($step1Output | Out-String)
    if ($combined1 -match 'STATE_MISSING\|' -or $combined1 -match 'LOCKED\|') {
        $shouldStop = $true
    }
} catch { $allOutput += "STEP1_EXCEPTION: $_" }
$allOutput += "===== END step1 ====="

if (-not $shouldStop) {
    # Step 2
    $allOutput += "===== EXECUTING step2 ====="
    try {
        $step2Output = & (Join-Path $LibDir 'step2.ps1') 2>&1
        $allOutput += $step2Output
        $combined2 = ($step2Output | Out-String)
        if ($combined2 -match 'PARSE_ERROR\|' -or $combined2 -match 'RUNTIME_ERROR\|' -or $combined2 -match 'LOCKED\|') {
            $shouldStop = $true
        }
    } catch { $allOutput += "STEP2_EXCEPTION: $_" }
    $allOutput += "===== END step2 ====="
}

if (-not $shouldStop) {
    # Step 3
    $allOutput += "===== EXECUTING step3 ====="
    try {
        $step3Output = & (Join-Path $LibDir 'step3.ps1') 2>&1
        $allOutput += $step3Output
    } catch { $allOutput += "STEP3_EXCEPTION: $_" }
    $allOutput += "===== END step3 ====="
}

if (-not $shouldStop -and -not $SkipStep4) {
    # Step 4 (review)
    $allOutput += "===== EXECUTING step4 ====="
    try {
        $step4Output = & (Join-Path $LibDir 'step4.ps1') 2>&1
        $allOutput += $step4Output
        $combined4 = ($step4Output | Out-String)
        if ($combined4 -match 'REVIEW_WRITE_ERROR\|' -or $combined4 -match 'RUNTIME_ERROR\|') {
            $shouldStop = $true
        }
    } catch { $allOutput += "STEP4_EXCEPTION: $_" }
    $allOutput += "===== END step4 ====="
}

if (-not $shouldStop) {
    # Step 5 (full: commit + lock release)
    $allOutput += "===== EXECUTING step5-full ====="
    try {
        $step5Output = & (Join-Path $LibDir 'step5-full.ps1') 2>&1
        $allOutput += $step5Output
    } catch { $allOutput += "STEP5_EXCEPTION: $_" }
    $allOutput += "===== END step5-full ====="
}

if ($shouldStop) {
    $allOutput += "PIPELINE_STOPPED_EARLY"
}

# Output everything
$allOutput | ForEach-Object { Write-Output $_ }
