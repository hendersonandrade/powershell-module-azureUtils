function ConvertTo-AzureUtilsHashtable {
    <#
        .SYNOPSIS
            Converts a tag-like value into a hashtable, regardless of source shape.
        .DESCRIPTION
            Azure Resource Graph returns 'tags' as a PSCustomObject, while
            Get-AzResource returns a dictionary. This helper normalizes either
            shape (and $null) into a plain hashtable so the inventory schema is
            stable across both backends.
        .OUTPUTS
            System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    process {
        $result = @{}

        if ($null -eq $InputObject) {
            return $result
        }

        if ($InputObject -is [System.Collections.IDictionary]) {
            foreach ($key in $InputObject.Keys) {
                $result[$key] = $InputObject[$key]
            }
            return $result
        }

        # PSCustomObject (Resource Graph) or any other object: read note properties.
        foreach ($property in $InputObject.PSObject.Properties) {
            $result[$property.Name] = $property.Value
        }

        return $result
    }
}
