param(
    [Parameter(Mandatory=$true)][string]$OutputPath,
    [Parameter(Mandatory=$true)][object[]]$Repos
)
$ErrorActionPreference = 'Stop'
if ($Repos.Count -eq 0) { throw 'Repos 不能为空' }

$nowBeijing = [DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(8)).ToString('yyyy-MM-dd HH:mm')

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# GitHub 项目版本监测列表')
$lines.Add('')
$lines.Add("> 最近核对时间：$nowBeijing（北京时间）")
$lines.Add('')
$lines.Add('## 监测列表')
$lines.Add('')
$lines.Add('| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |')
$lines.Add('|---|---|---|---|---|---|')
$i = 1
foreach ($r in $Repos) {
    $owner = $r.owner
    $repo  = $r.repo
    $name  = $r.name
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $repo }
    $line = "| $i | [$name](https://github.com/$owner/$repo/releases) | $($r.prevGitVer) | $($r.prevGitDate) | $($r.localVer) | $($r.prevFlag) |"
    $lines.Add($line)
    $i++
}
$lines.Add('')
$lines.Add('## 结论')
$lines.Add('')
$lines.Add('（结论段占位）')
$lines.Add('')
$lines.Add('## 更新摘要')
$lines.Add('')
$lines.Add('（更新摘要段占位）')
$lines.Add('')
$lines.Add('## 备注')
$lines.Add('')
$lines.Add('（备注段占位）')
$lines.Add('')
$lines.Add('## 核对方法')
$lines.Add('')
$lines.Add('（核对方法段占位）')
$lines.Add('')

$content = ($lines -join "`r`n") + "`r`n"
Set-Content -Path $OutputPath -Value $content -Encoding UTF8 -NoNewline
Write-Output "FIXTURE_OK|$OutputPath|$($Repos.Count) repos"
