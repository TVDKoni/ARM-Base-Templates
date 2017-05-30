$SolutionPrefix = "ttvdtrn"
$AzureSubscriptionName = "Microsoft Azure"
$ResourceGroupLocation = "westeurope"
$VirtualMachineSize = "Standard_DS12_v2"

$adminPasswordSec = Read-host "Admin and SQL password?" -AsSecureString
$adminPasswordBSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminPasswordSec)
$adminPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($adminPasswordBSTR)
$numVmcopies = Read-host "Number of copies to be created?"

$SourceResourceGroupName = ($SolutionPrefix + "resg001")
$DestResourceGroupName = ($SolutionPrefix + "resg002")
$TemplateParameters = @{
	numberOfVms = [convert]::ToInt32($numVmcopies)
	destResourceGroupName = $DestResourceGroupName
	sourceResourceGroupName = $SourceResourceGroupName
    adminPassword = $adminPassword
    sqlAuthenticationPassword = $adminPassword
    location = $ResourceGroupLocation
    virtualMachineName = $SolutionPrefix + "vser"
    adminUsername = $SolutionPrefix + "admin"
    virtualNetworkName = $SolutionPrefix + "vnet001"
    networkInterfaceName = $SolutionPrefix + "vnic"
    storageAccountName = $SolutionPrefix + "stac001"
    diagnosticsStorageAccountName = $SolutionPrefix + "stac002"
    subnetName = $SolutionPrefix + "snet001managementServices"
    publicIpAddressName = $SolutionPrefix + "vipi"
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
    osDiskUri = "LaterConfigured"
    dataDiskUri = "LaterConfigured"
}
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/SqlServerClone/sqlServerCloneDeployment.json"

function New-TemporaryDirectory
{
    $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    while(Test-Path $path) {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
    }
    New-Item -ItemType Directory -Path $path
}

Write-Host "Please prepare first the source image like described in:"
Write-Host "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/SqlServerClone/PrepareVmImage.pdf"
Write-Host '  - Run command: & "$Env:SystemRoot\system32\sysprep\sysprep.exe" /generalize /oobe /shutdown'
Write-Host '  - Wait until the vm has stopped state'
pause

Write-Host "Login to azure account"
Login-AzureRmAccount

Write-Host "Selecting subscription '$($AzureSubscriptionName)'"
$subscription = Get-AzureRmSubscription –SubscriptionName $AzureSubscriptionName #add -TenantId if subscription name is not unique
Select-AzureRmSubscription -SubscriptionId $subscription.SubscriptionId | Out-String | Write-Verbose

Write-Host "Getting resource group '$($DestResourceGroupName)'"
if (-not (Get-AzureRmResourceGroup -Name $DestResourceGroupName -Location $ResourceGroupLocation -ErrorAction SilentlyContinue)) {
	Write-Host "Resource group does not exists. Creating it."
	New-AzureRmResourceGroup -Name $DestResourceGroupName -Location $ResourceGroupLocation | Out-String | Write-Verbose
}

Write-Host "Preparing the source vm '$($SolutionPrefix)vser001'"
Stop-AzureRmVM -ResourceGroupName $SourceResourceGroupName -Name ($SolutionPrefix + "vser001") -Force
Set-AzureRmVM -ResourceGroupName $SourceResourceGroupName -Name ($SolutionPrefix + "vser001") -Generalized  

$tempdir = New-TemporaryDirectory
$tempfile = $tempdir.FullName + "\Template.json"
Write-Host "Saving the source vm '$($SolutionPrefix)vser001' as template to $($tempfile)"
Save-AzureRmVMImage -ResourceGroupName $SourceResourceGroupName -VMName ($SolutionPrefix + "vser001") -DestinationContainerName 'templates' -VHDNamePrefix 'template' -Path $tempfile

Write-Host "Reading template"
$template = (Get-Content $tempfile) -join "`n" | ConvertFrom-Json
$storageProfile = $template.resources[0].properties.storageProfile
$TemplateParameters.osDiskUri = $storageProfile.osDisk.image.uri
$TemplateParameters.dataDiskUri = $storageProfile.dataDisks[0].image.uri

Write-Host "Deploying template"
$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $DestResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

Write-Host "Template outputs:"
foreach($key in $deployment.Outputs.Keys)
{
    Write-Host ("  " + $key + ": " + $deployment.Outputs[$key].Value)
}

Write-Host "Done"
pause
