add-windowscapability -Online -Name OpenSSH.Client~~~~0.0.1.0

add-windowscapability -Online -Name OpenSSH.Server~~~~0.0.1.0

start-service sshd
set-service -Name sshd -StartupType "Automatic"

new-netfirewallrule -Name sshd -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22