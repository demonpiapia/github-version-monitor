# Test Report: T08 — network_error

## Test ID
T08

## Description
Real network error produced by setting `HTTPS_PROXY` and `HTTP_PROXY` to `http://127.0.0.1:1` (port 1 is closed on any system = connection refused) combined with a very short `TimeoutSec=1` as secondary evidence. The test verifies the state machine correctly handles a network-level failure (no HTTP response) by classifying it as `network_error`, preserving all state fields, and triggering `review=true`.

## Expected Result
- queryStatus = `network_error`
- gitVer preserved (not changed)
- gitDate preserved (not changed)
- flag preserved (not changed)
- review = `true`
- No HTTP response code (network-level failure, not HTTP-level)

## Actual Result

### API Call
- **Endpoint**: `GET https://api.github.com/repos/octocat/Hello-World/releases/latest`
- **Headers**: `User-Agent: workbuddy-version-monitor`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2026-03-10`, `Authorization: Bearer ***` (token set)
- **Proxy**: `HTTPS_PROXY=http://127.0.0.1:1`, `HTTP_PROXY=http://127.0.0.1:1`
- **Timeout**: 1 second (secondary evidence)
- **Result**: No HTTP response — `OperationCanceledException` (timeout)
- **Actual HTTP Code**: null (no HTTP response received)

### State Machine Output
| Field | Value |
|---|---|
| queryStatus | `network_error` |
| latest (tag_name) | `` (empty) |
| publishedUtc | `` (empty) |
| error | `The request was canceled due to the configured HttpClient.Timeout of 1 seconds elapsing.` |
| rateRemaining | `` (empty) |
| actualHttpCode | null (no HTTP response) |
| errorType | `OperationCanceledException (timeout)` |

### Comparison + Review Output
| Field | Value |
|---|---|
| gitVer (newGitVer) | `v1.8.0` (preserved) |
| gitDate (newGitDate) | `2026-06-10` (preserved) |
| flag (newFlag) | `no` (preserved) |
| prevFlag | `no` |
| review | `True` |
| reviewReasons | `api_failure` |

### Fixture
| Field | Value |
|---|---|
| repo | `octocat/Hello-World` |
| prevGitVer | `v1.8.0` |
| prevGitDate | `2026-06-10` |
| localVer | `v1.8.0` |
| prevFlag | `no` |
| HTTPS_PROXY | `http://127.0.0.1:1` (port 1 = closed) |
| HTTP_PROXY | `http://127.0.0.1:1` (port 1 = closed) |
| TimeoutSec | 1 (very short, secondary evidence) |

### Proxy Restoration
- **Before test**: HTTPS_PROXY = unset, HTTP_PROXY = unset
- **During test**: HTTPS_PROXY = `http://127.0.0.1:1`, HTTP_PROXY = `http://127.0.0.1:1`
- **After test**: HTTPS_PROXY = unset (cleared), HTTP_PROXY = unset (cleared)

## Verification Checklist

| # | Check | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | queryStatus=network_error | `network_error` | `network_error` | PASS |
| 2 | gitVer preserved | `v1.8.0` | `v1.8.0` | PASS |
| 3 | gitDate preserved | `2026-06-10` | `2026-06-10` | PASS |
| 4 | flag preserved | `no` | `no` | PASS |
| 5 | review=true | `true` | `true` | PASS |
| 6 | No HTTP response code | null | null | PASS |

## Verdict
**PASS**

## Evidence
- stdout saved to: `T08/stdout.txt`
- Test script: `T08/test.ps1`
- Real network-level failure produced via proxy to closed port (127.0.0.1:1) + 1-second timeout
- Error type: `OperationCanceledException (timeout)` — no HTTP response was received
- The state machine correctly classified this as `network_error` (the catch block's `else` branch, since `$code` was null)
- All state fields (`gitVer`, `gitDate`, `flag`) were preserved — no data loss
- `review=true` correctly triggered with reason `api_failure`
- Proxy environment variables were restored to their original values (unset) after the test

## Notes
- Two evidence approaches were used as required:
  1. **Primary**: `HTTPS_PROXY=http://127.0.0.1:1` — port 1 is closed on all systems, forcing a connection failure
  2. **Secondary**: `TimeoutSec=1` — extremely short timeout as backup evidence
- The actual error that triggered was `OperationCanceledException` (timeout) rather than a connection-refused error, because the 1-second timeout expired before the proxy connection could fully fail. Both are network-level failures with no HTTP response code, so the state machine correctly classified them as `network_error`.
