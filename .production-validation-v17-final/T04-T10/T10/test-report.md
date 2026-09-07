# Test Report: T10

## Test ID
T10

## Description
200 + tag_name present but published_at missing => queryStatus=metadata_incomplete

## Expected Result
``metadata_incomplete``

## Actual Result
``metadata_incomplete``

## Verdict
**PASS**

## Evidence
HTTP status: 200; body JSON has tag_name='v1.0.0' but no published_at; observed queryStatus: metadata_incomplete; error: tag_name present but published_at missing

## Detailed Fields

| Field | Value |
|-------|-------|
| bodySent | {"tag_name": "v1.0.0"} |
| httpStatus | 200 |
| observedQueryStatus | metadata_incomplete |

## Functions Under Test

- `Get-ResponseHeaderValue` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 323-329)
- `ConvertTo-UtcIso` - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 307-313)
- State machine catch block - Extracted verbatim from SKILL-v1.7.md Step 2 (lines 352-368)

## Test Method

Local HTTP listener (`System.Net.HttpListener`) on port 18345 returns configured HTTP responses. Real `Invoke-RestMethod` calls hit the listener. The actual `Get-ResponseHeaderValue` function and catch block logic from SKILL-v1.7.md are executed against the real response headers.


