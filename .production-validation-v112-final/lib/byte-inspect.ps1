param([string]$Path, [int]$LineNum)
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
$b = [System.IO.File]::ReadAllBytes($Path)
Write-Output "TotalBytes=$($b.Length)"
$lineStarts = @(0)
for ($i = 0; $i -lt $b.Length; $i++) {
    if ($b[$i] -eq 10) { $lineStarts += ($i + 1) }
}
Write-Output "TotalLines=$($lineStarts.Count)"
$idx = [Math]::Min($LineNum, $lineStarts.Count)
$lineStart = $lineStarts[$idx - 1]
$lineEnd = if ($idx -lt $lineStarts.Count) { $lineStarts[$idx] - 1 } else { $b.Length - 1 }
$chunk = $b[$lineStart..$lineEnd]
Write-Output "Line$LineNum Length=$($chunk.Length)"
Write-Output ([System.BitConverter]::ToString($chunk) -replace '-',' ')
