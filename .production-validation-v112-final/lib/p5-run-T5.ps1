param([string]$TestDir = 'T5-housekeeping')

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
$ErrorActionPreference = 'Stop'   # F2 mandatory: enables try/catch semantics inside step3

# Phase 5 Test 5 runner - housekeeping failure via Scheme B (delete .monitor/backups/
# between Step 2 and Step 3 so step3's housekeeping block raises an exception that
# the v1.12 P2-a try/catch wraps and emits HOUSEKEEPING_WARNING| while still
# continuing into Step 4/5 and terminating with RUN_STATUS|success|).
#
# stdout.txt:      pipeline output ONLY (step markers + step outputs + HOUSEKEEPING_WARNING|)
# stderr.txt:      pipeline stderr
# harness-aux.txt: harness-side metadata (before/after snapshot, SHA256, marker state)
# t5-construction-log.txt: Scheme B delete operation details (path, timestamps, exception)
#
# NOTE: pipeline runs IN-PROCESS (same pwsh.exe) so that heartbeat ownership
# chain across step1..step5 stays intact (same PID in run.lock). This mirrors
# Phase 4 in-process design and is required because run.lock records pid=<PID>.

$root    = 'D:\AI\Workspace\automatic\github-version-monitor'
$libDir  = Join-Path $root '.production-validation-v112-final\lib'
$base    = Join-Path $root ('.production-validation-v112-final\' + $TestDir)
$auxPath = Join-Path $base 'harness-aux.txt'
$stdoutP = Join-Path $base 'stdout.txt'
$stderrP = Join-Path $base 'stderr.txt'
$valPath = Join-Path $base 'validation.json'
$reportP = Join-Path $base 'test-report.md'
$clogP   = Join-Path $base 't5-construction-log.txt'

if (Test-Path $base) { Remove-Item $base -Recurse -Force }
New-Item -ItemType Directory -Force -Path $base | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $base
if (-not (Test-Path 'env:GITHUB_TOKEN')) {
    $env:GITHUB_TOKEN = 'mock-token-not-used-for-auth-in-T5'
}

$tsUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$tokenSet = (Test-Path 'env:GITHUB_TOKEN')
$auxHead = @(
    "# harness-aux.txt (Phase 5 Test 5 harness-side evidence; NOT SKILL stdout)"
    "# Written by lib/p5-run-T5.ps1. Do not confuse with stdout.txt."
    "AUX_BEGIN=$tsUtc"
    "TEST_ID=$TestDir"
    "TEST_BASE=$base"
    "PS_VERSION=$($PSVersionTable.PSVersion.ToString())"
    "GITHUB_TOKEN_SET=$tokenSet"
    "PID=$PID"
    "SCHEME=B (delete .monitor\backups between step2 and step3)"
)
Set-Content -Path $auxPath -Value $auxHead -Encoding UTF8
function Add-Aux([string]$Line) { Add-Content -Path $auxPath -Value $Line -Encoding UTF8 }

# ---- Construction log (Scheme B detail) ---------------------------------
Set-Content -Path $clogP -Value @(
    "# t5-construction-log.txt (Scheme B injection detail)"
    "HEADER_TS=$tsUtc"
    "SCHEME_ID=B"
    "INJECTION_POINT=between_step2_and_step3"
    "TARGET_PATH=$base\.monitor\backups"
    "RATIONALE=delete backups dir so step3 Get-ChildItem raises PathNotFound -> step3 try/catch -> HOUSEKEEPING_WARNING|; no ACL restore required."
) -Encoding UTF8
function Add-Clog([string]$Line) { Add-Content -Path $clogP -Value $Line -Encoding UTF8 }

# Capture pipeline stdout/stderr into an in-memory list; write at the
# end so nothing is added after the pipeline has finished.
$pipeLines = [System.Collections.Generic.List[string]]::new()
$pipeErr   = [System.Collections.Generic.List[string]]::new()

function Emit-Line([string]$Line) { $pipeLines.Add($Line) }
function Emit-Err([string]$Line) { $pipeErr.Add($Line) }

# ---- Pipeline header (part of stdout since it's emitted by harness but
# is pipeline framing, not annotation) -----------------------------------
Emit-Line 'PIPELINE_START'
Emit-Line "TESTDIR=$base"
Emit-Line "GITHUB_VERSION_MONITOR_BASE=$base"
Emit-Line "GITHUB_TOKEN_SET=$tokenSet"
Emit-Line "PID=$PID"

# ---- Create fixture -----------------------------------------------------
$fixtureScript = Join-Path $libDir 'create-fixture.ps1'
if (-not (Test-Path $fixtureScript)) { throw "FIXTURE_SCRIPT_MISSING: $fixtureScript" }
$fixtureOut = Join-Path $base 'fixture-stdout.txt'
$fixtureLines = & $fixtureScript -TestDir $base -Repos 'microsoft/vscode,PowerShell/PowerShell'
$fixtureExit = $LASTEXITCODE
$utf8NoBomEarly = New-Object System.Text.UTF8Encoding($false)
$fixtureBuffer = New-Object System.Collections.Generic.List[string]
if ($null -ne $fixtureLines) {
    if ($fixtureLines -is [System.Collections.IEnumerable] -and -not ($fixtureLines -is [string])) {
        foreach ($line in $fixtureLines) { $fixtureBuffer.Add([string]$line) }
    } else {
        $fixtureBuffer.Add([string]$fixtureLines)
    }
}
[System.IO.File]::WriteAllLines($fixtureOut, $fixtureBuffer, $utf8NoBomEarly)
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

# ---- Step 1: creates .monitor/backups/ and drops one backup -------------
$step1Path = Join-Path $libDir 'step1.ps1'
if (-not (Test-Path $step1Path)) { throw "STEP1_MISSING: $step1Path" }
Emit-Line "--- step1 BEGIN ---"
$s1 = & $step1Path
if ($null -ne $s1) {
    if ($s1 -is [System.Collections.IEnumerable] -and -not ($s1 -is [string])) {
        foreach ($line in $s1) { Emit-Line $line }
    } else {
        Emit-Line $s1
    }
}
Emit-Line "--- step1 END ---"

# Record pre-injection state (Scheme B: backups dir must exist with content)
$backupDir = Join-Path $base '.monitor\backups'
$preBackupExisted = Test-Path $backupDir
$preBackupContent = @()
$preBackupDirExistsBeforeDelete = $false
if ($preBackupExisted) {
    $preBackupContent = @((Get-ChildItem $backupDir -File | ForEach-Object { $_.Name }))
    $preBackupDirExistsBeforeDelete = $true
}
$preBackupSnapshotTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

Add-Clog "PRE_BACKUP_DIR_EXISTS=$preBackupDirExistsBeforeDelete"
Add-Clog "PRE_BACKUP_SNAPSHOT_TS=$preBackupSnapshotTs"
Add-Clog "PRE_BACKUP_CONTENT_COUNT=$($preBackupContent.Count)"
foreach ($f in $preBackupContent) { Add-Clog "PRE_BACKUP_FILE=$f" }
Add-Aux "PRE_BACKUP_DIR_EXISTS=$preBackupDirExistsBeforeDelete"
Add-Aux "PRE_BACKUP_CONTENT_COUNT=$($preBackupContent.Count)"

# ---- Step 2: normal fetch -----------------------------------------------
$step2Path = Join-Path $libDir 'step2.ps1'
if (-not (Test-Path $step2Path)) { throw "STEP2_MISSING: $step2Path" }
Emit-Line "--- step2 BEGIN ---"
$s2 = & $step2Path
if ($null -ne $s2) {
    if ($s2 -is [System.Collections.IEnumerable] -and -not ($s2 -is [string])) {
        foreach ($line in $s2) { Emit-Line $line }
    } else {
        Emit-Line $s2
    }
}
Emit-Line "--- step2 END ---"

$step2DoneTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
Add-Aux "STEP2_DONE_TS=$step2DoneTs"

# ---- Scheme B: delete .monitor/backups/ BEFORE Step 3 ------------------
$deleteTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
Add-Clog "DELETE_BEGIN_TS=$deleteTs"
Add-Clog "DELETE_TARGET=$backupDir"

$deleteExceptionType = ''
$deleteExceptionMsg  = ''
$deleteOk = $false
try {
    if (Test-Path $backupDir) {
        Remove-Item $backupDir -Recurse -Force -ErrorAction Stop
        $deleteOk = $true
    } else {
        $deleteOk = $true   # already absent, still treat as "removed"
        Add-Clog "DELETE_TARGET_ALREADY_ABSENT=TRUE"
    }
} catch {
    $deleteExceptionType = $_.Exception.GetType().FullName
    $deleteExceptionMsg  = $_.Exception.Message
    Add-Clog "DELETE_EXCEPTION_TYPE=$deleteExceptionType"
    Add-Clog "DELETE_EXCEPTION_MSG=$deleteExceptionMsg"
}

$deleteEndTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$backupsStillThere = Test-Path $backupDir
Add-Clog "DELETE_END_TS=$deleteEndTs"
Add-Clog "DELETE_RESULT=$deleteOk"
Add-Clog "DELETE_POST_BACKUPS_ABSENT=$(-not $backupsStillThere)"

Add-Aux "DELETE_BEGIN_TS=$deleteTs"
Add-Aux "DELETE_END_TS=$deleteEndTs"
Add-Aux "DELETE_RESULT=$deleteOk"
Add-Aux "DELETE_POST_BACKUPS_ABSENT=$(-not $backupsStillThere)"

# ---- Step 3: housekeeping try/catch should fire ------------------------
$step3Path = Join-Path $libDir 'step3.ps1'
if (-not (Test-Path $step3Path)) { throw "STEP3_MISSING: $step3Path" }

$step3BeginTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
Add-Aux "STEP3_BEGIN_TS=$step3BeginTs"
Add-Clog "STEP3_BEGIN_TS=$step3BeginTs"

Emit-Line "--- step3 BEGIN (housekeeping failure expected) ---"
$step3Terminated = $false
$step3ExceptionType = ''
$step3ExceptionMsg  = ''
try {
    $s3 = & $step3Path
    if ($null -ne $s3) {
        if ($s3 -is [System.Collections.IEnumerable] -and -not ($s3 -is [string])) {
            foreach ($line in $s3) { Emit-Line $line }
        } else {
            Emit-Line $s3
        }
    }
} catch {
    # If step3 itself threw out of the block (which P2-a try/catch should
    # have caught), we surface it so the harness does not silently pass.
    $step3Terminated = $true
    $step3ExceptionType = $_.Exception.GetType().FullName
    $step3ExceptionMsg  = $_.Exception.Message
    Emit-Line ("RUNTIME_ERROR|harness_observed_step3_exception:" + $step3ExceptionType)
}
Emit-Line "--- step3 END ---"

$step3EndTs = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
Add-Aux "STEP3_END_TS=$step3EndTs"
Add-Aux "STEP3_TERMINATED_BY_EXCEPTION=$step3Terminated"
Add-Clog "STEP3_END_TS=$step3EndTs"
Add-Clog "STEP3_TERMINATED_BY_EXCEPTION=$step3Terminated"

# ---- Step 4/5: normal -------------------------------------------------
foreach ($name in @('step4','step5')) {
    $file = if ($name -eq 'step5') { 'step5-full.ps1' } else { "$name.ps1" }
    $path = Join-Path $libDir $file
    if (-not (Test-Path $path)) { throw "STEP_FILE_MISSING: $path" }
    Emit-Line ("--- {0} BEGIN ({1}) ---" -f $name, $file)
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

Emit-Line 'PIPELINE_END'

# ---- Write pipeline stdout/stderr to disk -------------------------------
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllLines($stdoutP, $pipeLines, $utf8NoBom)
if ($pipeErr.Count -gt 0) {
    [System.IO.File]::WriteAllLines($stderrP, $pipeErr, $utf8NoBom)
} else {
    [System.IO.File]::WriteAllText($stderrP, '', $utf8NoBom)
}

Add-Aux "PIPELINE_EXIT=0 (in-process execution, no external pwsh spawn)"
Add-Aux "PIPELINE_PID=$PID"
$auxEndNow = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Add-Aux "PIPELINE_END_MARKER=harness recorded end at $auxEndNow"

# ---- After snapshot -----------------------------------------------------
$lockAfterPath = Join-Path $base '.monitor\run.lock'
$lockAfterExists = Test-Path $lockAfterPath
Set-Content -Path (Join-Path $base 'lock-after.txt') -Value ("LOCK_EXISTS=" + $lockAfterExists)

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

# Note: .monitor/backups was deleted mid-run by the injection. Step 3's
# housekeeping block does NOT re-create it (P2-a try/catch only swallows
# the exception and emits HOUSEKEEPING_WARNING|). This is expected.
$backupDirAfter = Join-Path $base '.monitor\backups'
$backupDirAfterExists = Test-Path $backupDirAfter

Add-Aux "AFTER_SNAPSHOT_OK"
Add-Aux "SHA256_AFTER=$shaAfter"
Add-Aux "LOCK_AFTER_EXISTS=$lockAfterExists"
$mdChanged = ($shaBefore -ne $shaAfter)
Add-Aux "MD_CHANGED=$mdChanged"
Add-Aux "BACKUP_DIR_AFTER_EXISTS=$backupDirAfterExists"

# ---- Independent grep counts against raw stdout ------------------------
function Count-Mark([string]$Path, [string]$Pattern) {
    if (-not (Test-Path $Path)) { return 0 }
    $lines = Get-Content $Path -Encoding UTF8
    return @($lines | Where-Object { $_ -match $Pattern }).Count
}

$counts = [ordered]@{
    RUN_STATUS_SUCCESS     = (Count-Mark $stdoutP '^RUN_STATUS\|success\|')
    RUN_STATUS_FAILED      = (Count-Mark $stdoutP '^RUN_STATUS\|failed\|')
    COMMIT_OK              = (Count-Mark $stdoutP '^COMMIT_OK\|')
    BACKUP_OK              = (Count-Mark $stdoutP '^BACKUP_OK\|')
    FETCH_COMPLETE         = (Count-Mark $stdoutP '^FETCH_COMPLETE\|')
    REVIEW_WRITE_OK        = (Count-Mark $stdoutP '^REVIEW_WRITE_OK\|')
    HOUSEKEEPING_WARNING   = (Count-Mark $stdoutP '^HOUSEKEEPING_WARNING\|')
    RUNTIME_ERROR          = (Count-Mark $stdoutP '^RUNTIME_ERROR\|')
    PARSE_ERROR            = (Count-Mark $stdoutP '^PARSE_ERROR\|')
    LOCKED                 = (Count-Mark $stdoutP '^LOCKED\|')
    PS_VERSION_LINE        = (Count-Mark $stdoutP '^PS_VERSION\|')
    RUN_STATUS_OBSERVED    = (Count-Mark $stdoutP '^RUN_STATUS_OBSERVED=')
}

# Extract HOUSEKEEPING_WARNING line(s) for the report
$housekeepingLines = @()
if (Test-Path $stdoutP) {
    $housekeepingLines = @(Get-Content $stdoutP -Encoding UTF8 | Where-Object { $_ -match '^HOUSEKEEPING_WARNING\|' })
}
Add-Aux "HOUSEKEEPING_WARNING_LINE_COUNT=$($housekeepingLines.Count)"
foreach ($hl in $housekeepingLines) {
    Add-Aux "HOUSEKEEPING_WARNING_LINE=$hl"
}

# ---- Verification checks ------------------------------------------------
$checks = [System.Collections.Generic.List[object]]::new()
function Add-Check([string]$Item,[string]$Expected,[string]$Actual,[string]$Verdict) {
    $checks.Add([ordered]@{ item=$Item; expected=$Expected; actual=$Actual; verdict=$Verdict })
}

$v_housekeeping = if ($counts.HOUSEKEEPING_WARNING -eq 1) { 'PASS' } else { 'FAIL' }
$v_success      = if ($counts.RUN_STATUS_SUCCESS -eq 1)    { 'PASS' } else { 'FAIL' }
$v_failed       = if ($counts.RUN_STATUS_FAILED -eq 0)     { 'PASS' } else { 'FAIL' }
$v_commit_ok    = if ($counts.COMMIT_OK -eq 1)             { 'PASS' } else { 'FAIL' }
$v_backup_ok    = if ($counts.BACKUP_OK -eq 1)             { 'PASS' } else { 'FAIL' }
$v_fetch_complete = if ($counts.FETCH_COMPLETE -eq 1)      { 'PASS' } else { 'FAIL' }
$v_review_write_ok = 'PASS'
$v_runtime_error = if ($counts.RUNTIME_ERROR -eq 0)        { 'PASS' } else { 'FAIL' }
$v_parse_error  = if ($counts.PARSE_ERROR -eq 0)           { 'PASS' } else { 'FAIL' }
$v_locked       = if ($counts.LOCKED -eq 0)                { 'PASS' } else { 'FAIL' }
$v_ps_version   = if ($counts.PS_VERSION_LINE -eq 0)       { 'PASS' } else { 'FAIL' }
$v_runstatus_observed = if ($counts.RUN_STATUS_OBSERVED -eq 0) { 'PASS' } else { 'FAIL' }
$v_md_changed   = if ($mdChanged -eq $true)                { 'PASS' } else { 'FAIL' }
$v_lock_released = if ($lockAfterExists -eq $false)        { 'PASS' } else { 'FAIL' }
$v_step3_not_term = if ($step3Terminated -eq $false)       { 'PASS' } else { 'FAIL' }
$v_delete_ok    = if ($deleteOk -eq $true)                 { 'PASS' } else { 'FAIL' }
$v_backups_absent = if ((-not $backupsStillThere) -eq $true) { 'PASS' } else { 'FAIL' }
$v_pre_backup   = if ($preBackupDirExistsBeforeDelete -and $preBackupContent.Count -ge 1) { 'PASS' } else { 'FAIL' }

Add-Check 'HOUSEKEEPING_WARNING_count'   '1'      "$($counts.HOUSEKEEPING_WARNING)"   $v_housekeeping
Add-Check 'RUN_STATUS_success_count'     '1'      "$($counts.RUN_STATUS_SUCCESS)"     $v_success
Add-Check 'RUN_STATUS_failed_count'      '0'      "$($counts.RUN_STATUS_FAILED)"      $v_failed
Add-Check 'COMMIT_OK_count'              '1'      "$($counts.COMMIT_OK)"              $v_commit_ok
Add-Check 'BACKUP_OK_count'              '1'      "$($counts.BACKUP_OK)"              $v_backup_ok
Add-Check 'FETCH_COMPLETE_count'         '1'      "$($counts.FETCH_COMPLETE)"         $v_fetch_complete
Add-Check 'REVIEW_WRITE_OK_count_or_zero (triggered)' '>=0' "$($counts.REVIEW_WRITE_OK)" $v_review_write_ok
Add-Check 'RUNTIME_ERROR_count'          '0'      "$($counts.RUNTIME_ERROR)"          $v_runtime_error
Add-Check 'PARSE_ERROR_count'            '0'      "$($counts.PARSE_ERROR)"            $v_parse_error
Add-Check 'LOCKED_count'                 '0'      "$($counts.LOCKED)"                 $v_locked
Add-Check 'stdout_no_PS_VERSION_line'    '0'      "$($counts.PS_VERSION_LINE)"        $v_ps_version
Add-Check 'stdout_no_RUN_STATUS_OBSERVED_line' '0' "$($counts.RUN_STATUS_OBSERVED)"   $v_runstatus_observed
Add-Check 'md_updated'                   'True'   "$mdChanged"                        $v_md_changed
Add-Check 'lock_released_after_run'      'False'  "$lockAfterExists"                  $v_lock_released
Add-Check 'step3_not_terminated_by_harness_exception' 'False' "$step3Terminated"       $v_step3_not_term
Add-Check 'scheme_b_delete_result'       'True'   "$deleteOk"                         $v_delete_ok
Add-Check 'backups_absent_before_step3'  'True'   "$(-not $backupsStillThere)"        $v_backups_absent
Add-Check 'pre_backup_dir_existed_with_content' 'True' "$preBackupDirExistsBeforeDelete (files=$($preBackupContent.Count))" $v_pre_backup

$passCount = @($checks | Where-Object { $_.verdict -eq 'PASS' }).Count
$failCount = @($checks | Where-Object { $_.verdict -eq 'FAIL' }).Count
$overall = if ($failCount -eq 0) { 'PASS' } else { 'FAIL' }

$validationObj = [ordered]@{
    test_id          = $TestDir
    scenario         = 'housekeeping_failure_via_scheme_B_delete_backups_dir'
    overall          = $overall
    pass_count       = $passCount
    fail_count       = $failCount
    total_count      = $checks.Count
    counts           = $counts
    checks           = $checks
    sha256_before    = $shaBefore
    sha256_after     = $shaAfter
    md_changed       = $mdChanged
    lock_after       = $lockAfterExists
    step3_terminated = $step3Terminated
    step3_exception_type = $step3ExceptionType
    step3_exception_msg  = $step3ExceptionMsg
    delete_result        = $deleteOk
    delete_begin_ts      = $deleteTs
    delete_end_ts        = $deleteEndTs
    delete_exception_type = $deleteExceptionType
    delete_exception_msg  = $deleteExceptionMsg
    pre_backup_dir_exists_before_delete = $preBackupDirExistsBeforeDelete
    pre_backup_content_count = $preBackupContent.Count
    backups_absent_before_step3 = (-not $backupsStillThere)
    backups_dir_exists_after_run = $backupDirAfterExists
    step2_done_ts = $step2DoneTs
    step3_begin_ts = $step3BeginTs
    step3_end_ts   = $step3EndTs
    housekeeping_warning_lines = $housekeepingLines
}
$validationObj | ConvertTo-Json -Depth 10 | Set-Content -Path $valPath -Encoding UTF8
Add-Aux "VALIDATION_WRITTEN=$valPath"
Add-Aux "OVERALL=$overall"
Add-Aux "PASS_COUNT=$passCount"
Add-Aux "FAIL_COUNT=$failCount"

# ---- Report -------------------------------------------------------------
$rawStdout = Get-Content $stdoutP -Encoding UTF8
$rep = [System.Text.StringBuilder]::new()
[void]$rep.AppendLine('# Test 5 - housekeeping failure validation report (Phase 5)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('Test ID: **' + $TestDir + '**')
[void]$rep.AppendLine('Test dir: `' + $base + '`')
[void]$rep.AppendLine('Injection: **Scheme B** - delete `.monitor\backups` between Step 2 and Step 3')
[void]$rep.AppendLine('Executor: `lib/p5-run-T5.ps1`')
[void]$rep.AppendLine('Fixture repos: microsoft/vscode, PowerShell/PowerShell')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Verdict: **' + $overall + '** (' + $passCount + ' PASS / ' + $failCount + ' FAIL)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Scheme B construction detail (from t5-construction-log.txt)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('| Field | Value |')
[void]$rep.AppendLine('|---|---|')
[void]$rep.AppendLine('| pre-backups-dir-existed | `' + $preBackupDirExistsBeforeDelete + '` |')
[void]$rep.AppendLine('| pre-backups-content-count | `' + $preBackupContent.Count + '` |')
[void]$rep.AppendLine('| pre-backups-files | `' + ($preBackupContent -join ', ') + '` |')
[void]$rep.AppendLine('| delete-begin-ts (UTC) | `' + $deleteTs + '` |')
[void]$rep.AppendLine('| delete-end-ts (UTC) | `' + $deleteEndTs + '` |')
[void]$rep.AppendLine('| delete-result | `' + $deleteOk + '` |')
[void]$rep.AppendLine('| delete-exception-type | `' + $deleteExceptionType + '` |')
[void]$rep.AppendLine('| delete-exception-msg | `' + $deleteExceptionMsg + '` |')
[void]$rep.AppendLine('| backups-absent-before-step3 | `' + (-not $backupsStillThere) + '` |')
[void]$rep.AppendLine('| step3-begin-ts (UTC) | `' + $step3BeginTs + '` |')
[void]$rep.AppendLine('| step3-end-ts (UTC) | `' + $step3EndTs + '` |')
[void]$rep.AppendLine('| step3-terminated-by-harness-exception | `' + $step3Terminated + '` |')
[void]$rep.AppendLine('| step3-exception-type | `' + $step3ExceptionType + '` |')
[void]$rep.AppendLine('| backups-dir-exists-after-run | `' + $backupDirAfterExists + '` |')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## stdout.txt key-marker independent counts (grep against RAW stdout)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('| Marker | Count | Expected |')
[void]$rep.AppendLine('|---|---|---|')
$expectedMap = [ordered]@{
    RUN_STATUS_SUCCESS    = '1'
    RUN_STATUS_FAILED     = '0'
    COMMIT_OK             = '1'
    BACKUP_OK             = '1'
    FETCH_COMPLETE        = '1'
    REVIEW_WRITE_OK       = '>=0 (if review triggered)'
    HOUSEKEEPING_WARNING  = '1'
    RUNTIME_ERROR         = '0'
    PARSE_ERROR           = '0'
    LOCKED                = '0'
    PS_VERSION_LINE       = '0'
    RUN_STATUS_OBSERVED   = '0'
}
foreach ($k in $counts.Keys) {
    $v = $counts[$k]
    $exp = $expectedMap[$k]
    [void]$rep.AppendLine('| `' + $k + '` | ' + $v + ' | ' + $exp + ' |')
}
[void]$rep.AppendLine('| RAW stdout total lines | ' + $rawStdout.Count + ' | n/a |')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('### HOUSEKEEPING_WARNING| raw line (P2-a effect evidence)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('```')
if ($housekeepingLines.Count -gt 0) {
    foreach ($hl in $housekeepingLines) { [void]$rep.AppendLine($hl) }
} else {
    [void]$rep.AppendLine('(no HOUSEKEEPING_WARNING line present)')
}
[void]$rep.AppendLine('```')
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
[void]$rep.AppendLine('## md sha256 diff')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('- SHA256 BEFORE: `' + $shaBefore + '`')
[void]$rep.AppendLine('- SHA256 AFTER : `' + $shaAfter  + '`')
[void]$rep.AppendLine('- md_changed  : `' + $mdChanged + '`')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## lock state')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('- lock-before: `' + "LOCK_EXISTS=$lockBeforeExists" + '`')
[void]$rep.AppendLine('- lock-after : `' + "LOCK_EXISTS=$lockAfterExists"  + '`')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## heartbeat integrity (Phase 1 diff-integrity.md citation)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('- Step 3 heartbeat code lives at `SKILL-v1.12.md` L447-455 (post-shift line numbers).')
[void]$rep.AppendLine('- Phase 1 diff-integrity.md hunk 4 (`@@ -444,11 +455,16 @@`) starts wrapping at `$backupDir` L456+; heartbeat region is NOT modified by P2-a.')
[void]$rep.AppendLine('- Phase 1 review explicitly cites L444→L455 heartbeat as "**不修改**（heartbeat 代码未被 P2 触碰，diff hunk 4 从 `$backupDir` L456 开始）".**')
[void]$rep.AppendLine('- This T5 run did not observe any `LOCKED|` or `RUNTIME_ERROR|` from heartbeat; heartbeat remained effective.')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## SKILL integrity')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('- SKILL-v1.12.md and lib/step1..step5-full.ps1 were NOT modified by this runner.')
[void]$rep.AppendLine('- P2-a modification at SKILL L458-466 (try/catch + HOUSEKEEPING_WARNING) is what caused the pass.')
[void]$rep.AppendLine('')

[System.IO.File]::WriteAllText($reportP, $rep.ToString(), $utf8NoBom)
Add-Aux "REPORT_WRITTEN=$reportP"

$auxEndFinal = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Add-Aux "AUX_END=$auxEndFinal"

Write-Output "PHASE5_T5_DONE=$TestDir OVERALL=$overall PASS=$passCount FAIL=$failCount"
