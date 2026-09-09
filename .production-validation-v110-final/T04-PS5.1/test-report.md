# T04-PS5.1 Test Report — rate_limited Regression (PS5.1)

## 测试目标
验证 SKILL-v1.10 在 PowerShell 5.1 环境下，`403 + X-RateLimit-Remaining=0` 状态机判定为 `rate_limited`。

## 测试环境
- PowerShell 版本: 5.1.22621.963
- 执行命令: `powershell.exe -NoProfile -NonInteractive -File step2-mock-harness.ps1 -Scenario rate_limited_403 -BaseDir <test-dir>`
- 隔离: `GITHUB_VERSION_MONITOR_BASE` 指向 T04-PS5.1/ 目录
- Mock 场景: `rate_limited_403` (HTTP 403 + X-RateLimit-Remaining='0')

## Mock 调用记录
- 场景: rate_limited_403
- HTTP Status: 403
- X-RateLimit-Remaining: '0'
- 请求计数: 1 (仅 latest API)
- Review API 调用: 0
- HTML 回退: 0
- Retry: 0

## 实际输出（stdout.txt 关键行）
```
FETCH_COMPLETE|apiOk=0 apiErr=1 total=1
SUMMARY|total=1 apiOK=0 apiErr=1 synced=0 yes=0 uninstalled=0 pendingReview=1 newReleases=0 flips=0 token=set
items[0].status = "rate_limited"
items[0].error = "HTTP 403"
MOCK_CALL|rate_limited_403|https://api.github.com/repos/microsoft/vscode/releases/latest
```

## 验证项
| 验证项 | 期望 | 实际 | 结果 |
|---|---|---|---|
| items[0].status | rate_limited | rate_limited | PASS |
| latest request count | 1 | 1 | PASS |
| review API count | 0 | 0 | PASS |
| HTML fallback count | 0 | 0 | PASS |
| retry count | 0 | 0 | PASS |
| exit code | 0 | 0 | PASS |

## 判定
**PASS** — PS5.1 环境下 `Get-ResponseHeaderValue` 在 `System.Net.WebHeaderCollection` 上正确返回 `'0'`，SKILL L364 的 `$rl -eq '0'` 比较成立，状态机正确判定为 `rate_limited`。

## 兼容性发现（非测试失败）
1. **PS5.1 ParseFile 编码问题**: `lib/mock-invoke-restmethod.ps1` 原为 UTF-8 无 BOM + LF-only，PS5.1 的 `ParseFile` 默认按 ANSI/Windows-1252 读取，导致中文注释字节被误解析为多字节 ASCII，引发 parser 错误。修复方式：为 mock 库添加 UTF-8 BOM。
2. **PS5.1 Get-Content -Raw 编码问题**: fixture md 原为 UTF-8 无 BOM，PS5.1 的 `Get-Content -Raw` 默认按 ANSI 读取，导致中文标题 `## 监测列表` 被误解析，SKILL L316 的 section 解析失败（`PARSE_ERROR|状态文件 schema 校验失败`）。修复方式：fixture 使用 UTF-8 BOM 写入。
3. **生产文件编码观察**: 生产状态文件 `.output/GitHub更新监测列表.md` 为 UTF-8 无 BOM，PS5.1 默认读取会失败。此为生产兼容性发现（非本轮 T04-PS5.1 测试失败原因）。

## 证据文件
- `stdout.txt` — 完整 stdout
- `stderr.txt` — stderr（空）
- `result-after.json` — 测试后 result.json
- `sha256-before.txt` / `sha256-after.txt` — 指纹快照
- `lock-before.txt` / `lock-after.txt` — 锁状态快照
