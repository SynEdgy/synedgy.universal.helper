function Write-UDPsuComponentLog
{
    <#
        .SYNOPSIS
        Writes a Universal Dashboard component diagnostic to PSU logging.

        .DESCRIPTION
        Uses Write-PSULog when it is available so component diagnostics appear under
        Observe > Logging > Live Logs. If PSU logging is unavailable or rejects the
        event, writes a warning to the current PowerShell stream without failing the
        component.

        .PARAMETER Level
        PSU log level for the event.

        .PARAMETER Resource
        PSU resource name used to filter events in Live Logs.

        .PARAMETER Message
        Human-readable diagnostic message.

        .PARAMETER Properties
        Structured diagnostic properties. Callers must not include app tokens or job
        output content.

        .EXAMPLE
        Write-UDPsuComponentLog -Level Warning -Resource 'New-UDPsuJobTerminalView:job-terminal' -Message 'Live output unavailable.' -Properties @{ JobId = 10494 }
    #>
    [CmdletBinding()]
    [OutputType([System.Void])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateSet('Error', 'Warning', 'Information', 'Debug')]
        [System.String]
        $Level,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Resource,

        [Parameter(Mandatory = $true)]
        [System.String]
        $Message,

        [Parameter()]
        [System.Collections.Hashtable]
        $Properties = @{}
    )

    try
    {
        $writePsuLog = Microsoft.PowerShell.Core\Get-Command -Name 'Write-PSULog' -ErrorAction SilentlyContinue
        if ($null -eq $writePsuLog)
        {
            Microsoft.PowerShell.Utility\Write-Warning -Message ('PSU log unavailable [{0}] {1}: {2}' -f $Level, $Resource, $Message)
            return
        }

        $logParams = @{
            Level      = $Level
            Feature    = 'App'
            Resource   = $Resource
            Message    = $Message
            Properties = $Properties
        }

        Write-PSULog @logParams
    }
    catch
    {
        Microsoft.PowerShell.Utility\Write-Warning -Message ('Failed to write PSU log [{0}] {1}: {2}. Logger error: {3}' -f $Level, $Resource, $Message, $_.Exception.Message)
    }
}
