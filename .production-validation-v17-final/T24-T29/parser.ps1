param([Parameter(Mandatory=$true)][string]$FixturePath)

$text = Get-Content $FixturePath -Raw
$sections=@($text -split '(?m)^## ')
$monitorSections=@($sections|Where-Object{$_ -match '^监测列表(?:\r?\n|$)'})
$parseErrors=@()
$repos=@()
if($monitorSections.Count -ne 1){$parseErrors+=('`## 监测列表` 节数量应为 1，实际 {0}'-f $monitorSections.Count)}
if($monitorSections.Count -eq 1){
    $sec=$monitorSections[0]
    $rows=@($sec -split "`n"|Where-Object{$_-match '^\s*\|'})
    $headerCount=0
    $dataRows=@()
    foreach($r in $rows){
        $t=$r.Trim()
        if(($t-replace '[|\s:\-]','')-eq ''){continue}
        $c=@($t.Trim('|')-split '\|'|ForEach-Object{$_.Trim()})
        if($c.Count -eq 6 -and (($c-join '|')-ceq '#|项目名称|GIT最新版本|GIT更新日期|本地版本|是否更新')){$headerCount++;continue}
        $dataRows+=,[PSCustomObject]@{Text=$t;Cells=$c}
    }
    if($headerCount-ne 1){$parseErrors+=('监测列表固定表头数量应为 1，实际 {0}'-f $headerCount)}
    if($text-notmatch '(?m)^>.*最近核对时间'){$parseErrors+='缺少顶部"最近核对时间"行'}
    foreach($anchor in @('结论','更新摘要','备注','核对方法')){
        if($text-notmatch ('(?m)^##\s*'+[regex]::Escape($anchor)+'\s*$')){
            $parseErrors+=('缺少写回锚点：## {0}'-f $anchor)
        }
    }
    $linkRe=[regex]'\[([^\]]+)\]\(https?://github\.com/([^/]+)/([^/]+)/releases\)'
    foreach($row in $dataRows){
        $t=$row.Text
        $c=$row.Cells
        if($c.Count-ne 6){$parseErrors+=('列数 {0}（应为 6）：{1}'-f $c.Count,$t);continue}
        if($c[0]-cnotmatch '^\d+$'){$parseErrors+=('第 1 列序号非法：{0}'-f $t);continue}
        $m=$linkRe.Match($c[1])
        if(-not $m.Success){$parseErrors+=('第 2 列非合法 releases 链接：{0}'-f $t);continue}
        if($c[5]-cnotmatch '^(yes|no)$'){$parseErrors+=('第 6 列 flag 非法：{0}'-f $t);continue}
        $repoKey='{0}/{1}'-f $m.Groups[2].Value,$m.Groups[3].Value
        if(@($repos|Where-Object{$_.repo-ceq $repoKey}).Count -gt 0){$parseErrors+=('repo 重复：{0}'-f $repoKey);continue}
        $repos+=[PSCustomObject]@{repo=$repoKey;name=$m.Groups[1].Value;prevGitVer=$c[2];prevGitDate=$c[3];localVer=$c[4];prevFlag=$c[5]}
    }
}
if($parseErrors.Count -gt 0 -or $repos.Count -eq 0){
    Write-Output 'PARSE_ERROR|状态文件 schema 校验失败，本轮终止，不写回主 md。'
    $parseErrors|ForEach-Object{Write-Output "  问题：$_"}
}
