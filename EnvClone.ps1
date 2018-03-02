#Define the vCenter to be used
Connect-VIServer vcenter01

#List the cloning environment
$global:i=0
Get-Tag | Where {$_.Category.Name -eq "Virtual Machines"} | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name,Description -OutVariable menu | format-table -Autosize
$tagNum = Read-Host "Select the number of the environment to clone"
$tagName = $menu | where {$_.Number -eq $tagNum}
$fullTagName = "Virtual Machines/" + $tagName.Name
Write-Host "The following VMs will be refreshed:" -foreground "Yellow"
$envVMs = Get-VM | Where {(Get-TagAssignment -Entity $_ | Select -ExpandProperty Tag) -like $fullTagName}
$envVMs

#List and select the cluster destination
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Destination Cluster"
$clusterName = $menu | where {$_.Number -eq $clusterNum}
$hostName = Get-Cluster $clusterName.Name | Get-VMHost | Where {$_.State -eq "Connected"} | Get-Random

#List and Select the Datastore destination
$global:i=0
Get-VMHost $hostName.Name | Get-Datastore | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name,FreeSpaceGB -OutVariable menu | format-table -AutoSize
$datastoreNum = Read-Host "Select the number of the Destination Datastore"
$datastoreName = $menu | where {$_.Number -eq $datastoreNum}

#What's happening
Write-Host "The $($tagName.Description) will be refreshed" -foreground "Yellow"
Read-Host "Press Enter to begin refresh..."

#Clone the Environment
foreach ($vm in $envVMs) {
$extension = "-clone"
$cloneName = $vm.Name + $extension
$hostName = Get-Cluster $clusterName.Name | Get-VMHost | Where {$_.ConnectionState -eq "Connected"} | Get-Random
New-VM -Name $cloneName -vm $vm -VMHost $hostName -Datastore $datastoreName.Name -DiskStorageFormat Thin
$vmMacAddresses = Get-VM $vm | Get-NetworkAdapter
foreach ($a in $vmMacAddresses) {
$adapterName = Get-VM $vm | Get-NetworkAdapter | Where {$_.Name -eq $a.Name}
$cloneAdapter = Get-VM $cloneName | Get-NetworkAdapter | Where {$_.Name -eq $adapterName.name}
$cloneAdapter | Set-NetworkAdapter -MacAddress $adapterName.macAddress -confirm:$false} }

#List old and new VMs 
Write-Host "Original Virtual Machines in $($tagName.Description):" -foreground "Yellow"
$envVMs | Get-NetworkAdapter | Select @{Name="VM Name";Expression={Get-VM -id $_.ParentId}}, Name, MacAddress | Sort "VM name" | format-table
Write-Host "Cloned VMs:" -foreground "Yellow"
Get-VM | Where {$_.Name -like "*$extension"} | Get-NetworkAdapter | Select @{Name="VM Name";Expression={Get-VM -id $_.ParentId}}, Name, MacAddress | Sort "VM name" | format-table

#Assign tag to new VMs
Write-Host "Assigning $($tagName.Name) Tag to Cloned VMs..." -foreground "Yellow"
$newTag = Get-Tag $tagName.Name
$clonedVMs = Get-Cluster $clusterName.Name | Get-VM | Where {$_.Name -like "*$extension"}
foreach ($vm in $clonedVMs) {New-TagAssignment -Tag $newTag -Entity $vm}

#Power off and remove original VMs
Write-Host "Powering off original VMs..." -foreground "Yellow"
Read-Host "Press enter to continue..."
foreach ($vm in $envVMs){
$powerState = Get-VM $vm
If ($powerState.PowerState -eq "PoweredOn"){
Stop-VM $vm -Kill -Confirm:$false }ELSE{}}
$deleteVMs = Read-Host "Press "Y" to remove original VMs from vCenter and delete from disk. Anything else to just remove from vCenter"
IF ($deleteVMs -eq "Y"){Write-Host "Removing original VMs from vCenter and deleting from disk..." -foreground "Yellow";foreach ($vm in $envVMs){Remove-VM $vm -DeletePermanently -confirm:$false}}ELSE{Write-Host "Removing original VMs from vCenter..." -foreground "Yellow";foreach ($vm in $envVMs){Remove-VM $vm -confirm:$false}}

#Rename cloned VMs to Original VM names
Write-Host "Rename cloned VMs to original name..." -foreground "Yellow"
Read-Host "Press Enter to begin VM renaming"
foreach ($vm in $clonedVMs) {
$newName = $vm -replace $extension
Set-VM $vm -name $newName -confirm:$false }
