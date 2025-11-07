function Get-ModuleApiEndpoint
{
    <#
    .SYNOPSIS
        Retrieves the API endpoint for the current module.

    .DESCRIPTION
        This function retrieves the API endpoint metadata for a specified service by getting the public functions of the module.

    .EXAMPLE
        Get-ModuleApiEndpoint
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'No parameters needed')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseOutputTypeCorrectly', '', Justification = 'Output type is a dictionary')]
    param
    (
        [Parameter()]
        [Microsoft.PowerShell.Commands.ModuleSpecification]
        $Module,

        [Parameter()]
        [ValidateSet('Information', 'Debug', 'Verbose')]
        [string[]]
        $LogLevel,

        [Parameter()]
        [string]
        $Environment,

        [Parameter()]
        [switch]
        $Authentication,

        [Parameter()]
        [string]
        $ApiPrefix
    )

    # TODO: Load module in Thread and process it there (once done the thread is closed and DLL handles freed)
    $apiModule = Get-Module $Module -ErrorAction Stop
    Write-Verbose -Message ('Module: {0} Version: {1}' -f $apiModule.Name, $apiModule.Version)
    $endpoints = $apiModule.ExportedFunctions.Values.Where{
        $_.ScriptBlock.Attributes.Where{
            $_.TypeId.ToString() -eq 'APIEndpoint' -and $_.IsEndpoint -eq $true
        }
    }

    Write-Verbose -Message ('Discovered API functions are: {0}' -f ($endpoints.Name -join ', '))
    foreach ($functionEndpoint in $endpoints)
    {
        # You can have more than one endpoint for a single function
        # by repeating the APIEndpoint attribute
        # This is useful for versioning or different methods, and overriding parameters signature (say between v1 and v2)
        $ApiEndpoints = $functionEndpoint.ScriptBlock.Attributes.Where{
            $_.TypeId.ToString() -eq 'APIEndpoint' -and $_.IsEndpoint -eq $true
        }

        foreach ($ApiEndpoint in $ApiEndpoints)
        {
            $urlPath = $ApiEndpoint.Path
            $version = $ApiEndpoint.version
            $Name = $ApiEndpoint.Name

            if ([string]::IsNullOrEmpty($urlPath))
            {
                $urlPath = $functionEndpoint.Noun.ToLower()
            }

            if ($PSBoundParameters.ContainsKey('ApiPrefix'))
            {
                $url = ('{0}/{1}' -f $PSBoundParameters['ApiPrefix'], $urlPath.TrimStart('/').ToLower()) -replace '//', '/'
            }
            else
            {
                $url = (('/{0}/{1}/{2}/{3}' -f $ApiEndpoint.apiPrefix, $ApiEndpoint.Name, $ApiEndpoint.version, $urlPath.TrimStart('/')).ToLower()) -replace '//', '/'
            }

            Write-Information -MessageData "Processing endpoint: $url for function: $($functionEndpoint.Name)"
            if ([string]::IsNullOrEmpty($Name))
            {
                $Name = '{0}{1}{2}' -f $functionEndpoint.verb.ToLower(), $functionEndpoint.Noun,$version
            }

            $description = $ApiEndpoint.Description
            if ([string]::IsNullOrEmpty($description))
            {
                $description = (Get-Help -Name $functionEndpoint.Name -ErrorAction SilentlyContinue).Description.Text
            }

            $method = $ApiEndpoint.Method
            if ([string]::IsNullOrEmpty($method))
            {
                $method = Get-HttpMethodFromPSVerb -Verb $functionEndpoint.Verb
            }

            $apiEndpointData = @{
                # Mandatory fields for the endpoint
                url          = $url
                Description  = $description
                Method       = $method
                FunctionInfo = $functionEndpoint
            }

            if ($PSBoundParameters.ContainsKey('LogLevel'))
            {
                $apiEndpointData['LogLevel'] = $PSBoundParameters['LogLevel']
            }
            elseif ($ApiEndpoint.LogLevel -and $ApiEndpoint.LogLevel.Count -gt 0)
            {
                $apiEndpointData['LogLevel'] = $ApiEndpoint.LogLevel
            }

            # Optional fields for the endpoint
            if ($PSBoundParameters.ContainsKey('Environment'))
            {
                $apiEndpointData['Environment'] = $PSBoundParameters['Environment']
            }
            elseif (-not [string]::IsNullOrEmpty($ApiEndpoint.Environment))
            {
                $apiEndpointData['Environment'] = $ApiEndpoint.Environment
            }

            if ($PSBoundParameters.ContainsKey('Authentication'))
            {
                $apiEndpointData['Authentication'] = $PSBoundParameters['Authentication']
            }
            elseif ($ApiEndpoint.Authentication)
            {
                $apiEndpointData['Authentication'] = $ApiEndpoint.Authentication
            }

            if ($PSBoundParameters.ContainsKey('Role'))
            {
                $apiEndpointData['Role'] = $PSBoundParameters['Role']
            }
            elseif ($ApiEndpoint.Role -and $ApiEndpoint.Role.Count -gt 0)
            {
                $apiEndpointData['Role'] = $ApiEndpoint.Role
            }

            if ($ApiEndpoint.Tag -gt 0)
            {
                $apiEndpointData['Tag'] = $ApiEndpoint.Tag
            }

            if ($ApiEndpoint.Timeout -and $ApiEndpoint.Timeout -gt 0)
            {
                $apiEndpointData['Timeout'] = $ApiEndpoint.Timeout
            }

            if (-not [string]::IsNullOrEmpty($ApiEndpoint.ContentType))
            {
                $apiEndpointData['ContentType'] = $ApiEndpoint.ContentType
            }

            if ($ApiEndpoint.Parameters -and $ApiEndpoint.Parameters -is [scriptblock])
            {
                $apiEndpointData['Parameters'] = $ApiEndpoint.Parameters
            }

            $apiEndpointData
        }
    }
}
