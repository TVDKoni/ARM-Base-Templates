$SolutionPrefix = "ttvdtrn"
$AzureSubscriptionName = "Microsoft Azure"
$ResourceGroupLocation = "West Europe"
$VpnGateway = "none"

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
    vpnGateway = $VpnGateway
}
$ResourceGroupName = ($SolutionPrefix + "resg001")
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/BaseInfrastructure/baseInfrastructureDeployment.json"

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
