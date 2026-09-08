$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
& (Join-Path $lib 'step1.ps1')
& (Join-Path $lib 'step2.ps1')
& (Join-Path $lib 'step3.ps1')
# Apply ACL deny on .output
$outputDir = Join-Path $base '.output'
$acl = Get-Acl $outputDir
$denyRule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, 'CreateFiles', 'Deny')
$acl.SetAccessRule($denyRule)
Set-Acl -Path $outputDir -AclObject $acl
# Run step5-full (Set-Content $tmp will fail)
& (Join-Path $lib 'step5-full.ps1')
# Restore ACL
$restoredAcl = Import-Clixml -Path (Join-Path $base 'acl-before.xml')
Set-Acl -Path $outputDir -AclObject $restoredAcl
