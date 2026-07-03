function ConvertTo-UDPsuThemedIconMarkup
{
    <#
        .SYNOPSIS
        Builds inline SVG markup for the synedgy PowerShell icon, themed for light/dark/auto.

        .DESCRIPTION
        Always uses the plain monochrome icon variants: pwsh_custom_black.svg for light theme
        and pwsh_custom_white.svg for dark theme. When Theme is 'Auto', both variants are
        rendered and wrapped in '.psu-theme-light-only' / '.psu-theme-dark-only' spans so that
        Get-UDPsuJobThemeStyleBlock's CSS rules can show/hide the correct one live, following
        PSU's own theme switch without a page reload. When Theme is 'Light' or 'Dark', only the
        matching variant is rendered directly (no wrapper spans needed).

        .PARAMETER ModuleBase
        The module's base path (from $MyInvocation.MyCommand.Module.ModuleBase in the caller),
        used to locate images/synedgy_pwsh/*.svg.

        .PARAMETER IdPrefix
        A unique prefix used to uniquify SVG element ids/classes so multiple inlined copies of
        the same SVG on one page do not collide.

        .PARAMETER ExtraStyle
        Inline CSS applied to the root <svg> element (sizing, display, etc.).

        .PARAMETER Theme
        'Auto' (default), 'Light', or 'Dark'.

        .EXAMPLE
        ConvertTo-UDPsuThemedIconMarkup -ModuleBase $moduleBase -IdPrefix 'jh-123' -ExtraStyle 'height:26px;' -Theme 'Auto'
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $ModuleBase,

        [Parameter(Mandatory = $true)]
        [System.String]
        $IdPrefix,

        [Parameter()]
        [System.String]
        $ExtraStyle = '',

        [Parameter()]
        [ValidateSet('Auto', 'Light', 'Dark')]
        [System.String]
        $Theme = 'Auto'
    )

    $imagesPath = Join-Path -Path $ModuleBase -ChildPath 'images'
    $imagesPath = Join-Path -Path $imagesPath -ChildPath 'synedgy_pwsh'
    $blackSvgPath = Join-Path -Path $imagesPath -ChildPath 'pwsh_custom_black.svg'
    $whiteSvgPath = Join-Path -Path $imagesPath -ChildPath 'pwsh_custom_white.svg'

    $renderSvg = {
        param([string]$svgPath, [string]$prefix, [string]$extraStyle)
        if (-not [System.IO.File]::Exists($svgPath)) { return '' }
        $c = [System.IO.File]::ReadAllText($svgPath)
        $c = $c -replace '<\?xml[^>]*\?>', ''
        # Uniquify gradient/element IDs and their references
        $c = $c -replace 'id="([^"]+)"',         "id=`"$prefix-`$1`""
        $c = $c -replace 'url\(#([^)]+)\)',       "url(#$prefix-`$1)"
        $c = $c -replace 'xlink:href="#([^"]+)"', "xlink:href=`"#$prefix-`$1`""
        # Uniquify CSS class names so two inlined SVGs don't share .cls-N rules
        $c = $c -replace '\.cls-(\d+)',           ".$prefix-cls-`$1"
        $c = $c -replace 'class="cls-(\d+)"',     "class=`"$prefix-cls-`$1`""
        $c = $c -replace '<svg ',                 "<svg style=`"$extraStyle`" "
        return $c.Trim()
    }

    switch ($Theme)
    {
        'Light'
        {
            return & $renderSvg $blackSvgPath ($IdPrefix + '-lt') $ExtraStyle
        }
        'Dark'
        {
            return & $renderSvg $whiteSvgPath ($IdPrefix + '-dk') $ExtraStyle
        }
        Default
        {
            $lightSvg = & $renderSvg $blackSvgPath ($IdPrefix + '-lt') $ExtraStyle
            $darkSvg  = & $renderSvg $whiteSvgPath ($IdPrefix + '-dk') $ExtraStyle

            $markup = ''
            if ($lightSvg)
            {
                $markup += '<span class="psu-theme-light-only" style="display:contents;">' + $lightSvg + '</span>'
            }
            if ($darkSvg)
            {
                $markup += '<span class="psu-theme-dark-only" style="display:none;">' + $darkSvg + '</span>'
            }
            return $markup
        }
    }
}
