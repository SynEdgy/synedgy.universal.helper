function Get-PSULanguageDisplayName
{
    [CmdletBinding()]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $Language,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $UseNativeLanguageName
    )

    try
    {
        $culture = [System.Globalization.CultureInfo]::GetCultureInfo($Language)
        if ($UseNativeLanguageName.IsPresent)
        {
            return $culture.NativeName
        }

        return $culture.EnglishName
    }
    catch [System.Globalization.CultureNotFoundException]
    {
        return $Language
    }
}
