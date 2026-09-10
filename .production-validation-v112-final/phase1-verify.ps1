[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $root

# Recompute SHA256 explicitly
$hash = Get-FileHash .\SKILL-v1.12.md -Algorithm SHA256
$hexStr = $hash.Hex
Write-Host "SHA256 = $hexStr"
$hexStr | Out-File '.production-validation-v112-final\v112.sha256' -Encoding ascii
Write-Host "File size:"
(Get-Item '.production-validation-v112-final\v112.sha256').Length

# Check hunk diff with minimal context
Write-Host "`n=== MINIMAL CONTEXT (U0) ==="
& git diff --no-index -U0 SKILL-v1.11.md SKILL-v1.12.md | Select-String '^@@'
$hunks0 = & git diff --no-index -U0 SKILL-v1.11.md SKILL-v1.12.md | Select-String '^@@'
Write-Host "Hunk count with -U0 = $($hunks0.Count)"

Write-Host "`n=== DEFAULT CONTEXT (U3) ==="
$hunks3 = & git diff --no-index SKILL-v1.11.md SKILL-v1.12.md | Select-String '^@@'
Write-Host "Hunk count with -U3 (default) = $($hunks3.Count)"
$hunks3 | ForEach-Object { $_.Line }

# Check baseline line 689-700 area in v1.11 vs v1.12 to confirm merge
Write-Host "`n=== v1.12 §9 area (lines 700-720) ==="
$lines = Get-Content '.\SKILL-v1.12.md'
for ($i = 700; $i -le 720; $i++) {
    Write-Host ("L{0}: {1}" -f $i, $lines[$i-1])
}
