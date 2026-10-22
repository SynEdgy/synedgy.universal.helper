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

Describe 'Resolve-PSULocalizationResource' {
    BeforeEach {
        $script:moduleBase = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid().Guid)
        $null = New-Item -Path $script:moduleBase -ItemType Directory -Force
    }

    It 'Should resolve default, parent, and exact resources in merge order' {
        foreach ($culture in @('en', 'fr', 'fr-CH'))
        {
            $culturePath = Join-Path -Path $script:moduleBase -ChildPath $culture
            $null = New-Item -Path $culturePath -ItemType Directory -Force
            $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
            Set-Content -Path $resourcePath -Value '@{ Message = ''Value'' }'
        }

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'fr-CH'
            DefaultUICulture = 'en'
        }
        $result = @(synedgy.universal.helper\Resolve-PSULocalizationResource @parameters)

        ($result.Culture -join ',') | Should -Be 'en,fr,fr-CH'
        ($result.Resolution -join ',') | Should -Be 'Default,Parent,Exact'
        ($result.Precedence -join ',') | Should -Be '0,1,2'
    }

    It 'Should return only the default resource when requested resources are absent' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value '@{ Message = ''Value'' }'

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'fr-CH'
            DefaultUICulture = 'en'
        }
        $result = @(synedgy.universal.helper\Resolve-PSULocalizationResource @parameters)

        $result.Count | Should -Be 1
        $result[0].Culture | Should -Be 'en'
    }

    It 'Should prefer the strings PSD1 resource name' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $culturePath -ChildPath 'TestModule.psd1') -Value '@{ Message = ''Fallback'' }'
        Set-Content -Path (Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1') -Value '@{ Message = ''Preferred'' }'

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'en'
            DefaultUICulture = 'en'
        }
        $result = @(synedgy.universal.helper\Resolve-PSULocalizationResource @parameters)

        $result[0].Path | Should -Match 'TestModule\.strings\.psd1$'
    }

    It 'Should support culture resolution when the process culture is invariant' {
        Mock -CommandName Get-UICulture -MockWith {
            [PSCustomObject] @{
                LCID = 127
                Name = ''
            }
        }

        foreach ($culture in @('en', 'fr', 'fr-CH'))
        {
            $culturePath = Join-Path -Path $script:moduleBase -ChildPath $culture
            $null = New-Item -Path $culturePath -ItemType Directory -Force
            $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
            Set-Content -Path $resourcePath -Value '@{ Message = ''Value'' }'
        }

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'fr-ch'
            DefaultUICulture = 'en'
        }
        $result = @(synedgy.universal.helper\Resolve-PSULocalizationResource @parameters)

        ($result.Culture -join ',') | Should -Be 'en,fr,fr-CH'
    }

    It 'Should throw when the default resource is missing' {
        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'fr'
            DefaultUICulture = 'en'
        }

        { synedgy.universal.helper\Resolve-PSULocalizationResource @parameters } |
            Should -Throw '*default culture*'
    }

    It 'Should throw for an invalid requested culture name' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value '@{ Message = ''Value'' }'

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'not_a_culture'
            DefaultUICulture = 'en'
        }

        { synedgy.universal.helper\Resolve-PSULocalizationResource @parameters } |
            Should -Throw '*not a valid localization culture name*'
    }
}
