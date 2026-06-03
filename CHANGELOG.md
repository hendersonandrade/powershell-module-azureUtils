# Changelog

All notable changes to AzureUtils are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `Find-AzureUtilsPublicResource`: surfaces resources exposed to the public
  internet via Azure Resource Graph, with an `Exposure` column. Categories
  (`-Type`): associated public IPs, `publicNetworkAccess = Enabled`, open /
  anonymous storage, and NSG inbound rules from the Internet. Scope by
  subscription(s) or management group(s); emits objects and a colored table.

## [0.1.8] - 2026-06-03

### Added
- `Find-AzureUtilsOrphanResource`: finds orphaned resources (unattached disks,
  NICs without a VM/private endpoint, public IPs without an IP config/NAT gateway,
  NSGs and route tables with no associations) via Azure Resource Graph, with a
  `Reason` column. Scope by subscription(s) or management group(s); `-Type`
  narrows the categories. Emits objects and a colored console table.
- `Find-AzureUtilsEmptyResourceGroup`: lists resource groups with no resources.

## [0.1.7] - 2026-06-03

### Added
- Initial module scaffold (PowerShell 7+, `CompatiblePSEditions = Core`).
- `Export-AzureUtilsTagInventory`: exports an Azure resource + tag inventory to an
  Excel workbook via Azure Resource Graph. Scope filters for management group(s),
  subscription(s), resource group(s), and a case-insensitive `-NameContains`.
  `-OutputPath` sets the `.xlsx` destination; `-FilterTags` restricts the exported
  tag columns (in the given order); `-IncludeSubscription` / `-IncludeResourceGroup`
  also inventory the subscriptions / resource groups themselves (their own tags) as
  extra rows from `resourcecontainers`. The workbook has fixed identity columns
  (`resourceId`, `Resource Name`, `Sub Name`, `Resource Group Name`,
  `Resource Type`, `Region`) plus one `TAG_<name>` column per tag, with a neutral
  table style (`-TableStyle`). Requires `ImportExcel`. Progress is printed as a
  leveled console report (Title / Scope / counts + `[INFO]`/`[ERROR]` lines); the
  cmdlet does not emit pipeline objects.
- `Set-AzureUtilsTagInventory`: reads an inventory `.xlsx` and merges the
  `TAG_<name>` values back onto each resource (`Update-AzTag -Operation Merge`).
  Keeps tags absent from the file, ignores empty cells, and creates tags from
  manually added `TAG_<name>` columns. Groups by subscription, supports `-WhatIf`
  / `-Confirm`, and requires `Az.Resources`.
- CI (PSScriptAnalyzer + Pester) and release automation: `Auto-tag release on
  main` and `Publish PowerShell Gallery` workflows.
