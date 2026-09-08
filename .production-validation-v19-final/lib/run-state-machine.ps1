param(
    [Parameter(Mandatory=$true)][string]$TestName,
    [Parameter(Mandatory=$true)][string]$Scenario,
    [Parameter(Mandatory=$true)][object[]]$Repos,
    [string]$LocalVer   = '1.0.0',
    [string]$PrevFlag   = 'no',
    [string]$PrevGitVer = 'v1.0.0',
    [string]$PrevGitDate = '2026-01-01'
)
$ErrorActionPreference = 'Stop'

$base = "d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\$TestName"
$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'

# 清理 base（不删 lib 或自身）
if (Test-Path $base) { Remove-Item $base -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null

# 生成 fixture
& (Join-Path $lib 'create-fixture.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Repos $Repos -LocalVer $LocalVer -PrevFlag $PrevFlag -PrevGitVer $PrevGitVer -PrevGitDate $PrevGitDate *>&1 | Out-Null

# 执行 step1（建立锁 + 备份）
$env:GITHUB_VERSION_MONITOR_BASE = $base
& pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step1.ps1') > (Join-Path $base 'step1-stdout.txt') 2> (Join-Path $base 'step1-stderr.txt')

# 执行 step2（mock）
& pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'step2-mock-harness.ps1') -Scenario $Scenario -Base $base > (Join-Path $base 'stdout.txt') 2> (Join-Path $base 'stderr.txt')

# 清理 env var
Remove-Item Env:GITHUB_VERSION_MONITOR_BASE -ErrorAction SilentlyContinue

# 读取 result.json
$result = Join-Path $base '.monitor\result.json'
if (Test-Path $result) {
    $doc = Get-Content $result -Raw | ConvertFrom-Json
    $item = $doc.items[0]
    Write-Output "=== $TestName ==="
    Write-Output "scenario: $Scenario"
    Write-Output "queryStatus: $($item.status)"
    Write-Output "cmp: $($item.cmp)"
    Write-Output "review: $($item.review)"
    Write-Output "reviewReasons: $($item.reviewReasons -join ', ')"
    Write-Output "gitVer: $($item.gitVer)"
    Write-Output "gitDate: $($item.gitDate)"
    Write-Output "flag: $($item.flag)"
    Write-Output "prevFlag: $($item.prevFlag)"
    Write-Output "latest: $($item.latest)"
    Write-Output "publishedUtc: $($item.publishedUtc)"
    Write-Output "versionJump: $($item.versionJump)"
    Write-Output "dateSuspicious: $($item.dateSuspicious)"
    Write-Output "isFlip: $($item.isFlip)"
    Write-Output "isNew: $($item.isNew)"
    Write-Output "error: $($item.error)"
    Write-Output "stats.apiOk: $($doc.stats.apiOk)"
    Write-Output "stats.apiErr: $($doc.stats.apiErr)"
} else {
    Write-Output "result.json not found"
}
