function Get-PSULocalizationLanguage
{
    <#
        .SYNOPSIS
        Gets the available localization languages for a module resource.

        .DESCRIPTION
        Discovers immediate culture directories containing the requested
        data-only localization resource at the culture root or in a nested
        subfolder. When ModuleBase is omitted, the
        consuming module is resolved from invocation metadata and the first
        non-helper module found in the PowerShell call stack.

        Both <Name>.strings.psd1 and the compatible <Name>.psd1 resource names
        are supported.

        .PARAMETER Name
        The base name of the localization resource bundle.

        .PARAMETER ModuleBase
        The module base containing culture directories. When omitted, the
        command resolves the consuming caller module automatically.

        .EXAMPLE
        Get-PSULocalizationLanguage -Name 'PSUConfigDemo'

        Returns languages available for PSUConfigDemo in the calling module.

        .EXAMPLE
        Get-PSULocalizationLanguage -ModuleBase $module.ModuleBase -Name $module.Name

        Returns languages from an explicitly selected module.
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
        $ModuleBase = $(if ($callingModule = ((Get-PSCallStack)[0]).InvocationInfo.MyCommand.Module) { $callingModule.ModuleBase })
    )

    if ([System.String]::IsNullOrWhiteSpace($ModuleBase))
    {
        $helperModuleName = $MyInvocation.MyCommand.Module.Name
        foreach ($frame in @(Get-PSCallStack))
        {
            $frameModule = $frame.InvocationInfo.MyCommand.Module
            if ($null -ne $frameModule -and $frameModule.Name -ne $helperModuleName)
            {
                $ModuleBase = $frameModule.ModuleBase
                break
            }
        }
    }

    if ([System.String]::IsNullOrWhiteSpace($ModuleBase))
    {
        $message = 'Unable to resolve the consuming module base. Pass ModuleBase explicitly.'
        throw [System.InvalidOperationException]::new($message)
    }

    if (-not (Test-Path -LiteralPath $ModuleBase -PathType Container))
    {
        throw [System.IO.DirectoryNotFoundException]::new(
            "Localization module base '$ModuleBase' does not exist."
        )
    }

    $languages = [System.Collections.Generic.SortedSet[System.String]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($cultureDirectory in @(Get-ChildItem -LiteralPath $ModuleBase -Directory))
    {
        try
        {
            $cultureName = @(Get-PSULocalizationCultureChain -CultureName $cultureDirectory.Name)[0]
        }
        catch [System.Globalization.CultureNotFoundException]
        {
            continue
        }

        $resourcePathParameters = @{
            ModuleBase  = $ModuleBase
            Name        = $Name
            CultureName = $cultureName
        }
        $resourcePath = Get-PSULocalizationResourcePath @resourcePathParameters
        if (-not [System.String]::IsNullOrEmpty($resourcePath))
        {
            $null = $languages.Add($cultureName)
        }
    }

    if ($languages.Count -eq 0)
    {
        $message = "No localization resources for '$Name' were found beneath '$ModuleBase'."
        throw [System.IO.FileNotFoundException]::new($message)
    }

    foreach ($language in $languages)
    {
        [System.String] $language
    }
}
