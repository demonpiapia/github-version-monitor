# T04-PS5.1: 403 + X-RateLimit-Remaining=0 => queryStatus=rate_limited
# PS5.1 兼容性验证：HttpListener 响应使用 WebHeaderCollection（与 PS7 的 HttpResponseHeaders 不同）
# 方法：Start-Job 后台跑 mock-listener.ps1，主线程走状态机
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$lib = Join-Path (Split-Path $here -Parent) 'lib'

$PSVersion = $PSVersionTable.PSVersion.ToString()
Write-Output "PS_VERSION|$PSVersion"

# 从 lib/step2.ps1 逐字提取的函数（L85-91 Get-ResponseHeaderValue）—— PS5.1 兼容多行格式
function Get-ResponseHeaderValue {
    param($Headers,[string]$Name)
    try {
        if ($Headers -is [System.Net.WebHeaderCollection]) {
            $v = $Headers.Get($Name)
            if ($null -ne $v -and [string]$v -ne '') { return [string]$v }
        }
    } catch {}
    try {
        $v = $Headers[$Name]
        if ($null -ne $v -and [string]$v -ne '') { return [string]$v }
    } catch {}
    try {
        $values = $null
        if ($Headers.TryGetValues($Name,[ref]$values)) {
            $first = $values | Select-Object -First 1
            if ($null -ne $first) { return [string]$first }
        }
    } catch {}
    return ''
}

# 逐字提取 ConvertTo-UtcIso (L69-75)
function ConvertTo-UtcIso {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return '' }
    if ($Value -is [DateTimeOffset]) { return $Value.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    if ($Value -is [DateTime]) { return ([DateTimeOffset]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return ([DateTimeOffset]::Parse([string]$Value)).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# ---- 启动 mock listener（后台 job）----
$port = 18345
$logPath = Join-Path $here 'listener.log'
if (Test-Path $logPath) { Remove-Item $logPath -Force }
$routes = @(
    @{
        Path   = '/repos/test/repo/releases/latest'
        Status = 403
        Body   = '{"message":"API rate limit exceeded for 127.0.0.1. If you are trying to make a large number of requests, you may want to consider using a personal access token with a higher rate limit. For more information see https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"}'
        Headers = @{ 'X-RateLimit-Remaining' = '0'; 'X-RateLimit-Limit' = '60'; 'Content-Type' = 'application/json' }
    }
)
$listenerScript = Join-Path $lib 'mock-listener.ps1'

$job = Start-Job -ScriptBlock {
    param($p, $r, $lp, $ls)
    & $ls -Port $p -Routes $r -LogPath $lp
} -ArgumentList $port, $routes, $logPath, $listenerScript

# 等待 listener 就绪
$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Milliseconds 200
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect('127.0.0.1', $port)
        $tcp.Close()
        $ready = $true
        break
    } catch { }
}
if (-not $ready) {
    Write-Output "LISTENER_NOT_READY|port=$port"
    Stop-Job $job
    Remove-Job $job -Force
    exit 1
}
Write-Output "LISTENER_READY|port=$port"

# ---- 状态机 try/catch 块（L99-139 内 foreach 循环体）—— 逐字提取，只把 URL 换成 localhost ----
$headers = @{ 'User-Agent' = 'workbuddy-version-monitor'
              'Accept'     = 'application/vnd.github+json'
              'X-GitHub-Api-Version' = '2026-03-10' }

$it = [PSCustomObject]@{ repo='test/repo'; name='Test'; prevGitVer='v1.0.0'; prevGitDate='2026-08-01'; localVer='v1.0.0'; prevFlag='yes' }

$status = 'ok'
$latest = ''
$pubDate = ''
$pubUtc = ''
$err = ''
$rl = ''
$headerType = ''
try {
    $j = Invoke-RestMethod -Uri "http://localhost:${port}/repos/$($it.repo)/releases/latest" -Headers $headers -TimeoutSec 20
    if ($j.tag_name -and $j.published_at) {
        $pubUtc = ConvertTo-UtcIso $j.published_at
        $dtUtc = [DateTimeOffset]::Parse($pubUtc)
        $pubDate = $dtUtc.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd')
        $latest  = $j.tag_name
    } elseif ($j.tag_name) {
        $status = 'metadata_incomplete'
        $err = 'tag_name present but published_at missing'
    } else {
        $status = 'invalid_response'
        $err = '200 but empty tag_name'
    }
} catch {
    $code = $null
    try {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $code = [int]$_.Exception.Response.StatusCode }
    } catch {}
    try {
        if ($_.Exception.Response -and $_.Exception.Response.Headers) {
            $rl = Get-ResponseHeaderValue $_.Exception.Response.Headers 'X-RateLimit-Remaining'
            $headerType = $_.Exception.Response.Headers.GetType().FullName
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

$out = [PSCustomObject]@{
    repo = $it.repo
    name = $it.name
    prevGitVer = $it.prevGitVer
    prevGitDate = $it.prevGitDate
    localVer = $it.localVer
    prevFlag = $it.prevFlag
    queryStatus = $status
    latest = $latest
    published = $pubDate
    publishedUtc = $pubUtc
    rateRemaining = $rl
    error = $err
}

Write-Output "RESULT|queryStatus=$($out.queryStatus)|rateRemaining=$($out.rateRemaining)|latest=$($out.latest)|error=$($out.error)"
Write-Output "HEADER_TYPE|$headerType"

# 停止 listener，统计请求次数
Stop-Job $job
Wait-Job $job -Timeout 5 | Out-Null
Remove-Job $job -Force

Start-Sleep -Milliseconds 300
if (Test-Path $logPath) {
    $logLines = Get-Content $logPath
    $latestReqCount = @($logLines | Where-Object { $_ -match '/repos/test/repo/releases/latest' }).Count
    $htmlReqCount = @($logLines | Where-Object { $_ -match 'github\.com|\.html' }).Count
    $step4ReqCount = @($logLines | Where-Object { $_ -match 'review|step4' }).Count
    Write-Output "REQ_COUNT|latest=$latestReqCount|html=$htmlReqCount|step4=$step4ReqCount"
    Write-Output "LISTENER_LOG_START"
    $logLines | ForEach-Object { Write-Output $_ }
    Write-Output "LISTENER_LOG_END"
}
