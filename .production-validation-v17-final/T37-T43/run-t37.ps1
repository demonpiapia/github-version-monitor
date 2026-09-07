# T37 - Full Success Test
# Fixture: 2 real repos (microsoft/vscode localVer=1.0.0, torvalds/linux localVer=6.5.0)
# Run complete pipeline Steps 1-6
# Expected: RUN_STATUS|success|

$ErrorActionPreference = 'Continue'
$baseDir = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T37-T43'
$testDir = Join-Path $baseDir 'T37'
$libDir = Join-Path $baseDir 'lib'
$mdPath = Join-Path $testDir 'GitHub更新监测列表.md'
$monitorDir = Join-Path $testDir '.monitor'

# Clean any previous test artifacts
if (Test-Path (Join-Path $testDir '.monitor')) { Remove-Item (Join-Path $testDir '.monitor') -Recurse -Force }
if (Test-Path $mdPath) { Remove-Item $mdPath -Force }

# Compute SHA256 of original fixture (for later comparison)
$originalContent = $lines -join "`r`n"

# Create fixture
$rows = @(
    [PSCustomObject]@{Id='1'; Name='VSCode'; Owner='microsoft'; Repo='vscode'; GitVer=''; GitDate=''; LocalVer='1.0.0'; Flag='no'},
    [PSCustomObject]@{Id='2'; Name='Linux'; Owner='torvalds'; Repo='linux'; GitVer=''; GitDate=''; LocalVer='6.5.0'; Flag='no'}
)

# Build the fixture content directly
$lines = @()
$lines += '> 最近核对时间：2026-09-01 00:00（北京时间，初始状态）'
$lines += ''
$lines += '## 监测列表'
$lines += ''
$lines += '| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$lines += '|---|---|---|---|---|---|'
$lines += '| 1 | [VSCode](https://github.com/microsoft/vscode/releases) | | | 1.0.0 | no |'
$lines += '| 2 | [Linux](https://github.com/torvalds/linux/releases) | | | 6.5.0 | no |'
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
$originalSha = (Get-FileHash $mdPath -Algorithm SHA256).Hash

# Run the full pipeline
$env:GITHUB_VERSION_MONITOR_BASE = $testDir
$stdout = & pwsh -NoProfile -File (Join-Path $libDir 'run-full-pipeline.ps1') -TestDir $testDir -LibDir $libDir 2>&1
$stdoutText = $stdout | Out-String

# Save outputs
$stdoutText | Set-Content -Path (Join-Path $testDir 'stdout.txt') -Encoding UTF8
'' | Set-Content -Path (Join-Path $testDir 'stderr.txt') -Encoding UTF8

# Verify results
$results = @()
$results += "## T37 - Full Success"
$results += ""
$results += "### Fixture"
$results += "- 2 repos: microsoft/vscode (localVer=1.0.0), torvalds/linux (localVer=6.5.0)"
$results += ""

# Check BACKUP_OK
$hasBackupOk = $stdoutText -match 'BACKUP_OK\|'
$results += "- BACKUP_OK output: $hasBackupOk"

# Check result.json exists and is valid
$resultJsonPath = Join-Path $monitorDir 'result.json'
$hasResultJson = Test-Path $resultJsonPath
$resultValid = $false
if ($hasResultJson) {
    try {
        $rj = Get-Content $resultJsonPath -Raw | ConvertFrom-Json
        $resultValid = ($null -ne $rj -and $null -ne $rj.stats -and $null -ne $rj.items)
    } catch { $resultValid = $false }
}
$results += "- result.json created and valid: $resultValid (exists=$hasResultJson)"

# Check main md updated
$updatedSha = (Get-FileHash $mdPath -Algorithm SHA256).Hash
$mdChanged = ($updatedSha -ne $originalSha)
$results += "- Main md changed from original: $mdChanged"

# Check for gitVer/gitDate in updated md
$updatedContent = Get-Content $mdPath -Raw
$hasGitVer = $updatedContent -match '\| \d+ \|.*\|.*\d.*\|.*\d{4}-\d{2}-\d{2}.*\|.*\| (yes|no) \|'
$results += "- Main md has gitVer/gitDate populated: $hasGitVer"

# Check lock released
$lockPath = Join-Path $monitorDir 'run.lock'
$lockReleased = -not (Test-Path $lockPath)
$results += "- Lock released: $lockReleased"

# Check fetch_run.log
$logPath = Join-Path $monitorDir 'fetch_run.log'
$hasLog = Test-Path $logPath
$results += "- fetch_run.log created: $hasLog"

# Check RUN_STATUS|success|
$hasSuccess = $stdoutText -match 'RUN_STATUS\|success\|'
$results += "- RUN_STATUS|success|: $hasSuccess"

# Overall
$allPass = $hasBackupOk -and $resultValid -and $mdChanged -and $lockReleased -and $hasLog -and $hasSuccess
$results += ""
$results += "### Result: $(if ($allPass) {'**PASS**'} else {'**FAIL**'})"

# Save test report
$results | Set-Content -Path (Join-Path $testDir 'test-report.md') -Encoding UTF8

# Output results
$results | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "=== STDOUT ==="
Write-Output $stdoutText
