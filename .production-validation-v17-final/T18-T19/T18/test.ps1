#Requires -Version 7.0
<#
    T18 - State Preservation Test
    Verifies that for each error queryStatus (auth_error, forbidden, rate_limited,
    server_error, network_error, http_error), gitVer/gitDate/flag are preserved
    from previous values.

    For not_found specifically: gitVer="" (cleared), gitDate="" (cleared),
    flag=prevFlag (preserved).

    Uses a local HTTP listener (System.Net.HttpListener) to produce controlled
    responses. Makes real Invoke-RestMethod calls to the listener and executes
    the actual catch block logic from SKILL-v1.7.md Step 2.
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
# HTTP Listener infrastructure
# ============================================================================

$port = 8765
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Log "HTTP listener started on http://localhost:$port/"

function Start-ListenerHandler {
    param(
        [System.Net.HttpListener]$Listener,
        [int]$StatusCode,
        [hashtable]$RespHeaders,
        [string]$Body = ''
    )

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable('_Listener', $Listener)
    $rs.SessionStateProxy.SetVariable('_StatusCode', $StatusCode)
    $rs.SessionStateProxy.SetVariable('_RespHeaders', $RespHeaders)
    $rs.SessionStateProxy.SetVariable('_Body', $Body)

    $ps = [PowerShell]::Create()
    $ps.Runspace = $rs
    $null = $ps.AddScript({
        try {
            $ctx = $_Listener.GetContext()
            $ctx.Response.StatusCode = $_StatusCode
            if ($_RespHeaders -and $_RespHeaders.Count -gt 0) {
                foreach ($k in $_RespHeaders.Keys) {
                    $ctx.Response.Headers.Add($k, $_RespHeaders[$k])
                }
            }
            if ($_Body) {
                $bytes = [Text.Encoding]::UTF8.GetBytes($_Body)
                $ctx.Response.ContentLength64 = $bytes.Length
                $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            }
            $ctx.Response.Close()
        } catch {
            # Silently handle - listener errors are non-critical for the test
        }
    })

    $handle = $ps.BeginInvoke()
    return @{ PS = $ps; Handle = $handle; Runspace = $rs }
}

function Stop-ListenerHandler {
    param($handler)
    if ($handler) {
        try { $handler.PS.EndInvoke($handler.Handle) } catch {}
        $handler.PS.Dispose()
        $handler.Runspace.Dispose()
    }
}

# ============================================================================
# Previous state (simulated)
# ============================================================================
$prevGitVer  = 'v1.5.0'
$prevGitDate = '2026-03-20'
$prevFlag    = 'no'
$localVer    = 'v1.5.0'

# ============================================================================
# Common: the actual catch block logic from SKILL-v1.7.md Step 2
# ============================================================================
function Invoke-CatchBlock {
    param($ErrorRecord)

    $code = $null
    $rl   = ''
    $err  = ''

    try { if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.StatusCode) { $code = [int]$ErrorRecord.Exception.Response.StatusCode } } catch {}
    try {
        if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.Headers) {
            $rl = Get-ResponseHeaderValue $ErrorRecord.Exception.Response.Headers 'X-RateLimit-Remaining'
        }
    } catch { $rl = '' }

    if     ($code -eq 401)             { $status = 'auth_error' }
    elseif ($code -eq 404)             { $status = 'not_found' }
    elseif ($code -eq 429)             { $status = 'rate_limited' }
    elseif ($code -eq 403)             { $status = if ($rl -eq '0') { 'rate_limited' } else { 'forbidden' } }
    elseif ($code -and $code -ge 500)  { $status = 'server_error' }
    elseif ($code)                     { $status = 'http_error' }
    else                               { $status = 'network_error' }
    $err = $ErrorRecord.Exception.Message

    return @{ Status = $status; Code = $code; RateLimit = $rl; Error = $err }
}

# ============================================================================
# Common: the actual state machine logic from SKILL-v1.7.md Step 2
# ============================================================================
function Invoke-StateMachine {
    param(
        [string]$Status,
        [string]$PrevGitVer,
        [string]$PrevGitDate,
        [string]$PrevFlag,
        [string]$LocalVer,
        [string]$Latest = '',
        [string]$PubDate = '',
        [string]$PubUtc = ''
    )

    $newGitVer = $PrevGitVer; $newGitDate = $PrevGitDate; $newFlag = $PrevFlag
    $isNew = $false; $isFlip = $false; $review = $false; $cmp = ''
    $versionJump = $false; $dateSuspicious = $false; $reasons = @()

    if ($Status -eq 'ok' -and $Latest) {
        $isNew = ($Latest -ne $PrevGitVer)
        if ($isNew) {
            $newGitVer = $Latest
            $newGitDate = $PubDate
            $oldV = ConvertTo-NormVer $PrevGitVer
            $newV = ConvertTo-NormVer $Latest
            if ($null -ne $oldV -and $null -ne $newV) {
                if (($newV.Major - $oldV.Major) -ge 2 -or
                    (($newV.Major -eq $oldV.Major) -and (($newV.Minor - $oldV.Minor) -ge 10)) -or
                    (($newV.Major -eq $oldV.Major) -and ($newV.Minor -eq $oldV.Minor) -and (($newV.Patch - $oldV.Patch) -ge 50))) {
                    $versionJump = $true; $reasons += 'version_jump'
                }
                if ($PubUtc -and $PrevGitDate -match '^\d{4}-\d{2}-\d{2}$') {
                    $newDate = ([DateTimeOffset]::Parse($PubUtc)).ToOffset([TimeSpan]::FromHours(8)).Date
                    $oldDate = [DateTime]::ParseExact($PrevGitDate, 'yyyy-MM-dd', $null).Date
                    if ($newDate -lt $oldDate) { $dateSuspicious = $true; $reasons += 'date_suspicious' }
                }
            }
        }
        if ($LocalVer -match '未安装') {
            $newFlag = 'no'
        } else {
            $cmp = Compare-Ver $LocalVer $Latest
            switch ($cmp) {
                'lt' { $newFlag = 'yes' }
                'eq' { $newFlag = 'no' }
                default { $newFlag = $PrevFlag; $review = $true; $reasons += 'incomparable_version' }
            }
        }
        if ($PrevFlag -ceq 'no' -and $newFlag -ceq 'yes') { $isFlip = $true }
        if ($versionJump -or $dateSuspicious) { $review = $true }
    } elseif ($Status -eq 'not_found') {
        $newGitVer = ''; $newGitDate = ''; $newFlag = $PrevFlag
        $review = $true; $reasons += 'not_found'
    } else {
        $review = $true; $reasons += 'api_failure'
    }

    return @{
        gitVer         = $newGitVer
        gitDate        = $newGitDate
        flag           = $newFlag
        isNew          = $isNew
        isFlip         = $isFlip
        review         = $review
        cmp            = $cmp
        versionJump    = $versionJump
        dateSuspicious = $dateSuspicious
        reasons        = $reasons
    }
}

# ============================================================================
# Request headers (same as SKILL-v1.7.md Step 2)
# ============================================================================
$reqHeaders = @{
    'User-Agent'           = 'workbuddy-version-monitor'
    'Accept'               = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2026-03-10'
}

# ============================================================================
# T18a - auth_error (HTTP 401)
# ============================================================================
Log ""
Log "========== T18a - auth_error (HTTP 401) =========="
Log "Prev: gitVer='$prevGitVer', gitDate='$prevGitDate', flag='$prevFlag'"

$handler = Start-ListenerHandler -Listener $listener -StatusCode 401 -RespHeaders @{}

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
try {
    $j = Invoke-RestMethod -Uri "http://localhost:$port/repos/test/repo/releases/latest" -Headers $reqHeaders -TimeoutSec 10
    Log "[UNEXPECTED] Invoke-RestMethod succeeded (expected throw on 401)"
} catch {
    $result = Invoke-CatchBlock -ErrorRecord $_
    $status = $result.Status; $rl = $result.RateLimit; $err = $result.Error
}
Stop-ListenerHandler -handler $handler

$sm = Invoke-StateMachine -Status $status -PrevGitVer $prevGitVer -PrevGitDate $prevGitDate -PrevFlag $prevFlag -LocalVer $localVer

Log "queryStatus: $status"
Log "gitVer: '$($sm.gitVer)' (expected: '$prevGitVer')"
Log "gitDate: '$($sm.gitDate)' (expected: '$prevGitDate')"
Log "flag: '$($sm.flag)' (expected: '$prevFlag')"
Log "review: $($sm.review) (expected: True)"
Log "reviewReasons: $($sm.reasons -join ', ')"

$v1 = ($sm.gitVer -eq $prevGitVer)
$v2 = ($sm.gitDate -eq $prevGitDate)
$v3 = ($sm.flag -eq $prevFlag)
$v4 = ($sm.review -eq $true)
$v5 = ($status -eq 'auth_error')
$pass = $v1 -and $v2 -and $v3 -and $v4 -and $v5

Invoke-Test -TestId "T18a" `
    -Description "auth_error (HTTP 401): gitVer/gitDate/flag preserved, review=true" `
    -Expected "PASS" -Actual $(if ($pass) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, gitVer='$($sm.gitVer)' (prev='$prevGitVer'), gitDate='$($sm.gitDate)' (prev='$prevGitDate'), flag='$($sm.flag)' (prev='$prevFlag'), review=$($sm.review)"

# ============================================================================
# T18b - forbidden (HTTP 403 + X-RateLimit-Remaining: 50)
# ============================================================================
Log ""
Log "========== T18b - forbidden (HTTP 403 + X-RateLimit-Remaining: 50) =========="
Log "Prev: gitVer='$prevGitVer', gitDate='$prevGitDate', flag='$prevFlag'"

$handler = Start-ListenerHandler -Listener $listener -StatusCode 403 -RespHeaders @{ 'X-RateLimit-Remaining' = '50' }

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
try {
    $j = Invoke-RestMethod -Uri "http://localhost:$port/repos/test/repo/releases/latest" -Headers $reqHeaders -TimeoutSec 10
    Log "[UNEXPECTED] Invoke-RestMethod succeeded (expected throw on 403)"
} catch {
    $result = Invoke-CatchBlock -ErrorRecord $_
    $status = $result.Status; $rl = $result.RateLimit; $err = $result.Error
}
Stop-ListenerHandler -handler $handler

$sm = Invoke-StateMachine -Status $status -PrevGitVer $prevGitVer -PrevGitDate $prevGitDate -PrevFlag $prevFlag -LocalVer $localVer

Log "queryStatus: $status"
Log "rateLimit-Remaining: '$rl'"
Log "gitVer: '$($sm.gitVer)' (expected: '$prevGitVer')"
Log "gitDate: '$($sm.gitDate)' (expected: '$prevGitDate')"
Log "flag: '$($sm.flag)' (expected: '$prevFlag')"
Log "review: $($sm.review) (expected: True)"

$v1 = ($sm.gitVer -eq $prevGitVer)
$v2 = ($sm.gitDate -eq $prevGitDate)
$v3 = ($sm.flag -eq $prevFlag)
$v4 = ($sm.review -eq $true)
$v5 = ($status -eq 'forbidden')
$pass = $v1 -and $v2 -and $v3 -and $v4 -and $v5

Invoke-Test -TestId "T18b" `
    -Description "forbidden (HTTP 403 + X-RateLimit-Remaining: 50): gitVer/gitDate/flag preserved, review=true" `
    -Expected "PASS" -Actual $(if ($pass) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, rl='$rl', gitVer='$($sm.gitVer)' (prev='$prevGitVer'), gitDate='$($sm.gitDate)' (prev='$prevGitDate'), flag='$($sm.flag)' (prev='$prevFlag'), review=$($sm.review)"

# ============================================================================
# T18c - rate_limited (HTTP 429)
# ============================================================================
Log ""
Log "========== T18c - rate_limited (HTTP 429) =========="
Log "Prev: gitVer='$prevGitVer', gitDate='$prevGitDate', flag='$prevFlag'"

$handler = Start-ListenerHandler -Listener $listener -StatusCode 429 -RespHeaders @{}

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
try {
    $j = Invoke-RestMethod -Uri "http://localhost:$port/repos/test/repo/releases/latest" -Headers $reqHeaders -TimeoutSec 10
    Log "[UNEXPECTED] Invoke-RestMethod succeeded (expected throw on 429)"
} catch {
    $result = Invoke-CatchBlock -ErrorRecord $_
    $status = $result.Status; $rl = $result.RateLimit; $err = $result.Error
}
Stop-ListenerHandler -handler $handler

$sm = Invoke-StateMachine -Status $status -PrevGitVer $prevGitVer -PrevGitDate $prevGitDate -PrevFlag $prevFlag -LocalVer $localVer

Log "queryStatus: $status"
Log "gitVer: '$($sm.gitVer)' (expected: '$prevGitVer')"
Log "gitDate: '$($sm.gitDate)' (expected: '$prevGitDate')"
Log "flag: '$($sm.flag)' (expected: '$prevFlag')"
Log "review: $($sm.review) (expected: True)"

$v1 = ($sm.gitVer -eq $prevGitVer)
$v2 = ($sm.gitDate -eq $prevGitDate)
$v3 = ($sm.flag -eq $prevFlag)
$v4 = ($sm.review -eq $true)
$v5 = ($status -eq 'rate_limited')
$pass = $v1 -and $v2 -and $v3 -and $v4 -and $v5

Invoke-Test -TestId "T18c" `
    -Description "rate_limited (HTTP 429): gitVer/gitDate/flag preserved, review=true" `
    -Expected "PASS" -Actual $(if ($pass) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, gitVer='$($sm.gitVer)' (prev='$prevGitVer'), gitDate='$($sm.gitDate)' (prev='$prevGitDate'), flag='$($sm.flag)' (prev='$prevFlag'), review=$($sm.review)"

# ============================================================================
# T18d - server_error (HTTP 500)
# ============================================================================
Log ""
Log "========== T18d - server_error (HTTP 500) =========="
Log "Prev: gitVer='$prevGitVer', gitDate='$prevGitDate', flag='$prevFlag'"

$handler = Start-ListenerHandler -Listener $listener -StatusCode 500 -RespHeaders @{}

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
try {
    $j = Invoke-RestMethod -Uri "http://localhost:$port/repos/test/repo/releases/latest" -Headers $reqHeaders -TimeoutSec 10
    Log "[UNEXPECTED] Invoke-RestMethod succeeded (expected throw on 500)"
} catch {
    $result = Invoke-CatchBlock -ErrorRecord $_
    $status = $result.Status; $rl = $result.RateLimit; $err = $result.Error
}
Stop-ListenerHandler -handler $handler

$sm = Invoke-StateMachine -Status $status -PrevGitVer $prevGitVer -PrevGitDate $prevGitDate -PrevFlag $prevFlag -LocalVer $localVer

Log "queryStatus: $status"
Log "gitVer: '$($sm.gitVer)' (expected: '$prevGitVer')"
Log "gitDate: '$($sm.gitDate)' (expected: '$prevGitDate')"
Log "flag: '$($sm.flag)' (expected: '$prevFlag')"
Log "review: $($sm.review) (expected: True)"

$v1 = ($sm.gitVer -eq $prevGitVer)
$v2 = ($sm.gitDate -eq $prevGitDate)
$v3 = ($sm.flag -eq $prevFlag)
$v4 = ($sm.review -eq $true)
$v5 = ($status -eq 'server_error')
$pass = $v1 -and $v2 -and $v3 -and $v4 -and $v5

Invoke-Test -TestId "T18d" `
    -Description "server_error (HTTP 500): gitVer/gitDate/flag preserved, review=true" `
    -Expected "PASS" -Actual $(if ($pass) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, gitVer='$($sm.gitVer)' (prev='$prevGitVer'), gitDate='$($sm.gitDate)' (prev='$prevGitDate'), flag='$($sm.flag)' (prev='$prevFlag'), review=$($sm.review)"

# ============================================================================
# T18e - http_error (HTTP 418 - unusual status code)
# ============================================================================
# Note: The task suggested HTTP 302, but Invoke-RestMethod follows 3xx redirects
# by default. Without a Location header, 302 may not reliably trigger the catch
# block as http_error. HTTP 418 is a clean unusual code that:
#   1. Causes Invoke-RestMethod to throw (4xx error)
#   2. Doesn't match 401/404/429/403/5xx in the catch block
#   3. Falls through to http_error
# This tests the same code path (elseif ($code) -> http_error) as 302 would.
Log ""
Log "========== T18e - http_error (HTTP 418 - unusual status code) =========="
Log "Note: Using HTTP 418 instead of 302 because Invoke-RestMethod follows 3xx"
Log "      redirects by default. 418 reliably triggers the http_error catch path."
Log "Prev: gitVer='$prevGitVer', gitDate='$prevGitDate', flag='$prevFlag'"

$handler = Start-ListenerHandler -Listener $listener -StatusCode 418 -RespHeaders @{}

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
try {
    $j = Invoke-RestMethod -Uri "http://localhost:$port/repos/test/repo/releases/latest" -Headers $reqHeaders -TimeoutSec 10
    Log "[UNEXPECTED] Invoke-RestMethod succeeded (expected throw on 418)"
} catch {
    $result = Invoke-CatchBlock -ErrorRecord $_
    $status = $result.Status; $rl = $result.RateLimit; $err = $result.Error
    Log "  catch block: code=$($result.Code), status=$status, rl='$rl'"
}
Stop-ListenerHandler -handler $handler

$sm = Invoke-StateMachine -Status $status -PrevGitVer $prevGitVer -PrevGitDate $prevGitDate -PrevFlag $prevFlag -LocalVer $localVer

Log "queryStatus: $status"
Log "gitVer: '$($sm.gitVer)' (expected: '$prevGitVer')"
Log "gitDate: '$($sm.gitDate)' (expected: '$prevGitDate')"
Log "flag: '$($sm.flag)' (expected: '$prevFlag')"
Log "review: $($sm.review) (expected: True)"

$v1 = ($sm.gitVer -eq $prevGitVer)
$v2 = ($sm.gitDate -eq $prevGitDate)
$v3 = ($sm.flag -eq $prevFlag)
$v4 = ($sm.review -eq $true)
$v5 = ($status -eq 'http_error')
$pass = $v1 -and $v2 -and $v3 -and $v4 -and $v5

Invoke-Test -TestId "T18e" `
    -Description "http_error (HTTP 418, unusual code): gitVer/gitDate/flag preserved, review=true" `
    -Expected "PASS" -Actual $(if ($pass) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, gitVer='$($sm.gitVer)' (prev='$prevGitVer'), gitDate='$($sm.gitDate)' (prev='$prevGitDate'), flag='$($sm.flag)' (prev='$prevFlag'), review=$($sm.review)"

# ============================================================================
# T18f - network_error (connection refused)
# ============================================================================
Log ""
Log "========== T18f - network_error (connection refused) =========="
Log "Prev: gitVer='$prevGitVer', gitDate='$prevGitDate', flag='$prevFlag'"
Log "Connecting to http://localhost:39999 (closed port)..."

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
try {
    $j = Invoke-RestMethod -Uri "http://localhost:39999/repos/test/repo/releases/latest" -Headers $reqHeaders -TimeoutSec 5
    Log "[UNEXPECTED] Invoke-RestMethod succeeded (expected connection refused)"
} catch {
    $result = Invoke-CatchBlock -ErrorRecord $_
    $status = $result.Status; $rl = $result.RateLimit; $err = $result.Error
    Log "  catch block: code=$($result.Code), status=$status"
}

$sm = Invoke-StateMachine -Status $status -PrevGitVer $prevGitVer -PrevGitDate $prevGitDate -PrevFlag $prevFlag -LocalVer $localVer

Log "queryStatus: $status"
Log "gitVer: '$($sm.gitVer)' (expected: '$prevGitVer')"
Log "gitDate: '$($sm.gitDate)' (expected: '$prevGitDate')"
Log "flag: '$($sm.flag)' (expected: '$prevFlag')"
Log "review: $($sm.review) (expected: True)"

$v1 = ($sm.gitVer -eq $prevGitVer)
$v2 = ($sm.gitDate -eq $prevGitDate)
$v3 = ($sm.flag -eq $prevFlag)
$v4 = ($sm.review -eq $true)
$v5 = ($status -eq 'network_error')
$pass = $v1 -and $v2 -and $v3 -and $v4 -and $v5

Invoke-Test -TestId "T18f" `
    -Description "network_error (connection refused): gitVer/gitDate/flag preserved, review=true" `
    -Expected "PASS" -Actual $(if ($pass) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, gitVer='$($sm.gitVer)' (prev='$prevGitVer'), gitDate='$($sm.gitDate)' (prev='$prevGitDate'), flag='$($sm.flag)' (prev='$prevFlag'), review=$($sm.review), err='$err'"

# ============================================================================
# T18g - not_found (HTTP 404)
# ============================================================================
Log ""
Log "========== T18g - not_found (HTTP 404) =========="
Log "Prev: gitVer='$prevGitVer', gitDate='$prevGitDate', flag='$prevFlag'"
Log "Expected: gitVer='' (cleared), gitDate='' (cleared), flag='$prevFlag' (preserved)"

$handler = Start-ListenerHandler -Listener $listener -StatusCode 404 -RespHeaders @{}

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
try {
    $j = Invoke-RestMethod -Uri "http://localhost:$port/repos/test/repo/releases/latest" -Headers $reqHeaders -TimeoutSec 10
    Log "[UNEXPECTED] Invoke-RestMethod succeeded (expected throw on 404)"
} catch {
    $result = Invoke-CatchBlock -ErrorRecord $_
    $status = $result.Status; $rl = $result.RateLimit; $err = $result.Error
}
Stop-ListenerHandler -handler $handler

$sm = Invoke-StateMachine -Status $status -PrevGitVer $prevGitVer -PrevGitDate $prevGitDate -PrevFlag $prevFlag -LocalVer $localVer

Log "queryStatus: $status"
Log "gitVer: '$($sm.gitVer)' (expected: '' - cleared)"
Log "gitDate: '$($sm.gitDate)' (expected: '' - cleared)"
Log "flag: '$($sm.flag)' (expected: '$prevFlag' - preserved)"
Log "review: $($sm.review) (expected: True)"
Log "reviewReasons: $($sm.reasons -join ', ') (expected: contains 'not_found')"

$v1 = ($sm.gitVer -eq '')
$v2 = ($sm.gitDate -eq '')
$v3 = ($sm.flag -eq $prevFlag)
$v4 = ($sm.review -eq $true)
$v5 = ($status -eq 'not_found')
$v6 = ($sm.reasons -contains 'not_found')
$pass = $v1 -and $v2 -and $v3 -and $v4 -and $v5 -and $v6

Invoke-Test -TestId "T18g" `
    -Description "not_found (HTTP 404): gitVer='' (cleared), gitDate='' (cleared), flag preserved, review=true, reviewReasons contains 'not_found'" `
    -Expected "PASS" -Actual $(if ($pass) { 'PASS' } else { 'FAIL' }) `
    -Evidence "status=$status, gitVer='$($sm.gitVer)' (cleared=''), gitDate='$($sm.gitDate)' (cleared=''), flag='$($sm.flag)' (prev='$prevFlag' preserved), review=$($sm.review), reasons=[$($sm.reasons -join ', ')]"

# ============================================================================
# Cleanup listener
# ============================================================================
$listener.Stop()
Log ""
Log "HTTP listener stopped."

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
[void]$md.AppendLine("# Production Validation v1.7 Final - Test Report (T18)")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
[void]$md.AppendLine("**Script:** ``test.ps1``")
[void]$md.AppendLine("**Test:** T18 - State Preservation")
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
[void]$md.AppendLine("Uses a local HTTP listener (``System.Net.HttpListener`` on ``http://localhost:8765``)")
[void]$md.AppendLine("to produce controlled HTTP responses. Real ``Invoke-RestMethod`` calls are made")
[void]$md.AppendLine("to the listener, and the actual catch block logic + state machine logic from")
[void]$md.AppendLine("SKILL-v1.7.md Step 2 are executed for each test case.")
[void]$md.AppendLine("")
[void]$md.AppendLine("**Previous state (simulated for all tests):**")
[void]$md.AppendLine("- ``prevGitVer = 'v1.5.0'``")
[void]$md.AppendLine("- ``prevGitDate = '2026-03-20'``")
[void]$md.AppendLine("- ``prevFlag = 'no'``")
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
# After API call, state machine processes queryStatus:
if ($status -eq 'ok' -and $latest) {
    # Normal path - gitVer/gitDate/flag updated from API
} elseif ($status -eq 'not_found') {
    $newGitVer = ''; $newGitDate = ''; # cleared
    $newFlag = $prevFlag;               # preserved
    $review = $true; $reasons += 'not_found'
} else {
    # ALL other statuses preserve gitVer, gitDate, flag
    $newGitVer = $prevGitVer; $newGitDate = $prevGitDate; $newFlag = $prevFlag
    $review = $true; $reasons += 'api_failure'
}
```
'@
[void]$md.Append($codeBlock)
[void]$md.AppendLine("")
$noteBlock = @'
## Note on HTTP 302 vs 418 for http_error Test

The task suggested HTTP 302 for the `http_error` test. However, `Invoke-RestMethod`
in PowerShell 7 follows 3xx redirects by default. A 302 without a `Location` header
does not reliably trigger the `http_error` catch path (it may produce a different
exception type without a response object). HTTP 418 (`I'm a teapot`) was used instead
because it is a clean unusual HTTP status code that:
1. Causes `Invoke-RestMethod` to throw an `HttpResponseException`
2. Has a `Response` object with `StatusCode = 418`
3. Does not match 401/404/429/403/5xx in the catch block
4. Falls through to `http_error` via the `elseif ($code)` branch

This tests the same code path that 302 would if it reached the catch block.
'@
[void]$md.Append($noteBlock)
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
