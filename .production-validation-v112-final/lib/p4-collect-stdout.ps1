$ErrorActionPreference = 'Stop'
$base = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final'

# stdout.txt: concatenated T3 + T4 raw SKILL pipeline stdout
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("PHASE4_BEGIN")
$lines.Add("")
$t3 = @([string[]](Get-Content (Join-Path $base 'T3-api-failure\stdout.txt') -Encoding UTF8))
$header3 = "-- T3-api-failure/stdout.txt (" + $t3.Count + " lines) --"
$lines.Add($header3)
foreach ($L in $t3) { $lines.Add($L) }
$lines.Add("")
$t4 = @([string[]](Get-Content (Join-Path $base 'T4-write-failure\stdout.txt') -Encoding UTF8))
$header4 = "-- T4-write-failure/stdout.txt (" + $t4.Count + " lines) --"
$lines.Add($header4)
foreach ($L in $t4) { $lines.Add($L) }
$lines.Add("")
$lines.Add("PHASE4_END")
[System.IO.File]::WriteAllLines((Join-Path $base 'phase4-stdout.txt'), $lines, (New-Object System.Text.UTF8Encoding($false)))

# stderr.txt
$lines2 = New-Object System.Collections.Generic.List[string]
$lines2.Add("PHASE4_BEGIN_STDERR")
$lines2.Add("")
$t3e = @([string[]]@())
$p3e = Join-Path $base 'T3-api-failure\stderr.txt'
if (Test-Path $p3e) { $t3e = @([string[]](Get-Content $p3e -Encoding UTF8)) }
$lines2.Add("-- T3-api-failure/stderr.txt (" + $t3e.Count + " lines) --")
foreach ($L in $t3e) { $lines2.Add($L) }
$lines2.Add("")
$t4e = @([string[]]@())
$p4e = Join-Path $base 'T4-write-failure\stderr.txt'
if (Test-Path $p4e) { $t4e = @([string[]](Get-Content $p4e -Encoding UTF8)) }
$lines2.Add("-- T4-write-failure/stderr.txt (" + $t4e.Count + " lines) --")
foreach ($L in $t4e) { $lines2.Add($L) }
$lines2.Add("")
$lines2.Add("PHASE4_END_STDERR")
[System.IO.File]::WriteAllLines((Join-Path $base 'phase4-stderr.txt'), $lines2, (New-Object System.Text.UTF8Encoding($false)))

$sz1 = (Get-Item (Join-Path $base 'phase4-stdout.txt')).Length
$sz2 = (Get-Item (Join-Path $base 'phase4-stderr.txt')).Length
Write-Host ("phase4-stdout.txt bytes={0} lines={1}" -f $sz1, $lines.Count)
Write-Host ("phase4-stderr.txt bytes={0} lines={1}" -f $sz2, $lines2.Count)
