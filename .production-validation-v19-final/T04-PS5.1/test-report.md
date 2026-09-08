# T04-PS5.1 Test Report

## Description
403 + X-RateLimit-Remaining=0 → rate_limited (PS5.1 compatibility)

## Scenario
- MOCK_SCENARIO=rate_limited_403
- PowerShell: 5.1.22621.963 (C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe)
- Mock: lib/mock-invoke-restmethod-ps51.ps1 (Add-Type + WebHeaderCollection)

## Expected
- queryStatus: rate_limited
- result.json valid: yes
- FETCH_COMPLETE|: present

## Actual Results
- queryStatus: rate_limited
- cmp: (empty)
- review: True
- reviewReasons: api_failure
- gitVer: v1.0.0
- gitDate: 2026-01-01
- flag: no
- prevFlag: no
- latest: (empty)
- publishedUtc: (empty)
- versionJump: False
- dateSuspicious: False
- isFlip: False
- isNew: False
- error: Mock rate_limited_403
- apiOk/apiErr: 0/1
- result.json valid: yes
- FETCH_COMPLETE|: present

## Get-ResponseHeaderValue Compatibility
- mock 使用 `System.Net.WebHeaderCollection`（PS5.1 原生 HTTP header 容器）
- step2.ps1 L86 分支 `if ($Headers -is [System.Net.WebHeaderCollection])` 命中
- `$Headers.Get('X-RateLimit-Remaining')` 返回 '0'
- 状态机正确分类为 rate_limited（区别于 forbidden_403 的 remaining=50）
- **兼容性验证：PASS**

## PS5.1 语法处理
- mock-invoke-restmethod-ps51.ps1 使用 `Add-Type -TypeDefinition` 定义 MockHttpException（替代 PS7 `class` 语法）
- step2.ps1 通过 step2-mock-harness-ps51.ps1 转换为 UTF-8 BOM 后 dot-source 执行
- 未触发 ParseException，无需展开紧凑代码

## Verdict
PASS
