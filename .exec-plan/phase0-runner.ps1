# Runner: captures stdout and stderr separately, writes each to its own evidence file.
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$stdoutPath = Join-Path '.production-validation-v112-final' 'phase0-stdout.txt'
$stderrPath = Join-Path '.production-validation-v112-final' 'phase0-stderr.txt'

# Clear both first
@() | Set-Content -Path $stdoutPath -Encoding UTF8
@() | Set-Content -Path $stderrPath -Encoding UTF8

# Capture both streams. $stdout = Write-Output (native stdout). $errors = Write-Error/Write-Host-err.
$stdout = & pwsh.exe -NoProfile -NonInteractive -File '.exec-plan/phase0-exec.ps1' 3>&1
$errors = $stdout | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
$text = $stdout | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }

# Write captured text
$text | Set-Content -Path $stdoutPath -Encoding UTF8
$errors | ForEach-Object { $_.ToString() } | Set-Content -Path $stderrPath -Encoding UTF8

Write-Output ("STDOUT_LINES=" + @($text).Count)
Write-Output ("STDERR_LINES=" + @($errors).Count)
Write-Output ("EXIT=$LASTEXITCODE")
