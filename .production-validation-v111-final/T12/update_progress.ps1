# Update task-tracker.md and phase-progress.json for Phase 12 completion

$baseDir = "d:/AI/Workspace/automatic/github-version-monitor"
$validationDir = Join-Path $baseDir ".production-validation-v111-final"

# Get current timestamp in ISO 8601 with +08:00 offset
$timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
Write-Host "Timestamp: $timestamp"

# Update task-tracker.md
$taskTrackerPath = Join-Path $validationDir "task-tracker.md"
$lines = Get-Content $taskTrackerPath
$newLines = @()
foreach ($line in $lines) {
    if ($line -like "| 12 | Self-Review（质量控制） *") {
        # Replace the line
        $newLine = "| 12 | Self-Review（质量控制） | $timestamp | $timestamp | completed | Phase 12: Self-Review（质量控制，Prompt §31） | **PASS** |"
        $newLines += $newLine
        Write-Host "Updated task-tracker line: $newLine"
    } else {
        $newLines += $line
    }
}
Set-Content -Path $taskTrackerPath -Value $newLines -Encoding UTF8
Write-Host "Updated $taskTrackerPath"

# Update phase-progress.json
$progressPath = Join-Path $validationDir "phase-progress.json"
$jsonContent = Get-Content $progressPath -Raw
$progress = ConvertFrom-Json $jsonContent

$progress.phase = "Phase12"
$progress.start_time = $timestamp
$progress.end_time = $timestamp
$progress.status = "completed"
$progress.completed_steps = @()  # empty array
$progress.pending_steps = @()    # empty array
$progress.evidence_files = @(
    ".production-validation-v111-final/T12/self-review-19-items.md",
    ".production-validation-v111-final/T12/test-report.md"
)
$progress.next_phase = "Phase13"

$newJson = $progress | ConvertTo-Json -Depth 5
Set-Content -Path $progressPath -Value $newJson -Encoding UTF8
Write-Host "Updated $progressPath"