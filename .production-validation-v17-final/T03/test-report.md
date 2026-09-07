# Test Report: T03 — 401 auth_error

## Test ID
T03

## Description
Real API call to `octocat/Hello-World` with an invalid GitHub token (`ghp_invalid_token_12345_fake`) to verify the state machine correctly handles HTTP 401 by classifying it as `auth_error`, preserving all state fields (`gitVer`, `gitDate`, `flag`), and triggering `review=true`.

## Expected Result
- queryStatus = `auth_error`
- gitVer preserved (not changed)
- gitDate preserved (not changed)
- flag preserved (not changed)
- review = `true`
- Original `GITHUB_TOKEN` restored after test

## Actual Result

### API Call
- **Endpoint**: `GET https://api.github.com/repos/octocat/Hello-World/releases/latest`
- **Headers**: `User-Agent: workbuddy-version-monitor`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2026-03-10`, `Authorization: Bearer ghp_invalid_token_12345_fake` (invalid token)
- **HTTP Response**: 401 Unauthorized
- **Actual HTTP Code**: 401

### State Machine Output
| Field | Value |
|---|---|
| queryStatus | `auth_error` |
| latest (tag_name) | `` (empty) |
| publishedUtc | `` (empty) |
| error | `Response status code does not indicate success: 401 (Unauthorized).` |
| rateRemaining | `` (empty) |
| actualHttpCode | `401` |

### Comparison + Review Output
| Field | Value |
|---|---|
| gitVer (newGitVer) | `v1.5.0` (preserved) |
| gitDate (newGitDate) | `2026-03-20` (preserved) |
| flag (newFlag) | `no` (preserved) |
| prevFlag | `no` |
| review | `True` |
| reviewReasons | `api_failure` |

### Fixture
| Field | Value |
|---|---|
| repo | `octocat/Hello-World` |
| prevGitVer | `v1.5.0` |
| prevGitDate | `2026-03-20` |
| localVer | `v1.5.0` |
| prevFlag | `no` |
| Token used | `ghp_invalid_token_12345_fake` (invalid) |

### Token Restoration
- **Before test**: GITHUB_TOKEN = `set` (original value)
- **During test**: GITHUB_TOKEN = `ghp_invalid_token_12345_fake` (invalid)
- **After test**: GITHUB_TOKEN = `set` (restored to original value)

## Verification Checklist

| # | Check | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | queryStatus=auth_error | `auth_error` | `auth_error` | PASS |
| 2 | gitVer preserved | `v1.5.0` | `v1.5.0` | PASS |
| 3 | gitDate preserved | `2026-03-20` | `2026-03-20` | PASS |
| 4 | flag preserved | `no` | `no` | PASS |
| 5 | review=true | `true` | `true` | PASS |
| 6 | GITHUB_TOKEN restored | original value restored | `set` (restored) | PASS |

## Verdict
**PASS**

## Evidence
- stdout saved to: `T03/stdout.txt`
- Test script: `T03/test.ps1`
- Real HTTP 401 response received from `api.github.com` with an invalid token
- All state fields (`gitVer`, `gitDate`, `flag`) were preserved — no data loss
- `review=true` correctly triggered with reason `api_failure`
- GITHUB_TOKEN was temporarily set to invalid value for the duration of the test, then restored to the original value
- The test confirms that auth errors do not corrupt the monitoring state
