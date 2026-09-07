#Requires -Version 7.0
<#
    T19 - 未安装 (Uninstalled) Scenario
    Construct a scenario where localVer="未安装" in the fixture.

    Expected:
    - flag=no (because localVer is "未安装" / not installed, so there's nothing to compare)
    - gitVer refreshed (updated from API if API returns 200)
    - gitDate refreshed (updated from API if API returns 200)

    The logic from SKILL-v1.7.md:
    - ConvertTo-NormVer returns $null for "未安装"
    - Compare-Ver returns 'incomparable' when either side is $null
    - But the version comparison logic checks for '未安装' before calling Compare-Ver:
      if ($localVer -match '未安装') { $newFlag = 'no' }
    - So flag=no directly, and gitVer/gitDate are refreshed from the API response
#>

$ErrorActionPreference = 'Stop'
$testDir = $PSScriptRoot

# ============================================================================
# stdout capture
# ============================================================================
$stdout = [System.Collections.Generic.List[string]]::new()
function Log([string]$m) { Write-Host $m; $stdout.Add($m) | Out-Null }

# ============================================================================
# Helper functions (extracted verbatim from SKILL-v1.7.md Step 2)
# ============================================================================

function ConvertTo-UtcIso {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '' }
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    if ($Value -is [DateTime]) { return ([DateTimeOffset]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return ([DateTimeOffset]::Parse([string]$Value)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function Get-ResponseHeaderValue {
    param($Headers, [string]$Name)
    try { if ($Headers -is [System.Net.WebHeaderCollection]) { $v = $Headers.Get($Name); if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } } catch {}
    try { $v = $Headers[$Name]; if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } catch {}
    try { $values = $null; if ($Headers.TryGetValues($Name, [ref]$values)) { $first = $values | Select-Object -First 1; if ($null -ne $first) { return [string]$first } } } catch {}
    return ''
}

function ConvertTo-NormVer {
    param([string]$v)
    if ([string]::IsNullOrWhiteSpace($v) -or $v -match '未安装|暂无') { return $null }
    $s = $v.Trim() -replace '^[vV]', '' -replace '\+.*$', ''
    $m = [regex]::Match($s, '^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:[-_.](rc|prototype|alpha|beta|nightly|canary|pre|dev|r)[-_.]?(\d+))?$', 'IgnoreCase')
    if (-not $m.Success) { return $null }
    [PSCustomObject]@{
        Major   = [int]$m.Groups[1].Value
        Minor   = if ($m.Groups[2].Success) { [int]$m.Groups[2].Value } else { 0 }
        Patch   = if ($m.Groups[3].Success) { [int]$m.Groups[3].Value } else { 0 }
        Pre     = $m.Groups[4].Success
        PreName = if ($m.Groups[4].Success) { $m.Groups[4].Value.ToLower() } else { '' }
        PreNum  = if ($m.Groups[5].Success) { [int]$m.Groups[5].Value } else { 0 }
    }
}

function Compare-Ver {
    param([string]$a, [string]$b)
    $na = ConvertTo-NormVer $a; $nb = ConvertTo-NormVer $b
    if ($null -eq $na -or $null -eq $nb) { return 'incomparable' }
    foreach ($f in 'Major', 'Minor', 'Patch') {
        if ($na.$f -lt $nb.$f) { return 'lt' }
        if ($na.$f -gt $nb.$f) { return 'gt' }
    }
    if (-not $na.Pre -and -not $nb.Pre) { return 'eq' }
    if ($na.Pre -and -not $nb.Pre) { return 'lt' }
    if (-not $na.Pre -and $nb.Pre) { return 'gt' }
    if ($na.PreName -ne $nb.PreName) { return 'incomparable' }
    if ($na.PreNum -lt $nb.PreNum) { return 'lt' }
    if ($na.PreNum -gt $nb.PreNum) { return 'gt' }
    return 'eq'
}

# ============================================================================
# Test infrastructure
# ============================================================================
$script:TestResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:AllPassed = $true

function Invoke-Test {
    param(
        [string]$TestId,
        [string]$Description,
        [string]$Expected,
        [string]$Actual,
        [string]$Evidence
    )
    $verdict = if ($Actual -eq $Expected) { 'PASS' } else { 'FAIL'; $script:AllPassed = $false }
    $script:TestResults.Add([PSCustomObject]@{
        TestId      = $TestId
        Description = $Description
        Expected    = $Expected
        Actual      = $Actual
        Verdict     = $verdict
        Evidence    = $Evidence
    })
}

# ============================================================================
# Load GITHUB_TOKEN from .env if not set
# ============================================================================
$base = 'd:\AI\Workspace\automatic\github-version-monitor'
if (-not $env:GITHUB_TOKEN) {
    $envFile = Join-Path $base '.env'
    if (Test-Path $envFile) {
        foreach ($line in (Get-Content $envFile)) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$') {
                if (-not (Get-Content "env:$($Matches[1])" -ErrorAction SilentlyContinue)) {
                    Set-Content -Path "env:$($Matches[1])" -Value $Matches[2]
                }
            }
        }
    }
}

# ============================================================================
# Fixture: localVer = "未安装"
# ============================================================================
$repo       = 'microsoft/vscode'
$prevGitVer = 'v1.90.0'
$prevGitDate = '2024-06-01'
$localVer   = '未安装'
$prevFlag   = 'no'

# ============================================================================
# API query (same as SKILL-v1.7.md Step 2)
# ============================================================================
$token = $env:GITHUB_TOKEN
$headers = @{
    'User-Agent'           = 'workbuddy-version-monitor'
    'Accept'               = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2026-03-10'
}
if ($token) { $headers['Authorization'] = "Bearer $token" }

Log "========== T19 - 未安装 (Uninstalled) Scenario =========="
Log "Repo: $repo"
Log "PrevGitVer: $prevGitVer"
Log "PrevGitDate: $prevGitDate"
Log "LocalVer: $localVer"
Log "PrevFlag: $prevFlag"
Log "Token: $(if ($token) { 'set' } else { 'unset' })"
Log ""

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''

try {
    Log "[API CALL] GET https://api.github.com/repos/$repo/releases/latest"
    $j = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
    Log "[API RESPONSE] tag_name=$($j.tag_name) published_at=$($j.published_at)"
    if ($j.tag_name -and $j.published_at) {
        $pubUtc = ConvertTo-UtcIso $j.published_at
        $dtUtc = [DateTimeOffset]::Parse($pubUtc)
        $pubDate = $dtUtc.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd')
        $latest = $j.tag_name
    } elseif ($j.tag_name) {
        $status = 'metadata_incomplete'
        $err = 'tag_name present but published_at missing'
    } else {
        $status = 'invalid_response'; $err = '200 but empty tag_name'
    }
} catch {
    $code = $null
    try { if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $code = [int]$_.Exception.Response.StatusCode } } catch {}
    try {
        if ($_.Exception.Response -and $_.Exception.Response.Headers) {
            $rl = Get-ResponseHeaderValue $_.Exception.Response.Headers 'X-RateLimit-Remaining'
        }
    } catch { $rl = '' }
    if     ($code -eq 401)             { $status = 'auth_error' }
    elseif ($code -eq 404)             { $status = 'not_found' }
    elseif ($code -eq 429)             { $status = 'rate_limited' }
    elseif ($code -eq 403)             { $status = if ($rl -eq '0') { 'rate_limited' } else { 'forbidden' } }
    elseif ($code -and $code -ge 500)  { $status = 'server_error' }
    elseif ($code)                     { $status = 'http_error' }
    else                               { $status = 'network_error' }
    $err = $_.Exception.Message
}

Log ""
Log "=== State Machine Output ==="
Log "queryStatus: $status"
Log "latest (tag_name): $latest"
Log "publishedUtc: $pubUtc"
Log "pubDate (UTC+8): $pubDate"
Log "error: $err"
Log ""

# ============================================================================
# State machine logic (from SKILL-v1.7.md Step 2)
# ============================================================================
$newGitVer = $prevGitVer; $newGitDate = $prevGitDate; $newFlag = $prevFlag
$isNew = $false; $isFlip = $false; $review = $false; $cmp = ''
$versionJump = $false; $dateSuspicious = $false; $reasons = @()

if ($status -eq 'ok' -and $latest) {
    $isNew = ($latest -ne $prevGitVer)
    if ($isNew) {
        $newGitVer = $latest
        $newGitDate = $pubDate
        $oldV = ConvertTo-NormVer $prevGitVer
        $newV = ConvertTo-NormVer $latest
        if ($null -ne $oldV -and $null -ne $newV) {
            if (($newV.Major - $oldV.Major) -ge 2 -or
                (($newV.Major -eq $oldV.Major) -and (($newV.Minor - $oldV.Minor) -ge 10)) -or
                (($newV.Major -eq $oldV.Major) -and ($newV.Minor -eq $oldV.Minor) -and (($newV.Patch - $oldV.Patch) -ge 50))) {
                $versionJump = $true; $reasons += 'version_jump'
            }
            if ($pubUtc -and $prevGitDate -match '^\d{4}-\d{2}-\d{2}$') {
                $newDate = ([DateTimeOffset]::Parse($pubUtc)).ToOffset([TimeSpan]::FromHours(8)).Date
                $oldDate = [DateTime]::ParseExact($prevGitDate, 'yyyy-MM-dd', $null).Date
                if ($newDate -lt $oldDate) { $dateSuspicious = $true; $reasons += 'date_suspicious' }
            }
        }
    }
    # Key logic: when localVer is "未安装", flag=no directly
    if ($localVer -match '未安装') {
        $newFlag = 'no'
    } else {
        $cmp = Compare-Ver $localVer $latest
        switch ($cmp) {
            'lt' { $newFlag = 'yes' }
            'eq' { $newFlag = 'no' }
            default { $newFlag = $prevFlag; $review = $true; $reasons += 'incomparable_version' }
        }
    }
    if ($prevFlag -ceq 'no' -and $newFlag -ceq 'yes') { $isFlip = $true }
    if ($versionJump -or $dateSuspicious) { $review = $true }
} elseif ($status -eq 'not_found') {
    $newGitVer = ''; $newGitDate = ''; $newFlag = $prevFlag
    $review = $true; $reasons += 'not_found'
} else {
    $review = $true; $reasons += 'api_failure'
}

Log "=== Comparison + Review Output ==="
Log "gitVer (newGitVer): $newGitVer"
Log "gitDate (newGitDate): $newGitDate"
Log "flag (newFlag): $newFlag"
Log "prevFlag: $prevFlag"
Log "cmp: $cmp"
Log "isNew: $isNew"
Log "isFlip: $isFlip"
Log "versionJump: $versionJump"
Log "dateSuspicious: $dateSuspicious"
Log "review: $review"
Log "reviewReasons: $($reasons -join ', ')"
Log ""

# ============================================================================
# Verification
# ============================================================================
Log "=== Verification ==="

# T19a: flag should be "no" because localVer is "未安装"
$v1 = ($newFlag -ceq 'no')
Log "flag=no (because localVer='未安装'): $v1 (actual: '$newFlag')"
Invoke-Test -TestId "T19a" `
    -Description "flag should be 'no' when localVer='未安装' (not installed, nothing to compare)" `
    -Expected "no" -Actual $newFlag `
    -Evidence "localVer='$localVer', flag='$newFlag', status=$status"

# T19b: gitVer should be refreshed (updated from API tag_name)
$v2 = ($status -eq 'ok' -and $newGitVer -eq $latest -and $latest -ne $prevGitVer)
$v2_alt = ($status -eq 'ok' -and $newGitVer -eq $latest)
Log "gitVer refreshed from API (=$latest, !=prev $prevGitVer): $v2"
if (-not $v2 -and $v2_alt) { Log "  (gitVer matches latest but may equal prev if no new release)" }
Invoke-Test -TestId "T19b" `
    -Description "gitVer should be refreshed to latest API tag_name when API returns 200" `
    -Expected "PASS" -Actual $(if ($v2_alt) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, gitVer='$newGitVer', latest='$latest', prevGitVer='$prevGitVer', isNew=$isNew"

# T19c: gitDate should be refreshed (updated from API published_at)
$v3 = ($status -eq 'ok' -and $newGitDate -eq $pubDate)
Log "gitDate refreshed from API (=pubDate $pubDate): $v3"
Invoke-Test -TestId "T19c" `
    -Description "gitDate should be refreshed to API published date when API returns 200" `
    -Expected "PASS" -Actual $(if ($v3) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, gitDate='$newGitDate', pubDate='$pubDate', prevGitDate='$prevGitDate'"

# T19d: ConvertTo-NormVer returns null for "未安装"
$normVer = ConvertTo-NormVer '未安装'
$v4 = ($null -eq $normVer)
Log "ConvertTo-NormVer('未安装')=null: $v4"
Invoke-Test -TestId "T19d" `
    -Description "ConvertTo-NormVer should return null for '未安装'" `
    -Expected "PASS" -Actual $(if ($v4) { 'PASS' } else { 'FAIL' }) `
    -Evidence "ConvertTo-NormVer('未安装') = $(if ($null -eq $normVer) { 'null' } else { $normVer })"

# T19e: Compare-Ver returns 'incomparable' when localVer is "未安装"
$cmpResult = Compare-Ver '未安装' $latest
$v5 = ($cmpResult -eq 'incomparable')
Log "Compare-Ver('未安装', '$latest')=incomparable: $v5 (actual: '$cmpResult')"
Invoke-Test -TestId "T19e" `
    -Description "Compare-Ver should return 'incomparable' when localVer='未安装' (null normalization)" `
    -Expected "incomparable" -Actual $cmpResult `
    -Evidence "Compare-Ver('未安装', '$latest') = '$cmpResult' (ConvertTo-NormVer returned null for '未安装')"

# ============================================================================
# Summary
# ============================================================================
Log ""
Log "========== SUMMARY =========="
$passCount = ($script:TestResults | Where-Object { $_.Verdict -eq 'PASS' }).Count
$failCount = ($script:TestResults | Where-Object { $_.Verdict -eq 'FAIL' }).Count
Log "Total: $($script:TestResults.Count) | PASS: $passCount | FAIL: $failCount"
foreach ($r in $script:TestResults) {
    Log "  [$($r.Verdict)] $($r.TestId): $($r.Description)"
}

# ============================================================================
# Generate test-report.md
# ============================================================================
$reportPath = Join-Path $testDir "test-report.md"

$md = [System.Text.StringBuilder]::new()
[void]$md.AppendLine("# Production Validation v1.7 Final - Test Report (T19)")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
[void]$md.AppendLine("**Script:** ``test.ps1``")
[void]$md.AppendLine("**Test:** T19 - 未安装 (Uninstalled) Scenario")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Summary")
[void]$md.AppendLine("")
[void]$md.AppendLine("| Metric | Value |")
[void]$md.AppendLine("|--------|-------|")
[void]$md.AppendLine("| Total Tests | $($script:TestResults.Count) |")
[void]$md.AppendLine("| PASS | $passCount |")
[void]$md.AppendLine("| FAIL | $failCount |")
[void]$md.AppendLine("| Overall | $(if ($script:AllPassed) { 'ALL PASS' } else { 'HAS FAILURES' }) |")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Test Methodology")
[void]$md.AppendLine("")
[void]$md.AppendLine("Real GitHub API call to ``microsoft/vscode`` ``releases/latest`` endpoint.")
[void]$md.AppendLine("The fixture sets ``localVer = '未安装'`` (uninstalled).")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Fixture:**")
[void]$md.AppendLine("- ``repo = 'microsoft/vscode'``")
[void]$md.AppendLine("- ``prevGitVer = 'v1.90.0'`` (simulated, lower than latest)")
[void]$md.AppendLine("- ``prevGitDate = '2024-06-01'`` (simulated)")
[void]$md.AppendLine("- ``localVer = '未安装'`` (uninstalled)")
[void]$md.AppendLine("- ``prevFlag = 'no'``")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Expected behavior per SKILL-v1.7.md:**")
[void]$md.AppendLine("- ``ConvertTo-NormVer('未安装')`` returns ``$null``")
[void]$md.AppendLine("- The state machine checks ``$localVer -match '未安装'`` before calling ``Compare-Ver``")
[void]$md.AppendLine("- When matched: ``$newFlag = 'no'`` (not installed → nothing to compare → no update needed)")
[void]$md.AppendLine("- But ``gitVer`` and ``gitDate`` ARE still refreshed from the API response")
[void]$md.AppendLine("")
[void]$md.AppendLine("## Test Details")
[void]$md.AppendLine("")

foreach ($r in $script:TestResults) {
    [void]$md.AppendLine("### $($r.TestId)")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("| Field | Value |")
    [void]$md.AppendLine("|-------|-------|")
    [void]$md.AppendLine("| Test ID | $($r.TestId) |")
    [void]$md.AppendLine("| Description | $($r.Description) |")
    [void]$md.AppendLine("| Expected | ``$($r.Expected)`` |")
    [void]$md.AppendLine("| Actual | ``$($r.Actual)`` |")
    [void]$md.AppendLine("| Verdict | **$($r.Verdict)** |")
    [void]$md.AppendLine("| Evidence | $($r.Evidence) |")
    [void]$md.AppendLine("")
}

$codeBlock = @'
## State Machine Logic Under Test

```powershell
# From SKILL-v1.7.md Step 2, version comparison logic:
if ($localVer -match '未安装') {
    $newFlag = 'no'    # not installed, nothing to compare
} else {
    $cmp = Compare-Ver $localVer $latest
    switch ($cmp) {
        'lt' { $newFlag = 'yes' }
        'eq' { $newFlag = 'no' }
        default { $newFlag = $prevFlag; $review = $true; $reasons += 'incomparable_version' }
    }
}
# gitVer and gitDate are refreshed from API response regardless of localVer
```
'@
[void]$md.Append($codeBlock)
[void]$md.AppendLine("")

Set-Content -Path $reportPath -Value $md.ToString() -Encoding UTF8
Log ""
Log "Report saved to: $reportPath"

# ============================================================================
# Save stdout
# ============================================================================
$stdoutPath = Join-Path $testDir "stdout.txt"
$stdout | Set-Content -Path $stdoutPath -Encoding UTF8
Log "stdout saved to: $stdoutPath"

if ($script:AllPassed) {
    Log ""
    Log "ALL TESTS PASSED"
} else {
    Log ""
    Log "SOME TESTS FAILED - see report above"
}
