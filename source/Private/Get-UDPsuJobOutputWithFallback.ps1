function Get-UDPsuJobOutputWithFallback
{
    <#
        .SYNOPSIS
        Gets PSU job output and falls back to a supplied snapshot.

        .DESCRIPTION
        Calls Get-PSUJobOutput with the supplied connection settings. If the live call
        fails or returns no records, a supplied snapshot is returned instead. The result
        includes the live-fetch error message and whether the snapshot was used so callers
        can clearly indicate degraded rendering.

        .PARAMETER JobId
        The PSU job identifier whose output should be retrieved.

        .PARAMETER AppToken
        Optional PSU app token used for the live output request.

        .PARAMETER UniversalServerUrl
        Optional PSU server URL used for the live output request. When supplied,
        Get-PSUJobOutput is called through the Management API with ComputerName and
        the optional AppToken. When omitted, Get-PSUJobOutput is called with Integrated.

        .PARAMETER FallbackOutput
        Pre-fetched output records to use when live output is unavailable.

        .EXAMPLE
        Get-UDPsuJobOutputWithFallback -JobId 10494 -UniversalServerUrl 'http://localhost:5000' -FallbackOutput $job.Output
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.Int64]
        $JobId,

        [Parameter()]
        [System.String]
        $AppToken,

        [Parameter()]
        [System.String]
        $UniversalServerUrl,

        [Parameter()]
        [System.Object[]]
        $FallbackOutput = @()
    )

    $outputRecords = @()
    $errorMessage = $null

    try
    {
        $fetchParams = @{
            JobId       = $JobId
            AsObject    = $true
            ErrorAction = 'Stop'
        }

        if (-not [System.String]::IsNullOrWhiteSpace($UniversalServerUrl))
        {
            $fetchParams['ComputerName'] = $UniversalServerUrl.TrimEnd('/')
            if (-not [System.String]::IsNullOrWhiteSpace($AppToken))
            {
                $fetchParams['AppToken'] = $AppToken
            }
        }
        else
        {
            $fetchParams['Integrated'] = $true
        }

        $outputRecords = @(Get-PSUJobOutput @fetchParams)
    }
    catch
    {
        $errorMessage = $_.Exception.Message
        if (-not [System.String]::IsNullOrWhiteSpace($AppToken))
        {
            $errorMessage = $errorMessage.Replace($AppToken, '[REDACTED]')
        }
    }

    $usedFallback = $false
    if (@($outputRecords).Count -eq 0 -and @($FallbackOutput).Count -gt 0)
    {
        $outputRecords = @($FallbackOutput)
        $usedFallback = $true
    }

    [PSCustomObject]@{
        OutputRecords = @($outputRecords)
        ErrorMessage  = $errorMessage
        UsedFallback  = $usedFallback
    }
}
