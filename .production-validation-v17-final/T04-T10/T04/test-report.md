# Test Report: T04

## Test ID
T04

## Description
403 + X-RateLimit-Remaining=0 => queryStatus=rate_limited (CORE: no retry, no Step4, no HTML)

## Expected Result
``rate_limited``

## Actual Result
``rate_limited``

## Verdict
**PASS**

## Evidence
HTTP status: 403; X-RateLimit-Remaining header sent: '0'; observed queryStatus: rate_limited; rateRemaining read by Get-ResponseHeaderValue: '0'

## Detailed Fields

| Field | Value |
|-------|-------|
| actualHtmlRequests | 0 |
| actualLatestRequests | 1 |
| actualReviewApiRequests | 0 |
| httpStatus | 403 |
| observedQueryStatus | rate_limited |
| rateLimitRemaining | 0 |
| rateRemainingReadByFunction | 0 |
| retryCount | 0 |
| runtime | PowerShell 7.6.4 |

## Functions Under Test

- `Get-ResponseHeaderValue` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 323-329)
- `ConvertTo-UtcIso` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 307-313)
- State machine catch block - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 352-368)

## Test Method

Local HTTP listener (`System.Net.HttpListener`) on port 18345 returns configured HTTP responses. Real `Invoke-RestMethod` calls hit the listener. The actual `Get-ResponseHeaderValue` function and catch block logic from SKILL-v1.7.md are executed against the real response headers.


