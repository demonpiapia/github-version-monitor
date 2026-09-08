# T23-v19 Test Report: md 原子替换失败（Step 5 Move-Item）

## 构造方法
对目标 md 设置外部文件锁（FileAccess::Read, FileShare::None），使 Move-Item 无法替换。
step1+step2+step3+step5-full 在同一 pwsh 进程中运行，确保锁 PID 一致；lock-holder 在 step3 完成后、step5-full 开始前持有 md 文件锁。
combined 脚本在 step5-full 完成后写 done.flag，lock-holder 收到信号后释放文件锁。

## 验证项

| 检查项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| 主 md unchanged | yes | yes | PASS |
| tmp cleaned | yes | yes | PASS |
| lock released | yes | yes | PASS |
| RUN_STATUS\|failed\| | present | present | PASS |
| COMMIT_OK\| | absent | absent | PASS |
| RUN_STATUS\|success\| | absent | absent | PASS |

## 最终判定
**PASS**

## stdout.txt 内容
```
BACKUP_OK|20260908-140720582
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
RUNTIME_ERROR|�� md ԭ���滻ʧ�ܣ����ļ��Ѵ���ʱ���޷��������ļ���
RUN_STATUS|failed|�� md δ�ύ��

```
