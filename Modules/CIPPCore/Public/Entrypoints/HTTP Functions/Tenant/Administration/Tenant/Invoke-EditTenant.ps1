using namespace System.Net

Function Invoke-EditTenant {
    <#
    .FUNCTIONALITY
        Entrypoint
    .ROLE
        CIPP.Core.ReadWrite
    #>
    [CmdletBinding()]
    param($Request, $TriggerMetadata)

    $APIName = $TriggerMetadata.FunctionName
    Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -message 'Accessed this API' -Sev 'Debug'

    $tenantDisplayName = $request.body.displayName
    $tenantDefaultDomainName = $request.body.defaultDomainName
    $Tenant = $request.body.tenantid
    $customerContextId = $request.body.customerId

    $tokens = try {
        $Graphtoken = (Get-GraphToken)
        $tenantDetails = (Invoke-RestMethod -Method Get -Uri "https://graph.microsoft.com/v1.0/contracts?`$filter=customerId eq $($customerContextId)" -ContentType 'application/json' -Headers $Graphtoken).value
        $tenantObjectId = $tenantDetails.id
    }
    catch {
        $Results = "Failed to retrieve tenant. Error: $($_.Exception.Message)"
        Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -tenant $($tenantDisplayName) -message "Failed to retrieve tenant. Error:$($_.Exception.Message)" -Sev 'Error'
    }


    if ($tenantObjectId) {
        try {
            $bodyToPatch = '{"displayName":"' + $tenantDisplayName + '","defaultDomainName":"' + $tenantDefaultDomainName + '"}'
            $patchTenant = (Invoke-RestMethod -Method PATCH -Uri "https://graph.microsoft.com/v1.0/contracts/$($tenantObjectId)" -Body $bodyToPatch -ContentType 'application/json' -Headers $Graphtoken -ErrorAction Stop)
            $Filter = "PartitionKey eq 'Tenants' and defaultDomainName eq '{0}'" -f $tenantDefaultDomainName
            try {
                $TenantsTable = Get-CippTable -tablename Tenants
                $Tenant = Get-CIPPAzDataTableEntity @TenantsTable -Filter $Filter
                $Tenant.displayName = $tenantDisplayName
                Update-AzDataTableEntity @TenantsTable -Entity $Tenant
            }
            catch {
                $AddedText = 'but could not edit the tenant cache. Clear the tenant cache to display the updated details'
            }
            Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -tenant $tenantDisplayName -message "Edited tenant $tenantDisplayName" -Sev 'Info'
            $results = "Successfully amended details for $($Tenant.displayName) $AddedText"
        }
        catch {
            $results = "Failed to amend details for $tenantDisplayName : $($_.Exception.Message)"
            Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME -tenant $tenantDisplayName -message "Failed amending details $tenantDisplayName. Error:$($_.Exception.Message)" -Sev 'Error'
        }
    }
    else {
        $Results = 'Could not find the tenant to edit in the contract endpoint. Please ensure you have a reseller relationship with the tenant you are trying to edit.'
    }

    $body = [pscustomobject]@{'Results' = $results }

    # Associate values to output bindings by calling 'Push-OutputBinding'.
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $body
        })

}
