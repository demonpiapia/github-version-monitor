# Production Validation v1.7 Final - Test Report (T11-T17)

**Generated:** 2026-09-07 13:25:28 +08:00
**Script:** `test.ps1`

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | 18 |
| PASS | 18 |
| FAIL | 0 |
| Overall | ALL PASS |

## Test Details

### T11

| Field | Value |
|-------|-------|
| Test ID | T11 |
| Description | Compare-Ver '1.2.3' '1.2.4' should return 'lt' (1.2.3 < 1.2.4) |
| Expected | `lt` |
| Actual | `lt` |
| Verdict | **PASS** |
| Evidence | Compare-Ver '1.2.3' '1.2.4' returned: lt |

### T12

| Field | Value |
|-------|-------|
| Test ID | T12 |
| Description | Compare-Ver '1.2.10' '1.2.9' should return 'gt' (numeric 10 > 9, not string '10' < '9') |
| Expected | `gt` |
| Actual | `gt` |
| Verdict | **PASS** |
| Evidence | Compare-Ver '1.2.10' '1.2.9' returned: gt |

### T13

| Field | Value |
|-------|-------|
| Test ID | T13 |
| Description | Compare-Ver '1.2.3-rc1' '1.2.3' should return 'lt' (prerelease is less than stable) |
| Expected | `lt` |
| Actual | `lt` |
| Verdict | **PASS** |
| Evidence | Compare-Ver '1.2.3-rc1' '1.2.3' returned: lt |

### T14a

| Field | Value |
|-------|-------|
| Test ID | T14a |
| Description | Compare-Ver 'some-weird-version' '1.2.3' should return 'incomparable' (non-parseable version) |
| Expected | `incomparable` |
| Actual | `incomparable` |
| Verdict | **PASS** |
| Evidence | Compare-Ver 'some-weird-version' '1.2.3' returned: incomparable |

### T14b

| Field | Value |
|-------|-------|
| Test ID | T14b |
| Description | Compare-Ver 'v1.0' '1.0' should return 'eq' (v-prefix is stripped, then 1.0 == 1.0) |
| Expected | `eq` |
| Actual | `eq` |
| Verdict | **PASS** |
| Evidence | Compare-Ver 'v1.0' '1.0' returned: eq |

### T15a

| Field | Value |
|-------|-------|
| Test ID | T15a |
| Description | versionJump: major 1->2 (diff=1, threshold >=2) should NOT be a jump |
| Expected | `False` |
| Actual | `False` |
| Verdict | **PASS** |
| Evidence | Test-VersionJump '1.0.0' '2.0.0' = False (major diff=1 < 2) |

### T15b

| Field | Value |
|-------|-------|
| Test ID | T15b |
| Description | versionJump: major 1->3 (diff=2, threshold >=2) should be a jump |
| Expected | `True` |
| Actual | `True` |
| Verdict | **PASS** |
| Evidence | Test-VersionJump '1.0.0' '3.0.0' = True (major diff=2 >= 2) |

### T15c

| Field | Value |
|-------|-------|
| Test ID | T15c |
| Description | versionJump: minor 9->10 same major (diff=1, threshold >=10) should NOT be a jump |
| Expected | `False` |
| Actual | `False` |
| Verdict | **PASS** |
| Evidence | Test-VersionJump '1.9.0' '1.10.0' = False (minor diff=1 < 10) |

### T15d

| Field | Value |
|-------|-------|
| Test ID | T15d |
| Description | versionJump: minor 0->10 same major (diff=10, threshold >=10) should be a jump |
| Expected | `True` |
| Actual | `True` |
| Verdict | **PASS** |
| Evidence | Test-VersionJump '1.0.0' '1.10.0' = True (minor diff=10 >= 10) |

### T15e

| Field | Value |
|-------|-------|
| Test ID | T15e |
| Description | versionJump: minor 0->9 same major (diff=9, threshold >=10) should NOT be a jump |
| Expected | `False` |
| Actual | `False` |
| Verdict | **PASS** |
| Evidence | Test-VersionJump '1.0.0' '1.9.0' = False (minor diff=9 < 10) |

### T15f

| Field | Value |
|-------|-------|
| Test ID | T15f |
| Description | versionJump: patch 49->50 same major+minor (diff=1, threshold >=50) should NOT be a jump |
| Expected | `False` |
| Actual | `False` |
| Verdict | **PASS** |
| Evidence | Test-VersionJump '1.0.49' '1.0.50' = False (patch diff=1 < 50) |

### T15g

| Field | Value |
|-------|-------|
| Test ID | T15g |
| Description | versionJump: patch 0->50 same major+minor (diff=50, threshold >=50) should be a jump |
| Expected | `True` |
| Actual | `True` |
| Verdict | **PASS** |
| Evidence | Test-VersionJump '1.0.0' '1.0.50' = True (patch diff=50 >= 50) |

### T15h

| Field | Value |
|-------|-------|
| Test ID | T15h |
| Description | versionJump: patch 0->49 same major+minor (diff=49, threshold >=50) should NOT be a jump |
| Expected | `False` |
| Actual | `False` |
| Verdict | **PASS** |
| Evidence | Test-VersionJump '1.0.0' '1.0.49' = False (patch diff=49 < 50) |

### T16

| Field | Value |
|-------|-------|
| Test ID | T16 |
| Description | dateSuspicious: prevGitDate '2026-06-01' is later than publishedUtc '2026-01-01T00:00:00Z' Beijing date (2026-01-01), should return True |
| Expected | `True` |
| Actual | `True` |
| Verdict | **PASS** |
| Evidence | Test-DateSuspicious publishedUtc='2026-01-01T00:00:00Z' prevGitDate='2026-06-01' = True (new Beijing date 2026-01-01 < old date 2026-06-01) |

### T16-neg

| Field | Value |
|-------|-------|
| Test ID | T16-neg |
| Description | dateSuspicious (negative): prevGitDate '2026-01-01' is earlier than publishedUtc '2026-06-01T00:00:00Z' Beijing date (2026-06-01), should return False |
| Expected | `False` |
| Actual | `False` |
| Verdict | **PASS** |
| Evidence | Test-DateSuspicious publishedUtc='2026-06-01T00:00:00Z' prevGitDate='2026-01-01' = False (new Beijing date 2026-06-01 > old date 2026-01-01) |

### T17

| Field | Value |
|-------|-------|
| Test ID | T17 |
| Description | isFlip: prevFlag='no', localVer='1.0.0' < latest='1.0.1' (cmp=lt, newFlag=yes), should flip to True |
| Expected | `True` |
| Actual | `True` |
| Verdict | **PASS** |
| Evidence | Test-IsFlip prevFlag='no' localVer='1.0.0' latest='1.0.1' = True (Compare-Ver returned lt, newFlag=yes, prevFlag=no -> flip) |

### T17-neg

| Field | Value |
|-------|-------|
| Test ID | T17-neg |
| Description | isFlip (negative): prevFlag='yes' already, localVer='1.0.0' < latest='1.0.1' (newFlag=yes but prevFlag=yes), should NOT flip |
| Expected | `False` |
| Actual | `False` |
| Verdict | **PASS** |
| Evidence | Test-IsFlip prevFlag='yes' localVer='1.0.0' latest='1.0.1' = False (newFlag=yes but prevFlag already yes -> no flip) |

### T17-neg2

| Field | Value |
|-------|-------|
| Test ID | T17-neg2 |
| Description | isFlip (negative): prevFlag='no', localVer='1.0.1' >= latest='1.0.0' (newFlag=no), should NOT flip |
| Expected | `False` |
| Actual | `False` |
| Verdict | **PASS** |
| Evidence | Test-IsFlip prevFlag='no' localVer='1.0.1' latest='1.0.0' = False (Compare-Ver returned gt, newFlag=no, no flip) |

## Functions Under Test

- `ConvertTo-NormVer` - Parses version strings into structured objects (Major/Minor/Patch/Pre/PreName/PreNum)
- `Compare-Ver` - Compares two version strings, returns `eq`/`lt`/`gt`/`incomparable`
- `Test-VersionJump` - Detects suspiciously large version jumps (major>=2, minor>=10 same major, patch>=50 same major+minor)
- `Test-DateSuspicious` - Detects when published date (UTC->Beijing) is earlier than previously known git date
- `Test-IsFlip` - Detects when prevFlag was 'no' and new flag becomes 'yes' (localVer < latest)


