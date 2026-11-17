# Full setup for a new bot machine. Run elevated.
# .ps1 steps live next to this file; .bat steps live in ../bash.
$ErrorActionPreference = "Stop"
$psDir = $PSScriptRoot
$bashDir = Join-Path (Split-Path $psDir -Parent) "bash"

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
    $dir = if ($name -like "*.bat") { $bashDir } else { $psDir }
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
