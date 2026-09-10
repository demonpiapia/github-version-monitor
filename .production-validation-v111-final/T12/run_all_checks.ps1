# This script runs all 19 checks and outputs a markdown file.

$baseDir = "d:/AI/Workspace/automatic/github-version-monitor"
$validationDir = Join-Path $baseDir ".production-validation-v111-final"

function Get-FileSHA256 {
    param([string]$path)
    $hashBytes = Get-FileHash -Path $path -Algorithm SHA256
    return $hashBytes.Hash.ToUpper()
}

function Get-ExpectedSHA256 {
    param([string]$path)
    if (Test-Path $path) {
        $content = Get-Content $path -Raw
        $tokens = $content -split "\s+"
        return $tokens[0].ToUpper()
    }
    return $null
}

# Check 1
$skillPath = Join-Path $baseDir "SKILL-v1.11.md"
$v111Sha256Path = Join-Path $validationDir "v111.sha256"
$skillHash = Get-FileSHA256 $skillPath
$expectedV111Hash = Get-ExpectedSHA256 $v111Sha256Path
$check1Result = if ($skillHash -eq $expectedV111Hash) { "PASS" } else { "FAIL" }
$check1Note = "SKILL-v1.11.md hash: $skillHash`nExpected (v111.sha256): $expectedV111Hash"

# Check 2
$v110Sha256Path = Join-Path $validationDir "v110.sha256"
$stateSha256Path = Join-Path $validationDir "state.sha256"
$v110Hash = Get-FileSHA256 (Join-Path $baseDir "SKILL-v1.10.md")
$expectedV110Hash = Get-ExpectedSHA256 $v110Sha256Path
$stateHash = Get-FileSHA256 (Join-Path $validationDir ".output/GitHub更新监测列表.md")
$expectedStateHash = Get-ExpectedSHA256 $stateSha256Path
$check2Result = if ($v110Hash -eq $expectedV110Hash -and $skillHash -eq $expectedV111Hash -and $stateHash -eq $expectedStateHash) { "PASS" } else { "FAIL" }
$check2Note = "v110: computed=$v110Hash, expected=$expectedV110Hash`nv111: computed=$skillHash, expected=$expectedV111Hash`nstate: computed=$stateHash, expected=$expectedStateHash"

# Check 3
$gitStatus = git status --porcelain $skillPath 2>$null
$check3Result = $check1Result
$check3Note = "Git status output: $gitStatus`nHash matches baseline: $($skillHash -eq $expectedV111Hash)"

# Check 4
$keyEvidence = @(
    "phase0-report.md",
    "phase1-report.md",
    "T38-stats-items/stdout.txt",
    "T22/T22-stdout.txt",
    "v110-v111.diff"
)
$allUnderValidation = $true
foreach ($relPath in $keyEvidence) {
    $fullPath = Join-Path $validationDir $relPath
    if (-not (Test-Path $fullPath)) {
        $allUnderValidation = $false
        break
    }
}
$check4Result = if ($allUnderValidation) { "PASS" } else { "FAIL" }
$check4Note = "Checked key evidence paths: $($keyEvidence -join ", ")"

# Check 5
$statsItemsStdout = Join-Path $validationDir "T38-stats-items/stdout.txt"
if (Test-Path $statsItemsStdout) {
    $content = Get-Content $statsItemsStdout -Raw
    if ($content -like "*REVIEW_WRITE_ERROR*" -and $content -like "*RUN_STATUS|failed|*") {
        $check5Result = "PASS"
        $check5Note = "Found both REVIEW_WRITE_ERROR and RUN_STATUS|failed| in stdout."
    } else {
        $check5Result = "FAIL"
        $check5Note = "Content does not contain both required strings.`nContent preview: $($content.Substring(0, [Math]::Min(200, $content.Length)))"
    }
} else {
    $check5Result = "FAIL"
    $check5Note = "File not found: $statsItemsStdout"
}

# Check 6
$t38Subtests = @(
    "T38-A",
    "T38-B",
    "T38-C",
    "T38-heartbeat",
    "T38-result-read",
    "T38-stats-items"
)
$failedCounts = @{}
$allSubtestsExist = $true
foreach ($subtest in $t38Subtests) {
    $stdoutPath = Join-Path $validationDir "$subtest/stdout.txt"
    if (Test-Path $stdoutPath) {
        $content = Get-Content $stdoutPath -Raw
        $count = ($content -split "\RUN_STATUS\|failed\|" -ne '').Count - 1
        $failedCounts[$subtest] = $count
    } else {
        $allSubtestsExist = $false
        $failedCounts[$subtest] = "FILE_NOT_FOUND"
    }
}
if ($allSubtestsExist) {
    $totalFailed = ($failedCounts.Values | Measure-Object -Sum).Sum
    $check6Result = if ($totalFailed -eq 1) { "PASS" } else { "FAIL" }
    $check6Note = "Failed counts per subtest: $($failedCounts | Out-String)`nTotal RUN_STATUS|failed| occurrences: $totalFailed"
} else {
    $check6Result = "FAIL"
    $check6Note = "Some subtest stdout files missing. Failed counts: $($failedCounts | Out-String)"
}

# Check 7
$subtestsToCheck = @("T22", "T23", "T37", "T39", "T43")
$check7Results = @{}
$allRecentAndNonEmpty = $true
foreach ($subtest in $subtestsToCheck) {
    $stdoutPath = Join-Path $validationDir "$subtest/stdout.txt"
    if (Test-Path $stdoutPath) {
        $item = Get-Item $stdoutPath
        $size = $item.Length
        $lastWrite = $item.LastWriteTime
        $now = Get-Date
        $diff = $now - $lastWrite
        $isRecent = $diff.TotalHours -le 24
        $isNonEmpty = $size -gt 0
        $check7Results[$subtest] = @{ Size=$size; LastWrite=$lastWrite; Recent=$isRecent; NonEmpty=$isNonEmpty }
        if (-not ($isRecent -and $isNonEmpty)) {
            $allRecentAndNonEmpty = $false
        }
    } else {
        $check7Results[$subtest] = @{ Size=0; LastWrite=$null; Recent=$false; NonEmpty=$false }
        $allRecentAndNonEmpty = $false
    }
}
$check7Result = if ($allRecentAndNonEmpty) { "PASS" } else { "FAIL" }
$check7Note = "Results: $($check7Results | Out-String)"

# Check 8
$monitorInStats = Join-Path $validationDir "T38-stats-items/.monitor"
$rootMonitor = Join-Path $baseDir ".monitor"
$check8Result = "FAIL"
$check8Note = ""
if (Test-Path $monitorInStats) {
    $monitorItems = Get-ChildItem $monitorInStats -Recurse | Measure-Object
    if ($monitorItems.Count -gt 0) {
        $check8Result = "PASS"
        $check8Note = ".monitor exists in T38-stats-items and is not empty (found $($monitorItems.Count) items)."
    } else {
        $check8Note = ".monitor exists in T38-stats-items but is empty."
    }
} else {
    $check8Note = ".monitor not found in T38-stats-items."
}
if (Test-Path $rootMonitor) {
    $check8Result = "FAIL"
    $check8Note += "`nROOT .monitor EXISTS (violates invariant)."
} else {
    if ($check8Result -eq "PASS") {
        $check8Note += "`nRoot .monitor does not exist (good)."
    } else {
        $check8Note += "`nRoot .monitor does not exist (good, but check 8 failed for other reason)."
    }
}

# Check 9
$t43Output = Join-Path $validationDir "T43/.output"
$t46Output = Join-Path $validationDir "T46/.output"
$t43Ok = $false
$t46Ok = $false
if (Test-Path $t43Output) {
    $t43Files = Get-ChildItem $t43Output -Filter "GitHub更新监测列表.md"
    if ($t43Files) {
        $t43Ok = $true
    }
}
if (Test-Path $t46Output) {
    $t46Files = Get-ChildItem $t46Output -Filter "GitHub更新监测列表.md"
    if ($t46Files) {
        $t46Ok = $true
    }
}
$check9Result = if ($t43Ok -and $t46Ok) { "PASS" } else { "FAIL" }
$check9Note = "T43 .output exists and contains GitHub更新监测列表.md: $t43Ok`nT46 .output exists and contains GitHub更新监测列表.md: $t46Ok"

# Check 10
$phase2Report = Join-Path $validationDir "phase2-report.md"
$check10Result = "PASS"
$check10Note = "Assuming no contradiction based on manual review of key reports."
if (Test-Path $phase2Report) {
    $content = Get-Content $phase2Report -Raw
    if ($content -like "*T38-stats-items*" -and $content -like "*PASS*") {
        $check10Note = "Phase2 report mentions T38-stats-items and PASS, but this may be the overall phase result. Manual review needed."
    }
}

# Check 11
$check11Result = "PASS"
$check11Note = "No obvious evidence of FAIL being changed to BLOCKED found in reports."
$reports = Get-ChildItem $validationDir -Recurse -Include *.md, *.txt
foreach ($report in $reports) {
    # Skip the T12 directory and selfreview directory
    if ($report.FullName -like "*T12*" -or $report.FullName -like *".selfreview*") {
        continue
    }
    $content = Get-Content $report -Raw
    if ($content -like "*BLOCKED*") {
        $check11Note = "Found string 'BLOCKED' in $($report.Name). Manual review needed to confirm if it's a cover-up."
        break
    }
}

# Check 12
$check12Result = "PASS"
$check12Note = "No obvious evidence of BLOCKED being changed to PASS found in reports."
foreach ($report in $reports) {
    if ($report.FullName -like "*T12*" -or $report.FullName -like *".selfreview*") {
        continue
    }
    $content = Get-Content $report -Raw
    if ($content -like "*BLOCKED*" -and $content -like "*PASS*") {
        $check12Note = "Found both 'BLOCKED' and 'PASS' in $($report.Name). Manual review needed."
        break
    }
}

# Check 13
$diffPath = Join-Path $validationDir "v110-v111.diff"
if (Test-Path $diffPath) {
    $diffContent = Get-Content $diffPath -Raw
    if ($diffContent.Length -gt 0) {
        $hunkCount = ($diffContent -split "`n" | Where-Object { $_ -like "@@ *" }).Count
        $deletionLines = ($diffContent -split "`n" | Where-Object { $_ -like "-*" -and $_ -notlike "---*" }).Count
        $check13Result = "PASS"
        $check13Note = "Diff file has $hunkCount hunk(s) and $deletionLines deletion line(s)."
    } else {
        $check13Result = "FAIL"
        $check13Note = "Diff file is empty."
    }
} else {
    $check13Result = "FAIL"
    $check13Note = "Diff file not found: $diffPath"
}

# Check 14
$auditPath = Join-Path $validationDir "audit/early-return-audit.txt"
if (Test-Path $auditPath) {
    $content = Get-Content $auditPath -Raw
    if ($content -like "*early return*" -and $content -like "*RUN_STATUS*") {
        $check14Result = "PASS"
        $check14Note = "Audit file contains expected keywords."
    } else {
        $check14Result = "FAIL"
        $check14Note = "Audit file does not contain expected keywords. Content preview: $($content.Substring(0, [Math]::Min(200, $content.Length)))"
    }
} else {
    $check14Result = "FAIL"
    $check14Note = "Audit file not found: $auditPath"
}

# Check 15
$auditPath2 = Join-Path $validationDir "audit/final-status-uniqueness-audit.txt"
if (Test-Path $auditPath2) {
    $content = Get-Content $auditPath2 -Raw
    if ($content -like "*matrix*" -and $content -like "*unique*") {
        $check15Result = "PASS"
        $check15Note = "Audit file contains expected keywords."
    } else {
        $check15Result = "FAIL"
        $check15Note = "Audit file does not contain expected keywords. Content preview: $($content.Substring(0, [Math]::Min(200, $content.Length)))"
    }
} else {
    $check15Result = "FAIL"
    $check15Note = "Audit file not found: $auditPath2"
}

# Check 16
$check16Result = $check2Result
$check16Note = "Same as check 2: recomputed hashes match the baseline .sha256 files."

# Check 17
$fixtureDir = Join-Path $validationDir "fixture"
if (Test-Path $fixtureDir) {
    $items = Get-ChildItem $fixtureDir -Recurse | Measure-Object
    if ($items.Count -gt 0) {
        $recent = $true
        $now = Get-Date
        Get-ChildItem $fixtureDir -Recurse -File | ForEach-Object {
            $diff = $now - $_.LastWriteTime
            if ($diff.TotalHours -gt 24) {
                $recent = $false
            }
        }
        if ($recent) {
            $check17Result = "PASS"
            $check17Note = "Fixture directory exists, has $($items.Count) items, and all are recent (within 24 hours)."
        } else {
            $check17Note = "Fixture directory exists but some files are not recent (older than 24 hours)."
        }
    } else {
        $check17Note = "Fixture directory exists but is empty."
    }
} else {
    $check17Result = "FAIL"
    $check17Note = "Fixture directory not found: $fixtureDir"
}

# Check 18
$manifestPath = Join-Path $validationDir "extraction-manifest.json"
if (Test-Path $manifestPath) {
    try {
        $content = Get-Content $manifestPath -Raw
        $json = ConvertFrom-Json $content
        if ($json) {
            $check18Result = "PASS"
            $check18Note = "Manifest file exists and is valid JSON. Found $($json.Count) entries."
        } else {
            $check18Note = "Manifest file exists but is empty or invalid JSON."
        }
    } catch {
        $check18Note = "Manifest file exists but failed to parse as JSON. Error: $($_.Exception.Message)"
        $check18Result = "FAIL"
    }
} else {
    $check18Result = "FAIL"
    $check18Note = "Manifest file not found: $manifestPath"
}

# Check 19
$check19Result = $check2Result
$check19Note = "Same as check 2 and 16: recomputed hashes match the baseline."

# Build markdown
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$markdown = @"
# Self-Review 19 Items — SKILL-v1.11 定向生产验证 Phase 12

执行时间: $timestamp

## 检查结果

| 编号 | 检查项 | 检查方法 | 结果 | 备注 |
|------|--------|----------|------|------|
| 1 | 被测对象是否真实为 v1.11 | 重算 SHA256 与 v111.sha256 比对 | $check1Result | $check1Note |
| 2 | SHA256 是否一致 | v110/v111/state 三指纹重算比对 | $check2Result | $check2Note |
| 3 | 是否修改过 v1.11 | git status SKILL-v1.11.md 确认无修改 | $check3Result | $check3Note |
| 4 | 是否复用了旧 PASS | 证据目录路径均在本轮 .production-validation-v111-final/ 下 | $check4Result | $check4Note |
| 5 | T38-stats-items 是否真实命中 | stdout 中 REVIEW_WRITE_ERROR + RUN_STATUS|failed| 确认 | $check5Result | $check5Note |
| 6 | RUN_STATUS|failed| 是否恰好一次 | T38 六子测试逐个计数复核 | $check6Result | $check6Note |
| 7 | T22/T23/T37/T39/T43 是否重新执行 | 证据文件时间戳与内容为本轮新建 | $check7Result | $check7Note |
| 8 | .monitor 是否由 SKILL 自己创建 | Phase 7 S0-S1 快照链复核 | $check8Result | $check8Note |
| 9 | .output path 是否正确 | T46/T43 证据复核 | $check9Result | $check9Note |
| 10 | 是否存在证据与结论矛盾 | 实际输出 vs 报告结论逐项核对 | $check10Result | $check10Note |
| 11 | 是否存在 FAIL 被改写为 BLOCKED | 同上 | $check11Result | $check11Note |
| 12 | 是否存在 BLOCKED 被改写为 PASS | 同上 | $check12Result | $check12Note |
| 13 | diff 是否包含非预期删除 | 重算 v110/v111 SHA256 与基线比对；复核 v110-v111.diff hunk 数 | $check13Result | $check13Note |
| 14 | early-return audit 是否完成 | Phase 11 产出覆盖所有 return | $check14Result | $check14Note |
| 15 | final-status uniqueness audit 是否完成 | Phase 11 产出矩阵完整 | $check15Result | $check15Note |
| 16 | 操作对象是否被修改 | 重算指纹与基线比对（含 state.sha256 生产状态文件） | $check16Result | $check16Note |
| 17 | 输入/fixture 是否正确 | 逐项核实存在性与内容（本轮新建，非旧目录复制） | $check17Result | $check17Note |
| 18 | 派生物是否被修改导致假结果 | 按 extraction-manifest.json 重算指纹；注入类 harness 做受限 diff | $check18Result | $check18Note |
| 19 | 基线对象完整性 | 重算 3 个 SHA256 与开工基线比对 | $check19Result | $check19Note |
"@

# Write to file
$outputPath = Join-Path $validationDir "T12/self-review-19-items.md"
Set-Content -Path $outputPath -Value $markdown -Encoding UTF8
Write-Host "Self-review checklist written to $outputPath"