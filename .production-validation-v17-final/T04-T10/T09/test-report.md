# Test Report: T09

## Test ID
T09

## Description
200 + JSON body without tag_name => queryStatus=invalid_response

## Expected Result
``invalid_response``

## Actual Result
``invalid_response``

## Verdict
**PASS**

## Evidence
HTTP status: 200; body JSON has no tag_name field; observed queryStatus: invalid_response; error: 200 but empty tag_name

## Detailed Fields

| Field | Value |
|-------|-------|
| bodySent | {"id": 1, "name": "test"} |
| httpStatus | 200 |
| observedQueryStatus | invalid_response |

## Functions Under Test

- `Get-ResponseHeaderValue` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 323-329)
- `ConvertTo-UtcIso` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 307-313)
- State machine catch block - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 352-368)

## Test Method

Local HTTP listener (`System.Net.HttpListener`) on port 18345 returns configured HTTP responses. Real `Invoke-RestMethod` calls hit the listener. The actual `Get-ResponseHeaderValue` function and catch block logic from SKILL-v1.7.md are executed against the real response headers.


