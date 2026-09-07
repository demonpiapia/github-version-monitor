# T41 - Token Unset
# Run the pipeline with GITHUB_TOKEN explicitly unset
# Verify: stats.token=unset in result.json

$ErrorActionPreference = 'Continue'
$baseDir = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T37-T43'
$testDir = Join-Path $baseDir 'T41'
$libDir = Join-Path $baseDir 'lib'
$mdPath = Join-Path $testDir 'GitHub更新监测列表.md'
$monitorDir = Join-Path $testDir '.monitor'

# Clean any previous test artifacts
if (Test-Path (Join-Path $testDir '.monitor')) { Remove-Item (Join-Path $testDir '.monitor') -Recurse -Force }
if (Test-Path $mdPath) { Remove-Item $mdPath -Force }
# Make sure no .env file exists in test dir
$envFilePath = Join-Path $testDir '.env'
if (Test-Path $envFilePath) { Remove-Item $envFilePath -Force }

# Create fixture: microsoft/vscode with localVer=1.0.0
$lines = @()
$lines += '> 最近核对时间：2026-09-01 00:00（北京时间，初始状态）'
$lines += ''
$lines += '## 监测列表'
$lines += ''
$lines += '| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$lines += '|---|---|---|---|---|---|'
$lines += '| 1 | [VSCode](https://github.com/microsoft/vscode/releases) | | | 1.0.0 | no |'
$lines += ''
$lines += '## 结论'
$lines += ''
$lines += '（初始结论）'
$lines += ''
$lines += '## 更新摘要'
$lines += ''
$lines += '（初始摘要）'
$lines += ''
$lines += '## 备注'
$lines += ''
$lines += '（初始备注）'
$lines += ''
$lines += '## 核对方法'
$lines += ''
$lines += 'GitHub REST API 直连，无 HTML 回退。'

$fixtureContent = $lines -join "`r`n"
Set-Content -Path $mdPath -Value $fixtureContent -Encoding UTF8 -NoNewline

# CRITICAL: Unset GITHUB_TOKEN
$originalToken = $env:GITHUB_TOKEN
Remove-Item Env:\GITHUB_TOKEN -ErrorAction SilentlyContinue
$env:GITHUB_VERSION_MONITOR_BASE = $testDir

$allOutput = @()

# Verify token is unset
$allOutput += "GITHUB_TOKEN before pipeline: $(if ($env:GITHUB_TOKEN) {'SET'} else {'UNSET'})"

# Run the full pipeline
$allOutput += "===== Running full pipeline (Steps 1-5) ====="
$pipeOut = & pwsh -NoProfile -File (Join-Path $libDir 'run-full-pipeline.ps1') -TestDir $testDir -LibDir $libDir 2>&1
$allOutput += $pipeOut
$allOutput += "===== Pipeline complete ====="

# Restore token for subsequent tests
if ($originalToken) { Set-Content -Path "env:GITHUB_TOKEN" -Value $originalToken }

# Save outputs
$stdoutText = $allOutput | Out-String
$stdoutText | Set-Content -Path (Join-Path $testDir 'stdout.txt') -Encoding UTF8
'' | Set-Content -Path (Join-Path $testDir 'stderr.txt') -Encoding UTF8

# Verify results
$results = @()
$results += "## T41 - Token Unset"
$results += ""
$results += "### Fixture"
$results += "- microsoft/vscode with localVer=1.0.0"
$results += "- GITHUB_TOKEN explicitly unset, no .env file"
$results += ""

$combined = $stdoutText

# Check stats.token=unset in result.json
$resultJsonPath = Join-Path $monitorDir 'result.json'
$tokenUnset = $false
if (Test-Path $resultJsonPath) {
    try {
        $rj = Get-Content $resultJsonPath -Raw | ConvertFrom-Json
        $tokenValue = $rj.stats.token
        $tokenUnset = ($tokenValue -eq 'unset')
        $results += "- result.json stats.token: '$tokenValue'"
    } catch {
        $results += "- result.json parse error: $_"
    }
} else {
    $results += "- result.json not found"
}

# Check SUMMARY line also shows token=unset
$summaryTokenUnset = $combined -match 'token=unset'
$results += "- SUMMARY line shows token=unset: $summaryTokenUnset"

# Check pipeline ran (BACKUP_OK, FETCH_COMPLETE)
$hasBackupOk = $combined -match 'BACKUP_OK\|'
$hasFetchComplete = $combined -match 'FETCH_COMPLETE\|'
$results += "- BACKUP_OK: $hasBackupOk"
$results += "- FETCH_COMPLETE: $hasFetchComplete"

# Overall
$allPass = $tokenUnset -and $summaryTokenUnset -and $hasBackupOk -and $hasFetchComplete
$results += ""
$results += "### Result: $(if ($allPass) {'**PASS**'} else {'**FAIL**'})"

# Save test report
$results | Set-Content -Path (Join-Path $testDir 'test-report.md') -Encoding UTF8

# Output results
$results | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "=== STDOUT ==="
Write-Output $stdoutText
