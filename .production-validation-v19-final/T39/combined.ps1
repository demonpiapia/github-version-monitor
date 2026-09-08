$ErrorActionPreference = 'Continue'
$base = $env:GITHUB_VERSION_MONITOR_BASE
$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
. (Join-Path $lib 'step1.ps1')
. (Join-Path $lib 'step2.ps1')
. (Join-Path $lib 'step3.ps1')
. (Join-Path $lib 'step4.ps1')
. (Join-Path $lib 'step5-t39-harness.ps1')
