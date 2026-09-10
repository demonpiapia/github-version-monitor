$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$root = 'D:\AI\Workspace\automatic\github-version-monitor'
$pv   = Join-Path $root '.production-validation-v112-final'
$lib  = Join-Path $pv 'lib'

Write-Output '=== FINAL DELIVERABLE VERIFICATION ==='
Write-Output ''

Write-Output '[A] lib/ contents (15 files expected):'
$libFiles = Get-ChildItem $lib -File | Sort-Object Name
$libFiles | ForEach-Object { Write-Output ("  {0,-40} {1,6}" -f $_.Name, $_.Length) }
Write-Output ("  TOTAL: {0} files" -f $libFiles.Count)

Write-Output ''
Write-Output '[B] Required files present check:'
$required = @(
    'lib\step1.ps1',
    'lib\step2.ps1',
    'lib\step3.ps1',
    'lib\step4.ps1',
    'lib\step5-full.ps1',
    'lib\run-full-pipeline.ps1',
    'lib\t3-mock-harness.ps1',
    'lib\t4-write-failure-harness.ps1',
    'lib\t5-housekeeping-harness.ps1',
    'lib\create-fixture.ps1',
    'lib\lock-holder.ps1',
    'lib\mock-invoke-restmethod.ps1',
    'lib\extract-code.ps1',
    'lib\extraction-manifest.json',
    'lib\mock-contract-selfcheck.txt',
    'phase2-stdout.txt',
    'phase2-stderr.txt',
    'phase2-report.md',
    'phase-progress.json'
)
$missing = @()
foreach ($f in $required) {
    $p = Join-Path $pv $f
    $ok = Test-Path $p
    Write-Output ("  {0,-45} {1}" -f $f, $ok)
    if (-not $ok) { $missing += $f }
}
if ($missing.Count -eq 0) { Write-Output 'ALL_REQUIRED_FILES_PRESENT=YES' } else { Write-Output "MISSING: $($missing -join ', ')" }

Write-Output ''
Write-Output '[C] SKILL-v1.12.md SHA256 (final read-only verification):'
$sha = (Get-FileHash (Join-Path $root 'SKILL-v1.12.md') -Algorithm SHA256).Hash.ToUpper()
Write-Output ("  actual:   {0}" -f $sha)
Write-Output ('  expected: 3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9')
Write-Output ("  MATCH:    {0}" -f ($sha -ceq '3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9'))

Write-Output ''
Write-Output '[D] .monitor/ must NOT exist (root or v112-final):'
Write-Output ("  root/.monitor:             {0}" -f (Test-Path (Join-Path $root '.monitor')))
Write-Output ("  v112-final/.monitor:       {0}" -f (Test-Path (Join-Path $pv '.monitor')))

Write-Output ''
Write-Output '[E] phase-progress.json top-level status:'
$prog = Get-Content (Join-Path $pv 'phase-progress.json') -Raw | ConvertFrom-Json
Write-Output ("  phase: {0}" -f $prog.phase)
Write-Output ("  status: {0}" -f $prog.status)
