$id = Read-Host -Prompt 'Enter the VM ID (Just the number)'
#Write-Host 'You entered VM ID VirtualMachine-vm-$id'
$VMid = "VirtualMachine-vm-" + $id
Get-VM -id $VMid | Select Name