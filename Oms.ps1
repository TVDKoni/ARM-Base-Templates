$WorkspaceName = "BFH90INFOMS001"
$AutomationName = "BFH90INFAMA002"
$WorkspacePlan = "Free"
$AzureSubscriptionName = "BFH90INF"
$ResourceGroupLocation = "westeurope"
$ResourceGroupName = "BFH90INFRSG003"

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

Write-Host "Deploying oms template"
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/Oms/omsWorkspace.json"
$TemplateParameters = @{
    name = $WorkspaceName
    region = $ResourceGroupLocation
    plan = $WorkspacePlan
}
$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

Write-Host "Deploying automation template"
$TemplateFileUri = "https://raw.githubusercontent.com/TVDKoni/ARM-Base-Templates/master/Oms/omsAutomationAccount.json"
$TemplateParameters = @{
    name = $AutomationName
    region = $ResourceGroupLocation
    plan = $WorkspacePlan
}
$deployment = New-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroupName -TemplateUri $TemplateFileUri -TemplateParameterObject $TemplateParameters -Verbose

Write-Host "Done"
pause
