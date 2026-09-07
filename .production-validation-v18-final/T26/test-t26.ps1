# T26-v18: 严格小写 flag 解析器测试（step2.ps1 L78-83）
# 逐字提取解析器代码，构造 7 个 fixture 验证大小写敏感性
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

$PSVersion = $PSVersionTable.PSVersion.ToString()
Write-Output "PS_VERSION|$PSVersion"

# 生成 fixture
function New-Fixture([string]$path, [string]$flag) {
    $content = @"
> 最近核对时间：2026-09-01 00:00（北京时间，初始状态）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---|---|---|---|---|
| 1 | [Test](https://github.com/test/repo/releases) | v1.0.0 | 2026-08-01 | v1.0.0 | $flag |

## 结论

（初始结论）

## 更新摘要

（初始摘要）

## 备注

（初始备注）

## 核对方法

GitHub REST API 直连，无 HTML 回退。
"@
    [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
}

# 逐字提取解析器代码 (step2.ps1 L78-83)
function Invoke-Parser([string]$text) {
    $sections=@($text -split '(?m)^## ');$monitorSections=@($sections|Where-Object{$_ -match '^监测列表(?:\r?\n|$)'});$parseErrors=@();$repos=@()
    if($monitorSections.Count -ne 1){$parseErrors+=('`## 监测列表` 节数量应为 1，实际 {0}'-f $monitorSections.Count)}
    if($monitorSections.Count -eq 1){$sec=$monitorSections[0];$rows=@($sec -split "`n"|Where-Object{$_-match '^\s*\|'});$headerCount=0;$dataRows=@();foreach($r in $rows){$t=$r.Trim();if(($t-replace '[|\s:\-]','')-eq ''){continue};$c=@($t.Trim('|')-split '\|'|ForEach-Object{$_.Trim()});if($c.Count -eq 6 -and (($c-join '|')-ceq '#|项目名称|GIT最新版本|GIT更新日期|本地版本|是否更新')){$headerCount++;continue};$dataRows+=,[PSCustomObject]@{Text=$t;Cells=$c}};if($headerCount-ne 1){$parseErrors+=('监测列表固定表头数量应为 1，实际 {0}'-f $headerCount)};if($text-notmatch '(?m)^>.*最近核对时间'){$parseErrors+='缺少顶部“最近核对时间”行'};foreach($anchor in @('结论','更新摘要','备注','核对方法')){if($text-notmatch ('(?m)^##\s*'+[regex]::Escape($anchor)+'\s*$')){$parseErrors+=('缺少写回锚点：## {0}'-f $anchor)}};$linkRe=[regex]'\[([^\]]+)\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)';foreach($row in $dataRows){$t=$row.Text;$c=$row.Cells;if($c.Count-ne 6){$parseErrors+=('列数 {0}（应为 6）：{1}'-f $c.Count,$t);continue};if($c[0]-cnotmatch '^\d+$'){$parseErrors+=('第 1 列序号非法：{0}'-f $t);continue};$m=$linkRe.Match($c[1]);if(-not $m.Success){$parseErrors+=('第 2 列非合法 releases 链接：{0}'-f $t);continue};if($c[5]-cnotmatch '^(yes|no)$'){$parseErrors+=('第 6 列 flag 非法：{0}'-f $t);continue};$repoKey='{0}/{1}'-f $m.Groups[2].Value,$m.Groups[3].Value;if(@($repos|Where-Object{$_.repo-ceq $repoKey}).Count -gt 0){$parseErrors+=('repo 重复：{0}'-f $repoKey);continue};$repos+=[PSCustomObject]@{repo=$repoKey;name=$m.Groups[1].Value;prevGitVer=$c[2];prevGitDate=$c[3];localVer=$c[4];prevFlag=$c[5]}}}
    return [PSCustomObject]@{ ParseErrors = $parseErrors; Repos = $repos }
}

# 定义 7 个 fixture
# 注意：Windows 文件系统大小写不敏感，因此用后缀区分大小写变体（_upper / _cap / _mixed / _cap2）
$cases = @(
    @{ File='fixture_valid_yes.md';       Flag='yes'; Expected='PASS' },
    @{ File='fixture_valid_no.md';        Flag='no';  Expected='PASS' },
    @{ File='fixture_invalid_flag_UPPER.md'; Flag='YES'; Expected='PARSE_ERROR' },
    @{ File='fixture_invalid_flag_CAP.md';   Flag='Yes'; Expected='PARSE_ERROR' },
    @{ File='fixture_invalid_flag_MIXED.md'; Flag='yEs'; Expected='PARSE_ERROR' },
    @{ File='fixture_invalid_flag_UPPER2.md'; Flag='NO';  Expected='PARSE_ERROR' },
    @{ File='fixture_invalid_flag_CAP2.md';   Flag='No';  Expected='PARSE_ERROR' }
)

$passCount = 0; $failCount = 0
foreach ($c in $cases) {
    $path = Join-Path $here $c.File
    New-Fixture $path $c.Flag
    $text = Get-Content $path -Raw
    $r = Invoke-Parser $text
    $errCount = @($r.ParseErrors).Count
    $flagErr = @($r.ParseErrors | Where-Object { $_ -match 'flag 非法' }).Count

    if ($c.Expected -eq 'PASS') {
        $ok = ($errCount -eq 0) -and ($r.Repos.Count -eq 1) -and ($r.Repos[0].prevFlag -ceq $c.Flag)
        if ($ok) { $verdict='PASS' } else { $verdict='FAIL' }
    } else {
        $ok = ($errCount -gt 0) -and ($flagErr -gt 0) -and ($r.Repos.Count -eq 0)
        if ($ok) { $verdict='PASS' } else { $verdict='FAIL' }
    }
    if ($verdict -eq 'PASS') { $passCount++ } else { $failCount++ }
    $errSummary = if ($errCount -gt 0) { ($r.ParseErrors -join ' || ') } else { '(none)' }
    Write-Output ("FIXTURE|file={0}|flag=[{1}]|expected={2}|verdict={3}|parseErrors={4}|repos={5}|errors={6}" -f $c.File, $c.Flag, $c.Expected, $verdict, $errCount, $r.Repos.Count, $errSummary)
}
Write-Output "SUMMARY|pass=$passCount|fail=$failCount"
