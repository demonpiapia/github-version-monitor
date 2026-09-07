# T08-PS7: 无 HTTP response（连接失败） => queryStatus=network_error
# 使用 RFC 5737 TEST-NET 192.0.2.1:9999 保证不可达
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$lib = Join-Path (Split-Path $here -Parent) 'lib'

$PSVersion = $PSVersionTable.PSVersion.ToString()
Write-Output "PS_VERSION|$PSVersion"

# 逐字提取 Get-ResponseHeaderValue (step2.ps1 L85-91)
function Get-ResponseHeaderValue {
    param($Headers,[string]$Name)
    try { if ($Headers -is [System.Net.WebHeaderCollection]) { $v=$Headers.Get($Name); if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } } catch {}
    try { $v=$Headers[$Name]; if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } catch {}
    try { $values=$null; if ($Headers.TryGetValues($Name,[ref]$values)) { $first=$values|Select-Object -First 1; if ($null -ne $first) { return [string]$first } } } catch {}
    return ''
}

# 逐字提取 ConvertTo-UtcIso (step2.ps1 L69-75)
function ConvertTo-UtcIso {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '' }
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    if ($Value -is [DateTime]) { return ([DateTimeOffset]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return ([DateTimeOffset]::Parse([string]$Value)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

$headers = @{ 'User-Agent' = 'workbuddy-version-monitor'
              'Accept'     = 'application/vnd.github+json'
              'X-GitHub-Api-Version' = '2026-03-10' }

$it = [PSCustomObject]@{ repo='test/repo'; name='Test'; prevGitVer='v1.0.0'; prevGitDate='2026-08-01'; localVer='v1.0.0'; prevFlag='yes' }

# 场景 A: TEST-NET 192.0.2.1:9999（RFC 5737，保证不可达）
$targetA = "http://192.0.2.1:9999/repos/$($it.repo)/releases/latest"
Write-Output "TARGET_A|$targetA"

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $j = Invoke-RestMethod -Uri $targetA -Headers $headers -TimeoutSec 15
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
$sw.Stop()

$outA = [PSCustomObject]@{
    repo = $it.repo; name = $it.name
    prevGitVer = $it.prevGitVer; prevGitDate = $it.prevGitDate
    localVer = $it.localVer; prevFlag = $it.prevFlag
    queryStatus = $status; latest = $latest
    published = $pubDate; publishedUtc = $pubUtc
    rateRemaining = $rl; error = $err
}
Write-Output "RESULT_A|queryStatus=$($outA.queryStatus)|rateRemaining=$($outA.rateRemaining)|elapsedMs=$($sw.ElapsedMilliseconds)|error=$($outA.error)"

# 场景 B: localhost:1（备用，通常无服务监听）
$targetB = "http://localhost:1/repos/$($it.repo)/releases/latest"
Write-Output "TARGET_B|$targetB"

$status = 'ok'; $latest = ''; $pubDate = ''; $pubUtc = ''; $err = ''; $rl = ''
$sw = [System.Diagnostics.Stopwatch]::StartNew()
try {
    $j = Invoke-RestMethod -Uri $targetB -Headers $headers -TimeoutSec 5
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
$sw.Stop()

$outB = [PSCustomObject]@{
    repo = $it.repo; name = $it.name
    prevGitVer = $it.prevGitVer; prevGitDate = $it.prevGitDate
    localVer = $it.localVer; prevFlag = $it.prevFlag
    queryStatus = $status; latest = $latest
    published = $pubDate; publishedUtc = $pubUtc
    rateRemaining = $rl; error = $err
}
Write-Output "RESULT_B|queryStatus=$($outB.queryStatus)|rateRemaining=$($outB.rateRemaining)|elapsedMs=$($sw.ElapsedMilliseconds)|error=$($outB.error)"
