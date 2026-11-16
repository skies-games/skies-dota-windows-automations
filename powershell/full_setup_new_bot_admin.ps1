# Full setup for a new bot machine. Run elevated.
$ErrorActionPreference = "Stop"
$psDir = $PSScriptRoot
$bashDir = Join-Path (Split-Path $psDir -Parent) "bash"

$steps = @(
    (Join-Path $psDir "initial_setup_admin.ps1"),
    (Join-Path $psDir "download_chocolatey_admin.ps1"),
    (Join-Path $psDir "packages_install_admin.ps1"),
    (Join-Path $psDir "vnc_setup_admin.ps1"),
    (Join-Path $bashDir "nebula_download.bat"),
    (Join-Path $psDir "nebula_setup_admin.ps1"),
    (Join-Path $psDir "ssh_install_admin.ps1")
)

foreach ($step in $steps) {
    if (-not (Test-Path $step)) { throw "Missing: $step" }
    Write-Host "`n=== $($step) ===" -ForegroundColor Cyan
    if ($step -like "*.bat") {
        & cmd.exe /c "`"$step`""
    } else {
        & $step
    }
    if (-not $?) { throw "Failed: $step" }
}

Write-Host "`n=== full_setup_new_bot done ===" -ForegroundColor Green
