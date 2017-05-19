#The following is an Azure Automation PowerShell runbook.
#Uses a preconfigured AutomationConnection object (AzureRunAsConnection) for authentication
#This object must be in place in your tenant with the appropriate role(s), and added as a connection asset in the
#Azure Automation account being used.

Param(
 [Parameter(Mandatory=$true)]
 [string]$subscriptionId,
 [string]$location = "westeurope",
 [Parameter(Mandatory=$true)]
 [string]$targetResourceGroupName,
 [Parameter(Mandatory=$true)]
 [string]$templateResourceGroupName,
 [Parameter(Mandatory=$true)]
 [string]$keyVaultName,
 [Parameter(Mandatory=$true)]
 [string]$templateStorageAccountName,
 [Parameter(Mandatory=$true)]
 [string]$templateStorageContainer,
 [Parameter(Mandatory=$true)]
 [string]$scriptStorageContainer,
 [Parameter(Mandatory=$true)]
 [string]$templateFileName,
 [string]$templateParametersFileName,
 [string]$requireSasToken
)

# Create timestamp and get automation connection
$timestamp = $(get-date -f MM-dd-yyyy_HH_mm_ss)
$conn = Get-AutomationConnection -Name 'AzureRunAsConnection'

# Get stored credentials
$adminCredential = Get-AutomationPSCredential -Name "$($templateResourceGroupName)AdminPassword"
$sqlCredential = Get-AutomationPSCredential -Name "$($templateResourceGroupName)SqlPassword"

# Authenticate Azure account and set subscription
Add-AzureRmAccount -ServicePrincipal -TenantId $conn.TenantId -ApplicationId $conn.ApplicationId -CertificateThumbprint $conn.CertificateThumbprint #-EnvironmentName $environmentName 
Select-AzureRmSubscription -SubscriptionId $subscriptionId

# Create Resource group if it does not already exist
$rg = Get-AzureRmResourceGroup -Name $targetResourceGroupName -ev notPresent -ea 0
$rg
if(!$rg) {
    New-AzureRmResourceGroup -Name $targetResourceGroupName -Location $location
}

#Get a collection of any existing locks on the resource group, remove locks, store name and locklevel
Write-Output "Get the collection of any existing resource group locks, and remove them."
$existingLocks = Get-AzureRmResourceLock -ResourceGroupName $targetResourceGroupName | Select @{Name="LockName";Expression={$_.Name}}, @{Name="LockLevel";Expression={$_.Properties.Level}}
$existingLocks | Remove-AzureRmResourceLock -ResourceGroupName $targetResourceGroupName -ErrorVariable removeLockError -ErrorAction SilentlyContinue -Force
if($removeLockError) {
    $RemoveLockError | ForEach-Object {Write-Output $_.Exception.Message}
}

# Get storage context, shared access tokens, and template blob
$context = (Get-AzureRmStorageAccount -Name $templateStorageAccountName -ResourceGroupName $templateResourceGroupName).Context
$templateSasToken = New-AzureStorageContainerSASToken -Container $templateStorageContainer -Context $context -StartTime ([System.DateTime]::UtcNow).AddMinutes(-2) -ExpiryTime ([System.DateTime]::UtcNow).AddMinutes(60) -Permission r
$scriptSasToken = New-AzureStorageContainerSASToken -Container $scriptStorageContainer -Context $context -StartTime ([System.DateTime]::UtcNow).AddMinutes(-2) -ExpiryTime ([System.DateTime]::UtcNow).AddMinutes(60) -Permission r
$templateBlob = Get-AzureStorageBlob -Context $context -Container $templateStorageContainer -Blob $templateFileName
$scriptsContainerUri = ($context.BlobEndPoint + $scriptStorageContainer)
$templatesContainerUri = ($context.BlobEndPoint + $templateStorageContainer)

# CONFIGURE DEPLOYMENT
if($templateParametersFileName) {
    Write-Output "Parameter file specified, continuing with deployment..."
    $templateUri = $templateBlob.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri

    #Get parameter blob and save it to disk
    $parameterBlob = Get-AzureStorageBlob -Context $context -Container $templateStorageContainer -Blob $templateParametersFileName
    $parameterBlob | Get-AzureStorageBlobContent -Destination $env:TEMP -Context $context -Force
    $pathToFile = ($env:TEMP + "\" + $templateParametersFileName)

    $json = Get-Content $pathToFile -Raw | ConvertFrom-Json
    # Add sas tokens to parameter file if required
    if($requireSasToken) {
        $templateUri = $templateBlob.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri + $templateSasToken
        # convert parameters file to powershell object, add sas tokens, convert back to json, and save to disk
        $json.parameters | Add-Member -Name "sasTokenTemplates" -Value @{'value' = $templateSasToken} -MemberType NoteProperty -Force
        $json.parameters | Add-Member -Name "sasTokenScripts" -Value @{'value' = $scriptSasToken} -MemberType NoteProperty -Force
    }
    $json.parameters | Add-Member -Name "templatesBaseUrl" -Value @{'value' = $templatesContainerUri} -MemberType NoteProperty -Force
    $json.parameters | Add-Member -Name "scriptsBaseUrl" -Value @{'value' = $scriptsContainerUri} -MemberType NoteProperty -Force
    $json.parameters | Add-Member -Name "keyVaultName" -Value @{'value' = $keyVaultName} -MemberType NoteProperty -Force
    $json.parameters | Add-Member -Name "orchestrationResourceGroupName" -Value @{'value' = $templateResourceGroupName} -MemberType NoteProperty -Force
    $json.parameters | Add-Member -Name "SqlserverAdminLoginPassword" -Value @{'value' = $sqlCredential.GetNetworkCredential().Password} -MemberType NoteProperty -Force
    ConvertTo-Json $json -Depth 4 | Set-Content $pathToFile

    # DEPLOY TEMPLATE WITH PARAMETER FILE
    New-AzureRmResourceGroupDeployment -Name $timestamp -ResourceGroupName $targetResourceGroupName -Mode Incremental `
        -TemplateUri $templateUri `
        -TemplateParameterFile $pathToFile `
        -Force -Verbose
}
elseif (!$templateParametersFileName -and $requireSasToken) {
  Write-Output "Parameter file not specified... SasToken required... continuing with deployment..."

  # formulate template uri with sas token
  $templateUri = $templateBlob.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri + $templateSasToken

  # DEPLOY WITHOUT PARAMETER FILE WITH SAS TOKENS
  New-AzureRmResourceGroupDeployment -Name $timestamp -ResourceGroupName $targetResourceGroupName -Mode Incremental `
      -TemplateUri $templateUri `
      -keyVaultName $keyVaultName `
      -orchestrationResourceGroupName $templateResourceGroupName `
      -scriptsBaseUrl $scriptsContainerUri `
      -sasTokenTemplates $templateSasToken `
      -sasTokenScripts $scriptSasToken `
      -Force -Verbose
      #TODO: change to -TemplateParameterObject

} else {
  Write-Output "Parameter file not specified... SasToken not required... continuing with deployment..."

  # Formulate template uri without sas token
  $templateUri = $blob.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri

  # DEPLOY WITHOUT PARAMETER FILE AND SAS TOKENS
  New-AzureRmResourceGroupDeployment -Name $timestamp -ResourceGroupName $targetResourceGroupName -Mode Incremental `
      -TemplateUri $templateUri `
      -scriptsBaseUrl $scriptsContainerUri `
      -keyVaultName $keyVaultName `
      -orchestrationResourceGroupName $templateResourceGroupName `
      -Force -Verbose
      #TODO: change to -TemplateParameterObject
}

# delete locally save parameter file if necessary
if ($templateParametersFileName) {
    Remove-Item $pathToFile
}

# if any existing resource group locks were found, re-apply to the resource group.
Write-Output "Re-apply any existing resource group locks."
if($existingLocks) {
    $existingLocks | select LockName, LockLevel, @{Name="LockNotes";Expression={$_.LockName + ": " + $_.LockLevel }} | `
    New-AzureRmResourceLock -ResourceGroupName $targetResourceGroupName -Verbose -Force -ErrorVariable addLockError -ErrorAction SilentlyContinue
}

if($addLockError) {
    $addLockError | ForEach-Object {Write-Output $_.Exception.Message}
}
