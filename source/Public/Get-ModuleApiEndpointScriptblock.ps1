
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

    #region Force Endpoint to have pascalCase parameters
    $paramBlock = $ModuleApiEndpoint.FunctionInfo.ScriptBlock.ast.Body.ParamBlock
    $paramBlockStr = $paramBlock.Extent.Text
    # change the Extent to camelCase the Extent name
    $paramBlock.Parameters | ForEach-Object {
        # Update $_.Name to be camelCase
        $parameter = $_

        # If the parameter name is not in camelCase, convert it
        $FirstChar = $parameter.Name.Extent.text.Substring(1, 1) # first letter after the $
        $RestOfName = $parameter.Name.Extent.text.Substring(2) # rest of the name after the first letter
        $newParamName = '${0}{1}' -f $FirstChar.ToLowerInvariant(),$RestOfName
        $startOffSet = $parameter.Name.Extent.StartOffset - $paramBlock.Extent.StartOffset
        $paramBlockStr = $paramBlockStr.Remove($startOffSet,$newParamName.Length).Insert($startOffSet,$newParamName)

        #TODO: Change switch parameter to bool if PSU prefers that
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


    $functionCall = '{0}{1}    {2} @PSBoundParameters{1}' -f $loggingConfig,"`r`n",$ModuleApiEndpoint.FunctionInfo.Name
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
