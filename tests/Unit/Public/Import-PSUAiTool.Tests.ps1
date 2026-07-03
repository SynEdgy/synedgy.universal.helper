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

    # A disposable module, decorated with [AiTool()], used to exercise Import-PSUAiTool's
    # discovery + -WhatIf path without requiring the real PowerShellUniversal 'Universal'
    # module (New-PSUScript/New-PSUAiTool) to be installed. -WhatIf short-circuits those
    # calls via ShouldProcess, so this only validates discovery/orchestration, not the
    # actual PSU resource registration.
    $script:testModuleName = 'ImportPSUAiToolTestModule'
    New-Module -Name $script:testModuleName -ScriptBlock {
        function Test-ImportAiToolSampleCommand
        {
            <#
                .SYNOPSIS
                Sample command used to validate Import-PSUAiTool discovery.
            #>
            [CmdletBinding()]
            [AiTool()]
            param ()
        }

        Export-ModuleMember -Function 'Test-ImportAiToolSampleCommand'
    } | Import-Module -Force -Global
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:testModuleName -ErrorAction SilentlyContinue
    Remove-Module -Name $script:moduleName
}

Describe 'Import-PSUAiTool' {
    It 'Should be available as an exported command' {
        $command = Get-Command -Name Import-PSUAiTool -Module $script:moduleName -ErrorAction Stop

        $command | Should -Not -BeNullOrEmpty
    }

    It 'Should support ShouldProcess' {
        $command = Get-Command -Name Import-PSUAiTool -Module $script:moduleName -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'Confirm'
        $command.Parameters.Keys | Should -Contain 'WhatIf'
    }

    It 'Should expose Module, Environment, Authenticated, and Mcp parameters' {
        $command = Get-Command -Name Import-PSUAiTool -Module $script:moduleName -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'Module'
        $command.Parameters.Keys | Should -Contain 'Environment'
        $command.Parameters.Keys | Should -Contain 'Authenticated'
        $command.Parameters.Keys | Should -Contain 'Mcp'
    }

    It 'Should discover the decorated function and not throw when run with -WhatIf' {
        {
            synedgy.universal.helper\Import-PSUAiTool -Module $script:testModuleName -WhatIf -ErrorAction Stop
        } | Should -Not -Throw
    }

    It 'Should not overwrite an already-existing backing PSU Script' {
        InModuleScope -Parameters @{ TestModuleName = $script:testModuleName } -ScriptBlock {
            param($TestModuleName)

            # Stub functions for the real PowerShell Universal 'Universal' module cmdlets,
            # which are not installed in this test environment (build agents don't have
            # PSU installed). These must be defined here, in this same InModuleScope
            # invocation, immediately before Mock -- function definitions from a separate
            # InModuleScope call do not persist into this one, and Pester's Mock cannot
            # create a mock for a command that isn't resolvable at all.
            function Get-PSUScript { [CmdletBinding()] param([string] $Name) }
            function New-PSUScript { [CmdletBinding()] param([object] $Module, [string] $Command, [string] $Environment) }
            function New-PSUAiTool { [CmdletBinding()] param([string] $Name, [string] $Description, [string] $ScriptFullPath, [bool] $Authenticated, [string[]] $Role, [bool] $Mcp) }

            Mock -CommandName 'Get-PSUScript' -MockWith { [pscustomobject]@{ FullPath = 'ImportPSUAiToolTestModule\Test-ImportAiToolSampleCommand' } }
            Mock -CommandName 'New-PSUScript' -MockWith { }
            Mock -CommandName 'New-PSUAiTool' -MockWith { }

            Import-PSUAiTool -Module $TestModuleName -Confirm:$false

            Should -Invoke -CommandName 'Get-PSUScript' -Times 1 -Exactly
            Should -Invoke -CommandName 'New-PSUScript' -Times 0 -Exactly
            Should -Invoke -CommandName 'New-PSUAiTool' -Times 1 -Exactly
        }
    }

    It 'Should create a backing PSU Script when one does not already exist' {
        InModuleScope -Parameters @{ TestModuleName = $script:testModuleName } -ScriptBlock {
            param($TestModuleName)

            function Get-PSUScript { [CmdletBinding()] param([string] $Name) }
            function New-PSUScript { [CmdletBinding()] param([object] $Module, [string] $Command, [string] $Environment) }
            function New-PSUAiTool { [CmdletBinding()] param([string] $Name, [string] $Description, [string] $ScriptFullPath, [bool] $Authenticated, [string[]] $Role, [bool] $Mcp) }

            Mock -CommandName 'Get-PSUScript' -MockWith { $null }
            Mock -CommandName 'New-PSUScript' -MockWith { }
            Mock -CommandName 'New-PSUAiTool' -MockWith { }

            Import-PSUAiTool -Module $TestModuleName -Confirm:$false

            Should -Invoke -CommandName 'Get-PSUScript' -Times 1 -Exactly
            Should -Invoke -CommandName 'New-PSUScript' -Times 1 -Exactly
            Should -Invoke -CommandName 'New-PSUAiTool' -Times 1 -Exactly
        }
    }
}
