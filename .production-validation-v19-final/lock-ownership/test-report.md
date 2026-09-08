# lock-ownership Test Report

## Purpose
验证 SKILL-v1.9 锁机制在特定场景下的行为。

## Stdout
```
FETCH_COMPLETE|apiOk=0 apiErr=1 total=1
SUMMARY|total=1 apiOK=0 apiErr=1 synced=0 yes=0 uninstalled=0 pendingReview=1 newReleases=0 flips=0 token=set
{
  "stats": {
    "total": 1,
    "apiOk": 0,
    "apiErr": 1,
    "synced": 0,
    "yes": 0,
    "uninstalled": 0,
    "pendingReview": 1,
    "newReleases": 0,
    "flips": 0,
    "token": "set"
  },
  "items": [
    {
      "repo": "test/test-repo",
      "name": "test",
      "gitVer": "",
      "gitDate": "",
      "localVer": "1.0.0",
      "flag": "no",
      "prevFlag": "no",
      "latest": "",
      "publishedUtc": "",
      "status": "not_found",
      "cmp": "",
      "isNew": false,
      "isFlip": false,
      "versionJump": false,
      "dateSuspicious": false,
      "review": true,
      "reviewReasons": [
        "not_found"
      ],
      "error": "Response status code does not indicate success: 404 (Not Found)."
    }
  ]
}

--- STEP3 ---

RUNTIME_ERROR|步骤3 heartbeat 失败：运行锁 ownership 不属于当前进程

```

## Lock Before
```
pid=27332;start=2026-09-08T08:22:46.7885667+00:00;step=1;beat=2026-09-08T08:22:46.7885667+00:00


```

## Lock After
```
pid=999999;start=2026-09-08T08:22:48.5180084+00:00;step=1;beat=2026-09-08T08:22:48.5180084+00:00


```
