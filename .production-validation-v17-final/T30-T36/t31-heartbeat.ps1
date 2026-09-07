#Requires -Version 7.0
<#
    T31 - Heartbeat test: verify lock file fields and step changes
    Runs all step heartbeats in a single process (same PID)
#>
$ErrorActionPreference = 'Stop'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$md = Join-Path $base 'GitHub更新监测列表.md'
$monitorDir = Join-Path $base '.monitor'
$lockPath = Join-Path $monitorDir 'run.lock'
$results = [System.Collections.Generic.List[string]]::new()

function Verify-Lock {
    param([string]$ExpectedStep, [string]$StepName)
    if (-not (Test-Path $lockPath)) {
        $results.Add("  [$StepName] FAIL: lock file does not exist")
        return $false
    }
    $raw = Get-Content $lockPath -Raw
    $hasPid = [bool]($raw -match 'pid=(\d+)'); $pidVal = if ($hasPid) { $Matches[1] } else { 'MISSING' }
    $hasStart = [bool]($raw -match 'start=([^;\r\n]+)')
    $hasBeat = [bool]($raw -match 'beat=([^;\r\n]+)')
    $hasStep = [bool]($raw -match 'step=(\d+)'); $stepVal = if ($hasStep) { $Matches[1] } else { 'MISSING' }

    $allPresent = $hasPid -and $hasStart -and $hasBeat -and $hasStep
    $stepOk = ($stepVal -eq $ExpectedStep)
    $pidOk = ($pidVal -eq [string]$PID)

    $status = if ($allPresent -and $stepOk -and $pidOk) { 'PASS' } else { 'FAIL' }
    $results.Add(("  [{0}] {1} | pid={2} step={3} (expected step={4}) allFields={5} pidMatch={6} stepMatch={7}" -f $StepName, $status, $pidVal, $stepVal, $ExpectedStep, $allPresent, $pidOk, $stepOk))
    $results.Add("    raw=$raw")
    return ($status -eq 'PASS')
}

# === Step 1: Create lock + backup ===
$results.Add("=== T31 Step 1: Create lock ===")
if (-not (Test-Path $md)) { $results.Add('  FAIL: state file missing'); return $results }
New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null

# Lock creation (exact code from SKILL Step 1)
function New-LockOnce {
    $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
    $fs.Close()
    $nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
    Set-Content -Path $lockPath -Value ("pid={0};start={1};step=1;beat={2}" -f $PID, $nowUtc, $nowUtc)
}
$lockAcquired = $false
try { New-LockOnce; $lockAcquired = $true } catch [System.IO.IOException] { $lockAcquired = $false }
if (-not $lockAcquired) { $results.Add('  FAIL: could not acquire lock'); return $results }

# Backup
$backupDir = Join-Path $monitorDir 'backups'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$ts = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyyMMdd-HHmmssfff')
Copy-Item $md (Join-Path $backupDir "GitHub更新监测列表.backup.$ts.md")
$results.Add("  BACKUP_OK|$ts")

# Verify Step 1 lock
$step1Ok = Verify-Lock -ExpectedStep '1' -StepName 'Step1'
Start-Sleep -Milliseconds 100  # ensure beat timestamp differs

# === Step 2: Heartbeat refresh (step=2) ===
$results.Add("=== T31 Step 2: Heartbeat refresh ===")
$prev = Get-Content $lockPath -Raw
$startTok = if ($prev -match 'start=([^;\r\n]+)') { $Matches[1] } else { [DateTimeOffset]::UtcNow.ToString('o') }
$fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
$fs.SetLength(0)
$bytes = [System.Text.Encoding]::UTF8.GetBytes(("pid={0};start={1};step=2;beat={2}" -f $PID, $startTok, [DateTimeOffset]::UtcNow.ToString('o')))
$fs.Write($bytes, 0, $bytes.Length)
$fs.Close()
$step2Ok = Verify-Lock -ExpectedStep '2' -StepName 'Step2'
Start-Sleep -Milliseconds 100

# === Step 3: Heartbeat refresh with ownership check (step=3) ===
$results.Add("=== T31 Step 3: Heartbeat refresh with ownership check ===")
$raw = Get-Content $lockPath -Raw -ErrorAction Stop
if ($raw -notmatch ('pid=' + [regex]::Escape([string]$PID) + ';')) { throw 'ownership mismatch' }
$startTok = if ($raw -match 'start=([^;\r\n]+)') { $Matches[1] } else { [DateTimeOffset]::UtcNow.ToString('o') }
$fs = [System.IO.File]::Open($lockPath,[System.IO.FileMode]::Open,[System.IO.FileAccess]::ReadWrite,[System.IO.FileShare]::None)
try { $fs.SetLength(0);$b=[Text.Encoding]::UTF8.GetBytes(('pid={0};start={1};step=3;beat={2}'-f $PID,$startTok,[DateTimeOffset]::UtcNow.ToString('o')));$fs.Write($b,0,$b.Length) } finally { $fs.Close() }
$step3Ok = Verify-Lock -ExpectedStep '3' -StepName 'Step3'
Start-Sleep -Milliseconds 100

# === Step 4: Heartbeat refresh with ownership check (step=4) ===
$results.Add("=== T31 Step 4: Heartbeat refresh with ownership check ===")
$raw=Get-Content $lockPath -Raw -ErrorAction Stop
if($raw-notmatch('pid='+[regex]::Escape([string]$PID)+';')){throw 'ownership mismatch'}
$startTok=if($raw-match 'start=([^;\r\n]+)'){$Matches[1]}else{[DateTimeOffset]::UtcNow.ToString('o')}
$fs=[IO.File]::Open($lockPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try{$fs.SetLength(0);$b=[Text.Encoding]::UTF8.GetBytes(('pid={0};start={1};step=4;beat={2}'-f $PID,$startTok,[DateTimeOffset]::UtcNow.ToString('o')));$fs.Write($b,0,$b.Length)}finally{$fs.Close()}
$step4Ok = Verify-Lock -ExpectedStep '4' -StepName 'Step4'
Start-Sleep -Milliseconds 100

# === Step 5: Heartbeat (LastWriteTime only, no step rewrite) + release ===
$results.Add("=== T31 Step 5: Heartbeat + release ===")
# Step 5 does NOT rewrite step in content - only updates LastWriteTime
$fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
$fs.Close()
(Get-Item $lockPath).LastWriteTime = Get-Date

# Read lock before release - step should still be 4 (Step 5 doesn't update step field)
$step5PreRelease = Verify-Lock -ExpectedStep '4' -StepName 'Step5-pre-release'

# Release lock (ownership check)
$lockReleased = $false
try {
    $lockRaw = Get-Content $lockPath -Raw -ErrorAction Stop
    $lockPid = if ($lockRaw -match 'pid=(\d+)') { [int]$Matches[1] } else { -1 }
    if ($lockPid -eq $PID) {
        Remove-Item $lockPath -Force -ErrorAction SilentlyContinue
        $lockReleased = $true
    }
} catch { $lockReleased = $false }

if ($lockReleased) {
    $results.Add("  [Step5-release] PASS: lock released (deleted)")
} else {
    $results.Add("  [Step5-release] FAIL: lock not released")
}

# Verify lock is gone
$lockGone = -not (Test-Path $lockPath)
if ($lockGone) {
    $results.Add("  [Step5-verify] PASS: lock file deleted after release")
} else {
    $results.Add("  [Step5-verify] FAIL: lock file still exists after release")
}

# Summary
$results.Add("")
$results.Add("=== T31 SUMMARY ===")
$allPass = $step1Ok -and $step2Ok -and $step3Ok -and $step4Ok -and $step5PreRelease -and $lockReleased -and $lockGone
$results.Add("Step1=$step1Ok Step2=$step2Ok Step3=$step3Ok Step4=$step4Ok Step5PreRelease=$step5PreRelease LockReleased=$lockReleased LockGone=$lockGone")
$results.Add("OVERALL=$($allPass ? 'PASS' : 'FAIL')")

# Output all results
$results | ForEach-Object { Write-Output $_ }
