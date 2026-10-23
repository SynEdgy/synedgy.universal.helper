BeforeAll {
    $script:moduleName = 'synedgy.universal.helper'
    $script:projectPath = $PSScriptRoot

    while (-not (Test-Path -Path (Join-Path -Path $script:projectPath -ChildPath 'build.ps1')))
    {
        $parentPath = Split-Path -Path $script:projectPath -Parent

        if ($parentPath -eq $script:projectPath)
        {
            throw 'Could not locate repository root containing build.ps1.'
        }

        $script:projectPath = $parentPath
    }

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

    InModuleScope -ScriptBlock {
        if (-not (Get-Command -Name New-UDHtml -ErrorAction SilentlyContinue))
        {
            function script:New-UDHtml {}
        }
    }
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

    It 'Should expose styling and localization parameters' {
        $command = Get-Command -Name New-UDPsuJobHeader -Module $script:moduleName -ErrorAction Stop

        $command.Parameters.Keys | Should -Contain 'ElementId'
        $command.Parameters.Keys | Should -Contain 'Theme'
        $command.Parameters.Keys | Should -Contain 'CustomCss'
        $command.Parameters.Keys | Should -Contain 'Language'
        $command.Parameters.Keys | Should -Contain 'DefaultUILanguage'
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

    It 'Should default Language to English' {
        InModuleScope -ScriptBlock {
            $fn   = Get-Command -Name New-UDPsuJobHeader
            $meta = $fn.ScriptBlock.Ast.Body.ParamBlock.Parameters |
                Where-Object { $_.Name.VariablePath.UserPath -eq 'Language' }

            $meta | Should -Not -BeNullOrEmpty
            $meta.DefaultValue.Value | Should -Be 'en'
        }
    }

    It 'Should render French component labels and status text' {
        Mock -CommandName New-UDHtml -MockWith {
            param($Markup)

            $Markup
        }

        $job = [pscustomobject]@{
            Id             = 42
            ScriptFullPath = 'Demo\Invoke-Example'
            Status         = 'Completed'
            CreatedTime    = [datetime]'2026-10-23T10:00:00'
            StartTime      = [datetime]'2026-10-23T10:00:01'
            EndTime        = [datetime]'2026-10-23T10:00:03'
        }

        $markup = New-UDPsuJobHeader -Job $job -Language 'fr' -DefaultUILanguage 'en'

        $markup | Should -Match '&#201;tat'
        $markup | Should -Match 'Cr&#233;&#233;'
        $markup | Should -Match 'TERMIN&#201;'
        $markup | Should -Match 'Copi&#233;'
        $markup | Should -Match '&quot;Copi&#233; !&quot;'
    }

    It 'Should provide matching English, French, and German component resources' {
        $englishPath = Join-Path -Path $script:projectPath -ChildPath 'source\en\synedgy.universal.helper.PsuJobHeader.strings.psd1'
        $frenchPath = Join-Path -Path $script:projectPath -ChildPath 'source\fr\synedgy.universal.helper.PsuJobHeader.strings.psd1'
        $germanPath = Join-Path -Path $script:projectPath -ChildPath 'source\de\synedgy.universal.helper.PsuJobHeader.strings.psd1'

        $englishData = Import-PowerShellDataFile -LiteralPath $englishPath
        $frenchData = Import-PowerShellDataFile -LiteralPath $frenchPath
        $germanData = Import-PowerShellDataFile -LiteralPath $germanPath

        @($englishData.Keys | Sort-Object) | Should -Be @($frenchData.Keys | Sort-Object)
        @($englishData.Keys | Sort-Object) | Should -Be @($germanData.Keys | Sort-Object)
        $englishData.StatusLabel | Should -Be 'Status'
        $frenchData.StatusLabel | Should -Be 'État'
        $germanData.CompletedLabel | Should -Be 'Abgeschlossen'
        $germanData.StatusRunning | Should -Be 'WIRD AUSGEFÜHRT'
    }
}
