# Extract PowerShell code blocks verbatim from SKILL-v1.8.md
# Uses byte-level slicing to guarantee exact character preservation.
param(
    [string]$SkillFile = 'd:\AI\Workspace\automatic\github-version-monitor\SKILL-v1.8.md',
    [string]$OutDir    = 'd:\AI\Workspace\automatic\github-version-monitor\.production-validation-v18-final\lib'
)
$ErrorActionPreference = 'Stop'
$bytes = [System.IO.File]::ReadAllBytes($SkillFile)
# Source is LF-only (verified: 721 LF, 0 CRLF).
# Build line-start byte offsets (1-indexed line -> byte offset).
$lineStarts = New-Object 'System.Collections.Generic.List[int]'
$lineStarts.Add(0)
for ($i = 0; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 10) { $lineStarts.Add($i + 1) }
}
Write-Output ("Source: {0} bytes, {1} lines (LF-only)" -f $bytes.Length, $lineStarts.Count)

function Extract-ByteRange([int]$StartLine, [int]$EndLine) {
    # 1-indexed inclusive; returns byte[] covering lines StartLine..EndLine exactly (no trailing LF)
    # lineStarts[i] = byte offset of line (i+1). LF of line N is at lineStarts[N]-1.
    $start = $lineStarts[$StartLine - 1]
    # End of last line: byte before the LF of EndLine, or EOF if EndLine is last
    if ($EndLine -lt $lineStarts.Count) {
        $end = $lineStarts[$EndLine] - 1  # exclusive end (skip the LF of EndLine)
    } else {
        $end = $bytes.Length
    }
    $len = $end - $start
    $out = New-Object byte[] $len
    [Array]::Copy($bytes, $start, $out, 0, $len)
    return $out
}

function Write-Bytes([string]$Path, [byte[]]$Data) {
    [System.IO.File]::WriteAllBytes($Path, $Data)
}

# Step boundaries (verified from SKILL-v1.8.md):
#   Step 1 fence: L159..L230 -> code L160..L229
#   Step 2 fence: L238..L422 -> code L239..L421
#   Step 3 fence: L430..L451 -> code L431..L450
#   Step 4 fence: L471..L480 -> code L472..L479
#   Step 5 fence: L490..L603 -> code L491..L602
#   Step 5 commit portion: L491..L584 (through closing `}` of if/else)
#   Step 5 lockrelease portion: L585..L602 (from "# 释放锁前确认 ownership" comment)
Write-Bytes (Join-Path $OutDir 'step1.ps1')            (Extract-ByteRange 160 229)
Write-Bytes (Join-Path $OutDir 'step2.ps1')            (Extract-ByteRange 239 421)
Write-Bytes (Join-Path $OutDir 'step3.ps1')            (Extract-ByteRange 431 450)
Write-Bytes (Join-Path $OutDir 'step4.ps1')            (Extract-ByteRange 472 479)
Write-Bytes (Join-Path $OutDir 'step5-full.ps1')       (Extract-ByteRange 491 602)
Write-Bytes (Join-Path $OutDir 'step5-commit.ps1')     (Extract-ByteRange 491 584)
Write-Bytes (Join-Path $OutDir 'step5-lockrelease.ps1')(Extract-ByteRange 585 602)

$files = @('step1.ps1','step2.ps1','step3.ps1','step4.ps1','step5-full.ps1','step5-commit.ps1','step5-lockrelease.ps1')
foreach ($f in $files) {
    $p = Join-Path $OutDir $f
    $c = @(Get-Content -LiteralPath $p)
    $first = $c[0]
    $last  = $c[-1]
    $h = (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash
    $sz = (Get-Item $p).Length
    Write-Output ("{0,-22} lines={1,-4} bytes={2,-6} sha256={3}" -f $f, $c.Count, $sz, $h)
    Write-Output ("    first: {0}" -f $first)
    Write-Output ("    last : {0}" -f $last)
}
