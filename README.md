# AzureUtils

Practical utility cmdlets for **Azure administration, governance, inventory, troubleshooting and operational automation**. AzureUtils does not replace the `Az` modules — it encapsulates real day-to-day pain (inventory at scale, cross-cutting diagnostics, governance checks, safe fixes) behind **simple commands with normalized, automation-ready output**.

- **PowerShell 7+ only** (`CompatiblePSEditions = Core`).
- `Get-*` commands return objects; `Export-*` commands write files and print a console report.
- Read commands use `Get-*`; mutating commands (later) support `-WhatIf` / `-Confirm`.
- All command output and messages are in **en-US**.

## Requirements

| Module            | Required | Purpose                                                   |
|-------------------|----------|-----------------------------------------------------------|
| `Az.Accounts`     | Yes      | Resolves the Azure context (`Connect-AzAccount`).         |
| `Az.ResourceGraph`| Yes      | Powers the inventory query (multi-scope, auto-paginated). |
| `ImportExcel`     | Yes      | Used by `Export-AzureUtilsTagInventory` to write the `.xlsx`. |

All three modules above are declared as `RequiredModules`, so `Install-Module` pulls them in automatically.

## Install

```powershell
Install-Module AzureUtils -Scope CurrentUser            # also installs Az.Accounts, Az.ResourceGraph, ImportExcel
# Pre-release:
Install-Module AzureUtils -AllowPrerelease -Scope CurrentUser
```

## `Export-AzureUtilsTagInventory`

Exports an Azure resource + tag inventory to an Excel workbook via Azure Resource Graph. The cmdlet **does not emit objects** — it writes the `.xlsx` and prints a console report. Scope can be narrowed by **management group(s)**, **subscription(s)**, **resource group(s)**, and a case-insensitive **`-NameContains`** match.

| Parameter | Multiple? | Purpose |
|-----------|-----------|---------|
| `-ManagementGroupId` | yes (`string[]`) | One or more management groups. |
| `-SubscriptionId` | yes (`string[]`) | One or more subscriptions (default: all enabled in the context). |
| `-ResourceGroupName` | yes (`string[]`) | Filter by resource group name(s). |
| `-NameContains` | no (single term) | Keep resources whose name contains this text. |
| `-FilterTags` | yes (`string[]`) | Export only these tag keys, in this order (default: all tags found). |
| `-IncludeSubscription` | — | Also add the subscriptions themselves as rows (their own tags). |
| `-IncludeResourceGroup` | — | Also add the resource groups themselves as rows (their own tags). |
| `-OutputPath` | — (required) | Destination `.xlsx` file. |
| `-TableStyle` | — | Excel table style (default neutral `Light1`). |
| `-Quiet` | — | Suppress per-resource log lines (show a progress bar instead). |

> `-ManagementGroupId` and `-SubscriptionId` are mutually exclusive (separate parameter sets). Requires the `ImportExcel` module.

### Examples

```powershell
Connect-AzAccount

# 1) Everything in the current context, all tags as columns
Export-AzureUtilsTagInventory -OutputPath '.\inventory.xlsx'

# 2) A management group, only two tags (columns in this order)
Export-AzureUtilsTagInventory -ManagementGroupId 'PLAT' `
    -FilterTags 'costCenter', 'environment' `
    -OutputPath 'C:\Temp\report.xlsx'

# 3) Several management groups at once
Export-AzureUtilsTagInventory -ManagementGroupId 'PLAT', 'SANDBOX' -OutputPath '.\all.xlsx'

# 4) Narrow scope + suppress the per-resource log (progress bar instead)
Export-AzureUtilsTagInventory -SubscriptionId $sub1, $sub2 `
    -ResourceGroupName 'rg-prod' -NameContains 'sql' `
    -OutputPath '.\sql-prod.xlsx' -Quiet

# 5) Also inventory the subscriptions and resource groups themselves (their tags)
Export-AzureUtilsTagInventory -ManagementGroupId 'PLAT' `
    -IncludeSubscription -IncludeResourceGroup `
    -OutputPath '.\full.xlsx'
```

> By default only resource-level tags are inventoried. `-IncludeSubscription` and `-IncludeResourceGroup` add the subscriptions / resource groups as extra rows (from `resourcecontainers`) so tags applied at those scopes are captured too.

Console report:

```text
Azure Tag Inventory Export
---------------------------------------------------
    Scope: PLAT [Management Group]
    Number of Subscriptions: 22
    Number of Resources: 1432

Starting export...
    [INFO] 1 of 1432 collecting tags of /subscriptions/.../networkWatchers/NetworkWatcher_brazilsouth
   [ERROR] <message shown for any resource that fails>
    [INFO] Collect Finish
Report exported to C:\Temp\report.xlsx
```

**Excel layout:** fixed columns `resourceId`, `Resource Name`, `Sub Name`, `Resource Group Name`, `Resource Type`, `Region`, followed by one `TAG_<name>` column. Without `-FilterTags`, every tag key found is a column (sorted union); with `-FilterTags`, only the listed keys appear, in the given order (blank where a resource lacks that tag). The table style defaults to a neutral look — change it with `-TableStyle` (any ImportExcel style name).

## `Set-AzureUtilsTagInventory`

Reads an inventory `.xlsx` (the one produced by `Export-AzureUtilsTagInventory`, optionally edited) and **applies** the `TAG_<name>` values back onto each resource identified by its `resourceId`. The operation is a **merge** (`Update-AzTag -Operation Merge`):

- tags present on the resource but **absent from the file are kept** (never removed);
- a `TAG_<name>` cell left **empty is ignored** (never created or changed);
- a **manually added** `TAG_<name>` column (with a value) **creates** that tag.

This cmdlet changes Azure resources, so it supports `-WhatIf` and `-Confirm`. Rows are grouped by subscription (the context is switched per group). Requires `Az.Resources`.

| Parameter | Purpose |
|-----------|---------|
| `-InputPath` (required, pos. 0) | Path to the `.xlsx` to read (alias `-Path`). |
| `-WorksheetName` | Worksheet to read (default `TagInventory`). |
| `-Quiet` | Suppress the per-resource log lines (errors still shown). |

```powershell
# Preview the changes without touching anything
Set-AzureUtilsTagInventory -InputPath 'C:\Temp\report.xlsx' -WhatIf

# Apply (edit the TAG_* cells / add TAG_<new> columns first)
Set-AzureUtilsTagInventory 'C:\Temp\report.xlsx'
```

Round-trip: `Export-AzureUtilsTagInventory` → edit the workbook (change tag values, add `TAG_<new>` columns) → `Set-AzureUtilsTagInventory` to apply.

## `Find-AzureUtilsOrphanResource`

Finds resources that appear orphaned (unused/unassociated) via Azure Resource Graph and explains each in a `Reason` column. Returns objects (also shown as a colored console table). Categories (all by default, narrow with `-Type`):

| `-Type` value | Orphan when… |
|---------------|--------------|
| `Disk` | managed disk `diskState = Unattached` |
| `NetworkInterface` | NIC with no VM and no private endpoint |
| `PublicIP` | public IP with no IP configuration and no NAT gateway |
| `NetworkSecurityGroup` | NSG not associated to any NIC or subnet |
| `RouteTable` | route table not associated to any subnet |

```powershell
Find-AzureUtilsOrphanResource                                   # current context, all categories
Find-AzureUtilsOrphanResource -ManagementGroupId 'PLAT' -Type Disk, PublicIP
Find-AzureUtilsOrphanResource | Export-Csv .\orphans.csv -NoTypeInformation
```

> Heuristics — review before deleting anything.

## `Find-AzureUtilsEmptyResourceGroup`

Lists resource groups whose resource count (from `resources`) is zero, across the chosen scope.

```powershell
Find-AzureUtilsEmptyResourceGroup
Find-AzureUtilsEmptyResourceGroup -SubscriptionId $sub1, $sub2
```

## `Find-AzureUtilsPublicResource`

Surfaces resources exposed to the public internet via Azure Resource Graph, with an `Exposure` column explaining each finding. Returns objects (also a colored console table). Categories (all by default, narrow with `-Type`):

| `-Type` value | Flags |
|---------------|-------|
| `PublicIp` | public IP addresses that are associated (in use) |
| `PublicNetworkAccess` | resources with `properties.publicNetworkAccess = Enabled` (managed disks excluded — `Enabled` by default and not a real exposure) |
| `StorageOpen` | storage with anonymous blob access or `networkAcls.defaultAction = Allow` |
| `NsgInternetInbound` | NSG inbound Allow rules sourced from the Internet (`*` / `0.0.0.0/0`) |

```powershell
Find-AzureUtilsPublicResource
Find-AzureUtilsPublicResource -ManagementGroupId 'PLAT' -Type StorageOpen, NsgInternetInbound
Find-AzureUtilsPublicResource | Export-Csv .\public-exposure.csv -NoTypeInformation
```

> Heuristics — a resource may appear more than once when several categories apply. Review before acting.

All `Find-*` cmdlets take `-SubscriptionId` (default: all enabled) or `-ManagementGroupId` (mutually exclusive) and emit objects for the pipeline.

## Release & publishing

Versioning is driven by the manifest (`AzureUtils/AzureUtils.psd1`):

1. Work happens on `develop`. Bump `ModuleVersion` (and `PrivateData.PSData.Prerelease` for pre-releases) there.
2. Merging `develop → main` (which changes `AzureUtils/AzureUtils.psd1`) runs **`Auto-tag release on main`**, which:
   - resolves the version from the manifest and creates the git tag — stable `v{ModuleVersion}`, pre-release `v{ModuleVersion}-{Prerelease}` — only if it does not already exist;
   - triggers the publish workflow via `gh workflow run` using the built-in `github.token`.
3. **`Publish PowerShell Gallery`** then runs a `guard → validate → publish` pipeline: it publishes **only when** the tag commit is reachable from `main` and the tag matches the manifest version. The publish step is idempotent (an already-published version is treated as success).

> No personal access token is required: the tag is pushed with the default `github.token` and the publish workflow is started explicitly via `gh workflow run` (it also accepts `workflow_dispatch` with a `release_tag` input for manual re-runs).

### Required repository secrets

| Secret              | Used by                     | Notes                       |
|---------------------|-----------------------------|-----------------------------|
| `PSGALLERY_API_KEY` | `Publish PowerShell Gallery`| PowerShell Gallery API key. |

The `auto-tag` workflow needs `permissions: contents: write` and `actions: write` (already declared in the workflow) so it can push the tag and dispatch the publish workflow with the built-in token.

## Development

```powershell
Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser
Invoke-Pester ./AzureUtils/Tests
```
