[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $root

# --- Recompute SHA256 with explicit string handling ---
$hashObj = Get-FileHash -Path '.\SKILL-v1.12.md' -Algorithm SHA256
$hex = [string]$hashObj.Hash
Write-Host "SHA256 hex length: $($hex.Length)"
Write-Host "SHA256 hex value : $hex"
Set-Content -Path '.production-validation-v112-final\v112.sha256' -Value $hex -Encoding ASCII
$writtenBack = Get-Content '.production-validation-v112-final\v112.sha256' -Raw
Write-Host "v112.sha256 file content: $writtenBack"
Write-Host "v112.sha256 file size    : $((Get-Item '.production-validation-v112-final\v112.sha256').Length)"

# --- Also record v1.11 baseline SHA256 for comparison ---
$hash11 = Get-FileHash -Path '.\SKILL-v1.11.md' -Algorithm SHA256
$hex11 = [string]$hash11.Hash
Write-Host "v1.11 SHA256 = $hex11"

# --- Emit unified diff (default U3) ---
$out3 = '.production-validation-v112-final\v111-v112.diff'
$err3 = '.production-validation-v112-final\v111-v112.diff.stderr'
if (Test-Path $out3) { Remove-Item $out3 -Force }
if (Test-Path $err3) { Remove-Item $err3 -Force }
& git diff --no-index SKILL-v1.11.md SKILL-v1.12.md > $out3 2> $err3
$rc3 = $LASTEXITCODE
Write-Host "git diff --no-index (U3) rc=$rc3 bytes=$((Get-Item $out3).Length)"

# --- Emit diff with -U0 for granular hunk count ---
$out0 = '.production-validation-v112-final\v111-v112.U0.diff'
if (Test-Path $out0) { Remove-Item $out0 -Force }
& git diff --no-index -U0 SKILL-v1.11.md SKILL-v1.12.md > $out0 2> $null
$rc0 = $LASTEXITCODE
Write-Host "git diff --no-index -U0 rc=$rc0 bytes=$((Get-Item $out0).Length)"

# --- hunk headers, both views ---
$hdrs3 = Select-String -Path $out3 -Pattern '^@@'
$hdrs0 = Select-String -Path $out0 -Pattern '^@@'
Write-Host "Hunk count (U3 default): $($hdrs3.Count)"
Write-Host "Hunk count (U0 minimal): $($hdrs0.Count)"

# --- git diff --check ---
$checkOut = '.production-validation-v112-final\git-diff-check.txt'
if (Test-Path $checkOut) { Remove-Item $checkOut -Force }
& git diff --check --no-index SKILL-v1.11.md SKILL-v1.12.md *>&1 | Out-File $checkOut -Encoding UTF8
$rcCheck = $LASTEXITCODE
Write-Host "git diff --check rc=$rcCheck"
Write-Host "--- check output ---"
Get-Content $checkOut

# --- Hunk contents summary ---
Write-Host "`n=== Hunks (U3 default) with contents ==="
$allLines = Get-Content $out3
$idx = 0
$hunkNum = 0
while ($idx -lt $allLines.Count) {
    if ($allLines[$idx] -match '^@@') {
        $hunkNum++
        Write-Host "  Hunk $hunkNum : $($allLines[$idx])"
        # Print next 20 lines of context
        $end = [Math]::Min($idx+20, $allLines.Count)
        for ($j = $idx+1; $j -lt $end; $j++) {
            Write-Host "    $($allLines[$j])"
        }
        Write-Host ""
    }
    $idx++
}
