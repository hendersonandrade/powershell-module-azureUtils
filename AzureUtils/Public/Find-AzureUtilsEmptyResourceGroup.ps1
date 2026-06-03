function Find-AzureUtilsEmptyResourceGroup {
    <#
        .SYNOPSIS
            Finds resource groups that contain no resources.

        .DESCRIPTION
            Uses Azure Resource Graph to list resource groups whose resource count
            is zero, across the chosen scope. Returns one object per empty group
            (also shown as a table on the console).

            Note: the count comes from the 'resources' table, which excludes some
            hidden/implicit resource types; a group flagged here has no resources
            visible to Resource Graph.

        .PARAMETER SubscriptionId
            One or more subscription IDs. Default: every enabled subscription in
            the current context.

        .PARAMETER ManagementGroupId
            One or more management groups to scan (requires Az.ResourceGraph).

        .EXAMPLE
            Find-AzureUtilsEmptyResourceGroup

        .EXAMPLE
            Find-AzureUtilsEmptyResourceGroup -ManagementGroupId 'PLAT' |
                Export-Csv .\empty-rgs.csv -NoTypeInformation

        .OUTPUTS
            AzureUtils.EmptyResourceGroup
    #>
    [CmdletBinding(DefaultParameterSetName = 'Subscriptions')]
    [OutputType('AzureUtils.EmptyResourceGroup')]
    param(
        [Parameter(ParameterSetName = 'Subscriptions')]
        [string[]] $SubscriptionId,

        [Parameter(ParameterSetName = 'ManagementGroup', Mandatory)]
        [string[]] $ManagementGroupId
    )

    $null = Assert-AzureUtilsContext

    $resolved = Resolve-AzureUtilsScope -SubscriptionId $SubscriptionId -ManagementGroupId $ManagementGroupId
    if ($resolved.Type -eq 'Subscription' -and -not $resolved.HasSubscriptions) {
        Write-Warning 'No accessible subscriptions in scope.'
        return
    }

    $query   = New-AzureUtilsEmptyResourceGroupQuery
    $nameMap = $resolved.NameMap
    $scope   = $resolved.Scope

    Invoke-AzureUtilsGraphQuery -Query $query @scope | ForEach-Object {
        $subId = [string]$_.subscriptionId
        [pscustomobject]@{
            PSTypeName        = 'AzureUtils.EmptyResourceGroup'
            ResourceGroupName = $_.name
            SubscriptionName  = if ($nameMap.ContainsKey($subId)) { $nameMap[$subId] } else { $subId }
            SubscriptionId    = $subId
            Location          = $_.location
            Tags              = ConvertTo-AzureUtilsHashtable -InputObject $_.tags
            ResourceGroupId   = $_.id
        }
    }
}
