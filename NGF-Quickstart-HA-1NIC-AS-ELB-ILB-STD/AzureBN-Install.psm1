# Generic user choice menu
# Supply an object list and function creates numbered list of choices for user to select from
# Supply an optional secondary value field if the primary field isn't what is being selected

function UserChoice {
param($objMenuSource,$valSelectionField, $strPrompt, $valSecondaryField)
    $menu = @{}
    for ($i=1;$i -le $objMenuSource.count; $i++) {
        $menuItem = $objMenuSource[$i-1].$valSelectionField
        if ( $valSecondaryField ) {
            $menuItem = "{0,-30} : {1,-30}" -f $menuItem,$objMenuSource[$i-1].$valSecondaryField
        }
        $menu.Add($i,($menuItem))
        Write-Host("{0,2}) {1}" -f $i,$menuItem)
    }

    do {
        [int]$ans = Read-Host $strPrompt
        if ( $ans -gt $objMenuSource.count -or $ans -lt 1 ) {
            Write-Host("Invalid entry, please enter a number between 1 and {0}" -f $objMenuSource.count) -ForegroundColor DarkYellow
        }
    } while ($ans -lt 1 -or $ans -gt $objMenuSource.count )
    
    if ( $valSecondaryField ) {
         $selection = $objMenuSource[$ans-1].$valSecondaryField
    } else {
         $selection = $objMenuSource[$ans-1].$valSelectionField
    }

    $selection
}

# Check for Azure cmdlets
function verifyAzureCmdlets {
    $res = Get-Module PowerShellGet -list | Select-Object Name,Version,Path
    return $res
}

# Validate CIDR
function isCIDR {
    Param(
        #[ValidatePattern("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/(3[0-2]|[1-2][0-9]|[0-9]))$")]
        $inputData
        )
    if ( $inputData -match '^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/(3[0-2]|[1-2][0-9]|[0-9]))$' ) {
        return $true
    }
}

# Verbose print
function vPrint {
    Param($val)
    if ( $Verbose ) { Write-Host $val }
}

# Check for subscription and prompt for login if not found
function getSubs {
$mysubs = Get-AzureRmSubscription -ErrorAction SilentlyContinue
    if ( ! $mysubs ) {
        vPrint("No subs found, running Login-AzureRmAccount")
        Login-AzureRmAccount
        $mysubs = Get-AzureRmSubscription -ErrorAction SilentlyContinue
        if ( ! $mysubs ) {
            Write-Host "Failed to find subscription, exiting..." -ForegroundColor Red
            exit
        } else {
            vPrint("Found subs: " + $mysubs)
        }
    } else {
        vPrint("Subs found: " + $mysubs)
    }
    return $mysubs
}

# Install into new VNET
function installIntoNewVNet {
    $vnetName = Read-Host "Please enter new VNet name (<enter>=CGF-VNet)"
    if ( ! $vnetName )
    {
        $vnetName = 'CGF-VNet'
    }

    do {
        $vnetAddrSpace = Read-Host "Please enter new VNet address space (<enter>=172.16.136.0/20)"
        if ( ! $vnetAddrSpace ) {
            $vnetAddrSpace = '172.16.136.0/20'
        } else {
            $CIDROK = isCIDR($vnetAddrSpace)
            if ( ! $CIDROK  ) {
                Write-Host "Sorry, '$vnetAddrSpace' appears not to be a valid CIDR. Please try again." -ForegroundColor Yellow
                $vnetAddrSpace = ''
            }
        }
    } while ( ! $vnetAddrSpace )
    $vnetName,$vnetAddrSpace
}

# Install into existing VNET
function installIntoExistingVNet {
    Write-Host "Gathering VNet information..." -ForegroundColor Cyan
    $vnets = Get-AzureRmVirtualNetwork | Select-Object Name,@{n='AddrSpace'; e={$_.AddressSpace.AddressPrefixes}}
    Write-Host "`n`nAvailable Virtual Networks in this subscription:"
    $sel = UserChoice $vnets 'addrSpace' 'Please choose VNet for deployment' 'Name' 

    $sel
}

# Add a new resource group
function addNewRG {
    $rgName = Read-Host "Please enter new resource group name (<enter>=CloudGenFW-RG)"
    if ( ! $rgName ) {
        $rgName = 'CloudGenFW-RG'
    }

    $rgName
}

# Get existing resource group
function getExistingRG {
    Write-Host "Gathering resource group information..." -ForegroundColor Cyan
    $rgs = Get-AzureRmResourceGroup | Select-Object ResourceGroupName
    $sel = UserChoice $rgs 'ResourceGroupName' 'Please choose Resource Group for deployment'

    $sel
}

$vmTypes = @{'Standard_F1'     = @{ 'cores' = '1'; 'memory' = '2GB'};
             'Standard_F1s'    = @{ 'cores' = '1'; 'memory' = '2GB'};
             'Standard_DS1'    = @{ 'cores' = '1'; 'memory' = '3.5GB'};
             'Standard_DS1_v2' = @{ 'cores' = '1'; 'memory' = '3.5GB'};
             'Standard_F2'     = @{ 'cores' = '2'; 'memory' = '4GB'};
             'Standard_F2s'    = @{ 'cores' = '2'; 'memory' = '4GB'};
             'Standard_DS2'    = @{ 'cores' = '2'; 'memory' = '7GB'};
             'Standard_DS2_v2' = @{ 'cores' = '2'; 'memory' = '7GB'};
             'Standard_F4'     = @{ 'cores' = '4'; 'memory' = '8GB'};
             'Standard_F4s'    = @{ 'cores' = '4'; 'memory' = '8GB'};
             'Standard_DS3'    = @{ 'cores' = '4'; 'memory' = '14GB'};
             'Standard_DS3_v2' = @{ 'cores' = '4'; 'memory' = '14GB'};
             'Standard_F8'     = @{ 'cores' = '8'; 'memory' = '16GB'};
             'Standard_F8s'    = @{ 'cores' = '8'; 'memory' = '16GB'};
             'Standard_DS4'    = @{ 'cores' = '8'; 'memory' = '28GB'};
             'Standard_DS4_v2' = @{ 'cores' = '8'; 'memory' = '28GB'};
            }

$skuTypes = @{'hourly' = 'PAYG Hourly (Includes compute and license)';
              'byol'   = 'BYOL (Bring Your Own License) - request license token from barracuda.com/eval)';
              }

# Export it all
Export-ModuleMember -Variable '*'
Export-ModuleMember -Function '*'
