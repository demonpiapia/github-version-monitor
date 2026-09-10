#Requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$TestDir,
    [Parameter()][string]$TargetPath,        # default: <TestDir>\.output\GitHub更新监测列表.md
    [Parameter()][string]$LockFile           # default: <TestDir>\.monitor\run.lock
)

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'   # F2

# =====================================================================
# t4-write-failure-harness.ps1
# Purpose: T4 write-failure injection. Hold an external file lock on the
#          step-5 write target AFTER steps 1..4 complete and BEFORE step 5
#          runs, so that step 5's Set-Content / Move-Item path fails.
#
# Contract (B1 revision, verified):
#   - Lock holder launches via Start-Process -WindowStyle Hidden.
#   - Uses 4-arg overload: File.Open(path, FileMode.Open, FileAccess.Read,
#     FileShare.Read). FileShare.Read is INTENTIONAL - 3-arg binds to wrong
#     overload; FileShare::None is NOT used here because it would refuse
#     the harness's own later reads.
#   - After OPENED_OK marker, harness runs step 5 in-process.
#   - Harness then kills the lock holder via Stop-Process.
#   - Harness prints each step's output and RUN_STATUS assertions.
#
# Note on Step 5 behavior: with the target file open for write-block,
# step 5's `Move-Item -Path $tmp -Destination $md -Force` typically raises
# an IOException. Because step 5 wraps Move-Item in a bare `catch {}`,
# the exception is caught and reported as RUNTIME_ERROR (not
# VALIDATE_ERROR). If a subsequent Set-Content to $tmp fails first,
# step 5 emits RUNTIME_ERROR for that. Either way the RUN_STATUS
# terminates as `failed` and the lock remains unreleased (assertion).
# =====================================================================

if (-not (Test-Path $TestDir)) { throw "TESTDIR_NOT_FOUND: $TestDir" }

$env:GITHUB_VERSION_MONITOR_BASE = $TestDir
$libDir = $PSScriptRoot
if (-not $libDir) { $libDir = (Resolve-Path '.').Path }

$holdTarget = if ($TargetPath) { $TargetPath } else { Join-Path $TestDir '.output\GitHub更新监测列表.md' }
if (-not (Test-Path $holdTarget)) { throw "HOLD_TARGET_MISSING: $holdTarget" }

Write-Output "T4_HARNESS_START"
Write-Output "TESTDIR=$TestDir"
Write-Output "HOLD_TARGET=$holdTarget"
Write-Output "PID=$PID"

# ---- Step 1-4: run normally in-process ---------------------------------
foreach ($name in @('step1','step2','step3','step4')) {
    $path = Join-Path $libDir "$name.ps1"
    if (-not (Test-Path $path)) { throw "STEP_FILE_MISSING: $path" }
    Write-Output ("--- {0} BEGIN ({1}) ---" -f $name, (Split-Path $path -Leaf))
    $out = & $path
    if ($null -ne $out) {
        if ($out -is [System.Collections.IEnumerable] -and -not ($out -is [string])) {
            foreach ($line in $out) { Write-Output $line }
        } else { Write-Output $out }
    }
    Write-Output ("--- {0} END ---" -f $name)
}

# ---- Step 4 completion timestamp ---------------------------------------
$step4Done = [DateTimeOffset]::UtcNow.ToString('o')
Write-Output "STEP4_DONE_TS=$step4Done"

# ---- Start lock-holder as external process -----------------------------
$lockHolderPath = Join-Path $libDir 'lock-holder.ps1'
if (-not (Test-Path $lockHolderPath)) { throw "LOCKHOLDER_MISSING: $lockHolderPath" }

$markerFile = Join-Path $TestDir 't4-lock-opened.marker'
if (Test-Path $markerFile) { Remove-Item $markerFile -Force -ErrorAction SilentlyContinue }

$startArgs = @(
    '-NoProfile','-NonInteractive','-File',$lockHolderPath,
    '-Target',$holdTarget,
    '-MarkerPath',$markerFile
)
$pwshBin = (Get-Command pwsh).Source
$proc = Start-Process -FilePath $pwshBin -ArgumentList $startArgs -WindowStyle Hidden -PassThru -NoNewWindow
$lockStartedTs = [DateTimeOffset]::UtcNow.ToString('o')
Write-Output "LOCKHOLDER_PID=$($proc.Id)"
Write-Output "LOCK_STARTED_TS=$lockStartedTs"

# ---- Poll for OPENED_OK (max 15s) ---------------------------------------
$deadline = (Get-Date).AddSeconds(15)
$opened = $false
while ((Get-Date) -lt $deadline) {
    if (Test-Path $markerFile) {
        $markerContent = Get-Content $markerFile -Raw -ErrorAction SilentlyContinue
        if ($markerContent -like 'OPENED_OK*') { $opened = $true; break }
        if ($markerContent -like 'OPEN_FAILED*') {
            Write-Output "LOCKHOLDER_OPEN_FAILED=$markerContent"
            throw "LOCKHOLDER_OPEN_FAILED"
        }
    }
    Start-Sleep -Milliseconds 250
}
if (-not $opened) {
    Write-Output "LOCKHOLDER_OPEN_TIMEOUT"
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    throw "LOCKHOLDER_OPEN_TIMEOUT"
}
Write-Output "LOCKHOLDER_OPENED_OK"

# ---- Step 5: run in-process while lock is held -------------------------
Write-Output "--- step5 BEGIN (write-failure expected) ---"
$step5Out = @()
$lockBeforeStep5 = Test-Path (Join-Path $TestDir '.monitor\run.lock')
try {
    $step5Path = Join-Path $libDir 'step5-full.ps1'
    $step5Out = & $step5Path
    if ($null -ne $step5Out) {
        if ($step5Out -is [System.Collections.IEnumerable] -and -not ($step5Out -is [string])) {
            foreach ($line in $step5Out) { Write-Output $line }
        } else { Write-Output $step5Out }
    }
} finally {
    # Always release the external lock holder
    try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch {}
}
Write-Output "--- step5 END ---"

# ---- Assertions --------------------------------------------------------
$lockAfterStep5 = Test-Path (Join-Path $TestDir '.monitor\run.lock')
Write-Output "LOCK_EXISTED_BEFORE_STEP5=$lockBeforeStep5"
Write-Output "LOCK_EXISTS_AFTER_STEP5=$lockAfterStep5"
Write-Output "T4_HARNESS_END"
