function Get-UDPsuJobThemePalette
{
    <#
        .SYNOPSIS
        Returns the light and dark color palettes used by the PSU job UD components.

        .DESCRIPTION
        Single source of truth for the CSS custom property values used by
        New-UDPsuJobHeader and New-UDPsuJobTerminalView to theme their rendered markup.
        The light palette is inspired by the classic PowerShell ISE / VS Code light theme
        color conventions (white background, dark text, ISE-style syntax accent colors for
        the job output stream types). The dark palette preserves the original color scheme.

        .EXAMPLE
        $palette = Get-UDPsuJobThemePalette
        $palette.Light['bg']
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param ()

    return @{
        Light = [ordered]@{
            'bg'                 = '#ffffff'
            'chrome-bg'          = '#f3f3f3'
            'fg'                 = '#1e1e1e'
            'muted-fg'           = '#6e6e6e'
            'border'             = '#d4d4d4'
            'accent'             = '#0060c0'
            'tooltip-bg'         = '#e8e8e8'
            'tooltip-fg'         = '#1e1e1e'
            'status-bar-bg'      = '#eaeaea'
            'chip-bg'            = '#eeeeee'
            'tab-active-bg'      = '#ffffff'
            'stream-error'       = '#a31515'
            'stream-warning'     = '#b5860b'
            'stream-information' = '#0451a5'
            'stream-verbose'     = '#008080'
            'stream-debug'       = '#af00db'
            'stream-default'     = '#1e1e1e'
        }
        Dark = [ordered]@{
            'bg'                 = '#111111'
            'chrome-bg'          = '#263238'
            'fg'                 = '#e0e0e0'
            'muted-fg'           = '#90a4ae'
            'border'             = '#37474f'
            'accent'             = '#42a5f5'
            'tooltip-bg'         = '#37474f'
            'tooltip-fg'         = '#e0e0e0'
            'status-bar-bg'      = '#1c2429'
            'chip-bg'            = '#263238'
            'tab-active-bg'      = '#1e2a2f'
            'stream-error'       = '#ef5350'
            'stream-warning'     = '#ffa726'
            'stream-information' = '#42a5f5'
            'stream-verbose'     = '#ffee58'
            'stream-debug'       = '#ab47bc'
            'stream-default'     = '#e0e0e0'
        }
    }
}
