# API Endpoint Attribute

`synedgy.universal.helper` ships an `APIEndpoint` class attribute, a `[System.Attribute]` you can
put on any public function in a consuming module to expose it as a PowerShell Universal REST API
endpoint, without hand-writing a `New-PSUEndpoint` call for every function:

```powershell
function New-myUser
{
    [CmdletBinding()]
    [APIEndpoint(
        Name = 'newmyUser',
        Path = '/myUser',
        Description = 'New myUser records from the local database.',
        Method = 'POST',
        Authentication = $false,
        Role = ('admin','user'),
        Timeout = 30
    )]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $FirstName
        # ...
    )

    # ...
}
```

Then, in the consuming module's `.universal/endpoints.ps1` resource file, a single call discovers
and registers every `[APIEndpoint()]`-decorated function in the module:

```powershell
Import-Module -Name synedgy.universal.helper, PSUConfig
Import-PSUEndpoint -Module PSUConfig -Environment 'PSUConfig' -ApiPrefix 'api' -Authentication:$false
```

`Import-PSUEndpoint` uses `Get-ModuleApiEndpoint` to scan the module's exported functions for the
`APIEndpoint` attribute, builds a wrapper scriptblock per function via
`Get-ModuleApiEndpointScriptblock`, and calls `New-PSUEndpoint -Endpoint {scriptblock} ...` for
each one -- no separate PSU Script resource is required, since `New-PSUEndpoint` accepts an inline
scriptblock directly.

## `APIEndpoint` attribute properties

| Property | Default | Description |
|---|---|---|
| `Name` | (none) | Name of the registered endpoint. |
| `ApiPrefix` | `'api'` | Prefix for the endpoint URL. |
| `Version` | `'v1'` | Version segment of the endpoint URL. |
| `Path` | (none) | URL path of the endpoint. |
| `Description` | (none) | Description of the endpoint. |
| `Documentation` | (none) | Name of the OpenAPI documentation resource to attach to. |
| `Method` | (none) | One or more HTTP methods (`GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`). |
| `Authentication` | `$false` | Whether the endpoint requires an authenticated user. |
| `Role` | (none) | Role(s) required to access the endpoint. |
| `Tag` | (none) | Tag used to categorize the endpoint. |
| `Timeout` | (none) | Timeout for the endpoint, in seconds. |
| `Environment` | (none) | PSU environment the endpoint should run in. |
| `ContentType` | `'application/json; charset=utf-8'` | Content type of the response. |
| `LogLevel` | `@('Information')` | Log level(s) recorded for the endpoint. |
| `Parameters` | (none) | Scriptblock overriding the parameters splatted to the target command. |

## Design note: inline scriptblock vs. backing PSU Script

`New-PSUEndpoint` accepts an inline `-Endpoint {scriptblock}` parameter, so `Import-PSUEndpoint`
can synthesize a wrapper scriptblock dynamically and register the endpoint in one step. This is
different from the [AI Tool Attribute](AI-Tool-Attribute.md) pattern, where `New-PSUAiTool` only
accepts `-ScriptFullPath` referencing an already-registered PSU Script resource, so
`Import-PSUAiTool` must also declare that backing script.
