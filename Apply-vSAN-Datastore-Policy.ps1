#Define variables (Replace Cluster Name, vSAN Datastore Name, and vSAN Storage Policy)
$clusterName = "Cluster Name"
$vSanDatastore = "vSAN Datastore Name"
$vSanStoragePolicy = "Virtual SAN Default Storage Policy"

#Get all VMs in $clusterName on $vSanDatastore without $vSanStoragePolicy applied and apply $vSanStoragePolicy
$vSanCluster = Get-cluster $clusterName | 
Get-VM |?{($_.extensiondata.config.datastoreurl|%{$_.name}) -contains $vSanDatastore} |
Get-SpbmEntityConfiguration | Where-Object {$_.storagepolicy -contains $vSanStoragePolicy -or $_.compliancestatus -notlike "Compliant"}
foreach ($vm in $vSanCluster)
{
Get-VM $vm | Set-SpbmEntityConfiguration -StoragePolicy $vSanStoragePolicy
}
