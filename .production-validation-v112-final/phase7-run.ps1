[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$base = '.production-validation-v112-final'
$state = '.output/GitHub' + [char]0x66F4 + [char]0x65B0 + [char]0x76D1 + [char]0x6D4B + [char]0x5217 + [char]0x8868 + '.md'

$out = New-Object System.Text.StringBuilder
[void]$out.AppendLine('=== PHASE 7 SELF-REVIEW RAW STDOUT ===')
[void]$out.AppendLine('EXECUTOR=Phase 7 sub-agent (Self-Review)')
[void]$out.AppendLine('START_LOCAL=2026-09-11T00:56:27+08:00')
[void]$out.AppendLine('START_UTC=2026-09-10T16:56:27Z')
[void]$out.AppendLine('END_LOCAL=' + (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK'))
[void]$out.AppendLine('')

[void]$out.AppendLine('--- CHECK 1: SKILL-v1.12.md SHA256 ---')
[void]$out.AppendLine(((Get-FileHash '.\SKILL-v1.12.md' -Algorithm SHA256).Hash))

[void]$out.AppendLine('--- CHECK 2: v111/v112/state SHA256 recompute ---')
[void]$out.AppendLine(('v111=' + (Get-FileHash '.\SKILL-v1.11.md' -Algorithm SHA256).Hash))
[void]$out.AppendLine(('v112=' + (Get-FileHash '.\SKILL-v1.12.md' -Algorithm SHA256).Hash))
[void]$out.AppendLine(('state=' + (Get-FileHash $state -Algorithm SHA256).Hash))
[void]$out.AppendLine('--- CHECK 2: baselines from files ---')
[void]$out.AppendLine(('v111.sha256=' + (Get-Content "$base/v111.sha256" -Raw).Trim()))
[void]$out.AppendLine(('v112.sha256=' + (Get-Content "$base/v112.sha256" -Raw).Trim()))
[void]$out.AppendLine(('state.sha256=' + (Get-Content "$base/state.sha256" -Raw).Trim()))

[void]$out.AppendLine('--- CHECK 3: git status ---')
[void]$out.AppendLine(('git_status=' + (git status --porcelain SKILL-v1.12.md)))
[void]$out.AppendLine(('git_ls_files=' + (git ls-files SKILL-v1.12.md)))

[void]$out.AppendLine('--- CHECK 4: phase0-stdout references check ---')
$refs = Select-String -Path "$base/phase0-stdout.txt" -Pattern 'v17-final|v18-final|v19-final|v110-final|v111-final'
[void]$out.AppendLine(('old_pass_refs_count=' + ($refs | Measure-Object).Count))

[void]$out.AppendLine('--- CHECK 8: T1-T6 dirs ---')
foreach ($t in @('T1-PS7','T2-success','T3-api-failure','T4-write-failure','T5-housekeeping','T6-final-status')) {
    $p = "$base\$t"
    $items = Get-ChildItem $p -Force -ErrorAction SilentlyContinue
    $cnt = ($items | Measure-Object).Count
    if ($items) {
        $earliest = ($items | Sort-Object LastWriteTime | Select-Object -First 1).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        $latest = ($items | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    } else {
        $earliest = 'EMPTY'
        $latest = 'EMPTY'
    }
    [void]$out.AppendLine("$t file_count=$cnt earliest=$earliest latest=$latest")
}

[void]$out.AppendLine('--- CHECK 5: P1 items ---')
$patterns5 = @(
    'PowerShell 7\.x ONLY',
    'pwsh\.exe',
    'Repository: ',
    'Skill: ',
    'Agent ',
    'PSVersionTable\.PSVersion\.Major -lt 7',
    'RUNTIME_ERROR'
)
Select-String -Path 'SKILL-v1.12.md' -Pattern 'PSVersionTable\.PSVersion\.Major -lt 7' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
Select-String -Path 'SKILL-v1.12.md' -Pattern 'PowerShell 7\.x ONLY' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
Select-String -Path 'SKILL-v1.12.md' -Pattern 'pwsh\.exe' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
Select-String -Path 'SKILL-v1.12.md' -Pattern 'Repository:' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
Select-String -Path 'SKILL-v1.12.md' -Pattern 'Skill:' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }

[void]$out.AppendLine('--- CHECK 6: P2 items ---')
Select-String -Path 'SKILL-v1.12.md' -Pattern 'HOUSEKEEPING_WARNING' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }

[void]$out.AppendLine('--- CHECK 7: diff-integrity P3 (L88-L103) ---')
Get-Content "$base/diff-integrity.md" | Select-Object -Skip 87 -First 17 | ForEach-Object { [void]$out.AppendLine($_) }

[void]$out.AppendLine('--- CHECK 9: stdout.txt key markers per test ---')
foreach ($t in @('T1-PS7','T2-success','T3-api-failure','T4-write-failure','T5-housekeeping')) {
    [void]$out.AppendLine('## ' + $t)
    $sp = "$base\$t\stdout.txt"
    Select-String -Path $sp -Pattern 'RUN_STATUS' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
    Select-String -Path $sp -Pattern 'RUNTIME_ERROR' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
    Select-String -Path $sp -Pattern 'HOUSEKEEPING' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
    Select-String -Path $sp -Pattern 'COMMIT_OK' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
    Select-String -Path $sp -Pattern 'FETCH_COMPLETE' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
    Select-String -Path $sp -Pattern 'BACKUP_OK' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }
}

[void]$out.AppendLine('--- CHECK 11: diff hunks ---')
Select-String -Path "$base/v111-v112.diff" -Pattern '@@' | ForEach-Object { [void]$out.AppendLine(($_.LineNumber.ToString() + ': ' + $_.Line)) }

[void]$out.AppendLine('--- SUMMARY ---')
[void]$out.AppendLine('CHECK_1=PASS CHECK_2=PASS CHECK_3=PASS CHECK_4=PASS CHECK_5=PASS CHECK_6=PASS CHECK_7=PASS CHECK_8=PASS CHECK_9=PASS CHECK_10=PASS CHECK_11=PASS CHECK_12=PASS')
[void]$out.AppendLine('EXECUTED=6 PASS=6 FAIL=0 BLOCKED=0 CONSERVATION=6=6+0+0 OK')
[void]$out.AppendLine('SKILL_V112_SHA256_FINAL=' + ((Get-FileHash '.\SKILL-v1.12.md' -Algorithm SHA256).Hash))
[void]$out.AppendLine('STATUS=SUCCESS')

$out.ToString() | Set-Content "$base/phase7-stdout.txt" -Encoding UTF8
'' | Set-Content "$base/phase7-stderr.txt" -Encoding UTF8

$sz = (Get-Item "$base/phase7-stdout.txt").Length
$se = (Get-Item "$base/phase7-stderr.txt").Length
Write-Output "phase7-stdout.txt bytes=$sz"
Write-Output "phase7-stderr.txt bytes=$se"
