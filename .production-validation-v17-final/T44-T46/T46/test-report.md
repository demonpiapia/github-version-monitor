# T46 — Production Runtime Contract

**Status: PASS**

## Test Objective
Verify that SKILL-v1.7.md declares PS7.x as production runtime, the actual runtime is PS7.x, no PS5.1 requirement for production main flow, and all core APIs execute correctly in PS7.

## Environment
- **PowerShell Version**: 7.6.4
- **OS**: Windows
- **Date**: 2026-09-08

## T46.1: SKILL-v1.7 Declares PS7.x Production Runtime
- **Status**: PASS
- **Evidence**: Line 9 of SKILL-v1.7.md: `> 生产执行基准：PowerShell 7.x；PowerShell 5.1 仅作兼容性验证环境。`

## T46.2: Actual Runtime is PS7.x
- **Status**: PASS
- **Evidence**: `$PSVersionTable.PSVersion` = `7.6.4`, Major = 7 (≥ 7)

## T46.3: No PS5.1 Requirement for Production Main Flow
- **Status**: PASS
- **Evidence**: PS5.1 is explicitly declared as "兼容性验证环境" (compatibility verification environment only). No code path in SKILL-v1.7.md requires PS5.1 for production execution. The `Get-ResponseHeaderValue` function provides PS5.1 header compatibility but does not require PS5.1.

## T46.4: Core API Execution Tests

### T46.4a: Invoke-RestMethod
- **Status**: PASS
- **Test**: Real API call to `https://api.github.com/repos/microsoft/vscode/releases/latest`
- **Headers**: `@{ 'User-Agent'='workbuddy-version-monitor'; 'Accept'='application/vnd.github+json' }`
- **Result**: Returned JSON with `tag_name=1.136.1` and `published_at` populated
- **Note**: In PS7, `published_at` is deserialized as `[System.DateTime]` object (not string), confirming v1.7's known limitation #9 documentation

### T46.4b: Invoke-WebRequest
- **Status**: PASS
- **Test**: Simple web request to `https://api.github.com`
- **Result**: StatusCode = 200

### T46.4c: ConvertFrom-Json
- **Status**: PASS
- **Test**: `'{"name":"test","version":"1.2.3","active":true}' | ConvertFrom-Json`
- **Result**: All properties accessible (name=True, version=True, active=True)

### T46.4d: ConvertTo-Json
- **Status**: PASS
- **Test**: `[PSCustomObject]@{name='test';version='1.2.3';active=$true} | ConvertTo-Json -Compress`
- **Result**: Valid JSON output `{"name":"test","version":"1.2.3","active":true}`

### T46.4e: Move-Item
- **Status**: PASS
- **Test**: Created temp file, Move-Item to new location
- **Result**: Destination exists, source gone, content matches

### T46.4f: FileMode.CreateNew
- **Status**: PASS
- **Test 1**: Create new file with `[System.IO.File]::Open($path, [System.IO.FileMode]::CreateNew, ...)` → succeeded
- **Test 2**: Create same file again → threw `[System.IO.IOException]` (correct exclusivity behavior)
- **Result**: Both behaviors confirmed — first create succeeds, second throws

## Summary

All 9 checks passed:
1. ✅ SKILL-v1.7 declares PS7.x production runtime
2. ✅ Actual runtime is PS7.x (7.6.4)
3. ✅ No PS5.1 production requirement
4. ✅ Invoke-RestMethod — real GitHub API call returns valid JSON
5. ✅ Invoke-WebRequest — works in PS7
6. ✅ ConvertFrom-Json — properties accessible
7. ✅ ConvertTo-Json — valid JSON output
8. ✅ Move-Item — atomic file move works
9. ✅ FileMode.CreateNew — exclusivity enforced (first succeeds, second throws)

**T46 = PASS**
