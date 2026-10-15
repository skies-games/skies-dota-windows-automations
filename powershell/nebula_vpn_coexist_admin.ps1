#Requires -RunAsAdministrator
# Laptop only: pin Nebula underlay /32s on physical uplink so OpenVPN /1 does not steal them.
param(
	[string]$UplinkAlias = "",
	[string]$Lighthouse = "94.159.114.153",
	[string[]]$ExtraUnderlay = @()
)
$ErrorActionPreference = "Stop"

function Test-Ipv4([string]$Ip) {
	$Ip -match '^(?:(?:25[0-5]|2[0-4]\d|[01]?\d\d?)\.){3}(?:25[0-5]|2[0-4]\d|[01]?\d\d?)$'
}

function Get-Uplink {
	param([string]$Prefer)
	$routes = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -EA SilentlyContinue |
		? { $_.NextHop -ne "0.0.0.0" -and $_.InterfaceAlias -notmatch "tun_|nebula|OpenVPN|TAP|Wintun" })
	if ($Prefer) {
		$hit = $routes | ? InterfaceAlias -eq $Prefer | Select -First 1
		if ($hit) { return $hit }
	}
	$phys = $routes | ? InterfaceAlias -match "^(Ethernet|Wi-Fi|WLAN)" | Sort RouteMetric | Select -First 1
	if ($phys) { return $phys }
	$routes | Sort RouteMetric | Select -First 1
}

function Get-PublicIpv4sFromLogs {
	$found = [System.Collections.Generic.List[string]]::new()
	$rx = [regex]'(?<![:\d])(\d{1,3}(?:\.\d{1,3}){3}):(?:4242|\d+)\b'
	foreach ($f in @(
			"C:\ProgramData\vpverst\nebula_service_out.log",
			"C:\ProgramData\vpverst\nebula_out.log"
		)) {
		if (-not (Test-Path $f)) { continue }
		Select-String -Path $f -Pattern "udpAddrs=" -EA SilentlyContinue | % {
			foreach ($m in $rx.Matches($_.Line)) {
				$ip = $m.Groups[1].Value
				if (-not (Test-Ipv4 $ip)) { continue }
				if ($ip -match "^(10\.|127\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|169\.254\.)") { continue }
				if (-not $found.Contains($ip)) { $found.Add($ip) }
			}
		}
	}
	@($found)
}

$up = Get-Uplink $UplinkAlias
if (-not $up) { throw "No uplink default route (Ethernet/Wi-Fi)" }
$UplinkAlias = $up.InterfaceAlias
$gw = $up.NextHop

$ips = @(
	@($Lighthouse) + @($ExtraUnderlay) + @(Get-PublicIpv4sFromLogs) |
		% { ("$_").Trim() -replace "/\d+$", "" } |
		? { $_ -and (Test-Ipv4 $_) } |
		Select -Unique
)
if ($ips.Count -eq 0) { throw "No valid underlay IPs to bypass" }

Write-Host "Uplink=$UplinkAlias gw=$gw"
Write-Host "Bypass: $($ips -join ', ')"

foreach ($ip in $ips) {
	$prefix = "$ip/32"
	$existing = Get-NetRoute -DestinationPrefix $prefix -InterfaceAlias $UplinkAlias -EA SilentlyContinue |
		? NextHop -eq $gw
	if (-not $existing) {
		New-NetRoute -DestinationPrefix $prefix -InterfaceAlias $UplinkAlias -NextHop $gw `
			-RouteMetric 1 -PolicyStore ActiveStore | Out-Null
		Write-Host "ADD $prefix via $gw on $UplinkAlias"
	} else {
		Write-Host "OK  $prefix already on $UplinkAlias"
	}
	cmd /c "route -p add $ip mask 255.255.255.255 $gw metric 1 >nul 2>&1" | Out-Null
	try {
		$via = (Find-NetRoute -RemoteIPAddress $ip | Select -First 1).InterfaceAlias
		Write-Host "  path $ip -> $via"
	} catch {
		Write-Host "  path $ip -> (no route yet)"
	}
}

try { Set-NetConnectionProfile -InterfaceAlias "nebula1" -NetworkCategory Private -EA SilentlyContinue } catch {}
Write-Host "Done. Nebula underlay on $UplinkAlias; OpenVPN keeps the rest."
