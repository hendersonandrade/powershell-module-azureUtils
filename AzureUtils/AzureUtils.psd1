@{
    # Script module associated with this manifest.
    RootModule        = 'AzureUtils.psm1'

    # Version number of this module (used by the tag pipeline to build the git tag).
    ModuleVersion     = '0.1.0'

    # Pre-release label. When set, the tag becomes v{ModuleVersion}-{Prerelease}
    # and the PowerShell Gallery package is published as a pre-release.
    # Defined under PrivateData.PSData.Prerelease below.

    # Supported PowerShell editions (Core only -> PowerShell 7+).
    CompatiblePSEditions = @('Core')

    # Minimum PowerShell engine version.
    PowerShellVersion = '7.0'

    # Unique identifier for this module.
    GUID              = 'd0c4f8a2-3b6e-4e1a-9f7c-2a5b8d3e1c47'

    Author            = 'Henderson Andrade'
    CompanyName       = 'Henderson Andrade | Personal Project'
    Copyright         = 'Henderson Andrade | Personal Project'

    Description       = 'Practical utility cmdlets for Azure administration, governance, inventory and operational automation. Complements (does not replace) the Az modules. Includes Export-AzureUtilsTagInventory, which reads every resource in scope via Azure Resource Graph and exports a tag inventory to Excel (one TAG_<name> column per tag).'

    # Hard dependencies (auto-installed by Install-Module AzureUtils):
    #   Az.Accounts      - resolves the Azure context (Connect-AzAccount)
    #   Az.ResourceGraph - powers the inventory query
    #   Az.Resources     - applies tags back to resources (Update-AzTag)
    #   ImportExcel      - reads/writes the .xlsx
    RequiredModules   = @(
        @{ ModuleName = 'Az.Accounts';      ModuleVersion = '2.12.1' },
        @{ ModuleName = 'Az.ResourceGraph'; ModuleVersion = '0.13.0' },
        @{ ModuleName = 'Az.Resources';     ModuleVersion = '6.0.0' },
        @{ ModuleName = 'ImportExcel';      ModuleVersion = '7.0.0' }
    )

    # Only commands placed under Public/ are exported.
    FunctionsToExport = @('Export-AzureUtilsTagInventory', 'Set-AzureUtilsTagInventory')
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags         = @('Azure', 'Governance', 'Inventory', 'Tags', 'ResourceGraph', 'FinOps', 'Excel', 'Automation', 'PSEdition_Core')
            LicenseUri   = 'https://github.com/hendersonandrade/powershell-module-azureUtils/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/hendersonandrade/powershell-module-azureUtils'
            ReleaseNotes = 'See CHANGELOG.md: https://github.com/hendersonandrade/powershell-module-azureUtils/blob/main/CHANGELOG.md'

            # Pre-release label. Leave empty ('') for a stable release.
            # Prerelease   = 'beta'
        }
    }
}
