$ErrorActionPreference = 'Continue'
$env:GITHUB_VERSION_MONITOR_BASE = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T38-A'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step1.ps1'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step2.ps1'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step3.ps1'
$monitorDir = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.monitor'
$tmpPath = Join-Path $monitorDir 'result.review.tmp'
if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue }
$aclBeforeFile = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T38-A\acl-before.xml'
Get-Acl $monitorDir | Export-Clixml $aclBeforeFile
$user = $env:USERNAME
$identity = New-Object System.Security.Principal.NTAccount($user)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, [System.Security.AccessControl.FileSystemRights]::CreateFiles, [System.Security.AccessControl.AccessControlType]::Deny)
$acl = Get-Acl $monitorDir
$acl.SetAccessRule($rule)
Set-Acl $monitorDir $acl
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step4.ps1'
$acl = Import-Clixml $aclBeforeFile
Set-Acl $monitorDir $acl
