BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'AzureUtils.psd1') -Force
}

AfterAll {
    Remove-Module AzureUtils -Force -ErrorAction SilentlyContinue
}

Describe 'Get-AzureUtilsTagSupportMap' {
    It 'maps each full resource type to whether its capabilities include SupportsTags' {
        InModuleScope AzureUtils {
            $page = @{
                value = @(
                    @{
                        namespace     = 'Microsoft.Compute'
                        resourceTypes = @(
                            @{ resourceType = 'virtualMachines';            capabilities = 'CrossResourceGroupResourceMove, SupportsTags' }
                            @{ resourceType = 'virtualMachines/extensions'; capabilities = 'None' }
                        )
                    }
                    @{
                        namespace     = 'Microsoft.Network'
                        resourceTypes = @(
                            @{ resourceType = 'networkWatchers'; capabilities = '' }
                        )
                    }
                )
            }
            Mock Invoke-AzRestMethod { [pscustomobject]@{ StatusCode = 200; Content = ($page | ConvertTo-Json -Depth 6) } }

            $map = Get-AzureUtilsTagSupportMap

            $map['microsoft.compute/virtualmachines']            | Should -BeTrue
            $map['microsoft.compute/virtualmachines/extensions'] | Should -BeFalse
            $map['microsoft.network/networkwatchers']            | Should -BeFalse
        }
    }

    It 'looks up types case-insensitively' {
        InModuleScope AzureUtils {
            $page = @{ value = @(@{ namespace = 'Microsoft.Compute'; resourceTypes = @(@{ resourceType = 'virtualMachines'; capabilities = 'SupportsTags' }) }) }
            Mock Invoke-AzRestMethod { [pscustomobject]@{ StatusCode = 200; Content = ($page | ConvertTo-Json -Depth 6) } }

            $map = Get-AzureUtilsTagSupportMap

            $map.ContainsKey('MICROSOFT.compute/VirtualMachines') | Should -BeTrue
            $map['MICROSOFT.compute/VirtualMachines']             | Should -BeTrue
        }
    }

    It 'follows nextLink across pages' {
        InModuleScope AzureUtils {
            $page1 = @{
                value    = @(@{ namespace = 'Microsoft.Compute'; resourceTypes = @(@{ resourceType = 'disks'; capabilities = 'SupportsTags' }) })
                nextLink = 'https://management.azure.com/providers?api-version=2021-04-01&$skiptoken=abc'
            }
            $page2 = @{ value = @(@{ namespace = 'Microsoft.Storage'; resourceTypes = @(@{ resourceType = 'storageAccounts'; capabilities = 'SupportsTags' }) }) }

            Mock Invoke-AzRestMethod -ParameterFilter { $Uri } { [pscustomobject]@{ StatusCode = 200; Content = ($page2 | ConvertTo-Json -Depth 6) } }
            Mock Invoke-AzRestMethod -ParameterFilter { $Path } { [pscustomobject]@{ StatusCode = 200; Content = ($page1 | ConvertTo-Json -Depth 6) } }

            $map = Get-AzureUtilsTagSupportMap

            $map['microsoft.compute/disks']            | Should -BeTrue
            $map['microsoft.storage/storageaccounts']  | Should -BeTrue
            Should -Invoke Invoke-AzRestMethod -Times 2 -Exactly
        }
    }

    It 'falls back to the curated list when the API call throws' {
        InModuleScope AzureUtils {
            Mock Invoke-AzRestMethod { throw 'network down' }

            $map = Get-AzureUtilsTagSupportMap

            $map | Should -BeOfType ([hashtable])
            # The fallback only records known-unsupported types (as $false); unknown
            # types are absent so the caller treats them as supported.
            foreach ($value in $map.Values) { $value | Should -BeFalse }
            $map.Count | Should -BeGreaterThan 0
        }
    }

    It 'falls back when the API returns a non-success status code' {
        InModuleScope AzureUtils {
            Mock Invoke-AzRestMethod { [pscustomobject]@{ StatusCode = 403; Content = '{"error":"forbidden"}' } }

            $map = Get-AzureUtilsTagSupportMap

            $map | Should -BeOfType ([hashtable])
            foreach ($value in $map.Values) { $value | Should -BeFalse }
        }
    }
}
