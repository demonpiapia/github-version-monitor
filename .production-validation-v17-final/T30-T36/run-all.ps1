#Requires -Version 7.0
<#
    Production Validation v1.7 Final - Tests T30-T36
    Concurrency and lock mechanism tests
#>
$testRoot = "d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T30-T36"
$commonDir = Join-Path $testRoot "common"
$allOutput = [System.Collections.Generic.List[string]]::new()
$testResults = [System.Collections.Generic.List[PSCustomObject]]::new()

function Write-TestLog {
    param([string]$msg)
    $allOutput.Add($msg)
    Write-Host $msg
}

function Setup-TestDir {
    param([string]$TestName)
    $dir = Join-Path $testRoot $TestName
    if (Test-Path $dir) { Remove-Item $dir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $monitorDir = Join-Path $dir '.monitor'
    New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null
    $backupDir = Join-Path $monitorDir 'backups'
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    Copy-Item (Join-Path $commonDir "fixture.md") (Join-Path $dir 'GitHub更新监测列表.md') -Force
    return $dir
}

function Save-TestOutput {
    param([string]$TestName, [string[]]$Output)
    $dir = Join-Path $testRoot $TestName
    $Output | Out-File -FilePath (Join-Path $dir 'stdout.txt') -Encoding utf8
}

function Add-TestResult {
    param([string]$TestId, [string]$Description, [string]$Verdict, [string[]]$Evidence)
    $testResults.Add([PSCustomObject]@{
        TestId = $TestId; Description = $Description; Verdict = $Verdict; Evidence = ($Evidence -join "`n")
    })
    Write-TestLog "  [$TestId] VERDICT: $Verdict"
}

# ============================================================================
# T30 - Concurrency: Two processes try to create the lock simultaneously
# ============================================================================
Write-TestLog ""
Write-TestLog "========== T30 - Concurrency =========="
Write-TestLog "Start two real PowerShell 7 processes. Both try to create the lock file."
Write-TestLog "Expected: one owner (BACKUP_OK), one LOCKED. No double commit, no mutual lock deletion."

$t30Dir = Setup-TestDir "T30"
$env:GITHUB_VERSION_MONITOR_BASE = $t30Dir

# Start two processes simultaneously
$out1 = Join-Path $t30Dir "proc1.txt"
$out2 = Join-Path $t30Dir "proc2.txt"
$err1 = Join-Path $t30Dir "proc1_err.txt"
$err2 = Join-Path $t30Dir "proc2_err.txt"

$step1Path = Join-Path $commonDir "step1.ps1"
$p1 = Start-Process pwsh -ArgumentList "-NoProfile", "-File", $step1Path -RedirectStandardOutput $out1 -RedirectStandardError $err1 -NoNewWindow -PassThru
$p2 = Start-Process pwsh -ArgumentList "-NoProfile", "-File", $step1Path -RedirectStandardOutput $out2 -RedirectStandardError $err2 -NoNewWindow -PassThru

Wait-Process -Id $p1.Id, $p2.Id -Timeout 30

$proc1Out = if (Test-Path $out1) { Get-Content $out1 -Raw } else { '' }
$proc2Out = if (Test-Path $out2) { Get-Content $out2 -Raw } else { ''
}
$proc1Out = $proc1Out.Trim()
$proc2Out = $proc2Out.Trim()

Write-TestLog "  Process 1 output: $proc1Out"
Write-TestLog "  Process 2 output: $proc2Out"

$hasBackup1 = $proc1Out -match 'BACKUP_OK'
$hasLocked1 = $proc1Out -match 'LOCKED\|'
$hasBackup2 = $proc2Out -match 'BACKUP_OK'
$hasLocked2 = $proc2Out -match 'LOCKED\|'

# Exactly one BACKUP_OK and one LOCKED
$exactlyOneBackup = ($hasBackup1 -xor $hasBackup2)
$exactlyOneLocked = ($hasLocked1 -xor $hasLocked2)
$noDoubleBackup = -not ($hasBackup1 -and $hasBackup2)

# Check lock file exists (should be one lock, owned by the winner)
$lockExists = Test-Path (Join-Path $t30Dir '.monitor\run.lock')

# Check backups (should be exactly one)
$backups = Get-ChildItem (Join-Path $t30Dir '.monitor\backups') -Filter '*.md' -ErrorAction SilentlyContinue
$backupCount = if ($backups) { @($backups).Count } else { 0 }

$t30Pass = $exactlyOneBackup -and $exactlyOneLocked -and $noDoubleBackup -and ($backupCount -eq 1)

$t30Evidence = @(
    "Process 1: $proc1Out",
    "Process 2: $proc2Out",
    "Exactly one BACKUP_OK: $exactlyOneBackup",
    "Exactly one LOCKED: $exactlyOneLocked",
    "No double BACKUP_OK: $noDoubleBackup",
    "Backup count: $backupCount (expected 1)",
    "Lock file exists: $lockExists"
)
Save-TestOutput "T30" @($proc1Out, "", $proc2Out, "", ($t30Evidence -join "`n"))
Add-TestResult "T30" "Concurrency: one BACKUP_OK, one LOCKED, no double commit" $(if($t30Pass){'PASS'}else{'FAIL'}) $t30Evidence

# Clean up lock for next tests
Remove-Item (Join-Path $t30Dir '.monitor\run.lock') -Force -ErrorAction SilentlyContinue

# ============================================================================
# T31 - Heartbeat: verify lock file fields and step changes
# ============================================================================
Write-TestLog ""
Write-TestLog "========== T31 - Heartbeat =========="
Write-TestLog "Verify the lock file contains: pid, start, step, beat and that step changes."

$t31Dir = Setup-TestDir "T31"
$env:GITHUB_VERSION_MONITOR_BASE = $t31Dir

$t31Script = Join-Path $testRoot "t31-heartbeat.ps1"
$t31Output = & pwsh -NoProfile -File $t31Script 2>&1
$t31Output | ForEach-Object { Write-TestLog "  $_" }

$t31Overall = ($t31Output | Where-Object { $_ -match 'OVERALL=PASS' }).Count -gt 0
Save-TestOutput "T31" $t31Output
Add-TestResult "T31" "Heartbeat: lock fields (pid/start/step/beat) present and step changes 1->2->3->4" $(if($t31Overall){'PASS'}else{'FAIL'}) @($t31Output -join "`n")

# ============================================================================
# T32 - Fresh/live lock: Live PID + fresh heartbeat -> LOCKED
# ============================================================================
Write-TestLog ""
Write-TestLog "========== T32 - Fresh/live lock =========="
Write-TestLog "Live PID + fresh heartbeat -> LOCKED (no takeover)."

$t32Dir = Setup-TestDir "T32"
$env:GITHUB_VERSION_MONITOR_BASE = $t32Dir

# Create a lock file with current process PID and current timestamp
$t32LockPath = Join-Path $t32Dir '.monitor\run.lock'
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
Set-Content -Path $t32LockPath -Value ("pid={0};start={1};step=1;beat={2}" -f $PID, $nowUtc, $nowUtc)
Write-TestLog "  Pre-created lock: pid=$PID, fresh heartbeat"

# Try to run Step 1 (which will try to create the lock with CreateNew)
$t32Output = & pwsh -NoProfile -File $step1Path 2>&1
$t32Output = $t32Output.Trim()
Write-TestLog "  Step 1 output: $t32Output"

$t32Locked = $t32Output -match 'LOCKED\|'
$t32NoTakeover = -not ($t32Output -match 'BACKUP_OK')

# Verify lock still has our PID (not taken over)
$lockAfter = Get-Content $t32LockPath -Raw
$lockPidMatches = $lockAfter -match "pid=$PID;"

$t32Pass = $t32Locked -and $t32NoTakeover -and $lockPidMatches

$t32Evidence = @(
    "Pre-created lock with live PID=$PID and fresh heartbeat",
    "Step 1 output: $t32Output",
    "Got LOCKED: $t32Locked",
    "No takeover (no BACKUP_OK): $t32NoTakeover",
    "Lock PID still matches: $lockPidMatches",
    "Lock content after: $lockAfter"
)
Save-TestOutput "T32" @($t32Output, "", ($t32Evidence -join "`n"))
Add-TestResult "T32" "Fresh/live lock: live PID + fresh heartbeat -> LOCKED" $(if($t32Pass){'PASS'}else{'FAIL'}) $t32Evidence

# Clean up
Remove-Item $t32LockPath -Force -ErrorAction SilentlyContinue

# ============================================================================
# T33 - Stale + alive: Heartbeat > 30 min, PID alive -> LOCKED (no takeover)
# ============================================================================
Write-TestLog ""
Write-TestLog "========== T33 - Stale + alive =========="
Write-TestLog "Heartbeat > 30 minutes, PID alive -> LOCKED (no takeover)."

$t33Dir = Setup-TestDir "T33"
$env:GITHUB_VERSION_MONITOR_BASE = $t33Dir

# Create a lock file with current process PID
$t33LockPath = Join-Path $t33Dir '.monitor\run.lock'
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
Set-Content -Path $t33LockPath -Value ("pid={0};start={1};step=1;beat={2}" -f $PID, $nowUtc, $nowUtc)

# Set LastWriteTime to 31 minutes ago (make it stale)
$staleTime = (Get-Date).AddMinutes(-31)
(Get-Item $t33LockPath).LastWriteTime = $staleTime
Write-TestLog "  Pre-created lock: pid=$PID (alive), LastWriteTime set to 31 min ago"

# Try to run Step 1
$t33Output = & pwsh -NoProfile -File $step1Path 2>&1
$t33Output = $t33Output.Trim()
Write-TestLog "  Step 1 output: $t33Output"

$t33Locked = $t33Output -match 'LOCKED\|'
$t33NoTakeover = -not ($t33Output -match 'BACKUP_OK')

# Verify lock still has our PID (not taken over)
$lockAfter33 = Get-Content $t33LockPath -Raw
$lockPidMatches33 = $lockAfter33 -match "pid=$PID;"

$t33Pass = $t33Locked -and $t33NoTakeover -and $lockPidMatches33

$t33Evidence = @(
    "Pre-created lock with live PID=$PID, LastWriteTime=31min ago",
    "Step 1 output: $t33Output",
    "Got LOCKED: $t33Locked",
    "No takeover: $t33NoTakeover",
    "Lock PID still matches: $lockPidMatches33",
    "Lock content after: $lockAfter33"
)
Save-TestOutput "T33" @($t33Output, "", ($t33Evidence -join "`n"))
Add-TestResult "T33" "Stale + alive: heartbeat >30min, PID alive -> LOCKED" $(if($t33Pass){'PASS'}else{'FAIL'}) $t33Evidence

# Clean up
Remove-Item $t33LockPath -Force -ErrorAction SilentlyContinue

# ============================================================================
# T34 - Stale + dead: Heartbeat > 30 min, PID dead -> takeover allowed
# ============================================================================
Write-TestLog ""
Write-TestLog "========== T34 - Stale + dead =========="
Write-TestLog "Heartbeat > 30 minutes, PID dead -> takeover allowed (BACKUP_OK)."

$t34Dir = Setup-TestDir "T34"
$env:GITHUB_VERSION_MONITOR_BASE = $t34Dir

# Create a lock file with a dead PID (999999)
$t34LockPath = Join-Path $t34Dir '.monitor\run.lock'
$deadPid = 999999
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
Set-Content -Path $t34LockPath -Value ("pid={0};start={1};step=1;beat={2}" -f $deadPid, $nowUtc, $nowUtc)

# Set LastWriteTime to 31 minutes ago (make it stale)
$staleTime = (Get-Date).AddMinutes(-31)
(Get-Item $t34LockPath).LastWriteTime = $staleTime
Write-TestLog "  Pre-created lock: pid=$deadPid (dead), LastWriteTime set to 31 min ago"

# Verify the dead PID is actually dead
$deadPidCheck = Get-Process -Id $deadPid -ErrorAction SilentlyContinue
Write-TestLog "  PID $deadPid alive check: $(if($deadPidCheck){'ALIVE (unexpected)'}else{'DEAD (correct)'})"

# Try to run Step 1 - should takeover
$t34Output = & pwsh -NoProfile -File $step1Path 2>&1
$t34Output = $t34Output.Trim()
Write-TestLog "  Step 1 output: $t34Output"

$t34BackupOk = $t34Output -match 'BACKUP_OK'
$t34NotLocked = -not ($t34Output -match 'LOCKED\|')

# Verify lock was taken over (new PID in lock)
$lockAfter34 = Get-Content $t34LockPath -Raw
$lockHasNewPid = -not ($lockAfter34 -match "pid=$deadPid;")

$t34Pass = $t34BackupOk -and $t34NotLocked -and $lockHasNewPid

$t34Evidence = @(
    "Pre-created lock with dead PID=$deadPid, LastWriteTime=31min ago",
    "PID $deadPid is dead: $(if($deadPidCheck){'NO'}else{'YES'})",
    "Step 1 output: $t34Output",
    "Got BACKUP_OK (takeover): $t34BackupOk",
    "Not LOCKED: $t34NotLocked",
    "Lock has new PID (takeover happened): $lockHasNewPid",
    "Lock content after: $lockAfter34"
)
Save-TestOutput "T34" @($t34Output, "", ($t34Evidence -join "`n"))
Add-TestResult "T34" "Stale + dead: heartbeat >30min, PID dead -> takeover" $(if($t34Pass){'PASS'}else{'FAIL'}) $t34Evidence

# Clean up
Remove-Item $t34LockPath -Force -ErrorAction SilentlyContinue

# ============================================================================
# T35 - Ownership mismatch: Foreign PID in lock -> RUNTIME_ERROR
# ============================================================================
Write-TestLog ""
Write-TestLog "========== T35 - Ownership mismatch =========="
Write-TestLog "Foreign PID in lock -> RUNTIME_ERROR, foreign lock retained."

$t35Dir = Setup-TestDir "T35"
$env:GITHUB_VERSION_MONITOR_BASE = $t35Dir

# Copy result.json (needed by Step 5)
Copy-Item (Join-Path $commonDir "result.json") (Join-Path $t35Dir '.monitor\result.json') -Force

# Create a lock file with a foreign PID (999998 - non-existent)
$t35LockPath = Join-Path $t35Dir '.monitor\run.lock'
$foreignPid = 999998
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
Set-Content -Path $t35LockPath -Value ("pid={0};start={1};step=4;beat={2}" -f $foreignPid, $nowUtc, $nowUtc)
Write-TestLog "  Pre-created lock: pid=$foreignPid (foreign/dead), step=4"

# Verify foreign PID is dead
$foreignPidCheck = Get-Process -Id $foreignPid -ErrorAction SilentlyContinue
Write-TestLog "  PID $foreignPid alive check: $(if($foreignPidCheck){'ALIVE'}else{'DEAD'})"

# Run Step 5 (which checks ownership before releasing)
$step5Path = Join-Path $commonDir "step5.ps1"
$t35Output = & pwsh -NoProfile -File $step5Path 2>&1
$t35Output = $t35Output.Trim()
Write-TestLog "  Step 5 output: $t35Output"

$t35HasRuntimeError = $t35Output -match 'RUNTIME_ERROR\|.*ownership'
$t35HasRunStatusFailed = $t35Output -match 'RUN_STATUS\|failed'

# Verify lock file still exists (not deleted)
$lockStillExists = Test-Path $t35LockPath

# Verify lock content still has foreign PID (not changed)
$lockAfter35 = Get-Content $t35LockPath -Raw
$lockStillForeign = $lockAfter35 -match "pid=$foreignPid;"

$t35Pass = $t35HasRuntimeError -and $lockStillExists -and $lockStillForeign

$t35Evidence = @(
    "Pre-created lock with foreign PID=$foreignPid, step=4",
    "PID $foreignPid is dead: $(if($foreignPidCheck){'NO'}else{'YES'})",
    "Step 5 output: $t35Output",
    "Has RUNTIME_ERROR (ownership): $t35HasRuntimeError",
    "Has RUN_STATUS|failed: $t35HasRunStatusFailed",
    "Lock file still exists: $lockStillExists",
    "Lock still has foreign PID: $lockStillForeign",
    "Lock content after: $lockAfter35"
)
Save-TestOutput "T35" @($t35Output, "", ($t35Evidence -join "`n"))
Add-TestResult "T35" "Ownership mismatch: foreign PID -> RUNTIME_ERROR, lock retained" $(if($t35Pass){'PASS'}else{'FAIL'}) $t35Evidence

# Clean up
Remove-Item $t35LockPath -Force -ErrorAction SilentlyContinue

# ============================================================================
# T36 - Process kill: kill at step, verify lock/backup/result handling
# ============================================================================
Write-TestLog ""
Write-TestLog "========== T36 - Process kill =========="
Write-TestLog "Kill process during execution, verify lock/backup handling, then re-run."

$t36Dir = Setup-TestDir "T36"
$env:GITHUB_VERSION_MONITOR_BASE = $t36Dir

# Step 1: Start a process running step1-and-hold.ps1 (creates lock, then sleeps)
$holdScript = Join-Path $commonDir "step1-and-hold.ps1"
$t36Out = Join-Path $t36Dir "hold_out.txt"
$t36Err = Join-Path $t36Dir "hold_err.txt"

$proc = Start-Process pwsh -ArgumentList "-NoProfile", "-File", $holdScript -RedirectStandardOutput $t36Out -RedirectStandardError $t36Err -NoNewWindow -PassThru
Write-TestLog "  Started process PID=$($proc.Id) running step1-and-hold.ps1"

# Wait for lock to be created (poll for up to 5 seconds)
$t36LockPath = Join-Path $t36Dir '.monitor\run.lock'
$lockCreated = $false
for ($i = 0; $i -lt 50; $i++) {
    Start-Sleep -Milliseconds 100
    if (Test-Path $t36LockPath) { $lockCreated = $true; break }
}
Write-TestLog "  Lock created: $lockCreated (after $($i*100)ms)"

if ($lockCreated) {
    # Give it a moment more, then kill the process
    Start-Sleep -Milliseconds 500
    $procPid = $proc.Id
    Stop-Process -Id $procPid -Force -ErrorAction SilentlyContinue
    Write-TestLog "  Killed process PID=$procPid"

    # Wait a moment for process to die
    Start-Sleep -Milliseconds 500
    $procAlive = Get-Process -Id $procPid -ErrorAction SilentlyContinue
    Write-TestLog "  Process alive after kill: $(if($procAlive){'YES (unexpected)'}else{'NO (correct)'})"
}

# Verify: lock exists, backup exists, main md unchanged
$lockExists36 = Test-Path $t36LockPath
$backups36 = Get-ChildItem (Join-Path $t36Dir '.monitor\backups') -Filter '*.md' -ErrorAction SilentlyContinue
$backupExists36 = if ($backups36) { @($backups36).Count -gt 0 } else { $false }
$mdContent36 = Get-Content (Join-Path $t36Dir 'GitHub更新监测列表.md') -Raw
$mdUnchanged = $mdContent36 -match '## 监测列表' -and $mdContent36 -match '## 结论'

Write-TestLog "  Lock exists: $lockExists36"
Write-TestLog "  Backup exists: $backupExists36"
Write-TestLog "  Main md unchanged: $mdUnchanged"

# Read the lock content to get the dead PID
$lockContent36 = if ($lockExists36) { Get-Content $t36LockPath -Raw } else { '' }
$killedPid = if ($lockContent36 -match 'pid=(\d+)') { $Matches[1] } else { 'unknown' }
Write-TestLog "  Lock content: $lockContent36 (dead PID: $killedPid)"

# Step 2: Try to run Step 1 again - should get LOCKED (PID dead, but heartbeat fresh < 30 min)
Write-TestLog "  --- Re-running Step 1 with fresh heartbeat (expect LOCKED) ---"
$t36ReOutput = & pwsh -NoProfile -File $step1Path 2>&1
$t36ReOutput = $t36ReOutput.Trim()
Write-TestLog "  Re-run output: $t36ReOutput"

$t36GotLocked = $t36ReOutput -match 'LOCKED\|'
$t36NoTakeoverFresh = -not ($t36ReOutput -match 'BACKUP_OK')

# Verify lock still has the dead PID (not taken over)
$lockAfterRe36 = Get-Content $t36LockPath -Raw
$lockStillDeadPid = $lockAfterRe36 -match "pid=$killedPid;"

# Step 3: Set heartbeat to > 30 min ago, then try again - should get BACKUP_OK (takeover)
Write-TestLog "  --- Setting LastWriteTime to 31 min ago, re-running Step 1 (expect BACKUP_OK/takeover) ---"
$staleTime36 = (Get-Date).AddMinutes(-31)
(Get-Item $t36LockPath).LastWriteTime = $staleTime36

$t36ReOutput2 = & pwsh -NoProfile -File $step1Path 2>&1
$t36ReOutput2 = $t36ReOutput2.Trim()
Write-TestLog "  Re-run after stale output: $t36ReOutput2"

$t36GotBackupOk = $t36ReOutput2 -match 'BACKUP_OK'
$t36TakeoverHappened = $t36GotBackupOk

# Verify lock has new PID (takeover happened)
$lockAfterRe236 = Get-Content $t36LockPath -Raw
$lockHasNewPid36 = -not ($lockAfterRe236 -match "pid=$killedPid;")

$t36Pass = $lockCreated -and $lockExists36 -and $backupExists36 -and $mdUnchanged -and $t36GotLocked -and $t36NoTakeoverFresh -and $t36GotBackupOk -and $lockHasNewPid36

$t36Evidence = @(
    "Killed process PID: $killedPid",
    "Lock exists after kill: $lockExists36",
    "Backup exists after kill: $backupExists36",
    "Main md unchanged: $mdUnchanged",
    "Re-run with fresh heartbeat got LOCKED: $t36GotLocked",
    "No takeover with fresh heartbeat: $t36NoTakeoverFresh",
    "Lock still has dead PID after fresh re-run: $lockStillDeadPid",
    "Re-run after stale got BACKUP_OK: $t36GotBackupOk",
    "Lock has new PID after stale re-run (takeover): $lockHasNewPid36",
    "Hold output: $(if(Test-Path $t36Out){Get-Content $t36Out -Raw}else{'N/A'})"
)
Save-TestOutput "T36" @($t36ReOutput, "", $t36ReOutput2, "", ($t36Evidence -join "`n"))
Add-TestResult "T36" "Process kill: lock left behind, fresh=LOCKED, stale+dead=takeover" $(if($t36Pass){'PASS'}else{'FAIL'}) $t36Evidence

# Clean up
Remove-Item $t36LockPath -Force -ErrorAction SilentlyContinue

# ============================================================================
# Generate combined report
# ============================================================================
Write-TestLog ""
Write-TestLog "========== FINAL SUMMARY =========="
$passCount = ($testResults | Where-Object { $_.Verdict -eq 'PASS' }).Count
$failCount = ($testResults | Where-Object { $_.Verdict -eq 'FAIL' }).Count
Write-TestLog "Total: $($testResults.Count) | PASS: $passCount | FAIL: $failCount"
foreach ($r in $testResults) {
    Write-TestLog "  [$($r.Verdict)] $($r.TestId): $($r.Description)"
}

# Save combined stdout
$allOutput | Out-File -FilePath (Join-Path $testRoot "stdout.txt") -Encoding utf8

# Generate combined test-report.md
$report = [System.Text.StringBuilder]::new()
[void]$report.AppendLine("# Production Validation v1.7 Final - Test Report (T30-T36)")
[void]$report.AppendLine("")
[void]$report.AppendLine("**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
[void]$report.AppendLine("**Focus:** Concurrency and lock mechanism")
[void]$report.AppendLine("")
[void]$report.AppendLine("## Summary")
[void]$report.AppendLine("")
[void]$report.AppendLine("| Metric | Value |")
[void]$report.AppendLine("|--------|-------|")
[void]$report.AppendLine("| Total Tests | $($testResults.Count) |")
[void]$report.AppendLine("| PASS | $passCount |")
[void]$report.AppendLine("| FAIL | $failCount |")
[void]$report.AppendLine("| Overall | $(if($failCount -eq 0){'ALL PASS'}else{'HAS FAILURES'}) |")
[void]$report.AppendLine("")
[void]$report.AppendLine("## Test Details")
[void]$report.AppendLine("")

foreach ($r in $testResults) {
    [void]$report.AppendLine("### $($r.TestId)")
    [void]$report.AppendLine("")
    [void]$report.AppendLine("| Field | Value |")
    [void]$report.AppendLine("|-------|-------|")
    [void]$report.AppendLine("| Test ID | $($r.TestId) |")
    [void]$report.AppendLine("| Description | $($r.Description) |")
    [void]$report.AppendLine("| Verdict | **$($r.Verdict)** |")
    [void]$report.AppendLine("")
    [void]$report.AppendLine("#### Evidence")
    [void]$report.AppendLine("")
    [void]$report.AppendLine('```')
    [void]$report.AppendLine($r.Evidence)
    [void]$report.AppendLine('```')
    [void]$report.AppendLine("")
}

[void]$report.AppendLine("## Tests Overview")
[void]$report.AppendLine("")
[void]$report.AppendLine("| Test | Description | Verdict |")
[void]$report.AppendLine("|------|-------------|---------|")
foreach ($r in $testResults) {
    [void]$report.AppendLine("| $($r.TestId) | $($r.Description) | **$($r.Verdict)** |")
}
[void]$report.AppendLine("")

Set-Content -Path (Join-Path $testRoot "test-report.md") -Value $report.ToString() -Encoding UTF8

Write-TestLog ""
Write-TestLog "Report saved to: $(Join-Path $testRoot 'test-report.md')"
Write-TestLog "Combined output saved to: $(Join-Path $testRoot 'stdout.txt')"

if ($failCount -eq 0) {
    Write-TestLog ""
    Write-TestLog "ALL TESTS PASSED"
} else {
    Write-TestLog ""
    Write-TestLog "SOME TESTS FAILED - see report above"
}
