$SolutionPrefix = "ttvdsol"
$AzureSubscriptionName = "Microsoft Azure"
$ResourceGroupName = ($SolutionPrefix + "resg001")
$ResourceGroupLocation = "West Europe"
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/HighPerformance/highPerformanceDeployment.json"

$TemplateParameters = @{
    namePrefix = $SolutionPrefix
	storageAccountType = "Standard_LRS"
	vmCount = 1
	vmSize = "Standard_DS1_v2"
	vmDiskCount = 4
	osVersion = "2016"
	adminPassword = "PleaseSpecify"
	existingVirtualNetworkName = "ttvdsolvnet001"
	existingSubnetName = "ttvdsolsnet001"
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
