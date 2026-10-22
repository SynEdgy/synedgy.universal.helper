function Resolve-PSULocalizationResource
{
    <#
        .SYNOPSIS
        Resolves localized data resources for a requested UI culture.

        .DESCRIPTION
        Resolves data-only PSD1 localization files stored in culture folders directly
        below a module base directory. Resources are returned in merge order: configured
        default culture, requested parent cultures, and requested exact culture.

        The preferred resource name is <Name>.strings.psd1. <Name>.psd1 is supported as
        a compatibility fallback when the preferred file is absent.

        .PARAMETER ModuleBase
        The base directory of the module that owns the localization resources.

        .PARAMETER Name
        The base name of the localization resource, normally the consuming module name.

        .PARAMETER UICulture
        The requested UI culture. Defaults to the current process UI culture. When the
        process uses invariant globalization, the configured default culture is used.

        .PARAMETER DefaultUICulture
        The required fallback culture. A resource must exist for this culture.

        .EXAMPLE
        Resolve-PSULocalizationResource -ModuleBase $module.ModuleBase -Name $module.Name -UICulture 'fr-CH' -DefaultUICulture 'en'

        Returns resources in the order en, fr, fr-CH when all three files exist.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ModuleBase,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Name,

        [Parameter()]
        [System.String]
        $UICulture = (Get-UICulture).Name,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $DefaultUICulture = 'en'
    )

    if (-not (Test-Path -LiteralPath $ModuleBase -PathType Container))
    {
        $message = "Module base directory '$ModuleBase' does not exist."
        throw [System.IO.DirectoryNotFoundException]::new($message)
    }

    $defaultCultureChain = @(Get-PSULocalizationCultureChain -CultureName $DefaultUICulture)
    $normalizedDefaultCulture = $defaultCultureChain[0]
    $resourcePathParameters = @{
        ModuleBase  = $ModuleBase
        Name        = $Name
        CultureName = $normalizedDefaultCulture
    }
    $defaultResourcePath = Get-PSULocalizationResourcePath @resourcePathParameters

    if ([System.String]::IsNullOrEmpty($defaultResourcePath))
    {
        $cultureDirectory = Join-Path -Path $ModuleBase -ChildPath $normalizedDefaultCulture
        $message = "No localization resource for default culture '$normalizedDefaultCulture' was found in '$cultureDirectory'."
        throw [System.IO.FileNotFoundException]::new($message)
    }

    if ([System.String]::IsNullOrWhiteSpace($UICulture))
    {
        $UICulture = $normalizedDefaultCulture
    }

    $requestedCultureChain = [System.String[]] @(Get-PSULocalizationCultureChain -CultureName $UICulture)
    $requestedCulture = $requestedCultureChain[0]
    [System.Array]::Reverse($requestedCultureChain)

    $resolvedCultures = [System.Collections.Generic.HashSet[System.String]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $precedence = 0

    $null = $resolvedCultures.Add($normalizedDefaultCulture)
    [PSCustomObject] @{
        PSTypeName         = 'SynEdgy.PSU.LocalizationResource'
        RequestedUICulture = $requestedCulture
        DefaultUICulture   = $normalizedDefaultCulture
        Culture            = $normalizedDefaultCulture
        Path               = $defaultResourcePath
        Resolution         = 'Default'
        Precedence         = $precedence
    }
    $precedence++

    foreach ($cultureName in $requestedCultureChain)
    {
        if (-not $resolvedCultures.Add($cultureName))
        {
            continue
        }

        $resourcePathParameters.CultureName = $cultureName
        $resourcePath = Get-PSULocalizationResourcePath @resourcePathParameters
        if ([System.String]::IsNullOrEmpty($resourcePath))
        {
            continue
        }

        $resolution = if ($cultureName -eq $requestedCulture)
        {
            'Exact'
        }
        else
        {
            'Parent'
        }

        [PSCustomObject] @{
            PSTypeName         = 'SynEdgy.PSU.LocalizationResource'
            RequestedUICulture = $requestedCulture
            DefaultUICulture   = $normalizedDefaultCulture
            Culture            = $cultureName
            Path               = $resourcePath
            Resolution         = $resolution
            Precedence         = $precedence
        }

        $precedence++
    }
}
