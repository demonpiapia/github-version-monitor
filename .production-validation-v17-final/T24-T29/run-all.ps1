$base = "d:\AI\Workspace\automatic\github-version-monitor\.production-validation-v17-final\T24-T29"

# --- T24: 5 columns (missing one) ---
& "$base\parser.ps1" -FixturePath "$base\T24\fixture.md" 2>&1 | Out-File -FilePath "$base\T24\stdout.txt" -Encoding utf8

# --- T25: 7 columns (extra one) ---
& "$base\parser.ps1" -FixturePath "$base\T25\fixture.md" 2>&1 | Out-File -FilePath "$base\T25\stdout.txt" -Encoding utf8

# --- T26: invalid flags + valid flags ---
$t26Out = @()
foreach($f in @('fixture_inv_upper_yes','fixture_inv_title_yes','fixture_inv_mixed_yes','fixture_inv_upper_no','fixture_inv_title_no','fixture_inv_pending','fixture_inv_true','fixture_valid_yes','fixture_valid_no')){
    $result = & "$base\parser.ps1" -FixturePath "$base\T26\$f.md" 2>&1
    $t26Out += "=== $f ==="
    $t26Out += $result
    $t26Out += ""
}
$t26Out | Out-File -FilePath "$base\T26\stdout.txt" -Encoding utf8

# --- T27: duplicate repo ---
& "$base\parser.ps1" -FixturePath "$base\T27\fixture.md" 2>&1 | Out-File -FilePath "$base\T27\stdout.txt" -Encoding utf8

# --- T28: non-integer index ---
& "$base\parser.ps1" -FixturePath "$base\T28\fixture.md" 2>&1 | Out-File -FilePath "$base\T28\stdout.txt" -Encoding utf8

# --- T29: missing anchor sections ---
$t29Out = @()
foreach($f in @('fixture_no_conclusion','fixture_no_update_summary','fixture_no_remarks','fixture_no_verify_method')){
    $result = & "$base\parser.ps1" -FixturePath "$base\T29\$f.md" 2>&1
    $t29Out += "=== $f ==="
    $t29Out += $result
    $t29Out += ""
}
$t29Out | Out-File -FilePath "$base\T29\stdout.txt" -Encoding utf8

Write-Output "All tests completed."
