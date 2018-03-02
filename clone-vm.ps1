#List and Select VM Template for Cloning
$global:i=0
get-template | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$templateNum = Read-Host "Select the number of the template"
$templateName = $menu | where {$_.Number -eq $templateNum}

#List and Select Guest Customization Spec
$global:i=0
Get-OSCustomizationSpec | Select @{Name="Number";Expression={$global:i++;$global:i}},Name,OSType -OutVariable menu | format-table -AutoSize
$osSpecNum = Read-Host "Select the number of the Guest Customization Spec"
$osSpecName = $menu | where {$_.Number -eq $osSpecNum}

#List and Select the Cluster 
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Cluster"
$clusterName = $menu | where {$_.Number -eq $clusterNum}

#Select a host from the cluster
$hostName = Get-Cluster $clusterName.Name | Get-VMHost | Where {$_.State -ne "Maintenance"} | Sort CpuUsageMhz | Select -first 1

#List and Select the Datastore
$global:i=0
Get-VMHost $hostName | Get-Datastore | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name,FreeSpaceGB -OutVariable menu | format-table -AutoSize
$datastoreNum = Read-Host "Select the number of the Datastore"
$datastoreName = $menu | where {$_.Number -eq $datastoreNum}

#List and Select Portgroups
$global:i=0
Get-VMHost $hostName | Get-VirtualPortGroup | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name,VLanID -OutVariable menu | format-table -AutoSize
$portgroupNum = Read-Host "Select the number of the Portgroup"
$portgroupName = $menu | where {$_.Number -eq $portgroupNum}

#Prompt for and Define Variables
$vmName = Read-Host "Enter name of the new Virtual Machine"

#Check if the VM name is currently in use
$checkName = Get-VM $vmname -ErrorAction SilentlyContinue
If ($checkName.count -gt 0){Write-Host "A Virtual Machine with name $($vmname) is already in use. Exiting..." -foreground "Red"; break}ELSE{Write-Host "Virtual Machine name not in use. Continuing..." -foreground "Green"}

[int]$cpus = $null
$cpus = Read-Host "Enter the number of CPUs (1-16)"
[int]$ram = $null
$ram = Read-Host "Enter the amount of RAM in GB"
$ram *= 1024

#Clone the VM from template
Write-Host "Cloning new Virtual Machine from Template: $($templateName.Name)"
New-VM -Name $vmName -template $templateName.Name -OSCustomizationSpec $osSpecName.Name -VMHost $hostName -Datastore $datastore

#Modify the CPU and Memory values of the VM
Write-Host "Assigning $($vmName) to $($portgroupName.Name)..." -foreground "Green"
Get-VM $vmName | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $portgroupName.Name -Confirm:$false
Write-Host "Allocating $($cpus) CPUs and $($ram) GB of RAM to $($vmName)..." -foreground "Green"
Set-VM -vm $vmName -NumCpu $cpus -MemoryMB $ram -confirm:$false

#Power on VM and start customization
Write-Host "Powering on Virtual Machine..."
Start-VM -VM $vmName -Confirm:$false

