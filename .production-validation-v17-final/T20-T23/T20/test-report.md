# Test Report: T20 - result.json atomicity

**Generated:** 2026-09-07 15:34:46 +08:00
**Script:** test.ps1

## Description

Test that when the atomic move Move-Item result.fetch.tmp -> result.json fails
(because result.json is locked with FileShare::None), the old result.json
is NOT corrupted. This validates SKILL-v1.7.md Step 2 lines 407-412:

`powershell
try { Move-Item -Path  -Destination D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T20-T23\T20\test-base\.monitor\result.json -Force }
catch {
    Remove-Item  -Force -ErrorAction SilentlyContinue
    Write-Output ('RUNTIME_ERROR|result.json 原子替换失败：{0}' -f .Exception.Message)
    Release-LockSafely
    return
}
`

## Test Method

1. Create a valid result.json fixture with known content.
2. Compute SHA256 of result.json before the test.
3. Open result.json with an exclusive lock (FileShare::None).
4. Write new content to result.fetch.tmp.
5. Attempt Move-Item -Force (expected to fail with sharing violation).
6. Apply SKILL's catch-block cleanup (Remove-Item  -Force -SilentlyContinue).
7. Close the file handle.
8. Compute SHA256 of result.json after the test.
9. Verify SHA256 is unchanged and JSON is still valid.

## Expected Result

| Check | Expected |
|-------|----------|
| Move-Item fails | True |
| SHA256 unchanged | True |
| result.json still valid JSON | True |
| result.fetch.tmp cleaned up | True |
| Output starts with RUNTIME_ERROR | True |

## Actual Result

| Check | Actual |
|-------|--------|
| Move-Item failed | True |
| Move-Item error message | 当文件已存在时，无法创建该文件。 |
| SHA256 before | DCC8810A54CA5384F8777E9F8A8FE60E8972E85364B257A0A78CEADA43F0E209 |
| SHA256 after | DCC8810A54CA5384F8777E9F8A8FE60E8972E85364B257A0A78CEADA43F0E209 |
| SHA256 unchanged | True |
| result.json still valid JSON | True |
| result.fetch.tmp cleaned up | True |
| SKILL output | RUNTIME_ERROR|result.json 原子替换失败：当文件已存在时，无法创建该文件。 |
| Output starts with RUNTIME_ERROR | True |

## Verdict

**PASS**

## Evidence

- result.json SHA256 before: DCC8810A54CA5384F8777E9F8A8FE60E8972E85364B257A0A78CEADA43F0E209
- result.json SHA256 after: DCC8810A54CA5384F8777E9F8A8FE60E8972E85364B257A0A78CEADA43F0E209
- Move-Item exception message: 当文件已存在时，无法创建该文件。
- SKILL error output: RUNTIME_ERROR|result.json 原子替换失败：当文件已存在时，无法创建该文件。
