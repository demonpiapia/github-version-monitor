#Requires -Version 7.0
param()

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# =====================================================================
# mock-invoke-restmethod.ps1
# Purpose: mock Invoke-RestMethod / Invoke-WebRequest for T3 API-failure
#          harness.
#
# NOTE (Phase 4 mock fix, record P4-E):
#   The Phase 2 implementation used
#     New-Object System.Net.WebResponse
#     $response.StatusCode = 500
#   which silently produced StatusCode=null under .NET 8 / PS 7.6.4
#   (WebResponse's StatusCode setter is only overridden by concrete
#   subclasses). We now build a PSCustomObject mock response with an
#   explicit NoteProperty StatusCode + Headers property, which SKILL
#   step2.ps1 L116 reads via `$_.Exception.Response.StatusCode`. This
#   preserves the Phase 2 mock contract (scenario -> status code
#   classification) reliably.
# =====================================================================

function New-MockHttpResponse {
    param([int]$StatusCode, [string]$RateLimitRemaining)
    $headers = New-Object System.Net.WebHeaderCollection
    if ($RateLimitRemaining -ne $null -and $RateLimitRemaining -ne '') {
        try { $headers.Add('X-RateLimit-Remaining', $RateLimitRemaining) } catch {}
    }
    $response = [PSCustomObject]@{}
    $response | Add-Member -MemberType NoteProperty -Name StatusCode -Value ([System.Net.HttpStatusCode]$StatusCode) -Force
    $response | Add-Member -MemberType NoteProperty -Name Headers    -Value $headers -Force
    return $response
}

function New-MockHttpException {
    param([string]$Message, [int]$StatusCode, [string]$RateLimitRemaining)
    $response = $null
    if ($StatusCode -gt 0) {
        $response = New-MockHttpResponse $StatusCode $RateLimitRemaining
    }
    $exc = New-Object System.Exception($Message, $null)
    $exc | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force
    return $exc
}

function Mock-MakeSuccessObject {
    param([string]$Tag, [string]$PublishedAt)
    if (-not $Tag)         { $Tag = 'v1.0.0' }
    if (-not $PublishedAt) { $PublishedAt = '2026-01-15T12:00:00Z' }
    return [PSCustomObject]@{
        tag_name     = $Tag
        published_at = $PublishedAt
        prerelease   = $false
        draft        = $false
        name         = $Tag
    }
}

function Mock-MakeListObject {
    return @(
        [PSCustomObject]@{ tag_name='v1.0.0';     published_at='2026-01-15T12:00:00Z'; prerelease=$false; draft=$false }
        [PSCustomObject]@{ tag_name='v1.0.1-rc.1'; published_at='2026-02-01T09:30:00Z'; prerelease=$true;  draft=$false }
    )
}

# ---- Public mock functions ----------------------------------------------

function Invoke-RestMethod {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        $Headers,
        [int]$TimeoutSec = 30,
        $Body
    )

    $isList   = $Uri -match 'releases\?per_page='
    $isLatest = $Uri -match 'releases/latest'

    if ($isList) {
        $scenario = if ($env:MOCK_SCENARIO_LIST) { $env:MOCK_SCENARIO_LIST } else { 'list-success' }
        switch ($scenario) {
            'list-success' { return (Mock-MakeListObject) }
            'list-empty'   { return @() }
            'list-500'     { throw (New-MockHttpException "Mock list 500" 500 $null) }
            'list-429'     { throw (New-MockHttpException "Mock list 429" 429 '0') }
            'list-network' { throw (New-MockHttpException "Mock list network" 0 $null) }
            default        { Write-Output ("MOCK_UNKNOWN_SCENARIO_LIST: {0}" -f $scenario); return @() }
        }
    }

    if (-not $isLatest) {
        return (Mock-MakeSuccessObject)
    }

    $scenario = if ($env:MOCK_SCENARIO) { $env:MOCK_SCENARIO } else { 'success' }
    switch ($scenario) {
        'success' {
            return (Mock-MakeSuccessObject $env:MOCK_TAG $env:MOCK_PUBLISHED_AT)
        }
        'metadata_incomplete' {
            return [PSCustomObject]@{
                tag_name = 'v1.0.0'; published_at = $null; prerelease=$false; draft=$false
            }
        }
        'invalid_response' {
            return [PSCustomObject]@{ tag_name = ''; published_at = $null; prerelease=$false; draft=$false }
        }
        'not_found' {
            throw (New-MockHttpException "Not Found (mock 404)" 404 $null)
        }
        'auth_error' {
            throw (New-MockHttpException "Unauthorized (mock 401)" 401 $null)
        }
        'forbidden' {
            throw (New-MockHttpException "Forbidden (mock 403)" 403 '')
        }
        'rate_429' {
            throw (New-MockHttpException "Too Many Requests (mock 429)" 429 '0')
        }
        'rate_403_remaining_0' {
            throw (New-MockHttpException "Forbidden (mock 403 RL=0)" 403 '0')
        }
        'server_500' {
            throw (New-MockHttpException "Internal Server Error (mock 500)" 500 $null)
        }
        'server_503' {
            throw (New-MockHttpException "Service Unavailable (mock 503)" 503 $null)
        }
        'network' {
            $exc = New-Object System.Exception("Mock network failure (no Response property)")
            $exc | Add-Member -MemberType NoteProperty -Name Response -Value $null -Force
            throw $exc
        }
        default {
            Write-Output ("MOCK_UNKNOWN_SCENARIO: {0}" -f $scenario)
            return (Mock-MakeSuccessObject)
        }
    }
}

function Invoke-WebRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        $Headers,
        [int]$TimeoutSec = 30,
        [switch]$UseBasicParsing
    )

    $htmlBody = "<html><head><title>$($Uri) - Mock Release Page</title></head><body>mock</body></html>"
    return [PSCustomObject]@{
        StatusCode = 200
        Content    = $htmlBody
        Headers    = New-Object 'System.Collections.Generic.Dictionary[string,string]'
        RawContent = $htmlBody
    }
}

# ---- Self-check: emit contract summary for logging -----------------------
Write-Output "MOCK_INVOKE_RESTMETHOD_LOADED=YES"
Write-Output "MOCK_SCENARIO=${env:MOCK_SCENARIO:-<unset>}"
Write-Output "MOCK_SCENARIO_LIST=${env:MOCK_SCENARIO_LIST:-<unset>}"
Write-Output "MOCK_HTML_DECISION=200+fixed_html_body_with_title"
Write-Output "MOCK_HTTP_RESPONSE_CLASS=PSCustomObject with NoteProperty StatusCode + Headers"
