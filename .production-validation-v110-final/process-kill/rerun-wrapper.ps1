$ErrorActionPreference='Stop'
$base=$env:GITHUB_VERSION_MONITOR_BASE
$libDir='d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib'
. (Join-Path $libDir 'mock-invoke-restmethod.ps1')
Set-MockScenario -Scenario 'normal' -TagName 'v1.0.0' -PublishedAt '2026-09-01T00:00:00Z'
. (Join-Path $libDir 'step1.ps1')
. (Join-Path $libDir 'step2.ps1')
. (Join-Path $libDir 'step3.ps1')
. (Join-Path $libDir 'step4.ps1')
. (Join-Path $libDir 'step5-full.ps1')