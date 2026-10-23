BeforeAll {
    $script:moduleName = 'synedgy.universal.helper'

    if (-not (Get-Module -Name $script:moduleName -ListAvailable))
    {
        & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
    }

    Import-Module -Name $script:moduleName -Force -ErrorAction Stop

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

Describe 'Get-PSUComponentLocalizedData' {
    BeforeEach {
        $script:moduleBase = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid().Guid)
        $null = New-Item -Path $script:moduleBase -ItemType Directory -Force

        foreach ($culture in @('en', 'fr'))
        {
            $culturePath = Join-Path -Path $script:moduleBase -ChildPath $culture
            $null = New-Item -Path $culturePath -ItemType Directory -Force
            $resourcePath = Join-Path -Path $culturePath -ChildPath 'Test.Component.strings.psd1'
            $message = if ($culture -eq 'fr') { 'Francais' } else { 'English' }
            Set-Content -Path $resourcePath -Value ("@{{ Message = '{0}' }}" -f $message)
        }
    }

    It 'Should use the requested resource-backed language' {
        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'Test.Component'
            Language         = 'fr-CH'
            DefaultUILanguage = 'en'
        }

        $result = Get-PSUComponentLocalizedData @parameters

        $result.Message | Should -Be 'Francais'
    }

    It 'Should use the configured module default when the requested language is unavailable' {
        $parameters = @{
            ModuleBase        = $script:moduleBase
            Name              = 'Test.Component'
            Language          = 'de'
            DefaultUILanguage = 'fr'
        }

        $result = Get-PSUComponentLocalizedData @parameters

        $result.Message | Should -Be 'Francais'
    }

    It 'Should fall back to English when the configured module default is unavailable' {
        $parameters = @{
            ModuleBase        = $script:moduleBase
            Name              = 'Test.Component'
            Language          = 'de'
            DefaultUILanguage = 'es'
        }

        $result = Get-PSUComponentLocalizedData @parameters

        $result.Message | Should -Be 'English'
    }

    It 'Should populate and reuse a supplied shared cache' {
        $cache = [System.Collections.Hashtable]::Synchronized(@{})
        $parameters = @{
            ModuleBase        = $script:moduleBase
            Name              = 'Test.Component'
            Language          = 'fr'
            DefaultUILanguage = 'en'
            Cache             = $cache
        }

        $firstResult = Get-PSUComponentLocalizedData @parameters
        $firstResult.Message = 'Modified'
        $secondResult = Get-PSUComponentLocalizedData @parameters

        $cache.Count | Should -Be 1
        $secondResult.Message | Should -Be 'Francais'
    }

    It 'Should discover the consuming module base during parameter binding' {
        $moduleScriptPath = Join-Path -Path $script:moduleBase -ChildPath 'ComponentCaller.psm1'
        Set-Content -Path $moduleScriptPath -Value @'
function Get-CallerComponentStrings
{
    Get-PSUComponentLocalizedData -Name 'Test.Component' -Language 'fr' -DefaultUILanguage 'en'
}
Export-ModuleMember -Function Get-CallerComponentStrings
'@
        Import-Module -Name $moduleScriptPath -Force

        try
        {
            $result = Get-CallerComponentStrings
            $result.Message | Should -Be 'Francais'
        }
        finally
        {
            Remove-Module -Name 'ComponentCaller' -ErrorAction SilentlyContinue
        }
    }
}
