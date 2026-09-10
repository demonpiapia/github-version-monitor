$ErrorActionPreference = 'Stop'
$err = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    '.production-validation-v112-final\lib\p3-verify.ps1',
    [ref]$tokens,
    [ref]$err)
if ($err.Count -eq 0) {
    Write-Host "PARSE_OK"
} else {
    Write-Host "PARSE_ERRORS=$($err.Count)"
    $err | ForEach-Object {
        Write-Host ("LINE={0} COL={1} MSG={2}" -f $_.Extent.StartLineNumber, $_.Extent.StartColumnNumber, $_.Message)
    }
}
