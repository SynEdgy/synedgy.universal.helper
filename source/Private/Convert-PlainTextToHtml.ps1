function Convert-PlainTextToHtml
{
    <#
        .SYNOPSIS
        Strips ANSI escape sequences, HTML-encodes plain text, and converts newlines to <br/>.

        .DESCRIPTION
        Accepts a plain text string via pipeline or direct parameter. Removes all ANSI/VT100
        escape sequences, HTML-encodes the result, and replaces line endings with <br/> tags
        suitable for rendering in an HTML terminal view.

        .PARAMETER Text
        The plain text string to convert. Accepts pipeline input.

        .EXAMPLE
        'Hello <World>' | Convert-PlainTextToHtml
        # Returns: Hello &lt;World&gt;

        .EXAMPLE
        "Line 1`nLine 2" | Convert-PlainTextToHtml
        # Returns: Line 1<br/>Line 2
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]
        $Text
    )

    process
    {
        $value = if ($null -eq $Text) { '' } else { [string]$Text }
        $value = [regex]::Replace($value, '(?:\x1B|\u241B)\[[0-9;?]*[A-Za-z]', '')
        $encodedValue = [System.Net.WebUtility]::HtmlEncode($value)
        $encodedValue.Replace("`r`n", '<br/>').Replace("`n", '<br/>').Replace("`r", '<br/>')
    }
}
