function Find-AzureUtilsPublicResource {
    <#
        .SYNOPSIS
            Finds Azure resources that appear to be publicly accessible.

        .DESCRIPTION
            Uses Azure Resource Graph to surface resources exposed to the public
            internet and explains each in an 'Exposure' column. Returns one object
            per finding (also shown as a colored console table). Categories
            (all by default, narrow with -Type):

                PublicIp             public IP addresses that are associated (in use)
                PublicNetworkAccess  resources with properties.publicNetworkAccess = Enabled
                                     (managed disks are excluded: Enabled by default,
                                     not a real exposure)
                StorageOpen          storage with anonymous blob access or open firewall
                NsgInternetInbound   NSG inbound Allow rules from the Internet (* / 0.0.0.0/0)

            These are heuristics; review before acting. A resource may appear more
            than once when several categories apply.

        .PARAMETER SubscriptionId
            One or more subscription IDs. Default: every enabled subscription.

        .PARAMETER ManagementGroupId
            One or more management groups to scan (requires Az.ResourceGraph).

        .PARAMETER Type
            Limit the exposure categories to check. Defaults to all of them.

        .EXAMPLE
            Find-AzureUtilsPublicResource

        .EXAMPLE
            Find-AzureUtilsPublicResource -ManagementGroupId 'PLAT' -Type StorageOpen, NsgInternetInbound

        .EXAMPLE
            Find-AzureUtilsPublicResource | Export-Csv .\public-exposure.csv -NoTypeInformation

        .OUTPUTS
            AzureUtils.PublicResource
    #>
    [CmdletBinding(DefaultParameterSetName = 'Subscriptions')]
    [OutputType('AzureUtils.PublicResource')]
    param(
        [Parameter(ParameterSetName = 'Subscriptions')]
        [string[]] $SubscriptionId,

        [Parameter(ParameterSetName = 'ManagementGroup', Mandatory)]
        [string[]] $ManagementGroupId,

        [ValidateSet('PublicIp', 'PublicNetworkAccess', 'StorageOpen', 'NsgInternetInbound')]
        [string[]] $Type = @('PublicIp', 'PublicNetworkAccess', 'StorageOpen', 'NsgInternetInbound')
    )

    $null = Assert-AzureUtilsContext

    $resolved = Resolve-AzureUtilsScope -SubscriptionId $SubscriptionId -ManagementGroupId $ManagementGroupId
    if ($resolved.Type -eq 'Subscription' -and -not $resolved.HasSubscriptions) {
        Write-Warning 'No accessible subscriptions in scope.'
        return
    }

    $query   = New-AzureUtilsPublicResourceQuery -Type $Type
    $nameMap = $resolved.NameMap
    $scope   = $resolved.Scope
    Write-Verbose "Public-resource query:`n$query"

    Invoke-AzureUtilsGraphQuery -Query $query @scope | ForEach-Object {
        $subId = [string]$_.subscriptionId
        [pscustomobject]@{
            PSTypeName       = 'AzureUtils.PublicResource'
            Name             = $_.name
            ResourceType     = $_.type
            ResourceGroup    = $_.resourceGroup
            Location         = $_.location
            SubscriptionName = if ($nameMap.ContainsKey($subId)) { $nameMap[$subId] } else { $subId }
            SubscriptionId   = $subId
            Exposure         = $_.exposure
            Tags             = ConvertTo-AzureUtilsHashtable -InputObject $_.tags
            ResourceId       = $_.id
        }
    }
}
