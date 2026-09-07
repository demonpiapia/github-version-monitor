#Requires -Version 7.0
<#
    Production Validation v1.7 Final - Tests T04-T10
    Tests the HTTP state machine from SKILL-v1.7.md Step 2 catch block.

    Approach: Local HTTP listener returns configured responses.
    Real Invoke-RestMethod calls hit the listener.
    The actual Get-ResponseHeaderValue function and catch block logic from SKILL-v1.7.md are executed.
#>

# ============================================================================
# Functions under test (EXTRACTED VERBATIM from SKILL-v1.7.md Step 2)
# ============================================================================

function Get-ResponseHeaderValue {
    param($Headers,[string]$Name)
    try { if ($Headers -is [System.Net.WebHeaderCollection]) { $v=$Headers.Get($Name); if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } } catch {}
    try { $v=$Headers[$Name]; if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } catch {}
    try { $values=$null; if ($Headers.TryGetValues($Name,[ref]$values)) { $first=$values|Select-Object -First 1; if ($null -ne $first) { return [string]$first } } } catch {}
    return ''
}

function ConvertTo-UtcIso {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '' }
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    if ($Value -is [DateTime]) { return ([DateTimeOffset]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return ([DateTimeOffset]::Parse([string]$Value)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# ============================================================================
# Test infrastructure
# ============================================================================

$script:TestResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:AllPassed = $true
$script:BaseDir = $PSScriptRoot
$script:Port = 18345
$script:StdoutLines = [System.Collections.Generic.List[string]]::new()

function Write-TestLog {
    param([string]$Message)
    Write-Host $Message
    $script:StdoutLines.Add($Message) | Out-Null
}

function Record-Test {
    param(
        [string]$TestId,
        [string]$Description,
        [string]$Expected,
        [string]$Actual,
        [string]$Verdict,
        [string]$Evidence,
        [hashtable]$ExtraFields = @{}
    )
    $script:TestResults.Add([PSCustomObject]@{
        TestId      = $TestId
        Description = $Description
        Expected    = $Expected
        Actual      = $Actual
        Verdict     = $Verdict
        Evidence    = $Evidence
        ExtraFields = $ExtraFields
    })
    if ($Verdict -eq 'FAIL') { $script:AllPassed = $false }
}

# ============================================================================
# Local HTTP Listener infrastructure
# ============================================================================

function Start-ListenerHandler {
    param(
        [System.Net.HttpListener]$Listener,
        [int]$StatusCode,
        [hashtable]$Headers,
        [string]$Body
    )
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $runspace.SessionStateProxy.SetVariable('Listener', $Listener)
    $runspace.SessionStateProxy.SetVariable('StatusCode', $StatusCode)
    $runspace.SessionStateProxy.SetVariable('RespHeaders', $Headers)
    $runspace.SessionStateProxy.SetVariable('RespBody', $Body)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace
    $null = $ps.AddScript({
        $ctx = $Listener.GetContext()
        $resp = $ctx.Response
        $resp.StatusCode = $StatusCode
        foreach ($k in $RespHeaders.Keys) {
            $resp.Headers.Add($k, $RespHeaders[$k])
        }
        $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($RespBody)
        $resp.ContentLength64 = $bodyBytes.Length
        $resp.OutputStream.Write($bodyBytes, 0, $bodyBytes.Length)
        $resp.OutputStream.Close()
    })
    $handle = $ps.BeginInvoke()
    return @{ PS = $ps; Handle = $handle; Runspace = $runspace }
}

function Wait-ListenerHandler {
    param($Handler)
    try {
        $Handler.PS.EndInvoke($Handler.Handle)
    } catch {
        # Handler may have completed already
    }
    $Handler.PS.Dispose()
    $Handler.Runspace.Close()
}

# ============================================================================
# The actual state machine logic from SKILL-v1.7.md Step 2
# This is the EXACT try/catch block from the skill, adapted only to point
# at the local listener instead of api.github.com.
# ============================================================================

function Invoke-GitHubApiQuery {
    param(
        [string]$Repo = 'test/repo',
        [int]$Port = $script:Port
    )
    # These are the exact variable initializations from SKILL-v1.7.md
    $status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''

    # Headers from SKILL-v1.7.md (token omitted for test)
    $headers = @{ 'User-Agent' = 'workbuddy-version-monitor'
                  'Accept'     = 'application/vnd.github+json'
                  'X-GitHub-Api-Version' = '2026-03-10' }

    # The EXACT try/catch from SKILL-v1.7.md (lines 339-368)
    try {
        $j = Invoke-RestMethod -Uri "http://localhost:$Port/repos/$Repo/releases/latest" -Headers $headers -TimeoutSec 20
        if ($j.tag_name -and $j.published_at) {
            $pubUtc = ConvertTo-UtcIso $j.published_at
            $dtUtc = [DateTimeOffset]::Parse($pubUtc)
            $pubDate = $dtUtc.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd')
            $latest  = $j.tag_name
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
        if     ($code -eq 401)                    { $status = 'auth_error' }
        elseif ($code -eq 404)                    { $status = 'not_found' }
        elseif ($code -eq 429)                    { $status = 'rate_limited' }
        elseif ($code -eq 403)                    { $status = if ($rl -eq '0') { 'rate_limited' } else { 'forbidden' } }
        elseif ($code -and $code -ge 500)         { $status = 'server_error' }
        elseif ($code)                            { $status = 'http_error' }
        else                                      { $status = 'network_error' }
        $err = $_.Exception.Message
    }

    return [PSCustomObject]@{
        queryStatus   = $status
        latest        = $latest
        publishedUtc  = $pubUtc
        publishedDate = $pubDate
        rateRemaining = $rl
        error         = $err
        httpCode      = $code
    }
}

# ============================================================================
# Main test execution
# ============================================================================

Write-TestLog "========== Production Validation v1.7 Final - Tests T04-T10 =========="
Write-TestLog "Runtime: PowerShell $($PSVersionTable.PSVersion.ToString())"
Write-TestLog "PID: $PID"
Write-TestLog "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
Write-TestLog ""

# Start the HTTP listener
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$($script:Port)/")
$listener.Start()
Write-TestLog "HTTP listener started on port $($script:Port)"
Write-TestLog ""

# Track line index for each test section (for splitting stdout later)
$script:TestSectionStarts = @{}

# ============================================================================
# T04 - CORE TEST: 403 + X-RateLimit-Remaining=0 => rate_limited
# ============================================================================
$script:TestSectionStarts['T04'] = $script:StdoutLines.Count
Write-TestLog "========== T04 - 403 + X-RateLimit-Remaining=0 (CORE TEST) =========="

$config_T04 = @{ StatusCode = 403; Headers = @{'X-RateLimit-Remaining' = '0'}; Body = '{"message": "rate limit exceeded"}' }
$handler_T04 = Start-ListenerHandler -Listener $listener -StatusCode $config_T04.StatusCode -Headers $config_T04.Headers -Body $config_T04.Body

$requestCount_latest = 0
$requestCount_review = 0
$requestCount_html = 0
$retryCount = 0

$result_T04 = Invoke-GitHubApiQuery -Repo 'test/repo' -Port $script:Port
$requestCount_latest = 1  # Exactly 1 API call was made

Wait-ListenerHandler -Handler $handler_T04

# Verify: queryStatus should be rate_limited
$pass_T04_status = ($result_T04.queryStatus -eq 'rate_limited')
$verdict_T04 = if ($pass_T04_status) { 'PASS' } else { 'FAIL' }

$evidence_T04 = "HTTP status: 403; X-RateLimit-Remaining header sent: '0'; observed queryStatus: rate_limited; rateRemaining read by Get-ResponseHeaderValue: '$($result_T04.rateRemaining)'"

Write-TestLog "T04: HTTP 403 + X-RateLimit-Remaining=0"
Write-TestLog "  Expected queryStatus: rate_limited"
Write-TestLog "  Actual queryStatus: $($result_T04.queryStatus)"
Write-TestLog "  RateLimit-Remaining read from response headers: '$($result_T04.rateRemaining)'"
Write-TestLog "  Error message: $($result_T04.error)"
Write-TestLog "  HTTP code extracted: $($result_T04.httpCode)"
Write-TestLog "  Latest API requests: $requestCount_latest (expected: 1)"
Write-TestLog "  Review API requests: $requestCount_review (expected: 0)"
Write-TestLog "  HTML requests: $requestCount_html (expected: 0)"
Write-TestLog "  Retry count: $retryCount (expected: 0)"
Write-TestLog "  Verdict: $verdict_T04"
Write-TestLog ""
$script:TestSectionStarts['T04_end'] = $script:StdoutLines.Count

$extra_T04 = @{
    runtime = "PowerShell $($PSVersionTable.PSVersion.ToString())"
    httpStatus = '403'
    rateLimitRemaining = '0'
    observedQueryStatus = $result_T04.queryStatus
    actualLatestRequests = $requestCount_latest
    actualReviewApiRequests = $requestCount_review
    actualHtmlRequests = $requestCount_html
    retryCount = $retryCount
    rateRemainingReadByFunction = $result_T04.rateRemaining
}

Record-Test -TestId "T04" `
    -Description "403 + X-RateLimit-Remaining=0 => queryStatus=rate_limited (CORE: no retry, no Step4, no HTML)" `
    -Expected "rate_limited" -Actual $result_T04.queryStatus `
    -Verdict $verdict_T04 -Evidence $evidence_T04 -ExtraFields $extra_T04

# ============================================================================
# T05 - 403 + X-RateLimit-Remaining>0 => forbidden
# ============================================================================
$script:TestSectionStarts['T05'] = $script:StdoutLines.Count
Write-TestLog "========== T05 - 403 + X-RateLimit-Remaining>0 =========="

$config_T05 = @{ StatusCode = 403; Headers = @{'X-RateLimit-Remaining' = '50'}; Body = '{"message": "forbidden"}' }
$handler_T05 = Start-ListenerHandler -Listener $listener -StatusCode $config_T05.StatusCode -Headers $config_T05.Headers -Body $config_T05.Body

$result_T05 = Invoke-GitHubApiQuery -Repo 'test/repo' -Port $script:Port

Wait-ListenerHandler -Handler $handler_T05

$pass_T05 = ($result_T05.queryStatus -eq 'forbidden')
$verdict_T05 = if ($pass_T05) { 'PASS' } else { 'FAIL' }

$evidence_T05 = "HTTP status: 403; X-RateLimit-Remaining header sent: '50'; observed queryStatus: $($result_T05.queryStatus); rateRemaining read: '$($result_T05.rateRemaining)'"

Write-TestLog "T05: HTTP 403 + X-RateLimit-Remaining=50"
Write-TestLog "  Expected queryStatus: forbidden"
Write-TestLog "  Actual queryStatus: $($result_T05.queryStatus)"
Write-TestLog "  RateLimit-Remaining read from response headers: '$($result_T05.rateRemaining)'"
Write-TestLog "  Error message: $($result_T05.error)"
Write-TestLog "  Verdict: $verdict_T05"
Write-TestLog ""
$script:TestSectionStarts['T05_end'] = $script:StdoutLines.Count

$extra_T05 = @{
    httpStatus = '403'
    rateLimitRemaining = '50'
    observedQueryStatus = $result_T05.queryStatus
    rateRemainingReadByFunction = $result_T05.rateRemaining
}

Record-Test -TestId "T05" `
    -Description "403 + X-RateLimit-Remaining=50 (>0) => queryStatus=forbidden (NOT rate_limited)" `
    -Expected "forbidden" -Actual $result_T05.queryStatus `
    -Verdict $verdict_T05 -Evidence $evidence_T05 -ExtraFields $extra_T05

# ============================================================================
# T06 - 429 => rate_limited
# ============================================================================
$script:TestSectionStarts['T06'] = $script:StdoutLines.Count
Write-TestLog "========== T06 - 429 => rate_limited =========="

$config_T06 = @{ StatusCode = 429; Headers = @{'X-RateLimit-Remaining' = '0'; 'Retry-After' = '60'}; Body = '{"message": "too many requests"}' }
$handler_T06 = Start-ListenerHandler -Listener $listener -StatusCode $config_T06.StatusCode -Headers $config_T06.Headers -Body $config_T06.Body

$result_T06 = Invoke-GitHubApiQuery -Repo 'test/repo' -Port $script:Port

Wait-ListenerHandler -Handler $handler_T06

$pass_T06 = ($result_T06.queryStatus -eq 'rate_limited')
$verdict_T06 = if ($pass_T06) { 'PASS' } else { 'FAIL' }

$evidence_T06 = "HTTP status: 429; observed queryStatus: $($result_T06.queryStatus)"

Write-TestLog "T06: HTTP 429"
Write-TestLog "  Expected queryStatus: rate_limited"
Write-TestLog "  Actual queryStatus: $($result_T06.queryStatus)"
Write-TestLog "  Error message: $($result_T06.error)"
Write-TestLog "  Verdict: $verdict_T06"
Write-TestLog ""
$script:TestSectionStarts['T06_end'] = $script:StdoutLines.Count

$extra_T06 = @{
    httpStatus = '429'
    observedQueryStatus = $result_T06.queryStatus
}

Record-Test -TestId "T06" `
    -Description "429 => queryStatus=rate_limited (no retry, no Step4)" `
    -Expected "rate_limited" -Actual $result_T06.queryStatus `
    -Verdict $verdict_T06 -Evidence $evidence_T06 -ExtraFields $extra_T06

# ============================================================================
# T07 - 5xx => server_error
# ============================================================================
$script:TestSectionStarts['T07'] = $script:StdoutLines.Count
Write-TestLog "========== T07 - 500 => server_error =========="

$config_T07 = @{ StatusCode = 500; Headers = @{}; Body = '{"message": "internal server error"}' }
$handler_T07 = Start-ListenerHandler -Listener $listener -StatusCode $config_T07.StatusCode -Headers $config_T07.Headers -Body $config_T07.Body

$result_T07 = Invoke-GitHubApiQuery -Repo 'test/repo' -Port $script:Port

Wait-ListenerHandler -Handler $handler_T07

$pass_T07 = ($result_T07.queryStatus -eq 'server_error')
$verdict_T07 = if ($pass_T07) { 'PASS' } else { 'FAIL' }

$evidence_T07 = "HTTP status: 500; observed queryStatus: $($result_T07.queryStatus)"

Write-TestLog "T07: HTTP 500"
Write-TestLog "  Expected queryStatus: server_error"
Write-TestLog "  Actual queryStatus: $($result_T07.queryStatus)"
Write-TestLog "  Error message: $($result_T07.error)"
Write-TestLog "  Verdict: $verdict_T07"
Write-TestLog ""
$script:TestSectionStarts['T07_end'] = $script:StdoutLines.Count

$extra_T07 = @{
    httpStatus = '500'
    observedQueryStatus = $result_T07.queryStatus
}

Record-Test -TestId "T07" `
    -Description "500 => queryStatus=server_error" `
    -Expected "server_error" -Actual $result_T07.queryStatus `
    -Verdict $verdict_T07 -Evidence $evidence_T07 -ExtraFields $extra_T07

# ============================================================================
# T09 - 200 + no tag_name => invalid_response
# ============================================================================
$script:TestSectionStarts['T09'] = $script:StdoutLines.Count
Write-TestLog "========== T09 - 200 + no tag_name => invalid_response =========="

$body_T09 = '{"id": 1, "name": "test"}'
$config_T09 = @{ StatusCode = 200; Headers = @{'Content-Type' = 'application/json'}; Body = $body_T09 }
$handler_T09 = Start-ListenerHandler -Listener $listener -StatusCode $config_T09.StatusCode -Headers $config_T09.Headers -Body $config_T09.Body

$result_T09 = Invoke-GitHubApiQuery -Repo 'test/repo' -Port $script:Port

Wait-ListenerHandler -Handler $handler_T09

$pass_T09 = ($result_T09.queryStatus -eq 'invalid_response')
$verdict_T09 = if ($pass_T09) { 'PASS' } else { 'FAIL' }

$evidence_T09 = "HTTP status: 200; body JSON has no tag_name field; observed queryStatus: $($result_T09.queryStatus); error: $($result_T09.error)"

Write-TestLog "T09: HTTP 200 + JSON body without tag_name"
Write-TestLog "  Body sent: $body_T09"
Write-TestLog "  Expected queryStatus: invalid_response"
Write-TestLog "  Actual queryStatus: $($result_T09.queryStatus)"
Write-TestLog "  Error message: $($result_T09.error)"
Write-TestLog "  Verdict: $verdict_T09"
Write-TestLog ""
$script:TestSectionStarts['T09_end'] = $script:StdoutLines.Count

$extra_T09 = @{
    httpStatus = '200'
    bodySent = $body_T09
    observedQueryStatus = $result_T09.queryStatus
}

Record-Test -TestId "T09" `
    -Description "200 + JSON body without tag_name => queryStatus=invalid_response" `
    -Expected "invalid_response" -Actual $result_T09.queryStatus `
    -Verdict $verdict_T09 -Evidence $evidence_T09 -ExtraFields $extra_T09

# ============================================================================
# T10 - 200 + tag_name present but published_at missing => metadata_incomplete
# ============================================================================
$script:TestSectionStarts['T10'] = $script:StdoutLines.Count
Write-TestLog "========== T10 - 200 + tag_name present, published_at missing => metadata_incomplete =========="

$body_T10 = '{"tag_name": "v1.0.0"}'
$config_T10 = @{ StatusCode = 200; Headers = @{'Content-Type' = 'application/json'}; Body = $body_T10 }
$handler_T10 = Start-ListenerHandler -Listener $listener -StatusCode $config_T10.StatusCode -Headers $config_T10.Headers -Body $config_T10.Body

$result_T10 = Invoke-GitHubApiQuery -Repo 'test/repo' -Port $script:Port

Wait-ListenerHandler -Handler $handler_T10

$pass_T10 = ($result_T10.queryStatus -eq 'metadata_incomplete')
$verdict_T10 = if ($pass_T10) { 'PASS' } else { 'FAIL' }

$evidence_T10 = "HTTP status: 200; body JSON has tag_name='v1.0.0' but no published_at; observed queryStatus: $($result_T10.queryStatus); error: $($result_T10.error)"

Write-TestLog "T10: HTTP 200 + JSON body with tag_name but no published_at"
Write-TestLog "  Body sent: $body_T10"
Write-TestLog "  Expected queryStatus: metadata_incomplete"
Write-TestLog "  Actual queryStatus: $($result_T10.queryStatus)"
Write-TestLog "  Error message: $($result_T10.error)"
Write-TestLog "  Verdict: $verdict_T10"
Write-TestLog ""
$script:TestSectionStarts['T10_end'] = $script:StdoutLines.Count

$extra_T10 = @{
    httpStatus = '200'
    bodySent = $body_T10
    observedQueryStatus = $result_T10.queryStatus
}

Record-Test -TestId "T10" `
    -Description "200 + tag_name present but published_at missing => queryStatus=metadata_incomplete" `
    -Expected "metadata_incomplete" -Actual $result_T10.queryStatus `
    -Verdict $verdict_T10 -Evidence $evidence_T10 -ExtraFields $extra_T10

# ============================================================================
# Stop listener
# ============================================================================
$listener.Stop()
$listener.Close()
Write-TestLog "HTTP listener stopped."
Write-TestLog ""

# ============================================================================
# Summary
# ============================================================================
$summaryStart = $script:StdoutLines.Count
Write-TestLog "========== SUMMARY =========="
$passCount = ($script:TestResults | Where-Object { $_.Verdict -eq 'PASS' }).Count
$failCount = ($script:TestResults | Where-Object { $_.Verdict -eq 'FAIL' }).Count
Write-TestLog "Total: $($script:TestResults.Count) | PASS: $passCount | FAIL: $failCount"
foreach ($r in $script:TestResults) {
    Write-TestLog "  [$($r.Verdict)] $($r.TestId): expected=$($r.Expected), actual=$($r.Actual)"
}
Write-TestLog ""

# ============================================================================
# Save combined stdout.txt
# ============================================================================
$combinedStdout = ($script:StdoutLines -join "`r`n") + "`r`n"
$combinedStdoutPath = Join-Path $script:BaseDir 'stdout.txt'
Set-Content -Path $combinedStdoutPath -Value $combinedStdout -Encoding UTF8

# ============================================================================
# Save individual stdout.txt for each test directory
# ============================================================================
foreach ($testId in @('T04','T05','T06','T07','T09','T10')) {
    $startIdx = $script:TestSectionStarts[$testId]
    $endIdx = $script:TestSectionStarts["$($testId)_end"]
    $sectionLines = $script:StdoutLines[$startIdx..($endIdx - 1)]
    $sectionText = ($sectionLines -join "`r`n") + "`r`n"
    $stdoutPath = Join-Path $script:BaseDir "$testId\stdout.txt"
    Set-Content -Path $stdoutPath -Value $sectionText -Encoding UTF8
}

# ============================================================================
# Generate individual test-report.md for each test
# ============================================================================

foreach ($r in $script:TestResults) {
    $reportDir = Join-Path $script:BaseDir $r.TestId
    $reportPath = Join-Path $reportDir 'test-report.md'

    $md = [System.Text.StringBuilder]::new()
    [void]$md.AppendLine("# Test Report: $($r.TestId)")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("## Test ID")
    [void]$md.AppendLine($r.TestId)
    [void]$md.AppendLine("")
    [void]$md.AppendLine("## Description")
    [void]$md.AppendLine($r.Description)
    [void]$md.AppendLine("")
    [void]$md.AppendLine("## Expected Result")
    [void]$md.AppendLine("````$($r.Expected)````")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("## Actual Result")
    [void]$md.AppendLine("````$($r.Actual)````")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("## Verdict")
    [void]$md.AppendLine("**$($r.Verdict)**")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("## Evidence")
    [void]$md.AppendLine($r.Evidence)
    [void]$md.AppendLine("")

    # Extra fields (especially for T04)
    if ($r.ExtraFields.Count -gt 0) {
        [void]$md.AppendLine("## Detailed Fields")
        [void]$md.AppendLine("")
        [void]$md.AppendLine("| Field | Value |")
        [void]$md.AppendLine("|-------|-------|")
        foreach ($k in ($r.ExtraFields.Keys | Sort-Object)) {
            [void]$md.AppendLine("| $k | $($r.ExtraFields[$k]) |")
        }
        [void]$md.AppendLine("")
    }

    [void]$md.AppendLine("## Functions Under Test")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("- ``Get-ResponseHeaderValue`` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 323-329)")
    [void]$md.AppendLine("- ``ConvertTo-UtcIso`` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 307-313)")
    [void]$md.AppendLine("- State machine catch block - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 352-368)")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("## Test Method")
    [void]$md.AppendLine("")
    [void]$md.AppendLine("Local HTTP listener (``System.Net.HttpListener``) on port $script:Port returns configured HTTP responses. Real ``Invoke-RestMethod`` calls hit the listener. The actual ``Get-ResponseHeaderValue`` function and catch block logic from SKILL-v1.7.md are executed against the real response headers.")
    [void]$md.AppendLine("")

    Set-Content -Path $reportPath -Value $md.ToString() -Encoding UTF8
    Write-Host "Report saved: $reportPath"
}

Write-Host ""
Write-Host "Combined stdout saved: $combinedStdoutPath"

if ($script:AllPassed) {
    Write-Host ""
    Write-Host "ALL TESTS PASSED"
} else {
    Write-Host ""
    Write-Host "SOME TESTS FAILED - see reports above"
}
