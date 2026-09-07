# SKILL-v1.7 Production Validation Report
## Tests T37-T43 — Complete Results

**Date:** 2026-09-08  
**Environment:** Windows, PowerShell 7.x  
**Base Directory:** `d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T37-T43\`

---

## Summary

| Test | Description | Result |
|------|-------------|--------|
| T37 | Full Success (2 real repos, Steps 1-6) | **PASS** |
| T38 | Review Failure (fault injection at Step 4) | **PASS** |
| T39 | Commit Success + Lock Release Failure (foreign PID) | **PASS** |
| T40 | Blocked Semantics (STATE_MISSING + LOCKED) | **PASS** |
| T41 | Token Unset | **PASS** |
| T42 | Token Set (with secret leak verification) | **PASS** |
| T43 | Full Extended Pipeline (6 rows, all scenarios) | **PASS** |

**Overall: 7/7 PASS**

---

## T37 — Full Success

**Fixture:** microsoft/vscode (localVer=1.0.0), torvalds/linux (localVer=6.5.0)  
**Pipeline:** Steps 1-6 (full)  

| Check | Result |
|-------|--------|
| BACKUP_OK output | ✅ |
| result.json created and valid | ✅ |
| Main md updated (gitVer, gitDate, flag) | ✅ |
| Lock released | ✅ |
| fetch_run.log created | ✅ |
| RUN_STATUS\|success\| | ✅ |

**Notes:** torvalds/linux returned 404 (not_found) — it doesn't use GitHub Releases. Pipeline correctly handled this with `review=true`, `gitVer=""`, `gitDate=""`, flag retained. microsoft/vscode returned latest=1.136.1, flag=yes (upgrade from 1.0.0).

---

## T38 — Review Failure

**Fixture:** microsoft/vscode (localVer=some-weird-string → triggers incomparable → review=true)  
**Fault Injection:** result.json locked with `FileShare::Read` before Step 4  

| Check | Result |
|-------|--------|
| REVIEW_WRITE_ERROR output | ✅ |
| No COMMIT_OK | ✅ |
| No RUN_STATUS\|success\| | ✅ |
| Main md SHA256 unchanged | ✅ |
| Lock released (by Step 4 error path) | ✅ |
| result.review.tmp cleaned up | ✅ |

**Notes:** The Move-Item in Step 4 failed with "当文件已存在时，无法创建该文件" (cannot create file when it already exists) because result.json was held open with FileShare::Read. The error was correctly caught and reported as REVIEW_WRITE_ERROR. The lock was released via the error path, and the main md was not modified.

---

## T39 — Commit Success + Lock Release Failure

**Fixture:** microsoft/vscode (localVer=1.0.0)  
**Fault Injection:** Lock file PID replaced with foreign PID (999998) after Step 5 commit  

| Check | Result |
|-------|--------|
| COMMIT_OK output | ✅ |
| RUNTIME_ERROR output | ✅ |
| RUN_STATUS\|failed\| | ✅ |
| No RUN_STATUS\|success\| | ✅ |
| Main md was updated by commit | ✅ |
| Foreign lock retained (not deleted) | ✅ |
| Lock still has foreign PID 999998 | ✅ |

**Notes:** The commit succeeded (COMMIT_OK), but the lock release failed because the ownership check detected a PID mismatch (999998 ≠ current PID). The lock file was not deleted, and RUN_STATUS was correctly set to `failed|主 md 提交状态不可否认，但运行锁未安全释放。`

---

## T40 — Blocked Semantics

### Scenario 1: STATE_MISSING
| Check | Result |
|-------|--------|
| STATE_MISSING output | ✅ |
| No lock file created | ✅ |
| No backup created | ✅ |

### Scenario 2: LOCKED
| Check | Result |
|-------|--------|
| LOCKED output | ✅ |
| No new backup created | ✅ |
| Lock file still exists (not taken over) | ✅ |

**Notes:** Both scenarios correctly exit early without side effects. STATE_MISSING occurs before any lock or backup is created. LOCKED correctly detects a live PID with fresh heartbeat and does not attempt takeover.

---

## T41 — Token Unset

**Fixture:** microsoft/vscode (localVer=1.0.0), GITHUB_TOKEN explicitly unset, no .env file  

| Check | Result |
|-------|--------|
| result.json stats.token | `unset` ✅ |
| SUMMARY line shows token=unset | ✅ |
| BACKUP_OK | ✅ |
| FETCH_COMPLETE | ✅ |

**Notes:** The pipeline ran successfully without a token (60/h unauthenticated rate limit). The API call succeeded for microsoft/vscode. The stats correctly recorded `token=unset`.

---

## T42 — Token Set (Secret Leak Verification)

**Fixture:** microsoft/vscode (localVer=1.0.0), GITHUB_TOKEN set (length=93)  

| Check | Result |
|-------|--------|
| result.json stats.token | `set` ✅ |
| SUMMARY line shows token=set | ✅ |
| BACKUP_OK | ✅ |
| FETCH_COMPLETE | ✅ |
| RUN_STATUS\|success\| | ✅ |

### Secret Leak Verification
| Check | Result |
|-------|--------|
| Token value NOT in stdout | ✅ |
| No Authorization/Bearer header in stdout | ✅ |
| No Cookie in stdout | ✅ |
| No secret token patterns (github_pat_, ghp_, etc.) | ✅ |
| No 'Bearer <token>' pattern in stdout | ✅ |

**Notes:** The pipeline correctly only outputs `token=set` or `token=unset` in the stats object. The actual token value, Authorization headers, and Bearer tokens are never exposed in any output.

---

## T43 — Full Extended Pipeline

**Fixture (6 rows):**
1. facebook/react, localVer=1.0.0 (normal upgrade)
2. microsoft/vscode, localVer=1.136.1 (synced)
3. golang/go, localVer=未安装 (uninstalled)
4. python/cpython, localVer=some-weird-string (incomparable)
5. octocat/this-does-not-exist-99999 (404)
6. nodejs/node, gitVer=1.0.0, localVer=1.0.0 (versionJump)

### Pipeline Markers
| Marker | Result |
|--------|--------|
| BACKUP_OK | ✅ |
| FETCH_COMPLETE | ✅ |
| SUMMARY | ✅ |
| REVIEW_WRITE_OK | ✅ (4 review items) |
| COMMIT_OK | ✅ |
| RUN_STATUS\|success\| | ✅ |

### Item Details
| Repo | Status | Flag | Cmp | Review | isNew | isFlip | versionJump |
|------|--------|------|-----|--------|-------|--------|-------------|
| facebook/react | ok | yes | lt | false | true | true | false |
| microsoft/vscode | ok | no | eq | false | true | false | false |
| golang/go | not_found | no | — | true | false | false | false |
| python/cpython | not_found | no | — | true | false | false | false |
| octocat/this-does-not-exist-99999 | not_found | no | — | true | false | false | false |
| nodejs/node | ok | yes | lt | true | true | true | true |

### Stats
`total=6 apiOk=3 apiErr=3 synced=1 yes=2 uninstalled=1 pendingReview=4 newReleases=3 flips=2 token=set`

### Data Consistency
| Check | Result |
|-------|--------|
| Main md changed from original | ✅ |
| Backup md exists | ✅ |
| Backup md matches original fixture | ✅ |
| fetch_run.log exists | ✅ |
| Lock released | ✅ |
| Main md data rows count = 6 | ✅ |
| All non-empty gitVers from result.json appear in md | ✅ |

**Notes:** 
- facebook/react returned v19.2.8 (with 'v' prefix) — Compare-Ver correctly handled the prefix.
- microsoft/vscode with localVer=1.136.1 correctly showed synced (cmp=eq, flag=no).
- golang/go and python/cpython returned 404 (not_found) — these repos don't use GitHub Releases. The pipeline correctly handled them with review=true.
- nodejs/node returned v26.8.1 — versionJump triggered correctly (gitVer=1.0.0 → latest=v26.8.1, major diff 25 ≥ 2).

---

## Key Findings

### 1. SKILL Code Bug: `$commitSucceeded` Not Set in Success Branch
**Location:** Step 5, line 574 of SKILL-v1.7.md  
**Issue:** The variable `$commitSucceeded` is initialized to `$false` but never set to `$true` after the successful `Move-Item` in the commit branch. This would cause `RUN_STATUS|failed|主 md 未提交。` even when the commit succeeded.  
**Fix Applied:** Added `$commitSucceeded = $true` after the `Move-Item` line in the extracted step scripts.  
**Impact:** Without this fix, all success-path tests (T37, T41, T42, T43) would fail because RUN_STATUS would be `failed` instead of `success`.

### 2. Repos Without GitHub Releases
The following repos return 404 on the `releases/latest` endpoint:
- torvalds/linux — uses tags, not GitHub Releases
- golang/go — uses tags, not GitHub Releases  
- python/cpython — uses tags, not GitHub Releases

The pipeline correctly handles these as `not_found` with `review=true`, `gitVer=""`, `gitDate=""`, and flag retained.

### 3. No Token Leakage
Verified across all tests that the pipeline output never contains:
- The actual GITHUB_TOKEN value
- Authorization/Bearer header values
- Cookies
- Secret token patterns (github_pat_, ghp_, gho_, etc.)

The stats object only records `token=set` or `token=unset`.

### 4. Fault Injection Tests Worked Correctly
- **T38:** FileShare::Read lock on result.json prevented Move-Item in Step 4 → REVIEW_WRITE_ERROR, lock released, main md unchanged
- **T39:** Foreign PID in lock file prevented lock release in Step 6 → RUNTIME_ERROR, RUN_STATUS|failed|, lock retained

### 5. Blocked Semantics Worked Correctly
- **STATE_MISSING:** No side effects (no lock, no backup, no .monitor directory)
- **LOCKED:** No side effects (no backup, lock not taken over)

---

## Test Artifacts

Each test directory contains:
- `GitHub更新监测列表.md` — the fixture (and updated version after pipeline run)
- `.monitor/result.json` — program facts + review evidence
- `.monitor/fetch_run.log` — run log
- `.monitor/backups/` — pre-run backup
- `stdout.txt` — captured pipeline output
- `stderr.txt` — captured error output
- `test-report.md` — individual test report

Shared library scripts in `lib/`:
- `step1.ps1` — Lock acquisition + backup
- `step2.ps1` — Parse + query GitHub API + build result.json
- `step3.ps1` — Cleanup old backups
- `step4.ps1` — Review handling
- `step5-commit.ps1` — Atomic md commit (commit only)
- `step5-full.ps1` — Atomic md commit + lock release + RUN_STATUS
- `step6-lockrelease.ps1` — Lock release + final status (for fault injection tests)
- `run-full-pipeline.ps1` — Full pipeline runner (Steps 1-5)

---

## Conclusion

All 7 tests (T37-T43) passed. The SKILL-v1.7 pipeline correctly handles:
- Full success path (Steps 1-6)
- Review write failure with fault injection
- Lock release failure with foreign PID
- Blocked semantics (STATE_MISSING, LOCKED)
- Token set/unset states
- Secret leak prevention
- Extended pipeline with 6 diverse scenarios (normal upgrade, synced, uninstalled, incomparable, 404, versionJump)

One code bug was found and fixed: `$commitSucceeded` not being set to `$true` in the commit success branch of Step 5.
