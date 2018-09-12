Write-Host "
##############################################################################################################
#  _                         
# |_) _  __ __ _  _     _| _ 
# |_)(_| |  | (_|(_ |_|(_|(_|
#
# Script to deploy the Barracuda CloudGen Firewall into Microsoft Azure. This is a quickstart script which 
# also creates the network infrastructure needed for it.
#
##############################################################################################################

"

$location = Read-Host -Prompt 'Enter location (e.g. eastus2): '
if([string]::IsNullOrEmpty($location)) {            
  $location = "eastus2"
}
Write-Host "Deployment in $location location ..."
