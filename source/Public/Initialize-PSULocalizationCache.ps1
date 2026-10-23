function Initialize-PSULocalizationCache
{
    <#
        .SYNOPSIS
        Initializes localization dictionaries for every available language.

        .DESCRIPTION
        Discovers the languages available for a named localization resource,
        loads each dictionary, and optionally replaces the contents of a
        caller-supplied cache. The consuming module base is discovered during
        parameter binding when ModuleBase is omitted.

        .PARAMETER Name
        The mandatory base name of the localization resource bundle.

        .PARAMETER ModuleBase
        The module base containing culture directories. When omitted, the
        command resolves the consuming caller module automatically.

        .PARAMETER DefaultUICulture
        The fallback culture whose localization resource is required.

        .PARAMETER Cache
        An optional dictionary to replace with language-keyed localized data.

        .PARAMETER Force
        Bypasses the underlying localized-data caches.

        .EXAMPLE
        Initialize-PSULocalizationCache -Name 'PSUConfigDemo' -Cache $Cache:PSUConfigLocalization

        Loads every PSUConfigDemo language into the supplied app-wide cache.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
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
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DefaultUICulture = 'en',

        [Parameter()]
        [System.Collections.IDictionary]
        $Cache,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Force
    )

    if ([System.String]::IsNullOrWhiteSpace($ModuleBase))
    {
        $message = 'Unable to resolve the consuming module base. Pass ModuleBase explicitly.'
        throw [System.InvalidOperationException]::new($message)
    }

    $cacheWasProvided = $PSBoundParameters.ContainsKey('Cache')
    if ($cacheWasProvided -and $null -eq $Cache)
    {
        throw [System.ArgumentNullException]::new(
            'Cache',
            'The cache dictionary cannot be null when the Cache parameter is supplied.'
        )
    }

    $languageParameters = @{
        ModuleBase = $ModuleBase
        Name       = $Name
    }
    $languages = @(Get-PSULocalizationLanguage @languageParameters)
    $localizedData = @{}

    foreach ($language in $languages)
    {
        $localizedDataParameters = @{
            ModuleBase       = $ModuleBase
            Name             = $Name
            UICulture        = $language
            DefaultUICulture = $DefaultUICulture
            Force            = $Force.IsPresent
        }
        $localizedData[$language] = Get-PSULocalizedData @localizedDataParameters
    }

    if ($cacheWasProvided)
    {
        $cacheLock = if ($Cache -is [System.Collections.ICollection])
        {
            $Cache.SyncRoot
        }
        else
        {
            $Cache
        }

        $cacheLockTaken = $false
        try
        {
            [System.Threading.Monitor]::Enter($cacheLock)
            $cacheLockTaken = $true
            $Cache.Clear()
            foreach ($language in $localizedData.Keys)
            {
                $Cache[$language] = $localizedData[$language]
            }
        }
        finally
        {
            if ($cacheLockTaken)
            {
                [System.Threading.Monitor]::Exit($cacheLock)
            }
        }
    }

    return $localizedData
}
