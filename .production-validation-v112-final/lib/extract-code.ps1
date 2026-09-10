#Requires -Version 7.0
param(
    [Parameter(Mandatory=$true)][string]$SourcePath,
    [Parameter(Mandatory=$true)][string]$OutDir
)

$PSDefaultParameterValues['*:Encoding'] = 'UTF8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

# =====================================================================
# extract-code.ps1
# Purpose: byte-exact extraction of the 5 ```powershell code blocks from
#          SKILL-v1.12.md into lib/step*.ps1 for Phase 2 harness use.
# Contract:
#   - Read source as UTF-8 (no BOM detection needed; preserve raw bytes).
#   - Locate the 5 opening ```powershell fences (must be exactly 5).
#   - Extract body lines between opening fence and matching closing ```
#     (exclusive of fence lines themselves).
#   - Preserve line endings exactly (LF in source -> LF in output).
#   - Output files: step1.ps1, step2.ps1, step3.ps1, step4.ps1, step5-full.ps1
#   - Emit byte-diff verification between extracted bytes and source slice.
# Args:
#   -SourcePath   (mandatory) Path to SKILL-v1.12.md
#   -OutDir       (mandatory) lib/ directory
# =====================================================================

if (-not (Test-Path $SourcePath)) { throw "SOURCE_NOT_FOUND: $SourcePath" }
if (-not (Test-Path $OutDir))     { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

# ---- Read as raw UTF-8 bytes to preserve line endings exactly -------------
$srcBytes = [System.IO.File]::ReadAllBytes($SourcePath)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$srcText = $utf8.GetString($srcBytes)

# Detect line ending convention of source file
if ($srcText -match "`r`n") {
    $srcEol = "`r`n"; Write-Output "SOURCE_EOL=CRLF"
} else {
    $srcEol = "`n"; Write-Output "SOURCE_EOL=LF"
}

# ---- Locate all ```powershell opening fences -----------------------------
$lines = [regex]::Split($srcText, "`r?`n")
Write-Output ("SOURCE_LINE_COUNT=" + $lines.Count)

$openIdx = @()
foreach ($i in 0..($lines.Count - 1)) {
    if ($lines[$i] -ceq '```powershell') { $openIdx += $i }
}
Write-Output ("OPEN_FENCE_COUNT=" + $openIdx.Count)
if ($openIdx.Count -ne 5) {
    throw "FENCE_COUNT_MISMATCH: expected 5, got $($openIdx.Count)"
}

# ---- For each opening fence, find the matching closing "```" --------------
$blocks = @()
for ($k = 0; $k -lt $openIdx.Count; $k++) {
    $openLine0 = $openIdx[$k]
    $closeLine0 = -1
    for ($j = $openLine0 + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -ceq '```') { $closeLine0 = $j; break }
    }
    if ($closeLine0 -lt 0) { throw "NO_CLOSE_FENCE: block #$($k+1) open at L$($openLine0+1)" }
    $bodyStart0 = $openLine0 + 1
    $bodyEnd0   = $closeLine0 - 1
    $bodyLines  = $lines[$bodyStart0..$bodyEnd0]
    $blocks += [PSCustomObject]@{
        Index       = $k + 1
        OpenLine1   = $openLine0 + 1
        CloseLine1  = $closeLine0 + 1
        BodyStart1  = $bodyStart0 + 1
        BodyEnd1    = $bodyEnd0 + 1
        BodyLines   = $bodyLines
    }
}

$names = @('step1.ps1', 'step2.ps1', 'step3.ps1', 'step4.ps1', 'step5-full.ps1')
if ($blocks.Count -ne $names.Count) {
    throw "BLOCKS_NAMES_MISMATCH: blocks=$($blocks.Count) names=$($names.Count)"
}

# ---- Compute byte offset of each source line for exact slice comparison ---
# We compute byte offset of each line by scanning the raw source bytes for
# line terminators, ensuring exact correspondence to raw file bytes (including
# any BOM).
$lineByteStart = New-Object 'System.Collections.Generic.List[int]'
$lineByteStart.Add(0)  # line 1 starts at byte 0
$eolLen = if ($srcEol -ceq "`r`n") { 2 } else { 1 }
for ($i = 0; $i -lt $srcBytes.Length - 1; $i++) {
    if ($srcBytes[$i] -eq 0x0A) {   # LF
        if ($srcEol -ceq "`r`n" -and $srcBytes[$i-1] -eq 0x0D) {
            $i = $i   # already handled: LF after CR
        }
        # Next line starts at $i + $eolLen
        $lineByteStart.Add($i + $eolLen)
    }
}
# If file doesn't end with newline, lineByteStart.Count == total lines + 1
# (last entry would point past EOF). Trim if so.
$expectedLineStartCount = $lines.Count
# Note: for "a\nb\n" Split gives ["a","b",""] (3 items), and lineByteStart
# would be [0, lenA+1, lenA+lenB+2] (3 entries). Both 3. Match.
# For "a\nb" Split gives ["a","b"] (2 items), lineByteStart=[0, lenA+1] (2). Match.
Write-Output ("LINES_SPLIT_COUNT=" + $lines.Count)
Write-Output ("LINE_BYTE_START_COUNT=" + $lineByteStart.Count)
Write-Output ("ACTUAL_SOURCE_BYTES=" + $srcBytes.Length)

$manifest = [System.Collections.Generic.List[PSCustomObject]]::new()
foreach ($b in $blocks) {
    $name = $names[$b.Index - 1]
    $outPath = Join-Path $OutDir $name

    # Byte range of body in source: from start of first body line to
    # end of last body line + its EOL (i.e., start of the close-fence line).
    $sliceStart = $lineByteStart[$b.BodyStart1 - 1]
    # The close fence line is at line index $b.CloseLine1 - 1 (0-based).
    # Its start byte = end of body slice.
    $sliceEnd   = $lineByteStart[$b.CloseLine1 - 1]
    $sliceLen   = $sliceEnd - $sliceStart
    if ($sliceLen -le 0) { throw "INVALID_SLICE: block #$($b.Index) len=$sliceLen" }
    $sliceBytes = New-Object byte[] $sliceLen
    [Array]::Copy($srcBytes, $sliceStart, $sliceBytes, 0, $sliceLen)
    # Write the raw slice bytes directly - guarantees byte-exactness
    [System.IO.File]::WriteAllBytes($outPath, $sliceBytes)
    $outBytes = $sliceBytes

    $match = ($sliceBytes.Length -eq $outBytes.Length)
    if ($match) {
        for ($i = 0; $i -lt $sliceBytes.Length; $i++) {
            if ($sliceBytes[$i] -ne $outBytes[$i]) { $match = $false; break }
        }
    }

    $sha = (Get-FileHash -Algorithm SHA256 -Path $outPath).Hash.ToUpper()
    $manifest += [PSCustomObject]@{
        File             = $name
        SourceStartLine  = $b.OpenLine1
        SourceEndLine    = $b.CloseLine1
        BodyStartLine    = $b.BodyStart1
        BodyEndLine      = $b.BodyEnd1
        SHA256           = $sha
        Bytes            = $outBytes.Length
        ByteDiffMatch    = [string]$match
    }
    Write-Output ("WROTE={0} SHA256={1} BYTES={2} LINES={3}-{4} BODYDIFF={5}" -f $name, $sha, $outBytes.Length, $b.BodyStart1, $b.BodyEnd1, $match)
}

Write-Output "MANIFEST_BEGIN"
$manifest | Format-Table -AutoSize | Out-String | Write-Output
Write-Output "MANIFEST_END"

$allMatch = ($manifest | Where-Object { $_.ByteDiffMatch -cne 'True' }).Count -eq 0
if (-not $allMatch) {
    Write-Output "VERDICT=FAIL"
    exit 2
} else {
    Write-Output "VERDICT=PASS"
}
