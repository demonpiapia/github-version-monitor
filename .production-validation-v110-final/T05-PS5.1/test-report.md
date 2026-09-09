# T05-PS5.1 Test Report — forbidden Regression (PS5.1)

## 测试目标
验证 SKILL-v1.10 在 PowerShell 5.1 环境下，`403 + X-RateLimit-Remaining>0` 状态机判定为 `forbidden`。

## 测试环境
- PowerShell 版本: 5.1.22621.963
- 执行命令: `powershell.exe -NoProfile -NonInteractive -File step2-mock-harness.ps1 -Scenario forbidden -BaseDir <test-dir>`
- 隔离: `GITHUB_VERSION_MONITOR_BASE` 指向 T05-PS5.1/ 目录
- Mock 场景: `forbidden` (HTTP 403 + X-RateLimit-Remaining='50')

## Mock 调用记录
- 场景: forbidden
- HTTP Status: 403
- X-RateLimit-Remaining: '50'
- 请求计数: 1 (仅 latest API)

## 实际输出（stdout.txt 关键行）
```
FETCH_COMPLETE|apiOk=0 apiErr=1 total=1
SUMMARY|total=1 apiOK=0 apiErr=1 synced=0 yes=0 uninstalled=0 pendingReview=1 newReleases=0 flips=0 token=set
items[0].status = "forbidden"
items[0].error = "HTTP 403"
MOCK_CALL|forbidden|https://api.github.com/repos/microsoft/vscode/releases/latest
```

## 验证项
| 验证项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| items[0].status | forbidden | forbidden | PASS |
| exit code | 0 | 0 | PASS |

## 判定
**PASS** — PS5.1 环境下 `Get-ResponseHeaderValue` 在 `System.Net.WebHeaderCollection` 上正确返回 `'50'`，SKILL L364 的 `$rl -eq '0'` 比较为 false，状态机正确判定为 `forbidden`。

## 兼容性发现（非测试失败）
同 T04-PS5.1 报告中的兼容性发现（PS5.1 ParseFile 编码问题 + Get-Content -Raw 编码问题）。

## 证据文件
- `stdout.txt` — 完整 stdout
- `stderr.txt` — stderr（空）
- `result-after.json` — 测试后 result.json
- `sha256-before.txt` / `sha256-after.txt` — 指纹快照
- `lock-before.txt` / `lock-after.txt` — 锁状态快照
