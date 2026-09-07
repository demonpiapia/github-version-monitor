# T02 — 404 / not_found
# Real API call to a non-existent repo
# Tests the state machine: 404 → not_found, gitVer="", gitDate="", flag=prevFlag, review=true

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

# --- Test fixture: a non-existent repo ---
$repo = 'octocat/this-repo-does-not-exist-99999'
$prevGitVer = 'v1.0.0'
$prevGitDate = '2026-01-15'
$localVer = 'v1.0.0'
$prevFlag = 'no'

# --- Build headers per SKILL-v1.7.md ---
$token = $env:GITHUB_TOKEN
$headers = @{
    'User-Agent'            = 'workbuddy-version-monitor'
    'Accept'                = 'application/vnd.github+json'
    'X-GitHub-Api-Version'  = '2026-03-10'
}
if ($token) { $headers['Authorization'] = "Bearer $token" }

Write-Output "=== T02 - 404 / not_found ==="
Write-Output "Repo: $repo (non-existent)"
Write-Output "PrevGitVer: $prevGitVer"
Write-Output "PrevGitDate: $prevGitDate"
Write-Output "LocalVer: $localVer"
Write-Output "PrevFlag: $prevFlag"
Write-Output "Token: $(if ($token) { 'set' } else { 'unset' })"
Write-Output ""

# --- State machine: API query ---
$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
$apiCallSucceeded = $false
$actualHttpCode = $null

try {
    Write-Output "[API CALL] GET https://api.github.com/repos/$repo/releases/latest"
    $j = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
    $apiCallSucceeded = $true
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
    Write-Output "[API ERROR] HTTP $code → status=$status, error=$err"
}

Write-Output ""
Write-Output "=== State Machine Output ==="
Write-Output "queryStatus: $status"
Write-Output "latest (tag_name): '$latest'"
Write-Output "publishedUtc: '$pubUtc'"
Write-Output "pubDate: '$pubDate'"
Write-Output "error: $err"
Write-Output "rateRemaining: '$rl'"
Write-Output "actualHttpCode: $actualHttpCode"
Write-Output ""

# --- Comparison + flip + review logic (from SKILL-v1.7.md Step 2) ---
$newGitVer = $prevGitVer; $newGitDate = $prevGitDate; $newFlag = $prevFlag
$isNew = $false; $isFlip = $false; $review = $false; $cmp = ''
$versionJump = $false; $dateSuspicious = $false; $reasons = @()

if ($status -eq 'ok' -and $latest) {
    $isNew = ($latest -ne $prevGitVer)
    if ($isNew) {
        $newGitVer = $latest
        $newGitDate = $pubDate
    }
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
} elseif ($status -eq 'not_found') {
    $newGitVer = ''; $newGitDate = ''; $newFlag = $prevFlag
    $review = $true; $reasons += 'not_found'
} else {
    $review = $true; $reasons += 'api_failure'
}

Write-Output "=== Comparison + Review Output ==="
Write-Output "gitVer (newGitVer): '$newGitVer'"
Write-Output "gitDate (newGitDate): '$newGitDate'"
Write-Output "flag (newFlag): '$newFlag'"
Write-Output "prevFlag: '$prevFlag'"
Write-Output "cmp: '$cmp'"
Write-Output "isNew: $isNew"
Write-Output "isFlip: $isFlip"
Write-Output "review: $review"
Write-Output "reviewReasons: $($reasons -join ', ')"
Write-Output ""

# --- Verification ---
Write-Output "=== Verification ==="
$pass = $true

$v1 = ($status -eq 'not_found')
Write-Output "queryStatus=not_found: $($v1) (actual: $status)"
if (-not $v1) { $pass = $false }

$v2 = ($newGitVer -eq '')
Write-Output "gitVer empty: $($v2) (actual: '$newGitVer')"
if (-not $v2) { $pass = $false }

$v3 = ($newGitDate -eq '')
Write-Output "gitDate empty: $($v3) (actual: '$newGitDate')"
if (-not $v3) { $pass = $false }

$v4 = ($newFlag -ceq $prevFlag)
Write-Output "flag preserved (==prevFlag): $($v4) (actual: '$newFlag' vs prevFlag '$prevFlag')"
if (-not $v4) { $pass = $false }

$v5 = ($review -eq $true)
Write-Output "review=true: $($v5) (actual: $review)"
if (-not $v5) { $pass = $false }

$v6 = ($reasons -contains 'not_found')
Write-Output "reviewReasons contains 'not_found': $($v6) (actual: $($reasons -join ', '))"
if (-not $v6) { $pass = $false }

# Error info NOT written into gitVer
$v7 = ($newGitVer -notmatch 'error|not_found|404|exception|message')
Write-Output "Error info NOT in gitVer: $($v7) (gitVer='$newGitVer')"
if (-not $v7) { $pass = $false }

# HTML result NOT used as API fact (no HTML fetch was attempted, latest stays empty)
$v8 = ($latest -eq '')
Write-Output "HTML result NOT used (latest stays empty): $($v8) (latest='$latest')"
if (-not $v8) { $pass = $false }

Write-Output ""
$verdict = if ($pass) { 'PASS' } else { 'FAIL' }
Write-Output "VERDICT: $verdict"
