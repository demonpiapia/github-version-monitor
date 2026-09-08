# T46-v19 Test Report: .output 状态路径回归

## 验证项

| 检查项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| .output/GitHub更新监测列表.md 存在 | yes | yes | PASS |
| 根目录不存在 GitHub更新监测列表.md | yes | yes | PASS |
| backup 基于 .output 状态文件 | yes | yes | PASS |

## 最终判定
**PASS**

## stdout.txt
```
BACKUP_OK|20260908-150244029
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
      "repo": "microsoft/vscode",
      "name": "vscode",
      "gitVer": "1.136.1",
      "gitDate": "2026-09-03",
      "localVer": "1.0.0",
      "flag": "yes",
      "prevFlag": "no",
      "latest": "1.136.1",
      "publishedUtc": "2026-09-03T15:25:32Z",
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

## stderr.txt
```
```

## directory-listing.txt
```

Name                  PSIsContainer
----                  -------------
.monitor                       True
.output                        True
after                          True
before                         True
directory-listing.txt         False
md-after.md                   False
md-before.md                  False
run-t46.ps1                   False
stderr.txt                    False
stdout.txt                    False


```

## root-md-check.txt
```
root md exists: False (expected: False)

```
