function Resolve-PSULocalizationLanguage
{
    <#
        .SYNOPSIS
        Resolves a supported language for a localization resource.

        .DESCRIPTION
        Selects a resource-backed language by checking an explicit preference
        first and then evaluating an HTTP Accept-Language value by quality and
        order. Exact and parent culture resources are considered before the
        configured default language.

        .PARAMETER Name
        The mandatory base name of the localization resource bundle.

        .PARAMETER ModuleBase
        The module base containing culture directories. When omitted, the
        command resolves the consuming caller module automatically.

        .PARAMETER PreferredLanguage
        An explicit language preference, such as a persisted user selection.

        .PARAMETER AcceptLanguage
        An HTTP Accept-Language header value.

        .PARAMETER DefaultUILanguage
        The language returned when no explicit or request preference resolves
        to an available localization resource.

        .EXAMPLE
        Resolve-PSULocalizationLanguage -Name 'PSUConfigDemo' -PreferredLanguage 'fr' -AcceptLanguage 'en-US,en;q=0.9'

        Returns fr because the explicit preference takes precedence.
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleBase = $(if ($callingModule = ((Get-PSCallStack)[0]).InvocationInfo.MyCommand.Module) { $callingModule.ModuleBase }),

        [Parameter()]
        [System.String]
        $PreferredLanguage,

        [Parameter()]
        [System.String]
        $AcceptLanguage,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DefaultUILanguage = 'en'
    )

    if ([System.String]::IsNullOrWhiteSpace($ModuleBase))
    {
        $message = 'Unable to resolve the consuming module base. Pass ModuleBase explicitly.'
        throw [System.InvalidOperationException]::new($message)
    }

    $languageParameters = @{
        ModuleBase = $ModuleBase
        Name       = $Name
    }
    $supportedLanguages = @(Get-PSULocalizationLanguage @languageParameters)
    $normalizedDefaultUILanguage = @(Get-PSULocalizationCultureChain -CultureName $DefaultUILanguage)[0]

    if ($normalizedDefaultUILanguage -notin $supportedLanguages)
    {
        $message = "Default UI language '$DefaultUILanguage' is not available for '$Name'."
        throw [System.ArgumentException]::new($message, 'DefaultUILanguage')
    }

    if (-not [System.String]::IsNullOrWhiteSpace($PreferredLanguage))
    {
        try
        {
            foreach ($candidateLanguage in @(Get-PSULocalizationCultureChain -CultureName $PreferredLanguage.Trim()))
            {
                if ($candidateLanguage -in $supportedLanguages)
                {
                    return $candidateLanguage
                }
            }
        }
        catch [System.Globalization.CultureNotFoundException]
        {
            Write-Verbose -Message ("Ignoring invalid preferred language '{0}'." -f $PreferredLanguage)
        }
    }

    $languagePreferences = @()
    $preferenceIndex = 0
    foreach ($headerValue in @($AcceptLanguage -split ','))
    {
        $segments = @($headerValue -split ';')
        $languageTag = $segments[0].Trim()
        if ([System.String]::IsNullOrWhiteSpace($languageTag) -or $languageTag -eq '*')
        {
            continue
        }

        $quality = 1.0
        foreach ($segment in $segments | Select-Object -Skip 1)
        {
            if ($segment.Trim() -match '^q=(?<Quality>0(?:\.\d+)?|1(?:\.0+)?)$')
            {
                $quality = [System.Double]::Parse(
                    $Matches.Quality,
                    [System.Globalization.CultureInfo]::InvariantCulture
                )
            }
        }

        if ($quality -gt 0)
        {
            $languagePreferences += [pscustomobject] @{
                Language = $languageTag
                Quality  = $quality
                Index    = $preferenceIndex
            }
        }

        $preferenceIndex++
    }

    $sortedPreferences = $languagePreferences |
        Sort-Object -Property @{ Expression = 'Quality'; Descending = $true }, Index

    foreach ($preference in $sortedPreferences)
    {
        try
        {
            foreach ($candidateLanguage in @(Get-PSULocalizationCultureChain -CultureName $preference.Language))
            {
                if ($candidateLanguage -in $supportedLanguages)
                {
                    return $candidateLanguage
                }
            }
        }
        catch [System.Globalization.CultureNotFoundException]
        {
            Write-Verbose -Message ("Ignoring invalid requested language '{0}'." -f $preference.Language)
        }
    }

    return $normalizedDefaultUILanguage
}
