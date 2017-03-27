$SolutionPrefix = "ttvdsol"
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
New-AzureRmResourceGroup @ResourceGroup
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

pause
