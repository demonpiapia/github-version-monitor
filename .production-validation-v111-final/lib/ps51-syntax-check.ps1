# ps51-syntax-check.ps1 — PS5.1 语法解析验证（Phase 1 Step 7.1）
# 用法：powershell.exe -NoProfile -NonInteractive -File ps51-syntax-check.ps1
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$files = @('mock-invoke-restmethod.ps1','step2-mock-harness.ps1')
$errs = 0
foreach ($f in $files) {
    $p = Join-Path $here $f
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $errs++
        Write-Output ('PS51_SYNTAX_ERROR|' + $f + '|' + ($parseErrors | ForEach-Object { $_.Message + ' @L' + $_.Extent.StartLineNumber }) -join '; ')
    } else {
        Write-Output ('PS51_SYNTAX_OK|' + $f)
    }
}
Write-Output ('PS51_TOTAL_ERRORS=' + $errs)
