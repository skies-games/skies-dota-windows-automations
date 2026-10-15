$ErrorActionPreference = "Continue"
$ok = $true
$Prefix = "SkiesVpnKS"

Write-Host "=== tasks ==="
foreach ($n in "VpverstVpn", "VpnPingKeepalive", "VpnKillswitch") {
	try {
		$t = Get-ScheduledTask $n -EA Stop
		$i = $t | Get-ScheduledTaskInfo
		Write-Host "$n $($t.State) last=$($i.LastTaskResult) run=$($i.LastRunTime)"
	} catch {
		Write-Host "$n MISSING"
		if ($n -eq "VpverstVpn") { $ok = $false }
	}
}

Write-Host "=== process / tun ==="
$proc = Get-Process vpverst_client_cli -EA SilentlyContinue
Write-Host $(if ($proc) { "vpverst pid=$($proc.Id)" } else { $ok = $false; "FAIL no vpverst" })
$tun = Get-NetAdapter -EA SilentlyContinue | ? { $_.Status -eq "Up" -and $_.Name -match "tun_vpverst" } | Select -First 1
Write-Host $(if ($tun) { "TUN $($tun.Name)" } else { $ok = $false; "FAIL no TUN" })
$h0 = $tun -and (Get-NetRoute "0.0.0.0/1" -EA SilentlyContinue | ? InterfaceAlias -eq $tun.Name)
$h1 = $tun -and (Get-NetRoute "128.0.0.0/1" -EA SilentlyContinue | ? InterfaceAlias -eq $tun.Name)
if ($h0 -and $h1) { Write-Host "TUN /1 OK" } else { $ok = $false; Write-Host "FAIL no /1 catchalls" }

Write-Host "=== routes ==="
Get-NetRoute "0.0.0.0/0", "0.0.0.0/1", "128.0.0.0/1", "94.159.114.153/32" -EA SilentlyContinue |
	ft DestinationPrefix, NextHop, InterfaceAlias, RouteMetric -Auto

Write-Host "=== killswitch ==="
$fw = Get-NetFirewallProfile
$fw | ft Name, DefaultOutboundAction -Auto
$rules = @(Get-NetFirewallRule -EA SilentlyContinue | ? DisplayName -like "$Prefix*")
$armed = ($rules.Count -gt 0) -and (@($fw | ? DefaultOutboundAction -eq "Block").Count -ge 3)
Write-Host "rules=$($rules.Count) $(if ($armed) { 'ARMED' } else { $ok = $false; 'OFF/PARTIAL' })"
foreach ($need in "$Prefix-VpnExe", "$Prefix-NebulaUdp") {
	if (-not ($rules | ? DisplayName -eq $need)) { $ok = $false; Write-Host "FAIL missing $need" }
}
if ($tun -and -not ($rules | ? DisplayName -like "$Prefix-If-tun*")) {
	$ok = $false; Write-Host "FAIL missing TUN if rule"
}

$log = "C:\ProgramData\vpverst\vpn_watchdog.log"
if (Test-Path $log) { Write-Host "=== watchdog tail ==="; Get-Content $log -Tail 5 }

Write-Host "=== verdict ==="
if ($ok) { "OK" } else { "NOT OK"; exit 1 }
