function New-AzureUtilsEmptyResourceGroupQuery {
    <#
        .SYNOPSIS
            Builds the Resource Graph (KQL) query for empty resource groups.
        .DESCRIPTION
            Pure, side-effect-free. Left-joins the resource groups in
            'resourcecontainers' against the per-group resource count in
            'resources'; groups with no matching resources are emitted. The join
            key is the lower-cased group name within each subscription.
        .OUTPUTS
            System.String (the KQL query)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return @'
resourcecontainers
| where type =~ 'microsoft.resources/subscriptions/resourcegroups'
| extend rgKey = tolower(name)
| join kind=leftouter (
    resources
    | extend rgKey = tolower(resourceGroup)
    | summarize resourceCount = count() by subscriptionId, rgKey
) on subscriptionId, rgKey
| where isnull(resourceCount) or resourceCount == 0
| project id, name, location, subscriptionId, tags
'@
}
