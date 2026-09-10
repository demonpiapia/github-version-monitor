# GitHub 项目更新监测列表

> 数据来源：GitHub 官方 API（api.github.com）`releases/latest` 接口直连（异常项三通道复核：latest + releases 列表 + HTML 页），非搜索快照、非 Python 脚本
> 最近核对时间：2026-09-10 08:05（北京时间，fixture 初始值）

## 监测列表

| # | 项目名称 | GIT最新版本 | GIT更新日期 | 本地版本 | 是否更新 |
|---|---------|------------|------------------|---------|-------------|
| 1 | [vscode-normal](https://github.com/microsoft/vscode/releases) | v0.0.1 | 2026-01-01 | 0.0.1 | yes |
| 2 | [vscode-synced](https://github.com/facebook/react/releases) | v19.3.0 | 2026-09-01 | v19.3.0 | no |
| 3 | [vscode-uninstalled](https://github.com/nodejs/node/releases) | v0.0.1 | 2026-01-01 | 未安装 | no |
| 4 | [vscode-unsupported](https://github.com/python/cpython/releases) | v0.0.1 | 2026-01-01 | 版本不可比较 | no |
| 5 | [nonexistent-404](https://github.com/workbuddy-v111-nonexistent-org-7f3a9c2e/nonexistent-repo-404/releases) |  |  | 1.0.0 | no |
| 6 | [vscode-versionjump](https://github.com/microsoft/TypeScript/releases) | v0.0.1 | 2026-01-01 | 0.0.1 | yes |

## 结论

- 共监测 **6** 个项目，**2** 个需要更新（yes），4 个版本一致或未安装。

## 更新摘要

- （fixture 初始占位，由步骤 5 程序替换）

## 备注

- （fixture 初始占位，由步骤 5 程序替换）

## 核对方法

- 步骤 2 PowerShell 逐行解析 + 每仓库 1 次 releases/latest 直连查询。
- flag 由 Compare-Ver 程序计算，agent 不手动抄表。

