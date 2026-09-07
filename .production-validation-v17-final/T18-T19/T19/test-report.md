# Production Validation v1.7 Final - Test Report (T19)

**Generated:** 2026-09-08 03:03:36 +08:00
**Script:** `test.ps1`
**Test:** T19 - 未安装 (Uninstalled) Scenario

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 5 |
| PASS | 5 |
| FAIL | 0 |
| Overall | ALL PASS |

## Test Methodology

Real GitHub API call to `microsoft/vscode` `releases/latest` endpoint.
The fixture sets `localVer = '未安装'` (uninstalled).

**Fixture:**
- `repo = 'microsoft/vscode'`
- `prevGitVer = 'v1.90.0'` (simulated, lower than latest)
- `prevGitDate = '2024-06-01'` (simulated)
- `localVer = '未安装'` (uninstalled)
- `prevFlag = 'no'`

**Expected behavior per SKILL-v1.7.md:**
- `ConvertTo-NormVer('未安装')` returns ``
- The state machine checks `未安装 -match '未安装'` before calling `Compare-Ver`
- When matched: `no = 'no'` (not installed → nothing to compare → no update needed)
- But `gitVer` and `gitDate` ARE still refreshed from the API response

## Test Details

### T19a

| Field | Value |
|-------|-------|
| Test ID | T19a |
| Description | flag should be 'no' when localVer='未安装' (not installed, nothing to compare) |
| Expected | `no` |
| Actual | `no` |
| Verdict | **PASS** |
| Evidence | localVer='未安装', flag='no', status=ok |

### T19b

| Field | Value |
|-------|-------|
| Test ID | T19b |
| Description | gitVer should be refreshed to latest API tag_name when API returns 200 |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=ok, gitVer='1.136.1', latest='1.136.1', prevGitVer='v1.90.0', isNew=True |

### T19c

| Field | Value |
|-------|-------|
| Test ID | T19c |
| Description | gitDate should be refreshed to API published date when API returns 200 |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=ok, gitDate='2026-09-03', pubDate='2026-09-03', prevGitDate='2024-06-01' |

### T19d

| Field | Value |
|-------|-------|
| Test ID | T19d |
| Description | ConvertTo-NormVer should return null for '未安装' |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | ConvertTo-NormVer('未安装') = null |

### T19e

| Field | Value |
|-------|-------|
| Test ID | T19e |
| Description | Compare-Ver should return 'incomparable' when localVer='未安装' (null normalization) |
| Expected | `incomparable` |
| Actual | `incomparable` |
| Verdict | **PASS** |
| Evidence | Compare-Ver('未安装', '1.136.1') = 'incomparable' (ConvertTo-NormVer returned null for '未安装') |

## State Machine Logic Under Test

```powershell
# From SKILL-v1.7.md Step 2, version comparison logic:
if ($localVer -match '未安装') {
    $newFlag = 'no'    # not installed, nothing to compare
} else {
    $cmp = Compare-Ver $localVer $latest
    switch ($cmp) {
        'lt' { $newFlag = 'yes' }
        'eq' { $newFlag = 'no' }
        default { $newFlag = $prevFlag; $review = $true; $reasons += 'incomparable_version' }
    }
}
# gitVer and gitDate are refreshed from API response regardless of localVer
```

