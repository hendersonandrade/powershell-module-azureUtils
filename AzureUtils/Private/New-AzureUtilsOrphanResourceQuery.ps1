function New-AzureUtilsOrphanResourceQuery {
    <#
        .SYNOPSIS
            Builds the Resource Graph (KQL) query for orphaned resources.
        .DESCRIPTION
            Pure, side-effect-free. Emits a 'where' over the selected orphan types
            and a 'reason' column explaining why each resource is considered
            orphaned. Null-safe association checks treat missing arrays as empty.
        .PARAMETER Type
            Which orphan categories to include. Defaults to all.
        .OUTPUTS
            System.String (the KQL query)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateSet('Disk', 'NetworkInterface', 'PublicIP', 'NetworkSecurityGroup', 'RouteTable')]
        [string[]] $Type = @('Disk', 'NetworkInterface', 'PublicIP', 'NetworkSecurityGroup', 'RouteTable')
    )

    $conditions = [System.Collections.Generic.List[string]]::new()

    if ($Type -contains 'Disk') {
        $conditions.Add("(type =~ 'microsoft.compute/disks' and tostring(properties.diskState) =~ 'Unattached')")
    }
    if ($Type -contains 'NetworkInterface') {
        $conditions.Add("(type =~ 'microsoft.network/networkinterfaces' and isnull(properties.virtualMachine) and isnull(properties.privateEndpoint))")
    }
    if ($Type -contains 'PublicIP') {
        $conditions.Add("(type =~ 'microsoft.network/publicipaddresses' and isnull(properties.ipConfiguration) and isnull(properties.natGateway))")
    }
    if ($Type -contains 'NetworkSecurityGroup') {
        $conditions.Add("(type =~ 'microsoft.network/networksecuritygroups' and (isnull(properties.networkInterfaces) or array_length(properties.networkInterfaces) == 0) and (isnull(properties.subnets) or array_length(properties.subnets) == 0))")
    }
    if ($Type -contains 'RouteTable') {
        $conditions.Add("(type =~ 'microsoft.network/routetables' and (isnull(properties.subnets) or array_length(properties.subnets) == 0))")
    }

    $where = $conditions -join "`n     or "

    return @"
resources
| where $where
| extend reason = case(
    type =~ 'microsoft.compute/disks', 'Unattached managed disk',
    type =~ 'microsoft.network/networkinterfaces', 'Network interface not attached',
    type =~ 'microsoft.network/publicipaddresses', 'Public IP not associated',
    type =~ 'microsoft.network/networksecuritygroups', 'Network security group not associated',
    type =~ 'microsoft.network/routetables', 'Route table not associated',
    'Orphaned')
| project id, name, type, resourceGroup, location, subscriptionId, tags, reason
"@
}
