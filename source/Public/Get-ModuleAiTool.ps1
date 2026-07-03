function Get-ModuleAiTool
{
    <#
        .SYNOPSIS
        Retrieves the AI tool metadata for functions decorated with [AiTool()] in a module.

        .DESCRIPTION
        Scans the exported functions of a module for the AiTool attribute and builds a
        metadata dictionary for each one, suitable for registering with PowerShell
        Universal via New-PSUScript and New-PSUAiTool (see Import-PSUAiTool).

        .PARAMETER Module
        The module to scan for AI tool functions.

        .PARAMETER Environment
        Overrides the PSU environment the backing script should run in. Falls back to the
        Environment set on the attribute, when present.

        .PARAMETER Authenticated
        Overrides whether discovered tools require an authenticated user. Falls back to
        the Authenticated value set on the attribute.

        .PARAMETER Mcp
        Overrides whether discovered tools are exposed through MCP. Falls back to the Mcp
        value set on the attribute (defaults to $true).

        .EXAMPLE
        Get-ModuleAiTool -Module PSUConfig
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Output type is a dictionary')]
    param
    (
        [Parameter()]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $Module,

        [Parameter()]
        [string]
        $Environment,

        [Parameter()]
        [switch]
        $Authenticated,

        [Parameter()]
        [switch]
        $Mcp
    )

    $aiToolModule = Get-Module $Module -ErrorAction Stop
    Write-Verbose -Message ('Module: {0} Version: {1}' -f $aiToolModule.Name, $aiToolModule.Version)

    $aiToolFunctions = $aiToolModule.ExportedFunctions.Values.Where{
        $_.ScriptBlock.Attributes.Where{
            $_.TypeId.ToString() -eq 'AiTool' -and $_.IsAiTool -eq $true
        }
    }

    Write-Verbose -Message ('Discovered AI tool functions are: {0}' -f ($aiToolFunctions.Name -join ', '))
    foreach ($aiToolFunction in $aiToolFunctions)
    {
        # You can have more than one AiTool attribute on a single function, e.g. to
        # register it under multiple names/roles.
        $aiToolAttributes = $aiToolFunction.ScriptBlock.Attributes.Where{
            $_.TypeId.ToString() -eq 'AiTool' -and $_.IsAiTool -eq $true
        }

        foreach ($aiToolAttribute in $aiToolAttributes)
        {
            $name = $aiToolAttribute.Name
            if ([string]::IsNullOrEmpty($name))
            {
                $name = $aiToolFunction.Name
            }

            $description = $aiToolAttribute.Description
            if ([string]::IsNullOrEmpty($description))
            {
                $description = (Get-Help -Name $aiToolFunction.Name -ErrorAction SilentlyContinue).Synopsis
            }

            $scriptFullPath = '{0}\{1}' -f $aiToolModule.Name, $aiToolFunction.Name

            $aiToolData = @{
                Name           = $name
                Description    = $description
                ScriptFullPath = $scriptFullPath
                FunctionInfo   = $aiToolFunction
            }

            if ($PSBoundParameters.ContainsKey('Environment'))
            {
                $aiToolData['Environment'] = $Environment
            }
            elseif (-not [string]::IsNullOrEmpty($aiToolAttribute.Environment))
            {
                $aiToolData['Environment'] = $aiToolAttribute.Environment
            }

            if ($PSBoundParameters.ContainsKey('Authenticated'))
            {
                $aiToolData['Authenticated'] = $Authenticated.IsPresent
            }
            else
            {
                $aiToolData['Authenticated'] = $aiToolAttribute.Authenticated
            }

            if ($aiToolAttribute.Role -and $aiToolAttribute.Role.Count -gt 0)
            {
                $aiToolData['Role'] = $aiToolAttribute.Role
            }

            if ($PSBoundParameters.ContainsKey('Mcp'))
            {
                $aiToolData['Mcp'] = $Mcp.IsPresent
            }
            else
            {
                $aiToolData['Mcp'] = $aiToolAttribute.Mcp
            }

            $aiToolData
        }
    }
}
