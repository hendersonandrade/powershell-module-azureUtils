function Export-AzureUtilsTagInventory {
    <#
        .SYNOPSIS
            Exports an Azure resource + tag inventory to an Excel workbook.

        .DESCRIPTION
            Reads every Azure resource in scope via Azure Resource Graph and writes
            an .xlsx workbook with the fixed columns resourceId, Resource Name,
            Sub Name, Resource Group Name, Resource Type, Region, followed by one
            'TAG_<name>' column per tag. By default every tag key found is exported;
            -FilterTags restricts the export to the listed keys (in the given order).

            Scope can be narrowed by management group(s), subscription(s), resource
            group(s) and a case-insensitive -NameContains match. Progress is shown
            on the console as a leveled report; the cmdlet does not emit objects to
            the pipeline.

            Requires Az.ResourceGraph and the ImportExcel module. Messages are en-US.

        .PARAMETER ManagementGroupId
            One or more management groups to inventory.

        .PARAMETER SubscriptionId
            One or more subscription IDs. Default: every enabled subscription in the
            current context.

        .PARAMETER ResourceGroupName
            Filter by one or more resource group names (case-insensitive).

        .PARAMETER NameContains
            Keep only resources whose name contains this text (case-insensitive).

        .PARAMETER FilterTags
            Export only these tag keys (one 'TAG_<name>' column each, in this order).
            When omitted, every tag key found is exported.

        .PARAMETER IncludeSubscription
            Also inventory the subscriptions themselves (as extra rows) with their
            own tags. Tags applied at subscription scope are otherwise not captured.

        .PARAMETER IncludeResourceGroup
            Also inventory the resource groups themselves (as extra rows) with their
            own tags. Tags applied at resource-group scope are otherwise not captured.

        .PARAMETER OutputPath
            Destination .xlsx file path.

        .PARAMETER TableStyle
            Excel table style name (ImportExcel). Defaults to a neutral 'Light1'.

        .PARAMETER Quiet
            Suppress the per-resource '[INFO] N of TOTAL ...' lines. The header,
            summary, error lines and final status are still shown.

        .EXAMPLE
            Export-AzureUtilsTagInventory -OutputPath '.\inventory.xlsx'

            Inventories every enabled subscription in the current context and writes
            an Excel workbook with one column per tag found.

        .EXAMPLE
            Export-AzureUtilsTagInventory -ManagementGroupId 'PLAT' `
                -FilterTags 'costCenter', 'environment' `
                -OutputPath 'C:\Temp\report.xlsx'

            Inventories a management group, exporting only the 'costCenter' and
            'environment' tags (as columns TAG_costCenter, TAG_environment, in that
            order).

        .EXAMPLE
            Export-AzureUtilsTagInventory -SubscriptionId $sub1, $sub2 `
                -ResourceGroupName 'rg-prod' -NameContains 'sql' `
                -OutputPath '.\sql-prod.xlsx' -Quiet

            Limits the scope to two subscriptions, the 'rg-prod' resource group and
            resources whose name contains 'sql', and suppresses the per-resource log
            (a progress bar is shown instead).

        .EXAMPLE
            Export-AzureUtilsTagInventory -ManagementGroupId 'PLAT' `
                -IncludeSubscription -IncludeResourceGroup `
                -OutputPath '.\full.xlsx'

            Inventories resources and also adds the subscriptions and resource groups
            themselves (as rows), so tags applied at those scopes are captured too.

        .LINK
            https://github.com/hendersonandrade/powershell-module-azureUtils
    #>
    [CmdletBinding(DefaultParameterSetName = 'Subscriptions')]
    param(
        [Parameter(ParameterSetName = 'ManagementGroup', Mandatory)]
        [string[]] $ManagementGroupId,

        [Parameter(ParameterSetName = 'Subscriptions')]
        [string[]] $SubscriptionId,

        [string[]] $ResourceGroupName,

        [string] $NameContains,

        [string[]] $FilterTags,

        # Also inventory the subscriptions / resource groups themselves (their own
        # tags), as extra rows from the resourcecontainers table.
        [switch] $IncludeSubscription,

        [switch] $IncludeResourceGroup,

        [Parameter(Mandatory)]
        [string] $OutputPath,

        [string] $TableStyle = 'Light1',

        [switch] $Quiet
    )

    $null = Assert-AzureUtilsContext

    if (-not (Get-Command -Name 'Export-Excel' -ErrorAction SilentlyContinue)) {
        if (Get-Module -ListAvailable -Name 'ImportExcel' -ErrorAction SilentlyContinue) {
            Import-Module ImportExcel -ErrorAction Stop
        }
        else {
            throw [System.Management.Automation.RuntimeException]::new(
                "Export-AzureUtilsTagInventory requires the 'ImportExcel' module. Install it with: Install-Module ImportExcel -Scope CurrentUser"
            )
        }
    }

    # Resolve scope, the subscriptionId -> name lookup, and a friendly scope label.
    $scope   = @{}
    $nameMap = @{}
    if ($PSCmdlet.ParameterSetName -eq 'ManagementGroup') {
        $scope['ManagementGroup'] = $ManagementGroupId
        foreach ($s in (Resolve-AzureUtilsSubscription)) { $nameMap[$s.Id] = $s.Name }  # best-effort names
        $scopeLabel = $ManagementGroupId -join ', '
        $scopeType  = 'Management Group'
    }
    else {
        $subs = Resolve-AzureUtilsSubscription -SubscriptionId $SubscriptionId
        if ($subs.Count -eq 0) {
            Write-AzureUtilsStatus -Level WARN -Message 'No accessible subscriptions in scope; nothing to export.'
            return
        }
        foreach ($s in $subs) { $nameMap[$s.Id] = $s.Name }
        $scope['Subscription'] = @($subs.Id)
        $scopeLabel = if ($SubscriptionId) { ($subs.Name -join ', ') } else { 'All enabled subscriptions' }
        $scopeType  = 'Subscription'
    }

    $baseQuery = New-AzureUtilsResourceQuery -ResourceGroupName $ResourceGroupName -NameContains $NameContains

    # Build the set of queries to run: resources, plus optionally the resource
    # group and subscription containers (so their own tags are inventoried too).
    $queries = [System.Collections.Generic.List[string]]::new()
    $queries.Add("$baseQuery`n| project id, name, type, resourceGroup, location, subscriptionId, tags")
    if ($IncludeResourceGroup) {
        $queries.Add((New-AzureUtilsContainerQuery -ContainerType ResourceGroup -NameContains $NameContains -ResourceGroupName $ResourceGroupName))
    }
    if ($IncludeSubscription) {
        $queries.Add((New-AzureUtilsContainerQuery -ContainerType Subscription -NameContains $NameContains))
    }

    # ---- Collect (tags arrive with the query); count from the data so the header
    #      totals are exact. A progress bar gives live feedback during pagination. ----
    $records   = [System.Collections.Generic.List[object]]::new()
    $errors    = [System.Collections.Generic.List[string]]::new()
    $collected = 0
    $activity  = 'Collecting Azure resources from Azure Resource Graph'

    foreach ($query in $queries) {
        Write-Verbose "Query:`n$query"
        Invoke-AzureUtilsGraphQuery -Query $query @scope | ForEach-Object {
            try {
                $records.Add(($_ | ConvertTo-AzureUtilsTagRecord -SubscriptionName $nameMap))
                $collected++
                if ($collected % 50 -eq 0) {
                    Write-Progress -Id 1 -Activity $activity -Status "$collected items collected" -PercentComplete -1
                }
            }
            catch {
                $errors.Add($_.Exception.Message)
            }
        }
    }
    Write-Progress -Id 1 -Activity $activity -Completed

    $total = $records.Count
    $subCount = if ($PSCmdlet.ParameterSetName -eq 'ManagementGroup') {
        ($records | ForEach-Object { $_.SubscriptionId } | Where-Object { $_ } | Sort-Object -Unique).Count
    }
    else {
        $subs.Count
    }

    # ---- Report header (exact totals) ----
    Write-Host ''
    Write-Host 'Azure Tag Inventory Export' -ForegroundColor Cyan
    Write-Host ('-' * 51) -ForegroundColor DarkGray
    Write-Host ("    Scope: {0} [{1}]" -f $scopeLabel, $scopeType)
    Write-Host ("    Number of Subscriptions: {0}" -f $subCount)
    Write-Host ("    Number of Resources: {0}" -f $total)
    Write-Host ''
    Write-Host 'Starting export...'

    # ---- Per-resource report (suppressed by -Quiet; errors always shown) ----
    if (-not $Quiet) {
        $n = 0
        foreach ($rec in $records) {
            $n++
            Write-AzureUtilsStatus -Level INFO -Message ("{0} of {1} collecting tags of {2}" -f $n, $total, $rec.ResourceId)
        }
    }
    foreach ($message in $errors) {
        Write-AzureUtilsStatus -Level ERROR -Message $message
    }

    Write-AzureUtilsStatus -Level INFO -Message 'Collect Finish'

    if ($records.Count -eq 0) {
        Write-AzureUtilsStatus -Level WARN -Message 'No resources found in scope; nothing to export.'
        return
    }

    # ---- Write the workbook ----
    $excelRows = @(Get-AzureUtilsTagExcelRow -Record $records -TagKey $FilterTags)
    $excelRows | Export-Excel -Path $OutputPath -WorksheetName 'TagInventory' `
        -TableName 'TagInventory' -TableStyle $TableStyle -AutoSize -FreezeTopRow -BoldTopRow

    Write-Host ("Report exported to {0}" -f $OutputPath)
}
