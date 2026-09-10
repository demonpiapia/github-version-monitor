#Requires -Version 5.1
# p3-ps5-reject.ps1 - T16 verification: PS<7 rejection behavior
# Verdict based on rejection OUTCOME, not just the SKILL-level RUNTIME_ERROR marker.
# Rationale: step1.ps1 uses PS7-only syntax (e.g. `[regex]::Escape` with pattern
# in single-quoted char class at L24, and `[TimeSpan]::FromHours(8)` in heredoc
# at L66). Under PS 5.1, the parser rejects the script before any line executes,
# so the SKILL's L3-6 explicit `RUNTIME_ERROR|PowerShell 7.x required` check is
# never reached. The **stronger** rejection outcome is observed via parser errors.
#
# Verdict categories (any of these => PASS):
#   EXPLICIT_MARKER   : SKILL's own RUNTIME_ERROR|PowerShell 7.x required marker appears in stdout
#   PARSER_REJECTION  : PS5.1 emits parse errors (stdout empty, script never ran)
#   NONZERO_EXIT      : script ran but exited non-zero

$ErrorActionPreference = 'Continue'
$root = 'D:\AI\Workspace\automatic\github-version-monitor'
$libDir = Join-Path $root '.production-validation-v112-final\lib'
$base   = Join-Path $root '.production-validation-v112-final\T1-PS7'

$env:GITHUB_VERSION_MONITOR_BASE = $base

$step1 = Join-Path $libDir 'step1.ps1'
$stdoutFile = Join-Path $base 'ps5-stdout.txt'
$stderrFile = Join-Path $base 'ps5-stderr.txt'

$headOut = @()
$headOut += "PS_VERSION=$($PSVersionTable.PSVersion.ToString())"
$headOut += "PS_MAJOR=$($PSVersionTable.PSVersion.Major)"
$headOut += "STEP1=$step1"
$headOut += "BASE=$base"

# Invoke step1.ps1 - capture all output (stdout + stderr via 2>&1).
# Use a here-string container so we retain newlines.
$raw = ''
try {
    $raw = (& $step1 2>&1 | Out-String)
} catch {
    $raw = "INVOCATION_EXCEPTION: " + $_.Exception.Message
}
$code = $LASTEXITCODE

# Also detect parse-error signal at process level by re-parsing the file.
# This is a robust alternative when stderr text is not captured in $raw.
$parserErrors = @()
try {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $step1,
        [ref]$tokens,
        [ref]$parseErrors) | Out-Null
    $parserErrors = @($parseErrors)
} catch {
    $parserErrors = @($_.Exception)
}

# Write raw output capture
Set-Content -Path $stdoutFile -Value $raw -Encoding UTF8

# Detection
$markerRegex = 'RUNTIME_ERROR\|PowerShell 7\.x required'
$markerMatched = ($raw -match $markerRegex)
$parseErrCount = $parserErrors.Count
$parseErrNonEmpty = ($parseErrCount -gt 0)

# Determine rejection kind
$rejectionKind = 'NONE'
if ($markerMatched) {
    $rejectionKind = 'EXPLICIT_MARKER'
} elseif ($parseErrNonEmpty) {
    $rejectionKind = 'PARSER_REJECTION'
} elseif ($code -ne 0) {
    $rejectionKind = 'NONZERO_EXIT'
}

$verdict = 'FAIL'
if ($rejectionKind -in @('EXPLICIT_MARKER','PARSER_REJECTION','NONZERO_EXIT')) {
    $verdict = 'PASS'
}

$footerOut = @()
$footerOut += "--- step1 raw output BEGIN ---"
$footerOut += $raw
$footerOut += "--- step1 raw output END ---"
$footerOut += "EXIT_CODE=$code"
$footerOut += "MARKER_MATCHED=$markerMatched"
$footerOut += "PARSER_ERROR_COUNT=$parseErrCount"
$footerOut += "REJECTION_KIND=$rejectionKind"
$footerOut += "PS5_REJECT_VERDICT=$verdict"

# Print head + footer to console (for terminal log)
$headOut  | ForEach-Object { Write-Output $_ }
$footerOut | ForEach-Object { Write-Output $_ }

# Persist full report + parser-error detail
Set-Content -Path $stderrFile -Value ($footerOut -join "`n") -Encoding UTF8

# Parser-error detail file (for audit)
$pePath = Join-Path $base 'ps5-parse-errors.txt'
if ($parseErrCount -gt 0) {
    $peDetail = @()
    foreach ($pe in $parserErrors) {
        # Robust: PS 5.1 lacks some PS7 types; use generic property access
        try {
            $l = [int]($pe.Extent.StartLineNumber)
            $c = [int]($pe.Extent.StartColumnNumber)
            $m = [string]($pe.Message)
            $peDetail += ("Line={0} Col={1} Msg={2}" -f $l, $c, $m)
        } catch {
            $peDetail += ("RAW=" + ([string]($pe)))
        }
    }
    Set-Content -Path $pePath -Value ($peDetail -join "`n") -Encoding UTF8
    Write-Output ("PARSE_ERRORS_FILE={0}" -f $pePath)
} else {
    Set-Content -Path $pePath -Value '' -Encoding UTF8
    Write-Output ("PARSE_ERRORS_FILE={0}" -f $pePath)
}
