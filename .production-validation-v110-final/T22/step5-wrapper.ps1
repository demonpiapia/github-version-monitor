$ErrorActionPreference = 'Continue'
$env:GITHUB_VERSION_MONITOR_BASE = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T22'
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step1.ps1'
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step2.ps1'
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step3.ps1'
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step4.ps1'
$outputDir = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.output'
$tmpPath = Join-Path $outputDir 'GitHub更新监测列表.md.tmp'
if (Test-Path $tmpPath) { Remove-Item $tmpPath -Force -ErrorAction SilentlyContinue; Write-Output 'T22_PRECHECK|removed existing md.tmp' }
$aclBeforeFile = 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T22\acl-before.xml'
Get-Acl $outputDir | Export-Clixml $aclBeforeFile
$user = $env:USERNAME
$identity = New-Object System.Security.Principal.NTAccount($user)
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule($identity, [System.Security.AccessControl.FileSystemRights]::CreateFiles, [System.Security.AccessControl.AccessControlType]::Deny)
$acl = Get-Acl $outputDir
$acl.SetAccessRule($rule)
Set-Acl $outputDir $acl
. 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step5-full.ps1'
$acl = Import-Clixml $aclBeforeFile
Set-Acl $outputDir $acl
