BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'AzureUtils.psd1') -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'New-AzureUtilsOrphanResourceQuery' {
    It 'includes all categories by default' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsOrphanResourceQuery
            $q | Should -Match "microsoft.compute/disks"
            $q | Should -Match "microsoft.network/networkinterfaces"
            $q | Should -Match "microsoft.network/publicipaddresses"
            $q | Should -Match "microsoft.network/networksecuritygroups"
            $q | Should -Match "microsoft.network/routetables"
            $q | Should -Match "extend reason = case\("
            $q | Should -Match "project id, name, type, resourceGroup, location, subscriptionId, tags, reason"
        }
    }

    It 'limits the where clause to the selected types' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsOrphanResourceQuery -Type Disk, PublicIP
            $q | Should -Match "microsoft.compute/disks"
            $q | Should -Match "microsoft.network/publicipaddresses"
            # not-selected categories must not appear in the where clause
            ($q -split 'extend reason')[0] | Should -Not -Match "networkinterfaces"
            ($q -split 'extend reason')[0] | Should -Not -Match "routetables"
        }
    }

    It 'uses null-safe checks for association arrays' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsOrphanResourceQuery -Type NetworkSecurityGroup
            $q | Should -Match "isnull\(properties.networkInterfaces\) or array_length\(properties.networkInterfaces\) == 0"
        }
    }
}

Describe 'New-AzureUtilsEmptyResourceGroupQuery' {
    It 'left-joins resource counts and keeps groups with none' {
        InModuleScope AzureUtils {
            $q = New-AzureUtilsEmptyResourceGroupQuery
            $q | Should -Match "resourcecontainers"
            $q | Should -Match "join kind=leftouter"
            $q | Should -Match "summarize resourceCount = count\(\) by subscriptionId, rgKey"
            $q | Should -Match "where isnull\(resourceCount\) or resourceCount == 0"
        }
    }
}
