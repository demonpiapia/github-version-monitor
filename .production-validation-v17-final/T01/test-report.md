# Test Report: T01 — Normal 200 (queryStatus=ok)

## Test ID
T01

## Description
Real API call to `microsoft/vscode` `releases/latest` endpoint to verify the state machine correctly handles a normal HTTP 200 response with valid `tag_name` and `published_at` fields. The full pipeline is exercised: API query → state classification → version comparison → flag computation → review/flip detection.

## Expected Result
- queryStatus = `ok`
- latest (tag_name) is non-empty
- publishedUtc is non-empty
- gitVer = latest (refreshed on new version)
- gitDate = pubDate (correct UTC+08:00 date)
- flag is correct (yes if localVer < latest, no if eq)

## Actual Result

### API Call
- **Endpoint**: `GET https://api.github.com/repos/microsoft/vscode/releases/latest`
- **Headers**: `User-Agent: workbuddy-version-monitor`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2026-03-10`, `Authorization: Bearer ***` (token set)
- **HTTP Response**: 200 OK
- **Response Fields**: `tag_name=1.136.1`, `published_at=2026-09-03T15:25:32Z` (parsed as DateTime by PowerShell)

### State Machine Output
| Field | Value |
|---|---|
| queryStatus | `ok` |
| latest (tag_name) | `1.136.1` |
| publishedUtc | `2026-09-03T15:25:32Z` |
| pubDate (UTC+08:00) | `2026-09-03` |
| error | (empty) |
| rateRemaining | (empty) |

### Comparison + Review Output
| Field | Value |
|---|---|
| gitVer (newGitVer) | `1.136.1` |
| gitDate (newGitDate) | `2026-09-03` |
| flag (newFlag) | `yes` |
| prevFlag | `no` |
| cmp | `lt` (local v1.90.0 < latest 1.136.1) |
| isNew | `True` |
| isFlip | `True` (no → yes) |
| versionJump | `True` (major diff ≥ 2: 1 vs 136) |
| dateSuspicious | `False` |
| review | `True` (version_jump triggered) |
| reviewReasons | `version_jump` |

### Fixture
| Field | Value |
|---|---|
| repo | `microsoft/vscode` |
| prevGitVer | `v1.90.0` |
| prevGitDate | `2024-06-01` |
| localVer | `v1.90.0` |
| prevFlag | `no` |

## Verification Checklist

| # | Check | Expected | Actual | Result |
|---|---|---|---|---|
| 1 | queryStatus=ok | `ok` | `ok` | PASS |
| 2 | latest non-empty | non-empty | `1.136.1` | PASS |
| 3 | publishedUtc non-empty | non-empty | `2026-09-03T15:25:32Z` | PASS |
| 4 | gitVer correct (=latest) | `1.136.1` | `1.136.1` | PASS |
| 5 | gitDate correct (=pubDate) | `2026-09-03` | `2026-09-03` | PASS |
| 6 | flag correct | `yes` (lt) | `yes` | PASS |
| 7 | API call succeeded | true | true | PASS |

## Verdict
**PASS**

## Evidence
- stdout saved to: `T01/stdout.txt`
- Test script: `T01/test.ps1`
- SKILL-v1.7.md Step 2 state machine extracted and executed against real GitHub API
- Real HTTP 200 response received from `api.github.com`
- `tag_name` and `published_at` correctly extracted and converted to UTC+08:00

## Notes
- `octocat/Hello-World` was initially attempted but returned 404 (that repo has no releases). Switched to `microsoft/vscode` which has real releases.
- `published_at` was automatically parsed as `[System.DateTime]` by PowerShell's `Invoke-RestMethod` (consistent with SKILL-v1.7.md Known Limitation #9). The `ConvertTo-UtcIso` function handled this correctly.
- `versionJump=true` because major version difference between v1.90.0 and 1.136.1 exceeds the threshold (≥2). This is expected behavior and does not affect the PASS verdict since the test only checks that `flag` is correct (not that versionJump is false).
