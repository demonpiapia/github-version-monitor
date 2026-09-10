OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$out = @()
$out += "=== SHA256 BASELINE RECOMPUTE (Phase 8 sub-agent) ==="
$out += ("Timestamp_utc=" + (Get-Date -AsUtc).ToString("yyyy-MM-ddTHH:mm:ssZ"))
$out += ("PSVersionTable.PSVersion=" + $PSVersionTable.PSVersion.ToString())
$out += ("PSVersionTable.PSVersion.Major=" + $PSVersionTable.PSVersion.Major)
$out += ("PSVersionTable.PSVersion.Minor=" + $PSVersionTable.PSVersion.Minor)
$out += ("PSVersionTable.PSVersion.Patch=" + $PSVersionTable.PSVersion.Patch)
$out += ("pwsh_exe=" + (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source)
$out += ("OS=" + $PSVersionTable.OS)
$out += ""

$out += "=== Three SHA256 recompute ==="
$files = @(
    "SKILL-v1.11.md",
    "SKILL-v1.12.md",
    ".output\GitHub更新监测列表.md"
)
$baselines = @{
    "SKILL-v1.11.md"                   = "B6632680A9AE18E02634E6EAF7F261FCD2502FE0529566088D0E0FC7160FC928"
    "SKILL-v1.12.md"                   = "3B15C9D7B3B37ADDB185489EBE2E8B89617867787F5EB83979FF066D23B28BE9"
    ".output\GitHub更新监测列表.md"     = "7396981A2FBF019D3DAD0C906A2B6E9C05D36C4746F35E0C0063FD1F3EB19CD3"
}
foreach ($f in $files) {
    $item = Get-Item -LiteralPath $f
    $h = Get-FileHash -Algorithm SHA256 -LiteralPath $f
    $match = if ($h.Hash -eq $baselines[$f]) { "MATCH" } else { "MISMATCH" }
    $out += ("FILE=" + $f)
    $out += ("  SHA256_actual   = " + $h.Hash)
    $out += ("  SHA256_baseline = " + $baselines[$f])
    $out += ("  SIZE_bytes      = " + $item.Length)
    $out += ("  RESULT          = " + $match)
}

$out += ""
$out += "=== Env token ==="
$envs = @("GITHUB_TOKEN","GH_TOKEN","GITHUB_PAT","GH_PAT")
foreach ($k in $envs) {
    $v = Get-Item "Env:$k" -ErrorAction SilentlyContinue
    if ($v) {
        $out += ("  " + $k + " available=True len=" + $v.Value.Length)
    } else {
        $out += ("  " + $k + " available=False")
    }
}

$out += ""
$out += "=== Environment restore checks ==="
# lock-after.txt existence for T1
$lockAfter = ".production-validation-v112-final\T4-write-failure\sha256-after.txt"
if (Test-Path -LiteralPath $lockAfter) {
    $out += ("  T4 sha256-after.txt exists: True")
}
# Check for stray lock files
$stray = Get-ChildItem -Recurse -Force -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '\.lock$|LOCK_EXISTS' }
$out += ("  stray lock-ish files found: " + @($stray).Count)

$out += ""
$out += "=== No external test processes ==="
$ps = Get-Process | Where-Object { $_.Name -like '*lock-holder*' -or $_.ProcessName -like '*mock*' }
$out += ("  suspicious processes: " + @($ps).Count)

$out -join [Environment]::NewLine
