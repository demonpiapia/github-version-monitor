param(
    [Parameter(Mandatory=$true)][string]$SourceFile,
    [Parameter(Mandatory=$true)][int]$StartLine,
    [Parameter(Mandatory=$true)][int]$EndLine,
    [Parameter(Mandatory=$true)][string]$OutputFile
)
$ErrorActionPreference = 'Stop'
if ($StartLine -lt 1 -or $EndLine -lt $StartLine) { throw "Invalid line range: $StartLine..$EndLine" }
$lines = Get-Content $SourceFile
if ($EndLine -gt $lines.Count) { throw "EndLine $EndLine exceeds file length $($lines.Count)" }
$slice = $lines[($StartLine-1)..($EndLine-1)]
Set-Content -Path $OutputFile -Value $slice -Encoding UTF8
Write-Output "EXTRACT_OK|$OutputFile|L$StartLine-L$EndLine|$($slice.Count) lines"
