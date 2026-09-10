#Requires -Version 7.0
# p3-verify.ps1 - Compute validation metrics for T1/T2 evidence files
param(
    [Parameter(Mandatory=$true)][string]$TestId
)

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

if ($TestId -notmatch '^(T1-PS7|T2-success)$') {
    throw "INVALID_TESTID: $TestId"
}

$root = 'D:\AI\Workspace\automatic\github-version-monitor'
$base = Join-Path $root ('.production-validation-v112-final\' + $TestId)
$stdout = Join-Path $base 'stdout.txt'
$stderr = Join-Path $base 'stderr.txt'
$resultAfter = Join-Path $base 'result-after.json'
$mdBefore = Join-Path $base 'md-before.md'
$mdAfter  = Join-Path $base 'md-after.md'
$shaBefore = (Get-Content (Join-Path $base 'sha256-before.txt') -Raw).Trim()
$shaAfter  = (Get-Content (Join-Path $base 'sha256-after.txt') -Raw).Trim()
$lockBefore = (Get-Content (Join-Path $base 'lock-before.txt') -Raw).Trim()
$lockAfter  = (Get-Content (Join-Path $base 'lock-after.txt') -Raw).Trim()

if (-not (Test-Path $stdout)) { throw "STDOUT_MISSING: $stdout" }
$outText = Get-Content $stdout -Raw
$errText = if (Test-Path $stderr) { Get-Content $stderr -Raw } else { '' }

$metrics = [ordered]@{}

# Marker counts (regex-anchored to line start)
$markers = @(
    'BACKUP_OK|',
    'FETCH_COMPLETE|',
    'SUMMARY|',
    'REVIEW_WRITE_OK|',
    'COMMIT_OK|',
    'RUN_STATUS|success|',
    'RUN_STATUS|failed|',
    'RUNTIME_ERROR|',
    'PARSE_ERROR|',
    'LOCKED|',
    'PS_VERSION|'
)
foreach ($m in $markers) {
    $re = '^' + [regex]::Escape($m)
    $found = @($outText -split "`r?`n" | Where-Object { $_ -match $re })
    $metrics[$m + '_count'] = $found.Count
    $metrics[$m + '_first'] = if ($found.Count -gt 0) { $found[0] } else { '' }
}

# PS version evidence
$psLine = @($outText -split "`r?`n" | Where-Object { $_ -match '^PS_VERSION=' })
$metrics['PS_VERSION_line'] = if ($psLine.Count -gt 0) { $psLine[0] } else { '(not present in stdout)' }

# stderr presence
$metrics['stderr_bytes'] = $errText.Length
$metrics['stderr_nonempty'] = ($errText.Length -gt 0)

# SHA + lock + md changed
$metrics['sha256_before'] = $shaBefore
$metrics['sha256_after']  = $shaAfter
$metrics['md_changed']    = ($shaBefore -ne $shaAfter)
$metrics['lock_before']   = $lockBefore
$metrics['lock_after']    = $lockAfter

# Result.json structure
$resultJsonOk = $false
$resultToken  = ''
$resultStats  = $null
$resultItemKeys = @()
if ((Test-Path $resultAfter) -and ((Get-Item $resultAfter).Length -gt 0)) {
    try {
        $rj = Get-Content $resultAfter -Raw | ConvertFrom-Json
        $resultJsonOk = $true
        $resultToken  = $rj.stats.token
        $resultStats  = $rj.stats
        if ($rj.items) { $resultItemKeys = @($rj.items | ForEach-Object { $_.repo }) }
    } catch {
        $resultJsonOk = $false
        $resultStats  = $null
    }
}
$metrics['result_json_ok']        = $resultJsonOk
$metrics['result_stats_total']    = if ($resultStats) { $resultStats.total } else { $null }
$metrics['result_stats_apiOk']    = if ($resultStats) { $resultStats.apiOk } else { $null }
$metrics['result_stats_apiErr']   = if ($resultStats) { $resultStats.apiErr } else { $null }
$metrics['result_stats_yes']      = if ($resultStats) { $resultStats.yes } else { $null }
$metrics['result_stats_uninstalled'] = if ($resultStats) { $resultStats.uninstalled } else { $null }
$metrics['result_stats_pendingReview'] = if ($resultStats) { $resultStats.pendingReview } else { $null }
$metrics['result_token_field']    = $resultToken
$metrics['result_items_repos']    = ($resultItemKeys -join ',')

# Main md table integrity
$mdAfterText = Get-Content $mdAfter -Raw
$mdBeforeText = Get-Content $mdBefore -Raw
$dataRowsBefore = @($mdBeforeText -split "`r?`n" | Where-Object { $_ -match '\]\(https?://github\.com/[^/]+/[^/]+/releases\)' })
$dataRowsAfter  = @($mdAfterText -split "`r?`n" | Where-Object { $_ -match '\]\(https?://github\.com/[^/]+/[^/]+/releases\)' })
$metrics['md_table_rows_before'] = $dataRowsBefore.Count
$metrics['md_table_rows_after']  = $dataRowsAfter.Count

# flag legality (col 6 must be yes/no)
$badFlagCount = 0
foreach ($row in $dataRowsAfter) {
    $cols = ($row.Trim().Trim('|') -split '\|' | ForEach-Object { $_.Trim() })
    if ($cols.Count -eq 6 -and ($cols[5] -notin @('yes','no'))) { $badFlagCount++ }
}
$metrics['md_bad_flag_rows'] = $badFlagCount

# repo set equality
$reposBefore = @($dataRowsBefore | ForEach-Object {
    $m = [regex]::Match($_, '\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)')
    if ($m.Success) { $m.Groups[1].Value + '/' + $m.Groups[2].Value }
})
$reposAfter  = @($dataRowsAfter | ForEach-Object {
    $m = [regex]::Match($_, '\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)')
    if ($m.Success) { $m.Groups[1].Value + '/' + $m.Groups[2].Value }
})
$reposBefore = $reposBefore | Sort-Object
$reposAfter  = $reposAfter  | Sort-Object
$metrics['md_repo_set_equal'] = ($reposBefore -join ',') -eq ($reposAfter -join ',')
$metrics['md_repos_after'] = ($reposAfter -join ',')

# Write validation JSON
$reportPath = Join-Path $base 'validation.json'
$metrics | ConvertTo-Json -Depth 6 | Set-Content -Path $reportPath -Encoding UTF8

Write-Output "=== $TestId VALIDATION SUMMARY ==="
foreach ($k in $metrics.Keys) {
    $v = $metrics[$k]
    if ($null -eq $v) { $v = 'null' }
    Write-Output ("{0}={1}" -f $k, $v)
}
Write-Output "VALIDATION_JSON=$reportPath"
