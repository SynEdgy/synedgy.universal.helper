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
}

AfterAll {
    $PSDefaultParameterValues.Remove('Mock:ModuleName')
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    $PSDefaultParameterValues.Remove('Should:ModuleName')

    Remove-Module -Name $script:moduleName
}

BeforeDiscovery {
    $script:themeTestCases = @('Auto', 'Light', 'Dark')
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
        $command.Parameters.Keys | Should -Contain 'Theme'
        $command.Parameters.Keys | Should -Contain 'CustomCss'
        $command.Parameters.Keys | Should -Contain 'HideLineNumbers'
        $command.Parameters.Keys | Should -Contain 'HideTimestamps'
        $command.Parameters.Keys | Should -Contain 'Language'
        $command.Parameters.Keys | Should -Contain 'DefaultUILanguage'
    }

    It 'Should type HideLineNumbers and HideTimestamps as switch parameters' {
        $command = Get-Command -Name New-UDPsuJobTerminalView -Module $script:moduleName -ErrorAction Stop

        $command.Parameters['HideLineNumbers'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
        $command.Parameters['HideTimestamps'].ParameterType | Should -Be ([System.Management.Automation.SwitchParameter])
    }

    It 'Should default Theme to Auto' {
        InModuleScope -ScriptBlock {
            $fn   = Get-Command -Name New-UDPsuJobTerminalView
            $meta = $fn.ScriptBlock.Ast.Body.ParamBlock.Parameters |
                Where-Object { $_.Name.VariablePath.UserPath -eq 'Theme' }

            $meta | Should -Not -BeNullOrEmpty
            $meta.DefaultValue.Value | Should -Be 'Auto'
        }
    }

    It 'Should default Language to English' {
        InModuleScope -ScriptBlock {
            $fn   = Get-Command -Name New-UDPsuJobTerminalView
            $meta = $fn.ScriptBlock.Ast.Body.ParamBlock.Parameters |
                Where-Object { $_.Name.VariablePath.UserPath -eq 'Language' }

            $meta | Should -Not -BeNullOrEmpty
            $meta.DefaultValue.Value | Should -Be 'en'
        }
    }

    It 'Should restrict Theme to Auto, Light, or Dark: <_>' -ForEach $script:themeTestCases {
        $command = Get-Command -Name New-UDPsuJobTerminalView -Module $script:moduleName -ErrorAction Stop
        $validValues = $command.Parameters['Theme'].Attributes.ValidValues

        $validValues | Should -Contain $_
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

    It 'Should not concatenate strings with the addition operator' {
        InModuleScope -ScriptBlock {
            $functionAst = (Get-Command -Name New-UDPsuJobTerminalView).ScriptBlock.Ast
            $additionExpressions = @(
                $functionAst.FindAll(
                    {
                        param($ast)

                        $ast -is [System.Management.Automation.Language.BinaryExpressionAst] -and
                        $ast.Operator -eq [System.Management.Automation.Language.TokenKind]::Plus
                    },
                    $true
                )
            )

            $additionExpressions.Count | Should -Be 0
        }
    }

    It 'Should not depend on Get-ModuleConfig or a localhost URL default' {
        InModuleScope -ScriptBlock {
            $functionText = (Get-Command -Name New-UDPsuJobTerminalView).ScriptBlock.Ast.Extent.Text

            $functionText | Should -Not -Match '\bGet-ModuleConfig\b'
            $functionText | Should -Not -Match 'http://localhost:5000'
        }
    }

    It 'Should resolve and propagate component-owned localized data' {
        InModuleScope -ScriptBlock {
            $functionText = (Get-Command -Name New-UDPsuJobTerminalView).ScriptBlock.Ast.Extent.Text

            $functionText | Should -Match "Name\s+= 'synedgy\.universal\.helper\.PsuJobTerminal'"
            $functionText | Should -Match 'Get-PSUComponentLocalizedData @localizedDataParameters'
            $functionText | Should -Match '\$localizedDataJson = \$localizedData \| ConvertTo-Json -Compress'
            $functionText | Should -Match 'ArgumentList\[8\]'
            $functionText | Should -Match 'ConvertFrom-Json .* -AsHashtable'
            ([regex]::Matches($functionText, '\$localizedDataJson').Count) | Should -BeGreaterOrEqual 5
        }
    }

    It 'Should use localized terminal chrome and dynamic messages' {
        InModuleScope -ScriptBlock {
            $functionText = (Get-Command -Name New-UDPsuJobTerminalView).ScriptBlock.Ast.Extent.Text

            $functionText | Should -Match '\$localizedData\.OutputTab'
            $functionText | Should -Match '\$localizedData\.StructuredEventsTab'
            $functionText | Should -Match '\$localizedData\.ToggleLineNumbers'
            $functionText | Should -Match '\$dynLocalizedData\.FetchedAt'
            $functionText | Should -Match '\$strings\.LiveOutputUnavailable'
            $functionText | Should -Match '\$strings\.TimestampColumn'
        }
    }

    It 'Should provide matching English, French, and German component resources' {
        $englishPath = Join-Path -Path $script:projectPath -ChildPath 'source\en\synedgy.universal.helper.PsuJobTerminal.strings.psd1'
        $frenchPath = Join-Path -Path $script:projectPath -ChildPath 'source\fr\synedgy.universal.helper.PsuJobTerminal.strings.psd1'
        $germanPath = Join-Path -Path $script:projectPath -ChildPath 'source\de\synedgy.universal.helper.PsuJobTerminal.strings.psd1'

        $englishData = Import-PowerShellDataFile -LiteralPath $englishPath
        $frenchData = Import-PowerShellDataFile -LiteralPath $frenchPath
        $germanData = Import-PowerShellDataFile -LiteralPath $germanPath

        @($englishData.Keys | Sort-Object) | Should -Be @($frenchData.Keys | Sort-Object)
        @($englishData.Keys | Sort-Object) | Should -Be @($germanData.Keys | Sort-Object)
        $englishData.OutputTab | Should -Be 'Output'
        $frenchData.OutputTab | Should -Be 'Sortie'
        ($frenchData.FetchedAt -f '12:00') | Should -Be 'récupéré à 12:00'
        $germanData.OutputTab | Should -Be 'Ausgabe'
        ($germanData.LiveOutputUnavailable -f 'Fehler', '') |
            Should -Be 'Live-Ausgabe nicht verfügbar: Fehler'
    }

    It 'Should separate completed blocks without splitting conditional or exception chains' {
        InModuleScope -ScriptBlock {
            $functionLines = (Get-Command -Name New-UDPsuJobTerminalView).ScriptBlock.Ast.Extent.Text -split '\r?\n'
            $violations = for ($lineIndex = 0; $lineIndex -lt ($functionLines.Count - 1); $lineIndex++)
            {
                if ($functionLines[$lineIndex].Trim() -ne '}')
                {
                    continue
                }

                $nextLine = $functionLines[$lineIndex + 1].Trim()
                if ($nextLine -match '^(else|elseif|catch|finally)\b' -or $nextLine -match '^[})]')
                {
                    continue
                }

                if ($nextLine -eq '')
                {
                    $nextNonEmptyLine = @(
                        $functionLines[($lineIndex + 2)..($functionLines.Count - 1)] |
                            Where-Object { $_.Trim() -ne '' } |
                            Select-Object -First 1
                    )

                    if (@($nextNonEmptyLine).Count -eq 0 -or $nextNonEmptyLine[0].Trim() -notmatch '^(else|elseif|catch|finally)\b')
                    {
                        continue
                    }
                }

                $lineIndex + 1
            }

            @($violations).Count | Should -Be 0
        }
    }
}
