# Localization

`synedgy.universal.helper` provides module-oriented localization commands for data-only PSD1
resources:

- `Resolve-PSULocalizationResource` discovers resources and returns them in merge order.
- `Get-PSULocalizedData` imports and merges their string dictionaries.
- `Get-PSUComponentLocalizedData` applies the standard requested, module
  default, and English fallback chain for a component bundle.
- `Initialize-PSULocalizationCache` preloads every available language into a caller-owned cache.
- `Resolve-PSULocalizationLanguage` selects a supported language from explicit and HTTP preferences.

## Resource layout

Store localization files below culture directories in the consuming module's
base directory, using the same culture-folder layout as localized PowerShell
module help:

```text
<ModuleBase>\
  en\
    <ModuleName>.strings.psd1
  fr\
    <ModuleName>.strings.psd1
  fr-CH\
    <ModuleName>.strings.psd1
```

`<ModuleName>.strings.psd1` is preferred. `<ModuleName>.psd1` is supported when the preferred
file is absent.

Resources may also be organized in arbitrary subfolders beneath each culture
directory:

```text
<ModuleBase>\
  en\
    Components\
      Jobs\
        <ModuleName>.strings.psd1
  fr\
    Components\
      Jobs\
        <ModuleName>.strings.psd1
```

Root-level resources retain priority for backward compatibility. When no
root-level preferred or compatible resource exists, discovery searches
subfolders recursively and still prefers `<Name>.strings.psd1` over
`<Name>.psd1`. A culture must contain only one nested match for the selected
filename; ambiguous duplicates produce an explicit error.

Large modules can split strings into independently loaded bundles. The `Name` parameter selects
the bundle base name:

```text
<ModuleBase>\
  en\
    PSUConfig.Common.strings.psd1
    PSUConfig.Home.strings.psd1
    PSUConfig.Users.strings.psd1
  fr\
    PSUConfig.Common.strings.psd1
    PSUConfig.Home.strings.psd1
    PSUConfig.Users.strings.psd1
```

Load each bundle separately:

```powershell
$commonParameters = @{
    ModuleBase       = $module.ModuleBase
    Name             = 'PSUConfig.Common'
    UICulture        = 'fr'
    DefaultUICulture = 'en'
}
$commonStrings = Get-PSULocalizedData @commonParameters

$userParameters = $commonParameters.Clone()
$userParameters.Name = 'PSUConfig.Users'
$userStrings = Get-PSULocalizedData @userParameters
```

`Name` currently accepts one bundle per call. Loading and combining multiple bundle names in one
call is not supported.

## Localize a reusable component

Give each component a module-owned bundle such as
`PSUConfig.AddUserButton.strings.psd1`, then pass the page's requested language
and the owning module's configured default:

```powershell
$psuConfigAddUserButtonStringsParameters = @{
    Name              = 'PSUConfig.AddUserButton'
    Language          = $Language
    DefaultUILanguage = (Get-PSUConfigSetting).DefaultUILanguage
    Cache             = $Cache:PSUConfigLocalization
}
$psuConfigAddUserButtonStrings = Get-PSUComponentLocalizedData @psuConfigAddUserButtonStringsParameters
```

The command selects the requested exact or parent culture when available,
otherwise the configured module default, and finally English. English is a
mandatory component resource. `ModuleBase` is discovered from the consuming
module during parameter binding, while an explicit override remains available
for scripts and tests. A supplied shared cache reuses dictionaries across PSU
runspaces; without one, the normal helper runspace cache is still used.

## Discover available languages

`Get-PSULocalizationLanguage` returns culture folders that contain a resource
for a bundle:

```powershell
$languages = @(Get-PSULocalizationLanguage -Name 'PSUConfigDemo')
```

`ModuleBase` is optional. Its default expression evaluates
`((Get-PSCallStack)[0]).InvocationInfo.MyCommand.Module.ModuleBase` during
parameter binding. At that point the callee's own frame has not yet replaced the
caller at stack position zero, so the consuming module is available. This is the
same caller-discovery pattern used by `synedgy.PSSqlite`.

See [Caller module discovery](Caller-Module-Discovery) for the complete pattern,
nested-helper rules, explicit overrides, and testing guidance.

An explicit module base remains available for scripts outside a module:

```powershell
$languages = @(
    Get-PSULocalizationLanguage -ModuleBase $module.ModuleBase -Name 'PSUConfigDemo'
)
```

Only immediate culture directories containing `PSUConfigDemo.strings.psd1` or
the compatible `PSUConfigDemo.psd1` are returned. Unrelated folders are ignored.

## Resolve a request language

`Resolve-PSULocalizationLanguage` requires the resource bundle `Name`. It checks
an explicit preference first, then parses `Accept-Language` by quality and
request order, and finally returns `DefaultUILanguage`:

```powershell
$languageParameters = @{
    Name              = 'PSUConfigDemo'
    PreferredLanguage = $Cookies['PSUConfigLanguage']
    AcceptLanguage    = $Headers['Accept-Language']
    DefaultUILanguage = 'en'
}
$language = Resolve-PSULocalizationLanguage @languageParameters
```

Exact cultures are preferred before their parents. For example, `fr-CH`
resolves to `fr-CH` when that resource exists, then to `fr`. The default
language must also have a resource for the mandatory `Name`.

## Initialize an app-wide language cache

`Initialize-PSULocalizationCache` also requires the resource bundle `Name`. It
discovers every available language, loads its merged dictionary, and optionally
replaces a caller-owned cache:

```powershell
$initializeParameters = @{
    Name             = 'PSUConfigDemo'
    DefaultUICulture = 'en'
    Cache            = $Cache:PSUConfigLocalization
}
$localizedData = Initialize-PSULocalizationCache @initializeParameters
```

Both commands discover the consuming module base during parameter binding.
Pass `ModuleBase` explicitly when calling from a script that is not owned by a
module.

## Universal Dashboard language selector

`New-UDLanguageSelector` combines resource discovery with a persistent Universal
Dashboard select:

```powershell
$selectorParameters = @{
    Language         = $language
    Name             = 'PSUConfigDemo'
    CookieName       = 'PSUConfigLanguage'
    UseLanguageLabel = $true
    ClassName        = 'site-language-selector'
    Sx               = @{
        alignSelf = 'center'
        height    = '36px'
        '& .MuiSelect-select' = @{
            paddingTop    = '2px'
            paddingBottom = '2px'
        }
    }
}
New-UDLanguageSelector @selectorParameters
```

The component automatically discovers languages from the calling module during
parameter binding. By default it displays each culture's English name.
`UseNativeLanguageName` displays each culture's own name, such as `English`,
`français`, or `Deutsch`. `UseLanguageLabel` displays compact uppercase
identifiers such as `EN`, `FR`, or `FR-CH`; the two switches are mutually
exclusive. `LanguageDisplayName` can override individual full names.

The selected value is written to `CookieName` for `CookieMaxAge` seconds and the
page reloads. The application remains responsible for reading that cookie and
resolving it before rendering localized content.

Use `Sx` for component-scoped Material UI styling. Use `ClassName` when a site
stylesheet should target the visual select root. The `Id` is assigned by PSU to
the hidden input and should primarily be treated as a dashboard behavior hook.

Each file must contain a data-only hashtable with string values:

```powershell
@{
    HeroTitle = 'PowerShell Universal, managed as code.'
    HeroLead  = 'A module-first demonstration application.'
}
```

The commands use `Import-PowerShellDataFile`, which safely imports the hashtable without
executing the resource as a localization script.

## Resolution and merge order

Resources are resolved separately from importing them. For a requested culture of `fr-CH` and a
default culture of `en`, the available resources are returned and merged in this order:

1. `en` - configured default culture
2. `fr` - parent culture
3. `fr-CH` - exact requested culture

Missing requested or parent resources are skipped. The configured default resource is required.
Duplicate cultures are removed from the result.

Later dictionaries override earlier dictionaries by key. A regional file can therefore contain
only its regional differences:

```powershell
# en/PSUConfig.strings.psd1
@{
    Greeting = 'Hello'
    Currency = 'Dollar'
}

# fr/PSUConfig.strings.psd1
@{
    Greeting = 'Bonjour'
}

# fr-CH/PSUConfig.strings.psd1
@{
    Currency = 'Franc suisse'
}
```

The merged `fr-CH` result contains `Greeting = 'Bonjour'` and
`Currency = 'Franc suisse'`.

## Usage from a PowerShell shell

```powershell
Import-Module -Name PSUConfig

$module = Get-Module -Name PSUConfig -ErrorAction Stop

$psuConfigStringsParameters = @{
    ModuleBase       = $module.ModuleBase
    Name             = $module.Name
    UICulture        = 'fr-CH'
    DefaultUICulture = 'en'
}
$psuConfigStrings = Get-PSULocalizedData @psuConfigStringsParameters

$psuConfigStrings.HeroTitle
```

When a module is used interactively from a shell and one culture applies for the lifetime of the
module import, it can initialize a script-scoped dictionary from its root module:

```powershell
# In the PSUConfig root module
$psuConfigStringsParameters = @{
    ModuleBase       = $PSScriptRoot
    Name             = 'PSUConfig'
    DefaultUICulture = 'en'
}
$script:psuConfigStrings = Get-PSULocalizedData @psuConfigStringsParameters
```

Omitting `UICulture` uses `(Get-UICulture).Name`. Module commands can then read
`$script:psuConfigStrings` without resolving the resource for every invocation.

To inspect resolution without importing the dictionaries:

```powershell
$resolveParameters = @{
    ModuleBase       = $module.ModuleBase
    Name             = $module.Name
    UICulture        = 'fr-CH'
    DefaultUICulture = 'en'
}
Resolve-PSULocalizationResource @resolveParameters
```

Each result includes the requested and default cultures, resolved culture, resource path,
resolution reason, and merge precedence.

## Usage from a PSU module

A PSU module such as PSUConfig should expose a small module command that resolves its own module
base. `$MyInvocation.MyCommand.Module` continues to identify the owning module when the command
runs from an interactive shell, a PSU Script, an endpoint, or an app runspace:

```powershell
function Get-PSUConfigLocalizedData
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter()]
        [System.String]
        $UICulture = (Get-UICulture).Name,

        [Parameter()]
        [System.String]
        $Name = 'PSUConfig',

        [Parameter()]
        [System.String]
        $DefaultUICulture = 'en',

        [Parameter()]
        [System.Collections.IDictionary]
        $Cache,

        [Parameter()]
        [System.Management.Automation.SwitchParameter]
        $Force
    )

    $module = $MyInvocation.MyCommand.Module
    $psuConfigStringsParameters = @{
        ModuleBase       = $module.ModuleBase
        Name             = $Name
        UICulture        = $UICulture
        DefaultUICulture = $DefaultUICulture
    }

    if ($PSBoundParameters.ContainsKey('Cache'))
    {
        $psuConfigStringsParameters.Cache = $Cache
    }

    if ($Force)
    {
        $psuConfigStringsParameters.Force = $true
    }

    Get-PSULocalizedData @psuConfigStringsParameters
}
```

The same module command works in an ordinary shell:

```powershell
Import-Module -Name PSUConfig
$psuConfigStrings = Get-PSUConfigLocalizedData -UICulture 'fr-CH'
```

It also works after PSU preloads `synedgy.universal.helper` and PSUConfig into an environment:

```powershell
# In a module-backed PSU Script, endpoint, or app runspace
$psuConfigUsersStrings = Get-PSUConfigLocalizedData -Name 'PSUConfig.Users' -UICulture 'fr'
$psuConfigUsersStrings.UserTableTitle
```

### PSU app-wide cache

PSU apps create and reuse multiple runspaces. Use PSU's app-wide `$Cache:` scope so each culture
and bundle is imported once for the whole app rather than once per endpoint runspace.

`Get-PSULocalizedData` uses two cache layers:

1. A module-local cache in the current runspace.
2. An optional shared cache supplied through `Cache`, such as a PSU `$Cache:` hashtable.

Each call checks the module cache first. If it misses, the command checks the shared cache. A
shared-cache hit is copied into the module cache. When both caches miss, the PSD1 resources are
resolved and imported, then both caches are populated. This keeps repeated lookups in an active
runspace fast while avoiding repeated file imports across PSU app runspaces.

Initialize a synchronized hashtable when the app starts or before its first use:

```powershell
if ($null -eq $Cache:PSUConfigLocalizedData)
{
    $Cache:PSUConfigLocalizedData = [System.Collections.Hashtable]::Synchronized(@{})
}
```

Pass that dictionary through the PSUConfig module wrapper:

```powershell
$psuConfigUsersStringsParameters = @{
    Name      = 'PSUConfig.Users'
    UICulture = 'fr'
    Cache     = $Cache:PSUConfigLocalizedData
}
$psuConfigUsersStrings = Get-PSUConfigLocalizedData @psuConfigUsersStringsParameters
```

Both cache layers use a key containing the module base, bundle name, requested culture, and
default culture. Versioned module deployments therefore receive new cache entries because their
module base path changes. Use `-Force` during same-version local development or after changing
PSD1 files without restarting the app:

```powershell
$psuConfigUsersStrings = Get-PSUConfigLocalizedData @psuConfigUsersStringsParameters -Force
```

Both caches store protected copies and each call returns a clone, preventing one endpoint from
modifying strings used by other app endpoints. Shared-cache access is synchronized while a value
is loaded, so concurrent endpoint runspaces do not import the same bundle simultaneously.

For PSU workloads that serve different users or requests, pass the desired culture explicitly.
The caller can obtain that culture from its request, user preference, or application state.

`Resolve-PSULocalizationLanguage` can inspect a caller-supplied HTTP
`Accept-Language` value, but these helpers do not change PSU's native `$tl:`
provider. If per-request culture is not required, omitting `UICulture` from
`Get-PSULocalizedData` uses the PSU runspace's current UI culture in the same
way as an ordinary PowerShell shell.

## ConvertFrom-StringData

`ConvertFrom-StringData` is part of PowerShell's original script internationalization design
introduced in Windows PowerShell 2.0. `Import-LocalizedData` uses it with culture folders and
translator-oriented `key = value` text.

`Import-PowerShellDataFile` was introduced later in Windows PowerShell 5.0. These helpers use it
because this module already requires PowerShell 5.0 and the new resources are data-only
hashtables. This avoids evaluating localization scripts, a `SupportedCommand` escape hatch, and
the constrained-runspace fallback needed to execute `ConvertFrom-StringData` resources under
invariant globalization.

DscResource.Common retains `ConvertFrom-StringData` to remain compatible with PowerShell's
established `Import-LocalizedData` contract and existing DSC localization resources. There is no
known `Import-PowerShellDataFile` defect motivating that choice.

## Error behavior

The commands fail explicitly when:

- the module base directory does not exist;
- the requested or default culture name is invalid;
- the configured default resource does not exist;
- a PSD1 cannot be imported;
- a localization value is not a string; or
- the resolved resources contain no strings.

Invariant-globalization processes use culture-name parsing that does not require creating
non-invariant `CultureInfo` instances.

## Scope

These commands discover, resolve, and merge module localization data only. They
do not register native PowerShell Universal translations or alter `$tl:`
behavior. `New-UDLanguageSelector` provides the optional dashboard selector,
while cache storage remains owned by the caller.
