# GitHub 项目更新监测列表

> 数据来源：GitHub 官方 API（api.github.com）`releases/latest` 接口直连（异常项三通道复核：latest + releases 列表 + HTML 页），非搜索快照、非 Python 脚本
> 最近核对时间：2026-09-10 08:04（北京时间，本轮 6 项：latest API 成功 4 / 失败 2 / 待核 4；失败项保留上轮状态；数据来源 GitHub REST API 直连，无 HTML 回退）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---------|------------|------------------|---------|-------------|
| 1 | [vscode-normal](https://github.com/microsoft/vscode/releases) | 1.137.0 | 2026-09-09 | 0.0.1 | yes |
| 2 | [vscode-synced](https://github.com/facebook/react/releases) | v19.3.0 | 2026-09-01 | v19.3.0 | no |
| 3 | [vscode-uninstalled](https://github.com/nodejs/node/releases) | v26.8.2 | 2026-09-10 | 未安装 | no |
| 4 | [vscode-unsupported](https://github.com/python/cpython/releases) |  |  | 版本不可比较 | no |
| 5 | [nonexistent-404](https://github.com/workbuddy-v111-nonexistent-org-7f3a9c2e/nonexistent-repo-404/releases) |  |  | 1.0.0 | no |
| 6 | [vscode-versionjump](https://github.com/microsoft/TypeScript/releases) | v7.0.2 | 2026-08-21 | 0.0.1 | yes |

## 结论

（结论段：N 监测 / M 需更新(yes) / K 未安装 / E 项本轮 API 失败保留上轮状态，全部取 stats 实测值）

## 更新摘要

（更新摘要段：本轮新发布 isNew 项 + no→yes 翻转 isFlip 项，含 UTC 发布时间与北京时间；API 失败项如实列出）

## 备注

（备注段：版本格式特殊项 / review=true 待核项 / 三通道复核结论逐项说明）

## 核对方法

- 步骤 2 PowerShell 逐行解析 + 每仓库 1 次 releases/latest 直连查询。
- flag 由 Compare-Ver 程序计算，agent 不手动抄表。

