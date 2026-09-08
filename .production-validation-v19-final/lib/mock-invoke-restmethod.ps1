param([string]$Scenario = 'normal')
$ErrorActionPreference = 'Stop'

# .NET Core 兼容：WebException 在 .NET Core 上不可用（PS7），
# 因此使用自定义 Exception 派生类，暴露 .Response 属性供 SKILL L353-356 读取。
# Response 使用 HttpResponseMessage（有公开构造函数）。
class MockHttpException : System.Exception {
    [object] $Response
    MockHttpException([string]$msg, [object]$resp) : base($msg) {
        $this.Response = $resp
    }
}

function New-MockResponse {
    param([System.Net.HttpStatusCode]$Code, [hashtable]$Headers)
    $resp = New-Object System.Net.Http.HttpResponseMessage($Code)
    if ($null -ne $Headers) {
        foreach ($key in $Headers.Keys) {
            $null = $resp.Headers.TryAddWithoutValidation($key, $Headers[$key])
        }
    }
    return $resp
}

function Invoke-RestMethod {
    param(
        [Parameter(Mandatory=$false)][string]$Uri,
        [Parameter(Mandatory=$false)][hashtable]$Headers,
        [Parameter(Mandatory=$false)][int]$TimeoutSec = 20
    )
    $scenario = $env:MOCK_SCENARIO
    if ([string]::IsNullOrWhiteSpace($scenario)) { $scenario = 'normal' }

    switch ($scenario) {
        'normal' {
            return [PSCustomObject]@{
                tag_name     = 'v2.0.0'
                published_at = '2026-09-07T12:00:00Z'
            }
        }
        'versionJump' {
            return [PSCustomObject]@{
                tag_name     = 'v2.0.0'
                published_at = '2026-09-07T12:00:00Z'
            }
        }
        'metadata_incomplete' {
            return [PSCustomObject]@{
                tag_name = 'v1.0.0'
            }
        }
        'invalid_response' {
            return [PSCustomObject]@{
                tag_name = ''
            }
        }
        'not_found' {
            $resp = New-MockResponse -Code ([System.Net.HttpStatusCode]::NotFound) -Headers @{}
            throw (New-Object MockHttpException -ArgumentList ('Mock not_found', $resp))
        }
        'auth_error' {
            $resp = New-MockResponse -Code ([System.Net.HttpStatusCode]::Unauthorized) -Headers @{}
            throw (New-Object MockHttpException -ArgumentList ('Mock auth_error', $resp))
        }
        'rate_limited_429' {
            $resp = New-MockResponse -Code ([System.Net.HttpStatusCode]::TooManyRequests) -Headers @{}
            throw (New-Object MockHttpException -ArgumentList ('Mock rate_limited_429', $resp))
        }
        'rate_limited_403' {
            $resp = New-MockResponse -Code ([System.Net.HttpStatusCode]::Forbidden) -Headers @{ 'X-RateLimit-Remaining' = '0' }
            throw (New-Object MockHttpException -ArgumentList ('Mock rate_limited_403', $resp))
        }
        'forbidden_403' {
            $resp = New-MockResponse -Code ([System.Net.HttpStatusCode]::Forbidden) -Headers @{ 'X-RateLimit-Remaining' = '50' }
            throw (New-Object MockHttpException -ArgumentList ('Mock forbidden_403', $resp))
        }
        'server_error' {
            $resp = New-MockResponse -Code ([System.Net.HttpStatusCode]::InternalServerError) -Headers @{}
            throw (New-Object MockHttpException -ArgumentList ('Mock server_error', $resp))
        }
        'http_error' {
            $resp = New-MockResponse -Code ([System.Net.HttpStatusCode]::Found) -Headers @{}
            throw (New-Object MockHttpException -ArgumentList ('Mock http_error', $resp))
        }
        'network_error' {
            throw (New-Object System.Exception('Mock network error'))
        }
        default {
            throw (New-Object System.Exception("Unknown MOCK_SCENARIO: $scenario"))
        }
    }
}
