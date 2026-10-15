#Requires -RunAsAdministrator
$ErrorActionPreference = "Continue"
& "$PSScriptRoot\vpn_killswitch_disable_admin.ps1"
foreach ($n in "VpverstVpn", "VpnPingKeepalive", "VpnKillswitch") {
	Stop-ScheduledTask -TaskName $n -EA SilentlyContinue
	Unregister-ScheduledTask -TaskName $n -Confirm:$false -EA SilentlyContinue
}
Get-Process vpverst_client_cli -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
Write-Host "vpn_teardown done"
