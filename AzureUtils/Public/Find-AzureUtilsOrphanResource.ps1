function Find-AzureUtilsOrphanResource {
    <#
        .SYNOPSIS
            Finds orphaned Azure resources (unused, unassociated).

        .DESCRIPTION
            Uses Azure Resource Graph to find resources that appear to be orphaned
            and explains why in a 'Reason' column. Returns one object per resource
            (also shown as a table on the console). Covered categories:

                Disk                  unattached managed disks
                NetworkInterface      NICs not attached to a VM or private endpoint
                PublicIP              public IPs with no IP configuration / NAT gateway
                NetworkSecurityGroup  NSGs not associated to NICs or subnets
                RouteTable            route tables not associated to subnets

            These are heuristics; review before acting.

        .PARAMETER SubscriptionId
            One or more subscription IDs. Default: every enabled subscription.

        .PARAMETER ManagementGroupId
            One or more management groups to scan (requires Az.ResourceGraph).

        .PARAMETER Type
            Limit the orphan categories to check. Defaults to all of them.

        .EXAMPLE
            Find-AzureUtilsOrphanResource

        .EXAMPLE
            Find-AzureUtilsOrphanResource -Type Disk, PublicIP |
                Sort-Object SubscriptionName, ResourceGroup

        .OUTPUTS
            AzureUtils.OrphanResource
    #>
    [CmdletBinding(DefaultParameterSetName = 'Subscriptions')]
    [OutputType('AzureUtils.OrphanResource')]
    param(
        [Parameter(ParameterSetName = 'Subscriptions')]
        [string[]] $SubscriptionId,

        [Parameter(ParameterSetName = 'ManagementGroup', Mandatory)]
        [string[]] $ManagementGroupId,

        [ValidateSet('Disk', 'NetworkInterface', 'PublicIP', 'NetworkSecurityGroup', 'RouteTable')]
        [string[]] $Type = @('Disk', 'NetworkInterface', 'PublicIP', 'NetworkSecurityGroup', 'RouteTable')
    )

    $null = Assert-AzureUtilsContext

    $resolved = Resolve-AzureUtilsScope -SubscriptionId $SubscriptionId -ManagementGroupId $ManagementGroupId
    if ($resolved.Type -eq 'Subscription' -and -not $resolved.HasSubscriptions) {
        Write-Warning 'No accessible subscriptions in scope.'
        return
    }

    $query   = New-AzureUtilsOrphanResourceQuery -Type $Type
    $nameMap = $resolved.NameMap
    $scope   = $resolved.Scope
    Write-Verbose "Orphan query:`n$query"

    Invoke-AzureUtilsGraphQuery -Query $query @scope | ForEach-Object {
        $subId = [string]$_.subscriptionId
        [pscustomobject]@{
            PSTypeName       = 'AzureUtils.OrphanResource'
            Name             = $_.name
            ResourceType     = $_.type
            ResourceGroup    = $_.resourceGroup
            Location         = $_.location
            SubscriptionName = if ($nameMap.ContainsKey($subId)) { $nameMap[$subId] } else { $subId }
            SubscriptionId   = $subId
            Reason           = $_.reason
            Tags             = ConvertTo-AzureUtilsHashtable -InputObject $_.tags
            ResourceId       = $_.id
        }
    }
}
