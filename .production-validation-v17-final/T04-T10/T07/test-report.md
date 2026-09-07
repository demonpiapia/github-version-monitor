# Test Report: T07

## Test ID
T07

## Description
500 => queryStatus=server_error

## Expected Result
``server_error``

## Actual Result
``server_error``

## Verdict
**PASS**

## Evidence
HTTP status: 500; observed queryStatus: server_error

## Detailed Fields

| Field | Value |
|-------|-------|
| httpStatus | 500 |
| observedQueryStatus | server_error |

## Functions Under Test

- `Get-ResponseHeaderValue` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 323-329)
- `ConvertTo-UtcIso` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 307-313)
- State machine catch block - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 352-368)

## Test Method

Local HTTP listener (`System.Net.HttpListener`) on port 18345 returns configured HTTP responses. Real `Invoke-RestMethod` calls hit the listener. The actual `Get-ResponseHeaderValue` function and catch block logic from SKILL-v1.7.md are executed against the real response headers.


