function New-AzureUtilsPublicResourceQuery {
    <#
        .SYNOPSIS
            Builds the Resource Graph (KQL) query for publicly exposed resources.
        .DESCRIPTION
            Pure, side-effect-free. Returns a union of the selected exposure
            categories, each projecting the same columns plus an 'exposure' reason.
        .PARAMETER Type
            Which exposure categories to include. Defaults to all.
        .OUTPUTS
            System.String (the KQL query)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateSet('PublicIp', 'PublicNetworkAccess', 'StorageOpen', 'NsgInternetInbound')]
        [string[]] $Type = @('PublicIp', 'PublicNetworkAccess', 'StorageOpen', 'NsgInternetInbound')
    )

    $cols = 'id, name, type, resourceGroup, location, subscriptionId, tags, exposure'
    $subQueries = [System.Collections.Generic.List[string]]::new()

    if ($Type -contains 'PublicIp') {
        $subQueries.Add(@"
resources
| where type =~ 'microsoft.network/publicipaddresses' and isnotnull(properties.ipConfiguration)
| extend exposure = strcat('Public IP in use: ', tostring(properties.ipAddress))
| project $cols
"@)
    }

    if ($Type -contains 'PublicNetworkAccess') {
        # Managed disks expose publicNetworkAccess = Enabled by default, but that
        # is not a real public exposure (controlled by networkAccessPolicy / SAS),
        # so they are excluded to avoid noise.
        $subQueries.Add(@"
resources
| where tostring(properties.publicNetworkAccess) =~ 'Enabled' and type !~ 'microsoft.compute/disks'
| extend exposure = strcat(type, ' publicNetworkAccess=Enabled')
| project $cols
"@)
    }

    if ($Type -contains 'StorageOpen') {
        $subQueries.Add(@"
resources
| where type =~ 'microsoft.storage/storageaccounts'
    and (properties.allowBlobPublicAccess == true or tostring(properties.networkAcls.defaultAction) =~ 'Allow')
| extend exposure = case(
    properties.allowBlobPublicAccess == true and tostring(properties.networkAcls.defaultAction) =~ 'Allow', 'Storage: anonymous blob access and open network default',
    properties.allowBlobPublicAccess == true, 'Storage: anonymous blob access allowed',
    'Storage: network default action is Allow')
| project $cols
"@)
    }

    if ($Type -contains 'NsgInternetInbound') {
        $subQueries.Add(@"
resources
| where type =~ 'microsoft.network/networksecuritygroups'
| mv-expand rule = properties.securityRules
| extend src = tolower(tostring(rule.properties.sourceAddressPrefix))
| where tolower(tostring(rule.properties.direction)) == 'inbound'
    and tolower(tostring(rule.properties.access)) == 'allow'
    and (src == '*' or src == '0.0.0.0/0' or src == 'internet' or src == 'any')
| extend exposure = strcat('NSG inbound from Internet on port(s) ', tostring(rule.properties.destinationPortRange))
| project $cols
"@)
    }

    if ($subQueries.Count -eq 1) {
        return $subQueries[0]
    }

    # Azure Resource Graph requires the query to start with a table, then chain
    # '| union (subquery)' for the remaining categories.
    $query = $subQueries[0]
    for ($i = 1; $i -lt $subQueries.Count; $i++) {
        $query += "`n| union (`n$($subQueries[$i])`n)"
    }
    return $query
}
