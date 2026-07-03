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

Describe 'New-UDPsuJobHeader' {
    It 'Should be available as an exported command' {
        $command = Get-Command -Name New-UDPsuJobHeader -Module $script:moduleName -ErrorAction Stop

        $command | Should -Not -BeNullOrEmpty
    }

    It 'Should expose a mandatory Job parameter' {
        $command = Get-Command -Name New-UDPsuJobHeader -Module $script:moduleName -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'Job'
        $command.Parameters['Job'].Attributes.Mandatory | Should -Contain $true
    }

    It 'Should expose ElementId, Theme, and CustomCss parameters' {
        $command = Get-Command -Name New-UDPsuJobHeader -Module $script:moduleName -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'ElementId'
        $command.Parameters.Keys | Should -Contain 'Theme'
        $command.Parameters.Keys | Should -Contain 'CustomCss'
    }

    It 'Should default Theme to Auto' {
        InModuleScope -ScriptBlock {
            $fn   = Get-Command -Name New-UDPsuJobHeader
            $meta = $fn.ScriptBlock.Ast.Body.ParamBlock.Parameters |
                Where-Object { $_.Name.VariablePath.UserPath -eq 'Theme' }

            $meta | Should -Not -BeNullOrEmpty
            $meta.DefaultValue.Value | Should -Be 'Auto'
        }
    }
}
