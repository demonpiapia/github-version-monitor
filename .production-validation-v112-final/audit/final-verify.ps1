Write-Output '=== FINAL VERIFY ==='
Write-Output ('audit file exists: ' + (Test-Path '.production-validation-v112-final/audit/final-status-audit.md'))
Write-Output ('attempt1 preserved: ' + (Test-Path '.production-validation-v112-final/audit-attempt1-fabricated/final-status-audit.md'))
Write-Output ('root audit dir exists: ' + (Test-Path 'audit'))
Write-Output '--- audit dir listing ---'
Get-ChildItem '.production-validation-v112-final/audit' | ForEach-Object { Write-Output ('. ' + $_.Name) }
Write-Output '--- attempt1 backups ---'
Get-ChildItem '.production-validation-v112-final' -Filter '*.attempt1_*' | ForEach-Object { Write-Output ('. ' + $_.Name) }
Write-Output '--- SKILL sha256 post ---'
(Get-FileHash -Algorithm SHA256 'SKILL-v1.12.md').Hash
Write-Output '--- audit file sha256 ---'
(Get-FileHash -Algorithm SHA256 '.production-validation-v112-final/audit/final-status-audit.md').Hash
