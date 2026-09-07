# T39 runner: commit succeeded + lock release failure
# Steps:
# 1. Create fixture
# 2. Run step1 + step2 + step3 + step4 (get result.json with review data)
# 3. Save lock-before.txt and result-before.json
# 4. Run step5-commit.ps1 (commit part only)
# 5. Verify COMMIT_OK
# 6. Modify lock file PID to mismatch value (pid=999999)
# 7. Save lock-after-modify.txt
# 8. Run step5-lockrelease-test.ps1 (wrapper for lock release part)
# 9. Verify RUNTIME_ERROR + RUN_STATUS|failed|, no RUN_STATUS|success|
# 10. Save lock-after.txt

$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T39'
$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean previous run
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.output\GitHub更新监测列表.md.tmp')) { Remove-Item (Join-Path $base '.output\GitHub更新监测列表.md.tmp') -Force -ErrorAction SilentlyContinue }
if (-not (Test-Path (Join-Path $base '.output'))) { New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null }

# Regenerate fixture (same as T37)
$rows = @(
    [PSCustomObject]@{Id=1;Name='VS Code';Owner='microsoft';Repo='vscode';GitVer='v1.0.0';GitDate='2026-01-01';LocalVer='1.0.0';Flag='no'},
    [PSCustomObject]@{Id=2;Name='Linux';Owner='torvalds';Repo='linux';GitVer='v6.5.0';GitDate='2026-01-01';LocalVer='6.5.0';Flag='no'}
)
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Rows $rows | Out-Null

# Save md-before
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-before.md')
$shaBefore = (Get-FileHash (Join-Path $base 'md-before.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

# Run step1 + step2 + step3 + step4
$script:allOutput = [System.Collections.Generic.List[string]]::new()
$script:shouldStop = $false
$script:stopReason = ''

function Invoke-Step([string]$Name, [string]$Script) {
    $script:allOutput.Add("===== EXECUTING $Name =====")
    try {
        $out = & (Join-Path $lib $Script) 2>&1
        $combined = $out | Out-String -Width 4096
        $script:allOutput.Add($combined)
        return $combined
    } catch {
        $script:allOutput.Add(("{0}_EXCEPTION: {1}" -f $Name.ToUpper(), $_))
        return ""
    }
    finally { $script:allOutput.Add("===== END $Name =====") }
}

$c1 = Invoke-Step 'step1' 'step1.ps1'
if ($c1 -match 'STATE_MISSING\|') { $script:shouldStop = $true; $script:stopReason = 'STATE_MISSING' }
elseif ($c1 -match 'LOCKED\|')    { $script:shouldStop = $true; $script:stopReason = 'LOCKED' }

if (-not $script:shouldStop) {
    $c2 = Invoke-Step 'step2' 'step2.ps1'
    if ($c2 -match 'PARSE_ERROR\|')   { $script:shouldStop = $true; $script:stopReason = 'PARSE_ERROR' }
    elseif ($c2 -match 'RUNTIME_ERROR\|') { $script:shouldStop = $true; $script:stopReason = 'RUNTIME_ERROR' }
    elseif ($c2 -match 'LOCKED\|')    { $script:shouldStop = $true; $script:stopReason = 'LOCKED' }
}

if (-not $script:shouldStop) {
    Invoke-Step 'step3' 'step3.ps1' | Out-Null
}

if (-not $script:shouldStop) {
    $c4 = Invoke-Step 'step4' 'step4.ps1'
    if ($c4 -match 'REVIEW_WRITE_ERROR\|') { $script:shouldStop = $true; $script:stopReason = 'REVIEW_WRITE_ERROR' }
    elseif ($c4 -match 'RUNTIME_ERROR\|')  { $script:shouldStop = $true; $script:stopReason = 'RUNTIME_ERROR' }
}

if ($script:shouldStop) {
    $script:allOutput.Add("PIPELINE_STOPPED_EARLY|$script:stopReason")
    $script:allOutput | Out-File -FilePath (Join-Path $base 'stdout.txt') -Encoding UTF8
    Write-Host "PIPELINE_STOPPED|$script:stopReason"
    return
}

# Save lock-before and result-before
$lockPath = Join-Path $base '.monitor\run.lock'
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-before.txt')
    Set-Content -Path (Join-Path $base 'lock-before-status.txt') -Value 'LOCK_PRESENT'
} else {
    Set-Content -Path (Join-Path $base 'lock-before-status.txt') -Value 'LOCK_MISSING'
}

if (Test-Path (Join-Path $base '.monitor\result.json')) {
    Copy-Item (Join-Path $base '.monitor\result.json') (Join-Path $base 'result-before.json')
}

# Run step5-commit.ps1 (commit part only, does NOT release lock)
$commitOutput = Invoke-Step 'step5-commit' 'step5-commit.ps1'
$commitOk = $commitOutput -match 'COMMIT_OK\|'
Write-Host "COMMIT_OK=$commitOk"

# Modify lock file PID to mismatch value (pid=999999)
if (Test-Path $lockPath) {
    $lockContent = Get-Content $lockPath -Raw
    $modifiedLock = $lockContent -replace 'pid=\d+', 'pid=999999'
    Set-Content -Path $lockPath -Value $modifiedLock -Encoding UTF8
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after-modify.txt')
    Write-Host "LOCK_MODIFIED|pid=999999"
} else {
    Write-Host "LOCK_MISSING_BEFORE_MODIFY"
}

# Run step5-lockrelease-test.ps1 (wrapper for lock release part)
# Note: wrapper is in $base, not $lib; call it directly
$script:allOutput.Add("===== EXECUTING step5-lockrelease-test =====")
try {
    $out = & (Join-Path $base 'step5-lockrelease-test.ps1') 2>&1
    $combined = $out | Out-String -Width 4096
    $script:allOutput.Add($combined)
} catch {
    $script:allOutput.Add(("STEP5-LOCKRELEASE-TEST_EXCEPTION: {0}" -f $_))
}
$script:allOutput.Add("===== END step5-lockrelease-test =====")

# Save after state
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash (Join-Path $base 'md-after.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

# Save final lock state
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after.txt')
    Set-Content -Path (Join-Path $base 'lock-released.txt') -Value 'NO_LOCK_STILL_PRESENT'
} else {
    Set-Content -Path (Join-Path $base 'lock-released.txt') -Value 'YES_LOCK_RELEASED'
}

# Save result-after.json
if (Test-Path (Join-Path $base '.monitor\result.json')) {
    Copy-Item (Join-Path $base '.monitor\result.json') (Join-Path $base 'result-after.json')
}

# Save outputs
$script:allOutput | Out-File -FilePath (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File -FilePath (Join-Path $base 'stderr.txt') -Encoding UTF8

# Verify assertions
$combinedOutput = $script:allOutput -join "`n"
$hasCommitOk = $combinedOutput -match 'COMMIT_OK\|'
$hasRuntimeError = $combinedOutput -match 'RUNTIME_ERROR\|'
$hasRunStatusFailed = $combinedOutput -match 'RUN_STATUS\|failed\|'
$hasRunStatusSuccess = $combinedOutput -match 'RUN_STATUS\|success\|'

Write-Host "--- ASSERTIONS ---"
Write-Host "HAS_COMMIT_OK=$hasCommitOk (expected: true)"
Write-Host "HAS_RUNTIME_ERROR=$hasRuntimeError (expected: true)"
Write-Host "HAS_RUN_STATUS_FAILED=$hasRunStatusFailed (expected: true)"
Write-Host "HAS_RUN_STATUS_SUCCESS=$hasRunStatusSuccess (expected: false)"
Write-Host "SHA_CHANGED=$($shaBefore -ne $shaAfter) (expected: true, commit succeeded)"
Write-Host "LOCK_RELEASED=$(Get-Content (Join-Path $base 'lock-released.txt')) (expected: NO_LOCK_STILL_PRESENT)"
