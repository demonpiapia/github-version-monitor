# Final Invariant Verification — I1-I7

> **Phase**: 10.2
> **被测对象**: `SKILL-v1.10.md`
> **SHA256**: `4F7E1170B655F73C847B445570CB68DFDAEB5B4F2C6961AF19A946490123DA42`
> **验证时间**: 2026-09-09 09:18 +08:00
> **依据**: exec-plan-v1.10-d §2 Phase 10.2 + Prompt §20
> **证据来源**: Phase 2-5 实际执行证据（非重新运行）

---

## I1: atomic md replacement success → commitSucceeded=true

### 定义

```
Move-Item $tmp $md -Force 成功
    ↓
$commitSucceeded = $true
    ↓
Write-Output "COMMIT_OK|..."
```

### 证据

| 测试 | 证据文件 | 关键行 |
|---|---|---|
| T37 | `T37/stdout.txt` | L72: `COMMIT_OK\|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。` |
| T43 | `T43/stdout.txt` | L156: `COMMIT_OK\|已原子替换主 md（数据行 6，yes/no 校验通过，repo 集合一致）。` |
| T39 | `T39/stdout.txt` | L72: `COMMIT_OK\|已原子替换主 md（数据行 2，yes/no 校验通过，repo 集合一致）。` |

### 代码路径验证

SKILL L623-L627:
```powershell
if ($rows2.Count -eq $items.Count -and $badFlag.Count -eq 0 -and $repoMatch -and $headerOk -and $anchorsOk) {
    try {
        Move-Item -Path $tmp -Destination $md -Force
        $commitSucceeded=$true
        Write-Output "COMMIT_OK|已原子替换主 md（数据行 $($rows2.Count)，yes/no 校验通过，repo 集合一致）。"
    } catch { ... }
}
```

`Move-Item` 成功后 `$commitSucceeded=$true` 且输出 `COMMIT_OK|`。

### 判定: **PASS**

---

## I2: commitSucceeded=true + lockReleased=true → RUN_STATUS|success|

### 定义

```
$commitSucceeded = $true
+
$lockReleased = $true
    ↓
Write-Output 'RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。'
```

### 证据

| 测试 | 证据文件 | 关键行 |
|---|---|---|
| T37 | `T37/stdout.txt` | L72: `COMMIT_OK\|...` (commitSucceeded=true) + L73: `RUN_STATUS\|success\|...` |
| T43 | `T43/stdout.txt` | L156: `COMMIT_OK\|...` (commitSucceeded=true) + L157: `RUN_STATUS\|success\|...` |

### 代码路径验证

SKILL L649-L651:
```powershell
} elseif ($commitSucceeded) {
    Write-Output 'RUN_STATUS|success|fetch + 必要 review + commit + lock release 完成。'
}
```

此分支仅在 `$lockReleased=$true`（L637-L645 成功）且 `$commitSucceeded=$true` 时执行。

### 判定: **PASS**

---

## I3: commitSucceeded=true + lockReleased=false → RUN_STATUS|failed|

### 定义

```
$commitSucceeded = $true
+
$lockReleased = $false
    ↓
Write-Output 'RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。'
```

### 证据

| 测试 | 证据文件 | 关键行 |
|---|---|---|
| T39 | `T39/stdout.txt` | L72: `COMMIT_OK\|...` (commitSucceeded=true) + L73: `RUNTIME_ERROR\|释放锁前 ownership 校验失败...` + L74: `RUN_STATUS\|failed\|主 md 提交状态不可否认，但运行锁未安全释放。` |

### 代码路径验证

SKILL L646-L648:
```powershell
if (-not $lockReleased) {
    Write-Output 'RUNTIME_ERROR|释放锁前 ownership 校验失败（锁内 PID 与当前进程不一致或锁不可读），未删除锁文件。'
    Write-Output 'RUN_STATUS|failed|主 md 提交状态不可否认，但运行锁未安全释放。'
}
```

T39 harness 在 Move-Item 成功后注入 PID=999999 到锁文件，使 ownership 校验失败 → `$lockReleased=$false`。

### 判定: **PASS**

---

## I4: review write failure → no md commit

### 定义

```
Step 4 输出 REVIEW_WRITE_ERROR| 或 RUNTIME_ERROR|
    ↓
Step 5 不执行（或执行但 md 原子替换失败）
    ↓
无 COMMIT_OK| 输出
```

### 证据

| 测试 | 证据文件 | REVIEW_WRITE_ERROR\| 存在? | COMMIT_OK\| 存在? | 判定 |
|---|---|---|---|---|
| T38-A | `T38-A/stdout.txt` | 是 (L40) | 否 | PASS |
| T38-B | `T38-B/stdout.txt` | 是 (L40) | 否 | PASS |
| T38-C | `T38-C/stdout.txt` | 是 (L40) | 否 | PASS |
| T38-heartbeat | `T38-heartbeat/stdout.txt` | 否 (RUNTIME_ERROR) | 否 | PASS |
| T38-result-read | `T38-result-read/stdout.txt` | 否 (RUNTIME_ERROR) | 否 | PASS |
| T38-stats-items | `T38-stats-items/stdout.txt` | 是 (L40) | 否 | PASS |
| T22 | `T22/stdout.txt` | 否 (REVIEW_WRITE_OK) | 否 | PASS |
| T23 | `T23/stdout.txt` | 否 (REVIEW_WRITE_OK) | 否 | PASS |

> T22/T23 的 review 写入成功（`REVIEW_WRITE_OK|`），但 md 提交失败（tmp 写入失败 / 原子替换失败），因此无 `COMMIT_OK|`。

### 代码路径验证

SKILL L517:
> 前置条件：步骤 4 未输出 `REVIEW_WRITE_ERROR|`。若步骤 4 输出 `REVIEW_WRITE_ERROR|`，本步骤不执行。

Step 4 的 6 条错误路径均在 `RUN_STATUS|failed|` 后 `return`（L480 除外），终止整轮，Step 5 不执行。

### 判定: **PASS**

---

## I5: review write failure → RUN_STATUS|failed|

### 定义

```
Step 4 输出 REVIEW_WRITE_ERROR| 或 RUNTIME_ERROR|
    ↓
输出 RUN_STATUS|failed|
```

### 证据

| 测试 | 证据文件 | RUN_STATUS\|failed\| 存在? | 出现次数 | 判定 |
|---|---|---|---|---|
| T38-A | `T38-A/stdout.txt` | 是 (L41) | 1 | PASS |
| T38-B | `T38-B/stdout.txt` | 是 (L41) | 1 | PASS |
| T38-C | `T38-C/stdout.txt` | 是 (L41) | 1 | PASS |
| T38-heartbeat | `T38-heartbeat/stdout.txt` | 是 (L41) | 1 | PASS |
| T38-result-read | `T38-result-read/stdout.txt` | 是 (L41) | 1 | PASS |
| T38-stats-items | `T38-stats-items/stdout.txt` | 是 (L41+L44) | **2** | **FAIL (P1)** |

### 判定: **FAIL (P1)**

- 5/6 测试 PASS：`RUN_STATUS|failed|` 出现 1 次
- 1/6 测试 FAIL：T38-stats-items 的 `RUN_STATUS|failed|` 出现 2 次（L41 + L44）
- 根因：L480 缺少 `return`，执行落入 L481→L491→L496，二次输出
- 违反 constraint #13"仅输出一次"

---

## I6: md replacement failure → main md unchanged

### 定义

```
Move-Item $tmp $md -Force 失败
    ↓
主 md SHA256 before == after
```

### 证据

| 测试 | 证据文件 | main_md SHA256 before | main_md SHA256 after | 一致? |
|---|---|---|---|---|
| T23 | `T23/sha256-before.txt` + `T23/sha256-after.txt` | `AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81` | `AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81` | 是 |
| T22 | `T22/sha256-before.txt` + `T22/sha256-after.txt` | `AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81` | `AEAEAF44851D62375D8DF7D6E21CAF1A05DC3C64ED9B5AE894141331B3143C81` | 是 |

### 代码路径验证

SKILL L628-L631:
```powershell
} catch {
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    Write-Output ('RUNTIME_ERROR|主 md 原子替换失败：{0}'-f $_.Exception.Message)
}
```

`Move-Item` 失败时 catch 块清理 tmp，不修改主 md。主 md 仅在 `Move-Item` 成功后被替换。

### 判定: **PASS**

---

## I7: failure → safe cleanup + lock handling + terminal failed status

### 定义

```
任何失败路径
    ↓
safe cleanup（tmp 清理）
+
lock handling（锁释放或保留供陈锁机制接管）
+
terminal failed status（RUN_STATUS|failed|）
```

### 证据

| 测试 | 失败类型 | tmp cleanup | lock handling | RUN_STATUS\|failed\| | 判定 |
|---|---|---|---|---|---|
| T22 | md tmp 写入失败 | `md.tmp: FILE_NOT_EXISTS` ✓ | `run.lock: FILE_NOT_EXISTS` ✓ | 是 (L42) ✓ | **PASS** |
| T23 | md 原子替换失败 | `md.tmp: FILE_NOT_EXISTS` ✓ | `run.lock: FILE_NOT_EXISTS` ✓ | 是 (L43) ✓ | **PASS** |
| T38-A | review tmp 写入失败 | `result.review.tmp: FILE_NOT_EXISTS` ✓ | `run.lock: FILE_NOT_EXISTS` ✓ | 是 (L41) ✓ | **PASS** |
| T38-B | review JSON 校验失败 | `result.review.tmp: FILE_NOT_EXISTS` ✓ | `run.lock: FILE_NOT_EXISTS` ✓ | 是 (L41) ✓ | **PASS** |
| T38-C | review 原子替换失败 | `result.review.tmp: FILE_NOT_EXISTS` ✓ | `run.lock: FILE_NOT_EXISTS` ✓ | 是 (L41) ✓ | **PASS** |
| T38-heartbeat | heartbeat 失败 | N/A（无 tmp） | 锁保留（heartbeat 失败后 return，未调用 Release-LockSafely） | 是 (L41) ✓ | **PASS** |
| T38-result-read | result.json 读取失败 | N/A（无 tmp） | `run.lock: FILE_NOT_EXISTS` ✓（Release-LockSafely 被调用） | 是 (L41) ✓ | **PASS** |
| T38-stats-items | stats/items 完整性失败 | `result.review.tmp: FILE_NOT_EXISTS` ✓ | `run.lock: FILE_NOT_EXISTS` ✓ | 是 (L41+L44) ⚠️ | **PASS (with P1 caveat)** |

> T38-stats-items 的 cleanup 和 lock handling 均正确执行，但 `RUN_STATUS|failed|` 出现 2 次（P1 发现，见 I5）。

### 代码路径验证

- **tmp cleanup**：所有失败路径的 catch 块均执行 `Remove-Item $tmp -Force -ErrorAction SilentlyContinue`
- **lock handling**：
  - Step 4 错误路径调用 `Release-LockSafely`（L478/L480/L484/L494/L504）
  - Step 4 heartbeat 失败（L477）不调用 Release-LockSafely（设计如此，锁保留供陈锁机制接管）
  - Step 5 md tmp 失败（L596-L603）手动释放锁
  - Step 5 末尾（L637-L645）统一释放锁
- **terminal failed status**：所有失败路径均输出 `RUN_STATUS|failed|`

### 判定: **PASS (with P1 caveat on T38-stats-items)**

---

## 总结

| Invariant | 定义 | 判定 | 证据指向 |
|---|---|---|---|
| I1 | atomic md replacement success → commitSucceeded=true | **PASS** | T37/T43/T39 stdout |
| I2 | commitSucceeded=true + lockReleased=true → RUN_STATUS\|success\| | **PASS** | T37/T43 stdout |
| I3 | commitSucceeded=true + lockReleased=false → RUN_STATUS\|failed\| | **PASS** | T39 stdout |
| I4 | review write failure → no md commit | **PASS** | T38-A/B/C/heartbeat/result-read/stats-items/T22/T23 stdout |
| I5 | review write failure → RUN_STATUS\|failed\| | **FAIL (P1)** | T38-stats-items stdout（2 次输出） |
| I6 | md replacement failure → main md unchanged | **PASS** | T22/T23 sha256 before/after |
| I7 | failure → safe cleanup + lock handling + terminal failed status | **PASS (with P1 caveat)** | T22/T23/T38-A/B/C/heartbeat/result-read/stats-items 全部证据 |

### 总体判定

**Invariant Verification = FAIL (P1)**

- 6/7 invariants PASS
- 1/7 invariant FAIL（I5：T38-stats-items 的 `RUN_STATUS|failed|` 出现 2 次）
- 根因：SKILL-v1.10.md L480 缺少 `return` 语句
- 影响：违反 constraint #13"仅输出一次 `RUN_STATUS|failed|`"
