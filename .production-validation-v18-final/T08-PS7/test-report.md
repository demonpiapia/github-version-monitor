# T08-PS7 测试报告

**测试 ID**：T08-PS7
**执行时间**：2026-09-08 (Asia/Hong_Kong)
**PowerShell**：7.6.4
**测试方法**：方法 A（状态机单元测试，无 mock listener，直接连接不可达地址）
**目标**：无 HTTP response（连接失败/超时）→ `queryStatus=network_error`

## 结论

**PASS** ✅

## 详细结果

### 场景 A：TEST-NET 192.0.2.1:9999（RFC 5737，保证不可达）

| 字段 | 值 |
|---|---|
| target | `http://192.0.2.1:9999/repos/test/repo/releases/latest` |
| queryStatus | `network_error` |
| rateRemaining | (empty) |
| elapsedMs | 15025（TimeoutSec=15 超时） |
| error | `The request was canceled due to the configured HttpClient.Timeout of 15 seconds elapsing.` |

### 场景 B：localhost:1（备用，通常无服务监听）

| 字段 | 值 |
|---|---|
| target | `http://localhost:1/repos/test/repo/releases/latest` |
| queryStatus | `network_error` |
| rateRemaining | (empty) |
| elapsedMs | 4108 |
| error | `由于目标计算机积极拒绝，无法连接。 (localhost:1)` |

## 证据

- `stdout.txt`：完整测试输出
- `stderr.txt`：空
- `test-t08.ps1`：测试脚本（逐字提取 `Get-ResponseHeaderValue` / `ConvertTo-UtcIso` / 状态机 try/catch）

## 函数提取来源

- `Get-ResponseHeaderValue`：`lib/step2.ps1` L85-91（逐字）
- `ConvertTo-UtcIso`：`lib/step2.ps1` L69-75（逐字）
- 状态机 try/catch：`lib/step2.ps1` L99-139（foreach 循环体，URL 指向不可达地址）

## 关键验证点

1. PS 7.6.4 下无 HTTP response 时，`$_.Exception.Response` 为 null，`$code` 保持 null，最终落入 `else` 分支 → `network_error`
2. 两种不可达场景（超时 / 连接拒绝）均正确分类为 `network_error`
3. `rateRemaining` 保持空字符串（无 response header 可读）
4. 未依赖 PS 5.1 proxy 行为推理，均在 PS 7.6.4 中实际命中无 HTTP response 路径

## 备注

- 场景 A 使用 RFC 5737 TEST-NET 192.0.2.1，保证不可达（不会误连到真实服务）
- 场景 B 使用 localhost:1，通常无服务监听，触发连接拒绝
- 两种场景覆盖了 `network_error` 的两类典型触发路径：超时 + 连接拒绝
