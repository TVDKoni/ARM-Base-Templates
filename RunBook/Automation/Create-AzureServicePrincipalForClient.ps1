 Param (
 [Parameter(Mandatory=$true)]
 [String] $SubscriptionId,

 [Parameter(Mandatory=$true)]
 [String] $ApplicationDisplayName,

 [Parameter(Mandatory=$true)]
 [string]$backupKeyVaultName,

 [Parameter(Mandatory=$true)]
 [string]$adminPassword

 )


function Create-AesManagedObject($key, $IV) {

    $aesManaged = New-Object "System.Security.Cryptography.AesManaged"
    $aesManaged.Mode = [System.Security.Cryptography.CipherMode]::CBC
    $aesManaged.Padding = [System.Security.Cryptography.PaddingMode]::Zeros
    $aesManaged.BlockSize = 128
    $aesManaged.KeySize = 256

    if ($IV) {
        if ($IV.getType().Name -eq "String") {
            $aesManaged.IV = [System.Convert]::FromBase64String($IV)
        }
        else {
            $aesManaged.IV = $IV
        }
    }

    if ($key) {
        if ($key.getType().Name -eq "String") {
            $aesManaged.Key = [System.Convert]::FromBase64String($key)
        }
        else {
            $aesManaged.Key = $key
        }
    }

    $aesManaged
}

function Create-AesKey() {
    $aesManaged = Create-AesManagedObject
    $aesManaged.GenerateKey()
    [System.Convert]::ToBase64String($aesManaged.Key)
}

$app = Get-AzureRmADApplication -DisplayNameStartWith $ApplicationDisplayName

if(!$app) {
 #Create the 44-character key value
$keyValue = Create-AesKey
#$psadCredential = New-Object "Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADPasswordCredential"
$psadCredential = New-Object "Microsoft.Azure.Graph.RBAC.Version1_6.ActiveDirectory.PSADPasswordCredential"
$startDate = Get-Date
$psadCredential.StartDate = $startDate
$psadCredential.EndDate = $startDate.AddYears(1)
$psadCredential.KeyId = [guid]::NewGuid()
$psadCredential.Password = $adminPassword


$newId = (New-Guid).Guid
$ClientApplication = New-AzureRmADApplication -DisplayName $ApplicationDisplayName -HomePage ("http://" + $ApplicationDisplayName) -IdentifierUris ("http://" + $newId) -PasswordCredentials $psadCredential

Write-Output "Azure AD application with Id: $($ClientApplication.ApplicationId) created successfully."

$newClientApp = Get-AzureRmADApplication -ApplicationId "$($ClientApplication.ApplicationId)" -ErrorAction SilentlyContinue
While ($newClientApp -eq $null)
{
	sleep 5
	$newClientApp = Get-AzureRmADApplication -ApplicationId "$($ClientApplication.ApplicationId)" -ErrorAction SilentlyContinue
}

# Create the child service principal for the Azure AD application
if (-not (Get-AzureRmADServicePrincipal | Where {$_.ApplicationId -eq $ClientApplication.ApplicationId})) {
	New-AzureRMADServicePrincipal -ApplicationId $ClientApplication.ApplicationId | Write-Verbose
}
Get-AzureRmADServicePrincipal | Where {$_.ApplicationId -eq $ClientApplication.ApplicationId}

$NewRole = Get-AzureRMRoleAssignment -ErrorAction SilentlyContinue | where {$_.DisplayName -eq $ApplicationDisplayName -and $_.RoleDefinitionName -eq "Automation Operator"}
While ($NewRole -eq $null)
{
	# Sleep here for a few seconds to allow the service principal application to become active (should only take a couple of seconds normally)
	Sleep 20
	Try {
		New-AzureRMRoleAssignment -RoleDefinitionName "Automation Operator" -ServicePrincipalName $ClientApplication.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Write-Output "Error message: $($ErrorMessage)"
		Write-Output "Service Principal not yet active, delay before adding the role assignment."
	}
	$NewRole = Get-AzureRMRoleAssignment -ErrorAction SilentlyContinue | where {$_.DisplayName -eq $ApplicationDisplayName -and $_.RoleDefinitionName -eq "Automation Operator"}
}

Write-Output "Azure AD application - $($ApplicationDisplayName) - and service principal with role assignment(s) created."

if($backupKeyVaultName){
    Try {
        $AppIdSecretValue = ConvertTo-SecureString -String $ClientApplication.ApplicationId -AsPlainText -Force
        $AppIdsecret = Set-AzureKeyVaultSecret -VaultName $backupKeyVaultName -Name "$($ApplicationDisplayName)AppId" -SecretValue $AppIdSecretValue
    }
    Catch {
        $ErrorMessage = $_.Exception.Message
        Write-Output "App Id Secret not written to backup key vault for client service principal: $($ErrorMessage)"
    }
    Try {
        $KeySecretValue = ConvertTo-SecureString -String $keyValue -AsPlainText -Force
        $KeyValuesecret = Set-AzureKeyVaultSecret -VaultName $backupKeyVaultName -Name "$($ApplicationDisplayName)Key" -SecretValue $KeySecretValue
    }
    Catch {
        Write-Output "Key Value Id Secret not written to backup key vault for client service principal: $($ErrorMessage)"
    }
}

 } else {
    Write-Output "Application with that name already exists in the tenant."
 }

