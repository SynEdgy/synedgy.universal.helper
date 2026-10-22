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

Describe 'Get-PSULocalizationResourcePath' {
    BeforeEach {
        $script:moduleBase = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid().Guid)
        $script:culturePath = Join-Path -Path $script:moduleBase -ChildPath 'fr-CH'
        $null = New-Item -Path $script:culturePath -ItemType Directory -Force
    }

    It 'Should prefer the strings PSD1 resource' {
        $fallbackPath = Join-Path -Path $script:culturePath -ChildPath 'TestModule.psd1'
        $preferredPath = Join-Path -Path $script:culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $fallbackPath -Value '@{}'
        Set-Content -Path $preferredPath -Value '@{}'

        InModuleScope -Parameters @{
            ModuleBase   = $script:moduleBase
            ExpectedPath = $preferredPath
        } -ScriptBlock {
            $parameters = @{
                ModuleBase  = $ModuleBase
                Name        = 'TestModule'
                CultureName = 'fr-CH'
            }
            $result = Get-PSULocalizationResourcePath @parameters

            $result | Should -Be (Get-Item -LiteralPath $ExpectedPath).FullName
        }
    }

    It 'Should return the compatibility PSD1 resource when the preferred file is absent' {
        $fallbackPath = Join-Path -Path $script:culturePath -ChildPath 'TestModule.psd1'
        Set-Content -Path $fallbackPath -Value '@{}'

        InModuleScope -Parameters @{
            ModuleBase   = $script:moduleBase
            ExpectedPath = $fallbackPath
        } -ScriptBlock {
            $parameters = @{
                ModuleBase  = $ModuleBase
                Name        = 'TestModule'
                CultureName = 'fr-CH'
            }
            $result = Get-PSULocalizationResourcePath @parameters

            $result | Should -Be (Get-Item -LiteralPath $ExpectedPath).FullName
        }
    }

    It 'Should return no path when the culture resource is absent' {
        InModuleScope -Parameters @{
            ModuleBase = $script:moduleBase
        } -ScriptBlock {
            $parameters = @{
                ModuleBase  = $ModuleBase
                Name        = 'TestModule'
                CultureName = 'fr-CH'
            }
            $result = Get-PSULocalizationResourcePath @parameters

            $result | Should -BeNullOrEmpty
        }
    }
}
