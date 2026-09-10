$ts = Get-Date -Format 'yyyyMMdd_HHmmss'
foreach ($f in 'phase6-stdout.txt','phase6-stderr.txt','phase6-report.md','phase-progress.json') {
  $src = '.production-validation-v112-final\' + $f
  if (Test-Path $src) {
    Copy-Item $src ($src + '.attempt1_' + $ts) -Force
    Write-Output ('BACKUP=' + $f + ' -> ' + $f + '.attempt1_' + $ts)
  } else {
    Write-Output ('NO_BACKUP=' + $f)
  }
}
