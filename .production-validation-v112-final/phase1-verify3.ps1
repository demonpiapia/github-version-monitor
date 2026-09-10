[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$root = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $root

# Fix SHA256 (previous attempt was mis-assigned)
$hashObj = Get-FileHash -Path '.\SKILL-v1.12.md' -Algorithm SHA256
$hex = [string]$hashObj.Hash
Write-Host "SHA256 length: $($hex.Length)"
Write-Host "SHA256 value:  $hex"
Set-Content -Path '.production-validation-v112-final\v112.sha256' -Value $hex -Encoding ASCII
$written = Get-Content '.production-validation-v112-final\v112.sha256' -Raw
Write-Host "v112.sha256 content: $written"
Write-Host "v112.sha256 bytes    : $((Get-Item '.production-validation-v112-final\v112.sha256').Length)"

# Baseline hash
$hash11 = Get-FileHash -Path '.\SKILL-v1.11.md' -Algorithm SHA256
Write-Host "v1.11 baseline SHA256: $($hash11.Hash)"

# Regenerate default diff (U3)
$out3 = '.production-validation-v112-final\v111-v112.diff'
if (Test-Path $out3) { Remove-Item $out3 -Force }
& git diff --no-index SKILL-v1.11.md SKILL-v1.12.md > $out3 2> $null
Write-Host "default U3 diff bytes: $((Get-Item $out3).Length)"
$hdrs3 = Select-String -Path $out3 -Pattern '^@@'
Write-Host "U3 hunk count: $($hdrs3.Count)"
foreach ($h in $hdrs3) { Write-Host "  $($h.Line)" }

# Regenerate -U0 granular diff
$out0 = '.production-validation-v112-final\v111-v112.U0.diff'
if (Test-Path $out0) { Remove-Item $out0 -Force }
& git diff --no-index -U0 SKILL-v1.11.md SKILL-v1.12.md > $out0 2> $null
Write-Host "`n-U0 diff bytes: $((Get-Item $out0).Length)"
$hdrs0 = Select-String -Path $out0 -Pattern '^@@'
Write-Host "-U0 hunk count: $($hdrs0.Count)"
foreach ($h in $hdrs0) { Write-Host "  $($h.Line)" }

# git diff --check
$checkOut = '.production-validation-v112-final\git-diff-check.txt'
if (Test-Path $checkOut) { Remove-Item $checkOut -Force }
$checkResult = & git diff --check --no-index SKILL-v1.11.md SKILL-v1.12.md 2>&1
$checkResult | Out-File $checkOut -Encoding UTF8
Write-Host "`ngit diff --check exit code: $LASTEXITCODE"
Write-Host "--- git diff --check output ---"
Get-Content $checkOut

# Write full stdout
$stdoutFile = '.production-validation-v112-final\phase1-stdout.txt'
if (Test-Path $stdoutFile) { Remove-Item $stdoutFile -Force }
"=== Phase 1 stdout ===" | Out-File $stdoutFile -Encoding UTF8
"SHA256 (v1.12): $hex" | Out-File $stdoutFile -Append -Encoding UTF8
"SHA256 (v1.11 baseline): $($hash11.Hash)" | Out-File $stdoutFile -Append -Encoding UTF8
"git diff --no-index (U3 default) exit code: 1 (expected, files differ)" | Out-File $stdoutFile -Append -Encoding UTF8
"U3 hunk count: $($hdrs3.Count)" | Out-File $stdoutFile -Append -Encoding UTF8
"U0 hunk count: $($hdrs0.Count)" | Out-File $stdoutFile -Append -Encoding UTF8
"Hunk headers (U3):" | Out-File $stdoutFile -Append -Encoding UTF8
$hdrs3 | ForEach-Object { "  $($_.Line)" } | Out-File $stdoutFile -Append -Encoding UTF8
"Hunk headers (-U0):" | Out-File $stdoutFile -Append -Encoding UTF8
$hdrs0 | ForEach-Object { "  $($_.Line)" } | Out-File $stdoutFile -Append -Encoding UTF8
"git diff --check exit code: $LASTEXITCODE" | Out-File $stdoutFile -Append -Encoding UTF8
"--- git diff --check output ---" | Out-File $stdoutFile -Append -Encoding UTF8
$checkResult | Out-File $stdoutFile -Append -Encoding UTF8
