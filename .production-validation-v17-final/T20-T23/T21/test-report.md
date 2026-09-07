# Test Report: T21 - review atomicity

**Generated:** 2026-09-07 15:38:57 +08:00
**Script:** test.ps1

## Description

Test that when the atomic move Move-Item result.review.tmp -> result.json fails
(because result.json is locked with FileShare::None), the old result.json is NOT
corrupted: stats, items, and review.performed are all preserved. This validates
SKILL-v1.7.md Step 4 (line 479):

`powershell
try { Move-Item D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T20-T23\T21\test-base\.monitor\result.review.tmp D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T20-T23\T21\test-base\.monitor\result.json -Force }
catch {
    Remove-Item D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T20-T23\T21\test-base\.monitor\result.review.tmp -Force -ErrorAction SilentlyContinue
    Write-Output ('REVIEW_WRITE_ERROR|review 原子替换失败：{0}' -f .Exception.Message)
    Release-LockSafely
    return
}
`

## Test Method

1. Create a valid result.json with a review=true item and review.performed=false.
2. Compute SHA256 of result.json before the test.
3. Open result.json with an exclusive lock (FileShare::None).
4. Build a new doc with review.performed=true (simulating Step 4 output).
5. Write new doc to result.review.tmp.
6. Attempt Move-Item -Force (expected to fail with sharing violation).
7. Apply SKILL's catch-block cleanup (Remove-Item D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T20-T23\T21\test-base\.monitor\result.review.tmp -Force -SilentlyContinue).
8. Close the file handle.
9. Compute SHA256 of result.json after the test.
10. Verify SHA256 is unchanged; stats/items/review.performed all preserved.

## Expected Result

| Check | Expected |
|-------|----------|
| Move-Item fails | True |
| SHA256 unchanged | True |
| result.json still valid JSON | True |
| stats still unchanged | True |
| items still unchanged | True |
| review.performed still false (not overwritten) | True |
| result.review.tmp cleaned up | True |
| Output starts with REVIEW_WRITE_ERROR | True |

## Actual Result

| Check | Actual |
|-------|--------|
| Move-Item failed | True |
| Move-Item error message | 当文件已存在时，无法创建该文件。 |
| SHA256 before | DF16984E24F6436820FB99E0AC3F9A96A027242469E50DCCA7E99CF111F81F44 |
| SHA256 after | DF16984E24F6436820FB99E0AC3F9A96A027242469E50DCCA7E99CF111F81F44 |
| SHA256 unchanged | True |
| result.json still valid JSON | True |
| stats still unchanged | True |
| items still unchanged | True |
| review.performed still false | True |
| result.review.tmp cleaned up | True |
| SKILL output | REVIEW_WRITE_ERROR|review 原子替换失败：当文件已存在时，无法创建该文件。 |
| Output starts with REVIEW_WRITE_ERROR | True |

## Verdict

**PASS**

## Evidence

- result.json SHA256 before: DF16984E24F6436820FB99E0AC3F9A96A027242469E50DCCA7E99CF111F81F44
- result.json SHA256 after: DF16984E24F6436820FB99E0AC3F9A96A027242469E50DCCA7E99CF111F81F44
- Move-Item exception message: 当文件已存在时，无法创建该文件。
- SKILL error output: REVIEW_WRITE_ERROR|review 原子替换失败：当文件已存在时，无法创建该文件。
- stats JSON preserved: True
- items JSON preserved: True
- review.performed preserved (still false): True
