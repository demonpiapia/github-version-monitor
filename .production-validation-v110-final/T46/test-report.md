# T46 Test Report — .output State Path Regression

> **测试目标**: 验证 SKILL-v1.10 使用 .output/GitHub更新监测列表.md 作为唯一生产状态文件位置
> **构造方法**: T46 测试目录 + fixture + Step 1 + Step 2（不执行 Step 5）
> **执行方式**: pwsh -File step1.ps1 + pwsh -File step2.ps1（两步独立执行）
> **执行时间**: 2026-09-09 08:01:28
> **执行耗时**: 0.0 秒
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 GITHUB_VERSION_MONITOR_BASE 隔离到 T46/ 子目录
2. 生成 fixture（create-fixture.ps1 -Scenario normal）：1 个真实仓库
3. 采集 before 状态
4. 执行 Step 1（状态检查 + 锁 + 备份）
5. 执行 Step 2（解析 + 查询 + 状态机 + 统计）
6. 采集 after 状态
7. 验证 .output/ 是唯一生产状态文件位置

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| .output/GitHub更新监测列表.md 存在 | True | **PASS** |
| 根目录不存在 GitHub更新监测列表.md | True | **PASS** |
| 读取 .output/ 写回 .output/ | 由 T43 完整管线证据覆盖 | **N/A（T43 覆盖）** |
| backup 基于 .output 状态文件 | 由 T43 完整管线证据覆盖 | **N/A（T43 覆盖）** |

## 关键 stdout 行

### Step 1
~~~
BACKUP_OK|20260909-080141532

~~~

### Step 2
~~~
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
      "name": "VS Code",
      "gitVer": "1.136.2",
      "gitDate": "2026-09-09",
      "localVer": "0.0.1",
      "flag": "yes",
      "prevFlag": "no",
      "latest": "1.136.2",
      "publishedUtc": "2026-09-08T17:54:34Z",
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

~~~

## 目录清单

参见 directory-listing.txt。

## 根目录 MD 检查

参见 oot-md-check.txt。

## 判定

**PASS**

T46 路径契约验证通过：.output/GitHub更新监测列表.md 是唯一生产状态文件位置，T46 测试目录根不存在同名文件。