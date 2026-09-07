# T08 — network_error
# Real network error via proxy to closed port + short timeout
# Tests the state machine: no HTTP response → network_error, state preserved, review=true

$ErrorActionPreference = 'Stop'

# --- Helper functions extracted from SKILL-v1.7.md Step 2 ---

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

# --- Save original proxy env vars for restoration ---
$origHttpsProxy = $env:HTTPS_PROXY
$origHttpProxy = $env:HTTP_PROXY
$origAllProxy = $env:ALL_PROXY

Write-Output "=== T08 - network_error ==="
Write-Output "Original HTTPS_PROXY: $(if ($origHttpsProxy) { $origHttpsProxy } else { 'unset' })"
Write-Output "Original HTTP_PROXY: $(if ($origHttpProxy) { $origHttpProxy } else { 'unset' })"
Write-Output ""

# --- Test fixture ---
$repo = 'octocat/Hello-World'
$prevGitVer = 'v1.8.0'
$prevGitDate = '2026-06-10'
$localVer = 'v1.8.0'
$prevFlag = 'no'

# --- Approach 1: Set proxy to closed port (connection refused) ---
# Port 1 should be closed on any system = connection refused
$env:HTTPS_PROXY = 'http://127.0.0.1:1'
$env:HTTP_PROXY = 'http://127.0.0.1:1'
Write-Output "Set HTTPS_PROXY=http://127.0.0.1:1 (port 1 should be closed = connection refused)"
Write-Output "Repo: $repo"
Write-Output "PrevGitVer: $prevGitVer"
Write-Output "PrevGitDate: $prevGitDate"
Write-Output "LocalVer: $localVer"
Write-Output "PrevFlag: $prevFlag"
Write-Output "Token: $(if ($env:GITHUB_TOKEN) { 'set' } else { 'unset' })"
Write-Output ""

# --- Build headers per SKILL-v1.7.md ---
$token = $env:GITHUB_TOKEN
$headers = @{
    'User-Agent'            = 'workbuddy-version-monitor'
    'Accept'                = 'application/vnd.github+json'
    'X-GitHub-Api-Version'  = '2026-03-10'
}
if ($token) { $headers['Authorization'] = "Bearer $token" }

# --- State machine: API query ---
# Using -TimeoutSec 1 as secondary evidence (very short timeout)
$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
$actualHttpCode = $null
$errorType = ''

try {
    Write-Output "[API CALL] GET https://api.github.com/repos/$repo/releases/latest (proxy=127.0.0.1:1, timeout=1s)"
    $j = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 1
    Write-Output "[API RESPONSE] (unexpected 200) tag_name=$($j.tag_name)"
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
    try { if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $code = [int]$_.Exception.Response.StatusCode; $actualHttpCode = $code } } catch {}
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
    # Capture error type for evidence
    if ($_.Exception -is [System.Net.Http.HttpRequestException]) { $errorType = 'HttpRequestException' }
    elseif ($_.Exception -is [System.Net.WebException]) { $errorType = 'WebException' }
    elseif ($_.Exception -is [System.OperationCanceledException]) { $errorType = 'OperationCanceledException (timeout)' }
    else { $errorType = $_.Exception.GetType().Name }
    Write-Output "[API ERROR] HTTP code=$code → status=$status"
    Write-Output "[ERROR TYPE] $errorType"
    Write-Output "[ERROR MESSAGE] $err"
}

Write-Output ""
Write-Output "=== State Machine Output ==="
Write-Output "queryStatus: $status"
Write-Output "latest (tag_name): '$latest'"
Write-Output "publishedUtc: '$pubUtc'"
Write-Output "error: $err"
Write-Output "rateRemaining: '$rl'"
Write-Output "actualHttpCode: $actualHttpCode"
Write-Output "errorType: $errorType"
Write-Output ""

# --- Comparison + flip + review logic ---
$newGitVer = $prevGitVer; $newGitDate = $prevGitDate; $newFlag = $prevFlag
$isNew = $false; $isFlip = $false; $review = $false; $cmp = ''
$versionJump = $false; $dateSuspicious = $false; $reasons = @()

if ($status -eq 'ok' -and $latest) {
    $isNew = ($latest -ne $prevGitVer)
    if ($isNew) { $newGitVer = $latest; $newGitDate = $pubDate }
    if ($localVer -match '未安装') { $newFlag = 'no' }
    else {
        $cmp = Compare-Ver $localVer $latest
        switch ($cmp) { 'lt' { $newFlag = 'yes' }; 'eq' { $newFlag = 'no' }; default { $newFlag = $prevFlag; $review = $true; $reasons += 'incomparable_version' } }
    }
    if ($prevFlag -ceq 'no' -and $newFlag -ceq 'yes') { $isFlip = $true }
} elseif ($status -eq 'not_found') {
    $newGitVer = ''; $newGitDate = ''; $newFlag = $prevFlag; $review = $true; $reasons += 'not_found'
} else {
    $review = $true; $reasons += 'api_failure'
}

Write-Output "=== Comparison + Review Output ==="
Write-Output "gitVer (newGitVer): '$newGitVer'"
Write-Output "gitDate (newGitDate): '$newGitDate'"
Write-Output "flag (newFlag): '$newFlag'"
Write-Output "prevFlag: '$prevFlag'"
Write-Output "review: $review"
Write-Output "reviewReasons: $($reasons -join ', ')"
Write-Output ""

# --- Verification ---
Write-Output "=== Verification ==="
$pass = $true

$v1 = ($status -eq 'network_error')
Write-Output "queryStatus=network_error: $($v1) (actual: $status)"
if (-not $v1) { $pass = $false }

$v2 = ($newGitVer -ceq $prevGitVer)
Write-Output "gitVer preserved: $($v2) (actual: '$newGitVer' vs prev '$prevGitVer')"
if (-not $v2) { $pass = $false }

$v3 = ($newGitDate -ceq $prevGitDate)
Write-Output "gitDate preserved: $($v3) (actual: '$newGitDate' vs prev '$prevGitDate')"
if (-not $v3) { $pass = $false }

$v4 = ($newFlag -ceq $prevFlag)
Write-Output "flag preserved: $($v4) (actual: '$newFlag' vs prev '$prevFlag')"
if (-not $v4) { $pass = $false }

$v5 = ($review -eq $true)
Write-Output "review=true: $($v5) (actual: $review)"
if (-not $v5) { $pass = $false }

# Evidence that no HTTP response was received
$v6 = ($null -eq $actualHttpCode)
Write-Output "No HTTP response code (network-level failure): $($v6) (actualHttpCode: $actualHttpCode)"
if (-not $v6) { $pass = $false }

Write-Output ""
$verdict = if ($pass) { 'PASS' } else { 'FAIL' }
Write-Output "VERDICT: $verdict"

# --- Restore original proxy env vars ---
Write-Output ""
Write-Output "=== Restoring original proxy env vars ==="
if ($origHttpsProxy) { $env:HTTPS_PROXY = $origHttpsProxy; Write-Output "HTTPS_PROXY restored" }
else { $env:HTTPS_PROXY = $null; Remove-Item Env:\HTTPS_PROXY -ErrorAction SilentlyContinue; Write-Output "HTTPS_PROXY cleared (was unset)" }
if ($origHttpProxy) { $env:HTTP_PROXY = $origHttpProxy; Write-Output "HTTP_PROXY restored" }
else { $env:HTTP_PROXY = $null; Remove-Item Env:\HTTP_PROXY -ErrorAction SilentlyContinue; Write-Output "HTTP_PROXY cleared (was unset)" }
