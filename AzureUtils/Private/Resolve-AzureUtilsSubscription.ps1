function Resolve-AzureUtilsSubscription {
    <#
        .SYNOPSIS
            Resolves the set of subscriptions to query, honoring includes/excludes.
        .DESCRIPTION
            Returns a list of normalized subscription descriptors
            (Id, Name, TenantId) that are enabled and accessible from the current
            context. Supports an explicit allow-list (-SubscriptionId) and a
            name-based exclude-list (-ExcludeSubscription).
        .OUTPUTS
            PSCustomObject[] with properties: Id, Name, TenantId
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[object]])]
    param(
        [string[]] $SubscriptionId,
        [string[]] $ExcludeSubscription
    )

    $subscriptions = Get-AzSubscription -ErrorAction Stop |
        Where-Object { $_.State -eq 'Enabled' }

    if ($SubscriptionId) {
        $subscriptions = $subscriptions | Where-Object { $_.Id -in $SubscriptionId }
    }

    if ($ExcludeSubscription) {
        $subscriptions = $subscriptions | Where-Object { $_.Name -notin $ExcludeSubscription }
    }

    $result = [System.Collections.Generic.List[object]]::new()
    foreach ($sub in $subscriptions) {
        $result.Add([pscustomobject]@{
            Id       = $sub.Id
            Name     = $sub.Name
            TenantId = $sub.TenantId
        })
    }

    if ($result.Count -eq 0) {
        Write-Warning 'No accessible, enabled subscriptions matched the requested scope.'
    }

    return $result
}
