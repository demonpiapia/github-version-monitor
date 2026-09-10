# splice-inline.ps1 — 注入版内联代码生成工具（harness 工具，非被测对象）
#
# 用途：从提取脚本（lib/stepN.ps1，本身已验证与 SKILL 原文零差异）生成"注入版内联代码"，
#       供同进程编排器 Invoke-Expression 执行。
#
# 设计要点（§0.7 进程模型声明）：
#   - pwsh -File 模式下每个脚本独立进程，脚本间无共享变量；dot-source 单个 step 无法实现
#     "执行到某行暂停注入"。因此注入类场景必须内联复制目标代码 + 精确注入点。
#   - 本工具不复制粘贴代码，而是**读取已验证零差异的提取文件并按行号拼接**，
#     保证内联代码与被测代码逐字一致（除声明的注入行）。
#   - 拼接边界 = 源文件第 N 行与第 N+1 行之间，与计划声明的 SKILL 行号一一对应：
#       T38-B          : step4.ps1 L17/L18 之间（SKILL L489/L490 之间）
#       T38-stats-items: step4.ps1 L7/L8   之间（SKILL L479/L480 之间）
#       T39            : step5-full.ps1 L116/L117 之间（SKILL L636/L637 之间）
#
# 用法：. (Join-Path $PSScriptRoot 'splice-inline.ps1')
#   $code = Get-InlinedStepCode -SourceFile $step4Path -AfterLine 17 -Injection @(
#       "# T38-B 注入：篡改 tmp 文件内容为非法 JSON",
#       "Set-Content $tmpPath -Value '{invalid json' -Force")

function Get-InlinedStepCode {
    param(
        [Parameter(Mandatory)][string]$SourceFile,
        [Parameter(Mandatory)][int]$AfterLine,
        [Parameter(Mandatory)][string[]]$Injection
    )
    if (-not (Test-Path $SourceFile)) { throw "splice-inline: source not found: $SourceFile" }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([System.IO.File]::ReadLines($SourceFile))
    if ($AfterLine -lt 1 -or $AfterLine -gt $lines.Count) {
        throw ("splice-inline: AfterLine {0} out of range (source has {1} lines)" -f $AfterLine, $lines.Count)
    }
    $out = [System.Collections.Generic.List[string]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $out.Add($lines[$i])
        if ($i -eq ($AfterLine - 1)) {
            foreach ($inj in $Injection) { $out.Add($inj) }
        }
    }
    return ($out -join "`r`n")
}
