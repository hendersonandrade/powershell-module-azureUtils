function Assert-AzureUtilsContext {
    <#
        .SYNOPSIS
            Ensures there is an active Azure context, returning it.
        .DESCRIPTION
            Throws an actionable, terminating error in en-US when the caller is
            not signed in to Azure. All other AzureUtils functions rely on this.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param()

    $context = Get-AzContext -ErrorAction SilentlyContinue

    if (-not $context -or -not $context.Account) {
        throw [System.Management.Automation.RuntimeException]::new(
            "Not connected to Azure. Run 'Connect-AzAccount' (and optionally 'Set-AzContext') before calling AzureUtils commands."
        )
    }

    return $context
}
