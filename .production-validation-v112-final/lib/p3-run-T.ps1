#Requires -Version 7.0
# =====================================================================
# p3-run-T.ps1 - Phase 3 Test runner (T1 / T2)
# Parameters:
#   -TestId  : 'T1-PS7' | 'T2-success'
#   -Repos   : comma-separated list (default: microsoft/vscode,PowerShell/PowerShell)
#
# OUTPUT CONTRACT (Phase 3-fix, 2026-09-10):
#   <TestDir>/stdout.txt    : RAW pipeline stdout ONLY. No harness-side
#                             annotations, no RUN_STATUS_OBSERVED, no
#                             PS_VERSION marker, no PIPELINE_END sidecar.
#   <TestDir>/stderr.txt    : RAW pipeline stderr ONLY.
#   <TestDir>/harness-aux.txt : ALL harness-side evidence lines:
#       PS_VERSION=<x>, PS_VERSION_MARKER=<x>, PIPELINE_START/PIPELINE_END
#       markers from harness, GITHUB_TOKEN_SET=<bool>, PIPELINE_EXIT,
#       PIPELINE_PID, RUN_MODE, CMD_TARGET, CMD_ARGS, BEFORE/AFTER
#       snapshot markers, SHA256_BEFORE/AFTER, LOCK_*_EXISTS, MD_CHANGED,
#       FIXTURE_EXIT, FIXTURE_MONITOR_DIR_EXISTS.
#                             If a downstream observer wants to know the
#                             observed RUN_STATUS it must inspect
#                             <TestDir>/run-status-sidecar.txt (see record D
#                             in harness-fix-log.md), not the SKILL stdout.
#
# Hard rules:
#   - Fixture isolation via $env:GITHUB_VERSION_MONITOR_BASE
#   - .monitor/ MUST NOT be pre-created by fixture
#   - All pipeline execution silent (background, redirected)
#   - Never Add-Content to <TestDir>/stdout.txt or stderr.txt
# =====================================================================
param(
    [Parameter(Mandatory=$true)][ValidateSet('T1-PS7','T2-success')][string]$TestId,
    [Parameter()][string]$Repos = 'microsoft/vscode,PowerShell/PowerShell'
)

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$root    = 'D:\AI\Workspace\automatic\github-version-monitor'
$libDir  = Join-Path $root '.production-validation-v112-final\lib'
$base    = Join-Path $root ('.production-validation-v112-final\' + $TestId)
$auxPath = Join-Path $base 'harness-aux.txt'

# Helper: append a line to harness-aux.txt only. Never touches stdout.txt.
function Add-Aux([string]$Line) {
    Add-Content -Path $auxPath -Value $Line -Encoding UTF8
}

Write-Output "TEST_ID=$TestId"
Write-Output "TEST_BASE=$base"
Write-Output "LIB_DIR=$libDir"

# ---------- Reset test dir (idempotent) ----------
if (Test-Path $base) {
    Remove-Item $base -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $base | Out-Null
# Initialize aux file with header (harness-side only).
$tsUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$auxLines = @(
    "# harness-aux.txt (Phase 3 harness-side evidence; NOT SKILL stdout)"
    "# Written by lib/p3-run-T.ps1. Do not confuse with stdout.txt."
    "AUX_BEGIN=$tsUtc"
    "TEST_ID=$TestId"
    "TEST_BASE=$base"
    "PS_VERSION=$($PSVersionTable.PSVersion.ToString())"
    "GITHUB_TOKEN_SET=" + (Test-Path 'env:GITHUB_TOKEN')
)
Set-Content -Path $auxPath -Value $auxLines -Encoding UTF8

# ---------- Step A: create fixture ----------
$fixtureScript = Join-Path $libDir 'create-fixture.ps1'
if (-not (Test-Path $fixtureScript)) { throw "FIXTURE_SCRIPT_MISSING: $fixtureScript" }

$fixtureStdout = (Join-Path $base 'fixture-stdout.txt')
$fixtureStderr = (Join-Path $base 'fixture-stderr.txt')

# Invoke fixture generator directly (same pwsh session)
& $fixtureScript -TestDir $base -Repos $Repos *> $fixtureStdout
Add-Aux "FIXTURE_EXIT=$LASTEXITCODE"

# Sanity: fixture must NOT have pre-created .monitor/
$monitorBefore = Test-Path (Join-Path $base '.monitor')
Add-Aux "FIXTURE_MONITOR_DIR_EXISTS=$monitorBefore"
if ($monitorBefore) {
    Add-Aux "FATAL: fixture created .monitor/ directory (forbidden)"
    exit 20
}
$mdPath = Join-Path $base '.output\GitHub更新监测列表.md'
if (-not (Test-Path $mdPath)) {
    Add-Aux "FATAL: fixture did not produce the required monitor markdown"
    exit 21
}

# ---------- Step B: BEFORE snapshot ----------
$beforeDir = Join-Path $base 'before'
$afterDir  = Join-Path $base 'after'
New-Item -ItemType Directory -Force -Path $beforeDir | Out-Null
New-Item -ItemType Directory -Force -Path $afterDir  | Out-Null

Copy-Item $mdPath (Join-Path $beforeDir 'GitHub更新监测列表.md')
if ($monitorBefore) {
    Copy-Item (Join-Path $base '.monitor') (Join-Path $beforeDir 'monitor') -Recurse -Force
}
Copy-Item $mdPath (Join-Path $base 'md-before.md')
$shaBefore = (Get-FileHash -Algorithm SHA256 -Path $mdPath).Hash.ToUpper()
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

# Result.json / lock state (both may be absent before first run)
$resultBeforePath = Join-Path $base 'result-before.json'
$lockBeforePath   = Join-Path $base 'lock-before.txt'
$resultFileBefore = Join-Path $base '.monitor\result.json'
$lockFileBefore   = Join-Path $base '.monitor\run.lock'

if (Test-Path $resultFileBefore) {
    Copy-Item $resultFileBefore $resultBeforePath
    Set-Content -Path $resultBeforePath '.placeholder-removed' -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $base 'result-before.json.placeholder') -ErrorAction SilentlyContinue
    Copy-Item $resultFileBefore $resultBeforePath -Force
} else {
    Set-Content -Path $resultBeforePath -Value ''
}
$lockBeforeExists = Test-Path $lockFileBefore
Set-Content -Path $lockBeforePath -Value ("LOCK_EXISTS=" + $lockBeforeExists)

Add-Aux "BEFORE_SNAPSHOT_OK"
Add-Aux "SHA256_BEFORE=$shaBefore"
Add-Aux "LOCK_BEFORE_EXISTS=$lockBeforeExists"

# ---------- Step C: run pipeline silently ----------
$pipelineScript = Join-Path $libDir 'run-full-pipeline.ps1'
if (-not (Test-Path $pipelineScript)) { throw "PIPELINE_SCRIPT_MISSING: $pipelineScript" }

# stdout.txt / stderr.txt carry ONLY the pipeline's raw streams.
$stdoutPath = Join-Path $base 'stdout.txt'
$stderrPath = Join-Path $base 'stderr.txt'

# Clear any pre-existing lock just in case (there shouldn't be any)
if (Test-Path $lockFileBefore) {
    Add-Aux "WARNING: stale lock removed before pipeline"
    Remove-Item $lockFileBefore -Force
}

# pwsh.exe path resolution
$pwshExe = 'C:\Program Files\PowerShell\7\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }
$cmdArgs = @('-NoProfile','-NonInteractive','-File',$pipelineScript,'-TestDir',$base)

# RUN_MODE kept as harness evidence (NOT appended to SKILL stdout.txt).
Add-Aux "RUN_MODE=Start-Process -RedirectStandardOutput/-RedirectStandardError (equivalent to pwsh -File ... *>&1 > stdout + stderr)"
Add-Aux "CMD_TARGET=$pipelineScript"
Add-Aux "CMD_ARGS=$($cmdArgs -join ' ')"

# Run pipeline via Start-Process (background, silent, redirected).
# Note on spec: exec-plan-v1.12-d.md §0.7 specifies
#   pwsh.exe ... *>&1 > <stdout.txt>
# which is pwsh-native syntax; equivalent separation via Start-Process
# -RedirectStandardOutput / -RedirectStandardError is used here so that
# BOTH stdout.txt and stderr.txt are captured to distinct files (which
# the cmd.exe shell does not understand as a *>&1 token).
$proc = Start-Process `
    -FilePath $pwshExe `
    -ArgumentList $cmdArgs `
    -NoNewWindow `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath

$pipeExit = $proc.ExitCode
Add-Aux "PIPELINE_EXIT=$pipeExit"
Add-Aux "PIPELINE_PID=$($proc.Id)"
$auxEndNow = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Add-Aux "PIPELINE_END_MARKER=harness recorded exit at $auxEndNow"

# ---------- Step D: AFTER snapshot ----------
Copy-Item $mdPath (Join-Path $afterDir 'GitHub更新监测列表.md')
if (Test-Path (Join-Path $base '.monitor')) {
    Copy-Item (Join-Path $base '.monitor') (Join-Path $afterDir 'monitor') -Recurse -Force
}
Copy-Item $mdPath (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash -Algorithm SHA256 -Path $mdPath).Hash.ToUpper()
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

$resultAfterPath = Join-Path $base 'result-after.json'
$lockAfterPath   = Join-Path $base 'lock-after.txt'
$resultFileAfter = Join-Path $base '.monitor\result.json'
$lockFileAfter   = Join-Path $base '.monitor\run.lock'

if (Test-Path $resultFileAfter) {
    Copy-Item $resultFileAfter $resultAfterPath -Force
} else {
    Set-Content -Path $resultAfterPath -Value ''
}
$lockAfterExists = Test-Path $lockFileAfter
Set-Content -Path $lockAfterPath -Value ("LOCK_EXISTS=" + $lockAfterExists)

Add-Aux "AFTER_SNAPSHOT_OK"
Add-Aux "SHA256_AFTER=$shaAfter"
Add-Aux "LOCK_AFTER_EXISTS=$lockAfterExists"
Add-Aux "MD_CHANGED=$($shaBefore -ne $shaAfter)"

# ---------- Step D2: PS_VERSION marker for Test 1 ----------
# Test 1 spec requires a PS_VERSION marker to be observable. It is written
# ONLY to harness-aux.txt; the SKILL stdout.txt is left untouched.
$psVersionMarker = "PS_VERSION_MARKER=" + $PSVersionTable.PSVersion.ToString()
Add-Aux $psVersionMarker

# ---------- Step D3: Run-status sidecar ----------
# The old run-full-pipeline.ps1 used to emit RUN_STATUS_OBSERVED to stdout,
# which caused RUN_STATUS|success| to appear twice in SKILL stdout.
# Post-fix, the pipeline stdout carries only the true SKILL RUN_STATUS
# line (from step5-full.ps1). Observers that want an explicit sidecar
# observation write it to run-status-sidecar.txt here, derived from the
# raw stdout (never appended to stdout.txt).
$sidecarPath = Join-Path $base 'run-status-sidecar.txt'
$rawStdout   = @()
if (Test-Path $stdoutPath) {
    $rawStdout = Get-Content $stdoutPath -Encoding UTF8
}
$observed = @($rawStdout | Where-Object { $_ -match '^RUN_STATUS\|' })
$sidecarLines = @(
    "# run-status-sidecar.txt (harness-derived; NOT part of SKILL stdout)"
    "RAW_STDOUT_RUN_STATUS_LINES=$($observed.Count)"
)
foreach ($o in $observed) { $sidecarLines += "RUN_STATUS_OBSERVED=$o" }
if ($observed.Count -eq 0) { $sidecarLines += "RUN_STATUS_OBSERVED=<none>" }
Set-Content -Path $sidecarPath -Value $sidecarLines -Encoding UTF8
Add-Aux "RUN_STATUS_SIDECAR_WRITTEN=$sidecarPath"

$auxEndFinal = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Add-Aux "AUX_END=$auxEndFinal"

# ---------- Step E: stdout/stderr summary to harness's console ----------
# These are logged to harness console only, NEVER to stdout.txt / stderr.txt.
Write-Output "--- pipeline stdout BEGIN ---"
if (Test-Path $stdoutPath) { Get-Content $stdoutPath -Encoding UTF8 | ForEach-Object { Write-Output $_ } }
Write-Output "--- pipeline stdout END ---"
Write-Output "--- pipeline stderr BEGIN ---"
if (Test-Path $stderrPath) { Get-Content $stderrPath -Encoding UTF8 | ForEach-Object { Write-Output $_ } }
Write-Output "--- pipeline stderr END ---"

Write-Output "PHASE3_TEST_DONE=$TestId"
