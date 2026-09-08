# PS5.1 mock smoke test - verifies MockHttpException + WebHeaderCollection shape
$ErrorActionPreference = 'Stop'
$env:MOCK_SCENARIO = $args[0]
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib\mock-invoke-restmethod-ps51.ps1'
try {
    $null = Invoke-RestMethod -Uri 'http://x' -Headers @{} -TimeoutSec 5
    Write-Output 'NO_THROW'
} catch {
    $ex = $_.Exception
    Write-Output ('Exception type: ' + $ex.GetType().FullName)
    Write-Output ('Message: ' + $ex.Message)
    Write-Output ('Has Response: ' + ($null -ne $ex.Response))
    if ($null -ne $ex.Response) {
        Write-Output ('StatusCode: ' + $ex.Response.StatusCode)
        Write-Output ('Headers type: ' + $ex.Response.Headers.GetType().FullName)
        $isWHC = ($ex.Response.Headers -is [System.Net.WebHeaderCollection])
        Write-Output ('Is WebHeaderCollection: ' + $isWHC)
        if ($isWHC) {
            $v = $ex.Response.Headers.Get('X-RateLimit-Remaining')
            Write-Output ('X-RateLimit-Remaining: ' + $v)
        }
    }
}
