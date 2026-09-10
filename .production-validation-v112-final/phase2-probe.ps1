param(
    [Parameter(Mandatory=$true)][string]$SourcePath,
    [Parameter(Mandatory=$true)][string]$OutDir
)
Write-Output "SOURCEPATH=[$SourcePath]"
Write-Output "OUTDIR=[$OutDir]"
Write-Output "TESTPATH=" + (Test-Path $SourcePath)
Write-Output "DOTNET=" + ([System.IO.File]::Exists($SourcePath))
