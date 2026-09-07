# Production Validation v1.7 Final - Test Report (T18)

**Generated:** 2026-09-08 03:03:26 +08:00
**Script:** `test.ps1`
**Test:** T18 - State Preservation

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 7 |
| PASS | 7 |
| FAIL | 0 |
| Overall | ALL PASS |

## Test Methodology

Uses a local HTTP listener (`System.Net.HttpListener` on `http://localhost:8765`)
to produce controlled HTTP responses. Real `Invoke-RestMethod` calls are made
to the listener, and the actual catch block logic + state machine logic from
SKILL-v1.7.md Step 2 are executed for each test case.

**Previous state (simulated for all tests):**
- `prevGitVer = 'v1.5.0'`
- `prevGitDate = '2026-03-20'`
- `prevFlag = 'no'`

## Test Details

### T18a

| Field | Value |
|-------|-------|
| Test ID | T18a |
| Description | auth_error (HTTP 401): gitVer/gitDate/flag preserved, review=true |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=auth_error, gitVer='v1.5.0' (prev='v1.5.0'), gitDate='2026-03-20' (prev='2026-03-20'), flag='no' (prev='no'), review=True |

### T18b

| Field | Value |
|-------|-------|
| Test ID | T18b |
| Description | forbidden (HTTP 403 + X-RateLimit-Remaining: 50): gitVer/gitDate/flag preserved, review=true |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=forbidden, rl='50', gitVer='v1.5.0' (prev='v1.5.0'), gitDate='2026-03-20' (prev='2026-03-20'), flag='no' (prev='no'), review=True |

### T18c

| Field | Value |
|-------|-------|
| Test ID | T18c |
| Description | rate_limited (HTTP 429): gitVer/gitDate/flag preserved, review=true |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=rate_limited, gitVer='v1.5.0' (prev='v1.5.0'), gitDate='2026-03-20' (prev='2026-03-20'), flag='no' (prev='no'), review=True |

### T18d

| Field | Value |
|-------|-------|
| Test ID | T18d |
| Description | server_error (HTTP 500): gitVer/gitDate/flag preserved, review=true |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=server_error, gitVer='v1.5.0' (prev='v1.5.0'), gitDate='2026-03-20' (prev='2026-03-20'), flag='no' (prev='no'), review=True |

### T18e

| Field | Value |
|-------|-------|
| Test ID | T18e |
| Description | http_error (HTTP 418, unusual code): gitVer/gitDate/flag preserved, review=true |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=http_error, gitVer='v1.5.0' (prev='v1.5.0'), gitDate='2026-03-20' (prev='2026-03-20'), flag='no' (prev='no'), review=True |

### T18f

| Field | Value |
|-------|-------|
| Test ID | T18f |
| Description | network_error (connection refused): gitVer/gitDate/flag preserved, review=true |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=network_error, gitVer='v1.5.0' (prev='v1.5.0'), gitDate='2026-03-20' (prev='2026-03-20'), flag='no' (prev='no'), review=True, err='由于目标计算机积极拒绝，无法连接。 (localhost:39999)' |

### T18g

| Field | Value |
|-------|-------|
| Test ID | T18g |
| Description | not_found (HTTP 404): gitVer='' (cleared), gitDate='' (cleared), flag preserved, review=true, reviewReasons contains 'not_found' |
| Expected | `PASS` |
| Actual | `PASS` |
| Verdict | **PASS** |
| Evidence | status=not_found, gitVer='' (cleared=''), gitDate='' (cleared=''), flag='no' (prev='no' preserved), review=True, reasons=[not_found] |

## State Machine Logic Under Test

```powershell
# After API call, state machine processes queryStatus:
if ($status -eq 'ok' -and $latest) {
    # Normal path - gitVer/gitDate/flag updated from API
} elseif ($status -eq 'not_found') {
    $newGitVer = ''; $newGitDate = ''; # cleared
    $newFlag = $prevFlag;               # preserved
    $review = $true; $reasons += 'not_found'
} else {
    # ALL other statuses preserve gitVer, gitDate, flag
    $newGitVer = $prevGitVer; $newGitDate = $prevGitDate; $newFlag = $prevFlag
    $review = $true; $reasons += 'api_failure'
}
```
## Note on HTTP 302 vs 418 for http_error Test

The task suggested HTTP 302 for the `http_error` test. However, `Invoke-RestMethod`
in PowerShell 7 follows 3xx redirects by default. A 302 without a `Location` header
does not reliably trigger the `http_error` catch path (it may produce a different
exception type without a response object). HTTP 418 (`I'm a teapot`) was used instead
because it is a clean unusual HTTP status code that:
1. Causes `Invoke-RestMethod` to throw an `HttpResponseException`
2. Has a `Response` object with `StatusCode = 418`
3. Does not match 401/404/429/403/5xx in the catch block
4. Falls through to `http_error` via the `elseif ($code)` branch

This tests the same code path that 302 would if it reached the catch block.

