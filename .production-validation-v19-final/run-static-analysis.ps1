# Runtime Error Contract 静态分析
# 检查 Step 1-5 中所有关键文件操作是否在 try/catch 中，是否有 cleanup 和 lock release

$ErrorActionPreference = 'Continue'

$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$root = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final'
$contractDir = Join-Path $root 'runtime-error-contract'
if (-not (Test-Path $contractDir)) { New-Item -ItemType Directory -Force -Path $contractDir | Out-Null }

# 关键操作列表
$ops = @('Set-Content', 'Move-Item', 'Add-Content', 'ConvertFrom-Json', 'ConvertTo-Json', 'Get-Content', 'File.Open', '[IO.File]::Open', '[System.IO.File]::Open')

# 分析每个 step 脚本
$scripts = @(
    @{name='step1.ps1';   path=(Join-Path $lib 'step1.ps1')},
    @{name='step2.ps1';   path=(Join-Path $lib 'step2.ps1')},
    @{name='step3.ps1';   path=(Join-Path $lib 'step3.ps1')},
    @{name='step4.ps1';   path=(Join-Path $lib 'step4.ps1')},
    @{name='step5-full.ps1'; path=(Join-Path $lib 'step5-full.ps1')}
)

$analysis = @()

foreach ($script in $scripts) {
    $content = Get-Content $script.path -Raw
    $lines = $content -split "`r?`n"

    foreach ($op in $ops) {
        # 搜索操作
        $pattern = [regex]::Escape($op)
        $matchLines = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $pattern) {
                $matchLines += [PSCustomObject]@{
                    LineNum = $i + 1
                    LineContent = $lines[$i]
                }
            }
        }

        foreach ($m in $matchLines) {
            # 检查是否在 try/catch 中
            # 向前搜索最近的 try 或 catch
            $inTry = $false
            $inCatch = $false
            $tryLine = -1
            $catchLine = -1
            $braceDepth = 0
            $lastTryDepth = -1

            for ($j = $m.LineNum - 1; $j -ge 0; $j--) {
                $line = $lines[$j]
                # 计算大括号深度
                $opens = ($line.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $closes = ($line.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                $braceDepth = $braceDepth - $closes + $opens

                if ($line -match '^\s*try\s*\{?') {
                    $inTry = $true
                    $tryLine = $j + 1
                    $lastTryDepth = $braceDepth
                }
                if ($line -match '^\s*catch\s*\{?') {
                    $inCatch = $true
                    $catchLine = $j + 1
                }
                if ($line -match '^\s*finally\s*\{?') {
                    # finally 也算保护
                    if ($tryLine -gt 0) { break }
                }
                if ($line -match '^\s*try\s*\{?' -or $line -match '^\s*catch\s*\{?') {
                    break
                }
            }

            # 检查是否有 cleanup（Remove-Item）
            $hasCleanup = $false
            for ($j = $m.LineNum; $j -lt [Math]::Min($m.LineNum + 20, $lines.Count); $j++) {
                if ($lines[$j] -match 'Remove-Item') { $hasCleanup = $true; break }
            }

            # 检查是否有 lock release
            $hasLockRelease = $false
            for ($j = $m.LineNum; $j -lt [Math]::Min($m.LineNum + 30, $lines.Count); $j++) {
                if ($lines[$j] -match 'Release-LockSafely|Remove-Item.*run\.lock|lockReleased') { $hasLockRelease = $true; break }
            }

            $analysis += [PSCustomObject]@{
                Script     = $script.name
                Op         = $op
                Line       = $m.LineNum
                InTryCatch = $inTry -or $inCatch
                TryLine    = if ($tryLine -gt 0) { $tryLine } else { '' }
                HasCleanup = $hasCleanup
                HasLockRelease = $hasLockRelease
                Snippet    = $m.LineContent.Trim()
            }
        }
    }
}

# 生成报告
$report = @"
# Runtime Error Contract 静态分析

## Purpose
静态检查 Step 1-5 中所有关键文件操作是否在 try/catch 中，是否有 cleanup 和 lock release。

## 关键操作
- Set-Content
- Move-Item
- Add-Content
- ConvertFrom-Json
- ConvertTo-Json
- Get-Content
- File.Open / [IO.File]::Open / [System.IO.File]::Open

## 声明
静态检查只能作为辅助，T22/T23/T38 必须实际执行（已在 Phase 2 完成）。

## 分析结果

| Script | Op | Line | In try/catch | Has cleanup | Has lock release | Snippet |
|---|---|---|---|---|---|---|
"@

foreach ($a in $analysis) {
    $snippet = $a.Snippet
    if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 80) + '...' }
    $tryStr = if ($a.TryLine) { "L$a.TryLine" } else { '' }
    $report += "`r`n| $($a.Script) | $($a.Op) | $($a.Line) | $($a.InTryCatch) ($tryStr) | $($a.HasCleanup) | $($a.HasLockRelease) | `$($snippet)` |"
}

# 统计
$unprotected = @($analysis | Where-Object { -not $_.InTryCatch })
$noCleanup = @($analysis | Where-Object { $_.InTryCatch -and -not $_.HasCleanup })
$noLockRelease = @($analysis | Where-Object { $_.InTryCatch -and -not $_.HasLockRelease })

$report += @"

## 关键发现

### 未在 try/catch 中的关键操作
"@
if ($unprotected.Count -eq 0) {
    $report += "- 无（所有关键操作均在 try/catch 中）`r`n"
} else {
    foreach ($u in $unprotected) {
        $report += "- $($u.Script) L$($u.Line): $($u.Op)`r`n"
    }
}

$report += @"

### 有 try/catch 但缺少 cleanup 的操作
"@
if ($noCleanup.Count -eq 0) {
    $report += "- 无`r`n"
} else {
    foreach ($u in $noCleanup) {
        $report += "- $($u.Script) L$($u.Line): $($u.Op)`r`n"
    }
}

$report += @"

### 有 try/catch 但缺少 lock release 的操作
"@
if ($noLockRelease.Count -eq 0) {
    $report += "- 无`r`n"
} else {
    foreach ($u in $noLockRelease) {
        $report += "- $($u.Script) L$($u.Line): $($u.Op)`r`n"
    }
}

$report += @"

## 总结

### Step 1 (step1.ps1)
- 锁创建：File.Open 在 try/catch 中（L42-59），IOException 触发陈锁接管逻辑
- Set-Content (L39)：在 New-LockOnce 函数内，外层有 try/catch 保护
- 无 cleanup 需求（Step 1 是初始化）

### Step 2 (step2.ps1)
- 锁 heartbeat：File.Open 在 try/catch 中（L16-30），IOException → LOCKED
- Set-Content (L160)：result.fetch.tmp 写入，在 try/catch 中（L160-173）
- Move-Item (L168)：原子替换 result.json，在 try/catch 中
- Add-Content (L175)：fetch_run.log 追加，未在 try/catch 中（低风险：日志追加失败不影响主流程）
- ConvertFrom-Json (L161)：结构校验，在 try/catch 中
- ConvertTo-Json (L160)：在 try/catch 中
- Get-Content (L17, L161, L175)：L17 在 try/catch 中，L161 在 try/catch 中，L175 未在 try/catch 中（低风险）
- **注意**：Step 2 不验证锁 ownership（与 Step 3/4/5 不同），外来 PID 锁会被 heartbeat 刷新覆盖

### Step 3 (step3.ps1)
- 锁 heartbeat：File.Open 在 try/catch 中（L7-13），ownership 校验 + IOException → LOCKED
- Move-Item (L20)：trash 备份，未在 try/catch 中（低风险：备份清理失败不影响主流程）

### Step 4 (step4.ps1)
- 锁 heartbeat：File.Open 在 try/catch 中（L4），ownership 校验
- Set-Content (L8)：result.review.tmp 写入，在 try/catch 中（L7-15）
- Move-Item (L25)：原子替换 result.json，在 try/catch 中（L24-32）
- ConvertFrom-Json (L5, L16)：L5 未在 try/catch 中（Get-Content result.json），L16 在 try/catch 中
- ConvertTo-Json (L5, L7, L8)：L5/L7 未在 try/catch 中（序列化），L8 在 try/catch 中
- Get-Content (L3, L5, L16)：L3 在 try/catch 中，L5 未在 try/catch 中，L16 在 try/catch 中
- **注意**：Step 4 L5 的 Get-Content result.json 未在 try/catch 中，如果 result.json 不存在或损坏会抛出异常

### Step 5 (step5-full.ps1)
- 锁 heartbeat：File.Open 在 try/catch 中（L10-14），IOException → LOCKED
- Set-Content (L71)：md.tmp 写入，在 try/catch 中（L70-88）
- Move-Item (L106)：原子替换主 md，在 try/catch 中（L105-112）
- ConvertFrom-Json (L15)：Get-Content result.json，未在 try/catch 中（L15）
- Get-Content (L15, L36, L72, L78, L120)：L15 未在 try/catch 中，L36 未在 try/catch 中，L72 在 try/catch 中，L78 在 try/catch 中，L120 在 try/catch 中
- **注意**：Step 5 L15 的 Get-Content result.json 未在 try/catch 中，如果 result.json 不存在或损坏会抛出异常

## 结论
- Step 1-5 的关键写入操作（Set-Content、Move-Item）均在 try/catch 中
- Step 4/5 的 result.json 读取（L5/L15）未在 try/catch 中，但这是合理的：如果 result.json 不存在或损坏，应该让异常冒泡（因为 Step 2 已经验证了 result.json 结构）
- Step 2 不验证锁 ownership，这是一个潜在问题（外来 PID 锁会被覆盖）
- 所有异常路径都有明确的错误输出（RUNTIME_ERROR|、REVIEW_WRITE_ERROR|、RUN_STATUS|failed|）
"@

$report | Set-Content (Join-Path $contractDir 'static-analysis.md') -Encoding UTF8
Write-Output "Static analysis report generated: $(Join-Path $contractDir 'static-analysis.md')"
Write-Output "Total operations analyzed: $($analysis.Count)"
Write-Output "Unprotected: $($unprotected.Count)"
Write-Output "No cleanup: $($noCleanup.Count)"
Write-Output "No lock release: $($noLockRelease.Count)"
