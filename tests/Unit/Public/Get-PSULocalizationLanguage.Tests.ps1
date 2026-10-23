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

Describe 'Get-PSULocalizationLanguage' {
    It 'Should discover sorted culture folders containing the requested resource' {
        $moduleBase = Join-Path -Path $TestDrive -ChildPath 'ExplicitModule'
        foreach ($language in @('fr', 'de-CH', 'en'))
        {
            $culturePath = Join-Path -Path $moduleBase -ChildPath $language
            $null = New-Item -Path $culturePath -ItemType Directory -Force
            $resourcePath = Join-Path -Path $culturePath -ChildPath 'Demo.strings.psd1'
            Set-Content -Path $resourcePath -Value '@{}'
        }

        $ignoredPath = Join-Path -Path $moduleBase -ChildPath 'images'
        $null = New-Item -Path $ignoredPath -ItemType Directory -Force

        $result = @(
            synedgy.universal.helper\Get-PSULocalizationLanguage -ModuleBase $moduleBase -Name 'Demo'
        )

        $result | Should -Be @('de-CH', 'en', 'fr')
    }

    It 'Should resolve ModuleBase from the consuming module call stack' {
        $moduleBase = Join-Path -Path $TestDrive -ChildPath 'CallerModule'
        $null = New-Item -Path $moduleBase -ItemType Directory -Force
        foreach ($language in @('en', 'fr'))
        {
            $culturePath = Join-Path -Path $moduleBase -ChildPath $language
            $null = New-Item -Path $culturePath -ItemType Directory -Force
            Set-Content -Path (Join-Path -Path $culturePath -ChildPath 'Demo.strings.psd1') -Value '@{}'
        }

        $moduleScriptPath = Join-Path -Path $moduleBase -ChildPath 'CallerModule.psm1'
        Set-Content -Path $moduleScriptPath -Value @'
function Get-CallerLanguage
{
    Get-PSULocalizationLanguage -Name 'Demo'
}
Export-ModuleMember -Function Get-CallerLanguage
'@
        Import-Module -Name $moduleScriptPath -Force

        try
        {
            @(Get-CallerLanguage) | Should -Be @('en', 'fr')
        }
        finally
        {
            Remove-Module -Name 'CallerModule' -ErrorAction SilentlyContinue
        }
    }

    It 'Should discover cultures with resources in nested folders' {
        $moduleBase = Join-Path -Path $TestDrive -ChildPath 'NestedModule'
        foreach ($language in @('en', 'fr'))
        {
            $resourcePath = Join-Path -Path $moduleBase -ChildPath $language
            $resourcePath = Join-Path -Path $resourcePath -ChildPath 'Pages\Home'
            $null = New-Item -Path $resourcePath -ItemType Directory -Force
            Set-Content -Path (
                Join-Path -Path $resourcePath -ChildPath 'Demo.strings.psd1'
            ) -Value '@{}'
        }

        $result = @(
            synedgy.universal.helper\Get-PSULocalizationLanguage -ModuleBase $moduleBase -Name 'Demo'
        )

        $result | Should -Be @('en', 'fr')
    }

    It 'Should throw when the requested resource is unavailable' {
        $moduleBase = Join-Path -Path $TestDrive -ChildPath 'EmptyModule'
        $null = New-Item -Path $moduleBase -ItemType Directory -Force

        {
            synedgy.universal.helper\Get-PSULocalizationLanguage -ModuleBase $moduleBase -Name 'Demo'
        } | Should -Throw
    }
}
