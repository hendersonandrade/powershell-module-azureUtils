BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'AzureUtils.psd1') -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'New-AzureUtilsContainerQuery' {
    It 'targets subscription containers and projects without resourceGroup' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsContainerQuery -ContainerType Subscription
            $q | Should -Match "resourcecontainers"
            $q | Should -Match "where type =~ 'microsoft.resources/subscriptions'"
            $q | Should -Match "project id, name, type, location, subscriptionId, tags"
            $q | Should -Not -Match 'resourceGroup'
        }
    }

    It 'targets resource group containers and surfaces the group name' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsContainerQuery -ContainerType ResourceGroup
            $q | Should -Match "where type =~ 'microsoft.resources/subscriptions/resourcegroups'"
            $q | Should -Match 'resourceGroup = name'
        }
    }

    It 'filters resource groups by name when -ResourceGroupName is given' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsContainerQuery -ContainerType ResourceGroup -ResourceGroupName 'rg-a', 'rg-b'
            $q | Should -Match "where name in~ \('rg-a', 'rg-b'\)"
        }
    }

    It 'applies a case-insensitive name contains filter and escapes quotes' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsContainerQuery -ContainerType Subscription -NameContains "x' or '1"
            $q | Should -Match "where name contains 'x\\' or"
        }
    }
}
