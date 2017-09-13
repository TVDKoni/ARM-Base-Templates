 #Requires -RunAsAdministrator
 Param (

 [Parameter(Mandatory=$true)]
 [String] $SubscriptionId,

 [Parameter(Mandatory=$true)]
 [String] $ResourceGroup,

 [Parameter(Mandatory=$true)]
 [String] $AutomationAccountName,

 [Parameter(Mandatory=$true)]
 [String] $ApplicationDisplayName,

 [Parameter(Mandatory=$true)]
 [SecureString] $CertPassword,

 [Parameter(Mandatory=$false)]
 [int] $NoOfMonthsUntilExpired = 36,

 [string]$backupCertVaultName

 )


$CurrentDate = Get-Date
$KeyId = (New-Guid).Guid
$CertPath = Join-Path $env:TEMP ($ApplicationDisplayName + ".pfx")

Write-Verbose "Create a new certificate for authentication of server (automation run as) service principal"
$Cert = Get-ChildItem -Path cert:\LocalMachine\My | Where-Object { ( $PSItem.Subject -eq "CN=$($ApplicationDisplayName)") -and ($PSItem.NotAfter -gt (Get-Date).AddDays(90)) }

if( -not $Cert) {
	$Cert = New-SelfSignedCertificate -DnsName $ApplicationDisplayName -CertStoreLocation cert:\LocalMachine\My -KeyExportPolicy Exportable -Provider "Microsoft Enhanced RSA and AES Cryptographic Provider"
}
Write-Verbose "Exporting authentication certificate"
Export-PfxCertificate -Cert ("Cert:\localmachine\my\" + $Cert.Thumbprint) -FilePath $CertPath -Password $CertPassword -Force | Write-Verbose

$PFXCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate -ArgumentList @($CertPath, ([PSCredential]::new('fakeCred',$CertPassword).GetNetworkCredential().Password))
$KeyValue = [System.Convert]::ToBase64String($PFXCert.GetRawCertData())

Write-Verbose "Create Azure PSADKeyCredential"
#$KeyCredential = New-Object Microsoft.Azure.Commands.Resources.Models.ActiveDirectory.PSADKeyCredential
$KeyCredential = New-Object Microsoft.Azure.Graph.RBAC.Version1_6.ActiveDirectory.PSADKeyCredential
$KeyCredential.StartDate = $CurrentDate
$KeyCredential.EndDate = $CurrentDate.AddYears(1) #(Get-Date $PFXCert.GetExpirationDateString()).ToString()
$KeyCredential.KeyId = $KeyId
$KeyCredential.CertValue = $KeyValue

Write-Verbose "Checking for existing AzureRmADApplication $($ApplicationDisplayName)."
$RunAsApplication = Get-AzureRmADApplication -DisplayNameStartWith $ApplicationDisplayName -ErrorAction SilentlyContinue

if ($null -eq $RunAsApplication) {
	Write-Verbose "Creating Azure AD application $($ApplicationDisplayName)."
	# Create the Azure AD application - use newly create certificate for key credentials
	$RunAsApplication = New-AzureRmADApplication -DisplayName $ApplicationDisplayName -HomePage ("http://" + $ApplicationDisplayName) -IdentifierUris ("http://" + $KeyId) -KeyCredentials $keyCredential
}

$newApp = Get-AzureRmADApplication -ApplicationId $RunAsApplication.ApplicationId -ErrorAction SilentlyContinue
While ($newApp -eq $null)
{
	sleep 10
	$newApp = Get-AzureRmADApplication -ApplicationId $RunAsApplication.ApplicationId -ErrorAction SilentlyContinue
}

# Create the child service principal for the Azure AD application
if (-not (Get-AzureRmADServicePrincipal | Where {$_.ApplicationId -eq $RunAsApplication.ApplicationId})) {
	New-AzureRMADServicePrincipal -ApplicationId $RunAsApplication.ApplicationId | Write-Verbose
}
Get-AzureRmADServicePrincipal | Where {$_.ApplicationId -eq $RunAsApplication.ApplicationId}

#When the service principal becomes active, create the appropriate role assignments
$NewRole = Get-AzureRMRoleAssignment -ErrorAction SilentlyContinue | where {$_.DisplayName -eq $ApplicationDisplayName -and $_.RoleDefinitionName -eq "Contributor"}
While ($NewRole -eq $null)
{
	# Sleep here for a few seconds to allow the service principal application to become active (should only take a couple of seconds normally)
	Sleep 20
	Try {
		New-AzureRMRoleAssignment -RoleDefinitionName "Contributor" -ServicePrincipalName $RunAsApplication.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
		New-AzureRMRoleAssignment -RoleDefinitionName "User Access Administrator" -ServicePrincipalName $RunAsApplication.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
	}
	Catch {
		$ErrorMessage = $_.Exception.Message
		Write-Output "Error message: $($ErrorMessage)"
		Write-Verbose "Service Principal not yet active, delay before adding the role assignment."
	}
	$NewRole = Get-AzureRMRoleAssignment -ErrorAction SilentlyContinue | where {$_.DisplayName -eq $ApplicationDisplayName -and $_.RoleDefinitionName -eq "Contributor"}
}
Write-Verbose "Azure AD application - $($ApplicationDisplayName) - and service principal with role assignment(s) created."

# Get the tenant id for this subscription
$SubscriptionInfo = Get-AzureRmSubscription -SubscriptionId $SubscriptionId
$TenantID = $SubscriptionInfo | Select TenantId -First 1

# Create the automation resources

Write-Verbose "Create the Azure automation certificate object"
if (-not ( get-AzureRmAutomationCertificate -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccountName -Name "AzureRunAsCertificate"  -ErrorAction SilentlyContinue)) {
 New-AzureRmAutomationCertificate -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccountName -Path $CertPath -Name "AzureRunAsCertificate" -Password $CertPassword -Exportable | write-verbose
 Write-Verbose "Azure automation certificate created - AzureRunAsCertificate - in Azure automation account: $($AutomationAccountName)."
}

 # Create a Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal, with the newly uploaded certificate.
 $ConnectionAssetName = "AzureRunAsConnection"
 Remove-AzureRmAutomationConnection -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccountName -Name $ConnectionAssetName -Force -ErrorAction SilentlyContinue
 $ConnectionFieldValues = @{"ApplicationId" = $RunAsApplication.ApplicationId; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Cert.Thumbprint; "SubscriptionId" = $SubscriptionId}
 New-AzureRmAutomationConnection -ResourceGroupName $ResourceGroup -AutomationAccountName $AutomationAccountName -Name $ConnectionAssetName -ConnectionTypeName AzureServicePrincipal -ConnectionFieldValues $ConnectionFieldValues

 Write-Output "Azure automation connection created - $($ConnectionAssetName) - in Azure automation account: $($AutomationAccountName)."

 if($backupCertVaultName){
    $secret = ConvertTo-SecureString -String $KeyValue -AsPlainText -Force
    $secretContentType = 'application/x-pkcs12'
    Set-AzureKeyVaultSecret -VaultName $backupCertVaultName -Name "$($ApplicationDisplayName)Cert" -SecretValue $secret -ContentType $secretContentType
 }
