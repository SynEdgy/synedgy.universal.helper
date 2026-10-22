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

Describe 'Get-PSULocalizedData' {
    BeforeEach {
        $script:moduleBase = Join-Path -Path $TestDrive -ChildPath ([System.Guid]::NewGuid().Guid)
        $null = New-Item -Path $script:moduleBase -ItemType Directory -Force
    }

    It 'Should merge default, parent, and exact dictionaries by key' {
        $resources = @{
            en      = "@{ Title = 'English title'; Lead = 'English lead'; Region = 'Default region' }"
            fr      = "@{ Title = 'Titre francais' }"
            'fr-CH' = "@{ Region = 'Suisse' }"
        }

        foreach ($culture in $resources.Keys)
        {
            $culturePath = Join-Path -Path $script:moduleBase -ChildPath $culture
            $null = New-Item -Path $culturePath -ItemType Directory -Force
            $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
            Set-Content -Path $resourcePath -Value $resources[$culture]
        }

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'fr-CH'
            DefaultUICulture = 'en'
        }
        $result = synedgy.universal.helper\Get-PSULocalizedData @parameters

        $result.Title | Should -Be 'Titre francais'
        $result.Lead | Should -Be 'English lead'
        $result.Region | Should -Be 'Suisse'
    }

    It 'Should retain default values when the requested dictionary is partial' {
        $defaultPath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $frenchPath = Join-Path -Path $script:moduleBase -ChildPath 'fr'
        $null = New-Item -Path $defaultPath -ItemType Directory -Force
        $null = New-Item -Path $frenchPath -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $defaultPath -ChildPath 'TestModule.strings.psd1') -Value "@{ Title = 'Title'; Lead = 'Lead' }"
        Set-Content -Path (Join-Path -Path $frenchPath -ChildPath 'TestModule.strings.psd1') -Value "@{ Title = 'Titre' }"

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'fr'
            DefaultUICulture = 'en'
        }
        $result = synedgy.universal.helper\Get-PSULocalizedData @parameters

        $result.Title | Should -Be 'Titre'
        $result.Lead | Should -Be 'Lead'
    }

    It 'Should throw when a resource is not a valid data file' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value 'this is not a data file'

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'en'
            DefaultUICulture = 'en'
        }

        { synedgy.universal.helper\Get-PSULocalizedData @parameters } |
            Should -Throw '*Unable to import localization resource*'
    }

    It 'Should throw when a localization value is not a string' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value '@{ RetryCount = 3 }'

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'en'
            DefaultUICulture = 'en'
        }

        { synedgy.universal.helper\Get-PSULocalizedData @parameters } |
            Should -Throw '*must contain a string value*'
    }

    It 'Should throw when localization resources contain no strings' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value '@{}'

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'en'
            DefaultUICulture = 'en'
        }

        { synedgy.universal.helper\Get-PSULocalizedData @parameters } |
            Should -Throw '*did not contain any strings*'
    }

    It 'Should reuse module-cached strings without a shared cache' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value "@{ Message = 'Initial' }"

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'en'
            DefaultUICulture = 'en'
        }
        $initialResult = synedgy.universal.helper\Get-PSULocalizedData @parameters

        Set-Content -Path $resourcePath -Value "@{ Message = 'Updated' }"
        $cachedResult = synedgy.universal.helper\Get-PSULocalizedData @parameters
        $refreshedResult = synedgy.universal.helper\Get-PSULocalizedData @parameters -Force

        $initialResult.Message | Should -Be 'Initial'
        $cachedResult.Message | Should -Be 'Initial'
        $refreshedResult.Message | Should -Be 'Updated'
    }

    It 'Should populate the module cache from the shared cache before reading resources' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value "@{ Message = 'Initial' }"
        $cache = [System.Collections.Hashtable]::Synchronized(@{})

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'en'
            DefaultUICulture = 'en'
            Cache            = $cache
        }
        $initialResult = synedgy.universal.helper\Get-PSULocalizedData @parameters

        Set-Content -Path $resourcePath -Value "@{ Message = 'Updated' }"
        InModuleScope -ScriptBlock {
            (Get-Variable -Name 'localizedDataCache' -Scope Script -ValueOnly).Clear()
        }
        $cachedResult = synedgy.universal.helper\Get-PSULocalizedData @parameters
        $refreshedResult = synedgy.universal.helper\Get-PSULocalizedData @parameters -Force

        $initialResult.Message | Should -Be 'Initial'
        $cachedResult.Message | Should -Be 'Initial'
        $refreshedResult.Message | Should -Be 'Updated'
        $cache.Count | Should -Be 1
    }

    It 'Should prefer the module cache over the shared cache' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value "@{ Message = 'Module value' }"
        $cache = [System.Collections.Hashtable]::Synchronized(@{})

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'en'
            DefaultUICulture = 'en'
            Cache            = $cache
        }
        $null = synedgy.universal.helper\Get-PSULocalizedData @parameters
        $sharedCacheKey = @($cache.Keys)[0]
        $cache[$sharedCacheKey] = @{
            Message = 'Shared value'
        }

        $result = synedgy.universal.helper\Get-PSULocalizedData @parameters

        $result.Message | Should -Be 'Module value'
    }

    It 'Should return a clone so callers cannot modify cached strings' {
        $culturePath = Join-Path -Path $script:moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        $resourcePath = Join-Path -Path $culturePath -ChildPath 'TestModule.strings.psd1'
        Set-Content -Path $resourcePath -Value "@{ Message = 'Original' }"
        $cache = [System.Collections.Hashtable]::Synchronized(@{})

        $parameters = @{
            ModuleBase       = $script:moduleBase
            Name             = 'TestModule'
            UICulture        = 'en'
            DefaultUICulture = 'en'
            Cache            = $cache
        }
        $firstResult = synedgy.universal.helper\Get-PSULocalizedData @parameters
        $firstResult.Message = 'Modified'
        $secondResult = synedgy.universal.helper\Get-PSULocalizedData @parameters

        $secondResult.Message | Should -Be 'Original'
    }
}
