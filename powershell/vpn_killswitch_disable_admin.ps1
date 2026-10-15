#Requires -RunAsAdministrator
$ErrorActionPreference = "Continue"
$Prefix = "SkiesVpnKS"
$State = "C:\ProgramData\vpverst\killswitch_state.json"
$allows = @()
if (Test-Path $State) {
	$s = Get-Content $State -Raw | ConvertFrom-Json
	if ($s.allows) { $allows = @($s.allows) }
}

Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Allow
Get-NetFirewallRule -EA SilentlyContinue | ? DisplayName -like "$Prefix*" | Remove-NetFirewallRule -EA SilentlyContinue
foreach ($ip in $allows) { cmd /c "route -p delete $ip >nul 2>&1" | Out-Null }

$cfg = Get-NetIPConfiguration |
	? { $_.IPv4DefaultGateway -and $_.InterfaceAlias -match "^(Ethernet|Wi-Fi)" } |
	Select -First 1
if ($cfg) {
	$if, $gw = $cfg.InterfaceAlias, $cfg.IPv4DefaultGateway.NextHop
	if (-not (Get-NetRoute "0.0.0.0/0" -InterfaceAlias $if -NextHop $gw -EA SilentlyContinue)) {
		New-NetRoute -DestinationPrefix "0.0.0.0/0" -InterfaceAlias $if -NextHop $gw `
			-RouteMetric 0 -PolicyStore ActiveStore -EA SilentlyContinue | Out-Null
	}
}
Remove-Item $State -Force -EA SilentlyContinue
Write-Host "KS DISABLED"
