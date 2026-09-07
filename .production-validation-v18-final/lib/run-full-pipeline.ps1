# Full pipeline runner: executes Steps 1-5(full) in a single PowerShell process
# Ensures $PID is shared across all steps for lock ownership verification.
# Stops early on terminal conditions: STATE_MISSING / LOCKED / PARSE_ERROR / RUNTIME_ERROR / REVIEW_WRITE_ERROR.
param(
    [Parameter(Mandatory=$true)][string]$TestDir,
    [string]$LibDir,
    [bool]$SkipStep4 = $false
)
$ErrorActionPreference = 'Continue'
$base = $TestDir
$env:GITHUB_VERSION_MONITOR_BASE = $base
if (-not $LibDir) { $LibDir = Join-Path $base 'lib' }

$allOutput = @()
$shouldStop = $false
$stopReason = ''

function Invoke-Step([string]$Name, [string]$Script) {
    $allOutput += "===== EXECUTING $Name ====="
    try {
        $out = & (Join-Path $LibDir $Script) 2>&1
        $allOutput += $out
        return ($out | Out-String)
    } catch {
        $allOutput += ("{0}_EXCEPTION: {1}" -f $Name.ToUpper(), $_)
        return ""
    }
    finally { $allOutput += "===== END $Name =====" }
}

# Step 1
$c1 = Invoke-Step 'step1' 'step1.ps1'
if ($c1 -match 'STATE_MISSING\|') { $shouldStop = $true; $stopReason = 'STATE_MISSING' }
elseif ($c1 -match 'LOCKED\|')    { $shouldStop = $true; $stopReason = 'LOCKED' }

if (-not $shouldStop) {
    $c2 = Invoke-Step 'step2' 'step2.ps1'
    if ($c2 -match 'PARSE_ERROR\|')   { $shouldStop = $true; $stopReason = 'PARSE_ERROR' }
    elseif ($c2 -match 'RUNTIME_ERROR\|') { $shouldStop = $true; $stopReason = 'RUNTIME_ERROR' }
    elseif ($c2 -match 'LOCKED\|')    { $shouldStop = $true; $stopReason = 'LOCKED' }
}

if (-not $shouldStop) {
    Invoke-Step 'step3' 'step3.ps1' | Out-Null
}

if (-not $shouldStop -and -not $SkipStep4) {
    $c4 = Invoke-Step 'step4' 'step4.ps1'
    if ($c4 -match 'REVIEW_WRITE_ERROR\|') { $shouldStop = $true; $stopReason = 'REVIEW_WRITE_ERROR' }
    elseif ($c4 -match 'RUNTIME_ERROR\|')  { $shouldStop = $true; $stopReason = 'RUNTIME_ERROR' }
}

if (-not $shouldStop) {
    Invoke-Step 'step5-full' 'step5-full.ps1' | Out-Null
}

if ($shouldStop) {
    $allOutput += "PIPELINE_STOPPED_EARLY|$stopReason"
}

$allOutput | ForEach-Object { Write-Output $_ }
