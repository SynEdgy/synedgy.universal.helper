function Convert-AnsiToHtml
{
    <#
        .SYNOPSIS
        Converts a string containing ANSI SGR escape sequences to HTML with inline span styles.

        .DESCRIPTION
        Parses ANSI SGR color and bold sequences and wraps affected text in <span> elements
        with inline CSS. Text segments without ANSI codes are passed through
        Convert-PlainTextToHtml. Accepts pipeline input for use in streaming pipelines.

        .PARAMETER Message
        The string potentially containing ANSI escape sequences. Accepts pipeline input.

        .EXAMPLE
        "`e[32mSuccess`e[0m: done" | Convert-AnsiToHtml
        # Returns: <span style='color:#66bb6a;'>Success</span>: done

        .EXAMPLE
        Get-PSUJobOutput -JobId 1 | Select-Object -Exp Message | Convert-AnsiToHtml
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]
        $Message
    )

    process
    {
        $ansiForegroundMap = @{
            '30' = '#000000'; '31' = '#ef5350'; '32' = '#66bb6a'; '33' = '#ffee58'
            '34' = '#42a5f5'; '35' = '#ab47bc'; '36' = '#26c6da'; '37' = '#e0e0e0'
            '90' = '#9e9e9e'; '91' = '#e57373'; '92' = '#81c784'; '93' = '#fff176'
            '94' = '#64b5f6'; '95' = '#ba68c8'; '96' = '#4dd0e1'; '97' = '#ffffff'
        }
        $ansiBackgroundMap = @{
            '40' = '#000000'; '41' = '#b71c1c'; '42' = '#1b5e20'; '43' = '#f57f17'
            '44' = '#0d47a1'; '45' = '#4a148c'; '46' = '#006064'; '47' = '#bdbdbd'
            '100' = '#616161'; '101' = '#ef9a9a'; '102' = '#a5d6a7'; '103' = '#fff59d'
            '104' = '#90caf9'; '105' = '#ce93d8'; '106' = '#80deea'; '107' = '#eeeeee'
        }

        $text        = if ($null -eq $Message) { '' } else { [string]$Message }
        $ansiMatches = [regex]::Matches($text, '(?:\x1B|\u241B)\[([0-9;]*)m')

        if (@($ansiMatches).Count -eq 0)
        {
            return ($text | Convert-PlainTextToHtml)
        }

        $state        = @{ Bold = $false; Foreground = $null; Background = $null }
        $fragments    = [System.Collections.Generic.List[string]]::new()
        $currentIndex = 0

        foreach ($match in $ansiMatches)
        {
            if ($match.Index -gt $currentIndex)
            {
                $segmentHtml = $text.Substring($currentIndex, $match.Index - $currentIndex) | Convert-PlainTextToHtml
                $styleParts  = [System.Collections.Generic.List[string]]::new()
                if ($state.Bold) { $null = $styleParts.Add('font-weight:700') }
                if (-not [string]::IsNullOrWhiteSpace($state.Foreground)) { $null = $styleParts.Add('color:{0}' -f $state.Foreground) }
                if (-not [string]::IsNullOrWhiteSpace($state.Background)) { $null = $styleParts.Add('background-color:{0}' -f $state.Background) }
                $fragment = if ($styleParts.Count -eq 0) { $segmentHtml } else { "<span style='{0}'>{1}</span>" -f ($styleParts -join ';'), $segmentHtml }
                $null = $fragments.Add($fragment)
            }

            $codesRaw = $match.Groups[1].Value
            $codes = if ([string]::IsNullOrWhiteSpace($codesRaw)) { @('0') } else { @($codesRaw -split ';') }
            foreach ($code in $codes)
            {
                if ([string]::IsNullOrWhiteSpace($code)) { continue }
                switch ($code)
                {
                    '0'  { $state.Bold = $false; $state.Foreground = $null; $state.Background = $null; continue }
                    '1'  { $state.Bold = $true; continue }
                    '22' { $state.Bold = $false; continue }
                    '39' { $state.Foreground = $null; continue }
                    '49' { $state.Background = $null; continue }
                }
                if ($ansiForegroundMap.ContainsKey($code)) { $state.Foreground = $ansiForegroundMap[$code]; continue }
                if ($ansiBackgroundMap.ContainsKey($code)) { $state.Background = $ansiBackgroundMap[$code]; continue }
            }

            $currentIndex = $match.Index + $match.Length
        }

        if ($currentIndex -lt $text.Length)
        {
            $segmentHtml = $text.Substring($currentIndex) | Convert-PlainTextToHtml
            $styleParts  = [System.Collections.Generic.List[string]]::new()
            if ($state.Bold) { $null = $styleParts.Add('font-weight:700') }
            if (-not [string]::IsNullOrWhiteSpace($state.Foreground)) { $null = $styleParts.Add('color:{0}' -f $state.Foreground) }
            if (-not [string]::IsNullOrWhiteSpace($state.Background)) { $null = $styleParts.Add('background-color:{0}' -f $state.Background) }
            $fragment = if ($styleParts.Count -eq 0) { $segmentHtml } else { "<span style='{0}'>{1}</span>" -f ($styleParts -join ';'), $segmentHtml }
            $null = $fragments.Add($fragment)
        }

        $fragments -join ''
    }
}
