function Get-PSULocalizationCultureChain
{
    <#
        .SYNOPSIS
        Gets a culture and its parent culture names.

        .DESCRIPTION
        Returns culture names from the requested exact culture toward its neutral
        parents. When the process uses invariant globalization, the function validates
        and normalizes the culture tag without creating non-invariant CultureInfo
        instances.

        .PARAMETER CultureName
        The culture name to normalize and expand into its parent culture chain.

        .EXAMPLE
        Get-PSULocalizationCultureChain -CultureName 'fr-CH'

        Returns fr-CH followed by fr.
    #>
    [CmdletBinding()]
    [OutputType([System.String[]])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CultureName
    )

    $cultureNamePattern = '^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$'
    if ($CultureName -notmatch $cultureNamePattern)
    {
        $message = "Culture name '$CultureName' is not a valid localization culture name."
        throw [System.Globalization.CultureNotFoundException]::new($message, 'CultureName', $CultureName)
    }

    # Determine if the current process is using the invariant culture.
    # Invariant culture makes it impossible to rely on the system's CultureInfo for normalization because
    # it does not provide culture-specific information like parent cultures or proper casing.
    $isInvariantCulture = (Get-UICulture).LCID -eq 127
    if (-not $isInvariantCulture)
    {
        try
        {
            $culture = [System.Globalization.CultureInfo]::GetCultureInfo($CultureName)
        }
        catch [System.Globalization.CultureNotFoundException]
        {
            $message = "Culture name '$CultureName' is not recognized by this system."
            throw [System.Globalization.CultureNotFoundException]::new($message, 'CultureName', $CultureName)
        }

        $cultureChain = [System.Collections.Generic.List[System.String]]::new()
        while ($culture -and -not [System.String]::IsNullOrEmpty($culture.Name))
        {
            $cultureChain.Add($culture.Name)
            $culture = $culture.Parent
        }

        return [System.String[]] $cultureChain.ToArray()
    }

    # Handle invariant culture by manually normalizing the culture name and constructing the culture chain.
    $cultureParts = $CultureName -split '-'
    $normalizedParts = [System.Collections.Generic.List[System.String]]::new()

    for ($index = 0; $index -lt $cultureParts.Count; $index++)
    {
        $part = $cultureParts[$index]
        if ($index -eq 0)
        {
            $normalizedParts.Add($part.ToLowerInvariant())
        }
        elseif ($part -match '^[A-Za-z]{4}$')
        {
            $normalizedParts.Add(
                $part.Substring(0, 1).ToUpperInvariant() + $part.Substring(1).ToLowerInvariant()
            )
        }
        elseif ($part -match '^[A-Za-z]{2}$')
        {
            $normalizedParts.Add($part.ToUpperInvariant())
        }
        else
        {
            $normalizedParts.Add($part.ToLowerInvariant())
        }
    }

    $cultureChain = [System.Collections.Generic.List[System.String]]::new()
    for ($length = $normalizedParts.Count; $length -ge 1; $length--)
    {
        $cultureChain.Add(($normalizedParts.GetRange(0, $length) -join '-'))
    }

    return [System.String[]] $cultureChain.ToArray()
}
