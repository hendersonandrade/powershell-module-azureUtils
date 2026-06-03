BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'AzureUtils.psd1') -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'ConvertFrom-AzureUtilsTagExcelRow' {
    It 'extracts resourceId and only the non-empty TAG_ columns (as strings)' {
        InModuleScope AzureUtils {
            $row = [pscustomobject]@{
                'resourceId'    = '/subscriptions/1111/resourceGroups/rg-a/providers/x/vm1'
                'Resource Name' = 'vm1'
                'Region'        = 'eastus'
                'TAG_env'       = 'prod'
                'TAG_costCenter' = 10010      # numeric cell -> string
                'TAG_owner'     = ''          # empty -> skipped (not created)
                'TAG_team'      = $null       # null  -> skipped
            }
            $parsed = $row | ConvertFrom-AzureUtilsTagExcelRow

            $parsed.ResourceId | Should -Be '/subscriptions/1111/resourceGroups/rg-a/providers/x/vm1'
            $parsed.Tags | Should -BeOfType ([hashtable])
            $parsed.Tags.Count | Should -Be 2
            $parsed.Tags['env'] | Should -Be 'prod'
            $parsed.Tags['costCenter'] | Should -Be '10010'
            $parsed.Tags.ContainsKey('owner') | Should -BeFalse
            $parsed.Tags.ContainsKey('team') | Should -BeFalse
        }
    }

    It 'returns an empty tag set when no TAG_ columns have values' {
        InModuleScope AzureUtils {
            $row = [pscustomobject]@{ 'resourceId' = '/subscriptions/1/x'; 'TAG_a' = ''; 'Region' = 'eastus' }
            ($row | ConvertFrom-AzureUtilsTagExcelRow).Tags.Count | Should -Be 0
        }
    }

    It 'ignores non-TAG_ columns' {
        InModuleScope AzureUtils {
            $row = [pscustomobject]@{ 'resourceId' = '/s/1'; 'Sub Name' = 'Prod'; 'TAG_env' = 'dev' }
            $parsed = $row | ConvertFrom-AzureUtilsTagExcelRow
            $parsed.Tags.Keys | Should -Be @('env')
        }
    }
}
