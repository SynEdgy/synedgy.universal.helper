function New-UDLanguageSelector
{
    <#
        .SYNOPSIS
        Creates a persistent Universal Dashboard language selector.

        .DESCRIPTION
        Discovers localization cultures from the consuming module and renders a
        Universal Dashboard select element. An explicit selection is persisted
        in a browser cookie and the page is reloaded so server-side localization
        can resolve the new language.

        ModuleBase is optional. When omitted, the consuming module is resolved
        through invocation metadata and the first non-helper module in the
        PowerShell call stack.

        .PARAMETER Language
        The currently selected language identifier.

        .PARAMETER Name
        The localization resource bundle name used to discover culture folders.

        .PARAMETER ModuleBase
        The module base containing culture directories. When omitted, the
        consuming caller module is resolved automatically.

        .PARAMETER LanguageDisplayName
        Optional language identifiers and custom display names. Languages without
        an override use their English CultureInfo name unless
        UseNativeLanguageName is specified.

        .PARAMETER Id
        The dashboard element identifier assigned to the selector.

        .PARAMETER ClassName
        A CSS class applied to the visual select root for site-level styling.

        .PARAMETER CookieName
        The browser cookie used to persist an explicit selection.

        .PARAMETER CookieMaxAge
        The cookie lifetime in seconds.

        .PARAMETER UseLanguageLabel
        Displays compact uppercase culture identifiers, such as EN and FR,
        instead of full language names.

        .PARAMETER UseNativeLanguageName
        Displays each culture's native name, such as English, français, and
        Deutsch, instead of its English name. Cannot be combined with
        UseLanguageLabel.

        .PARAMETER Sx
        Material UI style overrides passed directly to New-UDSelect.

        .EXAMPLE
        New-UDLanguageSelector -Language 'en' -Name 'PSUConfigDemo'

        Discovers resources from the calling module and renders full names.

        .EXAMPLE
        $selectorParameters = @{
            Language        = 'fr'
            Name            = 'PSUConfigDemo'
            UseLanguageLabel = $true
            ClassName       = 'site-language-selector'
            Sx              = @{
                alignSelf = 'center'
                height    = '36px'
                '& .MuiSelect-select' = @{
                    paddingTop    = '2px'
                    paddingBottom = '2px'
                }
            }
        }
        New-UDLanguageSelector @selectorParameters

        Renders a compact selector using automatically discovered languages.

        .EXAMPLE
        New-UDLanguageSelector -Language 'fr' -Name 'PSUConfigDemo' -UseNativeLanguageName

        Renders each option using the language's own name.
    #>
    [CmdletBinding(
        SupportsShouldProcess = $true,
        ConfirmImpact = 'Low'
    )]
    [OutputType([System.Object])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Language,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleBase = $(if ($callingModule = ((Get-PSCallStack)[0]).InvocationInfo.MyCommand.Module) { $callingModule.ModuleBase }),

        [Parameter()]
        [System.Collections.IDictionary]
        $LanguageDisplayName,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Id = 'ud-language-selector',

        [Parameter()]
        [System.String]
        $ClassName,

        [Parameter()]
        [ValidatePattern('^[A-Za-z0-9_-]+$')]
        [System.String]
        $CookieName = 'PSULanguage',

        [Parameter()]
        [ValidateRange(1, 2147483647)]
        [System.Int32]
        $CookieMaxAge = 31536000,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $UseLanguageLabel,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $UseNativeLanguageName,

        [Parameter()]
        [ValidateNotNull()]
        [System.Collections.IDictionary]
        $Sx = @{}
    )

    if ($UseLanguageLabel.IsPresent -and $UseNativeLanguageName.IsPresent)
    {
        throw [System.ArgumentException]::new(
            'UseLanguageLabel and UseNativeLanguageName cannot be combined.'
        )
    }

    $languageParameters = @{
        Name = $Name
    }
    if (-not [System.String]::IsNullOrWhiteSpace($ModuleBase))
    {
        $languageParameters.ModuleBase = $ModuleBase
    }

    $languages = @(Get-PSULocalizationLanguage @languageParameters)
    if ($Language -notin $languages)
    {
        throw [System.ArgumentException]::new(
            "Current language '$Language' is not available for resource '$Name'.",
            'Language'
        )
    }

    $languageOptions = [ordered] @{}
    foreach ($availableLanguage in $languages)
    {
        $displayName = $null
        if ($null -ne $LanguageDisplayName -and $LanguageDisplayName.Contains($availableLanguage))
        {
            $displayName = [System.String] $LanguageDisplayName[$availableLanguage]
        }

        if ([System.String]::IsNullOrWhiteSpace($displayName))
        {
            try
            {
                $culture = [System.Globalization.CultureInfo]::GetCultureInfo(
                    $availableLanguage
                )
                $displayName = if ($UseNativeLanguageName.IsPresent)
                {
                    $culture.NativeName
                }
                else
                {
                    $culture.EnglishName
                }
            }
            catch [System.Globalization.CultureNotFoundException]
            {
                $displayName = $availableLanguage
            }
        }

        $languageOptions[$availableLanguage] = $displayName
    }

    $resolvedLanguageOptions = $languageOptions
    $useLanguageLabelValue = $UseLanguageLabel.IsPresent

    if ($PSCmdlet.ShouldProcess($Id, 'Render persistent language selector'))
    {
        $Page:UDLanguageSelectorConfiguration = @{
            Languages    = $languages
            CookieName   = $CookieName
            CookieMaxAge = $CookieMaxAge
        }

        $selectParameters = @{
            Id           = $Id
            ClassName    = $ClassName
            DefaultValue = $Language
            Variant      = 'outlined'
            Sx           = $Sx
            Option       = {
                foreach ($entry in $resolvedLanguageOptions.GetEnumerator())
                {
                    $languageName = [System.String] $entry.Key
                    $optionName = if ($useLanguageLabelValue)
                    {
                        $languageName.ToUpperInvariant()
                    }
                    else
                    {
                        [System.String] $entry.Value
                    }

                    New-UDSelectOption -Name $optionName -Value $languageName
                }
            }
            OnChange     = {
                $selectedLanguage = [System.String] $EventData
                $selectorConfiguration = $Page:UDLanguageSelectorConfiguration

                if ($selectedLanguage -notin $selectorConfiguration.Languages)
                {
                    throw "Unsupported language '$selectedLanguage'."
                }

                $javaScript = @'
document.cookie = '{0}={1}; Path=/; Max-Age={2}; SameSite=Lax';
window.location.reload();
'@ -f $selectorConfiguration.CookieName, $selectedLanguage, $selectorConfiguration.CookieMaxAge

                Invoke-UDJavaScript -JavaScript $javaScript -IgnoreResult
            }
        }

        New-UDSelect @selectParameters
    }
}
