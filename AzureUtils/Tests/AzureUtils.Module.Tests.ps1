BeforeAll {
    $script:ModuleRoot     = Split-Path -Parent $PSScriptRoot
    $script:ManifestPath   = Join-Path $ModuleRoot 'AzureUtils.psd1'
    Import-Module $ManifestPath -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'AzureUtils manifest and surface' {
    It 'has a valid manifest' {
        $manifest = Test-ModuleManifest -Path $ManifestPath
        $manifest.Version | Should -Not -BeNullOrEmpty
    }

    It 'targets PowerShell 7+ Core only' {
        $data = Import-PowerShellDataFile -Path $ManifestPath
        $data.PowerShellVersion     | Should -Be '7.0'
        $data.CompatiblePSEditions  | Should -Be @('Core')
    }

    It 'exports exactly the public functions' {
        (Get-Command -Module AzureUtils).Name | Sort-Object |
            Should -Be @(
                'Export-AzureUtilsTagInventory',
                'Find-AzureUtilsEmptyResourceGroup',
                'Find-AzureUtilsOrphanResource',
                'Set-AzureUtilsTagInventory'
            )
    }

    It 'does not export private helpers' {
        Get-Command -Module AzureUtils -Name 'ConvertTo-AzureUtilsTagRecord' -ErrorAction SilentlyContinue |
            Should -BeNullOrEmpty
    }
}
