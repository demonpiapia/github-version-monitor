# Test Report: T05

## Test ID
T05

## Description
403 + X-RateLimit-Remaining=50 (>0) => queryStatus=forbidden (NOT rate_limited)

## Expected Result
``forbidden``

## Actual Result
``forbidden``

## Verdict
**PASS**

## Evidence
HTTP status: 403; X-RateLimit-Remaining header sent: '50'; observed queryStatus: forbidden; rateRemaining read: '50'

## Detailed Fields

| Field | Value |
|-------|-------|
| httpStatus | 403 |
| observedQueryStatus | forbidden |
| rateLimitRemaining | 50 |
| rateRemainingReadByFunction | 50 |

## Functions Under Test

- `Get-ResponseHeaderValue` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 323-329)
- `ConvertTo-UtcIso` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 307-313)
- State machine catch block - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 352-368)

## Test Method

Local HTTP listener (`System.Net.HttpListener`) on port 18345 returns configured HTTP responses. Real `Invoke-RestMethod` calls hit the listener. The actual `Get-ResponseHeaderValue` function and catch block logic from SKILL-v1.7.md are executed against the real response headers.


