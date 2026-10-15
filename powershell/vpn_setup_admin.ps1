#Requires -RunAsAdministrator
# Register watchdog/keepalive/KS tasks; arm KS after TUN is up.
$ErrorActionPreference = "Stop"
$VpnDir = "C:\Users\floger\Desktop\vpverst"
$Dir = "C:\Users\floger\Desktop\skies-dota-bot-automations\vpn"
$Ps = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$Exe = Join-Path $VpnDir "vpverst_client_cli.exe"
$Watch = Join-Path $Dir "vpn_run_watchdog.ps1"
$Ping = Join-Path $Dir "vpn_ping_keepalive.ps1"
$Ks = Join-Path $Dir "vpn_killswitch_enable_admin.ps1"

function Register-VpnTask($Name, $Arg, $Delay) {
	$action = New-ScheduledTaskAction -Execute $Ps -Argument $Arg -WorkingDirectory $Dir
	$trigger = New-ScheduledTaskTrigger -AtStartup
	$trigger.Delay = $Delay
	$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
		-StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew
	$settings.ExecutionTimeLimit = "PT0S"
	$prin = New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
	Register-ScheduledTask -TaskName $Name -Action $action -Trigger $trigger -Settings $settings -Principal $prin -Force | Out-Null
	Write-Host "Registered $Name"
}

foreach ($p in $Exe, $Watch, $Ping, $Ks) { if (-not (Test-Path $p)) { throw "Missing $p" } }
New-Item -ItemType Directory -Force -Path "C:\ProgramData\vpverst" | Out-Null
foreach ($n in "VpverstVpn", "VpnPingKeepalive", "VpnKillswitch") { Stop-ScheduledTask $n -EA SilentlyContinue }

Register-VpnTask VpverstVpn "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Watch`"" "PT1M"
Register-VpnTask VpnPingKeepalive "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Ping`"" "PT3M"
Register-VpnTask VpnKillswitch "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Ks`" -WaitForTun" "PT2M"

Start-ScheduledTask VpverstVpn
Start-ScheduledTask VpnPingKeepalive
Start-Sleep 3
& $Ks -WaitForTun -WaitSeconds 180
Write-Host "vpn_setup done"
