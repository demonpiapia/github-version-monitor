# Test fixture md file generator
# Creates a valid GitHub更新监测列表.md fixture
param(
    [string]$OutputPath,
    [array]$Rows  # Array of [PSCustomObject]@{Id, Name, Owner, Repo, GitVer, GitDate, LocalVer, Flag}
)

$lines = @()
$lines += '> 最近核对时间：2026-09-01 00:00（北京时间，初始状态）'
$lines += ''
$lines += '## 监测列表'
$lines += ''
$lines += '| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |'
$lines += '|---|---|---|---|---|---|'

foreach ($r in $rows) {
    $link = "[$($r.Name)](https://github.com/$($r.Owner)/$($r.Repo)/releases)"
    $lines += "| $($r.Id) | $link | $($r.GitVer) | $($r.GitDate) | $($r.LocalVer) | $($r.Flag) |"
}

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

$content = $lines -join "`r`n"
Set-Content -Path $OutputPath -Value $content -Encoding UTF8 -NoNewline
Write-Output "Fixture created: $OutputPath"
