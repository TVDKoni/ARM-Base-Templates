$SolutionPrefix = "ttvdtrn"
$AzureSubscriptionName = "Microsoft Azure"
$ResourceGroupName = ($SolutionPrefix + "resg002")

Write-Host "Login to azure account"
Login-AzureRmAccount

Write-Host "Selecting subscription '$($AzureSubscriptionName)'"
$subscription = Get-AzureRmSubscription -SubscriptionName $AzureSubscriptionName #add -TenantId if subscription name is not unique
Select-AzureRmSubscription -SubscriptionId $subscription.SubscriptionId | Out-String | Write-Verbose

Write-Host "Getting resource group '$($ResourceGroupName)'"
if (-not (Get-AzureRmResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
	Write-Host "Resource group does not exists. Exiting"
	Return
}

foreach($vm in (Get-AzureRmVM -ResourceGroupName $ResourceGroupName))
{
    Write-Host "Stopping: $($vm.Name)"
    Stop-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $vm.Name -Force
    Write-Host ""
}
