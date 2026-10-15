# Keep vpverst up. Restart if /1 catchalls incomplete. Refresh stale TUN fw rules.
$ErrorActionPreference = "Continue"
$VpnDir = "C:\Users\floger\Desktop\vpverst"
$Exe = Join-Path $VpnDir "vpverst_client_cli.exe"
$LogDir = "C:\ProgramData\vpverst"
$Log = Join-Path $LogDir "vpn_watchdog.log"
$Prefix = "SkiesVpnKS"
$State = Join-Path $LogDir "killswitch_state.json"
New-Item -ItemType Directory -Force -Path $LogDir -EA SilentlyContinue | Out-Null

function Log($m) {
	$line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"
	Write-Host $line
	Add-Content $Log $line -EA SilentlyContinue
}

function Test-TunCatchalls {
	$h0 = Get-NetRoute "0.0.0.0/1" -EA SilentlyContinue | ? InterfaceAlias -match "tun_vpverst"
	$h1 = Get-NetRoute "128.0.0.0/1" -EA SilentlyContinue | ? InterfaceAlias -match "tun_vpverst"
	[bool]($h0 -and $h1)
}

function Sync-TunFw {
	$tuns = @(Get-NetAdapter -EA SilentlyContinue | ? { $_.Status -eq "Up" -and $_.Name -match "tun_vpverst" } | % Name)
	if (-not $tuns) { return }
	Get-NetFirewallRule -EA SilentlyContinue | ? DisplayName -like "$Prefix-If-tun*" | Remove-NetFirewallRule -EA SilentlyContinue
	foreach ($t in $tuns) {
		New-NetFirewallRule -DisplayName "$Prefix-If-$($t -replace '[^A-Za-z0-9]','_')" `
			-Direction Outbound -Action Allow -Profile Any -Enabled True -InterfaceAlias $t -EA SilentlyContinue | Out-Null
		Log "tun fw $t"
	}
}

function Repair-TunFw {
	if (-not (Test-TunCatchalls)) { return }
	$alive = Test-Connection 1.1.1.1 -Count 1 -Quiet -EA SilentlyContinue
	$rule = [bool](Get-NetFirewallRule -EA SilentlyContinue | ? DisplayName -like "$Prefix-If-tun*")
	if ($rule -and $alive) { return }
	Log "tun fw repair (rule=$rule ping=$alive)"
	Sync-TunFw
}

function Repair-Pins {
	if (-not (Test-Path $State)) { return }
	$st = Get-Content $State -Raw | ConvertFrom-Json
	foreach ($ip in @($st.allows)) {
		if (-not $ip) { continue }
		if (Get-NetRoute "$ip/32" -EA SilentlyContinue | ? NextHop -eq $st.gateway) { continue }
		Log "repair /32 $ip"
		New-NetRoute -DestinationPrefix "$ip/32" -InterfaceAlias $st.uplink_alias `
			-NextHop $st.gateway -RouteMetric 1 -PolicyStore ActiveStore -EA SilentlyContinue | Out-Null
		cmd /c "route -p add $ip mask 255.255.255.255 $($st.gateway) metric 1 >nul 2>&1" | Out-Null
	}
}

function Start-Vpverst {
	$psi = New-Object Diagnostics.ProcessStartInfo
	$psi.FileName = $Exe
	$psi.WorkingDirectory = $VpnDir
	$psi.UseShellExecute = $false
	$psi.CreateNoWindow = $true
	[Diagnostics.Process]::Start($psi)
}

Log "watchdog start pid=$PID"
if (-not (Test-Path $Exe)) { Log "FAIL missing $Exe"; exit 1 }

while ($true) {
	try {
		if (Get-Process vpverst_client_cli -EA SilentlyContinue) {
			if (-not (Test-TunCatchalls)) {
				Log "incomplete /1 - restart vpverst"
				Get-Process vpverst_client_cli -EA SilentlyContinue | Stop-Process -Force
				Start-Sleep 5
				continue
			}
			Repair-TunFw
			Start-Sleep 15
			continue
		}

		Repair-Pins
		Log "starting vpverst"
		$p = Start-Vpverst
		if (-not $p) { Start-Sleep 5; continue }

		# Wait for BOTH /1 catchalls. Do not WaitForExit on a half-tunnel — that
		# blocks forever while KS drops 128.0.0.0/1 traffic (e.g. github).
		$deadline = (Get-Date).AddSeconds(90)
		$ok = $false
		while (-not $p.HasExited -and (Get-Date) -lt $deadline) {
			if (Test-TunCatchalls) {
				Repair-TunFw
				$ok = $true
				break
			}
			Start-Sleep 2
		}
		if (-not $ok) {
			Log "incomplete /1 after start - kill and retry"
			if (-not $p.HasExited) { $p.Kill() }
			Start-Sleep 5
			continue
		}
		# Poll while running — bare WaitForExit is blind if 128/1 drops mid-flight.
		while (-not $p.HasExited) {
			if (-not (Test-TunCatchalls)) {
				Log "incomplete /1 while running - kill"
				$p.Kill()
				break
			}
			Repair-TunFw
			Start-Sleep 15
		}
		if ($p.HasExited) { Log "exited $($p.ExitCode); restart in 5s" }
		else { Log "killed; restart in 5s" }
	} catch { Log "error $($_.Exception.Message)" }
	Start-Sleep 5
}
exit 1
