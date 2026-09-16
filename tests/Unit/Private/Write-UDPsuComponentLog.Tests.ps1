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

Describe 'Write-UDPsuComponentLog' {
    It 'Should write a structured event to PSU logging' {
        InModuleScope -ScriptBlock {
            function Write-PSULog
            {
                param($Level, $Feature, $Resource, $Message, $Properties)
            }

            Mock -CommandName Write-PSULog

            Write-UDPsuComponentLog -Level Warning -Resource 'terminal-1' -Message 'Live output unavailable.' -Properties @{
                JobId = 10494
            }

            Should -Invoke -CommandName Write-PSULog -Exactly -Times 1 -Scope It -ParameterFilter {
                $Level -eq 'Warning' -and
                $Feature -eq 'App' -and
                $Resource -eq 'terminal-1' -and
                $Message -eq 'Live output unavailable.' -and
                $Properties.JobId -eq 10494
            }
        }
    }

    It 'Should warn without throwing when PSU logging is unavailable' {
        InModuleScope -ScriptBlock {
            Mock -CommandName Get-Command -ParameterFilter { $Name -eq 'Write-PSULog' }
            Mock -CommandName Write-Warning

            {
                Write-UDPsuComponentLog -Level Error -Resource 'terminal-1' -Message 'Rendering failed.'
            } | Should -Not -Throw

            Should -Invoke -CommandName Write-Warning -Exactly -Times 1 -Scope It
        }
    }
}
