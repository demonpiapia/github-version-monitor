# extract-code.ps1 — 从 SKILL-v1.11.md 按代码围栏整块提取 PowerShell 代码块
# Phase 1 Step 5 提取工具（harness 工具，非被测对象）
# 用法: pwsh -NoProfile -NonInteractive -File extract-code.ps1
# 输出: 同目录 step1.ps1 / step2.ps1 / step3.ps1 / step4.ps1 / step5-full.ps1
#       + extraction-manifest.json（由本脚本生成）
# 禁止修改被测代码：本脚本只做"围栏内原文复制"，不做任何改写。

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path $here -Parent | Split-Path -Parent
$src  = Join-Path $root 'SKILL-v1.11.md'

if (-not (Test-Path $src)) { Write-Output "FATAL|source not found: $src"; exit 1 }

$lines = [System.Collections.Generic.List[string]]::new()
$lines.AddRange([System.IO.File]::ReadLines($src))
$total = $lines.Count

# 定位所有 ```powershell 围栏（开围栏行号 + 闭围栏行号）
$blocks = @()
$open = $null
for ($i = 0; $i -lt $total; $i++) {
    $ln = $lines[$i]
    if ($null -eq $open) {
        if ($ln -match '^```powershell\s*$') { $open = $i }
    } else {
        if ($ln -match '^```\s*$') {
            $blocks += [PSCustomObject]@{
                OpenLine = $open + 1
                CodeStart = $open + 2
                CodeEnd   = $i
                CloseLine = $i + 1
            }
            $open = $null
        }
    }
}

Write-Output "SRC=$src"
Write-Output "SRC_TOTAL_LINES=$total"
Write-Output "POWERSHELL_BLOCKS=$($blocks.Count)"
foreach ($b in $blocks) {
    Write-Output ("  BLOCK open=L{0} code=L{1}-L{2} close=L{3} (code_lines={4})" -f $b.OpenLine, $b.CodeStart, $b.CodeEnd, $b.CloseLine, ($b.CodeEnd - $b.CodeStart + 1))
}

if ($blocks.Count -lt 5) { Write-Output "FATAL|expected >=5 powershell blocks, got $($blocks.Count)"; exit 1 }

# 目标映射（按围栏出现顺序）
$targets = @(
    @{ Name = 'step1.ps1';       Index = 0 }
    @{ Name = 'step2.ps1';       Index = 1 }
    @{ Name = 'step3.ps1';       Index = 2 }
    @{ Name = 'step4.ps1';       Index = 3 }
    @{ Name = 'step5-full.ps1';  Index = 4 }
)

$manifest = @{
    source_file    = 'SKILL-v1.11.md'
    source_sha256  = (Get-FileHash $src -Algorithm SHA256).Hash
    extracted_at   = [DateTimeOffset]::UtcNow.ToString('o')
    extractions    = @()
}

foreach ($t in $targets) {
    $b = $blocks[$t.Index]
    $codeLines = $lines[($b.CodeStart - 1) .. ($b.CodeEnd - 1)]
    $outPath = Join-Path $here $t.Name
    # 逐字写出（保持原文换行，末尾补一个换行以符合脚本文件惯例）
    $content = ($codeLines -join "`r`n") + "`r`n"
    [System.IO.File]::WriteAllText($outPath, $content, [System.Text.UTF8Encoding]::new($false))
    $sha = (Get-FileHash $outPath -Algorithm SHA256).Hash
    $manifest.extractions += [PSCustomObject]@{
        file         = $t.Name
        source_lines = ("{0}-{1}" -f $b.CodeStart, $b.CodeEnd)
        fence_lines  = ("{0}-{1}" -f $b.OpenLine, $b.CloseLine)
        sha256       = $sha
    }
    Write-Output ("EXTRACTED {0} <- code L{1}-L{2} (fence L{3}-L{4}) sha256={5}" -f $t.Name, $b.CodeStart, $b.CodeEnd, $b.OpenLine, $b.CloseLine, $sha)
}

$manifestPath = Join-Path $here 'extraction-manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestPath -Encoding UTF8
Write-Output "MANIFEST=$manifestPath"
Write-Output 'EXTRACT_DONE'
