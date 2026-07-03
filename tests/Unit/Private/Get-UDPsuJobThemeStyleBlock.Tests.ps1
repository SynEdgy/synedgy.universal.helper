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

Describe 'Get-UDPsuJobThemePalette' {
    It 'Should return both a Light and a Dark palette' {
        InModuleScope -ScriptBlock {
            $palette = Get-UDPsuJobThemePalette

            $palette.Light | Should -Not -BeNullOrEmpty
            $palette.Dark | Should -Not -BeNullOrEmpty
        }
    }

    It 'Should define the same set of keys in both palettes' {
        InModuleScope -ScriptBlock {
            $palette = Get-UDPsuJobThemePalette

            $lightKeys = @($palette.Light.Keys | Sort-Object)
            $darkKeys  = @($palette.Dark.Keys | Sort-Object)

            Compare-Object -ReferenceObject $lightKeys -DifferenceObject $darkKeys | Should -BeNullOrEmpty
        }
    }

    It 'Should use white as the light background' {
        InModuleScope -ScriptBlock {
            (Get-UDPsuJobThemePalette).Light['bg'] | Should -Be '#ffffff'
        }
    }
}

Describe 'Get-UDPsuJobThemeStyleBlock' {
    It 'Should emit only a light rule when Theme is Light' {
        InModuleScope -ScriptBlock {
            $css = Get-UDPsuJobThemeStyleBlock -ElementId 'test-el' -Theme 'Light'

            $css | Should -Match '#test-el \{'
            $css | Should -Not -Match 'data-theme="dark"'
        }
    }

    It 'Should emit only a dark rule when Theme is Dark' {
        InModuleScope -ScriptBlock {
            $css = Get-UDPsuJobThemeStyleBlock -ElementId 'test-el' -Theme 'Dark'

            $css | Should -Match '--psu-term-bg:#111111'
            $css | Should -Not -Match 'data-theme="dark"'
        }
    }

    It 'Should emit both a light default and a dark override rule when Theme is Auto' {
        InModuleScope -ScriptBlock {
            $css = Get-UDPsuJobThemeStyleBlock -ElementId 'test-el' -Theme 'Auto'

            $css | Should -Match '#test-el \{ --psu-term-bg:#ffffff'
            $css | Should -Match 'html\[data-theme="dark"\] #test-el \{ --psu-term-bg:#111111'
        }
    }

    It 'Should append CustomCss after the theme rules' {
        InModuleScope -ScriptBlock {
            $css = Get-UDPsuJobThemeStyleBlock -ElementId 'test-el' -Theme 'Auto' -CustomCss '#test-el{color:red;}'

            $css.Contains('#test-el{color:red;}</style>') | Should -BeTrue
        }
    }
}

Describe 'ConvertTo-UDPsuThemedIconMarkup' {
    It 'Should render only the black icon when Theme is Light' {
        InModuleScope -ScriptBlock {
            $moduleBase = (Get-Module -Name synedgy.universal.helper).ModuleBase
            $markup = ConvertTo-UDPsuThemedIconMarkup -ModuleBase $moduleBase -IdPrefix 'test-lt' -Theme 'Light'

            $markup | Should -Not -BeNullOrEmpty
            $markup | Should -Not -Match 'psu-theme-light-only'
            $markup | Should -Not -Match 'psu-theme-dark-only'
        }
    }

    It 'Should render only the white icon when Theme is Dark' {
        InModuleScope -ScriptBlock {
            $moduleBase = (Get-Module -Name synedgy.universal.helper).ModuleBase
            $markup = ConvertTo-UDPsuThemedIconMarkup -ModuleBase $moduleBase -IdPrefix 'test-dk' -Theme 'Dark'

            $markup | Should -Not -BeNullOrEmpty
            $markup | Should -Not -Match 'psu-theme-light-only'
            $markup | Should -Not -Match 'psu-theme-dark-only'
        }
    }

    It 'Should render both variants wrapped for CSS toggling when Theme is Auto' {
        InModuleScope -ScriptBlock {
            $moduleBase = (Get-Module -Name synedgy.universal.helper).ModuleBase
            $markup = ConvertTo-UDPsuThemedIconMarkup -ModuleBase $moduleBase -IdPrefix 'test-auto' -Theme 'Auto'

            $markup | Should -Match 'psu-theme-light-only'
            $markup | Should -Match 'psu-theme-dark-only'
        }
    }
}
