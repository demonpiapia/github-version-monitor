$ErrorActionPreference = 'Continue'
$tokens = $null; $errors = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile('d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib\step2.ps1', [ref]$tokens, [ref]$errors)
if ($errors.Count -eq 0) { Write-Output 'STEP2_PARSE_OK' } else {
    Write-Output ('STEP2_PARSE_ERRORS: ' + $errors.Count)
    $errors | ForEach-Object { Write-Output ('  L' + $_.Extent.StartLineNumber + ': ' + $_.Message) }
}
