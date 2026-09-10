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

Write-Output "=== Parse check + EAP=Stop top-level presence for orchestrators ==="
foreach ($name in $orchestrators) {
    $p = Join-Path $lib $name
    $text = Get-Content $p -Raw
    $ast = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errs)
    $parseErr = $errs.Count -gt 0
    # Search for the EAP=Stop line (within first 20 non-comment, non-blank lines)
    $lines = $text -split "`n"
    $eapLine = -1
    $commentLines = 0
    for ($i = 0; $i -lt [Math]::Min(30, $lines.Count); $i++) {
        $t = $lines[$i].Trim()
        if ($t -eq '' -or $t.StartsWith('#')) { continue }
        if ($t -match "^\`$ErrorActionPreference\s*=\s*'Stop'\s*$") {
            $eapLine = $i + 1
            break
        }
    }
    Write-Output ("{0}: PARSE_OK={1} EAP_STOP_LINE={2}" -f $name, (-not $parseErr), $eapLine)
    if ($parseErr) {
        $errs | ForEach-Object { Write-Output ("  ERR: " + $_.Message) }
    }
}

Write-Output ""
Write-Output "=== Parse check for all lib ps1 files ==="
Get-ChildItem $lib -Filter '*.ps1' | ForEach-Object {
    $p = $_.FullName
    $text = Get-Content $p -Raw
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$errs)
    $ok = ($errs.Count -eq 0)
    Write-Output ("{0}: PARSE_OK={1}" -f $_.Name, $ok)
    if (-not $ok) {
        $errs | ForEach-Object { Write-Output ("  ERR[{0}]: {1}" -f $_.Extent.StartLineNumber, $_.Message) }
    }
}
