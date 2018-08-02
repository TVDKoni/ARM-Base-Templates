$WorkspaceName = "BFH90INFOMS001"
$WorkspaceResourceGroupName = "BFH90INFRSG003"
$WorkspaceResourceGroupLocation = "westeurope"
$WorkspaceSubscription = "9c7b5314-4996-4f12-833d-bdcb4177095a"

$VmName = "BFH20ABASRV001"
$VmResourceGroupName = "BFH20ABARSG001"
$VmSubscription = "ffe760fc-5986-4929-b007-fe3479191185"

Write-Host "Login to azure account"
Login-AzureRmAccount

Write-Host "Selecting subscription '$($VmSubscription)'"
$subscription = Get-AzureRmSubscription -SubscriptionId $VmSubscription
Select-AzureRmSubscription -SubscriptionId $subscription.SubscriptionId | Out-String | Write-Verbose

Write-Host "Getting resource group '$($WorkspaceResourceGroupName)'"
if (-not (Get-AzureRmResourceGroup -Name $WorkspaceResourceGroupName -Location $WorkspaceResourceGroupLocation -ErrorAction SilentlyContinue)) {
	Write-Host "Resource group does not exists. Creating it."
	New-AzureRmResourceGroup -Name $WorkspaceResourceGroupName -Location $WorkspaceResourceGroupLocation | Out-String | Write-Verbose
}

Write-Host "Deploying oms onboard vm template"
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/Oms/omsOnboardVm.json"
$TemplateParameters = @{
    vmName = $VmName
    vmResourceGroupName = $VmResourceGroupName
    vmSubscription = $VmSubscription
    workspaceName = $WorkspaceName
    workspaceResourceGroupName = $WorkspaceResourceGroupName
    workspaceSubscription = $WorkspaceSubscription
}
$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $VmResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

Write-Host "Done"
pause
