  # create-fixture.ps1 — fixture 生成工具（Phase 1 Step 7）
#
# 用途：在指定 base 目录下生成 .output/GitHub更新监测列表.md fixture，供各 Phase 测试使用。
# 不触碰生产状态文件（生产文件仅在 GITHUB_VERSION_MONITOR_BASE 未设置时被 SKILL 使用）。
#
# localVer 策略（计划 §Phase1 Step 7 明文要求）：
#   - synced / versionJump：运行时动态查询 releases/latest 获取最新版本后生成
#       synced      : localVer = 最新版本（cmp=eq）
#       versionJump : localVer = 低版本，使 major 差 ≥2（或 minor 差 ≥10）
#   - 404             : 使用不存在的 repo 名（稳定 404 → not_found → review=true，无版本漂移）
#   - normal          : 真实仓库 + localVer=0.0.1（低于任何真实 release → cmp=lt → flag=yes）
#   - uninstalled     : 真实仓库 + localVer=未安装（flag=no）
#   - unsupported     : 真实仓库 + localVer=不可比较格式（cmp=incomparable → review=true）
#   - t38             : 单个 404 repo（触发 review=true，供 T38 六子测试）
#   - t43             : 6 场景（normal/synced/uninstalled/unsupported/404/versionJump）
#
# 用法：
#   pwsh -NoProfile -NonInteractive -File create-fixture.ps1 -BaseDir <dir> -Scenario <name>
#   pwsh -NoProfile -NonInteractive -File create-fixture.ps1 -BaseDir <dir> -Scenario t43 -Repos "a/b,c/d"

param(
    [Parameter(Mandatory)][string]$BaseDir,
    [Parameter(Mandatory)][ValidateSet('normal','synced','versionJump','404','uninstalled','unsupported','t38','t43')][string]$Scenario,
    [string]$Repos = ''
)

$ErrorActionPreference = 'Stop'

function Get-LatestTag {
    param([string]$Repo)
    $h = @{ 'User-Agent' = 'workbuddy-version-monitor'; 'Accept' = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2026-03-10' }
    if ($env:GITHUB_TOKEN) { $h['Authorization'] = 'Bearer ' + $env:GITHUB_TOKEN }
    try {
        $j = Invoke-RestMethod -Uri ("https://api.github.com/repos/{0}/releases/latest" -f $Repo) -Headers $h -TimeoutSec 20
        if ($j -and $j.tag_name) { return [string]$j.tag_name }
    } catch {}
    return $null
}

function Split-Ver {
    param([string]$v)
    $s = $v.Trim() -replace '^[vV]', '' -replace '\+.*$', ''
    $parts = $s -split '[.\-]'
    if ($parts.Count -ge 1 -and $parts[0] -match '^\d+$') { return [int]$parts[0] }
    return $null
}

function Build-Md {
    param([string]$Base, [object[]]$Rows)
    $now = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd HH:mm')
    $yes = @($Rows | Where-Object { $_.Flag -ceq 'yes' }).Count
    $no = @($Rows | Where-Object { $_.Flag -ceq 'no' }).Count
    $md = New-Object System.Collections.Generic.List[string]
    $md.Add('# GitHub 项目更新监测列表')
    $md.Add('')
    $md.Add('> 数据来源：GitHub 官方 API（api.github.com）`releases/latest` 接口直连（异常项三通道复核：latest + releases 列表 + HTML 页），非搜索快照、非 Python 脚本')
    $md.Add('> 最近核对时间：' + $now + '（北京时间，fixture 初始值）')
    $md.Add('')
    $md.Add('## 监测列表')
    $md.Add('')
    $md.Add('| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |')
    $md.Add('|---|---------|------------|------------------|---------|-------------|')
    $i = 0
    foreach ($r in $Rows) {
        $i++
        $md.Add(('| {0} | [{1}](https://github.com/{2}/releases) | {3} | {4} | {5} | {6} |' -f $i, $r.Name, $r.Repo, $r.GitVer, $r.GitDate, $r.LocalVer, $r.Flag))
    }
    $md.Add('')
    $md.Add('## 结论')
    $md.Add('')
    $md.Add(('- 共监测 **' + $Rows.Count + '** 个项目，**' + $yes + '** 个需要更新（yes），' + $no + ' 个版本一致或未安装。'))
    $md.Add('')
    $md.Add('## 更新摘要')
    $md.Add('')
    $md.Add('- （fixture 初始占位，由步骤 5 程序替换）')
    $md.Add('')
    $md.Add('## 备注')
    $md.Add('')
    $md.Add('- （fixture 初始占位，由步骤 5 程序替换）')
    $md.Add('')
    $md.Add('## 核对方法')
    $md.Add('')
    $md.Add('- 步骤 2 PowerShell 逐行解析 + 每仓库 1 次 releases/latest 直连查询。')
    $md.Add('- flag 由 Compare-Ver 程序计算，agent 不手动抄表。')
    $md.Add('')
    $outDir = Join-Path $Base '.output'
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    $outPath = Join-Path $outDir 'GitHub更新监测列表.md'
    [System.IO.File]::WriteAllLines($outPath, $md, [System.Text.UTF8Encoding]::new($false))
    return $outPath
}

$existing = Join-Path $BaseDir '.output'
if (Test-Path $existing) {
    Write-Output ('FIXTURE_WARN|.output already exists at {0}（fixture 将被覆盖）' -f $existing)
}

$repoList = @()
if ($Repos -and $Repos.Trim().Length -gt 0) {
    $repoList = @($Repos -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

$rows = @()
switch ($Scenario) {
    'normal' {
        $repo = if ($repoList.Count -gt 0) { $repoList[0] } else { 'microsoft/vscode' }
        $tag = Get-LatestTag $repo
        if (-not $tag) { Write-Output ('FIXTURE_FAIL|无法查询 {0} 最新 release' -f $repo); exit 1 }
        $rows += [PSCustomObject]@{ Name = ($repo -split '/')[1]; Repo = $repo; GitVer = $tag; GitDate = '2026-09-01'; LocalVer = '0.0.1'; Flag = 'yes' }
    }
    'synced' {
        $repo = if ($repoList.Count -gt 0) { $repoList[0] } else { 'microsoft/vscode' }
        $tag = Get-LatestTag $repo
        if (-not $tag) { Write-Output ('FIXTURE_FAIL|无法查询 {0} 最新 release，无法生成 synced fixture' -f $repo); exit 1 }
        $rows += [PSCustomObject]@{ Name = ($repo -split '/')[1]; Repo = $repo; GitVer = $tag; GitDate = '2026-09-01'; LocalVer = $tag; Flag = 'no' }
        Write-Output ('FIXTURE_INFO|synced latest={0}' -f $tag)
    }
    'versionJump' {
        $repo = if ($repoList.Count -gt 0) { $repoList[0] } else { 'microsoft/vscode' }
        $tag = Get-LatestTag $repo
        if (-not $tag) { Write-Output ('FIXTURE_FAIL|无法查询 {0} 最新 release，无法生成 versionJump fixture' -f $repo); exit 1 }
        $maj = Split-Ver $tag
        if ($null -eq $maj -or $maj -lt 2) {
            Write-Output ('FIXTURE_FAIL|{0} 最新 major={1} < 2，无法满足 major 差 ≥2；请通过 -Repos 指定 major≥2 的仓库' -f $repo, $maj)
            exit 1
        }
        $rows += [PSCustomObject]@{ Name = ($repo -split '/')[1]; Repo = $repo; GitVer = 'v0.0.1'; GitDate = '2026-01-01'; LocalVer = '0.0.1'; Flag = 'yes' }
        Write-Output ('FIXTURE_INFO|versionJump latest={0} major={1} localMajor=0 (diff={2} ≥2)' -f $tag, $maj, $maj)
    }
    '404' {
        $repo = if ($repoList.Count -gt 0) { $repoList[0] } else { 'workbuddy-v111-nonexistent-org-7f3a9c2e/nonexistent-repo-404' }
        $rows += [PSCustomObject]@{ Name = ($repo -split '/')[1]; Repo = $repo; GitVer = ''; GitDate = ''; LocalVer = '1.0.0'; Flag = 'no' }
    }
    'uninstalled' {
        $repo = if ($repoList.Count -gt 0) { $repoList[0] } else { 'microsoft/vscode' }
        $rows += [PSCustomObject]@{ Name = ($repo -split '/')[1]; Repo = $repo; GitVer = 'v0.0.1'; GitDate = '2026-01-01'; LocalVer = '未安装'; Flag = 'no' }
    }
    'unsupported' {
        $repo = if ($repoList.Count -gt 0) { $repoList[0] } else { 'microsoft/vscode' }
        $rows += [PSCustomObject]@{ Name = ($repo -split '/')[1]; Repo = $repo; GitVer = 'v0.0.1'; GitDate = '2026-01-01'; LocalVer = '版本不可比较'; Flag = 'no' }
    }
    't38' {
        $repo = if ($repoList.Count -gt 0) { $repoList[0] } else { 'workbuddy-v111-nonexistent-org-7f3a9c2e/nonexistent-repo-404' }
        $rows += [PSCustomObject]@{ Name = ($repo -split '/')[1]; Repo = $repo; GitVer = ''; GitDate = ''; LocalVer = '1.0.0'; Flag = 'no' }
    }
    't43' {
        # Define defaults for up to 5 repos
        $defaults = @(
            'microsoft/vscode',      # 0: normal
            'facebook/react',        # 1: synced
            'nodejs/node',           # 2: uninstalled
            'python/cpython',        # 3: unsupported
            'microsoft/TypeScript'   # 4: versionJump
        )
        # Function to get repo by index with fallback to default
        function Get-RepoOrDefault {
            param([int]$Index)
            if ($repoList.Count -gt $Index) {
                return $repoList[$Index]
            }
            return $defaults[$Index]
        }
        $nfRepo = 'workbuddy-v111-nonexistent-org-7f3a9c2e/nonexistent-repo-404'
        # Get repos for each scenario
        $normalRepo = Get-RepoOrDefault -Index 0
        $syncedRepo = Get-RepoOrDefault -Index 1
        $uninstalledRepo = Get-RepoOrDefault -Index 2
        $unsupportedRepo = Get-RepoOrDefault -Index 3
        $versionJumpRepo = Get-RepoOrDefault -Index 4
        # Query latest tags for synced and versionJump repos (they need the latest tag)
        $syncedTag = Get-LatestTag $syncedRepo
        if (-not $syncedTag) { Write-Output ('FIXTURE_FAIL|无法查询 {0} 最新 release' -f $syncedRepo); exit 1 }
        $versionJumpTag = Get-LatestTag $versionJumpRepo
        if (-not $versionJumpTag) { Write-Output ('FIXTURE_FAIL|无法查询 {0} 最新 release' -f $versionJumpRepo); exit 1 }
        $versionJumpMaj = Split-Ver $versionJumpTag
        if ($null -eq $versionJumpMaj -or $versionJumpMaj -lt 2) {
            Write-Output ('FIXTURE_FAIL|{0} 最新 major={1} < 2，无法满足 versionJump 条件' -f $versionJumpRepo, $versionJumpMaj)
            exit 1
        }
        # Build rows for each scenario
        $rows += [PSCustomObject]@{ Name = 'vscode-normal'; Repo = $normalRepo; GitVer = 'v0.0.1'; GitDate = '2026-01-01'; LocalVer = '0.0.1'; Flag = 'yes' }
        $rows += [PSCustomObject]@{ Name = 'vscode-synced'; Repo = $syncedRepo; GitVer = $syncedTag; GitDate = '2026-09-01'; LocalVer = $syncedTag; Flag = 'no' }
        $rows += [PSCustomObject]@{ Name = 'vscode-uninstalled'; Repo = $uninstalledRepo; GitVer = 'v0.0.1'; GitDate = '2026-01-01'; LocalVer = '未安装'; Flag = 'no' }
        $rows += [PSCustomObject]@{ Name = 'vscode-unsupported'; Repo = $unsupportedRepo; GitVer = 'v0.0.1'; GitDate = '2026-01-01'; LocalVer = '版本不可比较'; Flag = 'no' }
        $rows += [PSCustomObject]@{ Name = 'nonexistent-404'; Repo = $nfRepo; GitVer = ''; GitDate = ''; LocalVer = '1.0.0'; Flag = 'no' }
        $rows += [PSCustomObject]@{ Name = 'vscode-versionjump'; Repo = $versionJumpRepo; GitVer = 'v0.0.1'; GitDate = '2026-01-01'; LocalVer = '0.0.1'; Flag = 'yes' }
        Write-Output ('FIXTURE_INFO|t43 synced={0} versionJump={1} (major diff={2})' -f $syncedTag, $versionJumpTag, $versionJumpMaj)
    }
}

if ($rows.Count -eq 0) { Write-Output ('FIXTURE_FAIL|scenario {0} 未产生任何行' -f $Scenario); exit 1 }
$mdPath = Build-Md -Base $BaseDir -Rows $rows
Write-Output ('FIXTURE_OK|scenario={0}|rows={1}|path={2}' -f $Scenario, $rows.Count, $mdPath)
