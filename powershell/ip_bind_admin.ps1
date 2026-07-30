#Requires -RunAsAdministrator

# === edit only this ===
$IpAddress = "192.168.100.153"
# ======================

$Gateway = ($IpAddress -replace '\.\d+$', '.1')

Set-NetIPInterface -InterfaceAlias "Ethernet" -Dhcp Disabled

Get-NetIPAddress -InterfaceAlias "Ethernet" -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

Remove-NetRoute -InterfaceAlias "Ethernet" -DestinationPrefix "0.0.0.0/0" -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress `
    -InterfaceAlias "Ethernet" `
    -IPAddress $IpAddress `
    -PrefixLength 24 `
    -DefaultGateway $Gateway

Set-DnsClientServerAddress -InterfaceAlias "Ethernet" -ServerAddresses $Gateway, "1.1.1.1"
