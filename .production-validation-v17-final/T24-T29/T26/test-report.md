# Test Report: T26

## Test ID
T26

## Description
Test invalid flag values in column 6 (是否更新) that must produce PARSE_ERROR, and valid lowercase flags that must NOT produce PARSE_ERROR. Confirm case-sensitivity: yes != YES, no != NO.

## Fixture Files
| Fixture | Flag Value | Expected | Actual |
|---|---|---|---|
| `fixture_inv_upper_yes.md` | YES | PARSE_ERROR | PARSE_ERROR — "第 6 列 flag 非法" |
| `fixture_inv_title_yes.md` | Yes | PARSE_ERROR | PARSE_ERROR — "第 6 列 flag 非法" |
| `fixture_inv_mixed_yes.md` | yEs | PARSE_ERROR | PARSE_ERROR — "第 6 列 flag 非法" |
| `fixture_inv_upper_no.md` | NO | PARSE_ERROR | PARSE_ERROR — "第 6 列 flag 非法" |
| `fixture_inv_title_no.md` | No | PARSE_ERROR | PARSE_ERROR — "第 6 列 flag 非法" |
| `fixture_inv_pending.md` | pending | PARSE_ERROR | PARSE_ERROR — "第 6 列 flag 非法" |
| `fixture_inv_true.md` | true | PARSE_ERROR | PARSE_ERROR — "第 6 列 flag 非法" |
| `fixture_valid_yes.md` | yes | NO PARSE_ERROR | NO PARSE_ERROR (empty output) |
| `fixture_valid_no.md` | no | NO PARSE_ERROR | NO PARSE_ERROR (empty output) |

## Expected Result
- All 7 invalid flags (YES, Yes, yEs, NO, No, pending, true) → PARSE_ERROR
- Valid lowercase "yes" and "no" → no PARSE_ERROR (empty output)
- Confirms yes != YES and no != NO (case-sensitive matching via `-cnotmatch '^(yes|no)$'`)

## Actual Result
All 7 invalid flags produced PARSE_ERROR with message "第 6 列 flag 非法".
Valid "yes" and "no" produced no output (no PARSE_ERROR).

## Case-Sensitivity Confirmation
- `YES` was rejected while `yes` was accepted → yes != YES ✓
- `NO` was rejected while `no` was accepted → no != NO ✓
- Parser uses `-cnotmatch '^(yes|no)$'` (case-sensitive, `c` prefix)

## Verdict
**PASS** — All 9 sub-tests passed. Invalid flags correctly rejected, valid flags correctly accepted, case-sensitivity confirmed.
