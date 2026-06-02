function New-AzureUtilsResourceQuery {
    <#
        .SYNOPSIS
            Builds the base Azure Resource Graph (KQL) filter query.
        .DESCRIPTION
            Pure, side-effect-free. Produces the 'Resources' table with optional
            resource-group and name-contains filters. The caller appends
            '| count' or '| project ...' as needed. Subscription and
            management-group scoping are handled by Search-AzGraph parameters, not
            in the query text. String values are escaped against query injection.
        .OUTPUTS
            System.String (the base KQL query)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string[]] $ResourceGroupName,
        [string]   $NameContains
    )

    # Escape a value for use inside a single-quoted KQL string literal.
    $escape = { param($value) ($value -replace '\\', '\\') -replace "'", "\'" }

    $clauses = [System.Collections.Generic.List[string]]::new()
    $clauses.Add('Resources')

    if ($ResourceGroupName) {
        $quoted = ($ResourceGroupName | ForEach-Object { "'$(& $escape $_)'" }) -join ', '
        $clauses.Add("| where resourceGroup in~ ($quoted)")
    }

    if (-not [string]::IsNullOrWhiteSpace($NameContains)) {
        $clauses.Add("| where name contains '$(& $escape $NameContains)'")
    }

    return ($clauses -join "`n")
}
