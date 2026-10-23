BeforeAll {
    $script:moduleName = 'synedgy.universal.helper'

    if (-not (Get-Module -Name $script:moduleName -ListAvailable))
    {
        & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
    }

    Import-Module -Name $script:moduleName -Force -ErrorAction 'Stop'

    $PSDefaultParameterValues['InModuleScope:ModuleName'] = $script:moduleName
    $PSDefaultParameterValues['Should:ModuleName'] = $script:moduleName
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:moduleName
}

Describe 'Get-PSULanguageDisplayName' {
    It 'Should return English culture names by default: <Language>' -ForEach @(
        @{ Language = 'en'; Expected = 'English' }
        @{ Language = 'fr'; Expected = 'French' }
        @{ Language = 'de'; Expected = 'German' }
    ) {
        InModuleScope -Parameters @{
            Language = $Language
            Expected = $Expected
        } -ScriptBlock {
            Get-PSULanguageDisplayName -Language $Language | Should -Be $Expected
        }
    }

    It 'Should return native culture names: <Language>' -ForEach @(
        @{ Language = 'en'; Expected = 'English' }
        @{ Language = 'fr'; Expected = 'français' }
        @{ Language = 'de'; Expected = 'Deutsch' }
    ) {
        InModuleScope -Parameters @{
            Language = $Language
            Expected = $Expected
        } -ScriptBlock {
            Get-PSULanguageDisplayName -Language $Language -UseNativeLanguageName |
                Should -Be $Expected
        }
    }

    It 'Should return an unknown language identifier unchanged' {
        InModuleScope -ScriptBlock {
            Get-PSULanguageDisplayName -Language 'custom-language' |
                Should -Be 'custom-language'
        }
    }
}
