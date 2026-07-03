BeforeAll {
    $script:moduleName = 'synedgy.universal.helper'

    # If the module is not found, run the build task 'noop'.
    if (-not (Get-Module -Name $script:moduleName -ListAvailable))
    {
        # Redirect all streams to $null, except the error stream (stream 2)
        & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
    }

    # Re-import the module using force to get any code changes between runs.
    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Mock:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:moduleName
}

Describe 'ConvertFrom-PsuJobOutputEntry' {
    It 'Should map integer type 0 to Information stream' {
        InModuleScope -ScriptBlock {
            $entry  = [PSCustomObject]@{ Type = 0; Message = 'Info line'; Timestamp = [datetime]'2026-01-01T00:00:00' }
            $result = $entry | ConvertFrom-PsuJobOutputEntry

            $result.Stream | Should -Be 'Information'
            $result.StreamColor | Should -Be 'var(--psu-term-stream-information)'
        }
    }

    It 'Should map integer type 4 to Error stream' {
        InModuleScope -ScriptBlock {
            $entry  = [PSCustomObject]@{ Type = 4; Message = 'Error!'; Timestamp = $null }
            $result = $entry | ConvertFrom-PsuJobOutputEntry

            $result.Stream | Should -Be 'Error'
            $result.StreamColor | Should -Be 'var(--psu-term-stream-error)'
        }
    }

    It 'Should map string type Warning to Warning stream' {
        InModuleScope -ScriptBlock {
            $entry  = [PSCustomObject]@{ Type = 'Warning'; Message = 'Watch out'; Timestamp = $null }
            $result = $entry | ConvertFrom-PsuJobOutputEntry

            $result.Stream | Should -Be 'Warning'
        }
    }

    It 'Should extract message from Message property' {
        InModuleScope -ScriptBlock {
            $entry  = [PSCustomObject]@{ Type = 0; Message = 'Hello'; Timestamp = $null }
            $result = $entry | ConvertFrom-PsuJobOutputEntry

            $result.Message | Should -Be 'Hello'
        }
    }

    It 'Should accept pipeline input and emit one row per entry' {
        InModuleScope -ScriptBlock {
            $entries = @(
                [PSCustomObject]@{ Type = 0; Message = 'Line 1'; Timestamp = $null }
                [PSCustomObject]@{ Type = 3; Message = 'Line 2'; Timestamp = $null }
            )
            $results = @($entries | ConvertFrom-PsuJobOutputEntry)

            $results.Count | Should -Be 2
        }
    }

    It 'Should default unknown type to Output stream' {
        InModuleScope -ScriptBlock {
            $entry  = [PSCustomObject]@{ Type = 99; Message = 'raw'; Timestamp = $null }
            $result = $entry | ConvertFrom-PsuJobOutputEntry

            $result.Stream | Should -Be 'Output'
            $result.StreamColor | Should -Be 'var(--psu-term-stream-default)'
        }
    }
}
