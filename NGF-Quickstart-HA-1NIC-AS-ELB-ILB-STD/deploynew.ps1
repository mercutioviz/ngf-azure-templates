#################################################################
#
#  AZURE DEPLOY CGF
#  by
#  Michael S Collins
#  mcollins@barracuda.com
#
#  Deploys 1 or 2 CGFs depending on user choice.
#   User may choose new or existing infrastructure
#
#  NO WARRANTY OR GUARANTEE OF ANY KIND, EXPRESS OR IMPLIED
#
#################################################################

### Specify parameters/flags
Param(
    [switch]$SkipAzure = $false,
    [switch]$Verbose   = $false,
    [switch]$Help      = $false,
    [int]$var1         = '1',
    [String]$var2      = 'myValue'
)

Import-Module AzureBN-Install

# Check for help first before doing anything else
if ( $Help ) {
    Write-Host "Help for program XXXX"
    exit
}
# Main program area
if ( ! $SkipAzure ) {
    vPrint("Checking for Azure cmdlets...")
    $azurecmdlets = verifyAzureCmdlets
    if ( ! $azurecmdlets ) {
        Write-Host "Azure cmdlets not found on this system" -ForegroundColor Red
        exit
    } else {
        vPrint("Found Azure cmdlets")
    }
} else {
    vPrint "Skipping Azure cmdlets check"
}

## Global variables used in building template
$vnets = ''
$vnetName = ''
$vnetAddrSpace = ''
$rgName = ''
$fwsubnetName = ''
$fwsubnetCIDR = ''
$privateSubnet1Name = ''
$privateSubnet1CIDR = ''
$privateSubnet2Name = ''
$privateSubnet1CIDR = ''
$vmSize = ''
$adminPassword = ''
$fw1VMName = ''
$fw2VMName = ''
$fw1IPAddr = ''
$fw2IPAddr = ''
$imageSKU = ''

Write-Host "Barracuda CloudGen Firewall Installer Script. Press <enter> to continue, any other key to quit" -ForegroundColor Cyan
$sel = Read-Host -Prompt "`nEnter selection "
if ( $sel ) { 
    Write-Host "Exiting at user direction..." 
    exit
}

Write-Host "`nCollecting subscription information..." -ForegroundColor Cyan
$mysubs = getSubs
$sub = ''
if ( $mysubs.count -eq '1' ) {
    Write-Host ('For account {0} we will use SubscriptionId {1}' -f $mysub.Name, $mysub.Id)
} else {
    # Select a subscription to use
    $sub = UserChoice $mysubs 'Id' 'Please select subscription for this operation' 'Name'
}

Write-Host ("`nGathering stats for subscription ID: {0}" -f $sub) -ForegroundColor Cyan

# New or existing VNet
do {
    $sel = Read-Host "`n(N)ew or (E)xisting VNet? (N/E/Q=quit/<enter>=New)"
    if ( ! $sel -or $sel -imatch '^N' ) {
        $installType = 'New'
    } elseif ( $sel -imatch '^E' ) {
        $installType = 'Existing'
    } elseif ( $sel -imatch '^Q' ) {
        Write-Host "Exiting program at user request..." -ForegroundColor Yellow
        exit
    } else {
        Write-Host "Invalid selection, please try again" -ForegroundColor DarkYellow
    }
} while ( ! $installType )

if ( $installType -eq 'New' ) {
    $res = installIntoNewVNet
    $vnetName = $res[0]
    $vnetAddrSpace = $res[1]
    Write-Host "Will create new VNet $vnetName with address space of $vnetAddrSpace" -ForegroundColor Cyan
} else {
    $vnetName = installIntoExistingVNet
    $vnetAddrSpace = $vnets.Where({$_.Name -eq $vnetName}).AddrSpace
    Write-Host "Will use existing VNet $vnetName with address space of $vnetAddrSpace" -ForegroundColor Cyan
}

# New or existing resource group
do {
    $sel = Read-Host "`n(N)ew or (E)xisting Resource Group? (N/E/Q=quit/<enter>=New)"
    if ( ! $sel -or $sel -imatch '^N' ) {
        $rgType = 'New'
    } elseif ( $sel -imatch '^E' ) {
        $rgType = 'Existing'
    } elseif ( $sel -imatch '^Q' ) {
        Write-Host "Exiting program at user request..." -ForegroundColor Yellow
        exit
    } else {
        Write-Host "Invalid selection, please try again" -ForegroundColor DarkYellow
    }
} while ( ! $rgType )

if ( $rgType -eq 'New' ) {
    $rgName = addNewRG
    Write-Host "Will create new resource group $rgName" -ForegroundColor Cyan
} else {
    $rgName = getExistingRG
    Write-Host "Using existing resource group $rgName" -ForegroundColor Cyan
}


# How many to install
do {
    Write-Host "`nInstallation Type"
    $sel = Read-Host "Single FW or High Availablity (HA) pair? (s/h/Q=Quit/<enter>=HA)"
    if ( ! $sel -or $sel -imatch '^H' ) {
        $numFirewalls = '2'
    } elseif ( $sel -imatch '^S' ) {
        $numFirewalls = '1'
    } elseif ( $sel -imatch '^Q' ) {
        Write-Host "Exiting program at user request..." -ForegroundColor Yellow
        exit
    } else {
        Write-Host "Invalid selection, please try again" -ForegroundColor DarkYellow
    }
} while ( ! $numFirewalls )

Write-Host
Write-Host "Installation Parameters"
Write-Host "======================="
Write-Host "VNet: $vnetName ($vnetAddrSpace)"
Write-Host "  RG: $rgName"
Write-Host " #FW: $numFirewalls"


