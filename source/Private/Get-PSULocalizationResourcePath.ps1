function Get-PSULocalizationResourcePath
{
    <#
        .SYNOPSIS
        Gets the localization resource path for a culture.

        .DESCRIPTION
        Searches a culture folder below a module base directory for a data-only PSD1
        localization resource. The preferred <Name>.strings.psd1 file is returned
        before the compatible <Name>.psd1 file.

        .PARAMETER ModuleBase
        The base directory of the module that owns the localization resources.

        .PARAMETER Name
        The base name of the localization resource, normally the consuming module name.

        .PARAMETER CultureName
        The culture folder to search below the module base directory.

        .EXAMPLE
        Get-PSULocalizationResourcePath -ModuleBase $module.ModuleBase -Name $module.Name -CultureName 'fr-CH'
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
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

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $CultureName
    )

    $cultureDirectory = Join-Path -Path $ModuleBase -ChildPath $CultureName
    $resourceNames = @(
        ('{0}.strings.psd1' -f $Name)
        ('{0}.psd1' -f $Name)
    )

    foreach ($resourceName in $resourceNames)
    {
        $resourcePath = Join-Path -Path $cultureDirectory -ChildPath $resourceName
        if (Test-Path -LiteralPath $resourcePath -PathType Leaf)
        {
            return (Get-Item -LiteralPath $resourcePath -ErrorAction Stop).FullName
        }
    }
}
