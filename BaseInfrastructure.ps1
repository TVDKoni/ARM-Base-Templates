$SolutionPrefix = "ttvdsol"
$AzureSubscriptionName = "Microsoft Azure"
$ResourceGroupName = ($SolutionPrefix + "resg001")
$ResourceGroupLocation = "West Europe"
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/BaseInfrastructure/baseInfrastructureDeployment.json"

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
$ResourceGroup = @{
    Name = $ResourceGroupName
    Location = $ResourceGroupLocation
    Force = $true
}

Login-AzureRmAccount
Get-AzureRmSubscription –SubscriptionName $AzureSubscriptionName | Select-AzureRmSubscription
New-AzureRmResourceGroup @ResourceGroup
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

pause
