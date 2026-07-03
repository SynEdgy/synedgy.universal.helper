function Import-PSUAiTool
{
    <#
        .SYNOPSIS
        Discovers functions decorated with [AiTool()] in a module and registers them as
        PowerShell Universal AI tools.

        .DESCRIPTION
        For each function found via Get-ModuleAiTool, ensures a backing PSU Script
        resource exists (New-PSUScript, keyed by <Module>\<Command>) and registers the
        corresponding AI tool (New-PSUAiTool). Unlike Import-PSUEndpoint, which builds an
        inline wrapper scriptblock for New-PSUEndpoint, New-PSUAiTool requires an existing
        Script resource referenced by its ScriptFullPath, so this function always
        (re-)declares that backing script alongside the AI tool. Both New-PSUScript and
        New-PSUAiTool are idempotent when called repeatedly with the same identity, which
        is safe since PSU resource declaration files are re-executed on every config
        reload.

        .PARAMETER Module
        The module to scan for AI tool functions.

        .PARAMETER Environment
        The PSU environment the backing script should run in. Falls back to the
        Environment set on the AiTool attribute, when present.

        .PARAMETER Authenticated
        Forces whether discovered tools require an authenticated user, overriding the
        AiTool attribute's value.

        .PARAMETER Mcp
        Forces whether discovered tools are exposed through MCP, overriding the AiTool
        attribute's value.

        .EXAMPLE
        Import-PSUAiTool -Module PSUConfig -Environment 'PSUConfig'
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([Object])]
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

    $moduleAiToolParams = @{}

    if ($PSBoundParameters.ContainsKey('Module'))
    {
        $moduleAiToolParams['Module'] = $Module
    }

    if ($PSBoundParameters.ContainsKey('Environment'))
    {
        $moduleAiToolParams['Environment'] = $Environment
    }

    if ($PSBoundParameters.ContainsKey('Authenticated'))
    {
        $moduleAiToolParams['Authenticated'] = $Authenticated.IsPresent
    }

    if ($PSBoundParameters.ContainsKey('Mcp'))
    {
        $moduleAiToolParams['Mcp'] = $Mcp.IsPresent
    }

    $aiTools = Get-ModuleAiTool @moduleAiToolParams
    $aiTools | ForEach-Object -Process {
        $aiTool = $_

        $newScriptParams = @{
            Module  = $Module
            Command = $aiTool.FunctionInfo.Name
        }
        if ($aiTool.ContainsKey('Environment'))
        {
            $newScriptParams['Environment'] = $aiTool.Environment
        }

        if ($PSCmdlet.ShouldProcess(('Registering backing PSU Script for AI tool {0}: {1}' -f $aiTool.Name, ($newScriptParams | ConvertTo-Json -Compress))))
        {
            New-PSUScript @newScriptParams
        }

        $newAiToolParams = @{
            Name           = $aiTool.Name
            Description    = $aiTool.Description
            ScriptFullPath = $aiTool.ScriptFullPath
        }

        if ($aiTool.ContainsKey('Authenticated'))
        {
            $newAiToolParams['Authenticated'] = $aiTool.Authenticated
        }

        if ($aiTool.ContainsKey('Role'))
        {
            $newAiToolParams['Role'] = $aiTool.Role
        }

        if ($aiTool.ContainsKey('Mcp'))
        {
            $newAiToolParams['Mcp'] = $aiTool.Mcp
        }

        if ($PSCmdlet.ShouldProcess(('Creating PSUAiTool with {0}' -f ($newAiToolParams | ConvertTo-Json -Compress))))
        {
            New-PSUAiTool @newAiToolParams
        }
    }
}
