# Local HTTP mock listener for testing github-version-monitor pipeline.
# Uses System.Net.HttpListener to intercept api.github.com / github.com requests
# during validation. Configure responses per path via -Routes.
#
# Usage (run in a background job, then kill when done):
#   $job = Start-Job -ScriptBlock { param($p,$r) & '.\mock-listener.ps1' -Port $p -Routes $r } -ArgumentList 18080 @(@{Path='/repos/octo/Hello/releases/latest';Status=200;Body='{"tag_name":"v1.0.0","published_at":"2026-09-01T00:00:00Z"}'})
#   Stop-Job $job; Remove-Job $job
#
# Note: To route api.github.com -> localhost, use a hosts file entry or
# override the base URL in the test harness. This listener only binds to 127.0.0.1.
param(
    [int]$Port = 18080,
    [string]$BindHost = '127.0.0.1',
    [array]$Routes = @(),
    [int]$MaxRequests = 0,   # 0 = unlimited
    [string]$LogPath = ''
)
$ErrorActionPreference = 'Stop'
$prefix = "http://${BindHost}:${Port}/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Output "MOCK_LISTENER|listening on $prefix  routes=$($Routes.Count) max=$MaxRequests"

if ($LogPath) { New-Item -ItemType File -Force -Path $LogPath | Out-Null }

function Find-Route([string]$Path) {
    foreach ($r in $Routes) {
        if ($r.Path -eq $Path) { return $r }
    }
    return $null
}

$count = 0
try {
    while ($listener.IsListening) {
        if ($MaxRequests -gt 0 -and $count -ge $MaxRequests) { break }
        $ctx = $listener.GetContext()
        $count++
        $reqPath = $ctx.Request.Url.AbsolutePath
        $reqMethod = $ctx.Request.HttpMethod
        $route = Find-Route $reqPath
        $status = 404
        $body   = ''
        $respHeaders = @{}
        if ($route) {
            $status = [int]($route.Status)
            $body   = [string]($route.Body)
            $respHeaders = [hashtable]($route.Headers)
        }
        if ($LogPath) {
            Add-Content -Path $LogPath -Value ("[{0}] {1} {2} -> {3}" -f (Get-Date -Format o), $reqMethod, $reqPath, $status) -Encoding UTF8
        }
        $resp = $ctx.Response
        $resp.StatusCode = $status
        foreach ($k in $respHeaders.Keys) {
            try { $resp.Headers.Add($k, $respHeaders[$k]) } catch { $resp.AddHeader($k, $respHeaders[$k]) }
        }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
        $resp.ContentLength64 = $bytes.Length
        $resp.OutputStream.Write($bytes, 0, $bytes.Length)
        $resp.OutputStream.Close()
        $resp.Close()
    }
} finally {
    try { $listener.Stop(); $listener.Close() } catch {}
}
Write-Output "MOCK_LISTENER|stopped after $count requests"
