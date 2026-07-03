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
        Script resource referenced by its ScriptFullPath. The backing script is only
        created when one doesn't already exist for that identity -- if it was already
        explicitly declared elsewhere (e.g. scripts.ps1) with more specific settings
        (Role, Timeout, Tags, etc.), that declaration is left untouched rather than
        being overwritten by this bare-bones one on every config reload. New-PSUAiTool
        itself is idempotent when called repeatedly with the same identity, which is
        safe since PSU resource declaration files are re-executed on every config
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

        # Only create a backing PSU Script when one doesn't already exist for this
        # <Module>\<Command> identity. A script may already be explicitly declared
        # elsewhere (e.g. scripts.ps1) with more specific settings (Role, Timeout,
        # Tags, etc.); blindly re-declaring it here on every config reload would
        # overwrite that more specific configuration with this bare-bones one.
        # NOTE: uses try/catch rather than -ErrorAction SilentlyContinue -- the
        # latter is reliably observed to prevent Pester from routing this call
        # through a Mock when invoked from this already-compiled function body,
        # making the "already exists" branch untestable without a live PSU server.
        try
        {
            $existingScript = Get-PSUScript -Name $aiTool.ScriptFullPath
        }
        catch
        {
            $existingScript = $null
        }

        if (-not $existingScript)
        {
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
                $null = New-PSUScript @newScriptParams
            }
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
