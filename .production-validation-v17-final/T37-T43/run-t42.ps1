# T42 - Token Set
# Run the pipeline with GITHUB_TOKEN set
# Verify: stats.token=set
# Also verify the output does NOT contain: GITHUB_TOKEN value, Authorization header value, Cookie, or any secret strings

$ErrorActionPreference = 'Continue'
$baseDir = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T37-T43'
$testDir = Join-Path $baseDir 'T42'
$libDir = Join-Path $baseDir 'lib'
$mdPath = Join-Path $testDir 'GitHub更新监测列表.md'
$monitorDir = Join-Path $testDir '.monitor'

# Clean any previous test artifacts
if (Test-Path (Join-Path $testDir '.monitor')) { Remove-Item (Join-Path $testDir '.monitor') -Recurse -Force }
if (Test-Path $mdPath) { Remove-Item $mdPath -Force }

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

# Ensure GITHUB_TOKEN is set (use the real one from environment)
# Token should already be set from the system environment
$env:GITHUB_VERSION_MONITOR_BASE = $testDir
$tokenValue = $env:GITHUB_TOKEN
$tokenLen = if ($tokenValue) { $tokenValue.Length } else { 0 }

$allOutput = @()
$allOutput += "GITHUB_TOKEN is set (length=$tokenLen)"

# Run the full pipeline
$allOutput += "===== Running full pipeline (Steps 1-5) ====="
$pipeOut = & pwsh -NoProfile -File (Join-Path $libDir 'run-full-pipeline.ps1') -TestDir $testDir -LibDir $libDir 2>&1
$allOutput += $pipeOut
$allOutput += "===== Pipeline complete ====="

# Save outputs
$stdoutText = $allOutput | Out-String
$stdoutText | Set-Content -Path (Join-Path $testDir 'stdout.txt') -Encoding UTF8
'' | Set-Content -Path (Join-Path $testDir 'stderr.txt') -Encoding UTF8

# Verify results
$results = @()
$results += "## T42 - Token Set"
$results += ""
$results += "### Fixture"
$results += "- microsoft/vscode with localVer=1.0.0"
$results += "- GITHUB_TOKEN set (length=$tokenLen)"
$results += ""

$combined = $stdoutText

# Check stats.token=set in result.json
$resultJsonPath = Join-Path $monitorDir 'result.json'
$tokenSet = $false
if (Test-Path $resultJsonPath) {
    try {
        $rj = Get-Content $resultJsonPath -Raw | ConvertFrom-Json
        $tokenValueInJson = $rj.stats.token
        $tokenSet = ($tokenValueInJson -eq 'set')
        $results += "- result.json stats.token: '$tokenValueInJson'"
    } catch {
        $results += "- result.json parse error: $_"
    }
} else {
    $results += "- result.json not found"
}

# Check SUMMARY line shows token=set
$summaryTokenSet = $combined -match 'token=set'
$results += "- SUMMARY line shows token=set: $summaryTokenSet"

# Check pipeline ran successfully
$hasBackupOk = $combined -match 'BACKUP_OK\|'
$hasFetchComplete = $combined -match 'FETCH_COMPLETE\|'
$hasRunSuccess = $combined -match 'RUN_STATUS\|success\|'
$results += "- BACKUP_OK: $hasBackupOk"
$results += "- FETCH_COMPLETE: $hasFetchComplete"
$results += "- RUN_STATUS|success|: $hasRunSuccess"

# SECRET LEAK CHECKS
$results += ""
$results += "### Secret Leak Verification"

# 1. Check if the actual token value appears in stdout
$tokenInOutput = $false
if ($tokenValue -and $tokenValue.Length -gt 0) {
    $tokenInOutput = $combined.Contains($tokenValue)
}
$results += "- Token value NOT in stdout: $(-not $tokenInOutput)"

# 2. Check for Authorization header value pattern
$authHeaderInOutput = $combined -match 'Authorization.*Bearer'
$results += "- No Authorization/Bearer header in stdout: $(-not $authHeaderInOutput)"

# 3. Check for Cookie
$cookieInOutput = $combined -match 'Cookie'
$results += "- No Cookie in stdout: $(-not $cookieInOutput)"

# 4. Check for common secret patterns (github_pat_, ghp_, gho_, ghs_, ghu_, ghr_)
$secretPatterns = @('github_pat_', 'ghp_', 'gho_', 'ghs_', 'ghu_', 'ghr_')
$foundSecretPattern = $false
foreach ($pattern in $secretPatterns) {
    if ($combined -match [regex]::Escape($pattern)) {
        $foundSecretPattern = $true
        break
    }
}
$results += "- No secret token patterns (github_pat_, ghp_, etc.) in stdout: $(-not $foundSecretPattern)"

# 5. Check for "Bearer " followed by any characters
$bearerTokenInOutput = $combined -match 'Bearer\s+[A-Za-z0-9_]'
$results += "- No 'Bearer <token>' pattern in stdout: $(-not $bearerTokenInOutput)"

# Overall
$secretLeakClean = (-not $tokenInOutput) -and (-not $authHeaderInOutput) -and (-not $cookieInOutput) -and (-not $foundSecretPattern) -and (-not $bearerTokenInOutput)
$allPass = $tokenSet -and $summaryTokenSet -and $hasBackupOk -and $hasFetchComplete -and $hasRunSuccess -and $secretLeakClean
$results += ""
$results += "### Result: $(if ($allPass) {'**PASS**'} else {'**FAIL**'})"

# Save test report
$results | Set-Content -Path (Join-Path $testDir 'test-report.md') -Encoding UTF8

# Output results
$results | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "=== STDOUT ==="
Write-Output $stdoutText
