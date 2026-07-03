function New-UDPsuJobTerminalView
{
    <#
        .SYNOPSIS
        Renders a terminal-style view for a PowerShell Universal job.

        .DESCRIPTION
        Displays job output in a terminal-style window. The terminal content panel is a
        New-UDDynamic that refreshes on demand via a button click, fetching the latest
        output from Get-PSUJobOutput each time. The structured events tab and status bar
        are rendered once from the initial fetch at page load.

        Uses private helpers from synedgy.universal.helper: ConvertFrom-PsuJobOutputEntry,
        Convert-AnsiToHtml, Convert-PlainTextToHtml.

        .PARAMETER JobId
        The PSU job identifier to render output for.

        .PARAMETER AppToken
        PSU app token used to call Get-PSUJobOutput. If omitted, the call is made without
        an explicit token (suitable when running inside the PSU dashboard with an ambient
        connection).

        .PARAMETER UniversalServerUrl
        PSU server URL for Get-PSUJobOutput. Defaults to UniversalServerUrl from module
        config (via Get-ModuleConfig, when available), then http://localhost:5000.

        .PARAMETER MaxRows
        Maximum number of most-recent output rows to render. Use 0 for no limit.

        .PARAMETER IncludeStructuredTable
        Include a structured events tab alongside the terminal view.

        .PARAMETER JobStatus
        Current job status string (passed to the terminal dynamic for context).

        .PARAMETER JobOutputSnapshot
        Pre-fetched job output records used as initial data for the structured table
        and status bar. The terminal dynamic performs its own live fetch.

        .PARAMETER ElementId
        Root element id. Defaults to "psu-job-terminal-<JobId>".

        .PARAMETER AutoRefreshInterval
        Interval in seconds for auto-refreshing the terminal output when the job is active
        (not in a terminal state). Defaults to 5. Set to 0 to disable auto-refresh entirely.

        .PARAMETER Theme
        'Auto' (default) follows PSU's own theme switch live (PSU sets a `data-theme`
        attribute on <html> that updates instantly when the user toggles it, with no page
        reload), so this component's colors and icon variant switch automatically. 'Light'
        or 'Dark' force that theme for this component instance regardless of the ambient
        PSU theme.

        .PARAMETER CustomCss
        Optional raw CSS appended after the theme rules, so it naturally overrides them.
        For example, override a single color variable:
        '#psu-job-terminal-123 { --psu-term-accent: #ff00ff; }'.

        .PARAMETER HideLineNumbers
        Hides line numbers by default for a first-time viewer (shown by default when
        omitted). Once a viewer manually toggles line numbers, their choice is remembered
        in the browser's localStorage and takes precedence over this default on later
        visits.

        .PARAMETER HideTimestamps
        Hides timestamps by default for a first-time viewer (shown by default when
        omitted). Once a viewer manually toggles timestamps, their choice is remembered in
        the browser's localStorage and takes precedence over this default on later visits.

        .EXAMPLE
        New-UDPsuJobTerminalView -JobId 10494 -AppToken $secret:automation_bot_token -IncludeStructuredTable -AutoRefreshInterval 10

        .EXAMPLE
        # Force light theme regardless of PSU's ambient theme
        New-UDPsuJobTerminalView -JobId 10494 -Theme Light

        .EXAMPLE
        # Hide line numbers and timestamps by default for first-time viewers
        New-UDPsuJobTerminalView -JobId 10494 -HideLineNumbers -HideTimestamps
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low'
    )]
    [OutputType([object])]
    param
    (
        [Parameter(Mandatory = $true)]
        [Int64]
        $JobId,

        [Parameter()]
        [System.String]
        $AppToken,

        [Parameter()]
        [System.String]
        $UniversalServerUrl,

        [Parameter()]
        [ValidateRange(0, 5000)]
        [Int32]
        $MaxRows = 0,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $IncludeStructuredTable,

        [Parameter()]
        [System.String]
        $JobStatus,

        [Parameter()]
        [object[]]
        $JobOutputSnapshot = @(),

        [Parameter()]
        [System.String]
        $ElementId = ('psu-job-terminal-{0}' -f $JobId),

        [Parameter()]
        [ValidateRange(0, 300)]
        [Int32]
        $AutoRefreshInterval = 5,

        [Parameter()]
        [ValidateSet('Auto', 'Light', 'Dark')]
        [System.String]
        $Theme = 'Auto',

        [Parameter()]
        [System.String]
        $CustomCss = '',

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $HideLineNumbers,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $HideTimestamps
    )

    $resolvedAppToken = $AppToken

    $configUrl    = if (Get-Command -Name 'Get-ModuleConfig' -ErrorAction SilentlyContinue)
    {
        try { [string](Get-ModuleConfig).UniversalServerUrl } catch { $null }
    }
    $resolvedUrl  = if (-not [string]::IsNullOrWhiteSpace($UniversalServerUrl)) { $UniversalServerUrl.TrimEnd('/') }
                    elseif (-not [string]::IsNullOrWhiteSpace($configUrl))      { $configUrl.TrimEnd('/') }
                    else                                                         { 'http://localhost:5000' }

    $resolvedIncludeStructuredTable = $IncludeStructuredTable.IsPresent

    # --- Initial fetch: drives the structured table and status bar ---
    $initialRaw = @()
    try
    {
        $fetchParams = @{
            JobId        = $JobId
            AsObject     = $true
            ComputerName = $resolvedUrl
            ErrorAction  = 'Stop'
        }
        if (-not [string]::IsNullOrWhiteSpace($resolvedAppToken))
        {
            $fetchParams['AppToken'] = $resolvedAppToken
        }
        $initialRaw = @(Get-PSUJobOutput @fetchParams)
    }
    catch
    {
        $initialRaw = @()
    }

    if (@($initialRaw).Count -eq 0)
    {
        $initialRaw = @($JobOutputSnapshot)
    }

    $initialDisplayRows = @(
        $initialRaw |
            Microsoft.PowerShell.Utility\Sort-Object -Property Timestamp |
            ConvertFrom-PsuJobOutputEntry
    )
    if ($MaxRows -gt 0)
    {
        $initialDisplayRows = @($initialDisplayRows | Microsoft.PowerShell.Utility\Select-Object -Last $MaxRows)
    }

    # --- Status bar ---
    $streamCounts = @(
        $initialDisplayRows |
            Microsoft.PowerShell.Utility\Group-Object -Property Stream |
            Microsoft.PowerShell.Utility\Sort-Object -Property Name
    )
    $statusStreamSpans = @(
        $streamCounts.ForEach{
            $c = switch ($_.Name) {
                'Error' { 'var(--psu-term-stream-error)' }; 'Warning' { 'var(--psu-term-stream-warning)' }; 'Information' { 'var(--psu-term-stream-information)' }
                'Verbose' { 'var(--psu-term-stream-verbose)' }; 'Debug' { 'var(--psu-term-stream-debug)' }; Default { 'var(--psu-term-stream-default)' }
            }
            "<span style='color:{0};'>{1}:&thinsp;{2}</span>" -f $c, $_.Name, $_.Count
        }
    )
    $statusInner = if (@($statusStreamSpans).Count -gt 0)
    {
        ($statusStreamSpans -join "<span style='color:var(--psu-term-border);padding:0 6px;'>|</span>") +
        ("<span style='color:var(--psu-term-border);padding:0 6px;'>|</span><span style='color:var(--psu-term-muted-fg);'>Events:&nbsp;{0}</span>" -f @($initialDisplayRows).Count)
    }
    else
    {
        "<span style='color:var(--psu-term-muted-fg);'>Events:&nbsp;0</span>"
    }

    # --- Inline SVG assets from module images ---
    $svgIconHtml      = ''
    $svgWatermarkHtml = ''
    $moduleBase       = $MyInvocation.MyCommand.Module.ModuleBase
    if ($moduleBase)
    {
        $iconSvg = ConvertTo-UDPsuThemedIconMarkup -ModuleBase $moduleBase -IdPrefix ($ElementId + '-icon') -ExtraStyle 'height:26px;width:auto;display:block;' -Theme $Theme
        $wmSvg   = ConvertTo-UDPsuThemedIconMarkup -ModuleBase $moduleBase -IdPrefix ($ElementId + '-wm')   -ExtraStyle 'height:100%;width:auto;'         -Theme $Theme
        if ($iconSvg) { $svgIconHtml = '<span style="padding:4px 8px 4px 12px;display:flex;align-items:center;">' + $iconSvg + '</span><span style="padding:0 14px 0 0;color:var(--psu-term-fg);font-family:Consolas,Monaco,monospace;font-size:15px;font-weight:700;letter-spacing:2px;display:flex;align-items:center;border-right:1px solid var(--psu-term-border);">TERMINAL</span>' }
        if ($wmSvg)   { $svgWatermarkHtml = '<div style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);height:65%;pointer-events:none;opacity:0.05;z-index:0;">' + $wmSvg + '</div>' }
    }
    $iconSpan = if ($svgIconHtml) { $svgIconHtml } else { '<span style="padding:0 14px;color:var(--psu-term-accent);font-family:Consolas,Monaco,monospace;font-size:14px;font-weight:700;display:flex;align-items:center;border-right:1px solid var(--psu-term-border);">&gt;_</span>' }

    # --- Title bar ---
    if ($resolvedIncludeStructuredTable)
    {
        $onClickTerminal = (
            "document.getElementById('" + $ElementId + "-panel-terminal').style.display='';" +
            "document.getElementById('" + $ElementId + "-panel-structured').style.display='none';" +
            "document.getElementById('" + $ElementId + "-cbtn-terminal').style.background='var(--psu-term-tab-active-bg)';" +
            "document.getElementById('" + $ElementId + "-cbtn-terminal').style.color='var(--psu-term-fg)';" +
            "document.getElementById('" + $ElementId + "-cbtn-terminal').style.borderBottom='2px solid var(--psu-term-accent)';" +
            "document.getElementById('" + $ElementId + "-cbtn-structured').style.background='transparent';" +
            "document.getElementById('" + $ElementId + "-cbtn-structured').style.color='var(--psu-term-muted-fg)';" +
            "document.getElementById('" + $ElementId + "-cbtn-structured').style.borderBottom='2px solid transparent';"
        )
        $onClickStructured = (
            "document.getElementById('" + $ElementId + "-panel-structured').style.display='';" +
            "document.getElementById('" + $ElementId + "-panel-terminal').style.display='none';" +
            "document.getElementById('" + $ElementId + "-cbtn-structured').style.background='var(--psu-term-tab-active-bg)';" +
            "document.getElementById('" + $ElementId + "-cbtn-structured').style.color='var(--psu-term-fg)';" +
            "document.getElementById('" + $ElementId + "-cbtn-structured').style.borderBottom='2px solid var(--psu-term-accent)';" +
            "document.getElementById('" + $ElementId + "-cbtn-terminal').style.background='transparent';" +
            "document.getElementById('" + $ElementId + "-cbtn-terminal').style.color='var(--psu-term-muted-fg)';" +
            "document.getElementById('" + $ElementId + "-cbtn-terminal').style.borderBottom='2px solid transparent';"
        )
    # JS tooltip helper - appends to body to bypass overflow:hidden on parent containers
    $tipShow = "var _t=document.createElement('div');_t.id='psu-tip';_t.textContent=this.dataset.tip;" +
               "_t.style.cssText='position:fixed;background:var(--psu-term-tooltip-bg);color:var(--psu-term-tooltip-fg);font-family:Consolas,Monaco,monospace;font-size:11px;padding:4px 8px;border-radius:4px;pointer-events:none;z-index:99999;white-space:nowrap;box-shadow:0 2px 6px rgba(0,0,0,0.4);';" +
               "document.body.appendChild(_t);" +
               "var r=this.getBoundingClientRect();" +
               "_t.style.left=(r.left+r.width/2-_t.offsetWidth/2)+'px';" +
               "_t.style.top=(r.top-_t.offsetHeight-6)+'px';"
    $tipHide = "var _t=document.getElementById('psu-tip');if(_t)_t.remove();"

    $lnToggleJs = (
        "var p1=document.getElementById('" + $ElementId + "-panel-terminal');" +
        "var p2=document.getElementById('" + $ElementId + "-panel-structured');" +
        "if(p1)p1.classList.toggle('" + $ElementId + "-ln-hidden');" +
        "if(p2)p2.classList.toggle('" + $ElementId + "-ln-hidden');" +
        "var off=p1&&p1.classList.contains('" + $ElementId + "-ln-hidden');" +
        "this.style.opacity=off?'0.35':'1';" +
        "try{localStorage.setItem('" + $ElementId + "-ln',off?'0':'1')}catch(e){}"
    )
    $lnToggleBtn = (
        '<button id="' + $ElementId + '-ln-toggle" onclick="' + $lnToggleJs + '" data-tip="Toggle line numbers" ' +
        'onmouseenter="' + $tipShow + '" onmouseleave="' + $tipHide + '" ' +
        'style="padding:4px 10px;background:transparent;border:none;cursor:pointer;' +
        'color:var(--psu-term-muted-fg);font-family:Consolas,Monaco,monospace;font-size:13px;font-weight:700;' +
        'display:flex;align-items:center;outline:none;line-height:1;" ' +
        'onmouseover="this.style.color=''var(--psu-term-fg)''" onmouseout="this.style.color=''var(--psu-term-muted-fg)''">#</button>'
    )
    $tsToggleJs = (
        "var p1=document.getElementById('" + $ElementId + "-panel-terminal');" +
        "var p2=document.getElementById('" + $ElementId + "-panel-structured');" +
        "if(p1)p1.classList.toggle('" + $ElementId + "-ts-hidden');" +
        "if(p2)p2.classList.toggle('" + $ElementId + "-ts-hidden');" +
        "var off=p1&&p1.classList.contains('" + $ElementId + "-ts-hidden');" +
        "this.style.opacity=off?'0.35':'1';" +
        "try{localStorage.setItem('" + $ElementId + "-ts',off?'0':'1')}catch(e){}"
    )
    $tsToggleBtn = (
        '<button id="' + $ElementId + '-ts-toggle" onclick="' + $tsToggleJs + '" data-tip="Toggle timestamps" ' +
        'onmouseenter="' + $tipShow + '" onmouseleave="' + $tipHide + '" ' +
        'style="padding:4px 8px;background:transparent;border:none;cursor:pointer;' +
        'color:var(--psu-term-muted-fg);font-family:Consolas,Monaco,monospace;font-size:13px;' +
        'display:flex;align-items:center;outline:none;line-height:1;" ' +
        'onmouseover="this.style.color=''var(--psu-term-fg)''" onmouseout="this.style.color=''var(--psu-term-muted-fg)''">&#128336;</button>'
    )
    $toggleBtns = '<div style="margin-left:auto;display:flex;align-items:center;">' + $lnToggleBtn + $tsToggleBtn + '</div>'
    # Restore toggle states on initial render: an explicit prior user choice in localStorage
    # always wins; otherwise fall back to the -HideLineNumbers/-HideTimestamps defaults.
    $showLnDefaultJs = if ($HideLineNumbers.IsPresent) { 'false' } else { 'true' }
    $showTsDefaultJs = if ($HideTimestamps.IsPresent) { 'false' } else { 'true' }
    $lnRestoreJs = (
        "(function(){" +
        "try{" +
        "var p1=document.getElementById('" + $ElementId + "-panel-terminal');" +
        "var p2=document.getElementById('" + $ElementId + "-panel-structured');" +
        "var lnStored=localStorage.getItem('" + $ElementId + "-ln');" +
        "var lnVisible=(lnStored===null)?" + $showLnDefaultJs + ":(lnStored!=='0');" +
        "if(!lnVisible){" +
        "if(p1)p1.classList.add('" + $ElementId + "-ln-hidden');" +
        "if(p2)p2.classList.add('" + $ElementId + "-ln-hidden');" +
        "var b=document.getElementById('" + $ElementId + "-ln-toggle');if(b)b.style.opacity='0.35';}" +
        "var tsStored=localStorage.getItem('" + $ElementId + "-ts');" +
        "var tsVisible=(tsStored===null)?" + $showTsDefaultJs + ":(tsStored!=='0');" +
        "if(!tsVisible){" +
        "if(p1)p1.classList.add('" + $ElementId + "-ts-hidden');" +
        "if(p2)p2.classList.add('" + $ElementId + "-ts-hidden');" +
        "var b=document.getElementById('" + $ElementId + "-ts-toggle');if(b)b.style.opacity='0.35';}" +
        "}catch(e){}})();"
    )

        $titleBarHtml = (
            '<div style="display:flex;align-items:stretch;height:100%;width:100%;">' +
            $iconSpan +
            '<button role="tab" id="' + $ElementId + '-cbtn-terminal" onclick="' + $onClickTerminal + '" style="padding:8px 16px;background:var(--psu-term-tab-active-bg);color:var(--psu-term-fg);border:none;border-right:1px solid var(--psu-term-border);cursor:pointer;font-family:Consolas,Monaco,monospace;font-size:12px;border-bottom:2px solid var(--psu-term-accent);outline:none;">Output</button>' +
            '<button role="tab" id="' + $ElementId + '-cbtn-structured" onclick="' + $onClickStructured + '" style="padding:8px 16px;background:transparent;color:var(--psu-term-muted-fg);border:none;border-right:1px solid var(--psu-term-border);cursor:pointer;font-family:Consolas,Monaco,monospace;font-size:12px;border-bottom:2px solid transparent;outline:none;">Structured Events</button>' +
            $toggleBtns +
            '</div>'
        )
    }
    else
    {
        $titleBarHtml = (
            '<div style="display:flex;align-items:center;height:100%;width:100%;">' +
            $iconSpan +
            '<span style="color:var(--psu-term-muted-fg);font-family:Consolas,Monaco,monospace;font-size:12px;padding:0 12px;display:flex;align-items:center;">Output</span>' +
            $toggleBtns +
            '</div>'
        )
    }

    if (-not $PSCmdlet.ShouldProcess($JobId, 'Render PSU job terminal view'))
    {
        return
    }

    $terminalStates      = @('Completed', 'Failed', 'Warning', 'Error', 'Stopped')
    $isTerminalJob       = [string]$JobStatus -in $terminalStates
    $terminalDynamicId   = "$ElementId-terminal-content"
    $structuredDynamicId = "$ElementId-structured-content"
    # ArgumentList: 0=JobId, 1=Token, 2=Url, 3=MaxRows, 4=view, 5=ElementId
    $dynArgs = @($JobId, $resolvedAppToken, $resolvedUrl, $MaxRows)

    # Shared dynamic content factory - fetches output and renders the given view type.
    # viewType: 'terminal' | 'structured'
    $makeDynContent = {
        $dynJobId   = [Int64]$ArgumentList[0]
        $dynToken   = [string]$ArgumentList[1]
        $dynUrl     = [string]$ArgumentList[2]
        $dynMaxRows = [Int32]$ArgumentList[3]
        $dynView    = [string]$ArgumentList[4]   # 'terminal' or 'structured'
        $dynEid     = [string]$ArgumentList[5]   # ElementId for CSS class scoping

        Microsoft.PowerShell.Core\Import-Module -Name 'synedgy.universal.helper' -ErrorAction SilentlyContinue
        $helperModule = Microsoft.PowerShell.Core\Get-Module -Name 'synedgy.universal.helper'

        $dynRaw = @()
        try
        {
            $fetchParams = @{
                JobId        = $dynJobId
                AsObject     = $true
                ComputerName = $dynUrl
                ErrorAction  = 'Stop'
            }
            if (-not [string]::IsNullOrWhiteSpace($dynToken))
            {
                $fetchParams['AppToken'] = $dynToken
            }
            $dynRaw = @(Get-PSUJobOutput @fetchParams)
        }
        catch { $dynRaw = @() }

        $markup = if ($null -ne $helperModule)
        {
            & $helperModule {
                param($raw, $max, $view, $eid)
                $rows = @($raw | Sort-Object -Property Timestamp | ConvertFrom-PsuJobOutputEntry)
                if ($max -gt 0) { $rows = @($rows | Select-Object -Last $max) }
                $lnClass = 'ln-' + $eid
                $tsClass = 'ts-' + $eid
                $lnStyle = 'color:var(--psu-term-muted-fg);min-width:3ch;text-align:right;margin-right:12px;user-select:none;flex-shrink:0;font-variant-numeric:tabular-nums;'

                if ($view -eq 'structured')
                {
                    $i = 0
                    $structRows = @($rows | ForEach-Object {
                        $i++
                        $ts      = if ($_.Timestamp) { '{0:yyyy-MM-dd HH:mm:ss}' -f ($_.Timestamp -as [datetime]) } else { '' }
                        $msgHtml = $_.Message | Convert-PlainTextToHtml
                        "<tr><td class='$lnClass' style='padding:4px 6px 4px 10px;color:var(--psu-term-muted-fg);text-align:right;user-select:none;white-space:nowrap;vertical-align:top;font-variant-numeric:tabular-nums;'>$i</td><td class='$tsClass' style='padding:4px 10px;color:var(--psu-term-muted-fg);white-space:nowrap;vertical-align:top;'>{0}</td><td style='padding:4px 10px;color:{1};font-weight:600;white-space:nowrap;vertical-align:top;'>{2}</td><td style='padding:4px 10px;color:var(--psu-term-fg);white-space:pre-wrap;vertical-align:top;'>{3}</td></tr>" -f [System.Net.WebUtility]::HtmlEncode($ts), $_.StreamColor, [System.Net.WebUtility]::HtmlEncode($_.Stream), $msgHtml
                    })
                    '<div style="max-height:500px;overflow:auto;background:var(--psu-term-bg);"><table style="width:100%;border-collapse:collapse;font-family:Consolas,Monaco,monospace;font-size:12px;"><thead><tr><th class="' + $lnClass + '" style="text-align:right;padding:6px 6px 6px 10px;color:var(--psu-term-muted-fg);border-bottom:1px solid var(--psu-term-border);background:var(--psu-term-bg);position:sticky;top:0;user-select:none;">#</th><th class="' + $tsClass + '" style="text-align:left;padding:6px 10px;color:var(--psu-term-muted-fg);border-bottom:1px solid var(--psu-term-border);background:var(--psu-term-bg);position:sticky;top:0;">Timestamp</th><th style="text-align:left;padding:6px 10px;color:var(--psu-term-muted-fg);border-bottom:1px solid var(--psu-term-border);background:var(--psu-term-bg);position:sticky;top:0;">Stream</th><th style="text-align:left;padding:6px 10px;color:var(--psu-term-muted-fg);border-bottom:1px solid var(--psu-term-border);background:var(--psu-term-bg);position:sticky;top:0;">Message</th></tr></thead><tbody>' + ($structRows -join '') + '</tbody></table></div>'
                }
                else
                {
                    $i = 0
                    $lines = @($rows | ForEach-Object {
                        $i++
                        $ts      = if ($_.Timestamp) { '{0:yyyy-MM-dd HH:mm:ss}' -f ($_.Timestamp -as [datetime]) } else { '' }
                        $msgHtml = $_.Message | Convert-AnsiToHtml
                        "<div style='display:flex;margin:0 0 4px 0;'><span class='$lnClass' style='$lnStyle'>$i</span><span><span class='$tsClass' style='color:var(--psu-term-muted-fg);'>[{0}]</span> <span style='color:{1};font-weight:600;'>[{2}]</span> <span>{3}</span></span></div>" -f $ts, $_.StreamColor, $_.Stream, $msgHtml
                    })
                    '<div style="font-family:Consolas,Monaco,monospace;font-size:12px;line-height:1.4;max-height:500px;overflow:auto;background:transparent;color:var(--psu-term-fg);padding:12px 14px;position:relative;z-index:1;">' + ($lines -join '') + '</div>'
                }
            } $dynRaw ([Int32]$dynMaxRows) $dynView $dynEid
        }
        else
        {
            '<div style="font-family:Consolas,Monaco,monospace;font-size:12px;padding:12px 14px;background:var(--psu-term-bg);color:var(--psu-term-stream-error);">Module unavailable.</div>'
        }

        $refreshedAt = '{0:yyyy-MM-dd HH:mm:ss}' -f [datetime]::Now
        New-UDHtml -Markup ($markup + "<div style='font-family:Consolas,Monaco,monospace;font-size:10px;color:var(--psu-term-muted-fg);padding:2px 14px 4px;background:var(--psu-term-bg);'>fetched $refreshedAt</div>")
    }

    New-UDElement -Tag 'div' -Id $ElementId -Attributes @{
        style = @{
            borderRadius = '6px'
            overflow     = 'hidden'
            border       = '1px solid var(--psu-term-border)'
            boxShadow    = '0 2px 8px rgba(0,0,0,0.3)'
            marginTop    = '4px'
        }
    } -Content {

        # Theme CSS custom properties (see Get-UDPsuJobThemeStyleBlock), line-number/timestamp
        # toggle CSS, and localStorage restore script. Emitted once here (not inside the
        # auto-refreshing dynamic panels below) since New-UDHtml's dangerouslySetInnerHTML
        # would otherwise reset it on every refresh.
        $themeStyleBlock = Get-UDPsuJobThemeStyleBlock -ElementId $ElementId -Theme $Theme -CustomCss $CustomCss
        $lnCss = '.' + $ElementId + '-ln-hidden .ln-' + $ElementId + ' { display:none !important; }' +
                 '.' + $ElementId + '-ts-hidden .ts-' + $ElementId + ' { display:none !important; }'
        New-UDHtml -Markup ($themeStyleBlock + '<style>' + $lnCss + '</style><script>' + $lnRestoreJs + '</script>')

        # Title bar
        New-UDElement -Tag 'div' -Attributes @{
            style = @{
                background   = 'var(--psu-term-chrome-bg)'
                display      = 'block'
                borderBottom = '1px solid var(--psu-term-border)'
            }
        } -Content {
            New-UDHtml -Markup $titleBarHtml
        }

        # Terminal panel - PSU wrapper preserves display style across dynamic re-renders
        New-UDElement -Tag 'div' -Id "$ElementId-panel-terminal" -Attributes @{
            style = @{ background = 'var(--psu-term-bg)'; position = 'relative' }
        } -Content {
            if ($svgWatermarkHtml) { New-UDHtml -Markup $svgWatermarkHtml }
            $termDynParams = @{
                Id           = $terminalDynamicId
                Content      = $makeDynContent
                ArgumentList = @($JobId, $resolvedAppToken, $resolvedUrl, $MaxRows, 'terminal', $ElementId)
            }
            if (-not $isTerminalJob -and $AutoRefreshInterval -gt 0)
            {
                $termDynParams['AutoRefresh']         = $true
                $termDynParams['AutoRefreshInterval'] = $AutoRefreshInterval
            }
            New-UDDynamic @termDynParams
        }

        # Structured panel - PSU wrapper, initially hidden; display controlled by tab JS only
        if ($resolvedIncludeStructuredTable)
        {
            New-UDElement -Tag 'div' -Id "$ElementId-panel-structured" -Attributes @{
                style = @{ display = 'none' }
            } -Content {
                New-UDDynamic -Id $structuredDynamicId -Content $makeDynContent -ArgumentList @($JobId, $resolvedAppToken, $resolvedUrl, $MaxRows, 'structured', $ElementId)
            }
        }

        # Status bar + refresh button (syncs both dynamics)
        $liveIndicator = if (-not $isTerminalJob) {
            "<span style='color:var(--psu-term-accent);margin-right:8px;'>&#9679;&nbsp;live</span>"
        } else { '' }

        New-UDElement -Tag 'div' -Attributes @{
            style = @{
                background   = 'var(--psu-term-status-bar-bg)'
                padding      = '4px 14px'
                borderTop    = '1px solid var(--psu-term-border)'
                fontFamily   = 'Consolas,Monaco,monospace'
                fontSize     = '11px'
                display      = 'flex'
                alignItems   = 'center'
            }
        } -Content {
            New-UDHtml -Markup ($liveIndicator + $statusInner)
            New-UDButton -Variant 'text' -Size 'small' -Icon (New-UDIcon -Icon 'sync') -OnClick {
                Sync-UDElement -Id $terminalDynamicId -ArgumentList @($JobId, $resolvedAppToken, $resolvedUrl, $MaxRows, 'terminal', $ElementId)
                if ($resolvedIncludeStructuredTable)
                {
                    Sync-UDElement -Id $structuredDynamicId -ArgumentList @($JobId, $resolvedAppToken, $resolvedUrl, $MaxRows, 'structured', $ElementId)
                }
            } -Style @{
                color      = 'var(--psu-term-muted-fg)'
                marginLeft = 'auto'
                minWidth   = 'unset'
                padding    = '0 8px'
                fontSize   = '11px'
            }
        }
    }
}
