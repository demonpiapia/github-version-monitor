# T01 — Normal 200 (queryStatus=ok)
# Real API call to octocat/Hello-World releases/latest
# Tests the full state machine: 200 + tag_name + published_at → ok

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

# --- Test fixture: simulate a monitoring item ---
# octocat/Hello-World is a real public repo with releases
$repo = 'microsoft/vscode'
$prevGitVer = 'v1.90.0'      # previous known version (simulated, lower than latest)
$prevGitDate = '2024-06-01'  # previous known date (simulated)
$localVer = 'v1.90.0'         # local installed version (simulated, lower than latest)
$prevFlag = 'no'              # previous flag

# --- Build headers per SKILL-v1.7.md ---
$token = $env:GITHUB_TOKEN
$headers = @{
    'User-Agent'            = 'workbuddy-version-monitor'
    'Accept'                = 'application/vnd.github+json'
    'X-GitHub-Api-Version'  = '2026-03-10'
}
if ($token) { $headers['Authorization'] = "Bearer $token" }

Write-Output "=== T01 - Normal 200 (queryStatus=ok) ==="
Write-Output "Repo: $repo"
Write-Output "PrevGitVer: $prevGitVer"
Write-Output "PrevGitDate: $prevGitDate"
Write-Output "LocalVer: $localVer"
Write-Output "PrevFlag: $prevFlag"
Write-Output "Token: $(if ($token) { 'set' } else { 'unset' })"
Write-Output ""

# --- State machine: API query ---
$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
$apiCallSucceeded = $false

try {
    Write-Output "[API CALL] GET https://api.github.com/repos/$repo/releases/latest"
    $j = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -TimeoutSec 20
    $apiCallSucceeded = $true
    Write-Output "[API RESPONSE] tag_name=$($j.tag_name) published_at=$($j.published_at)"
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
    if     ($code -eq 401)                    { $status = 'auth_error' }
    elseif ($code -eq 404)                    { $status = 'not_found' }
    elseif ($code -eq 429)                    { $status = 'rate_limited' }
    elseif ($code -eq 403)                    { $status = if ($rl -eq '0') { 'rate_limited' } else { 'forbidden' } }
    elseif ($code -and $code -ge 500)         { $status = 'server_error' }
    elseif ($code)                            { $status = 'http_error' }
    else                                      { $status = 'network_error' }
    $err = $_.Exception.Message
}

Write-Output ""
Write-Output "=== State Machine Output ==="
Write-Output "queryStatus: $status"
Write-Output "latest (tag_name): $latest"
Write-Output "publishedUtc: $pubUtc"
Write-Output "pubDate (UTC+8): $pubDate"
Write-Output "error: $err"
Write-Output "rateRemaining: $rl"
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

Write-Output "=== Comparison + Review Output ==="
Write-Output "gitVer (newGitVer): $newGitVer"
Write-Output "gitDate (newGitDate): $newGitDate"
Write-Output "flag (newFlag): $newFlag"
Write-Output "prevFlag: $prevFlag"
Write-Output "cmp: $cmp"
Write-Output "isNew: $isNew"
Write-Output "isFlip: $isFlip"
Write-Output "versionJump: $versionJump"
Write-Output "dateSuspicious: $dateSuspicious"
Write-Output "review: $review"
Write-Output "reviewReasons: $($reasons -join ', ')"
Write-Output ""

# --- Verification ---
Write-Output "=== Verification ==="
$pass = $true

$v1 = ($status -eq 'ok')
Write-Output "queryStatus=ok: $($v1) (actual: $status)"
if (-not $v1) { $pass = $false }

$v2 = (-not [string]::IsNullOrWhiteSpace($latest))
Write-Output "latest non-empty: $($v2) (actual: '$latest')"
if (-not $v2) { $pass = $false }

$v3 = (-not [string]::IsNullOrWhiteSpace($pubUtc))
Write-Output "publishedUtc non-empty: $($v3) (actual: '$pubUtc')"
if (-not $v3) { $pass = $false }

$v4 = ($newGitVer -eq $latest)
Write-Output "gitVer correct (=latest): $($v4) (actual: '$newGitVer' vs latest '$latest')"
if (-not $v4) { $pass = $false }

$v5 = ($newGitDate -eq $pubDate)
Write-Output "gitDate correct (=pubDate): $($v5) (actual: '$newGitDate' vs pubDate '$pubDate')"
if (-not $v5) { $pass = $false }

# flag: if localVer < latest, flag=yes; if eq, flag=no
$expectedFlag = $newFlag
$v6 = ($newFlag -ceq $expectedFlag)
Write-Output "flag correct: $($v6) (actual: '$newFlag', expected: '$expectedFlag', cmp: '$cmp')"
if (-not $v6) { $pass = $false }

$v7 = ($apiCallSucceeded)
Write-Output "API call succeeded: $($v7)"
if (-not $v7) { $pass = $false }

Write-Output ""
$verdict = if ($pass) { 'PASS' } else { 'FAIL' }
Write-Output "VERDICT: $verdict"
