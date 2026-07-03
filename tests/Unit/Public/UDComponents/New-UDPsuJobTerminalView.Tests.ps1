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

Describe 'New-UDPsuJobTerminalView' {
    It 'Should be available as an exported command' {
        $command = Get-Command -Name New-UDPsuJobTerminalView -Module $script:moduleName -ErrorAction Stop

        $command | Should -Not -BeNullOrEmpty
    }

    It 'Should expose the expected parameters' {
        $command = Get-Command -Name New-UDPsuJobTerminalView -Module $script:moduleName -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'JobId'
        $command.Parameters.Keys | Should -Contain 'AppToken'
        $command.Parameters.Keys | Should -Contain 'UniversalServerUrl'
        $command.Parameters.Keys | Should -Contain 'MaxRows'
        $command.Parameters.Keys | Should -Contain 'AutoRefreshInterval'
        $command.Parameters.Keys | Should -Contain 'JobStatus'
        $command.Parameters.Keys | Should -Contain 'IncludeStructuredTable'
        $command.Parameters.Keys | Should -Contain 'JobOutputSnapshot'
        $command.Parameters.Keys | Should -Contain 'ElementId'
    }

    It 'Should have AutoRefreshInterval default of 5' {
        InModuleScope -ScriptBlock {
            $fn   = Get-Command -Name New-UDPsuJobTerminalView
            $meta = $fn.ScriptBlock.Ast.Body.ParamBlock.Parameters |
                Where-Object { $_.Name.VariablePath.UserPath -eq 'AutoRefreshInterval' }

            $meta | Should -Not -BeNullOrEmpty
            # Default value is an integer literal; PSParser stores it as [int]
            [int]($meta.DefaultValue.Value) | Should -Be 5
        }
    }
}
