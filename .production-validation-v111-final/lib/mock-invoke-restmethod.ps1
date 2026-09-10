# mock-invoke-restmethod.ps1 — mock Invoke-RestMethod 覆盖函数库（Phase 1 Step 7）
#
# 用途：按场景返回仿真对象，成员形状与 SKILL 状态机访问路径一致（SKILL-v1.11 L341-367）。
# PS5.1 兼容：本文件禁用 PS7-only 语法（?? / 三元 ? : / && / ||），Phase 9 复用。
#
# 场景清单（contract）：
#   成功路径（正常返回 PSCustomObject）：
#     normal / versionJump   : tag_name(string) + published_at(ISO date)
#     metadata_incomplete    : 有 tag_name，无 published_at
#     invalid_response       : 空 tag_name 或无 tag_name
#   异常路径（throw，携带 .Exception.Response）：
#     404  → not_found       : StatusCode 404
#     401  → auth_error      : StatusCode 401
#     429  → rate_limited    : StatusCode 429
#     403  → rate_limited    : StatusCode 403 + X-RateLimit-Remaining='0'
#     403  → forbidden       : StatusCode 403 + X-RateLimit-Remaining='50'
#     500  → server_error    : StatusCode 500
#     302  → http_error      : StatusCode 302
#     network_error          : 异常无 .Exception.Response
#
# 关键实现说明（实测验证，2026-09-09）：SKILL L355/L357 访问的是 `$_`（catch 块自动变量）的
#   `.Exception.Response`：
#     try { if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $code = [int]$_.Exception.Response.StatusCode } } catch {}
# 实测结论（PowerShell 7.6.4）：
#   - throw PSCustomObject  → $_ 是 ErrorRecord，$_ .Exception 是 System.Management.Automation.RuntimeException
#     （PowerShell 把非 Exception 对象包装为 RuntimeException，原始对象的所有自定义属性丢失）
#     → $_.Exception.Response = $null → $code 保持 $null → 所有异常场景误判为 network_error。
#   - throw 真实 Exception 子类（WorkbuddyMock.MockHttpResponseException）→ $_.Exception 是该 Exception 实例
#     → $_.Exception.Response 正常暴露 StatusCode 与 Headers → 状态机正确判定。
# 故 mock 必须抛出**真实 Exception 子类**（非 PSCustomObject），使 $_.Exception.Response 可用。
# 本库使用 Add-Type 定义 WorkbuddyMock.MockHttpResponseException（C# 类型，PS5.1 兼容）。
#
# PS7 Headers 类型选择：System.Net.WebHeaderCollection（见 mock-contract-selfcheck.txt 记录）。

$ErrorActionPreference = 'Stop'

# 请求计数（按 URI 分类），供 T04 请求计数验证使用
$script:MockRequestCounts = @{
    releases_latest = 0
    releases_list   = 0
    html            = 0
    other           = 0
}

# 场景配置（编排器在执行 step2 前设置）
$script:MockScenario = 'normal'
$script:MockTag = 'v2.0.0'
$script:MockPublishedAt = '2026-09-01T10:00:00Z'
$script:MockRateRemaining = '50'

function New-MockResponseHeaders {
    param([hashtable]$Pairs)
    # 必须是 System.Net.WebHeaderCollection 实例（不可用 Hashtable 替代，否则 PS5.1 兼容性验证无意义）
    $h = New-Object System.Net.WebHeaderCollection
    foreach ($k in $Pairs.Keys) { $h.Add($k, $Pairs[$k]) }
    # 关键：WebHeaderCollection 实现 ICollection，`return $h` 会被 PowerShell 自动枚举展开
    #      → 函数返回 string（每个 header 值）而非 collection。必须用 Write-Output -NoEnumerate。
    Write-Output -NoEnumerate $h
}

# C# 类型定义（New-MockHttpResponse / New-MockHttpException 依赖；PS5.1 兼容）
# 说明：Response 必须用 C# 类型（不可用 PSCustomObject）——
#   PSCustomObject 有内置 Headers 属性（返回 string），会 shadow 自定义 Headers 属性，
#   导致 $_.Exception.Response.Headers 返回 string 而非 WebHeaderCollection。
if (-not ('WorkbuddyMock.MockHttpResponseException' -as [type])) {
    Add-Type -TypeDefinition @"
using System;
using System.Net;
namespace WorkbuddyMock {
    public class MockHttpResponse {
        public HttpStatusCode StatusCode { get; private set; }
        public WebHeaderCollection Headers { get; private set; }
        public MockHttpResponse(HttpStatusCode statusCode, WebHeaderCollection headers) {
            this.StatusCode = statusCode;
            this.Headers = headers;
        }
    }
    public class MockHttpResponseException : Exception {
        public object Response { get; private set; }
        public MockHttpResponseException(string message, object response) : base(message) { this.Response = response; }
    }
}
"@
}

function New-MockHttpResponse {
    param([int]$StatusCode, [string]$RateRemaining)
    # StatusCode 用 System.Net.HttpStatusCode 枚举实例，贴近真实响应形状
    # Response 用 C# 类型（不可用 PSCustomObject，因其内置 Headers 属性会 shadow）
    $headers = New-MockResponseHeaders @{ 'X-RateLimit-Remaining' = $RateRemaining }
    return New-Object WorkbuddyMock.MockHttpResponse([System.Net.HttpStatusCode]$StatusCode, $headers)
}

function New-MockHttpException {
    param([string]$Message, [object]$Response)
    # 必须返回真实 Exception 子类（不可用 PSCustomObject）：
    #   throw PSCustomObject → $_.Exception 被包装为 RuntimeException，原始自定义属性全部丢失
    #   → $_.Exception.Response = $null → 所有异常场景误判为 network_error。
    # 返回 WorkbuddyMock.MockHttpResponseException 实例，使 $_.Exception.Response 正常暴露 StatusCode 与 Headers。
    return New-Object WorkbuddyMock.MockHttpResponseException($Message, $Response)
}

function Invoke-RestMethod {
    param($Uri, $Headers, $TimeoutSec)
    $u = [string]$Uri
    if ($u -match '/releases/latest') { $script:MockRequestCounts['releases_latest']++ }
    elseif ($u -match '/releases\?per_page') { $script:MockRequestCounts['releases_list']++ }
    elseif ($u -match 'github\.com/.*/releases') { $script:MockRequestCounts['html']++ }
    else { $script:MockRequestCounts['other']++ }

    switch ($script:MockScenario) {
        'normal' {
            return New-Object PSCustomObject -Property @{ tag_name = $script:MockTag; published_at = $script:MockPublishedAt }
        }
        'versionJump' {
            return New-Object PSCustomObject -Property @{ tag_name = $script:MockTag; published_at = $script:MockPublishedAt }
        }
        'metadata_incomplete' {
            return New-Object PSCustomObject -Property @{ tag_name = $script:MockTag }
        }
        'invalid_response' {
            return New-Object PSCustomObject -Property @{ tag_name = '' }
        }
        '404' {
            throw (New-MockHttpException -Message '404 Not Found' -Response (New-MockHttpResponse -StatusCode 404 -RateRemaining '50'))
        }
        '401' {
            throw (New-MockHttpException -Message '401 Unauthorized' -Response (New-MockHttpResponse -StatusCode 401 -RateRemaining '50'))
        }
        '429' {
            throw (New-MockHttpException -Message '429 Too Many Requests' -Response (New-MockHttpResponse -StatusCode 429 -RateRemaining '0'))
        }
        '403' {
            throw (New-MockHttpException -Message '403 Forbidden' -Response (New-MockHttpResponse -StatusCode 403 -RateRemaining $script:MockRateRemaining))
        }
        '500' {
            throw (New-MockHttpException -Message '500 Internal Server Error' -Response (New-MockHttpResponse -StatusCode 500 -RateRemaining '50'))
        }
        '302' {
            throw (New-MockHttpException -Message '302 Found' -Response (New-MockHttpResponse -StatusCode 302 -RateRemaining '50'))
        }
        'network_error' {
            # 无 Response（如 timeout / DNS / TLS 失败）
            throw (New-MockHttpException -Message 'The operation has timed out.' -Response $null)
        }
        default {
            Write-Output ('MOCK_UNKNOWN_SCENARIO|{0}' -f $script:MockScenario)
            return New-Object PSCustomObject -Property @{ tag_name = $script:MockTag; published_at = $script:MockPublishedAt }
        }
    }
}

Write-Output 'MOCK_LIBRARY_LOADED'
