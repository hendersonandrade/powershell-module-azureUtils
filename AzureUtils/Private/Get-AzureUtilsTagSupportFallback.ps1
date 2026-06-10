function Get-AzureUtilsTagSupportFallback {
    <#
        .SYNOPSIS
            Curated fallback map of well-known resource types that do not support tags.
        .DESCRIPTION
            Used by Get-AzureUtilsTagSupportMap when the ARM Resource Providers API
            is unreachable. Best-effort only: it lists a handful of types that are
            known not to support tags, each mapped to $false. Types absent from the
            map are assumed to support tags by the caller, so this conservative list
            never hides a real resource — it only suppresses the most common noise.
        .OUTPUTS
            System.Collections.Hashtable (case-insensitive) of fullType -> $false
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $unsupported = @(
        'microsoft.classiccompute/domainnames'
        'microsoft.classicstorage/storageaccounts'
        'microsoft.classicnetwork/virtualnetworks'
        'microsoft.network/networkwatchers/flowlogs'
        'microsoft.network/networkwatchers/connectionmonitors'
        'microsoft.insights/diagnosticsettings'
        'microsoft.insights/webtests/syntheticmonitorlocations'
        'microsoft.resources/subscriptions/resourcegroups/providers'
    )

    $map = [System.Collections.Hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($type in $unsupported) { $map[$type] = $false }
    return $map
}
