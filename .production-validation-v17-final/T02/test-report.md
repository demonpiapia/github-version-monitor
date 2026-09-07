# Test Report: T02 — 404 / not_found

## Test ID
T02

## Description
Real API call to a non-existent GitHub repo (`octocat/this-repo-does-not-exist-99999`) to verify the state machine correctly handles HTTP 404 by classifying it as `not_found`, clearing `gitVer` and `gitDate`, preserving the `flag`, and triggering `review=true` with reason `not_found`.

## Expected Result
- queryStatus = `not_found`
- gitVer = `""` (empty)
- gitDate = `""` (empty)
- flag == prevFlag (preserved)
- review = `true`
- reviewReasons contains `not_found`
- Error info NOT written into gitVer
- HTML result NOT used as API fact

## Actual Result

### API Call
- **Endpoint**: `GET https://api.github.com/repos/octocat/this-repo-does-not-exist-99999/releases/latest`
- **Headers**: `User-Agent: workbuddy-version-monitor`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2026-03-10`, `Authorization: Bearer ***` (token set)
- **HTTP Response**: 404 Not Found
- **Actual HTTP Code**: 404

### State Machine Output
| Field | Value |
|---|---|
| queryStatus | `not_found` |
| latest (tag_name) | `` (empty) |
| publishedUtc | `` (empty) |
| pubDate | `` (empty) |
| error | `Response status code does not indicate success: 404 (Not Found).` |
| rateRemaining | `4997` |
| actualHttpCode | `404` |

### Comparison + Review Output
| Field | Value |
|---|---|
| gitVer (newGitVer) | `` (empty — per not_found semantics) |
| gitDate (newGitDate) | `` (empty — per not_found semantics) |
| flag (newFlag) | `no` (preserved from prevFlag) |
| prevFlag | `no` |
| cmp | `` (empty — no comparison performed) |
| isNew | `False` |
| isFlip | `False` |
| review | `True` |
| reviewReasons | `not_found` |

### Fixture
| Field | Value |
|---|---|
| repo | `octocat/this-repo-does-not-exist-99999` |
| prevGitVer | `v1.0.0` |
| prevGitDate | `2026-01-15` |
| localVer | `v1.0.0` |
| prevFlag | `no` |

## Verification Checklist

| # | Check | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | queryStatus=not_found | `not_found` | `not_found` | PASS |
| 2 | gitVer empty | `""` | `""` | PASS |
| 3 | gitDate empty | `""` | `""` | PASS |
| 4 | flag preserved (==prevFlag) | `no` | `no` | PASS |
| 5 | review=true | `true` | `true` | PASS |
| 6 | reviewReasons contains not_found | contains `not_found` | `not_found` | PASS |
| 7 | Error info NOT in gitVer | no error text in gitVer | gitVer=`""` | PASS |
| 8 | HTML result NOT used as API fact | latest stays empty | latest=`""` | PASS |

## Verdict
**PASS**

## Evidence
- stdout saved to: `T02/stdout.txt`
- Test script: `T02/test.ps1`
- Real HTTP 404 response received from `api.github.com` for a non-existent repo
- The `not_found` special semantics correctly cleared `gitVer` and `gitDate` while preserving `flag`
- No HTML fallback was attempted — `latest` remains empty, confirming HTML is not used as API fact
- Error message was stored in `error` field only, NOT in `gitVer`
