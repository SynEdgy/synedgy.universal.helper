# AI Tool Attribute

`synedgy.universal.helper` also ships an `AiTool` class attribute, a `[System.Attribute]` you can
put on any public function in a consuming module to expose it as a PowerShell Universal AI tool,
mirroring the [API Endpoint Attribute](API-Endpoint-Attribute) pattern used for REST endpoints:

```powershell
function Find-UserByCity
{
    [CmdletBinding()]
    [AiTool(
        Description   = 'Finds users by city'
        Authenticated = $false
        Role          = ('admin','user')
    )]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $City
    )

    # ...
}
```

Then, in the consuming module's `.universal/aiTools.ps1` resource file, a single call discovers
and registers every `[AiTool()]`-decorated function in the module:

```powershell
Import-Module -Name synedgy.universal.helper, PSUConfig
Import-PSUAiTool -Module PSUConfig -Environment 'PSUConfig'
```

`Import-PSUAiTool` uses `Get-ModuleAiTool` to scan the module's exported functions for the
`AiTool` attribute, then for each one:

1. Registers (or re-registers -- both cmdlets are idempotent, safe to call on every PSU config
   reload) a backing PSU Script resource via `New-PSUScript -Module <Module> -Command <Function>`.
2. Registers the AI tool itself via `New-PSUAiTool -ScriptFullPath '<Module>\<Function>' ...`.

This differs from the `APIEndpoint`/`Import-PSUEndpoint` pattern: `New-PSUEndpoint` accepts an
inline `-Endpoint {scriptblock}` (built dynamically by `Get-ModuleApiEndpointScriptblock`).
`New-PSUAiTool`, however, only accepts `-ScriptFullPath` referencing an **already-registered** PSU
Script (the same `<Module>\<Command>` naming convention used by `New-PSUScript`/`Get-PSUScript`),
so `Import-PSUAiTool` always (re-)declares that backing script alongside the AI tool registration.

## `AiTool` attribute properties

| Property | Default | Description |
|---|---|---|
| `Name` | function name | Name of the registered AI tool. |
| `Description` | comment-based help synopsis | Description shown to AI agents. |
| `Authenticated` | `$false` | Whether the tool requires an authenticated user. |
| `Role` | (none) | Role(s) required to access/invoke the tool. |
| `Mcp` | `$true` | Whether the tool is exposed through Model Context Protocol (MCP). |
| `Environment` | (none) | PSU environment the backing script should run in. |

## Gotcha: PSU resource file naming

PSU only auto-discovers `.universal/*.ps1` resource files by their exact expected filename per
resource type -- AI tools must live in a file named `aiTools.ps1` (matching the
`PowerShellUniversal.Models.Intelligence.AiTool` resource type), not any other name such as
`mcpTools.ps1`. A wrongly-named file is silently ignored by PSU; no error is raised. Use the
`psu-list_resource_types` MCP tool (or inspect PSU's resource discovery documentation) to confirm
the exact expected filename for a resource type if in doubt.

## Attribute argument syntax

Attribute array-valued properties (e.g. `Role`) must be written as a parenthesized comma-list,
`('admin','user')`, not an array subexpression `@('admin','user')` -- the latter is not accepted
as a constant expression in all attribute-argument contexts.
