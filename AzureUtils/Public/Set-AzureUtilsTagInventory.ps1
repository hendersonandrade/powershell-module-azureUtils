function Set-AzureUtilsTagInventory {
    <#
        .SYNOPSIS
            Applies tag values from an inventory Excel file back to Azure resources.

        .DESCRIPTION
            Reads an .xlsx produced by (or shaped like) Export-AzureUtilsTagInventory
            and sets the tag values from the 'TAG_<name>' columns on each resource
            identified by its 'resourceId'. The operation is a MERGE:

              * tags present on the resource but absent from the file are kept;
              * a 'TAG_<name>' cell left empty is ignored (never created/changed);
              * a manually added 'TAG_<name>' column (with a value) creates that tag.

            Implemented with Update-AzTag -Operation Merge. Rows are grouped by
            subscription and the context is switched per group. This cmdlet changes
            Azure resources, so it supports -WhatIf and -Confirm.

            Requires Az.Resources (Update-AzTag) and ImportExcel. Messages are en-US.

        .PARAMETER InputPath
            Path to the .xlsx inventory file to read.

        .PARAMETER WorksheetName
            Worksheet to read. Defaults to 'TagInventory'.

        .PARAMETER Quiet
            Suppress the per-resource '[INFO] ...' lines (errors are still shown).

        .EXAMPLE
            Set-AzureUtilsTagInventory -InputPath 'C:\Temp\report.xlsx' -WhatIf

            Shows what would be changed without modifying anything.

        .EXAMPLE
            Set-AzureUtilsTagInventory 'C:\Temp\report.xlsx'

            Merges the tag values from the workbook onto the matching resources.

        .LINK
            https://github.com/hendersonandrade/powershell-module-azureUtils
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('Path')]
        [ValidateScript({ if (-not (Test-Path -LiteralPath $_ -PathType Leaf)) { throw "Excel file not found: $_" }; $true })]
        [string] $InputPath,

        [string] $WorksheetName = 'TagInventory',

        [switch] $Quiet
    )

    $null = Assert-AzureUtilsContext

    if (-not (Get-Command -Name 'Import-Excel' -ErrorAction SilentlyContinue)) {
        if (Get-Module -ListAvailable -Name 'ImportExcel' -ErrorAction SilentlyContinue) {
            Import-Module ImportExcel -ErrorAction Stop
        }
        else {
            throw [System.Management.Automation.RuntimeException]::new(
                "Set-AzureUtilsTagInventory requires the 'ImportExcel' module. Install it with: Install-Module ImportExcel -Scope CurrentUser"
            )
        }
    }
    if (-not (Get-Command -Name 'Update-AzTag' -ErrorAction SilentlyContinue)) {
        throw [System.Management.Automation.RuntimeException]::new(
            "Set-AzureUtilsTagInventory requires the 'Az.Resources' module. Install it with: Install-Module Az.Resources -Scope CurrentUser"
        )
    }

    # Read and parse the workbook into { ResourceId, Tags } records.
    $rows = Import-Excel -Path $InputPath -WorksheetName $WorksheetName -ErrorAction Stop

    $apply   = [System.Collections.Generic.List[object]]::new()
    $skipped = 0
    foreach ($record in ($rows | ConvertFrom-AzureUtilsTagExcelRow)) {
        if ([string]::IsNullOrWhiteSpace($record.ResourceId)) { continue }
        if ($record.Tags.Count -eq 0) { $skipped++; continue }   # nothing to set on this row
        $apply.Add($record)
    }

    # Group by subscription so the context can be switched once per subscription.
    $groups   = $apply | Group-Object { if ($_.ResourceId -match '/subscriptions/([0-9a-fA-F-]{36})') { $Matches[1] } else { '' } }
    $subCount = @($groups | Where-Object { $_.Name }).Count

    Write-Host ''
    Write-Host 'Azure Tag Inventory Apply' -ForegroundColor Cyan
    Write-Host ('-' * 51) -ForegroundColor DarkGray
    Write-Host ("    Source: {0}" -f (Resolve-Path -LiteralPath $InputPath).Path)
    Write-Host ("    Resources to update: {0}" -f $apply.Count)
    Write-Host ("    Subscriptions: {0}" -f $subCount)
    if ($skipped -gt 0) { Write-Host ("    Rows skipped (no tag values): {0}" -f $skipped) }
    Write-Host ''
    Write-Host 'Starting apply...'

    if ($apply.Count -eq 0) {
        Write-AzureUtilsStatus -Level WARN -Message 'No resources with tag values to apply.'
        return
    }

    $applied    = 0
    $errorCount = 0
    $n          = 0
    $original   = Get-AzContext

    try {
        foreach ($group in $groups) {
            $subId = $group.Name
            if ($subId) {
                try {
                    $null = Set-AzContext -SubscriptionId $subId -ErrorAction Stop
                }
                catch {
                    $errorCount += $group.Count
                    Write-AzureUtilsStatus -Level ERROR -Message ("Cannot switch to subscription {0}; skipping {1} resource(s): {2}" -f $subId, $group.Count, $_.Exception.Message)
                    $n += $group.Count
                    continue
                }
            }

            foreach ($rec in $group.Group) {
                $n++
                $summary = (($rec.Tags.Keys | Sort-Object | ForEach-Object { '{0}={1}' -f $_, $rec.Tags[$_] }) -join '; ')

                if ($PSCmdlet.ShouldProcess($rec.ResourceId, "Merge tags: $summary")) {
                    try {
                        $null = Update-AzTag -ResourceId $rec.ResourceId -Tag $rec.Tags -Operation Merge -ErrorAction Stop
                        $applied++
                        if (-not $Quiet) {
                            Write-AzureUtilsStatus -Level INFO -Message ("{0} of {1} set {2} tag(s) on {3}: {4}" -f $n, $apply.Count, $rec.Tags.Count, $rec.ResourceId, $summary)
                        }
                    }
                    catch {
                        $errorCount++
                        Write-AzureUtilsStatus -Level ERROR -Message ("{0}: {1}" -f $rec.ResourceId, $_.Exception.Message)
                    }
                }
            }
        }
    }
    finally {
        if ($original) { $null = Set-AzContext -Context $original -ErrorAction SilentlyContinue }
    }

    Write-AzureUtilsStatus -Level INFO -Message 'Apply Finish'
    Write-Host ("Updated {0} of {1} resource(s){2}." -f $applied, $apply.Count, $(if ($errorCount) { ", $errorCount error(s)" } else { '' }))
}
