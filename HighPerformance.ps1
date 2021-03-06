$SolutionPrefix = "ttvdsol"
$AzureSubscriptionName = "Microsoft Azure"
$ResourceGroupLocation = "westeurope"

<#
	Attention: 
		- LRS is the most performing storage type! Premium_LRS is on SSD.
		- Max number of disks with max size is the most performing configuration
		- Admin user name is fixed: sysadmin
		- Please increase vmStartIndex if you run this script multiple times in same resource group
		
	Available disk sizes per vmSize: 
		vmSize              cores  memory  Max vmDiskCount
		------              -----  ------  ---------------
		Standard_DS1_v2     1      3.5GB   2
		Standard_DS2_v2     2      7GB     4
		Standard_DS3_v2     4      14GB    8
		Standard_DS4_v2     8      28GB    16
		Standard_DS5_v2     16     56GB    32
		Standard_DS11_v2    2      14GB    4
		Standard_DS12_v2    4      28GB    8
		Standard_DS13_v2    8      56GB    16
		Standard_DS14_v2    16     112GB   32
		Standard_DS15_v2    20     140GB   40
		Standard_GS1_v2     2      28GB    4
		Standard_GS2_v2     4      56GB    8
		Standard_GS3_v2     8      112GB   16
		Standard_GS4_v2     16     224GB   32
#>

$TemplateParameters = @{
    namePrefix = $SolutionPrefix
	storageAccountType = "Premium_LRS"
	vmCount = 1
	vmSize = "Standard_DS5_v2"
	vmDiskCount = 2
	vmDiskSize = 1023
	vmStartIndex = 1
	osVersion = "2016"
	adminPassword = "1Please-Specify3"
	existingVirtualNetworkName = ($SolutionPrefix + "vnet001")
	existingSubnetName = ($SolutionPrefix + "snet001managementServices")
}
$ResourceGroupName = ($SolutionPrefix + "resg001")
$ResourceGroup = @{
    Name = $ResourceGroupName
    Location = $ResourceGroupLocation
    Force = $true
}
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/HighPerformance/highPerformanceDeployment.json"

Login-AzureRmAccount
Get-AzureRmSubscription –SubscriptionName $AzureSubscriptionName | Select-AzureRmSubscription
New-AzureRmResourceGroup @ResourceGroup
New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

pause
