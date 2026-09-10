param([string]$TestDir = 'T4-write-failure')

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
$ErrorActionPreference = 'Stop'

# Phase 4 Test 4 runner - core write failure via external file lock.
# Design: run step1..step4 in the current pwsh.exe process (so the
# PID ownership chain in run.lock is intact); AFTER step4 completes,
# start an external lock-holder process that opens the target md with
# FileShare::Read (blocking delete/move); then run step5 in the same
# process; step5's Move-Item is expected to throw IOException ->
# RUNTIME_ERROR + tmp cleanup + RUN_STATUS|failed|.
#
# stdout.txt: pipeline output ONLY (step markers + step outputs).
# stderr.txt: pipeline stderr.
# harness-aux.txt: all harness-side metadata (before/after snapshot,
# SHA256, lock-holder PID/timestamps, marker state, etc.).
# lock-holder-stdout.txt / lock-holder-stderr.txt /
# lock-holder-start-timestamp.txt / open-marker.txt: external
# lock-holder evidence.

$root      = 'D:\AI\Workspace\automatic\github-version-monitor'
$libDir    = Join-Path $root '.production-validation-v112-final\lib'
$base      = Join-Path $root ('.production-validation-v112-final\' + $TestDir)
$auxPath   = Join-Path $base 'harness-aux.txt'
$stdoutP   = Join-Path $base 'stdout.txt'
$stderrP   = Join-Path $base 'stderr.txt'
$valPath   = Join-Path $base 'validation.json'
$reportP   = Join-Path $base 'test-report.md'
$lockPidFile = Join-Path $base 'lock-holder-pid.txt'
$lockStartTs = Join-Path $base 'lock-holder-start-timestamp.txt'
$lockStdout  = Join-Path $base 'lock-holder-stdout.txt'
$lockStderr  = Join-Path $base 'lock-holder-stderr.txt'
$openMarker  = Join-Path $base 'open-marker.txt'

if (Test-Path $base) { Remove-Item $base -Recurse -Force }
New-Item -ItemType Directory -Force -Path $base | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $base
if (-not (Test-Path 'env:GITHUB_TOKEN')) {
    $env:GITHUB_TOKEN = 'mock-token-not-used-for-auth-in-T4'
}

$tsUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$tokenSet = (Test-Path 'env:GITHUB_TOKEN')
$auxHead = @(
    "# harness-aux.txt (Phase 4 Test 4 harness-side evidence; NOT SKILL stdout)"
    "# Written by lib/p4-run-T4.ps1. Do not confuse with stdout.txt."
    "AUX_BEGIN=$tsUtc"
    "TEST_ID=$TestDir"
    "TEST_BASE=$base"
    "PS_VERSION=$($PSVersionTable.PSVersion.ToString())"
    "GITHUB_TOKEN_SET=$tokenSet"
    "PID=$PID"
)
Set-Content -Path $auxPath -Value $auxHead -Encoding UTF8

function Add-Aux([string]$Line) { Add-Content -Path $auxPath -Value $Line -Encoding UTF8 }

# Capture pipeline stdout/stderr into an in-memory list; write at the
# end so nothing is added after the pipeline has finished.
$pipeLines = [System.Collections.Generic.List[string]]::new()
$pipeErr   = [System.Collections.Generic.List[string]]::new()

function Emit-Line([string]$Line) { $pipeLines.Add($Line) }
function Emit-Err([string]$Line) { $pipeErr.Add($Line) }

# ---- Pipeline header ----------------------------------------------------
Emit-Line 'PIPELINE_START'
Emit-Line "TESTDIR=$base"
Emit-Line "GITHUB_VERSION_MONITOR_BASE=$base"
Emit-Line "GITHUB_TOKEN_SET=$tokenSet"
Emit-Line "PID=$PID"

# ---- Create fixture -----------------------------------------------------
$fixtureScript = Join-Path $libDir 'create-fixture.ps1'
if (-not (Test-Path $fixtureScript)) { throw "FIXTURE_SCRIPT_MISSING: $fixtureScript" }
$fixtureOut = Join-Path $base 'fixture-stdout.txt'
& $fixtureScript -TestDir $base -Repos 'microsoft/vscode,PowerShell/PowerShell' *> $fixtureOut
$fixtureExit = $LASTEXITCODE
Add-Aux "FIXTURE_EXIT=$fixtureExit"

$monitorBefore = Test-Path (Join-Path $base '.monitor')
Add-Aux "FIXTURE_MONITOR_DIR_EXISTS=$monitorBefore"
if ($monitorBefore) {
    Add-Aux "FATAL: fixture created .monitor directory (forbidden)"
    exit 20
}

$mdFile = Get-ChildItem (Join-Path $base '.output') -Filter '*.md' | Select-Object -First 1
if (-not $mdFile) {
    Add-Aux 'FATAL: no .md file under .output directory'
    exit 22
}
$mdName = $mdFile.Name
$mdPath = $mdFile.FullName
Add-Aux "MD_TARGET=$mdPath"

# ---- Before snapshot ----------------------------------------------------
$beforeDir = Join-Path $base 'before'
$afterDir  = Join-Path $base 'after'
New-Item -ItemType Directory -Force -Path $beforeDir | Out-Null
New-Item -ItemType Directory -Force -Path $afterDir  | Out-Null

Copy-Item $mdPath (Join-Path $beforeDir $mdName)
Copy-Item $mdPath (Join-Path $base 'md-before.md')
$shaBefore = (Get-FileHash -Algorithm SHA256 -Path $mdPath).Hash.ToUpper()
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

$resultFileBefore = Join-Path $base '.monitor\result.json'
$resultBeforePath = Join-Path $base 'result-before.json'
if (Test-Path $resultFileBefore) {
    Copy-Item $resultFileBefore $resultBeforePath -Force
} else {
    Set-Content -Path $resultBeforePath -Value ''
}

$lockFileBefore = Join-Path $base '.monitor\run.lock'
$lockBeforeExists = Test-Path $lockFileBefore
Set-Content -Path (Join-Path $base 'lock-before.txt') -Value ("LOCK_EXISTS=" + $lockBeforeExists)

Add-Aux "BEFORE_SNAPSHOT_OK"
Add-Aux "SHA256_BEFORE=$shaBefore"
Add-Aux "LOCK_BEFORE_EXISTS=$lockBeforeExists"

# ---- Run step 1..4 in-process -------------------------------------------
$step5Path = Join-Path $libDir 'step5-full.ps1'
if (-not (Test-Path $step5Path)) { throw "STEP5_MISSING: $step5Path" }

foreach ($name in @('step1','step2','step3','step4')) {
    $path = Join-Path $libDir "$name.ps1"
    if (-not (Test-Path $path)) { throw "STEP_FILE_MISSING: $path" }
    $fileName = [System.IO.Path]::GetFileName($path)
    Emit-Line ("--- {0} BEGIN ({1}) ---" -f $name, $fileName)
    $out = & $path
    if ($null -ne $out) {
        if ($out -is [System.Collections.IEnumerable] -and -not ($out -is [string])) {
            foreach ($line in $out) { Emit-Line $line }
        } else {
            Emit-Line $out
        }
    }
    Emit-Line ("--- {0} END ---" -f $name)
}

# ---- Step 4 completion timestamp ----------------------------------------
$step4DoneTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
Add-Aux "STEP4_DONE_TS=$step4DoneTs"

# ---- Start external lock-holder -----------------------------------------
$lockHolderPath = Join-Path $libDir 'lock-holder.ps1'
if (-not (Test-Path $lockHolderPath)) { throw "LOCKHOLDER_MISSING: $lockHolderPath" }

# Clear any pre-existing marker
if (Test-Path $openMarker) { Remove-Item $openMarker -Force -ErrorAction SilentlyContinue }

$pwshExe = 'C:\Program Files\PowerShell\7\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }

$lockStartArgs = @(
    '-NoProfile','-NonInteractive','-File',$lockHolderPath,
    '-Target',$mdPath,
    '-MarkerPath',$openMarker
)
$lockStartedTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
Set-Content -Path $lockStartTs -Value $lockStartedTs -Encoding UTF8

# Redirect lock-holder stdout/stderr to dedicated evidence files
$lockProc = Start-Process -FilePath $pwshExe -ArgumentList $lockStartArgs -NoNewWindow -PassThru -RedirectStandardOutput $lockStdout -RedirectStandardError $lockStderr

Set-Content -Path $lockPidFile -Value ("LOCKHOLDER_PID=" + $lockProc.Id) -Encoding UTF8
Add-Aux "LOCKHOLDER_PID=$($lockProc.Id)"
Add-Aux "LOCK_STARTED_TS=$lockStartedTs"

# Poll for OPENED_OK (max 15s)
$deadline = (Get-Date).AddSeconds(15)
$opened = $false
$openMarkerContent = ''
while ((Get-Date) -lt $deadline) {
    if (Test-Path $openMarker) {
        $openMarkerContent = (Get-Content $openMarker -Raw -ErrorAction SilentlyContinue)
        if ($openMarkerContent -like 'OPENED_OK*') { $opened = $true; break }
        if ($openMarkerContent -like 'OPEN_FAILED*') {
            Add-Aux "LOCKHOLDER_OPEN_FAILED=$openMarkerContent"
            try { Stop-Process -Id $lockProc.Id -Force -ErrorAction Stop } catch {}
            throw "LOCKHOLDER_OPEN_FAILED"
        }
    }
    Start-Sleep -Milliseconds 200
}
if (-not $opened) {
    Add-Aux "LOCKHOLDER_OPEN_TIMEOUT"
    try { Stop-Process -Id $lockProc.Id -Force -ErrorAction Stop } catch {}
    throw "LOCKHOLDER_OPEN_TIMEOUT"
}
Add-Aux "LOCKHOLDER_OPENED_OK"
Add-Aux "OPEN_MARKER_CONTENT=$openMarkerContent"

# ---- Run step 5 in-process while lock is held ---------------------------
$lockBeforeStep5 = Test-Path (Join-Path $base '.monitor\run.lock')
Add-Aux "LOCK_EXISTED_BEFORE_STEP5=$lockBeforeStep5"

Emit-Line "--- step5 BEGIN (step5-full.ps1) ---"
Emit-Line "--- step5 BEGIN (write-failure expected via external FileShare::Read lock) ---"

$step5Out = @()
try {
    $step5Out = & $step5Path
    if ($null -ne $step5Out) {
        if ($step5Out -is [System.Collections.IEnumerable] -and -not ($step5Out -is [string])) {
            foreach ($line in $step5Out) { Emit-Line $line }
        } else {
            Emit-Line $step5Out
        }
    }
} finally {
    # Always release the external lock holder
    try { Stop-Process -Id $lockProc.Id -Force -ErrorAction Stop } catch {}
}

Emit-Line "--- step5 END ---"
Emit-Line "PIPELINE_END"

# ---- Write pipeline stdout/stderr to disk -------------------------------
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($stdoutP, $pipeLines, $utf8NoBom)
if ($pipeErr.Count -gt 0) {
    [System.IO.File]::WriteAllLines($stderrP, $pipeErr, $utf8NoBom)
} else {
    [System.IO.File]::WriteAllText($stderrP, '', $utf8NoBom)
}

# ---- After snapshot -----------------------------------------------------
$lockAfterStep5 = Test-Path (Join-Path $base '.monitor\run.lock')
Set-Content -Path (Join-Path $base 'lock-after.txt') -Value ("LOCK_EXISTS=" + $lockAfterStep5)

# After external lock is released, md.tmp should have been cleaned by
# step5's catch block. Give it a moment to reflect.
Start-Sleep -Milliseconds 300
$tmpPath = "$mdPath.tmp"
$tmpExists = Test-Path $tmpPath

Copy-Item $mdPath (Join-Path $afterDir $mdName)
if (Test-Path (Join-Path $base '.monitor')) {
    Copy-Item (Join-Path $base '.monitor') (Join-Path $afterDir 'monitor') -Recurse -Force
}
Copy-Item $mdPath (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash -Algorithm SHA256 -Path $mdPath).Hash.ToUpper()
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

$resultFileAfter = Join-Path $base '.monitor\result.json'
$resultAfterPath = Join-Path $base 'result-after.json'
if (Test-Path $resultFileAfter) {
    Copy-Item $resultFileAfter $resultAfterPath -Force
} else {
    Set-Content -Path $resultAfterPath -Value ''
}

$backupDir = Join-Path $base '.monitor\backups'
$backupCount = 0
if (Test-Path $backupDir) {
    $backupFiles = Get-ChildItem $backupDir -File
    $backupCount = $backupFiles.Count
}

Add-Aux "AFTER_SNAPSHOT_OK"
Add-Aux "SHA256_AFTER=$shaAfter"
Add-Aux "LOCK_AFTER_EXISTS=$lockAfterStep5"
$mdChanged = ($shaBefore -ne $shaAfter)
Add-Aux "MD_CHANGED=$mdChanged"
Add-Aux "TMP_EXISTS_AFTER=$tmpExists"
Add-Aux "BACKUP_COUNT=$backupCount"

# Confirm the lock holder process is truly gone
$lockHolderStillRunning = $false
if (Get-Process -Id $lockProc.Id -ErrorAction SilentlyContinue) {
    $lockHolderStillRunning = $true
}
Add-Aux "LOCKHOLDER_STILL_RUNNING=$lockHolderStillRunning"

# ---- Verification ------------------------------------------------------
function Count-Mark([string]$Path, [string]$Pattern) {
    if (-not (Test-Path $Path)) { return 0 }
    $lines = Get-Content $Path -Encoding UTF8
    return @($lines | Where-Object { $_ -match $Pattern }).Count
}

$counts = [ordered]@{
    RUN_STATUS_SUCCESS   = (Count-Mark $stdoutP '^RUN_STATUS\|success\|')
    RUN_STATUS_FAILED    = (Count-Mark $stdoutP '^RUN_STATUS\|failed\|')
    COMMIT_OK            = (Count-Mark $stdoutP '^COMMIT_OK\|')
    BACKUP_OK            = (Count-Mark $stdoutP '^BACKUP_OK\|')
    FETCH_COMPLETE       = (Count-Mark $stdoutP '^FETCH_COMPLETE\|')
    REVIEW_WRITE_OK      = (Count-Mark $stdoutP '^REVIEW_WRITE_OK\|')
    RUNTIME_ERROR        = (Count-Mark $stdoutP '^RUNTIME_ERROR\|')
    PARSE_ERROR          = (Count-Mark $stdoutP '^PARSE_ERROR\|')
    LOCKED               = (Count-Mark $stdoutP '^LOCKED\|')
    VALIDATE_ERROR       = (Count-Mark $stdoutP '^VALIDATE_ERROR\|')
    PS_VERSION_LINE      = (Count-Mark $stdoutP '^PS_VERSION\|')
    RUN_STATUS_OBSERVED  = (Count-Mark $stdoutP '^RUN_STATUS_OBSERVED=')
    HARNESS_START_MARKER = (Count-Mark $stdoutP '^T4_HARNESS_START$')
    HARNESS_END_MARKER   = (Count-Mark $stdoutP '^T4_HARNESS_END$')
    LOCKHOLDER_OPENED_OK_LINE = (Count-Mark $stdoutP '^LOCKHOLDER_OPENED_OK$')
    STEP4_DONE_TS_LINE   = (Count-Mark $stdoutP '^STEP4_DONE_TS=')
    LOCK_STARTED_TS_LINE = (Count-Mark $stdoutP '^LOCK_STARTED_TS=')
    LOCKHOLDER_PID_LINE  = (Count-Mark $stdoutP '^LOCKHOLDER_PID=')
}

$checks = @()

$checks += [ordered]@{
    item     = "md_unchanged"
    expected = "SHA256 before == SHA256 after"
    actual   = "before=$shaBefore / after=$shaAfter / equal=$($shaBefore -ceq $shaAfter)"
    verdict  = $(if ($shaBefore -ceq $shaAfter) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "md_tmp_cleaned"
    expected = "False"
    actual   = "$tmpExists"
    verdict  = $(if ($tmpExists -eq $false) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "backup_retained"
    expected = ">=1"
    actual   = "$backupCount"
    verdict  = $(if ($backupCount -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "RUN_STATUS_failed_count"
    expected = "1"
    actual   = "$($counts.RUN_STATUS_FAILED)"
    verdict  = $(if ($counts.RUN_STATUS_FAILED -eq 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "RUN_STATUS_success_count"
    expected = "0"
    actual   = "$($counts.RUN_STATUS_SUCCESS)"
    verdict  = $(if ($counts.RUN_STATUS_SUCCESS -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "COMMIT_OK_count"
    expected = "0"
    actual   = "$($counts.COMMIT_OK)"
    verdict  = $(if ($counts.COMMIT_OK -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "lock_released_after_run"
    expected = "False"
    actual   = "$lockAfterStep5"
    verdict  = $(if ($lockAfterStep5 -eq $false) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "lockholder_process_stopped"
    expected = "False"
    actual   = "$lockHolderStillRunning"
    verdict  = $(if ($lockHolderStillRunning -eq $false) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "lockholder_OPENED_OK_marker_written"
    expected = "OPENED_OK present"
    actual   = $openMarkerContent
    verdict  = $(if ($openMarkerContent -like 'OPENED_OK*') { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "step1_backup_ok_observed"
    expected = ">=1"
    actual   = "$($counts.BACKUP_OK)"
    verdict  = $(if ($counts.BACKUP_OK -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "step2_fetch_complete_observed"
    expected = ">=1"
    actual   = "$($counts.FETCH_COMPLETE)"
    verdict  = $(if ($counts.FETCH_COMPLETE -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "step4_review_write_ok_observed"
    expected = ">=1"
    actual   = "$($counts.REVIEW_WRITE_OK)"
    verdict  = $(if ($counts.REVIEW_WRITE_OK -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "RUNTIME_ERROR_present_in_stdout"
    expected = ">=1"
    actual   = "$($counts.RUNTIME_ERROR)"
    verdict  = $(if ($counts.RUNTIME_ERROR -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "PARSE_ERROR_count"
    expected = "0"
    actual   = "$($counts.PARSE_ERROR)"
    verdict  = $(if ($counts.PARSE_ERROR -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "LOCKED_count"
    expected = "0"
    actual   = "$($counts.LOCKED)"
    verdict  = $(if ($counts.LOCKED -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "stdout_no_PS_VERSION_line"
    expected = "0"
    actual   = "$($counts.PS_VERSION_LINE)"
    verdict  = $(if ($counts.PS_VERSION_LINE -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "stdout_no_RUN_STATUS_OBSERVED_line"
    expected = "0"
    actual   = "$($counts.RUN_STATUS_OBSERVED)"
    verdict  = $(if ($counts.RUN_STATUS_OBSERVED -eq 0) { 'PASS' } else { 'FAIL' })
}
$harnessMarkerTotal = $counts.HARNESS_START_MARKER + $counts.HARNESS_END_MARKER + $counts.LOCKHOLDER_OPENED_OK_LINE + $counts.STEP4_DONE_TS_LINE + $counts.LOCK_STARTED_TS_LINE + $counts.LOCKHOLDER_PID_LINE
$checks += [ordered]@{
    item     = "stdout_no_harness_markers"
    expected = "0"
    actual   = "$harnessMarkerTotal"
    verdict  = $(if ($harnessMarkerTotal -eq 0) { 'PASS' } else { 'FAIL' })
}

$passCount = @($checks | Where-Object { $_.verdict -eq 'PASS' }).Count
$failCount = @($checks | Where-Object { $_.verdict -eq 'FAIL' }).Count
$overall = if ($failCount -eq 0) { 'PASS' } else { 'FAIL' }

$validationObj = [ordered]@{
    test_id      = $TestDir
    scenario     = 'core_write_failure_via_external_file_share_read_lock'
    overall      = $overall
    pass_count   = $passCount
    fail_count   = $failCount
    total_count  = $checks.Count
    counts       = $counts
    checks       = $checks
    sha256_before = $shaBefore
    sha256_after  = $shaAfter
    md_changed    = $mdChanged
    lock_after    = $lockAfterStep5
    tmp_exists    = $tmpExists
    backup_count  = $backupCount
    lockholder_pid = $lockProc.Id
    lockholder_started_ts = $lockStartedTs
    step4_done_ts = $step4DoneTs
    lockholder_still_running = $lockHolderStillRunning
}
$validationObj | ConvertTo-Json -Depth 10 | Set-Content -Path $valPath -Encoding UTF8
Add-Aux "VALIDATION_WRITTEN=$valPath"
Add-Aux "OVERALL=$overall"
Add-Aux "PASS_COUNT=$passCount"
Add-Aux "FAIL_COUNT=$failCount"

# ---- Report ------------------------------------------------------------
$rawStdout = Get-Content $stdoutP -Encoding UTF8
$rep = [System.Text.StringBuilder]::new()
[void]$rep.AppendLine('# Test 4 - core write failure validation report')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('Test ID: **' + $TestDir + '**')
[void]$rep.AppendLine('Test dir: `' + $base + '`')
[void]$rep.AppendLine('Injection: external lock-holder with FileShare::Read blocks Move-Item -Force')
[void]$rep.AppendLine('Executor: `lib/p4-run-T4.ps1`')
[void]$rep.AppendLine('Fixture repos: microsoft/vscode, PowerShell/PowerShell')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Verdict: **' + $overall + '** (' + $passCount + ' PASS / ' + $failCount + ' FAIL)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## stdout.txt key-marker independent counts (grep against RAW stdout)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('| Marker | Count |')
[void]$rep.AppendLine('|---|---|')
foreach ($k in $counts.Keys) {
    $v = $counts[$k]
    [void]$rep.AppendLine('| `' + $k + '` | ' + $v + ' |')
}
[void]$rep.AppendLine('| RAW stdout total lines | ' + $rawStdout.Count + ' |')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Verification items')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('| # | Item | Expected | Actual | Verdict |')
[void]$rep.AppendLine('|---|---|---|---|---|')
$idx = 1
foreach ($c in $checks) {
    [void]$rep.AppendLine('| ' + $idx + ' | `' + $c.item + '` | `' + $c.expected + '` | `' + $c.actual + '` | ' + $c.verdict + ' |')
    $idx++
}
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Lock-holder evidence')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('- LOCKHOLDER_PID: `' + $lockProc.Id + '`')
[void]$rep.AppendLine('- LOCK_STARTED_TS: `' + $lockStartedTs + '`')
[void]$rep.AppendLine('- STEP4_DONE_TS: `' + $step4DoneTs + '` (must precede LOCK_STARTED_TS)')
[void]$rep.AppendLine('- open-marker.txt content: `' + $openMarkerContent + '`')
[void]$rep.AppendLine('- lock-holder-stdout.txt: `' + $lockStdout + '`')
[void]$rep.AppendLine('- lock-holder-stderr.txt: `' + $lockStderr + '`')
[void]$rep.AppendLine('- lock-holder-pid.txt: `' + $lockPidFile + '`')
[void]$rep.AppendLine('- lock-holder-start-timestamp.txt: `' + $lockStartTs + '`')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## SKILL integrity')
[void]$rep.AppendLine('- SKILL-v1.12.md / lib/stepX.ps1 read-only throughout; harness did NOT modify the SKILL or step scripts.')
[void]$rep.AppendLine('')

[System.IO.File]::WriteAllText($reportP, $rep.ToString(), $utf8NoBom)
Add-Aux "REPORT_WRITTEN=$reportP"

$auxEndFinal = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Add-Aux "AUX_END=$auxEndFinal"

Write-Output "PHASE4_T4_DONE=$TestDir OVERALL=$overall PASS=$passCount FAIL=$failCount"
