function Get-PSUComponentLocalizedData
{
    <#
        .SYNOPSIS
        Gets localized strings for a PowerShell Universal component.

        .DESCRIPTION
        Resolves a component's requested language against its resource-backed
        cultures, then falls back to the module-configured default language and
        finally English. The resulting dictionary uses the localization
        module's existing runspace cache and an optional shared cache.

        .PARAMETER Name
        The component localization resource bundle name.

        .PARAMETER Language
        The language requested by the page or parent component.

        .PARAMETER DefaultUILanguage
        The owning module's configured default UI language. English is used
        when this value has no matching resource.

        .PARAMETER ModuleBase
        The module base containing the component resources. When omitted, the
        consuming module is resolved during parameter binding.

        .PARAMETER Cache
        An optional synchronized dictionary shared across PSU app runspaces.

        .EXAMPLE
        $psuConfigAddUserButtonStringsParameters = @{
            Name              = 'PSUConfig.AddUserButton'
            Language          = 'fr-CH'
            DefaultUILanguage = 'en'
            Cache             = $Cache:PSULocalization
        }
        $psuConfigAddUserButtonStrings = Get-PSUComponentLocalizedData @psuConfigAddUserButtonStringsParameters

        Gets the best available component strings and uses the shared cache
        when one is supplied.
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
        [System.String]
        $Language,

        [Parameter()]
        [System.String]
        $DefaultUILanguage,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleBase = $(if ($callingModule = ((Get-PSCallStack)[0]).InvocationInfo.MyCommand.Module) { $callingModule.ModuleBase }),

        [Parameter()]
        [System.Collections.IDictionary]
        $Cache
    )

    if ([System.String]::IsNullOrWhiteSpace($ModuleBase))
    {
        $message = 'Unable to resolve the consuming module base. Pass ModuleBase explicitly.'
        throw [System.InvalidOperationException]::new($message)
    }

    $defaultLanguageParameters = @{
        ModuleBase        = $ModuleBase
        Name              = $Name
        PreferredLanguage = $DefaultUILanguage
        DefaultUILanguage = 'en'
    }
    $resolvedDefaultLanguage = Resolve-PSULocalizationLanguage @defaultLanguageParameters

    $languageParameters = @{
        ModuleBase        = $ModuleBase
        Name              = $Name
        PreferredLanguage = $Language
        DefaultUILanguage = $resolvedDefaultLanguage
    }
    $resolvedLanguage = Resolve-PSULocalizationLanguage @languageParameters

    $componentStringsParameters = @{
        ModuleBase       = $ModuleBase
        Name             = $Name
        UICulture        = $resolvedLanguage
        DefaultUICulture = $resolvedDefaultLanguage
    }
    if ($null -ne $Cache)
    {
        $componentStringsParameters.Cache = $Cache
    }

    return Get-PSULocalizedData @componentStringsParameters
}
