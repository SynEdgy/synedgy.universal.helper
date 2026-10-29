function Get-PSULocalizedData
{
    <#
        .SYNOPSIS
        Gets merged localized data for a requested UI culture.

        .DESCRIPTION
        Resolves module localization resources with Resolve-PSULocalizationResource,
        imports each data-only PSD1 with Import-PowerShellDataFile, and merges keys in
        default, parent, and exact culture order. More specific cultures override keys
        from less specific cultures.

        Merged results are always cached in the helper module for fast reuse within the
        current runspace. An optional shared dictionary provides a second cache layer
        across PSU app runspaces. Lookup order is module cache, shared cache, then PSD1
        resources.

        .PARAMETER ModuleBase
        The base directory of the module that owns the localization resources.

        .PARAMETER Name
        The base name of the localization resource, normally the consuming module name.

        .PARAMETER UICulture
        The requested UI culture. Defaults to the current process UI culture. When the
        process uses invariant globalization, the configured default culture is used.

        .PARAMETER DefaultUICulture
        The required fallback culture. A resource must exist for this culture.

        .PARAMETER Cache
        An optional second-level shared dictionary used across runspaces. In a PSU app,
        pass a synchronized hashtable stored in the app-wide $Cache: scope. Results read
        from this cache are copied into the module-local first-level cache.

        .PARAMETER Force
        Bypasses both cache layers, reloads the localization resources, and replaces the
        module-local and optional shared cached values.

        .EXAMPLE
        $psuConfigStrings = Get-PSULocalizedData -ModuleBase $module.ModuleBase -Name 'PSUConfig' -UICulture 'fr-CH' -DefaultUICulture 'en'

        Imports and merges the English, French, and Swiss French resources that exist.

        .EXAMPLE
        $psuConfigStrings = Get-PSULocalizedData -ModuleBase $module.ModuleBase -Name 'PSUConfig' -UICulture 'fr' -Cache $Cache:LocalizedData

        Gets localized data using a PSU app-wide cache dictionary.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleBase,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('ModuleName')]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $UICulture = (Get-UICulture).Name,

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

    if ($null -eq $script:localizedDataCache)
    {
        $script:localizedDataCache = [System.Collections.Hashtable]::Synchronized(@{})
    }

    $cacheWasProvided = $PSBoundParameters.ContainsKey('Cache')
    if ($cacheWasProvided -and $null -eq $Cache)
    {
        throw [System.ArgumentNullException]::new(
            'Cache',
            'The cache dictionary cannot be null when the Cache parameter is supplied.'
        )
    }

    $requestedCultureName = if ([System.String]::IsNullOrWhiteSpace($UICulture))
    {
        $DefaultUICulture
    }
    else
    {
        $UICulture
    }

    $normalizedUICulture = @(Get-PSULocalizationCultureChain -CultureName $requestedCultureName)[0]
    $normalizedDefaultUICulture = @(Get-PSULocalizationCultureChain -CultureName $DefaultUICulture)[0]
    $normalizedModuleBase = [System.IO.Path]::GetFullPath($ModuleBase)
    $cacheKey = [System.String]::Join(
        [System.Char] 31,
        @(
            'Get-PSULocalizedData'
            $normalizedModuleBase
            $Name
            $normalizedUICulture
            $normalizedDefaultUICulture
        )
    )

    if (-not $Force.IsPresent -and $script:localizedDataCache.Contains($cacheKey))
    {
        $moduleCachedData = $script:localizedDataCache[$cacheKey]
        if ($moduleCachedData -isnot [System.Collections.Hashtable])
        {
            $message = "Module-cached localization data for '$Name' and culture '$normalizedUICulture' is not a hashtable."
            throw [System.IO.InvalidDataException]::new($message)
        }

        return [System.Collections.Hashtable] $moduleCachedData.Clone()
    }

    $sharedCacheLockTaken = $false
    try
    {
        if ($cacheWasProvided)
        {
            $sharedCacheLock = if ($Cache -is [System.Collections.ICollection])
            {
                $Cache.SyncRoot
            }
            else
            {
                $Cache
            }

            [System.Threading.Monitor]::Enter($sharedCacheLock)
            $sharedCacheLockTaken = $true

            if (-not $Force.IsPresent -and $Cache.Contains($cacheKey))
            {
                $sharedCachedData = $Cache[$cacheKey]
                if ($sharedCachedData -isnot [System.Collections.Hashtable])
                {
                    $message = "Shared-cached localization data for '$Name' and culture '$normalizedUICulture' is not a hashtable."
                    throw [System.IO.InvalidDataException]::new($message)
                }

                $script:localizedDataCache[$cacheKey] = [System.Collections.Hashtable] $sharedCachedData.Clone()
                return [System.Collections.Hashtable] $sharedCachedData.Clone()
            }
        }

        $resolveParameters = @{
            ModuleBase       = $ModuleBase
            Name             = $Name
            UICulture        = $UICulture
            DefaultUICulture = $DefaultUICulture
        }

        $resources = @(Resolve-PSULocalizationResource @resolveParameters)
        $localizedData = @{}

        foreach ($resource in $resources)
        {
            try
            {
                $resourceData = Import-PowerShellDataFile -LiteralPath $resource.Path -ErrorAction Stop
            }
            catch
            {
                $message = "Unable to import localization resource '$($resource.Path)' for culture '$($resource.Culture)': $($_.Exception.Message)"
                throw [System.IO.InvalidDataException]::new($message, $_.Exception)
            }

            if ($resourceData -isnot [System.Collections.IDictionary])
            {
                $message = "Localization resource '$($resource.Path)' for culture '$($resource.Culture)' did not return a dictionary."
                throw [System.IO.InvalidDataException]::new($message)
            }

            foreach ($key in $resourceData.Keys)
            {
                if ($resourceData[$key] -isnot [System.String])
                {
                    $message = "Localization key '$key' in '$($resource.Path)' must contain a string value."
                    throw [System.IO.InvalidDataException]::new($message)
                }

                $localizedData[$key] = $resourceData[$key]
            }
        }

        if ($localizedData.Count -eq 0)
        {
            $message = "Localization resources for '$Name' did not contain any strings."
            throw [System.IO.InvalidDataException]::new($message)
        }

        $script:localizedDataCache[$cacheKey] = [System.Collections.Hashtable] $localizedData.Clone()

        if ($cacheWasProvided)
        {
            $Cache[$cacheKey] = [System.Collections.Hashtable] $localizedData.Clone()
        }

        return [System.Collections.Hashtable] $localizedData.Clone()
    }
    finally
    {
        if ($sharedCacheLockTaken)
        {
            [System.Threading.Monitor]::Exit($sharedCacheLock)
        }
    }
}
