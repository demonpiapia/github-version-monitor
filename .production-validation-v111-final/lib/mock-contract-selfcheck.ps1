# mock-contract-selfcheck.ps1 — Step 7.1 mock contract 对齐自检（Phase 1）
#
# 目的：
#   1) 实测验证 New-MockHttpException 修复（返回 WorkbuddyMock.MockHttpResponseException 而非 PSCustomObject）
#   2) 按 SKILL-v1.11.md L341-367 逐成员模拟访问，逐场景确认取值路径与 contract 表一致
#   3) 记录 PS7 Headers 类型选择、X-RateLimit-Remaining 字符串类型、StatusCode 枚举实例
#
# 输出：lib/mock-contract-selfcheck.txt
# 用法：pwsh -NoProfile -NonInteractive -File mock-contract-selfcheck.ps1

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$outPath = Join-Path $here 'mock-contract-selfcheck.txt'

$lines = New-Object System.Collections.Generic.List[string]
function Out { param([string]$s) $lines.Add($s) }

Out ('MOCK_CONTRACT_SELFCHECK_START|ts={0}' -f ([DateTimeOffset]::UtcNow.ToString('o')))
Out ('PSVERSION={0}' -f $PSVersionTable.PSVersion.ToString())
Out ''

# 载入 mock 库
. (Join-Path $here 'mock-invoke-restmethod.ps1')
Out ('MOCK_LIBRARY_LOADED|path={0}' -f (Join-Path $here 'mock-invoke-restmethod.ps1'))
Out ''

# 定义 SKILL L355/L357 状态机判定函数（逐字复刻，含 Get-ResponseHeaderValue 辅助）
function Get-ResponseHeaderValue {
    param($Headers, [string]$Name)
    try { if ($Headers -is [System.Net.WebHeaderCollection]) { $v = $Headers.Get($Name); if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } } catch {}
    try { $v = $Headers[$Name]; if ($null -ne $v -and [string]$v -ne '') { return [string]$v } } catch {}
    try { $values = $null; if ($Headers.TryGetValues($Name, [ref]$values)) { $first = $values | Select-Object -First 1; if ($null -ne $first) { return [string]$first } } } catch {}
    return ''
}

function Invoke-SkillStateMachine {
    param($ErrorRecord)
    $status = $null; $code = $null; $rl = ''
    # L355
    try { if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.StatusCode) { $code = [int]$ErrorRecord.Exception.Response.StatusCode } } catch {}
    # L357-360
    try {
        if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.Headers) {
            $rl = Get-ResponseHeaderValue $ErrorRecord.Exception.Response.Headers 'X-RateLimit-Remaining'
        }
    } catch { $rl = '' }
    # L361-367
    if     ($code -eq 401)                    { $status = 'auth_error' }
    elseif ($code -eq 404)                    { $status = 'not_found' }
    elseif ($code -eq 429)                    { $status = 'rate_limited' }
    elseif ($code -eq 403)                    { $status = if ($rl -eq '0') { 'rate_limited' } else { 'forbidden' } }
    elseif ($code -and $code -ge 500)         { $status = 'server_error' }
    elseif ($code)                            { $status = 'http_error' }
    else                                      { $status = 'network_error' }
    return [PSCustomObject]@{ status = $status; code = $code; rl = $rl }
}

# 场景定义：(scenario, rateRemaining, expectedStatus)
$scenarios = @(
    [PSCustomObject]@{ Scenario='404';  RateRemaining='50'; Expected='not_found'    }
    [PSCustomObject]@{ Scenario='401';  RateRemaining='50'; Expected='auth_error'   }
    [PSCustomObject]@{ Scenario='429';  RateRemaining='0';  Expected='rate_limited' }
    [PSCustomObject]@{ Scenario='403';  RateRemaining='0';  Expected='rate_limited' }
    [PSCustomObject]@{ Scenario='403';  RateRemaining='50'; Expected='forbidden'    }
    [PSCustomObject]@{ Scenario='500';  RateRemaining='50'; Expected='server_error' }
    [PSCustomObject]@{ Scenario='302';  RateRemaining='50'; Expected='http_error'   }
    [PSCustomObject]@{ Scenario='network_error'; RateRemaining='50'; Expected='network_error' }
)

$passCount = 0; $failCount = 0
$allHeadersTypes = @{}
$allRlTypes = @{}
$allStatusCodes = @{}

foreach ($s in $scenarios) {
    $script:MockScenario = $s.Scenario
    $script:MockRateRemaining = $s.RateRemaining
    $tag = ('SCENARIO|{0}|rateRemaining={1}' -f $s.Scenario, $s.RateRemaining)
    Out $tag

    $errRecord = $null
    try {
        $null = Invoke-RestMethod -Uri 'https://api.github.com/repos/x/y/releases/latest' -Headers @{} -TimeoutSec 20
        Out '  RESULT|NO_EXCEPTION_THROWN|FAIL (expected exception)'
        $failCount++
        continue
    } catch {
        $errRecord = $_
    }

    # 断言 1：$_ .Exception.Response 可访问
    $resp = $errRecord.Exception.Response
    $respType = if ($resp -ne $null) { $resp.GetType().FullName } else { '<null>' }
    Out ('  EXCEPTION_TYPE={0}' -f $errRecord.Exception.GetType().FullName)
    Out ('  RESPONSE_TYPE={0}' -f $respType)

    if ($s.Scenario -eq 'network_error') {
        # 期望 Response = $null
        if ($resp -eq $null) {
            Out '  RESPONSE_NULL|PASS'
        } else {
            Out ('  RESPONSE_NULL|FAIL|got={0}' -f $respType)
            $failCount++
            continue
        }
    } else {
        if ($resp -eq $null) {
            Out '  RESPONSE_NULL|FAIL|expected non-null'
            $failCount++
            continue
        }
        # 断言 2：StatusCode 可访问且值正确
        $sc = $resp.StatusCode
        $scType = $sc.GetType().FullName
        $scInt = [int]$sc
        $allStatusCodes[$s.Scenario] = '{0}={1}' -f $scType, $scInt
        $expectedCode = [int]$s.Scenario
        if ($scInt -eq $expectedCode) {
            Out ('  STATUSCODE={0}|type={1}|int={2}|expected={3}|PASS' -f $sc, $scType, $scInt, $expectedCode)
        } else {
            Out ('  STATUSCODE|FAIL|got={0}|expected={1}' -f $scInt, $expectedCode)
            $failCount++
            continue
        }
        # 断言 3：Headers 类型 = System.Net.WebHeaderCollection
        $headers = $resp.Headers
        $hType = $headers.GetType().FullName
        $allHeadersTypes[$s.Scenario] = $hType
        if ($hType -eq 'System.Net.WebHeaderCollection') {
            Out ('  HEADERS_TYPE={0}|PASS' -f $hType)
        } else {
            Out ('  HEADERS_TYPE|FAIL|got={0}|expected=System.Net.WebHeaderCollection' -f $hType)
            $failCount++
            continue
        }
        # 断言 4：X-RateLimit-Remaining 返回字符串
        $rl = $headers['X-RateLimit-Remaining']
        $rlType = if ($rl -ne $null) { $rl.GetType().FullName } else { '<null>' }
        $allRlTypes[$s.Scenario] = '{0}={1}' -f $rlType, $rl
        if ($rl -is [string] -and $rl -eq $s.RateRemaining) {
            Out ('  RATELIMIT_REMAINING|value={0}|type={1}|expected={2}|PASS' -f $rl, $rlType, $s.RateRemaining)
        } else {
            Out ('  RATELIMIT_REMAINING|FAIL|value={0}|type={1}|expected={2}' -f $rl, $rlType, $s.RateRemaining)
            $failCount++
            continue
        }
    }

    # 断言 5：状态机判定
    $decision = Invoke-SkillStateMachine $errRecord
    $gotStatus = $decision.status
    if ($gotStatus -eq $s.Expected) {
        Out ('  STATE_MACHINE|status={0}|code={1}|rl={2}|expected={3}|PASS' -f $gotStatus, $decision.code, $decision.rl, $s.Expected)
        $passCount++
    } else {
        Out ('  STATE_MACHINE|FAIL|status={0}|expected={1}' -f $gotStatus, $s.Expected)
        $failCount++
    }
    Out ''
}

Out ('=== SUMMARY ===')
Out ('PASS_COUNT={0}' -f $passCount)
Out ('FAIL_COUNT={0}' -f $failCount)
Out ''

Out ('=== HEADERS_RUNTIME_TYPES ===')
foreach ($k in $allHeadersTypes.Keys | Sort-Object) { Out ('  {0}: {1}' -f $k, $allHeadersTypes[$k]) }
Out ''

Out ('=== RATELIMIT_REMAINING_TYPES ===')
foreach ($k in $allRlTypes.Keys | Sort-Object) { Out ('  {0}: {1}' -f $k, $allRlTypes[$k]) }
Out ''

Out ('=== STATUSCODE_TYPES ===')
foreach ($k in $allStatusCodes.Keys | Sort-Object) { Out ('  {0}: {1}' -f $k, $allStatusCodes[$k]) }
Out ''

Out ('=== CONTRACT_ALIGNMENT_NOTES ===')
Out 'PS7_HEADERS_TYPE_CHOICE=System.Net.WebHeaderCollection'
Out 'REASON: 与 PS5.1 共用同一 mock 库；WebHeaderCollection 支持索引器访问与 .Get(name) 方法，'
Out '       SKILL L357-358 通过 Get-ResponseHeaderValue 函数封装访问（先 .Get()，再索引器，再 TryGetValues），两者兼容。'
Out '       未选 HttpResponseHeaders 形状对象：构造复杂度高，且 PS5.1 环境下不可用（.NET Framework 4.5+ 才有）。'
Out 'X_RATELIMIT_REMAINING_TYPE=string (SKILL L364 用 -eq 字符串比较，故 mock 侧必须为 string 类型)'
Out 'STATUSCODE_TYPE=System.Net.HttpStatusCode enum instance (SKILL L355 用 [int] 显式转换，枚举实例可无损转换)'
Out 'EXCEPTION_TYPE=WorkbuddyMock.MockHttpResponseException (真实 Exception 子类，非 PSCustomObject)'
Out 'EXCEPTION_TYPE_REASON: throw PSCustomObject 时 $_.Exception 被包装为 RuntimeException，'
Out '                      原始自定义属性全部丢失，导致 $_.Exception.Response = $null，所有异常场景误判为 network_error。'
Out 'RESPONSE_TYPE=WorkbuddyMock.MockHttpResponse (C# 类型，非 PSCustomObject)'
Out 'RESPONSE_TYPE_REASON: PSCustomObject 有内置 Headers 属性（返回 string），会 shadow 自定义 Headers 属性。'
Out 'HEADERS_RETURN_TYPE_FIX: New-MockResponseHeaders 使用 Write-Output -NoEnumerate 而非 return，'
Out '                        因为 WebHeaderCollection 实现 ICollection，return 会被 PowerShell 自动枚举展开为 string。'
Out ''

if ($failCount -eq 0) {
    Out 'MOCK_CONTRACT_SELFCHECK_RESULT=PASS'
    Out ('MOCK_CONTRACT_SELFCHECK_END|ts={0}' -f ([DateTimeOffset]::UtcNow.ToString('o')))
} else {
    Out ('MOCK_CONTRACT_SELFCHECK_RESULT=FAIL|failCount={0}' -f $failCount)
    Out ('MOCK_CONTRACT_SELFCHECK_END|ts={0}' -f ([DateTimeOffset]::UtcNow.ToString('o')))
}

[System.IO.File]::WriteAllLines($outPath, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Output ('SELFCHECK_WRITTEN|path={0}|pass={1}|fail={2}' -f $outPath, $passCount, $failCount)
