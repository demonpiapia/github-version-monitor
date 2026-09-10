$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\lib'

$orchestrators = @(
    'run-full-pipeline.ps1',
    't3-mock-harness.ps1',
    't4-write-failure-harness.ps1',
    't5-housekeeping-harness.ps1'
)

$dollar = [char]36  # $

Write-Output '=== EAP=Stop top-level verification for 4 orchestrators ==='
foreach ($name in $orchestrators) {
    $p = Join-Path $lib $name
    $lines = Get-Content $p
    $found = -1
    $lineNo = 0
    foreach ($line in $lines) {
        $lineNo++
        if ($lineNo -gt 30) { break }
        $t = $line.Trim()
        $needle = $dollar + 'ErrorActionPreference'
        if ($t.StartsWith($needle)) {
            if ($t.Contains("'Stop'") -or $t.Contains('"Stop"') -or $t.Contains('=Stop')) {
                $found = $lineNo
                break
            }
        }
    }
    Write-Output ($name + ': EAP_STOP_TOP_LINE=' + $found)
}
