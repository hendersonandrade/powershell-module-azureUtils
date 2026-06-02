function Get-AzureUtilsTagExcelRow {
    <#
        .SYNOPSIS
            Flattens tag-inventory records into wide Excel rows.
        .DESCRIPTION
            Emits one ordered object per record with the fixed identity columns
            followed by a 'TAG_<name>' column per tag key. When -TagKey is given,
            only those keys are emitted, in the order supplied (case-insensitive
            value lookup, header uses the supplied casing). Otherwise the union of
            every tag key is used, sorted for a deterministic layout.
        .OUTPUTS
            PSCustomObject[] ready for Export-Excel.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Generic.List[object]] $Record,

        # Restrict/order the tag columns. When omitted, the sorted union is used.
        [string[]] $TagKey
    )

    if ($TagKey) {
        $columns = $TagKey
    }
    else {
        $set = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($rec in $Record) {
            if ($rec.TagMap) {
                foreach ($key in $rec.TagMap.Keys) { [void]$set.Add([string]$key) }
            }
        }
        $columns = $set
    }

    foreach ($rec in $Record) {
        $row = [ordered]@{
            'resourceId'          = $rec.ResourceId
            'Resource Name'       = $rec.ResourceName
            'Sub Name'            = $rec.SubscriptionName
            'Resource Group Name' = $rec.ResourceGroupName
            'Resource Type'       = $rec.ResourceType
            'Region'              = $rec.Region
        }

        foreach ($key in $columns) {
            # PowerShell hashtables are case-insensitive by default, so ContainsKey
            # matches the requested key regardless of casing.
            $value = if ($rec.TagMap -and $rec.TagMap.ContainsKey($key)) { $rec.TagMap[$key] } else { '' }
            $row["TAG_$key"] = $value
        }

        [pscustomobject]$row
    }
}
