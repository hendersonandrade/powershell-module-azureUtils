function ConvertTo-AzureUtilsTagRecord {
    <#
        .SYNOPSIS
            Normalizes a Resource Graph row into an internal tag-inventory record.
        .DESCRIPTION
            Produces a flat record with the resource identity fields plus the tags
            as a hashtable (TagMap). The public screen object and the Excel rows are
            both derived from this record by the cmdlet.
        .OUTPUTS
            PSCustomObject with: ResourceId, ResourceName, SubscriptionId,
            SubscriptionName, ResourceGroupName, ResourceType, Region, TagMap
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $InputObject,

        [hashtable] $SubscriptionName = @{}
    )

    process {
        $subId  = [string]$InputObject.subscriptionId
        $subName = if ($subId -and $SubscriptionName.ContainsKey($subId)) { $SubscriptionName[$subId] } else { $subId }

        [pscustomobject]@{
            ResourceId        = $InputObject.id
            ResourceName      = $InputObject.name
            SubscriptionId    = $subId
            SubscriptionName  = $subName
            ResourceGroupName = $InputObject.resourceGroup
            ResourceType      = $InputObject.type
            Region            = $InputObject.location
            TagMap            = ConvertTo-AzureUtilsHashtable -InputObject $InputObject.tags
        }
    }
}
