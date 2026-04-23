# bin/package-r7.ps1
# Produces a single OneWoW-Suite-R7.0.0.zip from the ONEWOW_SUITE_7 fork.
# Stages all 20 addon folders into a temp directory so the zip contents are
# exactly what a user drops into Interface\AddOns\.
#
# Usage: powershell -ExecutionPolicy Bypass -File bin\package-r7.ps1 [-Version <ver>]

param(
    [string]$Version    = "R7.0.0",
    [string]$SourceRoot = (Join-Path (Split-Path -Parent $PSScriptRoot) "ONEWOW_SUITE_7"),
    [string]$OutputDir  = (Join-Path (Split-Path -Parent $PSScriptRoot) ".releases")
)

$ErrorActionPreference = "Stop"

Write-Host "=== OneWoW Suite Packager ==="
Write-Host "Version    : $Version"
Write-Host "Source     : $SourceRoot"
Write-Host "Output dir : $OutputDir"
Write-Host ""

if (-not (Test-Path $SourceRoot)) {
    throw "Source root not found: $SourceRoot"
}
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
}

# The 20 addons that make up R7. Each must have a matching TOC file at the
# folder root. Anything else under ONEWOW_SUITE_7 (README.md, unrelated
# scratch dirs) is ignored by the zip so users get a clean payload.
$addons = @(
    "OneWoW",
    "OneWoW_GUI",
    "OneWoW_AltTracker",
    "OneWoW_Catalog",
    "OneWoW_Notes",
    "OneWoW_Trackers",
    "OneWoW_QoL",
    "OneWoW_Data_Storage",
    "OneWoW_Data_Character",
    "OneWoW_Data_Collections",
    "OneWoW_Data_Endgame",
    "OneWoW_Data_Accounting",
    "OneWoW_Data_Professions",
    "OneWoW_Data_Journal",
    "OneWoW_Data_Quests",
    "OneWoW_Data_Vendors",
    "OneWoW_Bags",
    "OneWoW_DirectDeposit",
    "OneWoW_ShoppingList",
    "OneWoW_Utility_DevTool"
)

# Validate every expected addon exists and has a TOC file whose version line
# matches $Version. This catches "someone forgot to bump" before we ship.
$missing = @()
$badVersion = @()
foreach ($a in $addons) {
    $folder = Join-Path $SourceRoot $a
    $toc    = Join-Path $folder "$a.toc"
    if (-not (Test-Path $folder)) { $missing += $a; continue }
    if (-not (Test-Path $toc))    { $missing += "$a (missing TOC)"; continue }
    $verLine = (Select-String -Path $toc -Pattern "^## Version:" | Select-Object -First 1).Line
    if (-not ($verLine -match [regex]::Escape($Version))) {
        $badVersion += "$a -> $verLine"
    }
}
if ($missing.Count -gt 0) {
    Write-Host "ERROR - missing addons or TOCs:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "Package aborted."
}
if ($badVersion.Count -gt 0) {
    Write-Host "ERROR - TOC version mismatch (expected $Version):" -ForegroundColor Red
    $badVersion | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    throw "Package aborted. Run the version bumper first."
}
Write-Host "All $($addons.Count) addons found at version $Version. Staging..." -ForegroundColor Green

# Stage into a fresh temp directory so the zip contents are deterministic
# regardless of what unrelated files live under ONEWOW_SUITE_7.
$staging = Join-Path ([System.IO.Path]::GetTempPath()) ("OneWoW-Suite-$Version-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $staging | Out-Null
try {
    foreach ($a in $addons) {
        $src = Join-Path $SourceRoot $a
        $dst = Join-Path $staging $a
        Copy-Item -Path $src -Destination $dst -Recurse -Force
    }

    # Copy the user-facing README and plan so the zip is self-documenting.
    $readme = Join-Path $SourceRoot "README.md"
    if (Test-Path $readme) { Copy-Item $readme (Join-Path $staging "README.md") -Force }
    $planDir = Join-Path (Split-Path -Parent $SourceRoot) ".releases"
    $planMd  = Join-Path $planDir "OneWoW-Suite-Consolidation-Plan.md"
    if (Test-Path $planMd) { Copy-Item $planMd (Join-Path $staging "OneWoW-Suite-Consolidation-Plan.md") -Force }

    $zipPath = Join-Path $OutputDir "OneWoW-Suite-$Version.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path (Join-Path $staging "*") -DestinationPath $zipPath -CompressionLevel Optimal

    $zipInfo = Get-Item $zipPath
    $sizeMB  = [math]::Round($zipInfo.Length / 1MB, 2)
    Write-Host ""
    Write-Host "SUCCESS" -ForegroundColor Green
    Write-Host "  $zipPath ($sizeMB MB)"
    Write-Host "  Contains $($addons.Count) addons."
} finally {
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
}
