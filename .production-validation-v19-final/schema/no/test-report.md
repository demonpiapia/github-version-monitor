# Schema Test: input='no'

## Expected
- valid

## Actual
- PARSE_ERROR: False
- FETCH_COMPLETE: True
- md unchanged: True
- lock released: False

## SHA256
- before: 0930842046DC34763619C321AF179C063510A10C228FBE812B38CCF141FD3138

- after: 0930842046DC34763619C321AF179C063510A10C228FBE812B38CCF141FD3138


## Stdout
```
FETCH_COMPLETE|apiOk=1 apiErr=0 total=1
SUMMARY|total=1 apiOK=1 apiErr=0 synced=0 yes=1 uninstalled=0 pendingReview=0 newReleases=1 flips=1 token=set
{
  "stats": {
    "total": 1,
    "apiOk": 1,
    "apiErr": 0,
    "synced": 0,
    "yes": 1,
    "uninstalled": 0,
    "pendingReview": 0,
    "newReleases": 1,
    "flips": 1,
    "token": "set"
  },
  "items": [
    {
      "repo": "test/test-repo",
      "name": "test",
      "gitVer": "v2.0.0",
      "gitDate": "2026-09-07",
      "localVer": "1.0.0",
      "flag": "yes",
      "prevFlag": "no",
      "latest": "v2.0.0",
      "publishedUtc": "2026-09-07T12:00:00Z",
      "status": "ok",
      "cmp": "lt",
      "isNew": true,
      "isFlip": true,
      "versionJump": false,
      "dateSuspicious": false,
      "review": false,
      "reviewReasons": [],
      "error": ""
    }
  ]
}

```

## Verdict
PASS
