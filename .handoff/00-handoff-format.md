# Handoff 通用格式规范

> **用途**: 所有 handoff 文件统一采用此格式，确保新 agent 能第一时间理解上下文并接续任务。  
> **文件名约定**: `handoff-<版本>-<ISO8601时间戳>.md`（如 `handoff-v18-20260908-050037.md`）  
> **本文件**: `00-handoff-format.md`（排序首位，agent 优先读取）

---

## 格式结构

```markdown
# Handoff — <任务简述>

> **交接时间**: <ISO8601 时间戳> (<时区>)  
> **交接来源**: <上一轮 agent 标识>  
> **交接目标**: <新 agent 标识>  
> **任务性质**: <全新独立 / 接续 / 修复>

---

## TASK

<本轮任务的一句话目标>

## INPUTS

<本轮所需的全部输入文件、路径、配置>

- `<文件路径>` — <用途说明>
- `<文件路径>` — <用途说明>

## CURRENT_STATE

<当前仓库/项目/系统的状态快照>

- Git branch: `<branch>`
- HEAD commit: `<hash>` (<message>)
- 工作树: <clean / dirty>
- <其他关键状态>

## COMPLETED

<已完成的工作项，每项附证据路径>

- [x] <工作项> — <证据路径>
- [x] <工作项> — <证据路径>

## FAILED

<失败的工作项，每项附失败原因>

- [ ] <工作项> — <失败原因>
- [ ] <工作项> — <失败原因>

## BLOCKED

<被阻塞的工作项，每项附阻塞原因和解除条件>

- [ ] <工作项> — 阻塞原因: <原因>；解除条件: <条件>

## NEXT_ACTION

<新 agent 应立即执行的第一步>

1. <具体操作>
2. <具体操作>

## IMPORTANT_FACTS

<新 agent 必须知道的关键事实，避免重复踩坑>

- <事实 1>
- <事实 2>
- <事实 3>
```

---

## 字段说明

| 字段 | 必填 | 说明 |
|---|---|---|
| TASK | 是 | 一句话目标，新 agent 的核心任务 |
| INPUTS | 是 | 所有输入文件路径，新 agent 无需猜测 |
| CURRENT_STATE | 是 | 仓库/系统快照，新 agent 无需重新探测 |
| COMPLETED | 是 | 已完成项 + 证据路径，新 agent 无需重复执行 |
| FAILED | 否 | 失败项 + 原因，新 agent 避免重复失败 |
| BLOCKED | 否 | 阻塞项 + 解除条件，新 agent 知道何时可继续 |
| NEXT_ACTION | 是 | 第一步操作，新 agent 无需规划即可开始 |
| IMPORTANT_FACTS | 是 | 关键事实/踩坑记录，新 agent 避免重复踩坑 |

---

## 使用规则

1. **文件名**: `handoff-<版本>-<ISO8601>.md`，放在 `.handoff/` 目录
2. **排序**: 本文件 `00-handoff-format.md` 始终排序首位
3. **推送**: `.handoff/` 目录纳入版本控制，推送时 commit message 说明内容
4. **新 agent 读取顺序**: 先读本格式文件，再读最新的 handoff 文件
5. **不替代 prompt**: handoff 仅提供上下文，不替代任务规范（prompt）

---

## 示例

```markdown
# Handoff — SKILL-v1.9 定向回归验证

> **交接时间**: 2026-09-08 08:00:00 (Asia/Hong_Kong)  
> **交接来源**: v1.8 验证 agent  
> **交接目标**: 新开对话的本地 agent  
> **任务性质**: 全新独立验证轮次（Clean-Room）

---

## TASK

验证 SKILL-v1.9.md 是否修复了 v1.8 已确认的 3 个 P2 缺陷（Set-Content/Move-Item 无 try/catch），且 v1.8 已验证能力不回归。

## INPUTS

- `.GPT/v1.9-targeted-validation-prompt.md` — 本轮任务规范（唯一事实源）
- `SKILL-v1.9.md` — 被测代码
- `SKILL-v1.8.md` — 基线对比
- `.output/GitHub更新监测列表.md` — 生产状态文件（只读）

## CURRENT_STATE

- Git branch: main
- HEAD commit: 7c2a6be (docs: add v1.8 self-review report)
- 工作树: clean
- PowerShell 7: 7.6.4
- PowerShell 5.1: 5.1.22621.963
- GITHUB_TOKEN: 已设置

## COMPLETED

- [x] SKILL-v1.8 生产验证（23 项，21 PASS / 2 FAIL，PRODUCTION_NOT_READY）— `production-validation-report-v18-final.md`
- [x] 发现 3 个 P2 缺陷（Set-Content/Move-Item 无 try/catch）— `.production-validation-v18-final/`
- [x] v1.8 报告 + 305 个证据文件已推送（commit 85b6194）
- [x] v1.8 静态复核（P2 计数不一致发现）— `.selfreview/selfreview-v18-20260908-073000.md`

## FAILED

- [ ] T38-v18 — Step 4 Set-Content 无 try/catch，异常冒泡后锁残留（主 md 安全）
- [ ] T23-v18 — Step 5 Move-Item 无 try/catch，异常冒泡后 tmp+锁残留（主 md 安全）

## BLOCKED

（无）

## NEXT_ACTION

1. 读取 `.GPT/v1.9-targeted-validation-prompt.md`（本轮唯一任务规范）
2. 重算 SKILL-v1.9.md SHA256 并与基线比对
3. 生成 v18-v19.diff，检查 3 个 P2 缺陷是否修复
4. 优先跑 T38-v19（核心 gate：review 写回失败 → 锁必须释放）

## IMPORTANT_FACTS

- SKILL-v1.8.md SHA256: `8C6B1CC31B61839853DEA0ABCEB903BD763ACE03A677130D08C3D56D8728CA68`
- 生产状态文件路径: `.output/GitHub更新监测列表.md`（不在仓库根目录）
- 3 个 P2 缺陷位置: Step 4 Set-Content / Step 5 Move-Item / Step 5 Set-Content
- 不得修改被测代码（SKILL-v1.9.md），发现问题只记录不修复
- 不得修改生产 `.output/GitHub更新监测列表.md`，用 fixture 副本测试
- 不得复用 v1.8 历史测试证据作为本轮 PASS 证据
- T22 测试标准需对齐 T38（增加锁释放验证）
- PowerShell 7 单行紧凑函数定义在 PS5.1 下无法解析，测试脚本需展开为多行
```
