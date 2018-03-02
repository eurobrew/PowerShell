#Connect to vCenter
Connect-viserver vcenter01

#List the Cluster to be remediated
$global:i=0
Get-Cluster | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$clusterNum = Read-Host "Select the number of the Cluster to be patched"
$clusterName = $menu | where {$_.Number -eq $clusterNum}

#List any "Must Run" DRS rules
$drsRules = Get-Cluster $($clusterName.Name) | Get-DrsVMHostRule | Where {$_.Type -eq "MustRunOn"} | Where {$_.Enabled -eq $True}
IF ($drsRules.Count -gt "0"){Write-Host "The following rules may prevent a host from entering Maintenance mode:" -foreground "Yellow"; $drsRules.Name; $disableRules = Read-Host "Press Y to disable these rules. Anything else to continue";
IF ($disableRules -eq "Y"){Write-Host "Disabling DRS Rules..." -foreground "Yellow";
foreach ($name in $drsRules){Set-DrsVMHostRule -rule $name -enabled:$false}} ELSE {Write-Host "Skipping disabling of DRS Rules. Continuing..." -foreground "Yellow"}} ELSE {Write-Host "No "Must Run" Rules in $($clusterName.Name). Continuing..." -foreground "Yellow"}

#Scan for VMs with Active Tools Installations
#$vmtoolsinstaller = get-view -viewtype virtualmachine -property 'name' -Filter @{'Runtime.ToolsInstallerMounted'='True'}
#IF ($vmtoolsinstaller.count -gt "0"){Write-Host "There are currently VMs with active tools installations. These may prevent a host from entering Maintenace mode." -foreground "Yellow"; $value = Read-Host "Press "Y" to end VM Tools installations. Anything else to continue"} ELSE {Write-Host "Leaving VM Tools installations active. Continuing..."}
#$vmtoolsinstaller.count
#$vmtoolsinstaller.Name

#List and Select the baseline to be attached to the cluster
$global:i=0
Get-Baseline | Select Name | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name -OutVariable menu | format-table -AutoSize
$baselineNum = Read-Host "Select the number of the Baseline to be attached"
$baselineName = $menu | where {$_.Number -eq $baselineNum}
Write-Host "Attaching $($baselineName.Name) Baseline to $($clusterName.Name)..." -Foreground "Yellow"
$baseline = Get-Baseline $baselineName.Name
Attach-Baseline -Baseline $baseline -Entity $clusterName.Name

#Start-Sleep 10

:HostLoop
DO
{
DO
{
#List the Hosts in the cluster to be remediated
$global:i=0
Get-Cluster $clusterName.Name | Get-VMhost | Sort Name | Select @{Name="Number";Expression={$global:i++;$global:i}},Name,Build -OutVariable menu | format-table -AutoSize
$hostNum = Read-Host "Select the number of the Host to be patched"
$hostName = $menu | where {$_.Number -eq $hostNum}

Start-Sleep 5

#Scan the selected host
Write-Host "Scanning $($hostName.Name) patch inventory..." -foreground "Yellow"
Scan-Inventory -Entity $hostName.Name

#Start-Sleep 7

#Scan for VMs with Tools Installer Mounted
$vmtools = Get-VMHost $hostName.Name | Get-VM | Where {$_.ExtensionData.RunTime.ToolsInstallerMounted -eq "True"} | Get-View
IF ($vmtools.Count -gt "0"){Write-Host "The following VMs on $($hostName.Name) have VMTools Installer Mounted:";
$vmtools.Name;
$unmountTools = Read-Host "Press "Y" to unmount VMTools and continue. Anything else to skip VMTools unmounting";
IF ($unmountTools -eq "Y") {Write-Host "Unmounting VMTools on VMs..." -foreground "Yellow"; foreach ($vm in $vmtools) {$vm.UnmountToolsInstaller()}}ELSE{Write-Host "Skipping VMTools unmounting..." -foreground "Yellow"}}ELSE{Write-Host "No VMs found with VMTools Installer mounted. Continuing..." -foreground "Yellow"}

Start-Sleep 10

#Scan for VMs with ISOs mounted
$mountedCDdrives = Get-VMHost $hostName.Name | Get-VM | Where { $_ | Get-CdDrive | Where { $_.ConnectionState.Connected -eq "True" } }
IF ($mountedCDdrives.Count -gt "0"){Write-Host "The following VMs on $($hostName.Name) have mounted CD Drives:";
$mountedCDdrives.Name;
$unmountDrives = Read-Host "Press "Y" to unmount these ISOs and continue. Anything else to skip ISO unmounting";
IF ($unmountDrives -eq "Y") {Write-Host "Unmounting ISOs on VMs..." -foreground "Yellow"; foreach ($vm in $mountedCDdrives) {Get-VM $vm | Get-CDDrive | Set-CDDrive -NoMedia -Confirm:$False}}ELSE{Write-Host "Skipping ISO unmounting..." -foreground "Yellow"}}ELSE{Write-Host "No VMs found with ISOs mounted. Continuing..." -foreground "Yellow"}

#Retrieve Compliance status for host
Write-Host "Scanning $($hostName.Name) for patch compliance..." -foreground "Yellow"
$compliance = Get-Compliance $hostName.Name 
IF ($compliance.Status -eq "Compliant"){Write-Host "No available patches for $($hostName.Name). Choose a different host" -foreground "Red"}ELSE{Write-Host "Host is out of date" -foreground "Yellow"}}
UNTIL ($compliance.Status -ne "Compliant")

Read-Host "Press Enter to place $($hostName.Name) in maintenance mode"

Start-Sleep 10

#Place select host in Maintenance mode
Write-Host "Enabling Maintenance mode for $($hostName.Name). This may take awhile.." -foreground "Yellow"
Set-VMHost $hostName.Name -State "Maintenance"
		
#Stage Patches to host
Write-Host "Staging patches to $($hostName.Name)..." -foreground "Yellow"
Stage-Patch -Entity $hostName.Name -baseline $baseline

#Remediate patches on host
Write-Host "Remediating patches on $($hostName.Name). Host will reboot when complete" -foreground "Yellow"
Remediate-Inventory -Entity $hostName.Name -Baseline $baseline -HostFailureAction Retry -HostNumberofRetries 2 -HostRetryDelaySeconds 120 -HostDisableMediaDevices $true -ClusterDisableDistributedPowerManagement $true -confirm:$false

Start-Sleep 20

#List current build status
Get-Cluster $clusterName.Name | Get-VMhost | Select Name,Build | Sort Name | format-table -autosize
Write-Host "Exiting Maintenance mode for Host $($hostName.Name)..." -foreground "Yellow"
Get-VMHost $hostName.Name | Set-VMHost -State Connected
$answer = Read-Host "Host patched. Press "1" to re-run the script. Anything else to exit"
}
UNTIL ($answer -ne "1")