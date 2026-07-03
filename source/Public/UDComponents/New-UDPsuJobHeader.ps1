function New-UDPsuJobHeader
{
    <#
        .SYNOPSIS
        Renders a summary header card for a PowerShell Universal job.

        .DESCRIPTION
        Produces a styled HTML metadata card showing the script path, a
        copy-to-clipboard job ID chip, status badge, and timestamps
        (Created, Started, Completed, Duration). Designed to pair with
        New-UDPsuJobTerminalView on a job detail page, but can be used
        independently wherever a concise job summary is needed.

        Colors are driven by CSS custom properties defined in a per-instance
        <style> block (see Get-UDPsuJobThemeStyleBlock in synedgy.universal.helper),
        so the card automatically follows PSU's own light/dark theme switch (Theme
        'Auto', the default), or can be forced to a specific theme, or further
        customized via -CustomCss.

        .PARAMETER Job
        The PSU job object returned by Get-PSUJob. Used to derive all
        displayed fields.

        .PARAMETER ElementId
        Root element id, used to scope the theme CSS to this instance. Defaults
        to "psu-job-header-<JobId>".

        .PARAMETER Theme
        'Auto' (default) follows PSU's own theme switch live, with no page reload
        required. 'Light' or 'Dark' force that theme for this component instance
        regardless of the ambient PSU theme.

        .PARAMETER CustomCss
        Optional raw CSS appended after the theme rules, so it naturally overrides
        them. For example, override a single color variable:
        '#psu-job-header-123 { --psu-term-accent: #ff00ff; }'.

        .EXAMPLE
        $job = Get-PSUJob -Id $id -AppToken $token
        New-UDPsuJobHeader -Job $job

        .EXAMPLE
        # Typical usage on a job detail page
        $job = Get-PSUJob -Id ([Int64]$id)
        New-UDPsuJobHeader -Job $job
        New-UDPsuJobTerminalView -JobId $job.Id -JobStatus ([string]$job.Status) `
            -JobOutputSnapshot @($job.Output) -IncludeStructuredTable

        .EXAMPLE
        # Force dark theme regardless of PSU's ambient theme
        New-UDPsuJobHeader -Job $job -Theme Dark
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param
    (
        [Parameter(Mandatory)]
        $Job,

        [Parameter()]
        [System.String]
        $ElementId = ('psu-job-header-{0}' -f $Job.Id),

        [Parameter()]
        [ValidateSet('Auto', 'Light', 'Dark')]
        [System.String]
        $Theme = 'Auto',

        [Parameter()]
        [System.String]
        $CustomCss = ''
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
        Default     { 'background:var(--psu-term-chip-bg);color:var(--psu-term-muted-fg);' }
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
        "setTimeout(function(){e.innerHTML=o;e.style.color='';},1500)" +
        "}).catch(function(){})"
    )

    $metaCol = 'display:flex;flex-direction:column;gap:3px;'
    $metaLbl = 'color:var(--psu-term-muted-fg);font-size:10px;font-family:Consolas,Monaco,monospace;text-transform:uppercase;letter-spacing:0.6px;'
    $metaVal = 'color:var(--psu-term-fg);font-size:12px;font-family:Consolas,Monaco,monospace;'

    # Inline SVG decoration - terminal icon top-right of the card
    $decorSvgHtml = ''
    $moduleBase   = $MyInvocation.MyCommand.Module.ModuleBase
    if ($moduleBase)
    {
        $decorSvg = ConvertTo-UDPsuThemedIconMarkup -ModuleBase $moduleBase -IdPrefix ('jh-' + $jobIdStr) -ExtraStyle 'width:auto;height:100%;' -Theme $Theme
        if ($decorSvg)
        {
            $decorSvgHtml = '<div style="position:absolute;top:10px;right:16px;height:70px;opacity:0.18;pointer-events:none;">' + $decorSvg + '</div>'
        }
    }

    $themeStyleBlock = Get-UDPsuJobThemeStyleBlock -ElementId $ElementId -Theme $Theme -CustomCss $CustomCss

    $markup = (
        $themeStyleBlock +
        '<div id="' + $ElementId + '" style="position:relative;overflow:hidden;background:var(--psu-term-bg);border-radius:8px;padding:16px 20px;margin-bottom:12px;border:1px solid var(--psu-term-border);">' +
        $decorSvgHtml +

        '<div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-bottom:14px;">' +
        '<span style="color:var(--psu-term-fg);font-family:Consolas,Monaco,monospace;font-size:13px;font-weight:600;">' + $scriptPath + '</span>' +
        '<span id="' + $chipId + '" onclick="' + $copyOnClick + '" title="Click to copy Job ID" ' +
        'style="background:var(--psu-term-chip-bg);color:var(--psu-term-muted-fg);font-family:Consolas,Monaco,monospace;font-size:11px;' +
        'padding:3px 10px;border-radius:12px;border:1px solid var(--psu-term-border);cursor:pointer;user-select:none;white-space:nowrap;">' +
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
