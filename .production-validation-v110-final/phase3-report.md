# Phase 3 Report: T22/T23 — md tmp 写入/原子替换失败回归

> **执行时间**: 2026-09-09 07:25:00 — 07:25:08
> **执行环境**: Windows + PowerShell 7.x
> **被测对象**: SKILL-v1.10.md (SHA256: 4F7E1170B655F73C847B445570CB68DFDAEB5B4F2C6961AF19A946490123DA42)
> **执行计划**: .exec-plan/exec-plan-v1.10-d.md §2 Phase 3

---

## 1. 测试概览

| 子测试 | 目标 | 构造方法 | 判定 |
|---|---|---|---|
| T22 | md tmp 写入失败 (Set-Content $tmp) | ACL deny CreateFiles on .output | **PASS** |
| T23 | md 原子替换失败 (Move-Item $tmp → $md) | 文件锁 (FileShare::Read on main md) | **PASS** |

**总计**: 2 个测试，2 PASS，0 FAIL，0 BLOCKED

---

## 2. T22: md 临时文件写入失败

**目标**: SKILL Step 5 `Set-Content $tmp`（md.tmp 创建/写入）真实失败。

**构造方法**: ACL deny 方案 — 对 `.output` 目录施加 ACL deny `CreateFiles` 权限。
- ACL 在 Step 4 完成后、Step 5 执行前施加
- 前置断言：确认 `GitHub更新监测列表.md.tmp` 不存在（否则 ACL 不阻止覆盖）
- 测试后还原 ACL 并验证 deny 规则已移除

**关键 stdout**:
```
REVIEW_WRITE_OK|复核完成：0 项；stats/items 保持不变。
RUNTIME_ERROR|主 md 临时文件写入/读取失败：Access to the path '...\T22\.output\GitHub更新监测列表.md.tmp' is denied.
RUN_STATUS|failed|主 md 未提交。
```

**验证结果**:
- RUNTIME_ERROR|主 md 临时文件写入/读取失败: **存在** ✓
- RUN_STATUS|failed|主 md 未提交: **存在** ✓
- COMMIT_OK|: **不存在** ✓
- RUN_STATUS|success|: **不存在** ✓
- 主 md unchanged (SHA256 before == after): **是** ✓ (AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81)
- md.tmp 不产生错误残留: **是** (md.tmp = FILE_NOT_EXISTS) ✓
- lock released: **是** (LOCK_FILE_NOT_EXISTS) ✓
- ACL 还原: **是** (acl_restore_ok: True) ✓

**判定: PASS**

---

## 3. T23: md 原子替换失败

**目标**: SKILL Step 5 `Move-Item $tmp -> $md` 真实失败。

**构造方法**: 文件锁方案 — 后台进程以 `FileShare::Read` 打开主 md 文件（允许读，阻止写/替换），使 Move-Item 无法替换。
- lock holder 通过 `Start-Process -WindowStyle Hidden -PassThru` 启动
- 等待 3 秒确保锁已建立（lock holder 输出 `LOCK_HELD|...|share=Read`）
- 测试后 `Stop-Process` 终止 lock holder

**关键 stdout**:
```
REVIEW_WRITE_OK|复核完成：0 项；stats/items 保持不变。
T23_LOCKHOLDER_STARTED|pid=54108
RUNTIME_ERROR|主 md 原子替换失败：当文件已存在时，无法创建该文件。
RUN_STATUS|failed|主 md 未提交。
T23_LOCKHOLDER_STOPPED
```

**验证结果**:
- RUNTIME_ERROR|主 md 原子替换失败: **存在** ✓
- RUN_STATUS|failed|主 md 未提交: **存在** ✓
- COMMIT_OK|: **不存在** ✓
- RUN_STATUS|success|: **不存在** ✓
- 主 md unchanged (SHA256 before == after): **是** ✓ (AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81)
- md.tmp cleaned: **是** (md.tmp = FILE_NOT_EXISTS，Step 5 catch 块执行了 Remove-Item) ✓
- lock released: **是** (LOCK_FILE_NOT_EXISTS) ✓

**判定: PASS**

---

## 4. 主 agent 审查点自检

| 审查点 | 结果 |
|---|---|
| T22/T23 stdout.txt 中是否出现预期的 RUN_STATUS\|failed\| | ✓ 全部出现 |
| T22/T23 stdout.txt 中是否不出现 RUN_STATUS\|success\| | ✓ 全部不出现 |
| T22/T23 stdout.txt 中是否不出现 COMMIT_OK\| | ✓ 全部不出现 |
| SHA256 before/after 一致（主 md unchanged） | ✓ 全部一致 |
| lock-after 确认锁已释放 | ✓ 全部释放 |
| sha256 文件覆盖 main md + result.json + tmp 三者 | ✓ 全部覆盖（含 run.lock 额外项） |

---

## 5. 总体判定

| 子测试 | 判定 |
|---|---|
| T22 | PASS |
| T23 | PASS |

**Phase 3 总体判定: PASS**

**关键发现**: Step 5 的异常处理在 v1.10 基础上保持不变，符合 SKILL-v1.10 contract：
- T22: md tmp 写入失败 → RUNTIME_ERROR + RUN_STATUS|failed| + lock released + tmp 不残留
- T23: md 原子替换失败 → RUNTIME_ERROR + RUN_STATUS|failed| + lock released + tmp cleaned

---

## 6. 产出文件清单

### 测试目录
- `.production-validation-v110-final/T22/`
- `.production-validation-v110-final/T23/`

### 每个测试目录包含
- `stdout.txt` — 完整 stdout
- `stderr.txt` — stderr（空）
- `test-report.md` — 测试报告
- `md-before.md` / `md-after.md` — 主 md before/after
- `result-before.json` / `result-after.json` — result.json before/after
- `sha256-before.txt` / `sha256-after.txt` — SHA256 指纹（含 main md + result.json + md.tmp + run.lock）
- `lock-before.txt` / `lock-after.txt` — 锁状态 before/after
- `before/` / `after/` — 目录列表快照
- `step5-wrapper.ps1` — 测试 wrapper 脚本
- `fixture-stdout.txt` — fixture 生成输出
- `tmp-existence.txt` — tmp 文件状态检查

### T22 额外
- `acl-before.xml` — ACL 变更前快照

### T23 额外
- `lock-holder-stdout.txt` — lock holder 进程 stdout（确认锁已建立）
- `lock-holder-stderr.txt` — lock holder 进程 stderr（空）

### Phase 级
- `.production-validation-v110-final/phase3-stdout.txt` — Phase 3 执行日志
- `.production-validation-v110-final/phase3-stderr.txt` — Phase 3 stderr（空）
- `.production-validation-v110-final/phase3-report.md` — Phase 3 报告（本文件）
- `.production-validation-v110-final/phase3-orchestrator.ps1` — 执行脚本
