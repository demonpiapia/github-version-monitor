# T37-v19 Test Report: 正常提交 -> RUN_STATUS|success|

## Fixture
2 个真实仓库：microsoft/vscode, torvalds/linux

## 执行方式
run-full-pipeline.ps1 单次执行（dot-source 模式，stdout 透传正常，依据 lib/stdout-verification.txt）

## 验证项

| 检查项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| BACKUP_OK\| | present | present | PASS |
| FETCH_COMPLETE\| | present | present | PASS |
| SUMMARY\| | present | present | PASS |
| REVIEW_WRITE_OK\| | 条件性（本轮无 review 候选） | present | PASS |
| COMMIT_OK\| | present | present | PASS |
| RUN_STATUS\|success\| | present | present | PASS |
| RUN_STATUS\|failed\| | absent | absent | PASS |
| lock released | yes | yes | PASS |
| md updated | yes | yes | PASS |
| result.json valid | yes | yes | PASS |

## 硬门槛检查
COMMIT_OK + RUN_STATUS|failed| -> PASS

## 最终判定
**PASS**

## stdout.txt 内容
```
BACKUP_OK|20260908-141448119
FETCH_COMPLETE|apiOk=1 apiErr=1 total=2
SUMMARY|total=2 apiOK=1 apiErr=1 synced=0 yes=1 uninstalled=0 pendingReview=2 newReleases=1 flips=1 token=set
{
  "stats": {
    "total": 2,
    "apiOk": 1,
    "apiErr": 1,
    "synced": 0,
    "yes": 1,
    "uninstalled": 0,
    "pendingReview": 2,
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
      "versionJump": true,
      "dateSuspicious": false,
      "review": true,
      "reviewReasons": [
        "version_jump"
      ],
      "error": ""
    },
    {
      "repo": "torvalds/linux",
      "name": "linux",
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
REVIEW_WRITE_OK|������ɣ�2 �stats/items ���ֲ��䡣
COMMIT_OK|��ԭ���滻�� md�������� 2��yes/no У��ͨ����repo ����һ�£���
RUN_STATUS|success|fetch + ��Ҫ review + commit + lock release ��ɡ�

```
