#Requires -RunAsAdministrator
# Fail-closed outbound. Allow: vpverst.exe, UDP/4242, TUN+nebula1, LAN/DHCP/DNS.
# Pin lighthouse /32 so VPN /1 catchalls do not steal Nebula underlay.
param(
	[string]$UplinkAlias = "Ethernet",
	[string]$Lighthouse = "94.159.114.153",
	[string]$VpnExe = "C:\Users\floger\Desktop\vpverst\vpverst_client_cli.exe",
	[switch]$WaitForTun,
	[int]$WaitSeconds = 180
)
$ErrorActionPreference = "Stop"
$Prefix = "SkiesVpnKS"
$State = "C:\ProgramData\vpverst\killswitch_state.json"
$Lan = @("10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12")

function Test-TunCatchalls {
	$h0 = Get-NetRoute "0.0.0.0/1" -EA SilentlyContinue | ? InterfaceAlias -match "tun_vpverst"
	$h1 = Get-NetRoute "128.0.0.0/1" -EA SilentlyContinue | ? InterfaceAlias -match "tun_vpverst"
	return [bool]($h0 -and $h1)
}

function Sync-TunFw {
	$tuns = @(Get-NetAdapter -EA SilentlyContinue | ? { $_.Status -eq "Up" -and $_.Name -match "tun_vpverst" } | % Name)
	if (-not $tuns) { return @() }
	Get-NetFirewallRule -EA SilentlyContinue | ? DisplayName -like "$Prefix-If-tun*" | Remove-NetFirewallRule -EA SilentlyContinue
	foreach ($t in $tuns) {
		New-NetFirewallRule -DisplayName "$Prefix-If-$($t -replace '[^A-Za-z0-9]','_')" `
			-Direction Outbound -Action Allow -Profile Any -Enabled True -InterfaceAlias $t | Out-Null
	}
	$tuns
}

if ($WaitForTun) {
	Write-Host "Waiting for TUN /1..."
	$deadline = (Get-Date).AddSeconds($WaitSeconds)
	while (-not (Test-TunCatchalls)) {
		if ((Get-Date) -gt $deadline) { throw "Timeout waiting for VPN TUN /1" }
		Start-Sleep 3
	}
}

$up = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -EA SilentlyContinue |
	? { $_.InterfaceAlias -eq $UplinkAlias -and $_.NextHop -ne "0.0.0.0" } |
	Select -First 1
if (-not $up) {
	$up = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -EA SilentlyContinue |
		? { $_.NextHop -ne "0.0.0.0" -and $_.InterfaceAlias -match "^(Ethernet|Wi-Fi)" } |
		Sort RouteMetric | Select -First 1
}
if (-not $up) { throw "No uplink default route" }
if (-not (Test-Path $VpnExe)) { throw "Missing $VpnExe" }

$ifAlias, $gw = $up.InterfaceAlias, $up.NextHop
$nebula = @(Get-NetAdapter -EA SilentlyContinue | ? { $_.Status -eq "Up" -and $_.Name -eq "nebula1" } | % Name)

New-Item -ItemType Directory -Force -Path (Split-Path $State) | Out-Null
Get-NetFirewallRule -EA SilentlyContinue | ? DisplayName -like "$Prefix*" | Remove-NetFirewallRule -EA SilentlyContinue

$allow = @{ Direction = "Outbound"; Action = "Allow"; Profile = "Any"; Enabled = "True" }
New-NetFirewallRule -DisplayName "$Prefix-Loopback" @allow -RemoteAddress "127.0.0.0/8" | Out-Null
New-NetFirewallRule -DisplayName "$Prefix-LAN" @allow -RemoteAddress $Lan | Out-Null
New-NetFirewallRule -DisplayName "$Prefix-VpnExe" @allow -Program $VpnExe | Out-Null
New-NetFirewallRule -DisplayName "$Prefix-NebulaUdp" @allow -Protocol UDP -RemotePort 4242 | Out-Null
New-NetFirewallRule -DisplayName "$Prefix-Dhcp" @allow -Protocol UDP -LocalPort 68 -RemotePort 67 | Out-Null
New-NetFirewallRule -DisplayName "$Prefix-DnsLan" @allow -Protocol UDP -RemotePort 53 -RemoteAddress $Lan | Out-Null
foreach ($n in $nebula) { New-NetFirewallRule -DisplayName "$Prefix-If-nebula1" @allow -InterfaceAlias $n | Out-Null }
$tuns = @(Sync-TunFw)

@{ uplink_alias = $ifAlias; gateway = $gw; allows = @($Lighthouse); lighthouse = $Lighthouse; vpn_exe = $VpnExe; saved_at = (Get-Date).ToString("o") } |
	ConvertTo-Json | Set-Content $State -Encoding UTF8

Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Block

$ErrorActionPreference = "Continue"
# Do NOT `route delete 128.0.0.0` — that can wipe VPN catchall 128.0.0.0/1 (half-tunnel).
if (-not (Get-NetRoute "$Lighthouse/32" -InterfaceAlias $ifAlias -EA SilentlyContinue)) {
	New-NetRoute -DestinationPrefix "$Lighthouse/32" -InterfaceAlias $ifAlias -NextHop $gw `
		-RouteMetric 1 -PolicyStore ActiveStore -EA SilentlyContinue | Out-Null
}
cmd /c "route -p add $Lighthouse mask 255.255.255.255 $gw metric 1 >nul 2>&1" | Out-Null

Write-Host "KS ENABLED uplink=$ifAlias gw=$gw lighthouse=$Lighthouse tuns=$($tuns -join ',')"
