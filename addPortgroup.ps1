$name = Read-Host -Prompt "Enter the name of the new Portgroup (ex: Management Network)"
$vlanId = Read-Host -Prompt "Enter the VLAN Id number for the Portgroup (ex: 13)"
$virtualSwitch = Read-Host -Prompt "Enter the name of the Virtual Switch for Portgroup (ex: vSwitch1)"
$cluster = Read-Host -Prompt "Enter the name of the cluster for this Portgroup (ex: Cluster1)"

$newPortgroup = $xmlConfig.config.Portgroups.AppendChild($xmlConfig.CreateElement("Portgroup"));
$newPortgroup.SetAttribute("Name",$name)
$newvlanIdAttribute = $newPortgroup.AppendChild($xmlConfig.CreateElement("vlanId"))
$newvlanIdValue = $newvlanIdAttribute.AppendChild($xmlConfig.CreateTextNode($vlanId))
$newvirtualSwitchAttribute = $newPortgroup.AppendChild($xmlConfig.CreateElement("virtualSwitch"))
$newvirtualSwitchValue = $newvirtualSwitchAttribute.AppendChild($xmlConfig.CreateTextNode($virtualSwitch))
$newclusterAttribute = $newPortgroup.AppendChild($xmlConfig.CreateElement("cluster"))
$newclusterValue = $newclusterAttribute.AppendChild($xmlConfig.CreateTextNode($cluster))

$xmlConfig.Save($xmlFile)
