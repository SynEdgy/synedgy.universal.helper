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

Describe 'Convert-PlainTextToHtml' {
    It 'Should HTML-encode special characters' {
        InModuleScope -ScriptBlock {
            $result = Convert-PlainTextToHtml -Text 'Hello <World> & "you"'
            $result | Should -Be 'Hello &lt;World&gt; &amp; &quot;you&quot;'
        }
    }

    It 'Should strip ANSI escape sequences' {
        InModuleScope -ScriptBlock {
            $result = Convert-PlainTextToHtml -Text "`e[32mGreen`e[0m"
            $result | Should -Be 'Green'
        }
    }

    It 'Should convert newlines to HTML line breaks' {
        InModuleScope -ScriptBlock {
            $result = Convert-PlainTextToHtml -Text "Line1`nLine2"
            $result | Should -Be 'Line1<br/>Line2'
        }
    }

    It 'Should accept pipeline input' {
        InModuleScope -ScriptBlock {
            $result = 'A & B' | Convert-PlainTextToHtml
            $result | Should -Be 'A &amp; B'
        }
    }

    It 'Should return empty string for empty input' {
        InModuleScope -ScriptBlock {
            $result = Convert-PlainTextToHtml -Text ''
            $result | Should -Be ''
        }
    }
}
