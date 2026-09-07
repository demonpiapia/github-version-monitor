# T40 - Blocked Semantics
# Test two scenarios:
# 1. STATE_MISSING: No md file -> STATE_MISSING
# 2. LOCKED: Lock file with live PID and fresh heartbeat -> LOCKED
# Expected: both are "blocked" (not success, not failed, just exit early)

$ErrorActionPreference = 'Continue'
$baseDir = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T37-T43'
$testDir = Join-Path $baseDir 'T40'
$libDir = Join-Path $baseDir 'lib'

# Clean any previous test artifacts
if (Test-Path (Join-Path $testDir '.monitor')) { Remove-Item (Join-Path $testDir '.monitor') -Recurse -Force }
$mdPath = Join-Path $testDir 'GitHub更新监测列表.md'
if (Test-Path $mdPath) { Remove-Item $mdPath -Force }

$allOutput = @()
$results = @()
$results += "## T40 - Blocked Semantics"
$results += ""

# === Scenario 1: STATE_MISSING ===
$env:GITHUB_VERSION_MONITOR_BASE = $testDir
$allOutput += "===== SCENARIO 1: STATE_MISSING (no md file) ====="
$step1Out1 = & (Join-Path $libDir 'step1.ps1') 2>&1
$allOutput += $step1Out1
$allOutput += "===== END SCENARIO 1 ====="

$scenario1Combined = $step1Out1 | Out-String
$hasStateMissing = $scenario1Combined -match 'STATE_MISSING\|'
$noLockCreated = -not (Test-Path (Join-Path $testDir '.monitor\run.lock'))
$noBackupCreated = -not (Test-Path (Join-Path $testDir '.monitor\backups'))

$results += "### Scenario 1: STATE_MISSING"
$results += "- STATE_MISSING output: $hasStateMissing"
$results += "- No lock file created: $noLockCreated"
$results += "- No backup created: $noBackupCreated"
$scenario1Pass = $hasStateMissing -and $noLockCreated -and $noBackupCreated
$results += "- Scenario 1 result: $(if ($scenario1Pass) {'PASS'} else {'FAIL'})"
$results += ""

# === Scenario 2: LOCKED ===
# First, create the md file (so it passes the existence check)
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

# Create .monitor directory and lock file with live PID and fresh heartbeat
$monitorDir = Join-Path $testDir '.monitor'
New-Item -ItemType Directory -Force -Path $monitorDir | Out-Null
$lockPath = Join-Path $monitorDir 'run.lock'
$nowUtc = [DateTimeOffset]::UtcNow.ToString('o')
# Use current process PID (definitely alive)
$lockContent = "pid=$PID;start=$nowUtc;step=1;beat=$nowUtc"
Set-Content -Path $lockPath -Value $lockContent -Encoding UTF8 -NoNewline
$allOutput += "===== SCENARIO 2: LOCKED (live PID=$PID, fresh heartbeat) ====="
$allOutput += "Lock file created with pid=$PID"

# Now run step1.ps1 - should detect existing lock with live PID and output LOCKED
$step1Out2 = & (Join-Path $libDir 'step1.ps1') 2>&1
$allOutput += $step1Out2
$allOutput += "===== END SCENARIO 2 ====="

$scenario2Combined = $step1Out2 | Out-String
$hasLocked = $scenario2Combined -match 'LOCKED\|'
$noNewBackup = -not ((Get-ChildItem (Join-Path $monitorDir 'backups') -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0)
$lockStillExists = Test-Path $lockPath

$results += "### Scenario 2: LOCKED"
$results += "- LOCKED output: $hasLocked"
$results += "- No new backup created: $noNewBackup"
$results += "- Lock file still exists (not taken over): $lockStillExists"
$scenario2Pass = $hasLocked -and $noNewBackup -and $lockStillExists
$results += "- Scenario 2 result: $(if ($scenario2Pass) {'PASS'} else {'FAIL'})"
$results += ""

# Clean up the lock file
Remove-Item $lockPath -Force -ErrorAction SilentlyContinue

# Overall
$allPass = $scenario1Pass -and $scenario2Pass
$results += "### Result: $(if ($allPass) {'**PASS**'} else {'**FAIL**'})"

# Save outputs
$stdoutText = $allOutput | Out-String
$stdoutText | Set-Content -Path (Join-Path $testDir 'stdout.txt') -Encoding UTF8
'' | Set-Content -Path (Join-Path $testDir 'stderr.txt') -Encoding UTF8
$results | Set-Content -Path (Join-Path $testDir 'test-report.md') -Encoding UTF8

# Output results
$results | ForEach-Object { Write-Output $_ }
Write-Output ""
Write-Output "=== STDOUT ==="
Write-Output $stdoutText
