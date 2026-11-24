# Control-PC: sshpass.exe for skies-dota-automations. Not for bots.
$ErrorActionPreference = "Stop"
$Url = "https://github.com/xhcoding/sshpass-win32/releases/download/v1.0.7/sshpass.exe"
$Dir = Join-Path $env:LOCALAPPDATA "sshpass"
$Dest = Join-Path $Dir "sshpass.exe"

New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Invoke-WebRequest -Uri $Url -OutFile $Dest -UseBasicParsing

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$parts = @()
if ($userPath) {
	$parts = $userPath -split ";" | Where-Object { $_ -and $_.Trim() -ne "" }
}
if ($parts -notcontains $Dir) {
	[Environment]::SetEnvironmentVariable(
		"Path",
		(($parts + $Dir) -join ";"),
		"User"
	)
}
$env:Path = "$Dir;$env:Path"

Write-Host "ok: $Dest"
Write-Host "open a NEW terminal, then: where.exe sshpass"
