# Full setup for a new bot machine. Run elevated.
# Expects all listed scripts in the same directory as this file.
$ErrorActionPreference = "Stop"
$dir = $PSScriptRoot

$steps = @(
    "initial_setup_admin.ps1",
    "download_chocolatey_admin.ps1",
    "packages_install_admin.ps1",
    "vnc_setup_admin.ps1",
    "nebula_download.bat",
    "nebula_setup_admin.ps1",
    "ssh_install_admin.ps1"
)

foreach ($name in $steps) {
    $step = Join-Path $dir $name
    if (-not (Test-Path $step)) { throw "Missing: $step" }
    Write-Host "`n=== $name ===" -ForegroundColor Cyan
    if ($name -like "*.bat") {
        & cmd.exe /c "`"$step`""
    } else {
        & $step
    }
    if (-not $?) { throw "Failed: $name" }
}

Write-Host "`n=== full_setup_new_bot done ===" -ForegroundColor Green
