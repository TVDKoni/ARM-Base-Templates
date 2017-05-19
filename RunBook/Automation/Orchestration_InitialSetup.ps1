#https://gist.github.com/davoodharun/7afe8666f5bbe087ab0b2ee7846b683a
 
#requires -RunAsAdministrator
#requires -Modules AzureRM

<#
.Description
Script needs to be run with elevated priveleges, as it interacts with the local file system (for generation of a certificate)
Executes the initial setup script, creating a dedicated resource group, storage account, and azure automation account.
Optionally uploads arm templtes and ps runbooks to created storage account (if path specified)
Optionally publishes all ps runbooks in specified directory to azure automation account created by the process.

.Example
Login-AzureRmAccount

$adminPassword = Read-host "Admin password to store in keyvault?"
$serverPrincipalCertPassword = New-SWRandomPassword -MinPasswordLength 20 -MaxPasswordLength 32 -Count 1

.\Orchestration_InitialSetup.ps1 `
    -location = "westeurope" `
    -subscriptionName "Microsoft Azure Enterprise" `
    -resourceGroupName "pdslivegresg002" `
    -storageAccountName "pdslivegstac002" `
    -automationAccountName "pdslivegamac002" `
    -keyVaultName "pdslivegamac002" `
    -adminPassword $adminPassword `
    -serverPrincipalCertPassword $serverPrincipalCertPassword `
    -armtemplatesLocalDir "..\Templates" `
    -scriptsLocalDir "..\Scripts" `
    -psrunbooksLocalDir "..\Runbooks" `
    -publishAutomationRunbooks $true `
    -verbose

#>
[cmdletbinding()]
Param(
	[string]$location = "USGov Virginia",
	[Parameter(Mandatory=$true)]
	[string]$subscriptionName,
	[Parameter(Mandatory=$true)]
	[string]$resourceGroupName,
	[Parameter(Mandatory=$true)]
	[ValidateLength(3, 24)]
	[ValidateScript({ if ($PSItem -cmatch '^[a-z0-9]*$') {$true} else { Throw "Must only contain lowercase and number"}}) ]
	[string]$storageAccountName,
	[string]$armtemplatesLocalDir,
	[string]$scriptsLocalDir,
	[string]$psrunbooksLocalDir,
	[string]$automationAccountName,
	[ValidateLength(3, 24)]
	[string]$keyVaultName,
	[string]$adminPassword,
	[string]$sqlPassword,
	[Parameter(Mandatory=$true)]
	[SecureString]$serverPrincipalCertPassword,
	[bool]$publishAutomationRunbooks = $true
)
$errorActionPreference = 'stop'
$adminPasswordAsSecureString = ConvertTo-SecureString $adminPassword -AsPlainText -Force
$sqlPasswordAsSecureString = ConvertTo-SecureString $sqlPassword -AsPlainText -Force

Write-Host "Selecting subscription as default"
$subscription = Get-AzureRmSubscription –SubscriptionName $subscriptionName #add -TenantId if subscription name is not unique
$subscription | Select-AzureRmSubscription

Write-Host "Creating resource group '$($resourceGroupName)' to hold the automation account, key vault, and template storage account."

if (-not (Get-AzureRmResourceGroup -Name $resourceGroupName -Location $location -ErrorAction SilentlyContinue)) {
	New-AzureRmResourceGroup -Name $resourceGroupName -Location $location  | Out-String | Write-Verbose
}

Write-Host "Create storage account '$($storageAccountName)' (this takes a while sometimes)"
if (-not (Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue )) {
	New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $location -SkuName Standard_LRS  | Out-String | Write-Verbose
}

Write-Host "Create automation account '$($automationAccountName)' to host deployment runbooks."
if (-not (Get-AzureRmAutomationAccount -ResourceGroupName $resourceGroupName -Name $automationAccountName -ErrorAction SilentlyContinue)) {
	New-AzureRmAutomationAccount -ResourceGroupName $resourceGroupName -Name $automationAccountName -Location $location -Plan Free  | Out-String | Write-Verbose

    Write-Host "Create automation credentials."
    $adminCredential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList "$($resourceGroupName)AdminPassword", $adminPasswordAsSecureString
    New-AzureRmAutomationCredential -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "$($resourceGroupName)AdminPassword" -Value $adminCredential
    $sqlCredential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList "$($resourceGroupName)SqlPassword", $sqlPasswordAsSecureString
    New-AzureRmAutomationCredential -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Name "$($resourceGroupName)SqlPassword" -Value $sqlCredential
}

Write-Host "Create a keyVault '$($keyVaultName)' to store the service principal ids, key, certificate"
if (-not (Get-AzureRMKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue )) {
	New-AzureRMKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -EnabledForTemplateDeployment -Location $location | Out-String | Write-Verbose
    $newKV = Get-AzureRMKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    While ($newKV -eq $null)
    {
        sleep 10
        $newKV = Get-AzureRMKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
    }
    Write-Host "  Adding key: AdminPassword"
	$key = Add-AzureKeyVaultKey -VaultName $keyVaultName -Name "$($resourceGroupName)AdminPassword" -Destination 'Software'
	$adminSecret = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "$($resourceGroupName)AdminPassword" -SecretValue $adminPasswordAsSecureString

    Write-Host "  Adding key: SqlPassword"
	$key = Add-AzureKeyVaultKey -VaultName $keyVaultName -Name "$($resourceGroupName)SqlPassword" -Destination 'Software'
	$sqlSecret = Set-AzureKeyVaultSecret -VaultName $keyVaultName -Name "$($resourceGroupName)SqlPassword" -SecretValue $sqlPasswordAsSecureString
}

	& ".\Create-AzureServicePrincipalForServerAutomation.ps1" `
	    -SubscriptionId $subscription.SubscriptionId `
	    -ResourceGroup $resourceGroupName `
	    -AutomationAccountName $automationAccountName `
	    -ApplicationDisplayName "$($automationAccountName)RunAs" `
	    -certPassword $serverPrincipalCertPassword `
	    -backupCertVaultName $keyVaultName

	Write-Output "New service principal created for server auth - $($automationAccountName)RunAs."
    $RunAsApplication = Get-AzureRmADApplication -DisplayNameStartWith "$($automationAccountName)RunAs" -ErrorAction SilentlyContinue
    Set-AzureRmKeyVaultAccessPolicy -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -ServicePrincipalName $RunAsApplication.ApplicationId -PermissionsToKeys all -PermissionsToSecrets all

	& ".\Create-AzureServicePrincipalForClient.ps1" `
	    -SubscriptionId $subscription.SubscriptionId `
	    -ApplicationDisplayName "$($automationAccountName)Client" `
	    -backupKeyVaultName $keyVaultName `
	    -adminPassword $adminPassword

	Write-Output "New service principal created for client auth - $($automationAccountName)Client."
    $ClientApplication = Get-AzureRmADApplication -DisplayNameStartWith "$($automationAccountName)Client"
    Set-AzureRmKeyVaultAccessPolicy -ResourceGroupName $resourceGroupName -VaultName $keyVaultName -ServicePrincipalName $ClientApplication.ApplicationId -PermissionsToKeys all -PermissionsToSecrets all

	$context = (Get-AzureRmStorageAccount -Name $storageAccountName -ResourceGroupName $resourceGroupName).Context

	$armtemplatecontainer = Get-AzureStorageContainer -Name "templates" -Context $context -ErrorAction SilentlyContinue
    if (-not $armtemplatecontainer) { $armtemplatecontainer = New-AzureStorageContainer -Name "templates" -Context $context -Permission Off -ErrorAction SilentlyContinue }
	Write-Output "New storage account container created - 'templates'."
	$scriptscontainer = Get-AzureStorageContainer -Name "scripts" -Context $context -ErrorAction SilentlyContinue
	if (-not $scriptscontainer) { $scriptscontainer = New-AzureStorageContainer -Name "scripts" -Context $context -Permission Off -ErrorAction SilentlyContinue }
	Write-Output "New storage account container created - 'scripts'."
	$psrunbookcontainer = Get-AzureStorageContainer -Name "runbooks" -Context $context -ErrorAction SilentlyContinue
	if (-not $psrunbookcontainer) { $psrunbookcontainer = New-AzureStorageContainer -Name "runbooks" -Context $context -Permission Off -ErrorAction SilentlyContinue }
	Write-Output "New storage account container created - 'runbooks'."

	if($armtemplatesLocalDir){
	    ls -Recurse -Path $armtemplatesLocalDir | Set-AzureStorageBlobContent -Container $armtemplatecontainer.Name -Context $context
	    Write-Output "Local files uploaded to storage container - 'arm'."
	}
	if($scriptsLocalDir){
			ls -Recurse -Path $scriptsLocalDir | Set-AzureStorageBlobContent -Container $scriptscontainer.Name -Context $context
			Write-Output "Local files uploaded to storage container - 'scripts'."
	}
	if($psrunbooksLocalDir){
	    if($publishAutomationRunbooks){
	        #Publish all runbooks in the directory after uploading to storage
	        ls -Recurse -Path $psrunbooksLocalDir | `
	        Set-AzureStorageBlobContent -Container $psrunbookcontainer.Name -Context $context -Force | `
	        select @{Name="Path";Expression={$psrunbooksLocalDir + "\" +  $_.Name}}, @{Name="Name";Expression={($_.Substring(0, $_.LastIndexOf('.')))}} | `
	        Import-AzureRMAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName -Type PowerShell -Force | `
	        Publish-AzureRmAutomationRunbook -ResourceGroupName $resourceGroupName -AutomationAccountName $automationAccountName

	        Write-Output "Local files uploaded to storage container - 'runbooks'. Runbooks published to Azure automation."

	        } else
	        {
	        #Upload runbooks to storage, do not publish
	        ls -Recurse -Path $psrunbooksLocalDir | Set-AzureStorageBlobContent -Container $psrunbookcontainer.Name -Context $context
	        Write-Output "Local files uploaded to storage container - 'runbooks'."
	        }
	}

write-host ""
write-host "WebHook parameters:"
write-host "subscriptionId = $($subscription.SubscriptionId)"
write-host "location = $($location)"
write-host "targetResourceGroupName = !!PleaseSpecify!!"
write-host "templateResourceGroupName = $($resourceGroupName)"
write-host "keyVaultName = $($keyVaultName)"
write-host "templateStorageAccountName = $($storageAccountName)"
write-host "templateStorageContainer = templates"
write-host "scriptStorageContainer = scripts"
write-host "templateFileName = !!PleaseSpecify!!.json"
write-host "templateParametersFileName = !!PleaseSpecify!!.json"
write-host "requireSasToken = true"
