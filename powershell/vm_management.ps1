#start all vms
get-vm | start-vm
#shut-down all vms
get-vm | stop-vm
#restart all vms
get-vm | restart-vm
#start a specific vm
get-vm -Name "vm1" | start-vm
#shut-down a specific vm
get-vm -Name "vm1" | stop-vm
#restart a specific vm 
get-vm -Name "vm1" | restart-vm