# T26 — Strict Flag Regression Test Report

## 测试目标
验证 flag 计算严格性：
- yes = cmp=lt 且已安装
- no = cmp=eq 或未安装
- review=true 的项不自动 flag=yes

## 测试环境
- 隔离目录: .production-validation-v111-final/T26/
- 环境变量: GITHUB_VERSION_MONITOR_BASE 指向该目录
- fixture: 使用 create-fixture.ps1 生成 t43 场景（6 项：normal/synced/uninstalled/unsupported/404/versionJump）
- 执行: 完整管线（run-full-pipeline.ps1）相当于步骤 1-5

## 执行命令
```powershell
pwsh -NoProfile -NonInteractive -Command "
  & '.production-validation-v111-final/lib/step1.ps1'
  & '.production-validation-v111-final/lib/step2.ps1'
  & '.production-validation-v111-final/lib/step3.ps1'
  & '.production-validation-v111-final/lib/step4.ps1'
  & '.production-validation-v111-final/lib/step5-full.ps1'
" > stdout.txt 2> stderr.txt
```

## 证据文件
- stdout.txt: 完整标准输出
- stderr.txt: 标准错误
- result-after.json: 管线执行后的 result.json
- md-before.md: 执行前的 fixture（未修改）
- md-after.md: 执行后的监测列表（应与 before 完全相同，因为只读取 localVer 并计算 flag，不修辑 fixture）

## 验证结果

### 逐项检查 flag 计算

| 项目 | localVer | latest | cmp | 已安装? | 期望 flag | 实际 flag | 审查 |
|------|----------|--------|-----|---------|-----------|-----------|------|
| vscode-normal | 0.0.1 | 1.137.0 | lt | 是 | yes | yes | ✓ |
| vscode-synced | v19.3.0 | v19.3.0 | eq | 是 | no | no | ✓ |
| vscode-uninstalled | 未安装 | v26.8.2 | (empty) | 否 | no | no | ✓ |
| vscode-unsupported | 版本不可比较 | (empty) | (empty) | 否（非未安装） | 保持 prevFlag (no) | no | ✓ |
| nonexistent-404 | 1.0.0 | (empty) | (empty) | 是 | 保持 prevFlag (no) | no | ✓ |
| vscode-versionjump | 0.0.1 | v7.0.2 | lt | 是 | yes | yes | ✓ |

### review=true 项不自动 flag=yes
- vscode-uninstalled: review=true (version_jump), flag=no ✓
- vscode-unsupported: review=true (not_found), flag=no ✓
- nonexistent-404: review=true (not_found), flag=no ✓
- vscode-versionjump: review=true (version_jump), flag=yes（但这是由于 cmp=lt 且已安装导致的，不是 review 强制）✓

### 其他说明
- 未安装项（vscode-uninstalled）强制 flag=no，与 cmp 无关 ✓
- 已安装且 cmp=eq 强制 flag=no ✓
- 已安装且 cmp=lt 强制 flag=yes ✓
- 其他情况（incomparable、not_found 等）保留上轮 flag，不自动设为 yes ✓

## 结论
所有验证项均通过：
- [x] yes = cmp=lt 且已安装
- [x] no = cmp=eq 或未安装
- [x] review=true 的项不自动 flag=yes
- [x] 未安装项强制 flag=no
- [x] 已安装且 cmp=eq 强制 flag=no
- [x] 已安装且 cmp=lt 强制 flag=yes
- [x] 其他情况保留上轮 flag

测试通过。