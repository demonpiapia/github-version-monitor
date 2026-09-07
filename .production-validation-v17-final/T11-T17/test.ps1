#Requires -Version 7.0
<#
    Production Validation v1.7 Final - Tests T11-T17
    Tests Compare-Ver, ConvertTo-NormVer, Test-VersionJump, Test-DateSuspicious, Test-IsFlip
#>

# ============================================================================
# Functions under test (extracted from SKILL-v1.7.md Step 2 code block)
# ============================================================================

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
    foreach ($f in 'Major','Minor','Patch') {
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

function Test-VersionJump {
    param([string]$oldVer, [string]$newVer)
    $oldV = ConvertTo-NormVer $oldVer
    $newV = ConvertTo-NormVer $newVer
    if ($null -ne $oldV -and $null -ne $newV) {
        if (($newV.Major - $oldV.Major) -ge 2 -or
            (($newV.Major -eq $oldV.Major) -and (($newV.Minor - $oldV.Minor) -ge 10)) -or
            (($newV.Major -eq $oldV.Major) -and ($newV.Minor -eq $oldV.Minor) -and (($newV.Patch - $oldV.Patch) -ge 50))) {
            return $true
        }
    }
    return $false
}

function Test-DateSuspicious {
    param([string]$publishedUtc, [string]$prevGitDate)
    if ($publishedUtc -and $prevGitDate -match '^\d{4}-\d{2}-\d{2}$') {
        $newDate = ([DateTimeOffset]::Parse($publishedUtc)).ToOffset([TimeSpan]::FromHours(8)).Date
        $oldDate = [DateTime]::ParseExact($prevGitDate, 'yyyy-MM-dd', $null).Date
        if ($newDate -lt $oldDate) { return $true }
    }
    return $false
}

function Test-IsFlip {
    param([string]$prevFlag, [string]$localVer, [string]$latest)
    $cmp = Compare-Ver $localVer $latest
    $newFlag = if ($cmp -eq 'lt') { 'yes' } else { 'no' }
    if ($prevFlag -eq 'no' -and $newFlag -eq 'yes') { return $true }
    return $false
}

# ============================================================================
# Test runner
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
# T11 - Normal version comparison
# ============================================================================
Write-Host "========== T11 - Normal version comparison =========="
$cmp_t11 = Compare-Ver "1.2.3" "1.2.4"
Write-Host "Compare-Ver '1.2.3' '1.2.4' = $cmp_t11 (expected: lt)"
Invoke-Test -TestId "T11" `
    -Description "Compare-Ver '1.2.3' '1.2.4' should return 'lt' (1.2.3 < 1.2.4)" `
    -Expected "lt" -Actual $cmp_t11 `
    -Evidence "Compare-Ver '1.2.3' '1.2.4' returned: $cmp_t11"

# ============================================================================
# T12 - Numeric version sort (not string sort)
# ============================================================================
Write-Host ""
Write-Host "========== T12 - Numeric version sort =========="
$cmp_t12 = Compare-Ver "1.2.10" "1.2.9"
Write-Host "Compare-Ver '1.2.10' '1.2.9' = $cmp_t12 (expected: gt, not string sort)"
Invoke-Test -TestId "T12" `
    -Description "Compare-Ver '1.2.10' '1.2.9' should return 'gt' (numeric 10 > 9, not string '10' < '9')" `
    -Expected "gt" -Actual $cmp_t12 `
    -Evidence "Compare-Ver '1.2.10' '1.2.9' returned: $cmp_t12"

# ============================================================================
# T13 - Prerelease < stable
# ============================================================================
Write-Host ""
Write-Host "========== T13 - Prerelease < stable =========="
$cmp_t13 = Compare-Ver "1.2.3-rc1" "1.2.3"
Write-Host "Compare-Ver '1.2.3-rc1' '1.2.3' = $cmp_t13 (expected: lt, prerelease < stable)"
Invoke-Test -TestId "T13" `
    -Description "Compare-Ver '1.2.3-rc1' '1.2.3' should return 'lt' (prerelease is less than stable)" `
    -Expected "lt" -Actual $cmp_t13 `
    -Evidence "Compare-Ver '1.2.3-rc1' '1.2.3' returned: $cmp_t13"

# ============================================================================
# T14 - Incomparable + v-prefix normalization
# ============================================================================
Write-Host ""
Write-Host "========== T14 - Incomparable + v-prefix normalization =========="
$cmp_t14a = Compare-Ver "some-weird-version" "1.2.3"
Write-Host "Compare-Ver 'some-weird-version' '1.2.3' = $cmp_t14a (expected: incomparable)"
Invoke-Test -TestId "T14a" `
    -Description "Compare-Ver 'some-weird-version' '1.2.3' should return 'incomparable' (non-parseable version)" `
    -Expected "incomparable" -Actual $cmp_t14a `
    -Evidence "Compare-Ver 'some-weird-version' '1.2.3' returned: $cmp_t14a"

$cmp_t14b = Compare-Ver "v1.0" "1.0"
Write-Host "Compare-Ver 'v1.0' '1.0' = $cmp_t14b (expected: eq, v-prefix stripped)"
Invoke-Test -TestId "T14b" `
    -Description "Compare-Ver 'v1.0' '1.0' should return 'eq' (v-prefix is stripped, then 1.0 == 1.0)" `
    -Expected "eq" -Actual $cmp_t14b `
    -Evidence "Compare-Ver 'v1.0' '1.0' returned: $cmp_t14b"

# ============================================================================
# T15 - versionJump boundary tests
# ============================================================================
Write-Host ""
Write-Host "========== T15 - versionJump boundary tests =========="

# T15a: major 1->2 (diff=1, NOT jump, threshold is >=2)
$jump_t15a = Test-VersionJump "1.0.0" "2.0.0"
Write-Host "T15a: major 1->2 (diff=1), expected jump=False, actual=$jump_t15a"
Invoke-Test -TestId "T15a" `
    -Description "versionJump: major 1->2 (diff=1, threshold >=2) should NOT be a jump" `
    -Expected "False" -Actual "$jump_t15a" `
    -Evidence "Test-VersionJump '1.0.0' '2.0.0' = $jump_t15a (major diff=1 < 2)"

# T15b: major 1->3 (diff=2, IS jump)
$jump_t15b = Test-VersionJump "1.0.0" "3.0.0"
Write-Host "T15b: major 1->3 (diff=2), expected jump=True, actual=$jump_t15b"
Invoke-Test -TestId "T15b" `
    -Description "versionJump: major 1->3 (diff=2, threshold >=2) should be a jump" `
    -Expected "True" -Actual "$jump_t15b" `
    -Evidence "Test-VersionJump '1.0.0' '3.0.0' = $jump_t15b (major diff=2 >= 2)"

# T15c: minor 9->10 same major (diff=1, NOT jump, threshold is >=10)
$jump_t15c = Test-VersionJump "1.9.0" "1.10.0"
Write-Host "T15c: minor 9->10 same major (diff=1), expected jump=False, actual=$jump_t15c"
Invoke-Test -TestId "T15c" `
    -Description "versionJump: minor 9->10 same major (diff=1, threshold >=10) should NOT be a jump" `
    -Expected "False" -Actual "$jump_t15c" `
    -Evidence "Test-VersionJump '1.9.0' '1.10.0' = $jump_t15c (minor diff=1 < 10)"

# T15d: minor 0->10 same major (diff=10, IS jump)
$jump_t15d = Test-VersionJump "1.0.0" "1.10.0"
Write-Host "T15d: minor 0->10 same major (diff=10), expected jump=True, actual=$jump_t15d"
Invoke-Test -TestId "T15d" `
    -Description "versionJump: minor 0->10 same major (diff=10, threshold >=10) should be a jump" `
    -Expected "True" -Actual "$jump_t15d" `
    -Evidence "Test-VersionJump '1.0.0' '1.10.0' = $jump_t15d (minor diff=10 >= 10)"

# T15e: minor 0->9 same major (diff=9, NOT jump)
$jump_t15e = Test-VersionJump "1.0.0" "1.9.0"
Write-Host "T15e: minor 0->9 same major (diff=9), expected jump=False, actual=$jump_t15e"
Invoke-Test -TestId "T15e" `
    -Description "versionJump: minor 0->9 same major (diff=9, threshold >=10) should NOT be a jump" `
    -Expected "False" -Actual "$jump_t15e" `
    -Evidence "Test-VersionJump '1.0.0' '1.9.0' = $jump_t15e (minor diff=9 < 10)"

# T15f: patch 49->50 same major+minor (diff=1, NOT jump, threshold is >=50)
$jump_t15f = Test-VersionJump "1.0.49" "1.0.50"
Write-Host "T15f: patch 49->50 same major+minor (diff=1), expected jump=False, actual=$jump_t15f"
Invoke-Test -TestId "T15f" `
    -Description "versionJump: patch 49->50 same major+minor (diff=1, threshold >=50) should NOT be a jump" `
    -Expected "False" -Actual "$jump_t15f" `
    -Evidence "Test-VersionJump '1.0.49' '1.0.50' = $jump_t15f (patch diff=1 < 50)"

# T15g: patch 0->50 same major+minor (diff=50, IS jump)
$jump_t15g = Test-VersionJump "1.0.0" "1.0.50"
Write-Host "T15g: patch 0->50 same major+minor (diff=50), expected jump=True, actual=$jump_t15g"
Invoke-Test -TestId "T15g" `
    -Description "versionJump: patch 0->50 same major+minor (diff=50, threshold >=50) should be a jump" `
    -Expected "True" -Actual "$jump_t15g" `
    -Evidence "Test-VersionJump '1.0.0' '1.0.50' = $jump_t15g (patch diff=50 >= 50)"

# T15h: patch 0->49 same major+minor (diff=49, NOT jump)
$jump_t15h = Test-VersionJump "1.0.0" "1.0.49"
Write-Host "T15h: patch 0->49 same major+minor (diff=49), expected jump=False, actual=$jump_t15h"
Invoke-Test -TestId "T15h" `
    -Description "versionJump: patch 0->49 same major+minor (diff=49, threshold >=50) should NOT be a jump" `
    -Expected "False" -Actual "$jump_t15h" `
    -Evidence "Test-VersionJump '1.0.0' '1.0.49' = $jump_t15h (patch diff=49 < 50)"

# ============================================================================
# T16 - dateSuspicious logic
# ============================================================================
Write-Host ""
Write-Host "========== T16 - dateSuspicious logic =========="
# Construct: prevGitDate is later than the new publishedUtc's Beijing date.
# publishedUtc = "2026-01-01T00:00:00Z" -> Beijing = 2026-01-01 08:00 -> date 2026-01-01
# prevGitDate = "2026-06-01" -> later than 2026-01-01
# So newDate < oldDate -> suspicious = true
$ds_t16 = Test-DateSuspicious -publishedUtc "2026-01-01T00:00:00Z" -prevGitDate "2026-06-01"
Write-Host "T16: publishedUtc='2026-01-01T00:00:00Z' (Beijing date=2026-01-01), prevGitDate='2026-06-01'"
Write-Host "    newDate(2026-01-01) < oldDate(2026-06-01), expected dateSuspicious=True, actual=$ds_t16"
Invoke-Test -TestId "T16" `
    -Description "dateSuspicious: prevGitDate '2026-06-01' is later than publishedUtc '2026-01-01T00:00:00Z' Beijing date (2026-01-01), should return True" `
    -Expected "True" -Actual "$ds_t16" `
    -Evidence "Test-DateSuspicious publishedUtc='2026-01-01T00:00:00Z' prevGitDate='2026-06-01' = $ds_t16 (new Beijing date 2026-01-01 < old date 2026-06-01)"

# Also test the negative case for completeness
$ds_t16_neg = Test-DateSuspicious -publishedUtc "2026-06-01T00:00:00Z" -prevGitDate "2026-01-01"
Write-Host "T16-neg: publishedUtc='2026-06-01T00:00:00Z' (Beijing date=2026-06-01), prevGitDate='2026-01-01'"
Write-Host "    newDate(2026-06-01) > oldDate(2026-01-01), expected dateSuspicious=False, actual=$ds_t16_neg"
Invoke-Test -TestId "T16-neg" `
    -Description "dateSuspicious (negative): prevGitDate '2026-01-01' is earlier than publishedUtc '2026-06-01T00:00:00Z' Beijing date (2026-06-01), should return False" `
    -Expected "False" -Actual "$ds_t16_neg" `
    -Evidence "Test-DateSuspicious publishedUtc='2026-06-01T00:00:00Z' prevGitDate='2026-01-01' = $ds_t16_neg (new Beijing date 2026-06-01 > old date 2026-01-01)"

# ============================================================================
# T17 - isFlip logic
# ============================================================================
Write-Host ""
Write-Host "========== T17 - isFlip logic =========="
# prevFlag="no" and new flag becomes "yes" (localVer < latest)
# localVer="1.0.0", latest="1.0.1" -> Compare-Ver returns "lt" -> newFlag="yes"
# prevFlag="no" -> isFlip = true
$flip_t17 = Test-IsFlip -prevFlag "no" -localVer "1.0.0" -latest "1.0.1"
Write-Host "T17: prevFlag='no', localVer='1.0.0', latest='1.0.1'"
Write-Host "    Compare-Ver('1.0.0','1.0.1')=lt -> newFlag='yes', prevFlag='no' -> isFlip=True, actual=$flip_t17"
Invoke-Test -TestId "T17" `
    -Description "isFlip: prevFlag='no', localVer='1.0.0' < latest='1.0.1' (cmp=lt, newFlag=yes), should flip to True" `
    -Expected "True" -Actual "$flip_t17" `
    -Evidence "Test-IsFlip prevFlag='no' localVer='1.0.0' latest='1.0.1' = $flip_t17 (Compare-Ver returned lt, newFlag=yes, prevFlag=no -> flip)"

# Also test negative case: prevFlag already "yes" -> no flip
$flip_t17_neg = Test-IsFlip -prevFlag "yes" -localVer "1.0.0" -latest "1.0.1"
Write-Host "T17-neg: prevFlag='yes', localVer='1.0.0', latest='1.0.1'"
Write-Host "    Compare-Ver('1.0.0','1.0.1')=lt -> newFlag='yes', but prevFlag='yes' -> isFlip=False, actual=$flip_t17_neg"
Invoke-Test -TestId "T17-neg" `
    -Description "isFlip (negative): prevFlag='yes' already, localVer='1.0.0' < latest='1.0.1' (newFlag=yes but prevFlag=yes), should NOT flip" `
    -Expected "False" -Actual "$flip_t17_neg" `
    -Evidence "Test-IsFlip prevFlag='yes' localVer='1.0.0' latest='1.0.1' = $flip_t17_neg (newFlag=yes but prevFlag already yes -> no flip)"

# Also test: localVer >= latest -> newFlag="no", prevFlag="no" -> no flip
$flip_t17_neg2 = Test-IsFlip -prevFlag "no" -localVer "1.0.1" -latest "1.0.0"
Write-Host "T17-neg2: prevFlag='no', localVer='1.0.1', latest='1.0.0'"
Write-Host "    Compare-Ver('1.0.1','1.0.0')=gt -> newFlag='no', prevFlag='no' -> isFlip=False, actual=$flip_t17_neg2"
Invoke-Test -TestId "T17-neg2" `
    -Description "isFlip (negative): prevFlag='no', localVer='1.0.1' >= latest='1.0.0' (newFlag=no), should NOT flip" `
    -Expected "False" -Actual "$flip_t17_neg2" `
    -Evidence "Test-IsFlip prevFlag='no' localVer='1.0.1' latest='1.0.0' = $flip_t17_neg2 (Compare-Ver returned gt, newFlag=no, no flip)"

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "========== SUMMARY =========="
$passCount = ($script:TestResults | Where-Object { $_.Verdict -eq 'PASS' }).Count
$failCount = ($script:TestResults | Where-Object { $_.Verdict -eq 'FAIL' }).Count
Write-Host "Total: $($script:TestResults.Count) | PASS: $passCount | FAIL: $failCount"
foreach ($r in $script:TestResults) {
    Write-Host "  [$($r.Verdict)] $($r.TestId): expected=$($r.Expected), actual=$($r.Actual)"
}

# ============================================================================
# Generate test-report.md
# ============================================================================
$reportDir = $PSScriptRoot
$reportPath = Join-Path $reportDir "test-report.md"

$md = [System.Text.StringBuilder]::new()
[void]$md.AppendLine("# Production Validation v1.7 Final - Test Report (T11-T17)")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
[void]$md.AppendLine("**Script:** ``test.ps1``")
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

[void]$md.AppendLine("## Functions Under Test")
[void]$md.AppendLine("")
[void]$md.AppendLine("- ``ConvertTo-NormVer`` - Parses version strings into structured objects (Major/Minor/Patch/Pre/PreName/PreNum)")
[void]$md.AppendLine("- ``Compare-Ver`` - Compares two version strings, returns ``eq``/``lt``/``gt``/``incomparable``")
[void]$md.AppendLine("- ``Test-VersionJump`` - Detects suspiciously large version jumps (major>=2, minor>=10 same major, patch>=50 same major+minor)")
[void]$md.AppendLine("- ``Test-DateSuspicious`` - Detects when published date (UTC->Beijing) is earlier than previously known git date")
[void]$md.AppendLine("- ``Test-IsFlip`` - Detects when prevFlag was 'no' and new flag becomes 'yes' (localVer < latest)")
[void]$md.AppendLine("")

Set-Content -Path $reportPath -Value $md.ToString() -Encoding UTF8
Write-Host ""
Write-Host "Report saved to: $reportPath"

if ($script:AllPassed) {
    Write-Host ""
    Write-Host "ALL TESTS PASSED"
} else {
    Write-Host ""
    Write-Host "SOME TESTS FAILED - see report above"
}
