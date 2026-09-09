# T22 Test Report — md 临时文件写入失败

> **测试目标**: SKILL Step 5 `Set-Content $tmp`（md.tmp 创建/写入）真实失败
> **构造方法**: ACL deny CreateFiles 权限（对 `.output` 目录）
> **执行时间**: 2026-09-09 07:25:01
> **执行环境**: Windows + PowerShell 7.x

## 构造方法详情

1. 通过 `GITHUB_VERSION_MONITOR_BASE` 隔离到 `T22/` 子目录
2. 生成 fixture（`create-fixture.ps1 -Scenario normal`）
3. 同进程内执行 Step 1→4（正常完成，产生 result.json + 更新 md 状态）
4. 前置断言：确认 `GitHub更新监测列表.md.tmp` 不存在（否则 ACL 不阻止覆盖）
5. 记录 `.output` 目录原始 ACL 到 `acl-before.xml`
6. 施加 ACL deny `CreateFiles` 权限（当前用户）
7. 执行 Step 5（`step5-full.ps1`）— `Set-Content $tmp` 应被 ACL 拒绝
8. 测试后还原 ACL 并验证 deny 规则已移除

## 验证项

| 验证项 | 期望 | 结果 |
|---|---|---|
| RUNTIME_ERROR\|主 md 临时文件写入/读取失败 | 存在 | **PASS** |
| RUN_STATUS\|failed\|主 md 未提交 | 存在 | **PASS** |
| COMMIT_OK\| | 不存在 | **PASS** |
| RUN_STATUS\|success\| | 不存在 | **PASS** |
| 主 md unchanged (SHA256 before == after) | 一致 | **PASS** |
| md.tmp 不产生错误残留 | 不存在 | **PASS** |
| lock released (run.lock 不存在) | 已释放 | **PASS** |
| ACL 还原成功 | deny 规则已移除 | **PASS** |

## 关键 stdout 行

```
REVIEW_WRITE_OK|复核完成：0 项；stats/items 保持不变。
RUNTIME_ERROR|主 md 临时文件写入/读取失败：Access to the path 'D:\AI\Workspace\automatic\github-version-monitor\.production-validation-v110-final\T22\.output\GitHub更新监测列表.md.tmp' is denied.
RUN_STATUS|failed|主 md 未提交。
```

## SHA256 对比

### Before
```
main_md: AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81
result.json: FILE_NOT_EXISTS
md.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS
```

### After
```
main_md: AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81
result.json: 9696EC8017A3A3EA41962DD4819C926FB18A30DD2D30161B5378955F5DEC9EC7
md.tmp: FILE_NOT_EXISTS
run.lock: FILE_NOT_EXISTS
```

**main_md SHA256 before == after** ✓（主 md 未被修改）
**md.tmp FILE_NOT_EXISTS** ✓（ACL 阻止了 tmp 创建）
**result.json 由 Step 2 生成**（Step 5 未修改，符合预期）
**run.lock 已释放** ✓（Step 5 catch 块执行了锁释放）

## Lock 状态

### Before
```
LOCK_FILE_NOT_EXISTS
```

### After
```
LOCK_FILE_NOT_EXISTS
```

## 判定

**PASS**

Step 5 md tmp 写入失败路径行为符合 SKILL-v1.10 contract：
- 异常被 catch 捕获并输出 `RUNTIME_ERROR|主 md 临时文件写入/读取失败：...`
- tmp 未产生残留（ACL 阻止创建）
- 锁被正确释放（run.lock 已删除）
- 输出 `RUN_STATUS|failed|主 md 未提交。` 作为终态
- 不输出 `COMMIT_OK|` 或 `RUN_STATUS|success|`

## 附加证据

- `tmp-existence.txt`: `md.tmp_exists: False` + `acl_restore_ok: True`
- `acl-before.xml`: ACL 变更前快照（用于还原验证）
