$ErrorActionPreference='Stop'
$base=$env:GITHUB_VERSION_MONITOR_BASE
$libDir='d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib'
. (Join-Path $libDir 'step1.ps1')
. (Join-Path $libDir 'step2.ps1')
. (Join-Path $libDir 'step3.ps1')
. (Join-Path $libDir 'step4.ps1')
$lockPath = Join-Path $base '.monitor\run.lock'
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
$lockValue = 'pid=999999;start=' + $nowUtc + ';step=4;beat=' + $nowUtc
Set-Content -Path $lockPath -Value $lockValue
Write-Output "OWNERSHIP_INJECTED|pid=999999"
. (Join-Path $libDir 'step5-full.ps1')