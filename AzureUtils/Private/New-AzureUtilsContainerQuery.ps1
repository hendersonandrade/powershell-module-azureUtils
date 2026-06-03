function New-AzureUtilsContainerQuery {
    <#
        .SYNOPSIS
            Builds the Resource Graph (KQL) query for subscription or resource
            group containers.
        .DESCRIPTION
            Pure, side-effect-free. Targets the 'resourcecontainers' table so the
            subscriptions (-ContainerType Subscription) or resource groups
            (-ContainerType ResourceGroup) themselves can be inventoried with their
            own tags. The projected shape matches what ConvertTo-AzureUtilsTagRecord
            expects. String values are escaped against query injection.
        .OUTPUTS
            System.String (the KQL query)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Subscription', 'ResourceGroup')]
        [string] $ContainerType,

        [string] $NameContains,

        # Only applies to ResourceGroup containers (matched on the group name).
        [string[]] $ResourceGroupName
    )

    $escape = { param($value) ($value -replace '\\', '\\') -replace "'", "\'" }

    $clauses = [System.Collections.Generic.List[string]]::new()
    $clauses.Add('resourcecontainers')

    if ($ContainerType -eq 'Subscription') {
        $clauses.Add("| where type =~ 'microsoft.resources/subscriptions'")
    }
    else {
        $clauses.Add("| where type =~ 'microsoft.resources/subscriptions/resourcegroups'")
        if ($ResourceGroupName) {
            $quoted = ($ResourceGroupName | ForEach-Object { "'$(& $escape $_)'" }) -join ', '
            $clauses.Add("| where name in~ ($quoted)")
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($NameContains)) {
        $clauses.Add("| where name contains '$(& $escape $NameContains)'")
    }

    if ($ContainerType -eq 'ResourceGroup') {
        # Surface the group's own name in the Resource Group Name column.
        $clauses.Add('| project id, name, type, resourceGroup = name, location, subscriptionId, tags')
    }
    else {
        # Subscriptions have no resource group / region.
        $clauses.Add('| project id, name, type, location, subscriptionId, tags')
    }

    return ($clauses -join "`n")
}
