BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'AzureUtils.psd1') -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'New-AzureUtilsResourceQuery' {
    It 'returns the bare Resources table with no filters' {
        InModuleScope AzureUtils {
            New-AzureUtilsResourceQuery | Should -Be 'Resources'
        }
    }

    It 'adds a case-insensitive resource group filter' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsResourceQuery -ResourceGroupName 'rg-prod', 'rg-dev'
            $q | Should -Match "where resourceGroup in~ \('rg-prod', 'rg-dev'\)"
        }
    }

    It 'adds a case-insensitive name contains filter' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsResourceQuery -NameContains 'prod'
            $q | Should -Match "where name contains 'prod'"
        }
    }

    It 'escapes single quotes to prevent injection' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsResourceQuery -NameContains "x' or '1'='1"
            $q | Should -Match "x\\' or"
        }
    }
}
