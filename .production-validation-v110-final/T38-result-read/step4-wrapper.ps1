$ErrorActionPreference = 'Continue'
$env:GITHUB_VERSION_MONITOR_BASE = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T38-result-read'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step1.ps1'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step2.ps1'
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step3.ps1'
$resultPath = Join-Path $env:GITHUB_VERSION_MONITOR_BASE '.monitor\result.json'
Remove-Item $resultPath -Force -ErrorAction SilentlyContinue
. 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\lib\step4.ps1'
