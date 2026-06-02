BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'AzureUtils.psd1') -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertTo-AzureUtilsTagRecord' {
    It 'maps a Resource Graph row and enriches the subscription name' {
        InModuleScope AzureUtils {
            $row = [pscustomobject]@{
                id             = '/subscriptions/1111/resourceGroups/rg-a/providers/x/vm1'
                name           = 'vm1'
                type           = 'microsoft.compute/virtualmachines'
                resourceGroup  = 'rg-a'
                location       = 'eastus'
                subscriptionId = '1111'
                tags           = [pscustomobject]@{ env = 'prod' }   # Graph shape
            }
            $rec = $row | ConvertTo-AzureUtilsTagRecord -SubscriptionName @{ '1111' = 'Production' }

            $rec.ResourceName     | Should -Be 'vm1'
            $rec.SubscriptionName | Should -Be 'Production'
            $rec.Region           | Should -Be 'eastus'
            $rec.TagMap           | Should -BeOfType ([hashtable])
            $rec.TagMap['env']    | Should -Be 'prod'
        }
    }

    It 'falls back to the subscription id when the name is unknown' {
        InModuleScope AzureUtils {
            $row = [pscustomobject]@{ id = 'x'; name = 'n'; type = 't'; resourceGroup = 'rg'; location = 'r'; subscriptionId = '9999'; tags = $null }
            $rec = $row | ConvertTo-AzureUtilsTagRecord
            $rec.SubscriptionName | Should -Be '9999'
            $rec.TagMap.Count     | Should -Be 0
        }
    }
}
