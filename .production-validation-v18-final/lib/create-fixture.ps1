# Test fixture md file generator for github-version-monitor.
# Produces a valid .output/GitHub更新监测列表.md fixture satisfying the v1.8 schema contract:
#   - exactly one "## 监测列表" section
#   - fixed 6-column header: # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新
#   - each data row exactly 6 columns with a valid releases link and lowercase yes/no flag
#   - top "最近核对时间" line
#   - four write-back anchors: ## 结论 / ## 更新摘要 / ## 备注 / ## 核对方法
param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [array]$Rows = @(
        [PSCustomObject]@{ Id=1; Name='VS Code';   Owner='microsoft'; Repo='vscode'; GitVer='v1.90.0'; GitDate='2026-08-15'; LocalVer='v1.89.0'; Flag='yes' }
        [PSCustomObject]@{ Id=2; Name='Trae';       Owner='trae-ai';   Repo='trae';   GitVer='v0.10.0'; GitDate='2026-08-20'; LocalVer='v0.10.0'; Flag='no'  }
        [PSCustomObject]@{ Id=3; Name='Trae Solo';  Owner='trae-ai';   Repo='solo';   GitVer='v0.5.0';  GitDate='2026-08-10'; LocalVer='未安装';    Flag='no'  }
    ),
    [string]$CheckedAt = '2026-09-01 00:00'
)
$ErrorActionPreference = 'Stop'
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("> 最近核对时间：$CheckedAt（北京时间，初始状态）")
$lines.Add('')
$lines.Add('## 监测列表')
$lines.Add('')
$lines.Add('| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |')
$lines.Add('|---|---|---|---|---|---|')
foreach ($r in $Rows) {
    $link = "[$($r.Name)](https://github.com/$($r.Owner)/$($r.Repo)/releases)"
    $lines.Add("| $($r.Id) | $link | $($r.GitVer) | $($r.GitDate) | $($r.LocalVer) | $($r.Flag) |")
}
$lines.Add('')
$lines.Add('## 结论')
$lines.Add('')
$lines.Add('（初始结论）')
$lines.Add('')
$lines.Add('## 更新摘要')
$lines.Add('')
$lines.Add('（初始摘要）')
$lines.Add('')
$lines.Add('## 备注')
$lines.Add('')
$lines.Add('（初始备注）')
$lines.Add('')
$lines.Add('## 核对方法')
$lines.Add('')
$lines.Add('GitHub REST API 直连，无 HTML 回退。')
$content = $lines -join "`r`n"
Set-Content -Path $OutputPath -Value $content -Encoding UTF8 -NoNewline
Write-Output "FIXTURE_OK|$OutputPath|rows=$($Rows.Count)"
