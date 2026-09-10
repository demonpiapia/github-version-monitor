$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

$lib = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v112-final\lib'
Write-Output "=== SHA256 of all lib files ==="
Get-ChildItem $lib -File | Sort-Object Name | ForEach-Object {
    $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToUpper()
    Write-Output ("{0}  {1}  {2}" -f $h, $_.Length, $_.Name)
}

Write-Output ""
Write-Output "=== SKILL-v1.12.md final hash verification ==="
$sha = (Get-FileHash -Algorithm SHA256 'D:\AI\Workspace\automatic\github-version-monitor\SKILL-v1.12.md').Hash.ToUpper()
Write-Output ("SKILL SHA256: {0}" -f $sha)
$expected = '3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9'
Write-Output ("Expected:     {0}" -f $expected)
Write-Output ("MATCH:        {0}" -f ($sha -ceq $expected))
