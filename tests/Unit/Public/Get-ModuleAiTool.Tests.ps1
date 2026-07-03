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

    # A disposable module, decorated with [AiTool()], used to exercise attribute discovery
    # end-to-end without depending on any real consuming module.
    $script:testModuleName = 'AiToolDiscoveryTestModule'
    New-Module -Name $script:testModuleName -ScriptBlock {
        function Test-AiToolSampleCommand
        {
            <#
                .SYNOPSIS
                Sample synopsis used to validate default Description discovery.
            #>
            [CmdletBinding()]
            [AiTool(
                Role = ('admin','user')
            )]
            param
            (
                [Parameter()]
                [System.String]
                $Name
            )

            $Name
        }

        function Test-AiToolNamedCommand
        {
            [CmdletBinding()]
            [AiTool(
                Name           = 'CustomToolName',
                Description    = 'Custom description',
                Authenticated  = $true,
                Mcp            = $false,
                Environment    = 'CustomEnv'
            )]
            param ()
        }

        Export-ModuleMember -Function 'Test-AiToolSampleCommand', 'Test-AiToolNamedCommand'
    } | Import-Module -Force -Global
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:testModuleName -ErrorAction SilentlyContinue
    Remove-Module -Name $script:moduleName
}

Describe 'Get-ModuleAiTool' {
    It 'Should discover a function decorated with [AiTool()] in the target module' {
        $results = Get-ModuleAiTool -Module $script:testModuleName

        $results | Should -Not -BeNullOrEmpty
        @($results).Count | Should -Be 2
    }

    It 'Should default Name to the function name when not set on the attribute' {
        $result = Get-ModuleAiTool -Module $script:testModuleName |
            Where-Object { $_.FunctionInfo.Name -eq 'Test-AiToolSampleCommand' }

        $result.Name | Should -Be 'Test-AiToolSampleCommand'
    }

    It 'Should build ScriptFullPath as the module name and function name joined by a backslash' {
        $result = Get-ModuleAiTool -Module $script:testModuleName |
            Where-Object { $_.FunctionInfo.Name -eq 'Test-AiToolSampleCommand' }

        $result.ScriptFullPath | Should -Be ('{0}\Test-AiToolSampleCommand' -f $script:testModuleName)
    }

    It 'Should default Description from comment-based help synopsis when not set on the attribute' {
        $result = Get-ModuleAiTool -Module $script:testModuleName |
            Where-Object { $_.FunctionInfo.Name -eq 'Test-AiToolSampleCommand' }

        $result.Description | Should -Match 'Sample synopsis'
    }

    It 'Should default Mcp to $true when not set on the attribute' {
        $result = Get-ModuleAiTool -Module $script:testModuleName |
            Where-Object { $_.FunctionInfo.Name -eq 'Test-AiToolSampleCommand' }

        $result.Mcp | Should -BeTrue
    }

    It 'Should default Authenticated to $false when not set on the attribute' {
        $result = Get-ModuleAiTool -Module $script:testModuleName |
            Where-Object { $_.FunctionInfo.Name -eq 'Test-AiToolSampleCommand' }

        $result.Authenticated | Should -BeFalse
    }

    It 'Should surface Role set on the attribute' {
        $result = Get-ModuleAiTool -Module $script:testModuleName |
            Where-Object { $_.FunctionInfo.Name -eq 'Test-AiToolSampleCommand' }

        $result.Role | Should -Contain 'admin'
    }

    It 'Should honor explicit Name, Description, Authenticated, Mcp, and Environment set on the attribute' {
        $result = Get-ModuleAiTool -Module $script:testModuleName |
            Where-Object { $_.FunctionInfo.Name -eq 'Test-AiToolNamedCommand' }

        $result.Name | Should -Be 'CustomToolName'
        $result.Description | Should -Be 'Custom description'
        $result.Authenticated | Should -BeTrue
        $result.Mcp | Should -BeFalse
        $result.Environment | Should -Be 'CustomEnv'
    }
}
