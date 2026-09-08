# Schema Test: input='yes'

## Expected
- valid

## Actual
- PARSE_ERROR: False
- FETCH_COMPLETE: True
- md unchanged: True
- lock released: False

## SHA256
- before: 223EB215764C9C718C41216BB11E914CDFA699B3782D291B31CB10C5BD5B98DC

- after: 223EB215764C9C718C41216BB11E914CDFA699B3782D291B31CB10C5BD5B98DC


## Stdout
```
FETCH_COMPLETE|apiOk=1 apiErr=0 total=1
SUMMARY|total=1 apiOK=1 apiErr=0 synced=0 yes=1 uninstalled=0 pendingReview=0 newReleases=1 flips=0 token=set
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
    "flips": 0,
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
      "prevFlag": "yes",
      "latest": "v2.0.0",
      "publishedUtc": "2026-09-07T12:00:00Z",
      "status": "ok",
      "cmp": "lt",
      "isNew": true,
      "isFlip": false,
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
