# extract-code.ps1 - 从 SKILL-v1.10.md 提取 PowerShell 代码块
# 用法: pwsh -NoProfile -NonInteractive -File extract-code.ps1 -SkillPath <path> -OutDir <dir>
param(
    [Parameter(Mandatory=$true)][string]$SkillPath,
    [Parameter(Mandatory=$true)][string]$OutDir
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

$lines = Get-Content $SkillPath
# 定位所有 ```powershell 起始行与配对结束行
$blocks = @()
$i = 0
while ($i -lt $lines.Count) {
    if ($lines[$i] -match '^```powershell\s*$') {
        $start = $i + 1  # 0-based index of first code line
        $j = $i + 1
        while ($j -lt $lines.Count -and $lines[$j] -notmatch '^```\s*$') { $j++ }
        $end = $j - 1    # 0-based index of last code line
        $blocks += [PSCustomObject]@{
            StartLine = $start + 1  # 1-based
            EndLine   = $end + 1    # 1-based
            StartIdx  = $start      # 0-based
            EndIdx    = $end        # 0-based
        }
        $i = $j + 1
    } else { $i++ }
}

Write-Output ("Found {0} powershell blocks" -f $blocks.Count)
foreach ($b in $blocks) {
    Write-Output ("  block: L{0}-L{1}" -f $b.StartLine, $b.EndLine)
}

# 映射：Step 1 = block 1, Step 2 = block 2, Step 3 = block 3, Step 4 = block 4, Step 5 = block 5
$mapping = @(
    @{ File = 'step1.ps1';        BlockIdx = 0 }
    @{ File = 'step2.ps1';        BlockIdx = 1 }
    @{ File = 'step3.ps1';        BlockIdx = 2 }
    @{ File = 'step4.ps1';        BlockIdx = 3 }
    @{ File = 'step5-full.ps1';   BlockIdx = 4 }
)

$manifest = [ordered]@{
    source_file = (Split-Path $SkillPath -Leaf)
    source_sha256 = ((Get-FileHash $SkillPath -Algorithm SHA256).Hash)
    extractions = @()
}

foreach ($m in $mapping) {
    $b = $blocks[$m.BlockIdx]
    $content = $lines[$b.StartIdx..$b.EndIdx]
    $outFile = Join-Path $OutDir $m.File
    [System.IO.File]::WriteAllLines($outFile, $content, (New-Object System.Text.UTF8Encoding($false)))
    $sha = (Get-FileHash $outFile -Algorithm SHA256).Hash
    $entry = [ordered]@{
        file = $m.File
        source_lines = ("{0}-{1}" -f $b.StartLine, $b.EndLine)
        sha256 = $sha
    }
    $manifest.extractions += $entry
    Write-Output ("Extracted {0} from L{1}-L{2}, sha256={3}" -f $m.File, $b.StartLine, $b.EndLine, $sha)
}

$manifestJson = $manifest | ConvertTo-Json -Depth 5
$manifestFile = Join-Path $OutDir 'extraction-manifest.json'
[System.IO.File]::WriteAllText($manifestFile, $manifestJson, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ("Wrote manifest: {0}" -f $manifestFile)
