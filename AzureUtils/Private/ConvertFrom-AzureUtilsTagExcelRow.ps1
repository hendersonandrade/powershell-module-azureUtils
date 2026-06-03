function ConvertFrom-AzureUtilsTagExcelRow {
    <#
        .SYNOPSIS
            Parses an inventory Excel row into a resource id + tag hashtable.
        .DESCRIPTION
            Reads the 'resourceId' column and every 'TAG_<name>' column. Empty /
            whitespace tag cells are skipped (so they are never created), so the
            resulting hashtable contains only the keys to set/merge. Tag values are
            coerced to strings (Azure tag values are strings).
        .OUTPUTS
            PSCustomObject with: ResourceId (string), Tags (hashtable)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $idProperty = $InputObject.PSObject.Properties['resourceId']
        $resourceId = if ($idProperty) { [string]$idProperty.Value } else { $null }

        $tags = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            if ($property.Name -like 'TAG_*') {
                $key = $property.Name.Substring(4)
                $value = $property.Value
                if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value) -and $key) {
                    $tags[$key] = [string]$value
                }
            }
        }

        [pscustomobject]@{
            ResourceId = $resourceId
            Tags       = $tags
        }
    }
}
