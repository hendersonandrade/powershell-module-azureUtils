function Get-AzureUtilsTagSupportMap {
    <#
        .SYNOPSIS
            Builds a map of Azure resource type -> whether it supports tags.
        .DESCRIPTION
            Queries the ARM Resource Providers API (via Invoke-AzRestMethod, from
            Az.Accounts) and inspects each resource type's 'capabilities' for the
            'SupportsTags' flag. The result is a case-insensitive hashtable keyed by
            the full type 'namespace/resourceType' (matched case-insensitively to
            Azure Resource Graph's 'type' field) whose value is $true when the type
            supports tags and $false otherwise.

            If the API call fails (or returns a non-success status), a small curated
            fallback list of well-known non-tag-supporting types is returned instead.
            Both shapes work with the same lookup rule used by the caller: a type is
            treated as unsupported only when the map says so ($false); a type absent
            from the map is assumed to support tags, so a real resource is never
            hidden by mistake.
        .OUTPUTS
            System.Collections.Hashtable (case-insensitive) of fullType -> [bool]
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $map = [System.Collections.Hashtable]::new([System.StringComparer]::OrdinalIgnoreCase)

    try {
        # First page is fetched by relative -Path; any nextLink is an absolute -Uri.
        $path = '/providers?api-version=2021-04-01'
        $uri  = $null
        do {
            $response = if ($uri) {
                Invoke-AzRestMethod -Method GET -Uri $uri -ErrorAction Stop
            }
            else {
                Invoke-AzRestMethod -Method GET -Path $path -ErrorAction Stop
            }

            if ([int]$response.StatusCode -ge 400) {
                throw "ARM providers request failed with status $($response.StatusCode)."
            }

            $body = $response.Content | ConvertFrom-Json
            foreach ($provider in $body.value) {
                foreach ($rt in $provider.resourceTypes) {
                    $fullType = '{0}/{1}' -f $provider.namespace, $rt.resourceType
                    $caps = @([string]$rt.capabilities -split '[,\s]+' | Where-Object { $_ })
                    $map[$fullType] = [bool]($caps -contains 'SupportsTags')
                }
            }

            # The providers list is normally a single page; follow nextLink defensively.
            $uri = $body.nextLink
        } while ($uri)
    }
    catch {
        Write-Verbose "Get-AzureUtilsTagSupportMap: using curated fallback ($($_.Exception.Message))."
        return (Get-AzureUtilsTagSupportFallback)
    }

    return $map
}
