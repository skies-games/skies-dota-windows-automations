New-VMSwitch -Name "Ethernet" -NetAdapterName Ethernet
mkdir C:\vms
new-vm -Name "vm1" -MemoryStartupBytes 5GB -Generation 2 -NewVHDPath C:\vms\vm1\vm1.vhdx -NewVHDSizeBytes 35GB -Path C:\vms\vm1 -Switch "Ethernet"
set-vmprocessor -VMName "vm1" -Count 2
add-vmdvddrive -VMName "vm1" -Path "C:\Users\$env:username\Downloads\ReviOS_v25.10_Win11_25H2_x64.iso"
enable-vmintegrationservice -VMName "vm1" -Name "Guest Service Interface"
disable-vmintegrationservice -VMName "vm1" -Name "VSS"
Set-VM -Name "vm1" -AutomaticCheckpointsEnabled $false
Set-VMMemory -VMName "vm1" -DynamicMemoryEnabled $false