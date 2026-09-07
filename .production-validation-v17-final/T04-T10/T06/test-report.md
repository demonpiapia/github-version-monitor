# Test Report: T06

## Test ID
T06

## Description
429 => queryStatus=rate_limited (no retry, no Step4)

## Expected Result
``rate_limited``

## Actual Result
``rate_limited``

## Verdict
**PASS**

## Evidence
HTTP status: 429; observed queryStatus: rate_limited

## Detailed Fields

| Field | Value |
|-------|-------|
| httpStatus | 429 |
| observedQueryStatus | rate_limited |

## Functions Under Test

- `Get-ResponseHeaderValue` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 323-329)
- `ConvertTo-UtcIso` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 307-313)
- State machine catch block - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 352-368)

## Test Method

Local HTTP listener (`System.Net.HttpListener`) on port 18345 returns configured HTTP responses. Real `Invoke-RestMethod` calls hit the listener. The actual `Get-ResponseHeaderValue` function and catch block logic from SKILL-v1.7.md are executed against the real response headers.


