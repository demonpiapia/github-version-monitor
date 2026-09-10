# runtime-artifact-pipeline.ps1 — Phase 7 单进程管线（Phase 1 Step 6）
#
# 用途：单进程 pwsh 脚本内顺序 & step1..5，step 间插入 .monitor 只读快照。
# 快照仅读取目录清单与文件内容，不修改任何状态（不触碰锁文件句柄）。
# 用于 Phase 7 捕获 result.review.tmp 的瞬时存在窗口（D5 主证据）。
#
# 快照目录：base 目录外的 sibling 目录（不污染 base 状态）。
# 快照内容：每个 step 执行后记录 .monitor 目录的文件清单 + 文件内容（SHA256 + 内容）。
#
# 用法：
#   pwsh -NoProfile -NonInteractive -File runtime-artifact-pipeline.ps1 -BaseDir <dir> [-Scenario t38]

param([string]$BaseDir = '', [string]$Scenario = 't38')
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

if (-not $BaseDir) { $BaseDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'test-runtime-artifact' }
if (Test-Path $BaseDir) { Remove-Item $BaseDir -Recurse -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $BaseDir | Out-Null

$env:GITHUB_VERSION_MONITOR_BASE = $BaseDir
$snapshotDir = Join-Path (Split-Path $BaseDir -Parent) ('snapshot-' + [System.IO.Path]::GetRandomFileName().TrimStart('.'))
New-Item -ItemType Directory -Force -Path $snapshotDir | Out-Null

Write-Output ('PIPELINE|runtime-artifact|base={0}|snapshot={1}|pid={2}' -f $BaseDir, $snapshotDir, $PID)

# 前置：fixture
& (Join-Path $here 'create-fixture.ps1') -BaseDir $BaseDir -Scenario $Scenario

# 快照函数：读取 .monitor 目录清单 + 文件内容（只读，不修改状态）
function Invoke-Snapshot {
    param([string]$Label)
    $monitorDir = Join-Path $BaseDir '.monitor'
    $snapFile = Join-Path $snapshotDir ('snapshot-' + $Label + '.txt')
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine(('SNAPSHOT|{0}|ts={1}|pid={2}' -f $Label, [DateTimeOffset]::UtcNow.ToString('o'), $PID))
    if (Test-Path $monitorDir) {
        $files = @(Get-ChildItem $monitorDir -File -ErrorAction SilentlyContinue | Sort-Object Name)
        [void]$sb.AppendLine(('FILES|count={0}' -f $files.Count))
        foreach ($f in $files) {
            $sha = ''
            $size = $f.Length
            $contentPreview = ''
            try {
                $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
                $sha = [System.BitConverter]::ToString((New-Object System.Security.Cryptography.SHA256Managed).ComputeHash($bytes)) -replace '-', ''
            } catch { $sha = 'READ_ERROR:' + $_.Exception.Message }
            try {
                $txt = Get-Content $f.FullName -Raw -ErrorAction Stop
                if ($txt.Length -gt 200) { $contentPreview = $txt.Substring(0, 200) + '...' } else { $contentPreview = $txt }
                $contentPreview = $contentPreview -replace "`r", '\r' -replace "`n", '\n'
            } catch { $contentPreview = 'READ_ERROR:' + $_.Exception.Message }
            [void]$sb.AppendLine(('FILE|name={0}|size={1}|sha256={2}|preview={3}' -f $f.Name, $size, $sha, $contentPreview))
        }
    } else {
        [void]$sb.AppendLine('FILES|monitor_dir_missing')
    }
    [System.IO.File]::WriteAllText($snapFile, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Write-Output ('SNAPSHOT_OK|label={0}|path={1}' -f $Label, $snapFile)
}

# Step 1
& (Join-Path $here 'step1.ps1')
Invoke-Snapshot -Label 'after-step1'

# Step 2
& (Join-Path $here 'step2.ps1')
Invoke-Snapshot -Label 'after-step2'

# Step 3
& (Join-Path $here 'step3.ps1')
Invoke-Snapshot -Label 'after-step3'

# Step 4
& (Join-Path $here 'step4.ps1')
Invoke-Snapshot -Label 'after-step4'

# Step 5
& (Join-Path $here 'step5-full.ps1')
Invoke-Snapshot -Label 'after-step5'

Write-Output ('PIPELINE_DONE|snapshot_dir={0}' -f $snapshotDir)
