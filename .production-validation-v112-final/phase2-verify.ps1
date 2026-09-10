$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$base = 'D:\AI\Workspace\automatic\github-version-monitor'
$lib  = Join-Path $base '.production-validation-v112-final\lib'

Write-Output "=== step1.ps1 PS7 check excerpt (P1-d) ==="
$s1 = Get-Content (Join-Path $lib 'step1.ps1') -Raw
$lines = $s1 -split "`n"
# Find lines matching PS7 check
$idx = 0
foreach ($l in $lines) {
    $idx++
    if ($l -match "PSVersionTable.PSVersion.Major -lt 7" -or $l -match "RUNTIME_ERROR\|PowerShell 7.x required") {
        Write-Output "HIT line $idx : $l"
    }
}

Write-Output ""
Write-Output "=== step3.ps1 HOUSEKEEPING_WARNING excerpt (P2-a) ==="
$s3 = Get-Content (Join-Path $lib 'step3.ps1') -Raw
$lines = $s3 -split "`n"
$idx = 0
foreach ($l in $lines) {
    $idx++
    if ($l -match "try\s*\{" -or $l -match "catch\s*\{" -or $l -match "HOUSEKEEPING_WARNING") {
        Write-Output "HIT line $idx : $l"
    }
}

Write-Output ""
Write-Output "=== Full step1.ps1 first 30 lines ==="
$lines1 = Get-Content (Join-Path $lib 'step1.ps1')
for ($i = 0; $i -lt 30 -and $i -lt $lines1.Count; $i++) {
    Write-Output ("{0,3}: {1}" -f ($i+1), $lines1[$i])
}

Write-Output ""
Write-Output "=== Full step3.ps1 ==="
$lines3 = Get-Content (Join-Path $lib 'step3.ps1')
for ($i = 0; $i -lt $lines3.Count; $i++) {
    Write-Output ("{0,3}: {1}" -f ($i+1), $lines3[$i])
}

Write-Output ""
Write-Output "=== File sizes ==="
Get-ChildItem $lib -Filter '*.ps1' | Select-Object Name,Length | Format-Table -AutoSize | Out-String | Write-Output

Write-Output "=== SHA256 of each step file ==="
Get-ChildItem $lib -Filter '*.ps1' | Where-Object { $_.Name -match '^step' } | ForEach-Object {
    $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToUpper()
    Write-Output ("{0}  {1}" -f $h, $_.Name)
}
