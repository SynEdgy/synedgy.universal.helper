BeforeAll {
    $script:moduleName = 'synedgy.universal.helper'

    # If the module is not found, run the build task 'noop'.
    if (-not (Get-Module -Name $script:moduleName -ListAvailable))
    {
        # Redirect all streams to $null, except the error stream (stream 2)
        & "$PSScriptRoot/../../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
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

Describe 'New-UDLanguageSelector' {
    It 'Should expose discovery, display, cookie, and styling parameters' {
        $command = Get-Command -Name New-UDLanguageSelector -Module $script:moduleName -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'Language'
        $command.Parameters.Keys | Should -Contain 'Name'
        $command.Parameters.Keys | Should -Contain 'ModuleBase'
        $command.Parameters.Keys | Should -Contain 'LanguageDisplayName'
        $command.Parameters.Keys | Should -Contain 'ClassName'
        $command.Parameters.Keys | Should -Contain 'CookieName'
        $command.Parameters.Keys | Should -Contain 'CookieMaxAge'
        $command.Parameters.Keys | Should -Contain 'UseLanguageLabel'
        $command.Parameters.Keys | Should -Contain 'UseNativeLanguageName'
        $command.Parameters.Keys | Should -Contain 'Sx'
        $command.Parameters.Keys | Should -Contain 'WhatIf'
    }

    It 'Should resolve option display names through the culture helper' {
        $command = Get-Command -Name New-UDLanguageSelector -Module $script:moduleName -ErrorAction Stop
        $commandSource = $command.ScriptBlock.ToString()

        $commandSource | Should -Match 'Get-PSULanguageDisplayName @displayNameParameters'
        $commandSource | Should -Match 'UseNativeLanguageName\s+= \$UseNativeLanguageName'
    }

    It 'Should reject native names combined with compact labels' {
        InModuleScope -ScriptBlock {
            $selectorParameters = @{
                Language              = 'en'
                Name                  = 'Demo'
                UseLanguageLabel      = $true
                UseNativeLanguageName = $true
            }

            {
                New-UDLanguageSelector @selectorParameters
            } | Should -Throw '*cannot be combined*'
        }
    }

    It 'Should discover languages before rendering the selector' {
        $command = Get-Command -Name New-UDLanguageSelector -Module $script:moduleName -ErrorAction Stop
        $commandSource = $command.ScriptBlock.ToString()

        $commandSource | Should -Match 'Get-PSULocalizationLanguage @languageParameters'
        $commandSource | Should -Match 'New-UDSelect @selectParameters'
        $commandSource | Should -Match 'document\.cookie'
        $commandSource | Should -Match 'window\.location\.reload'
    }

    It 'Should validate the selected language against discovered resources' {
        $moduleBase = Join-Path -Path $TestDrive -ChildPath 'SelectorModule'
        $culturePath = Join-Path -Path $moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $culturePath -ChildPath 'Demo.strings.psd1') -Value '@{}'

        $selectorParameters = @{
            Language   = 'fr'
            Name       = 'Demo'
            ModuleBase = $moduleBase
            Confirm    = $false
        }

        {
            synedgy.universal.helper\New-UDLanguageSelector @selectorParameters
        } | Should -Throw
    }

    It 'Should support discovery without rendering when WhatIf is used' {
        $moduleBase = Join-Path -Path $TestDrive -ChildPath 'WhatIfModule'
        $culturePath = Join-Path -Path $moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $culturePath -ChildPath 'Demo.strings.psd1') -Value '@{}'

        $selectorParameters = @{
            Language   = 'en'
            Name       = 'Demo'
            ModuleBase = $moduleBase
        }

        synedgy.universal.helper\New-UDLanguageSelector @selectorParameters -WhatIf |
            Should -BeNullOrEmpty
    }

    It 'Should resolve ModuleBase from the caller during parameter binding' {
        $moduleBase = Join-Path -Path $TestDrive -ChildPath 'SelectorCallerModule'
        $null = New-Item -Path $moduleBase -ItemType Directory -Force
        $culturePath = Join-Path -Path $moduleBase -ChildPath 'en'
        $null = New-Item -Path $culturePath -ItemType Directory -Force
        Set-Content -Path (Join-Path -Path $culturePath -ChildPath 'Demo.strings.psd1') -Value '@{}'

        $moduleScriptPath = Join-Path -Path $moduleBase -ChildPath 'SelectorCallerModule.psm1'
        Set-Content -Path $moduleScriptPath -Value @'
function Test-LanguageSelectorCaller
{
    New-UDLanguageSelector -Language 'en' -Name 'Demo' -WhatIf
}
Export-ModuleMember -Function Test-LanguageSelectorCaller
'@
        Import-Module -Name $moduleScriptPath -Force

        try
        {
            { Test-LanguageSelectorCaller } | Should -Not -Throw
        }
        finally
        {
            Remove-Module -Name 'SelectorCallerModule' -ErrorAction SilentlyContinue
        }
    }
}
