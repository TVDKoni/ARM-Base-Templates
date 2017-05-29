$SolutionPrefix = "ttvdtrn"
$AzureSubscriptionName = "Microsoft Azure"
$ResourceGroupLocation = "westeurope"
$VirtualMachineSize = "Standard_DS12_v2"

$adminPasswordSec = Read-host "Admin and SQL password?" -AsSecureString
$adminPasswordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPasswordSec)
$adminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($adminPasswordBSTR)

$ResourceGroupName = ($SolutionPrefix + "resg001")
$TemplateParameters = @{
	destResourceGroupName = $ResourceGroupName
    adminPassword = $adminPassword
    sqlAuthenticationPassword = $adminPassword
    location = $ResourceGroupLocation
    virtualMachineName = $SolutionPrefix + "vser001"
    adminUsername = $SolutionPrefix + "admin"
    virtualNetworkName = $SolutionPrefix + "vnet001"
    networkInterfaceName = $SolutionPrefix + "vser001nic"
    storageAccountName = $SolutionPrefix + "stac001"
    diagnosticsStorageAccountName = $SolutionPrefix + "stac002"
    subnetName = $SolutionPrefix + "snet001managementServices"
    publicIpAddressName = $SolutionPrefix + "vser001pip"
    sqlAuthenticationLogin = $SolutionPrefix + "admin"
    virtualMachineSize = $VirtualMachineSize
    storageAccountType = "Premium_LRS"
    diagnosticsStorageAccountType = "Standard_LRS"
    diagnosticsStorageAccountId = "Microsoft.Storage/storageAccounts/" + $SolutionPrefix + "stac002"
    publicIpAddressType = "Dynamic"
    sqlConnectivityType = "Private"
    sqlPortNumber = 1433
    sqlStorageDisksCount = 1
    sqlStorageWorkloadType = "GENERAL"
    sqlStorageDisksConfigurationType = "NEW"
    sqlStorageStartingDeviceId = 2
    sqlStorageDeploymentToken = 16335
    sqlAutopatchingDayOfWeek = "Sunday"
    sqlAutopatchingStartHour = "2"
    sqlAutopatchingWindowDuration = "60"
    rServicesEnabled = "true"
}
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/SqlServer/sqlServerDeployment.json"

Write-Host "Login to azure account"
Login-AzureRmAccount

Write-Host "Selecting subscription '$($AzureSubscriptionName)'"
$subscription = Get-AzureRmSubscription –SubscriptionName $AzureSubscriptionName #add -TenantId if subscription name is not unique
Select-AzureRmSubscription -SubscriptionId $subscription.SubscriptionId | Out-String | Write-Verbose

Write-Host "Getting resource group '$($ResourceGroupName)'"
if (-not (Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation -ErrorAction SilentlyContinue)) {
	Write-Host "Resource group does not exists. Creating it."
	New-AzureRmResourceGroup -Name $ResourceGroupName -Location $ResourceGroupLocation | Out-String | Write-Verbose
}

Write-Host "Deploying template"
$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

Write-Host "Template outputs:"
foreach($key in $deployment.Outputs.Keys)
{
    Write-Host ("  " + $key + ": " + $output[$key].Value)
}

Write-Host "Done"
pause
