# 为 lock 测试目录生成 test-report.md
$ErrorActionPreference = 'Continue'
$root = "d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final"
$fence = '```'

foreach ($d in @("lock-concurrency","lock-ownership","lock-stale-alive","lock-stale-dead")) {
    $base = Join-Path $root $d
    if (-not (Test-Path $base)) { continue }
    $stdout = Get-Content (Join-Path $base 'stdout.txt') -Raw -ErrorAction SilentlyContinue
    $lockBefore = Get-Content (Join-Path $base 'lock-before.txt') -Raw -ErrorAction SilentlyContinue
    $lockAfter = Get-Content (Join-Path $base 'lock-after.txt') -Raw -ErrorAction SilentlyContinue

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# $d Test Report")
    $lines.Add("")
    $lines.Add("## Purpose")
    $lines.Add("验证 SKILL-v1.9 锁机制在特定场景下的行为。")
    $lines.Add("")
    $lines.Add("## Stdout")
    $lines.Add($fence)
    if ($stdout) { $lines.Add($stdout) }
    $lines.Add($fence)
    $lines.Add("")
    $lines.Add("## Lock Before")
    $lines.Add($fence)
    if ($lockBefore) { $lines.Add($lockBefore) }
    $lines.Add($fence)
    $lines.Add("")
    $lines.Add("## Lock After")
    $lines.Add($fence)
    if ($lockAfter) { $lines.Add($lockAfter) }
    $lines.Add($fence)

    ($lines -join "`r`n") | Set-Content (Join-Path $base 'test-report.md') -Encoding UTF8
    Write-Output "Generated: $d/test-report.md"
}
