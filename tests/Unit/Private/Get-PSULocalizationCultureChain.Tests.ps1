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

Describe 'Get-PSULocalizationCultureChain' {
    It 'Should return the exact culture followed by its parent' {
        InModuleScope -ScriptBlock {
            $result = @(Get-PSULocalizationCultureChain -CultureName 'fr-CH')

            ($result -join ',') | Should -Be 'fr-CH,fr'
        }
    }

    It 'Should normalize culture casing in invariant globalization mode' {
        Mock -CommandName Get-UICulture -MockWith {
            [PSCustomObject] @{
                LCID = 127
                Name = ''
            }
        }

        InModuleScope -ScriptBlock {
            $result = @(Get-PSULocalizationCultureChain -CultureName 'zh-hans-ch')

            ($result -join ',') | Should -Be 'zh-Hans-CH,zh-Hans,zh'
        }
    }

    It 'Should throw for an invalid localization culture name' {
        InModuleScope -ScriptBlock {
            { Get-PSULocalizationCultureChain -CultureName 'not_a_culture' } |
                Should -Throw '*not a valid localization culture name*'
        }
    }
}
