# T38 runner: review write-back failure test
# Steps:
# 1. Create fixture
# 2. Run step1 + step2 (get result.json)
# 3. Create .monitor/result.review.tmp as read-only (block step4 from writing)
# 4. Run step4 (will fail on Set-Content)
# 5. Capture output, verify md unchanged, lock released, no COMMIT_OK

$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T38'
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

# Run step1 + step2 to get result.json (with lock acquired)
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

if ($script:shouldStop) {
    $script:allOutput.Add("PIPELINE_STOPPED_EARLY|$script:stopReason")
    $script:allOutput | Out-File -FilePath (Join-Path $base 'stdout.txt') -Encoding UTF8
    Write-Host "PIPELINE_STOPPED|$script:stopReason"
    return
}

# Save lock-before (after step2, lock should be held by current PID)
$lockPath = Join-Path $base '.monitor\run.lock'
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-before.txt')
    Set-Content -Path (Join-Path $base 'lock-before-status.txt') -Value 'LOCK_PRESENT'
} else {
    Set-Content -Path (Join-Path $base 'lock-before-status.txt') -Value 'LOCK_MISSING'
}

# Save result-before.json
if (Test-Path (Join-Path $base '.monitor\result.json')) {
    Copy-Item (Join-Path $base '.monitor\result.json') (Join-Path $base 'result-before.json')
}

# Create .monitor/result.review.tmp as read-only (block step4 from writing)
$monitorDir = Join-Path $base '.monitor'
$tmpPath = Join-Path $monitorDir 'result.review.tmp'
if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force }
Set-Content -Path $tmpPath -Value 'BLOCKED' -Encoding UTF8
Set-ItemProperty -Path $tmpPath -Name IsReadOnly -Value $true

# Verify tmp is read-only
$tmpAttr = Get-Item $tmpPath
Write-Host "TMP_READONLY=$($tmpAttr.IsReadOnly)"

# Run step4 (will fail on Set-Content because tmp is read-only)
# step4.ps1 has $ErrorActionPreference='Stop' and no try/catch around Set-Content
# So the exception will propagate up
$step4Output = @()
$step4Exception = $null
try {
    $out = & (Join-Path $lib 'step4.ps1') 2>&1
    $step4Output = $out
} catch {
    $step4Exception = $_
}

$script:allOutput.Add("===== EXECUTING step4 (with blocked tmp) =====")
if ($step4Exception) {
    $script:allOutput.Add("STEP4_EXCEPTION: $step4Exception")
} else {
    $combined = $step4Output | Out-String -Width 4096
    $script:allOutput.Add($combined)
}
$script:allOutput.Add("===== END step4 =====")

# Save after state
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash (Join-Path $base 'md-after.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

# Check lock status
if (Test-Path $lockPath) {
    Get-Content $lockPath -Raw | Set-Content -Path (Join-Path $base 'lock-after.txt')
    Set-Content -Path (Join-Path $base 'lock-released.txt') -Value 'NO_LOCK_STILL_PRESENT'
} else {
    Set-Content -Path (Join-Path $base 'lock-released.txt') -Value 'YES_LOCK_RELEASED'
}

# Save result-after.json (if it exists)
if (Test-Path (Join-Path $base '.monitor\result.json')) {
    Copy-Item (Join-Path $base '.monitor\result.json') (Join-Path $base 'result-after.json')
}

# Save outputs
$script:allOutput | Out-File -FilePath (Join-Path $base 'stdout.txt') -Encoding UTF8
@() | Out-File -FilePath (Join-Path $base 'stderr.txt') -Encoding UTF8

# Summary
Write-Host "T38_DONE|sha_before=$shaBefore|sha_after=$shaAfter|lock=$(Get-Content (Join-Path $base 'lock-released.txt'))"
Write-Host "SHA_CHANGED=$($shaBefore -ne $shaAfter)"
Write-Host "STEP4_EXCEPTION=$($step4Exception -ne $null)"
