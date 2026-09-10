OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ErrorActionPreference = 'Stop'

$paths = @(
  '.production-validation-v112-final/T2-success/stdout.txt',
  '.production-validation-v112-final/T4-write-failure/stdout.txt',
  '.production-validation-v112-final/T5-housekeeping/stdout.txt',
  'SKILL-v1.12.md'
)

foreach ($p in $paths) {
  $h = Get-FileHash -Algorithm SHA256 $p
  $lines = Get-Content $p
  Write-Output ("PATH=" + $p)
  Write-Output ("SHA256=" + $h.Hash)
  Write-Output ("LINE_COUNT=" + $lines.Count)
  Write-Output "----GREP----"
  for ($i = 0; $i -lt $lines.Count; $i++) {
    $ln = $lines[$i]
    if ($ln -match 'RUN_STATUS\|success\|')   { Write-Output ("SUCCESS_LINE_" + ($i+1) + ": " + $ln) }
    if ($ln -match 'RUN_STATUS\|failed\|')    { Write-Output ("FAILED_LINE_"  + ($i+1) + ": " + $ln) }
    if ($ln -match 'HOUSEKEEPING_WARNING\|')  { Write-Output ("HW_LINE_"      + ($i+1) + ": " + $ln) }
  }
  $content = Get-Content $p -Raw
  Write-Output ("RUN_STATUS_SUCCESS_COUNT=" + ([regex]::Matches($content,'RUN_STATUS\|success\|')).Count)
  Write-Output ("RUN_STATUS_FAILED_COUNT="  + ([regex]::Matches($content,'RUN_STATUS\|failed\|')).Count)
  Write-Output ("HOUSEKEEPING_WARNING_COUNT=" + ([regex]::Matches($content,'HOUSEKEEPING_WARNING\|')).Count)
  Write-Output "====END===="
}
