function Get-UDPsuJobThemeStyleBlock
{
    <#
        .SYNOPSIS
        Builds the <style> block that themes a PSU job UD component instance.

        .DESCRIPTION
        Emits CSS custom properties (--psu-term-*) scoped to the component's own element id,
        so multiple instances on the same page never collide. When Theme is 'Auto', both the
        light (default) and dark (activated via PSU's own `html[data-theme="dark"]` attribute,
        which PSU's built-in theme switch sets and updates live) rule sets are emitted, so the
        component automatically follows PSU's theme without a page reload. When Theme is
        'Light' or 'Dark', only that palette is emitted, overriding the ambient PSU theme for
        this component instance. Also emits the show/hide rules used to swap between the
        black/white themed icon variants rendered by ConvertTo-UDPsuThemedIconMarkup.

        .PARAMETER ElementId
        The root element id of the component instance to scope these CSS rules to.

        .PARAMETER Theme
        'Auto' (default) follows PSU's theme switch live. 'Light' or 'Dark' force that theme
        for this component instance regardless of the ambient PSU theme.

        .PARAMETER CustomCss
        Optional raw CSS appended after the theme rules, so it naturally overrides them
        (e.g. targeting `#<ElementId> { --psu-term-accent: #ff00ff; }` or any other selector).

        .EXAMPLE
        Get-UDPsuJobThemeStyleBlock -ElementId 'psu-job-terminal-123' -Theme 'Auto'
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ElementId,

        [Parameter()]
        [ValidateSet('Auto', 'Light', 'Dark')]
        [System.String]
        $Theme = 'Auto',

        [Parameter()]
        [System.String]
        $CustomCss = ''
    )

    $palette = Get-UDPsuJobThemePalette

    $toVarsCss = {
        param($set)
        ($set.GetEnumerator() | ForEach-Object { '--psu-term-{0}:{1};' -f $_.Key, $_.Value }) -join ''
    }

    $rules = switch ($Theme)
    {
        'Light'
        {
            '#{0} {{ {1} }}' -f $ElementId, (& $toVarsCss $palette.Light)
        }
        'Dark'
        {
            '#{0} {{ {1} }}' -f $ElementId, (& $toVarsCss $palette.Dark)
        }
        Default
        {
            (
                ('#{0} {{ {1} }}' -f $ElementId, (& $toVarsCss $palette.Light)) +
                ('#{0} .psu-theme-light-only {{ display:contents; }}' -f $ElementId) +
                ('#{0} .psu-theme-dark-only {{ display:none; }}' -f $ElementId) +
                ('html[data-theme="dark"] #{0} {{ {1} }}' -f $ElementId, (& $toVarsCss $palette.Dark)) +
                ('html[data-theme="dark"] #{0} .psu-theme-light-only {{ display:none; }}' -f $ElementId) +
                ('html[data-theme="dark"] #{0} .psu-theme-dark-only {{ display:contents; }}' -f $ElementId)
            )
        }
    }

    return '<style>{0}{1}</style>' -f $rules, $CustomCss
}
