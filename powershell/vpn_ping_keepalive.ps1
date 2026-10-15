# Keep VPN from idling.
$log = "C:\ProgramData\vpverst\ping.log"
New-Item -ItemType Directory -Force -Path (Split-Path $log) -EA SilentlyContinue | Out-Null
while ($true) {
	$ok = Test-Connection 1.1.1.1 -Count 1 -Quiet -EA SilentlyContinue
	"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $(if ($ok) { 'OK' } else { 'FAIL' })" |
		Tee-Object $log -Append | Out-Null
	Start-Sleep 60
}
