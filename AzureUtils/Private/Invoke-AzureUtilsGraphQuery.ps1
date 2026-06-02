function Invoke-AzureUtilsGraphQuery {
    <#
        .SYNOPSIS
            Runs an Azure Resource Graph query with automatic pagination.
        .DESCRIPTION
            Wraps Search-AzGraph, transparently following the SkipToken until the
            result set is exhausted (or the optional -First cap is reached).
            Resource Graph returns up to 1000 rows per page.
        .OUTPUTS
            The raw Resource Graph rows (PSCustomObject) streamed to the pipeline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Query,

        [string[]] $Subscription,

        [string[]] $ManagementGroup,

        [int] $First
    )

    $pageSize  = 1000
    $skipToken = $null
    $emitted   = 0

    do {
        $params = @{
            Query = $Query
            First = $pageSize
        }
        if ($Subscription)    { $params['Subscription']    = $Subscription }
        if ($ManagementGroup) { $params['ManagementGroup'] = $ManagementGroup }
        if ($skipToken)       { $params['SkipToken']       = $skipToken }

        $response = Search-AzGraph @params

        foreach ($row in $response) {
            $row
            $emitted++
            if ($First -gt 0 -and $emitted -ge $First) {
                Write-Verbose "Reached the requested limit of $First resource(s); stopping pagination."
                return
            }
        }

        $skipToken = $response.SkipToken
    } while ($skipToken)
}
