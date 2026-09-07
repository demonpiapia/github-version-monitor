# T46-v18 runner: .output path contract verification
# Verifies SKILL-v1.8 reads/writes .output/GitHub更新监测列表.md and never creates a root-level file.
$ErrorActionPreference = 'Continue'
$base = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\T46'
$lib  = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# Clean previous run (idempotent)
if (Test-Path (Join-Path $base '.monitor')) { Remove-Item (Join-Path $base '.monitor') -Recurse -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base '.output\GitHub更新监测列表.md.tmp')) { Remove-Item (Join-Path $base '.output\GitHub更新监测列表.md.tmp') -Force -ErrorAction SilentlyContinue }
if (Test-Path (Join-Path $base 'GitHub更新监测列表.md')) { Remove-Item (Join-Path $base 'GitHub更新监测列表.md') -Force -ErrorAction SilentlyContinue }

New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null

# Regenerate fixture
$rows = @(
    [PSCustomObject]@{Id=1;Name='Node.js';    Owner='nodejs';      Repo='node';      GitVer='v26.7.0'; GitDate='2026-07-15'; LocalVer='v26.6.0'; Flag='no'},
    [PSCustomObject]@{Id=2;Name='Kubernetes'; Owner='kubernetes';  Repo='kubernetes';GitVer='v1.37.0'; GitDate='2026-08-26'; LocalVer='v1.37.0'; Flag='no'},
    [PSCustomObject]@{Id=3;Name='Grafana';    Owner='grafana';     Repo='grafana';   GitVer='v13.0.0'; GitDate='2026-06-01'; LocalVer='未安装';   Flag='no'}
)
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Rows $rows | Out-Null

# Pre-check: root md must NOT exist
$rootMdPath = Join-Path $base 'GitHub更新监测列表.md'
$rootMdBefore = Test-Path $rootMdPath
if ($rootMdBefore) { Write-Host 'ERROR: root md exists before test' } else { Write-Host 'OK: no root md before test' }

# Save md-before + SHA256
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-before.md')
$shaBefore = (Get-FileHash (Join-Path $base 'md-before.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

# Run Step 1 + Step 2 only (in-process, shared PID)
$outFile = Join-Path $base 'stdout.txt'
$errFile = Join-Path $base 'stderr.txt'
$allOutput = [System.Collections.Generic.List[string]]::new()

function Invoke-Step([string]$Name, [string]$Script) {
    $allOutput.Add("===== EXECUTING $Name =====")
    try {
        $out = & (Join-Path $lib $Script) 2>&1
        $combined = $out | Out-String -Width 4096
        $allOutput.Add($combined)
        return $combined
    } catch {
        $allOutput.Add(("{0}_EXCEPTION: {1}" -f $Name.ToUpper(), $_))
        return ""
    }
    finally { $allOutput.Add("===== END $Name =====") }
}

$c1 = Invoke-Step 'step1' 'step1.ps1'
if ($c1 -notmatch 'STATE_MISSING\|' -and $c1 -notmatch 'LOCKED\|') {
    Invoke-Step 'step2' 'step2.ps1' | Out-Null
}

$allOutput | Out-File -FilePath $outFile -Encoding UTF8
@() | Out-File -FilePath $errFile -Encoding UTF8

# Save md-after + SHA256
Copy-Item (Join-Path $base '.output\GitHub更新监测列表.md') (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash (Join-Path $base 'md-after.md') -Algorithm SHA256).Hash
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

# Post-check: root md must NOT exist
$rootMdAfter = Test-Path $rootMdPath
if ($rootMdAfter) {
    Set-Content -Path (Join-Path $base 'root-md-check.txt') -Value "FAIL: root md exists after test"
} else {
    Set-Content -Path (Join-Path $base 'root-md-check.txt') -Value "PASS: no root md after test"
}

# Directory listing
Get-ChildItem $base -Recurse | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize | Out-File (Join-Path $base 'directory-listing.txt') -Encoding UTF8

# Result.json (if present)
if (Test-Path (Join-Path $base '.monitor\result.json')) {
    Copy-Item (Join-Path $base '.monitor\result.json') (Join-Path $base 'result-after.json')
}

Write-Host "T46_DONE|rootMdBefore=$rootMdBefore|rootMdAfter=$rootMdAfter"
