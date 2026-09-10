param([string]$TestDir = 'T3-api-failure')

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
$ErrorActionPreference = 'Stop'

# Phase 4 Test 3 runner - API failure (main scenario: 500 / server_error).

$root      = 'D:\AI\Workspace\automatic\github-version-monitor'
$libDir    = Join-Path $root '.production-validation-v112-final\lib'
$base      = Join-Path $root ('.production-validation-v112-final\' + $TestDir)
$auxPath   = Join-Path $base 'harness-aux.txt'
$mockCfg   = Join-Path $base 'mock-config.txt'
$stdoutP   = Join-Path $base 'stdout.txt'
$stderrP   = Join-Path $base 'stderr.txt'
$sidecarP  = Join-Path $base 'run-status-sidecar.txt'
$valPath   = Join-Path $base 'validation.json'
$reportP   = Join-Path $base 'test-report.md'

if (Test-Path $base) { Remove-Item $base -Recurse -Force }
New-Item -ItemType Directory -Force -Path $base | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $base
$env:MOCK_SCENARIO               = 'server_500'
$env:MOCK_SCENARIO_LIST          = 'list-success'

$tsUtc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$tokenSet = (Test-Path 'env:GITHUB_TOKEN')
$auxHead = @(
    "# harness-aux.txt (Phase 4 harness-side evidence; NOT SKILL stdout)"
    "# Written by lib/p4-run-T3.ps1. Do not confuse with stdout.txt."
    "AUX_BEGIN=$tsUtc"
    "TEST_ID=$TestDir"
    "TEST_BASE=$base"
    "PS_VERSION=$($PSVersionTable.PSVersion.ToString())"
    "GITHUB_TOKEN_SET=$tokenSet"
    "MOCK_SCENARIO=$env:MOCK_SCENARIO"
    "MOCK_SCENARIO_LIST=$env:MOCK_SCENARIO_LIST"
    "MOCK_HTML_DECISION=200+fixed_html_body_with_title"
    "PID=$PID"
)
Set-Content -Path $auxPath -Value $auxHead -Encoding UTF8

function Add-Aux([string]$Line) { Add-Content -Path $auxPath -Value $Line -Encoding UTF8 }

$mockConfigLines = @(
    "# mock-config.txt (Phase 4 Test 3 declarative mock contract)"
    "# Three decisions required by exec-plan-v1.12-d.md Phase 4 B6."
    "MOCK_TARGET=lib/mock-invoke-restmethod.ps1 (dot-sourced before any step runs)"
    ""
    "SCENARIO_MAIN_LATEST=server_500"
    "SCENARIO_MAIN_LATEST_DESC=Invoke-RestMethod /repos/{repo}/releases/latest -> throws Exception with Response.StatusCode=500 (server_error branch in step2 L126)"
    ""
    "SCENARIO_LIST_ENDPOINT=list-success"
    "SCENARIO_LIST_ENDPOINT_DESC=Invoke-RestMethod /repos/{repo}/releases?per_page=5 -> returns 2-item PSCustomObject[] (deterministic; decouples review branch from primary-failure branch)"
    ""
    "SCENARIO_HTML_DIAGNOSTIC=200+fixed_html_with_title"
    "SCENARIO_HTML_DIAGNOSTIC_DESC=Invoke-WebRequest -> returns PSCustomObject{StatusCode=200; Content=html-with-title-body; RawContent=same}"
    "SCENARIO_HTML_DIAGNOSTIC_RATIONALE=avoids real-network dependency in T3; keeps step 4 HTML diagnostic branch deterministic; SKILL step4 accepts any StatusCode and only regex-extracts <title> from Content"
    ""
    "ENV_MOCK_SCENARIO=server_500"
    "ENV_MOCK_SCENARIO_LIST=list-success"
    ""
    "EXPECTED_STEP2_STATUS=server_error"
    "EXPECTED_STEP4_API_LIST_STATUS=ok"
    "EXPECTED_STEP4_HTML_STATUS=ok"
    "EXPECTED_OVERALL_RUN_STATUS=success"
    ""
    "Rationale_500_over_404_F1_D8=SKILL not_found contract sets gitVer and gitDate to empty string (special clear-state semantics); Prompt Test 3 requires unchanged-preserve-last-round-state; that maps to server_error / network_error branch, NOT not_found."
)
Set-Content -Path $mockCfg -Value $mockConfigLines -Encoding UTF8
Add-Aux "MOCK_CONFIG_WRITTEN=$mockCfg"

$fixtureScript = Join-Path $libDir 'create-fixture.ps1'
if (-not (Test-Path $fixtureScript)) { throw "FIXTURE_SCRIPT_MISSING: $fixtureScript" }
$fixtureOutPath = Join-Path $base 'fixture-stdout.txt'
& $fixtureScript -TestDir $base -Repos 'microsoft/vscode,PowerShell/PowerShell' *> $fixtureOutPath
$fixtureExit = $LASTEXITCODE
Add-Aux "FIXTURE_EXIT=$fixtureExit"

$monitorBefore = Test-Path (Join-Path $base '.monitor')
Add-Aux "FIXTURE_MONITOR_DIR_EXISTS=$monitorBefore"
if ($monitorBefore) {
    Add-Aux "FATAL: fixture created .monitor directory (forbidden)"
    exit 20
}

$mdFile = Get-ChildItem (Join-Path $base '.output') -Filter '*.md' | Select-Object -First 1
if (-not $mdFile) {
    Add-Aux 'FATAL: no .md file under .output directory'
    exit 22
}
$mdName = $mdFile.Name
$mdPath = $mdFile.FullName

$beforeDir = Join-Path $base 'before'
$afterDir  = Join-Path $base 'after'
New-Item -ItemType Directory -Force -Path $beforeDir | Out-Null
New-Item -ItemType Directory -Force -Path $afterDir  | Out-Null

Copy-Item $mdPath (Join-Path $beforeDir $mdName)
Copy-Item $mdPath (Join-Path $base 'md-before.md')
$shaBefore = (Get-FileHash -Algorithm SHA256 -Path $mdPath).Hash.ToUpper()
Set-Content -Path (Join-Path $base 'sha256-before.txt') -Value $shaBefore

$resultFileBefore = Join-Path $base '.monitor\result.json'
$resultBeforePath = Join-Path $base 'result-before.json'
if (Test-Path $resultFileBefore) {
    Copy-Item $resultFileBefore $resultBeforePath -Force
} else {
    Set-Content -Path $resultBeforePath -Value ''
}

$lockFileBefore = Join-Path $base '.monitor\run.lock'
$lockBeforeExists = Test-Path $lockFileBefore
Set-Content -Path (Join-Path $base 'lock-before.txt') -Value ("LOCK_EXISTS=" + $lockBeforeExists)

Add-Aux "BEFORE_SNAPSHOT_OK"
Add-Aux "SHA256_BEFORE=$shaBefore"
Add-Aux "LOCK_BEFORE_EXISTS=$lockBeforeExists"

$pipelineScript = Join-Path $libDir 'run-full-pipeline-mock.ps1'
if (-not (Test-Path $pipelineScript)) { throw "PIPELINE_SCRIPT_MISSING: $pipelineScript" }

Add-Aux "RUN_MODE=Start-Process -RedirectStandardOutput/-RedirectStandardError"
Add-Aux "CMD_TARGET=$pipelineScript"
$cmdArgs = @('-NoProfile','-NonInteractive','-File',$pipelineScript,'-TestDir',$base)
Add-Aux "CMD_ARGS=$($cmdArgs -join ' ')"

$pwshExe = 'C:\Program Files\PowerShell\7\pwsh.exe'
if (-not (Test-Path $pwshExe)) { $pwshExe = 'pwsh.exe' }

$proc = Start-Process -FilePath $pwshExe -ArgumentList $cmdArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutP -RedirectStandardError $stderrP

$pipeExit = $proc.ExitCode
Add-Aux "PIPELINE_EXIT=$pipeExit"
Add-Aux "PIPELINE_PID=$($proc.Id)"
$auxEndMid = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Add-Aux "PIPELINE_END_MARKER=harness recorded exit at $auxEndMid"

Copy-Item $mdPath (Join-Path $afterDir $mdName)
if (Test-Path (Join-Path $base '.monitor')) {
    Copy-Item (Join-Path $base '.monitor') (Join-Path $afterDir 'monitor') -Recurse -Force
}
Copy-Item $mdPath (Join-Path $base 'md-after.md')
$shaAfter = (Get-FileHash -Algorithm SHA256 -Path $mdPath).Hash.ToUpper()
Set-Content -Path (Join-Path $base 'sha256-after.txt') -Value $shaAfter

$resultFileAfter = Join-Path $base '.monitor\result.json'
$resultAfterPath = Join-Path $base 'result-after.json'
if (Test-Path $resultFileAfter) {
    Copy-Item $resultFileAfter $resultAfterPath -Force
} else {
    Set-Content -Path $resultAfterPath -Value ''
}

$lockFileAfter = Join-Path $base '.monitor\run.lock'
$lockAfterExists = Test-Path $lockFileAfter
Set-Content -Path (Join-Path $base 'lock-after.txt') -Value ("LOCK_EXISTS=" + $lockAfterExists)

$tmpPath = "$mdPath.tmp"
$tmpExists = Test-Path $tmpPath
Add-Aux "AFTER_SNAPSHOT_OK"
Add-Aux "SHA256_AFTER=$shaAfter"
Add-Aux "LOCK_AFTER_EXISTS=$lockAfterExists"
$mdChanged = ($shaBefore -ne $shaAfter)
Add-Aux "MD_CHANGED=$mdChanged"
Add-Aux "TMP_EXISTS_AFTER=$tmpExists"

$rawStdout = @()
if (Test-Path $stdoutP) { $rawStdout = Get-Content $stdoutP -Encoding UTF8 }
$observed = @($rawStdout | Where-Object { $_ -match '^RUN_STATUS\|' })
$sidecarLines = @(
    "# run-status-sidecar.txt (harness-derived; NOT part of SKILL stdout)"
    "RAW_STDOUT_TOTAL_LINES=$($rawStdout.Count)"
    "RAW_STDOUT_RUN_STATUS_LINES=$($observed.Count)"
)
foreach ($o in $observed) { $sidecarLines += "RUN_STATUS_OBSERVED=$o" }
if ($observed.Count -eq 0) { $sidecarLines += "RUN_STATUS_OBSERVED=<none>" }
Set-Content -Path $sidecarP -Value $sidecarLines -Encoding UTF8
Add-Aux "RUN_STATUS_SIDECAR_WRITTEN=$sidecarP"

function Count-Mark([string]$Path, [string]$Pattern) {
    if (-not (Test-Path $Path)) { return 0 }
    $lines = Get-Content $Path -Encoding UTF8
    return @($lines | Where-Object { $_ -match $Pattern }).Count
}

$counts = [ordered]@{
    RUN_STATUS_SUCCESS   = (Count-Mark $stdoutP '^RUN_STATUS\|success\|')
    RUN_STATUS_FAILED    = (Count-Mark $stdoutP '^RUN_STATUS\|failed\|')
    COMMIT_OK            = (Count-Mark $stdoutP '^COMMIT_OK\|')
    BACKUP_OK            = (Count-Mark $stdoutP '^BACKUP_OK\|')
    FETCH_COMPLETE       = (Count-Mark $stdoutP '^FETCH_COMPLETE\|')
    REVIEW_WRITE_OK      = (Count-Mark $stdoutP '^REVIEW_WRITE_OK\|')
    RUNTIME_ERROR        = (Count-Mark $stdoutP '^RUNTIME_ERROR\|')
    PARSE_ERROR          = (Count-Mark $stdoutP '^PARSE_ERROR\|')
    LOCKED               = (Count-Mark $stdoutP '^LOCKED\|')
    VALIDATE_ERROR       = (Count-Mark $stdoutP '^VALIDATE_ERROR\|')
    PS_VERSION_LINE      = (Count-Mark $stdoutP '^PS_VERSION\|')
    RUN_STATUS_OBSERVED  = (Count-Mark $stdoutP '^RUN_STATUS_OBSERVED=')
    HARNESS_START_MARKER = (Count-Mark $stdoutP '^T3_HARNESS_START$')
    HARNESS_END_MARKER   = (Count-Mark $stdoutP '^T3_HARNESS_END$')
}

$items = @()
$stats = $null
if ((Test-Path $resultAfterPath) -and (Get-Item $resultAfterPath).Length -gt 0) {
    try {
        $doc = Get-Content $resultAfterPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $items = @($doc.items)
        $stats = $doc.stats
    } catch { }
}

$mdBeforeLines = Get-Content (Join-Path $base 'md-before.md') -Encoding UTF8
$repoRowsBefore = @{}
foreach ($line in $mdBeforeLines) {
    if ($line -match '\(https?://github\.com/([^/]+)/([^/]+)/releases\)') {
        $repo = '{0}/{1}' -f $Matches[1], $Matches[2]
        $cells = @($line.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -eq 6) {
            $repoRowsBefore[$repo] = @{
                gitVer   = $cells[2]
                gitDate  = $cells[3]
                localVer = $cells[4]
                flag     = $cells[5]
            }
        }
    }
}

$mdAfterLines = Get-Content (Join-Path $base 'md-after.md') -Encoding UTF8
$repoRowsAfter = @{}
foreach ($line in $mdAfterLines) {
    if ($line -match '\(https?://github\.com/([^/]+)/([^/]+)/releases\)') {
        $repo = '{0}/{1}' -f $Matches[1], $Matches[2]
        $cells = @($line.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -eq 6) {
            $repoRowsAfter[$repo] = @{
                gitVer   = $cells[2]
                gitDate  = $cells[3]
                localVer = $cells[4]
                flag     = $cells[5]
            }
        }
    }
}

$checks = @()

foreach ($it in $items) {
    $checks += [ordered]@{
        item     = "api_item_status[$($it.repo)]"
        expected = "server_error"
        actual   = "$($it.status)"
        verdict  = $(if ($it.status -eq 'server_error') { 'PASS' } else { 'FAIL' })
    }
}

foreach ($it in $items) {
    $itRepo = [string]$it.repo
    if ([string]::IsNullOrEmpty($itRepo)) { continue }
    $before = if ($repoRowsBefore.ContainsKey($itRepo)) { $repoRowsBefore[$itRepo] } else { $null }
    if ($before) {
        $checks += [ordered]@{
            item     = "api_item_gitVer_unchanged[$itRepo]"
            expected = "$($before.gitVer)"
            actual   = "$($it.gitVer)"
            verdict  = $(if (($it.gitVer -ceq $before.gitVer)) { 'PASS' } else { 'FAIL' })
        }
        $checks += [ordered]@{
            item     = "api_item_gitDate_unchanged[$($it.repo)]"
            expected = "$($before.gitDate)"
            actual   = "$($it.gitDate)"
            verdict  = $(if (($it.gitDate -ceq $before.gitDate)) { 'PASS' } else { 'FAIL' })
        }
        $checks += [ordered]@{
            item     = "api_item_flag_unchanged[$($it.repo)]"
            expected = "$($before.flag)"
            actual   = "$($it.flag)"
            verdict  = $(if (($it.flag -ceq $before.flag)) { 'PASS' } else { 'FAIL' })
        }
    }
}

foreach ($it in $items) {
    $checks += [ordered]@{
        item     = "api_item_review_true[$($it.repo)]"
        expected = "True"
        actual   = "$($it.review)"
        verdict  = $(if ($it.review -eq $true) { 'PASS' } else { 'FAIL' })
    }
}

foreach ($it in $items) {
    $reasons = @($it.reviewReasons)
    $hasApiFail = ($reasons | Where-Object { $_ -ceq 'api_failure' }).Count -gt 0
    $checks += [ordered]@{
        item     = "api_item_reason_api_failure[$($it.repo)]"
        expected = "api_failure in reviewReasons"
        actual   = "$($reasons -join ',')"
        verdict  = $(if ($hasApiFail) { 'PASS' } else { 'FAIL' })
    }
}

foreach ($repo in $repoRowsBefore.Keys) {
    $b = $repoRowsBefore[$repo]
    $a = $repoRowsAfter[$repo]
    if ($a) {
        $checks += [ordered]@{
            item     = "md_after_gitVer_unchanged[$repo]"
            expected = "$($b.gitVer)"
            actual   = "$($a.gitVer)"
            verdict  = $(if (($a.gitVer -ceq $b.gitVer)) { 'PASS' } else { 'FAIL' })
        }
        $checks += [ordered]@{
            item     = "md_after_gitDate_unchanged[$repo]"
            expected = "$($b.gitDate)"
            actual   = "$($a.gitDate)"
            verdict  = $(if (($a.gitDate -ceq $b.gitDate)) { 'PASS' } else { 'FAIL' })
        }
        $checks += [ordered]@{
            item     = "md_after_flag_unchanged[$repo]"
            expected = "$($b.flag)"
            actual   = "$($a.flag)"
            verdict  = $(if (($a.flag -ceq $b.flag)) { 'PASS' } else { 'FAIL' })
        }
    }
}

$checks += [ordered]@{
    item     = "stats.apiOk"
    expected = "0"
    actual   = "$($stats.apiOk)"
    verdict  = $(if ($stats.apiOk -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "stats.apiErr"
    expected = "2"
    actual   = "$($stats.apiErr)"
    verdict  = $(if ($stats.apiErr -eq 2) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "stats.pendingReview"
    expected = "2"
    actual   = "$($stats.pendingReview)"
    verdict  = $(if ($stats.pendingReview -eq 2) { 'PASS' } else { 'FAIL' })
}

$checks += [ordered]@{
    item     = "RUN_STATUS_success_count"
    expected = ">=1"
    actual   = "$($counts.RUN_STATUS_SUCCESS)"
    verdict  = $(if ($counts.RUN_STATUS_SUCCESS -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "RUN_STATUS_failed_count"
    expected = "0"
    actual   = "$($counts.RUN_STATUS_FAILED)"
    verdict  = $(if ($counts.RUN_STATUS_FAILED -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "COMMIT_OK_count"
    expected = ">=1"
    actual   = "$($counts.COMMIT_OK)"
    verdict  = $(if ($counts.COMMIT_OK -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "BACKUP_OK_count"
    expected = ">=1"
    actual   = "$($counts.BACKUP_OK)"
    verdict  = $(if ($counts.BACKUP_OK -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "FETCH_COMPLETE_count"
    expected = ">=1"
    actual   = "$($counts.FETCH_COMPLETE)"
    verdict  = $(if ($counts.FETCH_COMPLETE -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "REVIEW_WRITE_OK_count"
    expected = ">=1"
    actual   = "$($counts.REVIEW_WRITE_OK)"
    verdict  = $(if ($counts.REVIEW_WRITE_OK -ge 1) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "RUNTIME_ERROR_count"
    expected = "0"
    actual   = "$($counts.RUNTIME_ERROR)"
    verdict  = $(if ($counts.RUNTIME_ERROR -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "PARSE_ERROR_count"
    expected = "0"
    actual   = "$($counts.PARSE_ERROR)"
    verdict  = $(if ($counts.PARSE_ERROR -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "stdout_no_PS_VERSION_line"
    expected = "0"
    actual   = "$($counts.PS_VERSION_LINE)"
    verdict  = $(if ($counts.PS_VERSION_LINE -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "stdout_no_RUN_STATUS_OBSERVED_line"
    expected = "0"
    actual   = "$($counts.RUN_STATUS_OBSERVED)"
    verdict  = $(if ($counts.RUN_STATUS_OBSERVED -eq 0) { 'PASS' } else { 'FAIL' })
}
$harnessMarkerTotal = $counts.HARNESS_START_MARKER + $counts.HARNESS_END_MARKER
$checks += [ordered]@{
    item     = "stdout_no_harness_start_end_marker"
    expected = "0"
    actual   = "$harnessMarkerTotal"
    verdict  = $(if ($harnessMarkerTotal -eq 0) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "lock_released_after_run"
    expected = "False"
    actual   = "$lockAfterExists"
    verdict  = $(if ($lockAfterExists -eq $false) { 'PASS' } else { 'FAIL' })
}
$checks += [ordered]@{
    item     = "md_tmp_cleaned"
    expected = "False"
    actual   = "$tmpExists"
    verdict  = $(if ($tmpExists -eq $false) { 'PASS' } else { 'FAIL' })
}

$backupDir = Join-Path $base '.monitor\backups'
$backupCount = 0
if (Test-Path $backupDir) {
    $backupFiles = Get-ChildItem $backupDir -File
    $backupCount = $backupFiles.Count
}
$checks += [ordered]@{
    item     = "backup_exists_under_monitor_backups"
    expected = ">=1"
    actual   = "$backupCount"
    verdict  = $(if ($backupCount -ge 1) { 'PASS' } else { 'FAIL' })
}

$passCount = @($checks | Where-Object { $_.verdict -eq 'PASS' }).Count
$failCount = @($checks | Where-Object { $_.verdict -eq 'FAIL' }).Count
$overall = if ($failCount -eq 0) { 'PASS' } else { 'FAIL' }

$validationObj = [ordered]@{
    test_id      = $TestDir
    scenario     = 'server_500'
    overall      = $overall
    pass_count   = $passCount
    fail_count   = $failCount
    total_count  = $checks.Count
    counts       = $counts
    checks       = $checks
    stats        = $stats
    md_changed   = $mdChanged
    lock_after   = $lockAfterExists
    tmp_exists   = $tmpExists
    backup_count = $backupCount
    mock_config  = "MOCK_SCENARIO=$($env:MOCK_SCENARIO); MOCK_SCENARIO_LIST=$($env:MOCK_SCENARIO_LIST); HTML=200+fixed_body"
}
$validationObj | ConvertTo-Json -Depth 10 | Set-Content -Path $valPath -Encoding UTF8
Add-Aux "VALIDATION_WRITTEN=$valPath"
Add-Aux "OVERALL=$overall"
Add-Aux "PASS_COUNT=$passCount"
Add-Aux "FAIL_COUNT=$failCount"

$rep = [System.Text.StringBuilder]::new()
[void]$rep.AppendLine('# Test 3 - API failure validation report (500 / server_error main scenario)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('Test ID: **' + $TestDir + '**')
[void]$rep.AppendLine('Test dir: `' + $base + '`')
[void]$rep.AppendLine('Main scenario: **server_500** (mock /releases/latest throws StatusCode=500)')
[void]$rep.AppendLine('Supplementary 404 scenario: **NOT EXECUTED** (per exec-plan F1/D8, 500 is the sole main scenario)')
[void]$rep.AppendLine('Executor: `lib/p4-run-T3.ps1`')
[void]$rep.AppendLine('Fixture repos: microsoft/vscode, PowerShell/PowerShell')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Verdict: **' + $overall + '** (' + $passCount + ' PASS / ' + $failCount + ' FAIL)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## stdout.txt key-marker independent counts (grep against RAW stdout)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('| Marker | Count |')
[void]$rep.AppendLine('|---|---|')
foreach ($k in $counts.Keys) {
    $v = $counts[$k]
    [void]$rep.AppendLine('| `' + $k + '` | ' + $v + ' |')
}
[void]$rep.AppendLine('| RAW stdout total lines | ' + $rawStdout.Count + ' |')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Corrected verification items (500 / network_error main scenario, 4 items)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('| # | Item | Expected | Actual | Verdict |')
[void]$rep.AppendLine('|---|---|---|---|---|')
$idx = 1
foreach ($c in $checks) {
    [void]$rep.AppendLine('| ' + $idx + ' | `' + $c.item + '` | `' + $c.expected + '` | `' + $c.actual + '` | ' + $c.verdict + ' |')
    $idx++
}
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Mock decisions (mock-config.txt summary)')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('- MOCK_SCENARIO = server_500 (latest endpoint -> 500 exception)')
[void]$rep.AppendLine('- MOCK_SCENARIO_LIST = list-success (list endpoint -> 2-item deterministic list)')
[void]$rep.AppendLine('- HTML diagnostic = 200 + html-with-title-body')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## Evidence index')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('| File | Content |')
[void]$rep.AppendLine('|---|---|')
[void]$rep.AppendLine('| stdout.txt | RAW pipeline stdout (no harness pollution) |')
[void]$rep.AppendLine('| stderr.txt | RAW pipeline stderr |')
[void]$rep.AppendLine('| harness-aux.txt | All harness-side evidence |')
[void]$rep.AppendLine('| mock-config.txt | 3-item mock decision declaration |')
[void]$rep.AppendLine('| run-status-sidecar.txt | Harness-derived RUN_STATUS observation |')
[void]$rep.AppendLine('| md-before.md / md-after.md | Main md snapshots |')
[void]$rep.AppendLine('| result-before.json / result-after.json | result.json snapshots |')
[void]$rep.AppendLine('| sha256-before.txt / sha256-after.txt | Main md SHA256 |')
[void]$rep.AppendLine('| lock-before.txt / lock-after.txt | Lock existence |')
[void]$rep.AppendLine('| before/ / after/ | Full state directory snapshots |')
[void]$rep.AppendLine('| validation.json | Structured verification metrics |')
[void]$rep.AppendLine('| fixture-stdout.txt | Fixture generation log |')
[void]$rep.AppendLine('')
[void]$rep.AppendLine('## SKILL integrity')
[void]$rep.AppendLine('- SKILL-v1.12.md / lib/stepX.ps1 read-only throughout; harness did NOT modify the SKILL or step scripts.')
[void]$rep.AppendLine('')

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($reportP, $rep.ToString(), $utf8NoBom)
Add-Aux "REPORT_WRITTEN=$reportP"

$auxEndFinal = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
Add-Aux "AUX_END=$auxEndFinal"

Write-Output "PHASE4_T3_DONE=$TestDir OVERALL=$overall PASS=$passCount FAIL=$failCount"
