# T37 runner: runs full pipeline and captures all output to stdout.txt
# Uses a global list to avoid PowerShell function scope issues
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T37'
$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean previous run
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.output\GitHub更新监测列表.md.tmp')) { Remove-Item (Join-Path $base '.output\GitHub更新监测列表.md.tmp') -Force -ErrorAction SilentlyContinue }

# Regenerate fixture
$rows = @(
    [PSCustomObject]@{Id=1;Name='VS Code';Owner='microsoft';Repo='vscode';GitVer='v1.0.0';GitDate='2026-01-01';LocalVer='1.0.0';Flag='no'},
    [PSCustomObject]@{Id=2;Name='Linux';Owner='torvalds';Repo='linux';GitVer='v6.5.0';GitDate='2026-01-01';LocalVer='6.5.0';Flag='no'}
)
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Rows $rows | Out-Null

# Save md-before
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-before.md')
$shaBefore = (Get-FileHash (Join-Path $base 'md-before.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

# Run pipeline in-process (shared PID for lock ownership)
$outFile = Join-Path $base 'stdout.txt'
$errFile = Join-Path $base 'stderr.txt'
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

if (-not $script:shouldStop) {
    Invoke-Step 'step5-full' 'step5-full.ps1' | Out-Null
}

if ($script:shouldStop) {
    $script:allOutput.Add("PIPELINE_STOPPED_EARLY|$script:stopReason")
}

# Save outputs
$script:allOutput | Out-File -FilePath $outFile -Encoding UTF8
@() | Out-File -FilePath $errFile -Encoding UTF8

# Save after state
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash (Join-Path $base 'md-after.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

if (Test-Path (Join-Path $base '.monitor\result.json')) {
    Copy-Item (Join-Path $base '.monitor\result.json') (Join-Path $base 'result-after.json')
}
if (Test-Path (Join-Path $base '.monitor\run.lock')) {
    Get-Content (Join-Path $base '.monitor\run.lock') -Raw | Set-Content -Path (Join-Path $base 'lock-after.txt')
    Set-Content -Path (Join-Path $base 'lock-released.txt') -Value 'NO_LOCK_STILL_PRESENT'
} else {
    Set-Content -Path (Join-Path $base 'lock-released.txt') -Value 'YES_LOCK_RELEASED'
}

Write-Host "PIPELINE_DONE|stop=$script:shouldStop|reason=$script:stopReason|outputItems=$($script:allOutput.Count)"
