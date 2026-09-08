# Runtime Error Contract 静态分析

## Purpose
静态检查 Step 1-5 中所有关键文件操作是否在 try/catch 中，是否有 cleanup 和 lock release。

## 关键操作
- Set-Content
- Move-Item
- Add-Content
- ConvertFrom-Json
- ConvertTo-Json
- Get-Content
- File.Open / [IO.File]::Open / [System.IO.File]::Open

## 声明
静态检查只能作为辅助，T22/T23/T38 必须实际执行（已在 Phase 2 完成）。

---

## Step 1 (lib/step1.ps1, 70 行)

| 操作 | 行号 | try/catch | cleanup | lock release | 备注 |
|---|---|---|---|---|---|
| `[System.IO.File]::Open` (CreateNew) | L36 | ✅ L42-59 | N/A | N/A | New-LockOnce 函数内，外层 try/catch 捕获 IOException → 陈锁接管 |
| `Set-Content` (lock) | L39 | ✅ L42-59 | N/A | N/A | 在 New-LockOnce 函数内，被外层 try 保护 |
| `Get-Content` (lock) | L48 | ✅ L47-54 | N/A | N/A | 陈锁接管逻辑内，try/catch 保护 |
| `Remove-Item` (lock) | L56 | ✅ L55-57 | ✅ | ✅ | 陈锁接管 |
| `Copy-Item` (backup) | L69 | ❌ | ❌ | ❌ | 备份失败会冒泡（低风险：Step 1 唯一副作用是 backup，失败应终止） |

**结论**：Step 1 的锁操作全部受保护。备份操作无 try/catch 但这是合理的（备份失败应终止流程）。

---

## Step 2 (lib/step2.ps1, 182 行)

| 操作 | 行号 | try/catch | cleanup | lock release | 备注 |
|---|---|---|---|---|---|
| `Get-Content` (lock) | L17 | ✅ L16-30 | N/A | N/A | 锁 heartbeat 刷新，IOException → LOCKED |
| `[System.IO.File]::Open` (heartbeat) | L19 | ✅ L16-30 | N/A | N/A | 独占打开锁文件刷新 beat |
| `Get-Content` (md) | L32 | ❌ | ❌ | ❌ | 读取状态文件，失败会冒泡（合理：md 不存在应在 Step 1 检查） |
| `ConvertTo-Json` (result) | L160 | ✅ L160-173 | ✅ | ✅ | result.fetch.tmp 写入，失败 → RUNTIME_ERROR + Release-LockSafely |
| `Get-Content` (tmp) | L161 | ✅ L161 | ✅ | ✅ | 结构校验，失败 → RUNTIME_ERROR |
| `ConvertFrom-Json` (tmp) | L161 | ✅ L161 | ✅ | ✅ | 结构校验 |
| `Move-Item` (result.json) | L168 | ✅ L168-173 | ✅ | ✅ | 原子替换，失败 → RUNTIME_ERROR + Release-LockSafely |
| `Add-Content` (fetch_run.log) | L175 | ❌ | ❌ | ❌ | 日志追加，失败会冒泡（低风险：日志失败不影响主流程） |
| `Remove-Item` (tmp) | L163, L169 | ✅ | ✅ | ✅ | 清理 tmp 文件 |
| `Release-LockSafely` | L165, L171 | ✅ | ✅ | ✅ | 释放锁 |

**关键发现**：
- Step 2 **不验证锁 ownership**（与 Step 3/4/5 不同）：L17-18 只读取锁文件内容，不检查 `pid=` 是否匹配当前 PID
- 外来 PID 锁会被 heartbeat 刷新覆盖（L19-23 直接 SetLength(0) + Write）
- 这是 lock-ownership 测试 FAIL 的根本原因

---

## Step 3 (lib/step3.ps1, 20 行)

| 操作 | 行号 | try/catch | cleanup | lock release | 备注 |
|---|---|---|---|---|---|
| `Get-Content` (lock) | L8 | ✅ L7-13 | N/A | N/A | 锁 heartbeat + ownership 校验 |
| `[System.IO.File]::Open` (heartbeat) | L11 | ✅ L7-13 | N/A | N/A | 独占打开锁文件刷新 beat |
| `Move-Item` (trash) | L20 | ❌ | ❌ | ❌ | 备份清理到 trash，失败会冒泡（低风险：清理失败不影响主流程） |

**结论**：Step 3 的锁操作全部受保护。备份清理无 try/catch 但这是合理的（清理失败应终止流程）。

---

## Step 4 (lib/step4.ps1, 33 行)

| 操作 | 行号 | try/catch | cleanup | lock release | 备注 |
|---|---|---|---|---|---|
| `Get-Content` (lock) | L3 | ✅ L3 (Release-LockSafely) | N/A | ✅ | 锁释放函数内 |
| `Get-Content` (lock) | L4 | ✅ L4 (heartbeat) | N/A | N/A | 锁 heartbeat + ownership 校验 |
| `[IO.File]::Open` (heartbeat) | L4 | ✅ L4 | N/A | N/A | 独占打开锁文件刷新 beat |
| `Get-Content` (result.json) | L5 | ❌ | ❌ | ❌ | 读取 result.json，失败会冒泡（合理：Step 2 已验证结构） |
| `ConvertFrom-Json` (result.json) | L5 | ❌ | ❌ | ❌ | 同上 |
| `ConvertTo-Json` (stats/items) | L5, L7 | ❌ | ❌ | ❌ | 序列化比较，失败会冒泡（合理） |
| `Set-Content` (result.review.tmp) | L8 | ✅ L7-15 | ✅ | ✅ | 写入 tmp，失败 → REVIEW_WRITE_ERROR + Release-LockSafely |
| `Get-Content` (tmp) | L16 | ✅ L16 | ✅ | ✅ | 结构校验，失败 → REVIEW_WRITE_ERROR |
| `ConvertFrom-Json` (tmp) | L16 | ✅ L16 | ✅ | ✅ | 结构校验 |
| `ConvertTo-Json` (stats/items) | L17 | ✅ L17 | ✅ | ✅ | 序列化比较 |
| `Move-Item` (result.json) | L25 | ✅ L24-32 | ✅ | ✅ | 原子替换，失败 → REVIEW_WRITE_ERROR + Release-LockSafely |
| `Remove-Item` (tmp) | L10, L18, L27 | ✅ | ✅ | ✅ | 清理 tmp 文件 |
| `Release-LockSafely` | L11, L20, L29 | ✅ | ✅ | ✅ | 释放锁 |

**关键发现**：
- Step 4 L5 的 `Get-Content result.json | ConvertFrom-Json` 未在 try/catch 中
- 如果 result.json 不存在或损坏，异常会冒泡（不释放锁）
- 这是合理的：Step 2 已经验证了 result.json 结构，Step 4 不应再处理此错误
- 但如果 Step 2 和 Step 4 之间 result.json 被外部修改，Step 4 会异常退出

---

## Step 5 (lib/step5-full.ps1, 134 行)

| 操作 | 行号 | try/catch | cleanup | lock release | 备注 |
|---|---|---|---|---|---|
| `[System.IO.File]::Open` (heartbeat) | L11 | ✅ L10-14 | N/A | N/A | 锁 heartbeat，IOException → LOCKED |
| `Get-Content` (result.json) | L15 | ❌ | ❌ | ❌ | 读取 result.json，失败会冒泡（合理：Step 2/4 已验证） |
| `ConvertFrom-Json` (result.json) | L15 | ❌ | ❌ | ❌ | 同上 |
| `Get-Content` (md) | L36 | ❌ | ❌ | ❌ | 读取主 md，失败会冒泡（合理：Step 1 已检查存在性） |
| `Set-Content` (md.tmp) | L71 | ✅ L70-88 | ✅ | ✅ | 写入 tmp，失败 → RUNTIME_ERROR + 锁释放 + RUN_STATUS\|failed\| |
| `Get-Content` (md.tmp) | L72 | ✅ L70-88 | ✅ | ✅ | 读取校验，失败 → RUNTIME_ERROR |
| `Move-Item` (md) | L106 | ✅ L105-112 | ✅ | ❌ | 原子替换主 md，失败 → RUNTIME_ERROR（但锁释放逻辑在 L117-126 独立执行） |
| `Remove-Item` (md.tmp) | L74, L110, L114 | ✅ | ✅ | ❌ | 清理 tmp 文件 |
| `Get-Content` (lock) | L78, L120 | ✅ L77-84, L119-126 | N/A | ✅ | 锁释放前的 ownership 校验 |
| `Remove-Item` (lock) | L81, L123 | ✅ | N/A | ✅ | 释放锁 |

**关键发现**：
- Step 5 L15 的 `Get-Content result.json | ConvertFrom-Json` 未在 try/catch 中
- Step 5 L36 的 `Get-Content $md` 未在 try/catch 中
- 这些都是合理的：Step 2/4 已经验证了 result.json 结构，Step 1 已经检查了 md 存在性
- 如果这些文件在 Step 5 执行前被外部修改，异常会冒泡（不释放锁）
- **但**：Step 5 的锁释放逻辑（L117-126）是独立的，即使前面的代码异常退出，锁也不会被释放
- 这是 v1.9 的已知设计：Step 5 的异常路径（L70-88）有完整的锁释放，但 L15/L36 的异常路径没有

---

## 总结

### 受保护的关键写入操作（全部 ✅）
- Step 2: Set-Content result.fetch.tmp (L160), Move-Item result.json (L168)
- Step 4: Set-Content result.review.tmp (L8), Move-Item result.json (L25)
- Step 5: Set-Content md.tmp (L71), Move-Item md (L106)

### 未受保护的读取操作（合理设计）
- Step 2 L32: Get-Content md（Step 1 已检查存在性）
- Step 4 L5: Get-Content result.json（Step 2 已验证结构）
- Step 5 L15: Get-Content result.json（Step 2/4 已验证结构）
- Step 5 L36: Get-Content md（Step 1 已检查存在性）

### 未受保护的日志/清理操作（低风险）
- Step 2 L175: Add-Content fetch_run.log（日志追加失败不影响主流程）
- Step 3 L20: Move-Item trash（备份清理失败不影响主流程）
- Step 1 L69: Copy-Item backup（备份失败应终止流程）

### 锁释放覆盖
- Step 2: Release-LockSafely 在 L165, L171（result.fetch.tmp 写入/替换失败时）
- Step 3: 无锁释放需求（Step 3 不修改主状态）
- Step 4: Release-LockSafely 在 L11, L20, L29（review 写入/替换失败时）
- Step 5: 锁释放在 L77-84（md.tmp 写入失败时）和 L117-126（正常流程结束时）

### 已知问题
1. **Step 2 不验证锁 ownership**：外来 PID 锁会被 heartbeat 刷新覆盖（lock-ownership 测试 FAIL）
2. **Step 4/5 的 result.json 读取无 try/catch**：如果 result.json 在 Step 2 之后被外部修改，Step 4/5 会异常退出且不释放锁
3. **Step 5 的 md 读取无 try/catch**：如果 md 在 Step 1 之后被外部修改，Step 5 会异常退出且不释放锁

### 与 Phase 2 测试结果的一致性
- T22 (md.tmp 写入失败)：Step 5 L70-88 有完整 try/catch + cleanup + lock release + RUN_STATUS|failed| ✅
- T23 (Move-Item 原子替换失败)：Step 5 L105-112 有 try/catch + cleanup，锁释放在 L117-126 独立执行 ✅
- T38 (result.review.tmp 写入失败)：Step 4 L7-15 有完整 try/catch + cleanup + lock release + REVIEW_WRITE_ERROR| ✅
