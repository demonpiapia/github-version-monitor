# verify-extraction.ps1 — 受限 diff：提取脚本 vs SKILL 原文对应代码块
# Phase 1 Step 5 验证工具。零差异 = PASS。
# 比对方式：从 SKILL-v1.11.md 按围栏重新切片（独立实现，不复用 extract-code.ps1 的中间产物），
# 与已落盘提取文件逐字节比对（归一化 CRLF 后）。

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path $here -Parent | Split-Path -Parent
$src  = Join-Path $root 'SKILL-v1.11.md'

$raw = [System.IO.File]::ReadAllText($src)
$normRaw = $raw -replace "`r`n", "`n"
$srcLines = $normRaw -split "`n"

# 独立重新定位围栏
$blocks = [System.Collections.Generic.List[object]]::new(); $open = $null
for ($i = 0; $i -lt $srcLines.Count; $i++) {
    if ($null -eq $open) { if ($srcLines[$i] -match '^```powershell\s*$') { $open = $i } }
    else { if ($srcLines[$i] -match '^```\s*$') { $blocks.Add([PSCustomObject]@{ S = $open + 1; E = $i - 1 }); $open = $null } }
}

$names = @('step1.ps1','step2.ps1','step3.ps1','step4.ps1','step5-full.ps1')
$allPass = $true
foreach ($idx in 0..4) {
    $name = $names[$idx]
    $s = $blocks[$idx].S; $e = $blocks[$idx].E
    $expected = ($srcLines[$s..$e] -join "`n") + "`n"
    $actualRaw = [System.IO.File]::ReadAllText((Join-Path $here $name))
    $actual = $actualRaw -replace "`r`n", "`n"
    if ($actual -ceq $expected) {
        Write-Output ("PASS {0} L{1}-L{2} bytes={3} zero-diff" -f $name, ($s+1), ($e+1), $actualRaw.Length)
    } else {
        $allPass = $false
        Write-Output ("FAIL {0} L{1}-L{2} expected_bytes={2} actual_bytes={3}" -f $name, ($s+1), ($e+1), $expected.Length, $actual.Length)
        # 定位首个差异
        $min = [Math]::Min($expected.Length, $actual.Length)
        $firstDiff = -1
        for ($k = 0; $k -lt $min; $k++) { if ($expected[$k] -ne $actual[$k]) { $firstDiff = $k; break } }
        if ($firstDiff -ge 0) { Write-Output ("  first_diff_at_byte={0} expected='{1}' actual='{2}'" -f $firstDiff, $expected[$firstDiff], $actual[$firstDiff]) }
        else { Write-Output "  length_mismatch_only" }
    }
}
if ($allPass) { Write-Output 'VERIFY_EXTRACT_ALL_PASS' } else { Write-Output 'VERIFY_EXTRACT_HAS_FAIL'; exit 1 }
