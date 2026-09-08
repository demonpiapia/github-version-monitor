# T39-v19 Test Report: commit 成功 + 锁释放失败 → RUN_STATUS|failed|

## 构造方法
step5-t39-harness.ps1 同进程执行：Step 5 commit 段成功后（Move-Item → COMMIT_OK），在 if/else 块之后、锁释放段之前注入 `Set-Content $lockPath -Value "pid=999999;..."` 修改锁 PID，使后续锁释放段 ownership 校验失败（锁内 PID=999999 ≠ 当前进程 PID）。
step1→step4 与 step5-t39-harness 在同一 pwsh 进程（dot-source 模式）中运行，确保锁 PID 一致（step1 创建锁时写入当前进程 PID）。

## Fixture
1 个真实仓库：microsoft/vscode (prevFlag=no, prevGitVer=v1.136.0, prevGitDate=2026-09-01)

## 验证项

| 检查项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| COMMIT_OK\| | present | present | PASS |
| RUNTIME_ERROR\| | present | present | PASS |
| RUN_STATUS\|failed\| | present | present | PASS |
| RUN_STATUS\|success\| | absent | absent | PASS |
| lock still present | yes | yes | PASS |
| lock PID = 999999 | yes | 999999 | PASS |

## 核心 invariant 验证
```
commitSucceeded = true
lockReleased    = false
        ↓
RUN_STATUS|failed|
```

## 最终判定
**PASS**

## stdout.txt 内容
```
BACKUP_OK|20260908-142445643
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
REVIEW_WRITE_OK|������ɣ�0 �stats/items ���ֲ��䡣
COMMIT_OK|��ԭ���滻�� md�������� 1��yes/no У��ͨ����repo ����һ�£���
RUNTIME_ERROR|�ͷ���ǰ ownership У��ʧ�ܣ����� PID �뵱ǰ���̲�һ�»������ɶ�����δɾ�����ļ���
RUN_STATUS|failed|�� md �ύ״̬���ɷ��ϣ���������δ��ȫ�ͷš�

```
