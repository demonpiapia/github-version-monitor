[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$root = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $root

$stdout = Join-Path $root '.production-validation-v112-final\phase1-stdout.txt'
$stderr = Join-Path $root '.production-validation-v112-final\phase1-stderr.txt'
$diffFile = Join-Path $root '.production-validation-v112-final\v111-v112.diff'

# Clear prior
if (Test-Path $stdout) { Remove-Item $stdout -Force }
if (Test-Path $stderr) { Remove-Item $stderr -Force }

# --- 1. git diff --no-index -> diff file (stdout), stderr captured
# --- 2. git diff --check --no-index -> stdout/stderr for whitespace errors
# --- 3. Compute SHA256
# --- 4. Extract per-hunk info

"=== STEP 6a: git diff --no-index (writing to $diffFile) ===" | Out-File $stdout -Encoding utf8
git diff --no-index SKILL-v1.11.md SKILL-v1.12.md > $diffFile 2>>$stderr
$rc1 = $LASTEXITCODE
"rc1(diff)=$rc1" | Out-File $stdout -Append -Encoding utf8
"diffFileBytes=$((Get-Item $diffFile).Length)" | Out-File $stdout -Append -Encoding utf8

"=== STEP 6b: git diff --check --no-index ===" | Out-File $stdout -Append -Encoding utf8
& git diff --check --no-index SKILL-v1.11.md SKILL-v1.12.md *>&1 | Out-File $stdout -Append -Encoding utf8
$rc2 = $LASTEXITCODE
"rc2(check)=$rc2" | Out-File $stdout -Append -Encoding utf8

"=== STEP 9: SHA256 ===" | Out-File $stdout -Append -Encoding utf8
$hash = Get-FileHash .\SKILL-v1.12.md -Algorithm SHA256
$hash.Hex | Out-File '.production-validation-v112-final\v112.sha256' -Encoding utf8
"SHA256=$($hash.Hex)" | Out-File $stdout -Append -Encoding utf8

"=== STEP 6c: hunk headers ===" | Out-File $stdout -Append -Encoding utf8
Select-String -Path $diffFile -Pattern '^@@' | ForEach-Object { $_.Line } | Out-File $stdout -Append -Encoding utf8

"=== STEP 6d: hunk count ===" | Out-File $stdout -Append -Encoding utf8
$hunks = Select-String -Path $diffFile -Pattern '^@@'
"hunkCount=$($hunks.Count)" | Out-File $stdout -Append -Encoding utf8

"=== DONE ===" | Out-File $stdout -Append -Encoding utf8

Write-Host "rc1=$rc1 rc2=$rc2 sha256=$($hash.Hex) hunks=$($hunks.Count)"
