function ConvertFrom-PsuJobOutputEntry
{
    <#
        .SYNOPSIS
        Converts a raw PSU job output entry to a normalized display row object.

        .DESCRIPTION
        Maps raw objects returned by Get-PSUJobOutput (or stored in Job.Output) to a
        consistent PSCustomObject with Timestamp, Stream, StreamColor, and Message
        properties, suitable for rendering in a terminal or structured table view.
        StreamColor is a CSS var() reference (e.g. 'var(--psu-term-stream-error)') rather
        than a literal color, so rendered output follows the light/dark theme set by
        Get-UDPsuJobThemeStyleBlock instead of being hardcoded to one palette.
        Accepts pipeline input for use in streaming pipelines.

        .PARAMETER Entry
        A raw PSU job output entry object. Accepts pipeline input.

        .EXAMPLE
        Get-PSUJobOutput -JobId 1234 | ConvertFrom-PsuJobOutputEntry

        .EXAMPLE
        $job.Output | ConvertFrom-PsuJobOutputEntry | Where-Object { $_.Stream -eq 'Error' }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]
        $Entry
    )

    process
    {
        $streamName = switch ($Entry.Type)
        {
            4             { 'Error' }
            3             { 'Warning' }
            2             { 'Verbose' }
            1             { 'Debug' }
            0             { 'Information' }
            'Error'       { 'Error' }
            'Warning'     { 'Warning' }
            'Verbose'     { 'Verbose' }
            'Debug'       { 'Debug' }
            'Information' { 'Information' }
            Default       { 'Output' }
        }

        $streamColor = switch ($streamName)
        {
            'Error'       { 'var(--psu-term-stream-error)' }
            'Warning'     { 'var(--psu-term-stream-warning)' }
            'Information' { 'var(--psu-term-stream-information)' }
            'Verbose'     { 'var(--psu-term-stream-verbose)' }
            'Debug'       { 'var(--psu-term-stream-debug)' }
            Default       { 'var(--psu-term-stream-default)' }
        }

        $messageValue = $null
        foreach ($prop in @('message', 'Message', 'data', 'Data', 'output', 'Output', 'text', 'Text'))
        {
            if ($Entry.PSObject.Properties.Match($prop).Count -eq 0) { continue }
            $candidate = $Entry.$prop
            if ($null -eq $candidate) { continue }
            $candidateText = [string]$candidate
            if (-not [string]::IsNullOrWhiteSpace($candidateText)) { $messageValue = $candidateText; break }
        }

        if ([string]::IsNullOrWhiteSpace([string]$messageValue))
        {
            $messageValue = if ($Entry -is [string]) { [string]$Entry }
                            else { [string](Microsoft.PowerShell.Utility\ConvertTo-Json -InputObject $Entry -Compress -Depth 5) }
        }

        [PSCustomObject]@{
            Timestamp   = $Entry.Timestamp
            Stream      = $streamName
            StreamColor = $streamColor
            Message     = $messageValue
        }
    }
}
