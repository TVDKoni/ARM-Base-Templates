$SolutionPrefix = "ttvdtrn"
$AzureSubscriptionName = "Microsoft Azure"
$ResourceGroupLocation = "West Europe"

<#
	Attention: Provisioning a vpn gateway can take up to 20 minutes!
	Available vpnGateway: 
		- none
		- basic
		- standard
		- highperformace
#>

$TemplateParameters = @{
    namePrefix = $SolutionPrefix
    vpnGateway = "basic"
}
$ResourceGroupName = ($SolutionPrefix + "resg001")
$ResourceGroup = @{
    Name = $ResourceGroupName
    Location = $ResourceGroupLocation
    Force = $true
}
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/BaseInfrastructure/baseInfrastructureDeployment.json"

Login-AzureRmAccount
Get-AzureRmSubscription –SubscriptionName $AzureSubscriptionName | Select-AzureRmSubscription


Write-Host "Selecting subscription as default"
$subscription = Get-AzureRmSubscription –SubscriptionName $AzureSubscriptionName #add -TenantId if subscription name is not unique
Select-AzureRmSubscription -SubscriptionId $subscription.SubscriptionId



Write-Host "Creating resource group '$($resourceGroupName)' to hold the automation account, key vault, and template storage account."

if (-not (Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -ErrorAction SilentlyContinue)) {
	New-AzureRmResourceGroup -Name $resourceGroupName -Location $location  | Out-String | Write-Verbose
}



New-AzureRmResourceGroup @ResourceGroup
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

pause
