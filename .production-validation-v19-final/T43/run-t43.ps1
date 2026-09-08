$ErrorActionPreference = 'Continue'
$base = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\T43'
$lib  = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\lib'
$env:GITHUB_VERSION_MONITOR_BASE = $base

# 清理 base（保留本脚本自身和 create-fixture-t43.ps1）
if (Test-Path $base) {
    Get-ChildItem $base -Force | Where-Object {
        $_.Name -notin @('run-t43.ps1','create-fixture-t43.ps1')
    } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $base | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base '.output') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base 'before') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $base 'after')  | Out-Null

# 6 场景 fixture（每行独立参数）
# 场景说明（基于 2026-09-08 实测 GitHub latest release）：
#   1. normal upgrade      microsoft/vscode      localVer=1.0.0   latest=1.136.1  → yes
#   2. synced              kubernetes/kubernetes localVer=v1.37.0 latest=v1.37.0  → no (cmp=eq)
#   3. uninstalled         nodejs/node           localVer=未安装  latest=v26.8.1  → no (未安装强制 no)
#   4. unsupported version rust-lang/rust        localVer=v1.2.3a latest=1.98.1   → 保留 prevFlag + review(incomparable)
#   5. 404                 test/nonexistent-repo-12345 → not_found + review
#   6. versionJump         vercel/next.js        prevGitVer=v14.0.0, localVer=v10.0.0, latest=v16.3.4 → yes + review(versionJump)
& (Join-Path $base 'create-fixture-t43.ps1') -OutputPath (Join-Path $base '.output\GitHub更新监测列表.md') -Repos @(
    @{owner='microsoft'; repo='vscode'; name='vscode'; prevGitVer='1.136.0'; prevGitDate='2026-09-01'; localVer='1.0.0'; prevFlag='no'},
    @{owner='kubernetes'; repo='kubernetes'; name='kubernetes'; prevGitVer='v1.37.0'; prevGitDate='2026-08-26'; localVer='v1.37.0'; prevFlag='no'},
    @{owner='nodejs'; repo='node'; name='node'; prevGitVer='v26.0.0'; prevGitDate='2026-04-01'; localVer='未安装'; prevFlag='no'},
    @{owner='rust-lang'; repo='rust'; name='rust'; prevGitVer='1.97.0'; prevGitDate='2026-08-01'; localVer='v1.2.3a'; prevFlag='no'},
    @{owner='test'; repo='nonexistent-repo-12345'; name='nonexistent'; prevGitVer='v1.0.0'; prevGitDate='2023-01-01'; localVer='1.0.0'; prevFlag='no'},
    @{owner='vercel'; repo='next.js'; name='next.js'; prevGitVer='v14.0.0'; prevGitDate='2024-04-01'; localVer='v10.0.0'; prevFlag='no'}
)

$md = Join-Path $base '.output\GitHub更新监测列表.md'
Copy-Item $md (Join-Path $base 'md-before.md')
Copy-Item $md (Join-Path $base 'before\GitHub更新监测列表.md')

# 执行完整管线（dot-source 模式，stdout 透传正常）
& pwsh -NoProfile -NonInteractive -File (Join-Path $lib 'run-full-pipeline.ps1') -Base $base *> (Join-Path $base 'stdout.txt') 2>&1
$exit = $LASTEXITCODE

# 收集 after 状态
Copy-Item $md (Join-Path $base 'md-after.md')
Copy-Item $md (Join-Path $base 'after\GitHub更新监测列表.md')
$resultPath = Join-Path $base '.monitor\result.json'
if (Test-Path $resultPath) {
    Copy-Item $resultPath (Join-Path $base 'result-after.json')
    Copy-Item $resultPath (Join-Path $base 'after\result.json')
}
# result-before.json：本轮无前置 result.json（初始状态），标记 N/A
Set-Content -Path (Join-Path $base 'result-before.json') -Value '{"note":"no prior result.json (fresh T43 run)"}' -Encoding UTF8

# 锁状态
$lockPath = Join-Path $base '.monitor\run.lock'
$lockExists = Test-Path $lockPath
$lockInfo = if ($lockExists) { Get-Content $lockPath -Raw } else { 'lock released (file absent)' }
Set-Content -Path (Join-Path $base 'lock-after.txt') -Value "lockExists=$lockExists`r`n$lockInfo" -Encoding UTF8

# stderr 单独留空文件（因为 *> 已合并；这里显式记录说明）
Set-Content -Path (Join-Path $base 'stderr.txt') -Value '# stderr 与 stdout 已合并到 stdout.txt（PowerShell *> 语义）' -Encoding UTF8

Write-Output "T43 exit=$exit lockExists=$lockExists"
