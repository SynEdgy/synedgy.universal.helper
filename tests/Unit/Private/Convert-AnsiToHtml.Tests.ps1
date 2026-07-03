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

Describe 'Convert-AnsiToHtml' {
    It 'Should return plain HTML when no ANSI codes are present' {
        InModuleScope -ScriptBlock {
            $result = Convert-AnsiToHtml -Message 'Hello World'
            $result | Should -Be 'Hello World'
        }
    }

    It 'Should wrap colored text in a span with inline style' {
        InModuleScope -ScriptBlock {
            $esc = [char]27
            $result = Convert-AnsiToHtml -Message "${esc}[32mSuccess${esc}[0m"
            $result | Should -Match 'color:#66bb6a'
            $result | Should -Match 'Success'
        }
    }

    It 'Should reset color on SGR 0' {
        InModuleScope -ScriptBlock {
            $esc = [char]27
            $result = Convert-AnsiToHtml -Message "${esc}[31mRed${esc}[0m Normal"
            $result | Should -Match 'Normal'
            # Text after reset should not be inside a color span
            $result | Should -Not -Match 'Normal</span>'
        }
    }

    It 'Should accept pipeline input' {
        InModuleScope -ScriptBlock {
            $result = 'plain text' | Convert-AnsiToHtml
            $result | Should -Be 'plain text'
        }
    }

    It 'Should return empty string for empty input' {
        InModuleScope -ScriptBlock {
            $result = Convert-AnsiToHtml -Message ''
            $result | Should -Be ''
        }
    }
}
