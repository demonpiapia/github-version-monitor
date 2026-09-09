# create-fixture.ps1 - fixture 生成工具
# 用途：为各测试场景生成 .output/GitHub更新监测列表.md fixture 副本。
#
# 用法：
#   pwsh -NoProfile -NonInteractive -File create-fixture.ps1 -BaseDir <path> -Scenario <name>
#
# 场景列表：
#   normal           - 真实仓库，localVer 低于最新 release（触发 isNew + flag=yes）
#   synced           - 真实仓库，localVer 等于最新 release（触发 synced）
#   versionJump      - 真实仓库，localVer 低版本使 major 差 ≥2 或 minor 差 ≥10
#   uninstalled      - 真实仓库，localVer=未安装
#   unsupported      - 真实仓库，版本格式不可比较
#   404              - 不存在的仓库名称
#   T37              - 2 个真实仓库（microsoft/vscode + torvalds/linux）
#   T43              - 6 场景综合（6 个不同真实仓库 + 1 个 404 不存在仓库）
#
# localVer 策略：
#   - synced/versionJump 场景须运行时动态查询 releases/latest 获取最新 release 版本后生成 fixture
#     （synced: localVer=最新版本；versionJump: localVer=低版本使 major 差 ≥2 或 minor 差 ≥10）
#   - 404 场景使用不存在的 repo 名称
#   - normal/uninstalled/unsupported 使用固定 fixture
#   - 动态查询策略避免上游发版导致场景漂移
#
# 注意：SKILL schema 要求 owner/repo 不得重复，因此 T43 使用 6 个不同真实仓库。

param(
    [Parameter(Mandatory=$true)][string]$BaseDir,
    [Parameter(Mandatory=$true)][string]$Scenario
)

$ErrorActionPreference = 'Stop'

$outputDir = Join-Path $BaseDir '.output'
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Force -Path $outputDir | Out-Null }
$mdPath = Join-Path $outputDir 'GitHub更新监测列表.md'

# 动态查询 GitHub releases/latest 获取最新版本
function Get-LatestReleaseTag {
    param([string]$Repo)
    try {
        $headers = @{ 'User-Agent' = 'workbuddy-version-monitor'
                      'Accept' = 'application/vnd.github+json'
                      'X-GitHub-Api-Version' = '2026-03-10' }
        if ($env:GITHUB_TOKEN) { $headers['Authorization'] = "Bearer $env:GITHUB_TOKEN" }
        $j = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers -TimeoutSec 20
        return $j.tag_name
    } catch {
        Write-Error ("Failed to fetch latest release for {0}: {1}" -f $Repo, $_.Exception.Message)
        return $null
    }
}

# 从版本号计算一个"低版本"（使 major 差 ≥2）
function Get-LowVersion {
    param([string]$LatestTag)
    $tag = $LatestTag -replace '^[vV]', ''
    $parts = $tag -split '\.'
    if ($parts.Count -ge 1) {
        $major = [int]$parts[0]
        $newMajor = [Math]::Max(0, $major - 3)  # 确保 major 差 ≥2
        return ("{0}.0.0" -f $newMajor)
    }
    return '0.0.0'
}

# 生成标准 md 模板
function New-MdTemplate {
    param([string]$Rows)
    return @"
# GitHub 项目版本监测列表

> 最近核对时间：2026-09-01 00:00（北京时间，本轮 0 项：latest API 成功 0 / 失败 0 / 待核 0；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---|---|---|---|---|
$Rows

## 结论

（结论段：初始占位）

## 更新摘要

（更新摘要段：初始占位）

## 备注

（备注段：初始占位）

## 核对方法

（核对方法段：初始占位）
"@
}

# 场景 → 仓库列表 + localVer 策略
switch ($Scenario) {
    'normal' {
        $rows = '| 1 | [VS Code](https://github.com/microsoft/vscode/releases) |  |  | 0.0.1 | no |'
        $md = New-MdTemplate -Rows $rows
    }
    'synced' {
        $latest = Get-LatestReleaseTag -Repo 'microsoft/vscode'
        if (-not $latest) { throw 'Failed to query microsoft/vscode latest release' }
        $rows = ('| 1 | [VS Code](https://github.com/microsoft/vscode/releases) |  |  | {0} | no |' -f $latest)
        $md = New-MdTemplate -Rows $rows
        Write-Output ("synced: localVer={0}" -f $latest)
    }
    'versionJump' {
        $latest = Get-LatestReleaseTag -Repo 'microsoft/vscode'
        if (-not $latest) { throw 'Failed to query microsoft/vscode latest release' }
        $low = Get-LowVersion -LatestTag $latest
        $rows = ('| 1 | [VS Code](https://github.com/microsoft/vscode/releases) |  |  | {0} | no |' -f $low)
        $md = New-MdTemplate -Rows $rows
        Write-Output ("versionJump: latest={0} localVer={1}" -f $latest, $low)
    }
    'uninstalled' {
        $rows = '| 1 | [VS Code](https://github.com/microsoft/vscode/releases) |  |  | 未安装 | no |'
        $md = New-MdTemplate -Rows $rows
    }
    'unsupported' {
        $rows = '| 1 | [VS Code](https://github.com/microsoft/vscode/releases) |  |  | abc-invalid-format | no |'
        $md = New-MdTemplate -Rows $rows
    }
    '404' {
        $rows = '| 1 | [Nonexistent](https://github.com/test/nonexistent-repo-12345/releases) |  |  | 1.0.0 | no |'
        $md = New-MdTemplate -Rows $rows
    }
    'T37' {
        $rows = @"
| 1 | [VS Code](https://github.com/microsoft/vscode/releases) |  |  | 1.0.0 | no |
| 2 | [Linux](https://github.com/torvalds/linux/releases) |  |  | 6.5.0 | no |
"@
        $md = New-MdTemplate -Rows $rows
    }
    'T43' {
        # 6 个不同真实仓库 + 1 个 404（共 6 场景）
        # 注：versionJump 场景需要 prevGitVer（GIT最新版本列）非空，才能触发 versionJump=true
        #   （SKILL L381: if isNew { ConvertTo-NormVer $o.prevGitVer; ... versionJump=true }）
        #   若 prevGitVer 为空，versionJump 计算被跳过，versionJump=false
        $latestVscode = Get-LatestReleaseTag -Repo 'microsoft/vscode'
        if (-not $latestVscode) { throw 'Failed to query microsoft/vscode latest release' }
        $lowVscode = Get-LowVersion -LatestTag $latestVscode

        $latestNode = Get-LatestReleaseTag -Repo 'nodejs/node'
        if (-not $latestNode) { throw 'Failed to query nodejs/node latest release' }

        # 为 versionJump 场景构造一个旧的 prevGitVer（major 差 ≥2）
        # 使用 "1.0.0" 作为 prevGitVer，与 angular 最新版本（约 v22.x）major 差 ≥2
        $prevGitVerForJump = '1.0.0'

        $rows = @"
| 1 | [VS Code normal](https://github.com/microsoft/vscode/releases) |  |  | 0.0.1 | no |
| 2 | [Node.js synced](https://github.com/nodejs/node/releases) |  |  | {0} | no |
| 3 | [React uninstalled](https://github.com/facebook/react/releases) |  |  | 未安装 | no |
| 4 | [TypeScript unsupported](https://github.com/microsoft/TypeScript/releases) |  |  | abc-invalid-format | no |
| 5 | [Nonexistent 404](https://github.com/test/nonexistent-repo-12345/releases) |  |  | 1.0.0 | no |
| 6 | [Angular versionJump](https://github.com/angular/angular/releases) | {1} | 2025-01-01 | {2} | no |
"@ -f $latestNode, $prevGitVerForJump, $lowVscode
        $md = New-MdTemplate -Rows $rows
        Write-Output ("T43: vscode={0} node={1} lowVscode={2} prevGitVerForJump={3}" -f $latestVscode, $latestNode, $lowVscode, $prevGitVerForJump)
    }
    default {
        throw ("Unknown scenario: {0}" -f $Scenario)
    }
}

[System.IO.File]::WriteAllText($mdPath, $md, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("Wrote fixture: {0} (scenario={1})" -f $mdPath, $Scenario)
