# Caller module discovery

Reusable PowerShell modules sometimes need to locate resources owned by the
module that called them. Examples include SQLite configuration, localization
resources, templates, and application assets.

## Pattern

Resolve the caller in an optional parameter default expression:

```powershell
[Parameter(DontShow)]
[System.String]
$ModuleBase = $(
    $callingModule = ((Get-PSCallStack)[0]).InvocationInfo.MyCommand.Module
    if ($null -ne $callingModule)
    {
        $callingModule.ModuleBase
    }
)
```

Parameter default expressions run while PowerShell is binding the command. At
that point, stack frame `0` still represents the caller. After the function body
starts, frame `0` represents the function being executed and therefore resolves
the wrong module.

This is the established pattern used by
`synedgy.PSSqlite\Get-PSSqliteDBConfigFile`.

## Nested reusable helpers

Resolve the caller on the outermost public function. Pass the captured module
base explicitly to inner helpers:

```powershell
function New-UDExample
{
    [CmdletBinding()]
    param
    (
        [Parameter(DontShow)]
        [System.String]
        $ModuleBase = $(
            $callingModule = ((Get-PSCallStack)[0]).InvocationInfo.MyCommand.Module
            if ($null -ne $callingModule)
            {
                $callingModule.ModuleBase
            }
        )
    )

    Get-ExampleResource -ModuleBase $ModuleBase
}
```

If `Get-ExampleResource` performs caller discovery again, its caller is
`synedgy.universal.helper`, not the consuming module.

## Deferred PSU callbacks

PowerShell Universal can execute stored dashboard scriptblocks in a deferred
endpoint runspace without retaining the scriptblock's original module identity.
In that case, call the reusable helper through a function owned by the consuming
module:

```powershell
function New-ContosoLanguageSelector
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Language
    )

    New-UDLanguageSelector -Language $Language -Name 'ContosoApp'
}
```

The deferred scriptblock calls `New-ContosoLanguageSelector`. During
`New-UDLanguageSelector` parameter binding, stack frame `0` is the Contoso
module function, so its module base is resolved correctly.

## Explicit override

Keep the parameter available as an override:

```powershell
New-UDExample -ModuleBase $module.ModuleBase
```

This supports ordinary scripts, tests, and hosts that do not associate the
calling scriptblock with a module.

## Testing

Create and import a temporary consumer module. Its exported wrapper should call
the reusable command without `ModuleBase`. Verify that resources beneath the
temporary module are discovered.

Also test an explicit `ModuleBase` to preserve use outside a module.

Avoid searching all loaded modules for matching resources. More than one loaded
module can use the same resource bundle name, making that fallback ambiguous and
dependent on module load order.
