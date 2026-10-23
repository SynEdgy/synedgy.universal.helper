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

Describe 'Initialize-PSULocalizationCache' {
    BeforeEach {
        $script:moduleBase = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid().Guid)
        foreach ($language in @('en', 'fr'))
        {
            $culturePath = Join-Path -Path $script:moduleBase -ChildPath $language
            $null = New-Item -Path $culturePath -ItemType Directory -Force
            $resourcePath = Join-Path -Path $culturePath -ChildPath 'Demo.strings.psd1'
            Set-Content -Path $resourcePath -Value ("@{{ Message = 'Message {0}' }}" -f $language)
        }
    }

    It 'Should require a localization resource name' {
        $command = Get-Command -Name Initialize-PSULocalizationCache -Module $script:moduleName

        $command.Parameters.Name.Attributes.Mandatory | Should -Contain $true
    }

    It 'Should load every resource language and replace the supplied cache' {
        $cache = [System.Collections.Hashtable]::Synchronized(@{
            stale = @{
                Message = 'Stale'
            }
        })
        $parameters = @{
            ModuleBase = $script:moduleBase
            Name       = 'Demo'
            Cache      = $cache
            Force      = $true
        }
        $result = synedgy.universal.helper\Initialize-PSULocalizationCache @parameters

        @($result.Keys).Count | Should -Be 2
        $result.en.Message | Should -Be 'Message en'
        $result.fr.Message | Should -Be 'Message fr'
        $cache.Contains('stale') | Should -BeFalse
        $cache.en.Message | Should -Be 'Message en'
        $cache.fr.Message | Should -Be 'Message fr'
    }

    It 'Should discover the consuming module base during parameter binding' {
        $moduleScriptPath = Join-Path -Path $script:moduleBase -ChildPath 'LocalizationCaller.psm1'
        Set-Content -Path $moduleScriptPath -Value @'
function Initialize-CallerLocalization
{
    Initialize-PSULocalizationCache -Name 'Demo'
}
Export-ModuleMember -Function Initialize-CallerLocalization
'@
        Import-Module -Name $moduleScriptPath -Force

        try
        {
            $result = Initialize-CallerLocalization

            $result.en.Message | Should -Be 'Message en'
            $result.fr.Message | Should -Be 'Message fr'
        }
        finally
        {
            Remove-Module -Name 'LocalizationCaller' -ErrorAction SilentlyContinue
        }
    }

    It 'Should reject an explicitly supplied null cache' {
        $parameters = @{
            ModuleBase = $script:moduleBase
            Name       = 'Demo'
            Cache      = $null
        }

        {
            synedgy.universal.helper\Initialize-PSULocalizationCache @parameters
        } | Should -Throw '*cache dictionary cannot be null*'
    }
}
