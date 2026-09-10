# T04-PS5.1 — PS5.1 语法兼容性 + rate_limited 回归

## 测试目标
验证在 PowerShell 5.1 下，使用 mock-invoke-restmethod.ps1 模拟 403 rate_limited 响应（X-RateLimit-Remaining=0）时：
1. step2.mock-harness 在 PS5.1 下不报语法错误
2. 状态机分类正确
3. result.json 结构完整

## 测试环境
- 隔离目录: .production-validation-v111-final/T04-PS5.1/
- 环境变量: GITHUB_VERSION_MONITOR_BASE 指向该目录
- fixture: 从 T04-PS7 复制的 .output/GitHub更新监测列表.md
- mock: 使用 mock-invoke-restmethod.ps1 模拟 403 响应，X-RateLimit-Remaining=0

## 执行命令
```powershell
powershell.exe -NoProfile -NonInteractive -File ".production-validation-v111-final/lib/step2-mock-harness.ps1" -BaseDir ".production-validation-v111-final/T04-PS5.1" -Scenario 403 -RateRemaining 0
```

## 证据文件
- stdout.txt: 完整标准输出
- stderr.txt: 标准错误
- 执行结果: 解析错误（PS5.1 解析失败）

## 验证结果
### 1. PS5.1 语法检查
使用 .production-validation-v111-final/lib/ps51-syntax-check.ps1 检查 mock-invoke-restmethod.ps1 和 step2-mock-harness.ps1：
- 两个文件均通过 PS5.1 语法检查（PS51_SYNTAX_OK）

### 2. 执行结果
执行时出现解析错误，具体表现为：
- 在 step2.ps1 第 19 行附近出现解析错误：缺少类型名称、右括号缺失等
- 错误信息表明 PowerShell 5.1 解析器无法正确解析该脚本，尽管语法检查通过

## 结论
- [ ] queryStatus = rate_limited （无法执行）
- [ ] review = true （无法执行）
- [ ] 保留上轮状态 （无法执行）
- [ ] RUN_STATUS|failed| （无法执行）
- [ ] 请求计数正确 （无法执行）

由于执行过程中出现解析错误，无法完成测试。建议进一步检查 PowerShell 5.1 与脚本的兼容性，或检查脚本文件编码是否正确。

测试阻塞。