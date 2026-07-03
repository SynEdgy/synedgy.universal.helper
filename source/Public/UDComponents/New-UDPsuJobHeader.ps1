function New-UDPsuJobHeader
{
    <#
        .SYNOPSIS
        Renders a dark summary header card for a PowerShell Universal job.

        .DESCRIPTION
        Produces a styled HTML metadata card showing the script path, a
        copy-to-clipboard job ID chip, status badge, and timestamps
        (Created, Started, Completed, Duration). Designed to pair with
        New-UDPsuJobTerminalView on a job detail page, but can be used
        independently wherever a concise job summary is needed.

        .PARAMETER Job
        The PSU job object returned by Get-PSUJob. Used to derive all
        displayed fields.

        .EXAMPLE
        $job = Get-PSUJob -Id $id -AppToken $token
        New-UDPsuJobHeader -Job $job

        .EXAMPLE
        # Typical usage on a job detail page
        $job = Get-PSUJob -Id ([Int64]$id)
        New-UDPsuJobHeader -Job $job
        New-UDPsuJobTerminalView -JobId $job.Id -JobStatus ([string]$job.Status) `
            -JobOutputSnapshot @($job.Output) -IncludeStructuredTable
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory)]
        $Job
    )

    $formatDt = {
        param($dt)
        if ($dt -and ([datetime]$dt).Year -gt 1) { '{0:yyyy-MM-dd HH:mm:ss}' -f ([datetime]$dt) } else { 'N/A' }
    }

    $createdStr   = & $formatDt $Job.CreatedTime
    $startedStr   = & $formatDt $Job.StartTime
    $completedStr = & $formatDt $Job.EndTime

    $durationStr = 'N/A'
    if ($Job.StartTime -and $Job.EndTime)
    {
        $s = [datetime]$Job.StartTime
        $e = [datetime]$Job.EndTime
        if ($s.Year -gt 1 -and $e.Year -gt 1 -and $e -gt $s)
        {
            $span        = $e - $s
            $durationStr = if ($span.TotalHours -ge 1)      { '{0}h {1:mm\:ss}' -f [int]$span.TotalHours, $span }
                           elseif ($span.TotalMinutes -ge 1) { '{0:m\:ss}' -f $span }
                           else                              { '{0}s' -f [int]$span.TotalSeconds }
        }
    }

    $statusStyle = switch ([string]$Job.Status)
    {
        'Completed' { 'background:#1b5e20;color:#66bb6a;' }
        'Failed'    { 'background:#7f0000;color:#ef9a9a;' }
        'Warning'   { 'background:#4a3000;color:#ffa726;' }
        'Running'   { 'background:#0d47a1;color:#90caf9;' }
        'Error'     { 'background:#7f0000;color:#ef9a9a;' }
        Default     { 'background:#263238;color:#90a4ae;' }
    }

    $jobIdStr    = [string]$Job.Id
    $scriptPath  = [System.Net.WebUtility]::HtmlEncode([string]$Job.ScriptFullPath)
    $statusLabel = [System.Net.WebUtility]::HtmlEncode(([string]$Job.Status).ToUpper())

    $chipId      = 'job-id-chip-' + $jobIdStr
    $copyOnClick = (
        "navigator.clipboard.writeText('" + $jobIdStr + "')." +
        "then(function(){" +
        "var e=document.getElementById('" + $chipId + "');" +
        "var o=e.innerHTML;" +
        "e.textContent='Copied!';" +
        "e.style.color='#66bb6a';" +
        "setTimeout(function(){e.innerHTML=o;e.style.color='#90a4ae';},1500)" +
        "}).catch(function(){})"
    )

    $metaCol = 'display:flex;flex-direction:column;gap:3px;'
    $metaLbl = 'color:#546e7a;font-size:10px;font-family:Consolas,Monaco,monospace;text-transform:uppercase;letter-spacing:0.6px;'
    $metaVal = 'color:#b0bec5;font-size:12px;font-family:Consolas,Monaco,monospace;'

    # Inline SVG decoration - terminal icon top-right of the card
    $decorSvgHtml = ''
    $moduleBase   = $MyInvocation.MyCommand.Module.ModuleBase
    if ($moduleBase)
    {
        $imagesPath = Join-Path -Path $moduleBase -ChildPath 'images'
        $imagesPath = Join-Path -Path $imagesPath -ChildPath 'synedgy_pwsh'
        $svgPath    = Join-Path -Path $imagesPath -ChildPath 'pwsh_custom_terminal_blueandwhite.svg'
        if ([System.IO.File]::Exists($svgPath))
        {
            $pfx = 'jh-' + $jobIdStr
            $c = [System.IO.File]::ReadAllText($svgPath)
            $c = $c -replace '<\?xml[^>]*\?>', ''
            $c = $c -replace 'id="([^"]+)"',         "id=`"$pfx-`$1`""
            $c = $c -replace 'url\(#([^)]+)\)',       "url(#$pfx-`$1)"
            $c = $c -replace 'xlink:href="#([^"]+)"', "xlink:href=`"#$pfx-`$1`""
            $c = $c -replace '\.cls-(\d+)',            ".$pfx-cls-`$1"
            $c = $c -replace 'class="cls-(\d+)"',      "class=`"$pfx-cls-`$1`""
            $c = $c -replace '<svg ',                  '<svg style="width:auto;height:100%;" '
            $decorSvgHtml = '<div style="position:absolute;top:10px;right:16px;height:70px;opacity:0.18;pointer-events:none;">' + $c.Trim() + '</div>'
        }
    }

    $markup = (
        '<div style="position:relative;overflow:hidden;background:#1a2332;border-radius:8px;padding:16px 20px;margin-bottom:12px;border:1px solid #2d3d45;">' +
        $decorSvgHtml +

        '<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:14px;">' +
        '<span style="color:#e0e0e0;font-family:Consolas,Monaco,monospace;font-size:13px;font-weight:600;">' + $scriptPath + '</span>' +
        '<span id="' + $chipId + '" onclick="' + $copyOnClick + '" title="Click to copy Job ID" ' +
        'style="background:#263238;color:#90a4ae;font-family:Consolas,Monaco,monospace;font-size:11px;' +
        'padding:3px 10px;border-radius:12px;border:1px solid #37474f;cursor:pointer;user-select:none;white-space:nowrap;">' +
        '#' + $jobIdStr + '&nbsp;&nbsp;&#10697;' +
        '</span>' +
        '</div>' +

        '<div style="display:flex;gap:24px;flex-wrap:wrap;align-items:flex-start;">' +

        '<div style="' + $metaCol + '">' +
        '<span style="' + $metaLbl + '">Status</span>' +
        '<span style="' + $statusStyle + 'font-size:11px;font-family:Consolas,Monaco,monospace;font-weight:700;padding:2px 10px;border-radius:3px;letter-spacing:0.3px;">' + $statusLabel + '</span>' +
        '</div>' +

        '<div style="' + $metaCol + '">' +
        '<span style="' + $metaLbl + '">Created</span>' +
        '<span style="' + $metaVal + '">' + [System.Net.WebUtility]::HtmlEncode($createdStr) + '</span>' +
        '</div>' +

        '<div style="' + $metaCol + '">' +
        '<span style="' + $metaLbl + '">Started</span>' +
        '<span style="' + $metaVal + '">' + [System.Net.WebUtility]::HtmlEncode($startedStr) + '</span>' +
        '</div>' +

        '<div style="' + $metaCol + '">' +
        '<span style="' + $metaLbl + '">Completed</span>' +
        '<span style="' + $metaVal + '">' + [System.Net.WebUtility]::HtmlEncode($completedStr) + '</span>' +
        '</div>' +

        '<div style="' + $metaCol + '">' +
        '<span style="' + $metaLbl + '">Duration</span>' +
        '<span style="' + $metaVal + '">' + [System.Net.WebUtility]::HtmlEncode($durationStr) + '</span>' +
        '</div>' +

        '</div>' +
        '</div>'
    )

    New-UDHtml -Markup $markup
}
