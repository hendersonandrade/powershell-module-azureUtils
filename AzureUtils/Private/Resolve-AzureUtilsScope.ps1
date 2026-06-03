function Resolve-AzureUtilsScope {
    <#
        .SYNOPSIS
            Resolves a Resource Graph scope and a subscriptionId -> name lookup.
        .DESCRIPTION
            Given an optional management-group or subscription scope, returns the
            Search-AzGraph scope splat (ManagementGroup / Subscription), a
            subscriptionId -> display-name map for enrichment, and a friendly
            scope label/type for reports. Used by the Find-/Export- cmdlets.
        .OUTPUTS
            PSCustomObject with: Scope (hashtable), NameMap (hashtable),
            Label (string), Type (string), HasSubscriptions (bool)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [string[]] $SubscriptionId,
        [string[]] $ManagementGroupId
    )

    $scope   = @{}
    $nameMap = @{}

    if ($ManagementGroupId) {
        $scope['ManagementGroup'] = $ManagementGroupId
        foreach ($s in (Resolve-AzureUtilsSubscription)) { $nameMap[$s.Id] = $s.Name }  # best-effort names
        return [pscustomobject]@{
            Scope            = $scope
            NameMap          = $nameMap
            Label            = ($ManagementGroupId -join ', ')
            Type             = 'Management Group'
            HasSubscriptions = $true
        }
    }

    $subs = Resolve-AzureUtilsSubscription -SubscriptionId $SubscriptionId
    foreach ($s in $subs) { $nameMap[$s.Id] = $s.Name }
    if ($subs.Count -gt 0) { $scope['Subscription'] = @($subs.Id) }

    [pscustomobject]@{
        Scope            = $scope
        NameMap          = $nameMap
        Label            = if ($SubscriptionId) { ($subs.Name -join ', ') } else { 'All enabled subscriptions' }
        Type             = 'Subscription'
        HasSubscriptions = ($subs.Count -gt 0)
    }
}
