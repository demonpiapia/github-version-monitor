[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$root = 'D:\AI\Workspace\automatic\github-version-monitor'
Set-Location $root

# --- P3: find 6 fatal paths in v1.12 with actual line numbers ---
Write-Host "=== P3: fatal path search in v1.12 ==="
$patterns = @(
    @{name="L254: Step 2 lock not exist → RUNTIME_ERROR → return"; pat="锁不存在|LOCKED\|"},
    @{name="L320: Step 2 PARSE_ERROR → return"; pat="PARSE_ERROR\|.*return|PARSE_ERROR"},
    @{name="L406: Step 2 result.fetch.tmp JSON validation fail → RUNTIME_ERROR → return"; pat="result\.fetch\.tmp|RUNTIME_ERROR.*fetch|fetch.*RUNTIME_ERROR"},
    @{name="L412: Step 2 result.json replacement fail → RUNTIME_ERROR → return"; pat="RUNTIME_ERROR.*替换|替换.*RUNTIME_ERROR|result\.json.*失败"},
    @{name="L444: Step 3 heartbeat fail → RUNTIME_ERROR → return"; pat="步骤3 heartbeat"},
    @{name="L529: Step 5 lock not exist → RUNTIME_ERROR → return"; pat="步骤5.*RUNTIME_ERROR|步骤 5.*RUNTIME_ERROR"}
)
foreach ($p in $patterns) {
    Write-Host "`n--- $($p.name) ---"
    $matches = Select-String -Path '.\SKILL-v1.12.md' -Pattern $p.pat -AllMatches
    foreach ($m in $matches) {
        Write-Host ("  L{0}: {1}" -f $m.LineNumber, $m.Line.Substring(0, [Math]::Min(180, $m.Line.Length)))
    }
}

# --- Capability retention: search for each capability keyword in v1.12 ---
Write-Host "`n=== Step 7: Capability retention evidence ==="
$capabilities = @(
    @("output md path", 'GitHub更新监测列表\.md'),
    @(".monitor/", '\.monitor'),
    @("versionJump", 'versionJump'),
    @("dateSuspicious", 'dateSuspicious'),
    @("reviewReasons", 'reviewReasons'),
    @("schema validation", 'schema|表头|第 6 列'),
    @("strict lowercase yes/no", 'yes.*no.*大小写|大小写.*yes'),
    @("404 not_found", 'not_found'),
    @("rate_limited", 'rate_limited'),
    @("network_error", 'network_error'),
    @("auth_error", 'auth_error'),
    @("forbidden", 'forbidden'),
    @("server_error", 'server_error'),
    @("invalid_response", 'invalid_response'),
    @("metadata_incomplete", 'metadata_incomplete'),
    @("http_error", 'http_error'),
    @("result.fetch.tmp", 'result\.fetch\.tmp'),
    @("result.review.tmp", 'result\.review\.tmp'),
    @("run.lock", 'run\.lock'),
    @("heartbeat", 'heartbeat'),
    @("ownership", 'ownership'),
    @("atomic result persistence", 'result\.json'),
    @("atomic review persistence", 'result\.review\.tmp|result\.json'),
    @("atomic md commit", 'COMMIT_OK|原子替换|Move-Item'),
    @("commitSucceeded", 'commitSucceeded'),
    @("COMMIT_OK", 'COMMIT_OK'),
    @("RUN_STATUS|success|", 'RUN_STATUS\|success'),
    @("RUN_STATUS|failed|", 'RUN_STATUS\|failed'),
    @("Get-ResponseHeaderValue", 'Get-ResponseHeaderValue'),
    @("Compare-Ver", 'Compare-Ver'),
    @("ConvertTo-NormVer", 'ConvertTo-NormVer'),
    @("ConvertTo-UtcIso", 'ConvertTo-UtcIso')
)
foreach ($c in $capabilities) {
    $name = $c[0]; $pat = $c[1]
    $hits = Select-String -Path '.\SKILL-v1.12.md' -Pattern $pat -AllMatches
    $count = $hits.Count
    $firstLines = ($hits | Select-Object -First 3 | ForEach-Object { "L$($_.LineNumber)" }) -join ','
    Write-Host ("  [{0}] hits={1} first={2}" -f $name, $count, $firstLines)
}

# --- Forbidden items: check NOT in diff added lines ---
Write-Host "`n=== Step 8: Forbidden item check (added lines only) ==="
$forbidden = @(
    @("mock URL", 'mock'),
    @("forced success", 'forced|force-success'),
    @("debug bypass", 'debug.*bypass|bypass.*debug'),
    @("test-only branch", 'test.?only|TEST.?ONLY'),
    @("hardcoded token", 'ghp_|gho_|github_pat_'),
    @("hardcoded test repo", 'github\.com/test|github\.com/example|github\.com/foo'),
    @("skip schema", 'skip.*schema|schema.*skip'),
    @("skip lock", 'skip.*lock|lock.*skip'),
    @("skip commit", 'skip.*commit|commit.*skip'),
    @("full SemVer parser", 'semver.*parser|parser.*semver'),
    @("new API request", 'api\.github\.com/(?!repos)'),
    @("new review source", '新增.*review|review.*新增'),
    @("lock rewrite", 'redesign.*lock|lock.*redesign')
)
# Extract added lines from diff
$diffAdded = Get-Content '.production-validation-v112-final\v111-v112.diff' | Where-Object { $_ -match '^\+[^+]' }
Write-Host "Total added lines in diff: $($diffAdded.Count)"
foreach ($f in $forbidden) {
    $name = $f[0]; $pat = $f[1]
    $hits = $diffAdded | Where-Object { $_ -match $pat }
    if ($hits) {
        Write-Host ("  [FAIL] {0}: FOUND {1}" -f $name, $hits)
    } else {
        Write-Host ("  [OK]   {0}: NOT FOUND in added lines" -f $name)
    }
}
