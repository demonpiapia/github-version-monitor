# T44 — v1.6 → v1.7 Diff Integrity

**Status: PASS**

## Test Objective
Verify SHA256 integrity of v1.6 and v1.7 files, analyze the diff for unexpected deletions of v1.6 capabilities, unexpected additions, and forbidden patterns.

## Step 1: SHA256 Verification

| File | Actual SHA256 | Stored SHA256 | Match |
|------|--------------|---------------|-------|
| SKILL-v1.6.md | 7480B6B5E34BDD8B2F07552F8B174F41421BB7BF3537A8486DF35A9BC3F55CD7 | 7480B6B5E34BDD8B2F07552F8B174F41421BB7BF3537A8486DF35A9BC3F55CD7 | ✅ |
| SKILL-v1.7.md | F386879CCB1CA4C88D6DDBC5D9057D906913897C743F03151ABE164108B97DDC | F386879CCB1CA4C88D6DDBC5D9057D906913897C743F03151ABE164108B97DDC | ✅ |

Both SHA256 files exist and match the actual file hashes.

## Step 2: Diff File Verification

The diff file `v16-v17.diff` exists at `.production-validation-v17-final/v16-v17.diff` (931 lines, git unified diff format).

## Step 3: UNEXPECTED_DELETIONS Check

All 14 v1.6 capabilities verified present in v1.7:

| # | Capability | Present in v1.7 | Evidence (line numbers in v1.7) |
|---|------------|-----------------|-------------------------------|
| 1 | versionJump | ✅ | Schema L107, Code L380, Contract L118, Status L681 |
| 2 | dateSuspicious | ✅ | Schema L107, Code L380, Contract L119, Status L681 |
| 3 | reviewReasons | ✅ | Schema L107, Code L380, Step4 L478 |
| 4 | result.fetch.tmp | ✅ | Code L397, Error L403, Changelog L715 |
| 5 | result.review.tmp | ✅ | Code L474, Docs L468, Table L671 |
| 6 | schema validation | ✅ | Invariant L51, Parse L319, Contract L91 |
| 7 | RUN_STATUS\|success\| | ✅ | Code L598, Contract L123 |
| 8 | RUN_STATUS\|failed\| | ✅ | Code L596/L600, Contract L123 |
| 9 | 404 → not_found | ✅ | State machine L132, Code L361, Status L680 |
| 10 | lock heartbeat | ✅ | Steps 1-4 (L190, L249, L435, L476) |
| 11 | lock ownership | ✅ | Step2 L439, Step5 L584-595 |
| 12 | atomic md commit | ✅ | Code L578 (Move-Item), Contract L75 |
| 13 | atomic result persistence | ✅ | Code L407 (fetch), L479 (review) |
| 14 | strict lowercase yes/no | ✅ | Parse L318 (-cnotmatch), Stats L388 (-ceq), Validate L565 (-cnotmatch), Header L576 (-ceq) |

**UNEXPECTED_DELETIONS: NONE**

## Step 4: UNEXPECTED_ADDITIONS (ALLOWED) Check

All 5 allowed additions verified present:

| # | Addition | Present | Evidence |
|---|----------|---------|----------|
| 1 | Get-ResponseHeaderValue | ✅ | Function L323-329, Called L357 |
| 2 | PS5.1/PS7 HTTP header compatibility | ✅ | L9 declaration, L323-329 multi-type handling |
| 3 | T04 rate_limited compatibility fix | ✅ | Changelog L715 |
| 4 | Production environment description | ✅ | L9 |
| 5 | v1.7 changelog | ✅ | L715 |

**UNEXPECTED_ADDITIONS: NONE** (all additions are in the ALLOWED list)

## Step 5: FORBIDDEN Patterns Check

Searched the full diff for all 12 forbidden patterns:

| Pattern | Found | Notes |
|---------|-------|-------|
| mock URL | ❌ No | — |
| localhost production bypass | ❌ No | — |
| debug bypass | ❌ No | — |
| test-only branch | ❌ No | — |
| hardcoded test repository | ❌ No | — |
| hardcoded token (ghp_/github_pat_) | ❌ No | — |
| forced success | ❌ No | — |
| forced rate_limited | ❌ No | — |
| skip schema | ❌ No | — |
| skip lock | ❌ No | — |
| skip review | ❌ No (false positive) | Diff L637 matched `skip.*review` regex due to `skipped_rate_limited` status string — this is correct rate_limited handling, not a review bypass |
| skip commit | ❌ No | — |

**FORBIDDEN_PATTERNS: NONE**

## Diff Analysis Summary

The v1.6 → v1.7 diff is primarily a code reformatting + compatibility enhancement:
- Code blocks reformatted (multi-line → compact single-line where appropriate)
- `Get-ResponseHeaderValue` function added for PS5.1/PS7 header type compatibility
- T04 fix: 403 + X-RateLimit-Remaining now uses the new header reader
- Production runtime explicitly declared as PS7.x
- Documentation tables condensed (e.g., 5.4 status table, .monitor products table)
- No functional capabilities removed; all v1.6 logic preserved in code

## Final Verdict

**T44 = PASS**
