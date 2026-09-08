# 为 schema 每个输入目录生成 test-report.md
$ErrorActionPreference = 'Continue'
$root = "d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final"
$schemaBase = Join-Path $root 'schema'
$fence = '```'

Get-ChildItem -Path $schemaBase -Directory | ForEach-Object {
    $subBase = $_.FullName
    $inputName = $_.Name
    $stdout = Get-Content (Join-Path $subBase 'stdout.txt') -Raw -ErrorAction SilentlyContinue
    $mdBefore = Get-Content (Join-Path $subBase 'md-before.md') -Raw -ErrorAction SilentlyContinue
    $mdAfter = Get-Content (Join-Path $subBase 'md-after.md') -Raw -ErrorAction SilentlyContinue
    $shaBefore = Get-Content (Join-Path $subBase 'sha256-before.txt') -Raw -ErrorAction SilentlyContinue
    $shaAfter = Get-Content (Join-Path $subBase 'sha256-after.txt') -Raw -ErrorAction SilentlyContinue
    $lockAfter = Get-Content (Join-Path $subBase 'lock-after.txt') -Raw -ErrorAction SilentlyContinue

    # 判定
    $hasParseError = $stdout -match 'PARSE_ERROR'
    $hasFetchComplete = $stdout -match 'FETCH_COMPLETE'
    $mdUnchanged = ($shaBefore -eq $shaAfter)
    $lockReleased = ($lockAfter -match 'lock released')

    $expected = if ($inputName -in @('yes','no')) { 'valid' } else { 'PARSE_ERROR' }
    $verdict = 'PASS'
    if ($expected -eq 'valid') {
        if ($hasParseError -or -not $hasFetchComplete) { $verdict = 'FAIL' }
    } else {
        if (-not $hasParseError -or -not $mdUnchanged -or -not $lockReleased) { $verdict = 'FAIL' }
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Schema Test: input='$inputName'")
    $lines.Add("")
    $lines.Add("## Expected")
    $lines.Add("- $expected")
    $lines.Add("")
    $lines.Add("## Actual")
    $lines.Add("- PARSE_ERROR: $hasParseError")
    $lines.Add("- FETCH_COMPLETE: $hasFetchComplete")
    $lines.Add("- md unchanged: $mdUnchanged")
    $lines.Add("- lock released: $lockReleased")
    $lines.Add("")
    $lines.Add("## SHA256")
    $lines.Add("- before: $shaBefore")
    $lines.Add("- after: $shaAfter")
    $lines.Add("")
    $lines.Add("## Stdout")
    $lines.Add($fence)
    if ($stdout) { $lines.Add($stdout) }
    $lines.Add($fence)
    $lines.Add("")
    $lines.Add("## Verdict")
    $lines.Add("$verdict")

    ($lines -join "`r`n") | Set-Content (Join-Path $subBase 'test-report.md') -Encoding UTF8
    Write-Output "$verdict  schema/$inputName/test-report.md"
}
