# T22-v19 Test Report: md 临时文件写入失败（Step 5 md.tmp）

## 构造方法
通过 ACL deny 拒绝当前用户对 .output 目录的 CreateFiles 权限。
step1+step2+step3+step5-full 在同一 pwsh 进程中运行，确保锁 PID 一致。
ACL deny 在 step3 完成后、step5-full 执行前应用，测试后还原。

## 验证项

| 检查项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| 主 md unchanged | yes | yes | PASS |
| tmp 不残留 | yes | yes | PASS |
| lock released | yes | yes | PASS |
| RUN_STATUS\|failed\| | present | present | PASS |
| COMMIT_OK\| | absent | absent | PASS |
| RUN_STATUS\|success\| | absent | absent | PASS |

## 最终判定
**PASS**

## stdout.txt 内容
```
BACKUP_OK|20260908-140602629
FETCH_COMPLETE|apiOk=1 apiErr=0 total=1
SUMMARY|total=1 apiOK=1 apiErr=0 synced=0 yes=1 uninstalled=0 pendingReview=1 newReleases=1 flips=1 token=set
{
  "stats": {
    "total": 1,
    "apiOk": 1,
    "apiErr": 0,
    "synced": 0,
    "yes": 1,
    "uninstalled": 0,
    "pendingReview": 1,
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
    }
  ]
}
RUNTIME_ERROR|主 md 临时文件写入/读取失败：Access to the path 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v19-final\T22\.output\GitHub更新监测列表.md.tmp' is denied.
RUN_STATUS|failed|主 md 未提交。

```
