# T43-v18 runner: 6-scenario full pipeline regression (in-process, shared PID)
# Scenarios:
#   1. normal upgrade   (nodejs/node):     localVer=v26.6.0 vs latest=v26.8.1 -> flag=yes
#   2. synced           (kubernetes):      localVer=v1.37.0 == latest=v1.37.0 -> flag=no, cmp=eq
#   3. uninstalled      (grafana):         localVer=未安装                        -> flag=no
#   4. unsupported ver  (terraform):       localVer=N/A  -> cmp=incomparable, review=true, reviewReasons~incomparable_version
#   5. 404              (demonpiapia/nonexistent-repo-xyz): status=not_found, gitVer='', gitDate='', flag=prevFlag, review=true
#   6. versionJump      (microsoft/typescript): prevGitVer=v5.0.0 -> latest=v7.0.2 (major diff 2) -> isNew=true, versionJump=true, review=true
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T43'
$lib  = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean previous run (idempotent)
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.output\GitHub更新监测列表.md.tmp')) { Remove-Item (Join-Path $base '.output\GitHub更新监测列表.md.tmp') -Force -ErrorAction SilentlyContinue }

# Regenerate fixture
$rows = @(
    [PSCustomObject]@{Id=1;Name='Node.js';    Owner='nodejs';      Repo='node';      GitVer='v26.7.0'; GitDate='2026-07-15'; LocalVer='v26.6.0'; Flag='no'},
    [PSCustomObject]@{Id=2;Name='Kubernetes'; Owner='kubernetes';  Repo='kubernetes';GitVer='v1.37.0'; GitDate='2026-08-26'; LocalVer='v1.37.0'; Flag='no'},
    [PSCustomObject]@{Id=3;Name='Grafana';    Owner='grafana';     Repo='grafana';   GitVer='v13.0.0'; GitDate='2026-06-01'; LocalVer='未安装';   Flag='no'},
    [PSCustomObject]@{Id=4;Name='Terraform';  Owner='hashicorp';   Repo='terraform'; GitVer='v1.15.0'; GitDate='2026-07-01'; LocalVer='N/A';     Flag='yes'},
    [PSCustomObject]@{Id=5;Name='GhostRepo';  Owner='demonpiapia'; Repo='nonexistent-repo-xyz'; GitVer='v0.1.0'; GitDate='2025-01-01'; LocalVer='v0.1.0'; Flag='no'},
    [PSCustomObject]@{Id=6;Name='TypeScript'; Owner='microsoft';   Repo='typescript';GitVer='v5.0.0';  GitDate='2023-06-01'; LocalVer='v6.0.0';  Flag='no'}
)
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Rows $rows | Out-Null

# Save md-before + SHA256
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

if (-not $script:shouldStop) { Invoke-Step 'step3' 'step3.ps1' | Out-Null }

if (-not $script:shouldStop) {
    $c4 = Invoke-Step 'step4' 'step4.ps1'
    if ($c4 -match 'REVIEW_WRITE_ERROR\|') { $script:shouldStop = $true; $script:stopReason = 'REVIEW_WRITE_ERROR' }
    elseif ($c4 -match 'RUNTIME_ERROR\|')  { $script:shouldStop = $true; $script:stopReason = 'RUNTIME_ERROR' }
}

if (-not $script:shouldStop) { Invoke-Step 'step5-full' 'step5-full.ps1' | Out-Null }

if ($script:shouldStop) { $script:allOutput.Add("PIPELINE_STOPPED_EARLY|$script:stopReason") }

$script:allOutput | Out-File -FilePath $outFile -Encoding UTF8
@() | Out-File -FilePath $errFile -Encoding UTF8

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

Set-Content -Path (Join-Path $base 'exit-code.txt') -Value 0
Write-Host "PIPELINE_DONE|stop=$script:shouldStop|reason=$script:stopReason|outputItems=$($script:allOutput.Count)"
