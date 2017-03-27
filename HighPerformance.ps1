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
	vmDiskCount = 2
	vmStartIndex = 1
	osVersion = "2016"
	adminPassword = "1Please-Specify3"
	existingVirtualNetworkName = "ttvdsolvnet001"
	existingSubnetName = "ttvdsolsnet001managementServices"
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
