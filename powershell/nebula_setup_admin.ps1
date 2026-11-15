$nebulaDir = "C:\Users\$env:username\Desktop\nebula"
$exePath = Join-Path $nebulaDir "nebula.exe"
$configPath = Join-Path $nebulaDir "config.yaml"

$action = New-ScheduledTaskAction `
    -Execute $exePath `
    -Argument "-config `"$configPath`"" `
    -WorkingDirectory $nebulaDir

# Network/Wintun often aren't ready at the exact boot moment — delay + retries.
$trigger = New-ScheduledTaskTrigger -AtStartup
$trigger.Delay = "PT1M"

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 10 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName "Nebula" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Force

Start-Process -FilePath $exePath -ArgumentList "-config `"$configPath`"" -WorkingDirectory $nebulaDir
