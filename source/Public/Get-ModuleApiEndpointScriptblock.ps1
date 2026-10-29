
using namespace System.Collections
function Get-ModuleApiEndpointScriptblock
{
    <#
        .SYNOPSIS
        Returns a scriptblock that can be used as an endpoint for a PSU API.

        .DESCRIPTION
        This function returns a scriptblock that can be used as an endpoint for the module API.
        The scriptblock will return the module's API endpoints.

        .EXAMPLE
        $scriptBlock = Get-ModuleApiEndpointScriptblock
        Invoke-Command -ScriptBlock $scriptBlock

        .OUTPUTS
        [PSCustomObject[]] - An array of custom objects representing the module's API endpoints.
    #>
    [CmdletBinding()]
    [OutputType([ScriptBlock])]
    param
    (
        [Parameter(Mandatory = $true)]
        [IDictionary]
        $ModuleApiEndpoint
    )

    #region Build a parser-safe endpoint parameter contract
    $paramBlock = $ModuleApiEndpoint.FunctionInfo.ScriptBlock.ast.Body.ParamBlock
    $paramBlockStr = $paramBlock.Extent.Text
    $parameterReplacements = [System.Collections.Generic.List[object]]::new()
    $hiddenParameterIndexes = [System.Collections.Generic.List[int]]::new()
    $parameters = @($paramBlock.Parameters)

    for ($parameterIndex = 0; $parameterIndex -lt $parameters.Count; $parameterIndex++)
    {
        $parameter = $parameters[$parameterIndex]
        $oldParamName = $parameter.Name.VariablePath.UserPath
        $parameterMetadata = $ModuleApiEndpoint.FunctionInfo.Parameters[$oldParamName]
        $isHidden = $parameterMetadata.Attributes |
            Where-Object {
                $_ -is [System.Management.Automation.ParameterAttribute] -and $_.DontShow
            }
        if ($isHidden)
        {
            $hiddenParameterIndexes.Add($parameterIndex)
            continue
        }

        $firstChar = $oldParamName.Substring(0, 1)
        $restOfName = $oldParamName.Substring(1)
        $newParamName = '{0}{1}' -f $firstChar.ToLowerInvariant(), $restOfName
        $replacedParamName = $parameter.Name.Extent.text -creplace ([regex]::Escape($oldParamName)), $newParamName
        $parameterReplacements.Add([pscustomobject]@{
                StartOffset = $parameter.Name.Extent.StartOffset - $paramBlock.Extent.StartOffset
                Length      = $parameter.Name.Extent.EndOffset - $parameter.Name.Extent.StartOffset
                Text        = $replacedParamName
            })

        $typeConstraint = $parameter.Attributes |
            Where-Object { $_ -is [System.Management.Automation.Language.TypeConstraintAst] } |
            Select-Object -Last 1
        if (-not $typeConstraint -or -not $parameterMetadata)
        {
            return
        }

        $parameterType = $parameterMetadata.ParameterType
        $replacementType = $null
        if ($parameterType -eq [System.Management.Automation.SwitchParameter])
        {
            $replacementType = '[bool]'
        }
        else
        {
            $enumType = if ($parameterType.IsEnum)
            {
                $parameterType
            }
            elseif ($parameterType.IsArray -and $parameterType.GetElementType().IsEnum)
            {
                $parameterType.GetElementType()
            }

            if ($enumType)
            {
                $replacementType = if ($parameterType.IsArray) { '[string[]]' } else { '[string]' }
                $hasValidateSet = $parameterMetadata.Attributes |
                    Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
                if (-not $hasValidateSet)
                {
                    $enumValues = [System.Enum]::GetNames($enumType) | ForEach-Object {
                        "'{0}'" -f $_.Replace("'", "''")
                    }
                    $replacementType = '[ValidateSet({0})]{1}' -f ($enumValues -join ', '), $replacementType
                }

                if ($parameter.DefaultValue)
                {
                    $enumDefaultMembers = $parameter.DefaultValue.FindAll(
                        {
                            param($ast)

                            $ast -is [System.Management.Automation.Language.MemberExpressionAst] -and
                            $ast.Static -and
                            $ast.Expression -is [System.Management.Automation.Language.TypeExpressionAst]
                        },
                        $true
                    )
                    foreach ($enumDefaultMember in $enumDefaultMembers)
                    {
                        $defaultType = $enumDefaultMember.Expression.TypeName.GetReflectionType()
                        $defaultName = $enumDefaultMember.Member.Value
                        if ($defaultType -eq $enumType -and [System.Enum]::IsDefined($enumType, $defaultName))
                        {
                            $parameterReplacements.Add([pscustomobject]@{
                                    StartOffset = $enumDefaultMember.Extent.StartOffset - $paramBlock.Extent.StartOffset
                                    Length      = $enumDefaultMember.Extent.EndOffset - $enumDefaultMember.Extent.StartOffset
                                    Text        = "'{0}'" -f $defaultName.Replace("'", "''")
                                })
                        }
                    }
                }
            }
        }

        if ($replacementType)
        {
            $parameterReplacements.Add([pscustomobject]@{
                    StartOffset = $typeConstraint.Extent.StartOffset - $paramBlock.Extent.StartOffset
                    Length      = $typeConstraint.Extent.EndOffset - $typeConstraint.Extent.StartOffset
                    Text        = $replacementType
                })
        }
    }

    if ($hiddenParameterIndexes.Count -gt 0)
    {
        $hiddenParameterGroups = [System.Collections.Generic.List[object]]::new()
        $groupStart = $hiddenParameterIndexes[0]
        $groupEnd = $groupStart
        foreach ($hiddenParameterIndex in $hiddenParameterIndexes | Select-Object -Skip 1)
        {
            if ($hiddenParameterIndex -eq ($groupEnd + 1))
            {
                $groupEnd = $hiddenParameterIndex
                continue
            }

            $hiddenParameterGroups.Add([pscustomobject]@{
                    Start = $groupStart
                    End   = $groupEnd
                })
            $groupStart = $hiddenParameterIndex
            $groupEnd = $hiddenParameterIndex
        }
        $hiddenParameterGroups.Add([pscustomobject]@{
                Start = $groupStart
                End   = $groupEnd
            })

        foreach ($hiddenParameterGroup in $hiddenParameterGroups)
        {
            if ($hiddenParameterGroup.End -lt ($parameters.Count - 1))
            {
                $removalStart = $parameters[$hiddenParameterGroup.Start].Extent.StartOffset
                $removalEnd = $parameters[$hiddenParameterGroup.End + 1].Extent.StartOffset
            }
            elseif ($hiddenParameterGroup.Start -gt 0)
            {
                $removalStart = $parameters[$hiddenParameterGroup.Start - 1].Extent.EndOffset
                $removalEnd = $parameters[$hiddenParameterGroup.End].Extent.EndOffset
            }
            else
            {
                $removalStart = $parameters[$hiddenParameterGroup.Start].Extent.StartOffset
                $removalEnd = $parameters[$hiddenParameterGroup.End].Extent.EndOffset
            }

            $parameterReplacements.Add([pscustomobject]@{
                    StartOffset = $removalStart - $paramBlock.Extent.StartOffset
                    Length      = $removalEnd - $removalStart
                    Text        = ''
                })
        }
    }

    $parameterReplacements |
        Sort-Object -Property StartOffset -Descending |
        ForEach-Object {
            $paramBlockStr = $paramBlockStr.Remove($_.StartOffset, $_.Length).Insert($_.StartOffset, $_.Text)
        }

    if ($parameterReplacements.Count -gt 0)
    {
        Write-Debug -Message ('Generated parser-safe parameter contract for {0}: {1}' -f
            $ModuleApiEndpoint.FunctionInfo.Name, $paramBlockStr)
    }
    #TODO: Add the Inputs/Outputs documentation to the CBH section
    #endregion

    if ($PSBoundParameters.ContainsKey('Environment'))
    {
        $paramBlockStr = $paramBlockStr -replace '\$Environment', '$PSBoundParameters["Environment"]'
    }

    [string] $InformationAction, $VerboseAction, $DebugAction = ''

    if ($ModuleApiEndpoint.LogLevel -contains 'Information')
    {
        $InformationAction = '$InformationPreference = ''Continue'';'
    }

    if ($ModuleApiEndpoint.LogLevel -contains 'Verbose')
    {
        $VerboseAction = '$VerbosePreference = ''Continue'';'
    }

    if ($ModuleApiEndpoint.LogLevel -contains 'Debug')
    {
        $DebugAction = '$DebugPreference = ''Continue'';'
    }

    $testingStream = '
    Write-Host "this is a Write-Host test message"
    Write-Information "this is a Write-Information test message"
    Write-Debug -Message "This is a Write-Debug test message"
    Write-Verbose -Verbose -Message "This is a Write-Verbose test message"
'
    $loggingConfig = @(
        $InformationAction,
        $VerboseAction,
        $DebugAction
        # $testingStream
        #TODO: raise a bug with PowerShell Universal (only Information/Write-Host works)
    ) -join ''


    $confirmArgument = if ($ModuleApiEndpoint.FunctionInfo.Parameters.ContainsKey('Confirm'))
    {
        ' -Confirm:$false'
    }
    else
    {
        ''
    }
    $functionCall = '{0}{1}    {2} @PSBoundParameters{3}{1}' -f
        $loggingConfig,
        "`r`n",
        $ModuleApiEndpoint.FunctionInfo.Name,
        $confirmArgument
    # $functionCall = '$result = {0} @PSBoundParameters' -f $ModuleApiEndpoint.FunctionInfo.Name
    # JSON automatic serialization
    # $jsonConvert = '$result | ConvertTo-Json -Depth 10'
    $scriptBlockStr = '    {0}{1}{1}    {2}{1}    {3}' -f $paramBlockStr,"`r`n", $functionCall,$jsonConvert
    Write-Information -MessageData ('Creating scriptblock for module API endpoint: {0}. {1}' -f $ModuleApiEndpoint.url, $scriptBlockStr)
    # TODO: Implement Generic HTTP codes

    # Create a scriptblock from the string
    $scriptBlock = [scriptblock]::Create($scriptBlockStr)
    return $scriptBlock
}
