BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'AzureUtils.psd1') -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'New-AzureUtilsPublicResourceQuery' {
    It 'chains categories with piped union and starts with the resources table' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsPublicResourceQuery
            $q | Should -Match '^resources'                 # ARG queries must start with a table
            $q | Should -Match '\| union \('                # remaining categories chained via | union ()
            $q | Should -Match "type =~ 'microsoft.network/publicipaddresses' and isnotnull\(properties.ipConfiguration\)"
            $q | Should -Match "tostring\(properties.publicNetworkAccess\) =~ 'Enabled'"
            $q | Should -Match "properties.allowBlobPublicAccess == true"
            $q | Should -Match "mv-expand rule = properties.securityRules"
        }
    }

    It 'returns a single sub-query (no union) for one category' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsPublicResourceQuery -Type PublicNetworkAccess
            $q | Should -Not -Match '\| union \('
            $q | Should -Match "tostring\(properties.publicNetworkAccess\) =~ 'Enabled'"
            $q | Should -Match 'project id, name, type, resourceGroup, location, subscriptionId, tags, exposure'
        }
    }

    It 'only includes the requested categories' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsPublicResourceQuery -Type StorageOpen, NsgInternetInbound
            $q | Should -Match 'microsoft.storage/storageaccounts'
            $q | Should -Match 'mv-expand rule'
            $q | Should -Not -Match 'publicipaddresses'
            $q | Should -Not -Match 'publicNetworkAccess'
        }
    }

    It 'excludes managed disks from the publicNetworkAccess category (false positive)' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsPublicResourceQuery -Type PublicNetworkAccess
            $q | Should -Match "type !~ 'microsoft.compute/disks'"
        }
    }

    It 'detects Internet sources case-insensitively in NSG rules' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsPublicResourceQuery -Type NsgInternetInbound
            $q | Should -Match "src == '\*' or src == '0.0.0.0/0' or src == 'internet' or src == 'any'"
        }
    }
}
