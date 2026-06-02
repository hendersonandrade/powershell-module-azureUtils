# Changelog

All notable changes to AzureUtils are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/).

## [0.1.0-alpha] - Unreleased

### Added
- Initial module scaffold (PowerShell 7+, `CompatiblePSEditions = Core`).
- `Export-AzureUtilsTagInventory`: exports an Azure resource + tag inventory to an
  Excel workbook via Azure Resource Graph. Scope filters for management group(s),
  subscription(s), resource group(s), and a case-insensitive `-NameContains`.
  `-OutputPath` sets the `.xlsx` destination; `-FilterTags` restricts the exported
  tag columns (in the given order). The workbook has fixed identity columns
  (`resourceId`, `Resource Name`, `Sub Name`, `Resource Group Name`,
  `Resource Type`, `Region`) plus one `TAG_<name>` column per tag, with a neutral
  table style (`-TableStyle`). Requires `ImportExcel`. Progress is printed as a
  leveled console report (Title / Scope / counts + `[INFO]`/`[ERROR]` lines); the
  cmdlet does not emit pipeline objects.
- CI (PSScriptAnalyzer + Pester) and release automation: `Auto-tag release on
  main` and `Publish PowerShell Gallery` workflows.
