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

Describe 'Get-UDPsuJobOutputWithFallback' {
    BeforeAll {
        function global:Get-PSUJobOutput
        {
            param($JobId, $AsObject, $ComputerName, $AppToken)
        }
    }

    AfterAll {
        Remove-Item -Path 'Function:\global:Get-PSUJobOutput'
    }

    It 'Should return live output without using the fallback' {
        Mock -CommandName Get-PSUJobOutput -MockWith {
            [PSCustomObject]@{ Message = 'live output' }
        }

        InModuleScope -ScriptBlock {
            $result = Get-UDPsuJobOutputWithFallback -JobId 10494 -UniversalServerUrl 'http://localhost:5000' -FallbackOutput @(
                [PSCustomObject]@{ Message = 'snapshot output' }
            )

            @($result.OutputRecords).Count | Should -Be 1
            $result.OutputRecords[0].Message | Should -Be 'live output'
            $result.UsedFallback | Should -BeFalse
            $result.ErrorMessage | Should -BeNullOrEmpty
        }
    }

    It 'Should return the snapshot and error when the live request fails' {
        Mock -CommandName Get-PSUJobOutput -MockWith {
            throw 'The PSU server is unavailable.'
        }

        InModuleScope -ScriptBlock {
            $result = Get-UDPsuJobOutputWithFallback -JobId 10494 -UniversalServerUrl 'http://localhost:5000' -FallbackOutput @(
                [PSCustomObject]@{ Message = 'snapshot output' }
            )

            @($result.OutputRecords).Count | Should -Be 1
            $result.OutputRecords[0].Message | Should -Be 'snapshot output'
            $result.UsedFallback | Should -BeTrue
            $result.ErrorMessage | Should -Be 'The PSU server is unavailable.'
        }
    }

    It 'Should return the snapshot when the live request returns no output' {
        Mock -CommandName Get-PSUJobOutput -MockWith {}

        InModuleScope -ScriptBlock {
            $result = Get-UDPsuJobOutputWithFallback -JobId 10494 -UniversalServerUrl 'http://localhost:5000' -FallbackOutput @(
                [PSCustomObject]@{ Message = 'snapshot output' }
            )

            @($result.OutputRecords).Count | Should -Be 1
            $result.OutputRecords[0].Message | Should -Be 'snapshot output'
            $result.UsedFallback | Should -BeTrue
            $result.ErrorMessage | Should -BeNullOrEmpty
        }
    }

    It 'Should redact the app token from a live request error' {
        Mock -CommandName Get-PSUJobOutput -MockWith {
            throw 'Request failed while using token secret-token-value.'
        }

        InModuleScope -ScriptBlock {
            $result = Get-UDPsuJobOutputWithFallback -JobId 10494 -AppToken 'secret-token-value' -UniversalServerUrl 'http://localhost:5000'

            $result.ErrorMessage | Should -Be 'Request failed while using token [REDACTED].'
            $result.ErrorMessage | Should -Not -Match 'secret-token-value'
        }
    }
}
