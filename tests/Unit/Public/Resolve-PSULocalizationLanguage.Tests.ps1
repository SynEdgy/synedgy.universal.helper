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

Describe 'Resolve-PSULocalizationLanguage' {
    BeforeEach {
        $script:moduleBase = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid().Guid)
        foreach ($language in @('en', 'fr', 'fr-CH'))
        {
            $culturePath = Join-Path -Path $script:moduleBase -ChildPath $language
            $null = New-Item -Path $culturePath -ItemType Directory -Force
            $resourcePath = Join-Path -Path $culturePath -ChildPath 'Demo.strings.psd1'
            Set-Content -Path $resourcePath -Value '@{}'
        }
    }

    It 'Should require a localization resource name' {
        $command = Get-Command -Name Resolve-PSULocalizationLanguage -Module $script:moduleName

        $command.Parameters.Name.Attributes.Mandatory | Should -Contain $true
    }

    It 'Should prefer an explicit language over the request header' {
        $parameters = @{
            ModuleBase        = $script:moduleBase
            Name              = 'Demo'
            PreferredLanguage = 'fr'
            AcceptLanguage    = 'en-US,en;q=0.9'
        }
        $result = synedgy.universal.helper\Resolve-PSULocalizationLanguage @parameters

        $result | Should -Be 'fr'
    }

    It 'Should resolve the most specific available request culture' {
        $parameters = @{
            ModuleBase     = $script:moduleBase
            Name           = 'Demo'
            AcceptLanguage = 'fr-CH,fr;q=0.9,en;q=0.8'
        }
        $result = synedgy.universal.helper\Resolve-PSULocalizationLanguage @parameters

        $result | Should -Be 'fr-CH'
    }

    It 'Should honor request quality values' {
        $parameters = @{
            ModuleBase     = $script:moduleBase
            Name           = 'Demo'
            AcceptLanguage = 'fr;q=0.4,en-US;q=0.9'
        }
        $result = synedgy.universal.helper\Resolve-PSULocalizationLanguage @parameters

        $result | Should -Be 'en'
    }

    It 'Should discover the consuming module base during parameter binding' {
        $moduleScriptPath = Join-Path -Path $script:moduleBase -ChildPath 'LocalizationCaller.psm1'
        Set-Content -Path $moduleScriptPath -Value @'
function Resolve-CallerLocalizationLanguage
{
    Resolve-PSULocalizationLanguage -Name 'Demo' -AcceptLanguage 'fr-CH,fr;q=0.9'
}
Export-ModuleMember -Function Resolve-CallerLocalizationLanguage
'@
        Import-Module -Name $moduleScriptPath -Force

        try
        {
            Resolve-CallerLocalizationLanguage | Should -Be 'fr-CH'
        }
        finally
        {
            Remove-Module -Name 'LocalizationCaller' -ErrorAction SilentlyContinue
        }
    }

    It 'Should use the configured default when no preference is supported' {
        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'Demo'
            AcceptLanguage   = 'de-DE,de;q=0.9'
            DefaultUILanguage = 'fr'
        }
        $result = synedgy.universal.helper\Resolve-PSULocalizationLanguage @parameters

        $result | Should -Be 'fr'
    }

    It 'Should reject a default without a localization resource' {
        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'Demo'
            DefaultUILanguage = 'de'
        }

        {
            synedgy.universal.helper\Resolve-PSULocalizationLanguage @parameters
        } | Should -Throw "*Default UI language 'de' is not available for 'Demo'*"
    }
}
