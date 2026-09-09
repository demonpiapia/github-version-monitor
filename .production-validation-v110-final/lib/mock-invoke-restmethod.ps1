# mock-invoke-restmethod.ps1 - Invoke-RestMethod 覆盖函数库
# 用途：为 T04/T05/T18/T26 等状态机测试提供受控的 HTTP 响应/异常模拟。
#
# PS5.1 语法兼容要求：本脚本在 Phase 1（PS7）创建，被 Phase 8（PS5.1）复用。
# 禁用 PS7-only 运算符：?? / ? :（三元）/ && / ||（管道链）。
#
# Headers 类型选择：System.Net.WebHeaderCollection
#   - 与 PS5.1 共用同一 mock 库，实现简单
#   - 本轮 PS7 侧 Get-ResponseHeaderValue 面向 HttpResponseHeaders 的分支将无直接覆盖
#   - 已在 lib/mock-contract-selfcheck.txt 中记录此选择与覆盖缺口
#
# 类型规范：
#   - Exception.Response.StatusCode：使用 System.Net.HttpStatusCode 枚举实例
#   - X-RateLimit-Remaining：字符串（'0' / '50'），因 SKILL L364 以字符串比较
#   - network_error 场景：异常无 .Response 属性
#
# 场景枚举（scenario）：
#   normal             - 200 + tag_name + published_at
#   versionJump        - 200 + tag_name + published_at（同 normal，由 fixture localVer 决定）
#   metadata_incomplete- 200 + tag_name，无 published_at
#   invalid_response   - 200 + 空 tag_name
#   not_found          - 404
#   auth_error         - 401
#   rate_limited_429   - 429
#   rate_limited_403   - 403 + X-RateLimit-Remaining='0'
#   forbidden          - 403 + X-RateLimit-Remaining='50'
#   server_error       - 500
#   http_error         - 302
#   network_error      - 无 .Response 的异常（模拟 timeout）

# 场景配置表：scenario -> @{ StatusCode=<int>; RateLimitRemaining=<string>; Body=<PSCustomObject or null>; Throw=<bool>; NetworkError=<bool> }
$script:MockScenarios = @{
    'normal'              = @{ StatusCode=200; RateLimitRemaining='';    Body=$null; Throw=$false; NetworkError=$false }
    'versionJump'         = @{ StatusCode=200; RateLimitRemaining='';    Body=$null; Throw=$false; NetworkError=$false }
    'metadata_incomplete' = @{ StatusCode=200; RateLimitRemaining='';    Body=$null; Throw=$false; NetworkError=$false }
    'invalid_response'    = @{ StatusCode=200; RateLimitRemaining='';    Body=$null; Throw=$false; NetworkError=$false }
    'not_found'           = @{ StatusCode=404; RateLimitRemaining='';    Body=$null; Throw=$true;  NetworkError=$false }
    'auth_error'          = @{ StatusCode=401; RateLimitRemaining='';    Body=$null; Throw=$true;  NetworkError=$false }
    'rate_limited_429'    = @{ StatusCode=429; RateLimitRemaining='';    Body=$null; Throw=$true;  NetworkError=$false }
    'rate_limited_403'    = @{ StatusCode=403; RateLimitRemaining='0';   Body=$null; Throw=$true;  NetworkError=$false }
    'forbidden'           = @{ StatusCode=403; RateLimitRemaining='50';  Body=$null; Throw=$true;  NetworkError=$false }
    'server_error'        = @{ StatusCode=500; RateLimitRemaining='';    Body=$null; Throw=$true;  NetworkError=$false }
    'http_error'          = @{ StatusCode=302; RateLimitRemaining='';    Body=$null; Throw=$true;  NetworkError=$false }
    'network_error'       = @{ StatusCode=0;   RateLimitRemaining='';    Body=$null; Throw=$true;  NetworkError=$true  }
}

# 测试 harness 通过此变量设置场景（默认 normal）
$script:MockScenario = 'normal'
# 测试 harness 可覆盖 tag_name / published_at（用于 versionJump 等）
$script:MockTagName = 'v1.0.0'
$script:MockPublishedAt = '2026-09-01T00:00:00Z'

# 记录所有 mock 调用（用于 T04 请求计数验证）
$global:MockCallLog = New-Object System.Collections.Generic.List[object]

function New-MockHttpWebResponse {
    param(
        [int]$StatusCode,
        [string]$RateLimitRemaining
    )
    # 构造一个鸭子类型的 Response 对象，含 StatusCode 与 Headers 属性
    # StatusCode 使用 System.Net.HttpStatusCode 枚举实例（SKILL L355 会 [int] 转换）
    $headers = New-Object System.Net.WebHeaderCollection
    if ($RateLimitRemaining -ne '') {
        $headers.Add('X-RateLimit-Remaining', $RateLimitRemaining)
    }
    $response = New-Object PSObject
    $response | Add-Member -NotePropertyName StatusCode -NotePropertyValue ([System.Net.HttpStatusCode]$StatusCode) -Force
    $response | Add-Member -NotePropertyName Headers -NotePropertyValue $headers -Force
    return $response
}

function New-MockWebException {
    param(
        [int]$StatusCode,
        [string]$RateLimitRemaining
    )
    $response = New-MockHttpWebResponse -StatusCode $StatusCode -RateLimitRemaining $RateLimitRemaining
    $ex = New-Object System.Exception ("HTTP {0}" -f $StatusCode)
    $ex | Add-Member -NotePropertyName Response -NotePropertyValue $response -Force
    return $ex
}

function New-MockNetworkException {
    # 无 .Response 属性的异常，模拟 timeout / DNS / TLS 失败
    return (New-Object System.Exception 'The operation timed out')
}

function Invoke-RestMethod {
    param(
        [string]$Uri,
        $Headers,
        [int]$TimeoutSec = 20,
        [switch]$UseBasicParsing
    )
    $scenario = $script:MockScenario
    if (-not $script:MockScenarios.ContainsKey($scenario)) {
        throw ("Mock scenario '{0}' not registered" -f $scenario)
    }
    $cfg = $script:MockScenarios[$scenario]
    [void]$script:MockCallLog.Add([PSCustomObject]@{
        Scenario = $scenario
        Uri = $Uri
        Timestamp = (Get-Date).ToString('o')
    })
    if ($cfg.Throw -eq $true) {
        if ($cfg.NetworkError -eq $true) {
            throw (New-MockNetworkException)
        }
        throw (New-MockWebException -StatusCode $cfg.StatusCode -RateLimitRemaining $cfg.RateLimitRemaining)
    }
    # 成功路径：返回 PSCustomObject
    switch ($scenario) {
        'metadata_incomplete' {
            return [PSCustomObject]@{
                tag_name = $script:MockTagName
            }
        }
        'invalid_response' {
            return [PSCustomObject]@{
                tag_name = ''
            }
        }
        default {
            # normal / versionJump
            return [PSCustomObject]@{
                tag_name = $script:MockTagName
                published_at = $script:MockPublishedAt
            }
        }
    }
}

# 辅助：重置 mock 状态
function Reset-MockState {
    $script:MockScenario = 'normal'
    $script:MockTagName = 'v1.0.0'
    $script:MockPublishedAt = '2026-09-01T00:00:00Z'
    $global:MockCallLog.Clear()
}

# 辅助：设置场景
function Set-MockScenario {
    param([string]$Scenario, [string]$TagName = 'v1.0.0', [string]$PublishedAt = '2026-09-01T00:00:00Z')
    $script:MockScenario = $Scenario
    if ($TagName -ne '') { $script:MockTagName = $TagName }
    if ($PublishedAt -ne '') { $script:MockPublishedAt = $PublishedAt }
}

# 辅助：读取调用日志
function Get-MockCallLog {
    return $script:MockCallLog
}
