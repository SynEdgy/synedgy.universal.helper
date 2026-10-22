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

    $script:testModuleName = 'EndpointAutoImportTestModule'
    $script:testModuleRoot = Join-Path -Path $TestDrive -ChildPath $script:testModuleName
    $null = New-Item -Path $script:testModuleRoot -ItemType Directory -Force

    $script:testModuleManifest = Join-Path -Path $script:testModuleRoot -ChildPath "$($script:testModuleName).psd1"
    $testModuleFile = Join-Path -Path $script:testModuleRoot -ChildPath "$($script:testModuleName).psm1"

    @'
function Get-AutoImportedEndpoint
{
    [CmdletBinding()]
    [APIEndpoint(
        Path = '/auto-import',
        Method = 'GET'
    )]
    param ()
}

Export-ModuleMember -Function 'Get-AutoImportedEndpoint'
'@ | Set-Content -Path $testModuleFile -Encoding utf8

    $manifestParameters = @{
        Path              = $script:testModuleManifest
        RootModule        = "$($script:testModuleName).psm1"
        ModuleVersion     = '1.0.0'
        FunctionsToExport = @('Get-AutoImportedEndpoint')
    }
    New-ModuleManifest @manifestParameters
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:testModuleName -Force -ErrorAction SilentlyContinue
    Remove-Module -Name $script:moduleName
}

Describe 'Get-ModuleApiEndpoint' {
    BeforeEach {
        Remove-Module -Name $script:testModuleName -Force -ErrorAction SilentlyContinue
    }

    It 'Should import the target module before discovering endpoints' {
        Get-Module -Name $script:testModuleName | Should -BeNullOrEmpty

        $result = synedgy.universal.helper\Get-ModuleApiEndpoint -Module $script:testModuleManifest

        Get-Module -Name $script:testModuleName | Should -Not -BeNullOrEmpty
        Get-Command -Name 'Get-AutoImportedEndpoint' -ErrorAction Stop | Should -Not -BeNullOrEmpty
        @($result).Count | Should -Be 1
        $result.FunctionInfo.Name | Should -Be 'Get-AutoImportedEndpoint'
        $result.Url | Should -Be '/api/v1/auto-import'
    }

    It 'Should allow Import-PSUEndpoint to discover a module that was not already loaded' {
        Mock -CommandName 'Get-Command' -ParameterFilter {
            $Name -eq 'New-PSUEndpoint' -and $Module -eq 'Universal'
        } -MockWith {
            [pscustomobject] @{
                Parameters = @{
                    Authentication = $null
                    Description    = $null
                    Endpoint       = $null
                    Method         = $null
                    Url            = $null
                }
            }
        }

        Get-Module -Name $script:testModuleName | Should -BeNullOrEmpty

        $importParameters = @{
            Module      = $script:testModuleManifest
            WhatIf      = $true
            ErrorAction = 'Stop'
        }
        {
            synedgy.universal.helper\Import-PSUEndpoint @importParameters
        } | Should -Not -Throw

        Get-Module -Name $script:testModuleName | Should -Not -BeNullOrEmpty
        Should -Invoke -CommandName 'Get-Command' -Exactly -Times 1 -Scope It
    }
}
