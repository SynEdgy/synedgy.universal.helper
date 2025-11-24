function Import-PSUEndpoint
{
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
        [string]
        $ApiPrefix,

        [Parameter()]
        [string]
        # Name of the documentation endpoint to use for this endpoint.
        # If not specified, the one defined by the attribute will be used, or the default one.
        $Documentation,

        [Parameter()]
        [switch]
        # Force authentication on the endpoint regardless of its configuration.
        $Authentication,

        [Parameter()]
        [ValidateSet('Information','Debug', 'Verbose')]
        [string[]]
        $LogLevel = 'Information'
    )

    $moduleApiEndpointParams = @{}

    if ($PSBoundParameters.ContainsKey('Module'))
    {
        $moduleApiEndpointParams['Module'] = $Module
    }

    if ($PSBoundParameters.ContainsKey('Environment'))
    {
        $moduleApiEndpointParams['Environment'] = $Environment
    }

    if ($PSBoundParameters.ContainsKey('ApiPrefix'))
    {
        $moduleApiEndpointParams['ApiPrefix'] = $ApiPrefix
    }

    if ($PSBoundParameters.ContainsKey('Authentication'))
    {
        $moduleApiEndpointParams['Authentication'] = $Authentication
    }

    if ($PSBoundParameters.ContainsKey('LogLevel'))
    {
        $moduleApiEndpointParams['LogLevel'] = $LogLevel
    }

    if ($PSBoundParameters.ContainsKey('Documentation'))
    {
        $moduleEndpointScriptblockParameters['Documentation'] = $Documentation
    }

    $endpoints = Get-ModuleApiEndpoint @moduleApiEndpointParams
    $endpoints | ForEach-Object {
        # Create a new endpoint for each function that has the APIEndpoint attribute
        $psuEndpointParams = @{} + $_
        $psuCommand = Get-Command -Name 'New-PSUEndpoint'
        $psuEndpointParams.Keys.Where{
            $_ -notin $psuCommand.Parameters.Keys
        } | ForEach-Object {
            $psuEndpointParams.Remove($_)
        }

        $moduleEndpointScriptblockParameters = @{
            ModuleApiEndpoint = $_
        }

        $endpointScriptBlock = Get-ModuleApiEndpointScriptblock @moduleEndpointScriptblockParameters

        if ($PSCmdlet.ShouldProcess(('Creating PSUEndpoint with {0}' -f ($psuEndpointParams | ConvertTo-Json -depth 6 -Compress))))
        {
            New-PSUEndpoint @psuEndpointParams -Endpoint $endpointScriptBlock
        }
    }
}
