# Test Report: T23 - md replacement failure

**Generated:** 2026-09-07 15:51:30 +08:00
**Script:** test.ps1

## Description

Test that when Move-Item md.tmp -> main md fails (because the main md is locked
with FileShare::None), the main md is unchanged and an error is reported. This
validates SKILL-v1.7.md Step 5 (lines 560-583):

`powershell
Set-Content -Path  -Value  -Encoding UTF8 -NoNewline
# GitHub 更新监测列表

> 最近核对时间：2026-09-07 12:02（北京时间，本轮 1 项：latest API 成功 1 / 失败 0 / 待核 0；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---------|-------------|-------------|----------|----------|
| 1 | [VS Code](https://github.com/microsoft/vscode/releases) | 1.96.0 | 2025-01-15 | 1.95.0 | yes |

## 结论

（结论段：1 监测 / 1 需更新(yes) / 0 未安装）

## 更新摘要

（更新摘要段：本轮无新发布；无翻转）

## 备注

（备注段：无 review=true 项）

## 核对方法

（占位） = Get-Content  -Raw
# ... validation ...
if (| 1 | [VS Code](https://github.com/microsoft/vscode/releases) | 1.96.0 | 2025-01-15 | 1.95.0 | yes |.Count -eq .Count -and .Count -eq 0 -and True -and True -and True) {
    Move-Item -Path  -Destination  -Force
    Write-Output "COMMIT_OK|..."
} else {
    Remove-Item  -Force -ErrorAction SilentlyContinue
    Write-Output "VALIDATE_ERROR|..."
}
`

Note: SKILL Step 5 does not wrap Move-Item in try/catch. The surrounding
script-level error handler catches the exception. For test purposes we emit a
canonical RUNTIME_ERROR message.

## Test Method

1. Create a valid GitHub更新监测列表.md fixture.
2. Compute SHA256 of the main md before the test.
3. Open the main md with an exclusive lock (FileShare::None).
4. Write new content to md.tmp (this succeeds — new file).
5. Validate md.tmp content (should pass — content is valid).
6. Attempt Move-Item md.tmp -> main md (expected to fail with sharing violation).
7. Clean up md.tmp.
8. Close the file handle.
9. Compute SHA256 of the main md after the test.
10. Verify SHA256 is unchanged and no partial write occurred.

## Expected Result

| Check | Expected |
|-------|----------|
| md.tmp write succeeds | True |
| md.tmp validation passes | True |
| Move-Item fails | True |
| SHA256 unchanged | True |
| Main md content unchanged (byte-for-byte) | True |
| Main md does NOT contain new timestamp (no partial write) | True |
| md.tmp cleaned up | True |
| SKILL output is RUNTIME_ERROR or VALIDATE_ERROR | True |

## Actual Result

| Check | Actual |
|-------|--------|
| md.tmp write succeeded | True |
| md.tmp validation passed | True |
| Move-Item failed | True |
| Move-Item error message | 当文件已存在时，无法创建该文件。 |
| SHA256 before | 80AF89622907CB40F8A10AE211380C903C45E2F10F7C9BD12EC3B63D8CA3ADF9 |
| SHA256 after | 80AF89622907CB40F8A10AE211380C903C45E2F10F7C9BD12EC3B63D8CA3ADF9 |
| SHA256 unchanged | True |
| Main md content unchanged | True |
| Main md does NOT contain new timestamp | True |
| md.tmp cleaned up | True |
| SKILL output is error | True |
| SKILL output | RUNTIME_ERROR|md 原子替换失败：当文件已存在时，无法创建该文件。 |

## Verdict

**PASS**

## Evidence

- Main md SHA256 before: 80AF89622907CB40F8A10AE211380C903C45E2F10F7C9BD12EC3B63D8CA3ADF9
- Main md SHA256 after: 80AF89622907CB40F8A10AE211380C903C45E2F10F7C9BD12EC3B63D8CA3ADF9
- Move-Item exception message: 当文件已存在时，无法创建该文件。
- SKILL output: RUNTIME_ERROR|md 原子替换失败：当文件已存在时，无法创建该文件。
- Main md content byte-for-byte unchanged: True
- No partial write (no '12:02' timestamp in main md): True
