#Requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$TestDir
)

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'   # F2: mandatory for try/catch semantics in step3

# =====================================================================
# t5-housekeeping-harness.ps1
# Purpose: T5 housekeeping failure injection. Recommended scheme B:
#          remove .monitor/backups/ before Step 3 runs so that
#          Get-ChildItem in step3's housekeeping block raises
#          PathNotFound; step3's try/catch catches it and emits
#          HOUSEKEEPING_WARNING|; core pipeline (step 4/5) proceeds.
#
# Contract:
#   - Step 1 creates .monitor/backups/ and drops one backup file.
#   - Harness deletes .monitor/backups/ (fully) between step 1 and step 3.
#   - Step 3 attempts housekeeping: Get-ChildItem $backupDir raises
#     PathNotFound; the outer try/catch wraps it and emits
#     HOUSEKEEPING_WARNING|backup/trash cleanup failed: <msg>.
#   - Because EAP=Stop at orchestrator level, non-terminating errors in
#     the try block get promoted into terminating errors so the catch
#     actually catches. This is why EAP=Stop is a hard requirement
#     (F2/D7) - without it the catch would NOT fire and HOUSEKEEPING_WARNING
#     would NOT be emitted, producing a false FAIL.
#   - Step 4/5 proceed normally; RUN_STATUS|success| expected.
# =====================================================================

if (-not (Test-Path $TestDir)) { throw "TESTDIR_NOT_FOUND: $TestDir" }

$env:GITHUB_VERSION_MONITOR_BASE = $TestDir
$libDir = $PSScriptRoot
if (-not $libDir) { $libDir = (Resolve-Path '.').Path }

Write-Output "T5_HARNESS_START"
Write-Output "TESTDIR=$TestDir"
Write-Output "PID=$PID"

$allOutput = @()
$allRunStatuses = @()

# ---- Step 1: creates .monitor/backups/ and drops one backup ----------
Write-Output "--- step1 BEGIN ---"
$s1 = & (Join-Path $libDir 'step1.ps1')
if ($null -ne $s1) {
    if ($s1 -is [System.Collections.IEnumerable] -and -not ($s1 -is [string])) {
        foreach ($line in $s1) { Write-Output $line; $allOutput += $line }
    } else { Write-Output $s1; $allOutput += $s1 }
}
$allRunStatuses += @($s1 | Where-Object { $_ -match '^RUN_STATUS\|' })
Write-Output "--- step1 END ---"

# ---- Step 2: normal fetch ---------------------------------------------
Write-Output "--- step2 BEGIN ---"
$s2 = & (Join-Path $libDir 'step2.ps1')
if ($null -ne $s2) {
    if ($s2 -is [System.Collections.IEnumerable] -and -not ($s2 -is [string])) {
        foreach ($line in $s2) { Write-Output $line; $allOutput += $line }
    } else { Write-Output $s2; $allOutput += $s2 }
}
$allRunStatuses += @($s2 | Where-Object { $_ -match '^RUN_STATUS\|' })
Write-Output "--- step2 END ---"

# ---- Scheme B: delete .monitor/backups/ BEFORE step3 ------------------
$backupDir = Join-Path $TestDir '.monitor\backups'
$backupsExisted = Test-Path $backupDir
if ($backupsExisted) {
    Remove-Item $backupDir -Recurse -Force -ErrorAction Stop
    Write-Output "T5_INJECT_BACKUPS_REMOVED=YES"
} else {
    Write-Output "T5_INJECT_BACKUPS_REMOVED=NO_DIR_PRESENT"
}
# Verify it's gone
$backupsStillThere = Test-Path $backupDir
Write-Output "T5_INJECT_BACKUPS_ABSENT=" + (-not $backupsStillThere)

# ---- Step 3: housekeeping should raise PathNotFound -> caught --------
Write-Output "--- step3 BEGIN (housekeeping failure expected) ---"
$s3 = & (Join-Path $libDir 'step3.ps1')
if ($null -ne $s3) {
    if ($s3 -is [System.Collections.IEnumerable] -and -not ($s3 -is [string])) {
        foreach ($line in $s3) { Write-Output $line; $allOutput += $line }
    } else { Write-Output $s3; $allOutput += $s3 }
}
$allRunStatuses += @($s3 | Where-Object { $_ -match '^RUN_STATUS\|' })
Write-Output "--- step3 END ---"

# ---- Step 4/5: normal -------------------------------------------------
foreach ($name in @('step4','step5')) {
    $file = if ($name -eq 'step5') { 'step5-full.ps1' } else { "$name.ps1" }
    Write-Output ("--- {0} BEGIN ---" -f $name)
    $out = & (Join-Path $libDir $file)
    if ($null -ne $out) {
        if ($out -is [System.Collections.IEnumerable] -and -not ($out -is [string])) {
            foreach ($line in $out) { Write-Output $line; $allOutput += $line }
        } else { Write-Output $out; $allOutput += $out }
    }
    $allRunStatuses += @($out | Where-Object { $_ -match '^RUN_STATUS\|' })
    Write-Output ("--- {0} END ---" -f $name)
}

# ---- Assertions ------------------------------------------------------
$warningLine = $allOutput | Where-Object { $_ -match '^HOUSEKEEPING_WARNING\|' }
$successLine = $allRunStatuses | Where-Object { $_ -match '^RUN_STATUS\|success\|' }
$failedLine  = $allRunStatuses | Where-Object { $_ -match '^RUN_STATUS\|failed\|' }

Write-Output "T5_HARNESS_END"
Write-Output ("ASSERT_WARNING_PRESENT={0}" -f (-not $null -and $warningLine.Count -gt 0))
Write-Output ("ASSERT_RUN_STATUS_SUCCESS={0}" -f (-not $null -and $successLine.Count -gt 0))
Write-Output ("ASSERT_RUN_STATUS_FAILED={0}" -f (-not $null -and $failedLine.Count -gt 0))
