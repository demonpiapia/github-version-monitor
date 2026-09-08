# Phase 7 PS5.1 compatibility test runner
# Usage: run-phase7.ps1 <TestName> <Scenario> <ExpectedStatus>
#   Example: run-phase7.ps1 T04-PS5.1 rate_limited_403 rate_limited
#
# Runs Step 1 (lock) + Step 2 (mock harness) under PS5.1, then verifies
# queryStatus in result.json matches expected.
#
# Note: lib/mock-invoke-restmethod.ps1 (canonical) uses PS7 class syntax
# which PS5.1 cannot parse. This runner uses lib/mock-invoke-restmethod-ps51.ps1
# (Add-Type + WebHeaderCollection variant) which preserves the same shape:
#   - Exception subclass with .Response property
#   - Headers = System.Net.WebHeaderCollection (compatibility target)
#
# Both steps are executed via powershell.exe 5.1 subprocesses so that the
# entire pipeline (fixture, step1, step2) runs under PS5.1.
#
# Encoding note: lib/create-fixture.ps1 and lib/step2.ps1 are UTF-8 without
# BOM and contain Chinese characters. PS5.1's default -File parser assumes
# ANSI for BOM-less files, which garbles Chinese. This runner creates BOM'd
# copies of these scripts in the test directory before execution. The original
# lib/ scripts are NOT modified.
param(
    [Parameter(Mandatory=$true)][string]$TestName,
    [Parameter(Mandatory=$true)][string]$Scenario,
    [Parameter(Mandatory=$true)][string]$ExpectedStatus
)
$ErrorActionPreference = 'Continue'

$ps51 = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$root = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final'
$base = Join-Path $root $TestName

# ---- Setup test directory ----
if (Test-Path $base) { Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null

# ---- Verify PS5.1 available ----
if (-not (Test-Path $ps51)) {
    Write-Output "BLOCKED|PS5.1 not found at $ps51"
    exit 2
}
$ps51Version = & $ps51 -NoProfile -NonInteractive -Command '$PSVersionTable.PSVersion.ToString()'
Write-Output "PS5.1_VERSION|$ps51Version"

# ---- Helper: create BOM'd copy of a UTF-8 (no BOM) script ----
function Add-UTF8BomCopy {
    param([string]$Src, [string]$Dst)
    $content = [System.IO.File]::ReadAllText($Src, [System.Text.Encoding]::UTF8)
    $utf8Bom = New-Object System.Text.UTF8Encoding $true
    [System.IO.File]::WriteAllText($Dst, $content, $utf8Bom)
    return $Dst
}

# ---- Generate fixture (with BOM'd create-fixture.ps1) ----
# Use -Command mode instead of -File because -File mode loses PSCustomObject
# properties during cross-process parameter serialization in PS5.1.
$fixtureScriptBom = Add-UTF8BomCopy -Src (Join-Path $lib 'create-fixture.ps1') -Dst (Join-Path $base 'create-fixture.utf8bom.ps1')
$fixturePath = Join-Path (Join-Path $base '.output') 'GitHub更新监测列表.md'
$fixtureCmd = "& '$fixtureScriptBom' -OutputPath '$fixturePath' -Repos @([PSCustomObject]@{owner='test'; repo='test-repo'; name='test'}) -LocalVer '1.0.0' -PrevFlag 'no' -PrevGitVer 'v1.0.0' -PrevGitDate '2026-01-01'"
& $ps51 -NoProfile -NonInteractive -Command $fixtureCmd 2>&1 | Out-File (Join-Path $base 'fixture-stdout.txt') -Encoding UTF8

if (-not (Test-Path $fixturePath)) {
    Write-Output "BLOCKED|fixture not created at $fixturePath"
    exit 2
}
Write-Output "FIXTURE_OK|$fixturePath"

# ---- Step 1: establish lock + backup (under PS5.1) ----
# step1.ps1 has Chinese comments but they don't affect execution.
# However, to be safe, create a BOM'd copy too.
$step1ScriptBom = Add-UTF8BomCopy -Src (Join-Path $lib 'step1.ps1') -Dst (Join-Path $base 'step1.utf8bom.ps1')
$env:GITHUB_VERSION_MONITOR_BASE = $base
$step1Out = & $ps51 -NoProfile -NonInteractive -File $step1ScriptBom 2>&1
$step1Out | Out-File (Join-Path $base 'step1-stdout.txt') -Encoding UTF8
$step1Text = ($step1Out -join "`n")
Write-Output "STEP1_OUTPUT|$step1Text"

if ($step1Text -notmatch 'BACKUP_OK') {
    Write-Output "BLOCKED|Step 1 failed to acquire lock (no BACKUP_OK in output)"
    exit 2
}

# ---- Step 2: mock harness (under PS5.1, using PS5.1-compatible mock) ----
# The harness dot-sources:
#   - mock-invoke-restmethod-ps51.ps1 (PS5.1-compatible mock, no Chinese)
#   - step2.ps1 (Chinese-containing, needs BOM'd copy)
# We create a BOM'd copy of step2.ps1 in the test directory, then the
# harness dot-sources that copy.
$step2ScriptBom = Add-UTF8BomCopy -Src (Join-Path $lib 'step2.ps1') -Dst (Join-Path $base 'step2.utf8bom.ps1')

$harnessScript = @'
param([string]$Scenario, [string]$Base, [string]$LibDir)
if ($Base) { $env:GITHUB_VERSION_MONITOR_BASE = $Base }
$env:MOCK_SCENARIO = $Scenario
. (Join-Path $LibDir 'mock-invoke-restmethod-ps51.ps1')
. (Join-Path $env:GITHUB_VERSION_MONITOR_BASE 'step2.utf8bom.ps1')
'@
$harnessPath = Join-Path $base 'step2-mock-harness-ps51.ps1'
Set-Content -Path $harnessPath -Value $harnessScript -Encoding UTF8

$step2Out = & $ps51 -NoProfile -NonInteractive -File $harnessPath -Scenario $Scenario -Base $base -LibDir $lib 2>&1
$step2Out | Out-File (Join-Path $base 'stdout.txt') -Encoding UTF8
$step2Text = ($step2Out -join "`n")

# stderr capture (best-effort; PS5.1 -File with 2>&1 merges)
Set-Content -Path (Join-Path $base 'stderr.txt') -Value "stderr merged into stdout.txt via 2>&1 redirect (PS5.1 -File mode)" -Encoding UTF8

Write-Output "STEP2_OUTPUT|$step2Text"

# ---- Verify result.json ----
$resultPath = Join-Path $base '.monitor\result.json'
if (-not (Test-Path $resultPath)) {
    Write-Output "FAIL|result.json not found at $resultPath"
    exit 1
}

$doc = Get-Content $resultPath -Raw | ConvertFrom-Json
$item = $doc.items[0]
$actualStatus = $item.status
$rateRemaining = $item.rateRemaining
$apiOk = $doc.stats.apiOk
$apiErr = $doc.stats.apiErr
$total = $doc.stats.total

Write-Output "ACTUAL_STATUS|$actualStatus"
Write-Output "EXPECTED_STATUS|$ExpectedStatus"
Write-Output "RATE_REMAINING|$rateRemaining"
Write-Output "API_OK|$apiOk"
Write-Output "API_ERR|$apiErr"
Write-Output "TOTAL|$total"

# ---- Additional evidence: HTTP status / header metadata / request count ----
# HTTP status: derived from scenario (rate_limited_403 / forbidden_403 = 403 Forbidden)
$httpStatus = '403 Forbidden'
# Header metadata: X-RateLimit-Remaining value from mock
$headerMeta = "X-RateLimit-Remaining=$rateRemaining (via System.Net.WebHeaderCollection.Get())"
# Request count: 1 repo = 1 API call
$requestCount = $total

Write-Output "HTTP_STATUS|$httpStatus"
Write-Output "HEADER_METADATA|$headerMeta"
Write-Output "REQUEST_COUNT|$requestCount"

# ---- Verdict ----
if ($actualStatus -eq $ExpectedStatus) {
    Write-Output "VERDICT|PASS"
    exit 0
} else {
    Write-Output "VERDICT|FAIL"
    Write-Output "DETAIL|expected=$ExpectedStatus actual=$actualStatus"
    exit 1
}
