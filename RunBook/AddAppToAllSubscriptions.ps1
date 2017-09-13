#requires -Modules AzureRM

$automationAccountName = "BFH90INFAMA001"
$applicationRunAsName  = "$($automationAccountName)RunAs"
$applicationClientName = "$($automationAccountName)Client"

Login-AzureRmAccount

$RunAsApplication = Get-AzureRmADApplication -DisplayNameStartWith $applicationRunAsName -ErrorAction SilentlyContinue
$ClientApplication = Get-AzureRmADApplication -DisplayNameStartWith $applicationClientName -ErrorAction SilentlyContinue

Get-AzureRmSubscription | foreach {

    write-host "Configuring app on subscription $($_.Name) $($_.Id)"
    Select-AzureRmSubscription -SubscriptionId $_.Id

    $NewRole = Get-AzureRMRoleAssignment -ErrorAction SilentlyContinue | where {$_.DisplayName -eq $applicationRunAsName -and $_.RoleDefinitionName -eq "Contributor"}
    While ($NewRole -eq $null)
    {
	    Try {
		    New-AzureRMRoleAssignment -RoleDefinitionName "Contributor" -ServicePrincipalName $RunAsApplication.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
		    New-AzureRMRoleAssignment -RoleDefinitionName "User Access Administrator" -ServicePrincipalName $RunAsApplication.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
	    }
	    Catch {
		    $ErrorMessage = $_.Exception.Message
		    Write-Output "Error message: $($ErrorMessage)"
		    Write-Verbose "Service Principal not yet active, delay before adding the role assignment."
            Sleep 5
	    }
	    $NewRole = Get-AzureRMRoleAssignment -ErrorAction SilentlyContinue | where {$_.DisplayName -eq $applicationRunAsName -and $_.RoleDefinitionName -eq "Contributor"}
    }
    Write-Verbose "Azure AD application - $($applicationRunAsName) - and service principal with role assignment(s) created."

    $NewRole = Get-AzureRMRoleAssignment -ErrorAction SilentlyContinue | where {$_.DisplayName -eq $applicationClientName -and $_.RoleDefinitionName -eq "Automation Operator"}
    While ($NewRole -eq $null)
    {
	    Try {
		    New-AzureRMRoleAssignment -RoleDefinitionName "Automation Operator" -ServicePrincipalName $ClientApplication.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue
	    }
	    Catch {
		    $ErrorMessage = $_.Exception.Message
		    Write-Output "Error message: $($ErrorMessage)"
		    Write-Output "Service Principal not yet active, delay before adding the role assignment."
            Sleep 5
	    }
	    $NewRole = Get-AzureRMRoleAssignment -ErrorAction SilentlyContinue | where {$_.DisplayName -eq $applicationClientName -and $_.RoleDefinitionName -eq "Automation Operator"}
    }
    Write-Output "Azure AD application - $($applicationClientName) - and service principal with role assignment(s) created."

}
