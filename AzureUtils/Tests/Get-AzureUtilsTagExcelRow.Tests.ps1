BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'AzureUtils.psd1') -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AzureUtilsTagExcelRow' {
    It 'emits the fixed identity columns plus a TAG_ column per tag key (union)' {
        InModuleScope AzureUtils {
            $records = [System.Collections.Generic.List[object]]::new()
            $records.Add([pscustomobject]@{
                ResourceId = '/sub/1/r1'; ResourceName = 'vm1'; SubscriptionName = 'Prod'
                ResourceGroupName = 'rg-a'; ResourceType = 'microsoft.compute/virtualmachines'
                Region = 'eastus'; TagMap = @{ env = 'prod'; owner = 'team-a' }
            })
            $records.Add([pscustomobject]@{
                ResourceId = '/sub/1/r2'; ResourceName = 'disk1'; SubscriptionName = 'Prod'
                ResourceGroupName = 'rg-a'; ResourceType = 'microsoft.compute/disks'
                Region = 'eastus'; TagMap = @{ costCenter = '10010' }
            })

            $rows = @(Get-AzureUtilsTagExcelRow -Record $records)
            $rows.Count | Should -Be 2

            $cols = $rows[0].PSObject.Properties.Name
            $cols[0..5] | Should -Be @('resourceId', 'Resource Name', 'Sub Name', 'Resource Group Name', 'Resource Type', 'Region')

            # Union of all tag keys, each prefixed with TAG_.
            $cols | Should -Contain 'TAG_env'
            $cols | Should -Contain 'TAG_owner'
            $cols | Should -Contain 'TAG_costCenter'

            # Present tag is filled; absent tag on the other row is blank.
            $rows[0].'TAG_env'        | Should -Be 'prod'
            $rows[0].'TAG_costCenter' | Should -Be ''
            $rows[1].'TAG_costCenter' | Should -Be '10010'
            $rows[1].'TAG_env'        | Should -Be ''
        }
    }

    It 'with -TagKey, emits only those tag columns in the given order (case-insensitive)' {
        InModuleScope AzureUtils {
            $records = [System.Collections.Generic.List[object]]::new()
            $records.Add([pscustomobject]@{
                ResourceId = '/sub/1/r1'; ResourceName = 'vm1'; SubscriptionName = 'Prod'
                ResourceGroupName = 'rg-a'; ResourceType = 't'; Region = 'eastus'
                TagMap = @{ environment = 'prod'; costCenter = '10010'; owner = 'team-a' }
            })

            # Requested with different casing and a specific order.
            $rows = @(Get-AzureUtilsTagExcelRow -Record $records -TagKey 'CostCenter', 'environment')
            $cols = $rows[0].PSObject.Properties.Name

            # Only the two requested TAG_ columns, in the requested order/casing.
            ($cols | Where-Object { $_ -like 'TAG_*' }) | Should -Be @('TAG_CostCenter', 'TAG_environment')
            $rows[0].'TAG_CostCenter'  | Should -Be '10010'   # case-insensitive value lookup
            $rows[0].'TAG_environment' | Should -Be 'prod'
            $cols | Should -Not -Contain 'TAG_owner'
        }
    }

    It 'keeps identical columns across all rows' {
        InModuleScope AzureUtils {
            $records = [System.Collections.Generic.List[object]]::new()
            $records.Add([pscustomobject]@{ ResourceId = 'a'; ResourceName = 'a'; SubscriptionName = 's'; ResourceGroupName = 'rg'; ResourceType = 't'; Region = 'r'; TagMap = @{ a = '1' } })
            $records.Add([pscustomobject]@{ ResourceId = 'b'; ResourceName = 'b'; SubscriptionName = 's'; ResourceGroupName = 'rg'; ResourceType = 't'; Region = 'r'; TagMap = @{ b = '2' } })

            $rows = @(Get-AzureUtilsTagExcelRow -Record $records)
            ($rows[0].PSObject.Properties.Name) | Should -Be ($rows[1].PSObject.Properties.Name)
        }
    }
}
