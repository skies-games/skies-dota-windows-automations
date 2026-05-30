$CloneVMConfigFile = read-host "Please, enter the name of the config file with the .vmcx extension from the VM being cloned: "
$vmCount = read-host "Please, enter the amount of vms you want to see: "
For ($i = 2; $i -le $vmCount; $i++) {
    write-host "Creating VM: $i"
    $Result = import-vm -Path "C:\vms\vm1\vm1\Virtual Machines\$CloneVMConfigFile" -VhdSourcePath "C:\vms\vm1\" -Copy -GenerateNewID -VirtualMachinePath "C:\vms\vm$i" -VhdDestinationPath "C:\vms\vm$i"
    $Result | rename-vm -NewName "vm$i"
}