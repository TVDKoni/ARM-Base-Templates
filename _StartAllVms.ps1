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
    Write-Host "Starting: $($vm.Name)"
    Start-AzureRmVM -ResourceGroupName $ResourceGroupName -Name $vm.Name
    $pipName = (Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName | Where-Object {($_.VirtualMachine.id).Split("/")[-1] -like $vm.Name}).IpConfigurations.PublicIpAddress.Id.Split("/")[-1]
    $pip = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $pipName).IpAddress
    $pdns = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $pipName).DnsSettings.Fqdn
    Write-Host "Public IP: $pip"
    Write-Host "DNS Name : $pdns"
    Write-Host ""
}
