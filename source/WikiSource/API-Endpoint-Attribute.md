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
Import-Module -Name synedgy.universal.helper
Import-PSUEndpoint -Module PSUConfig -Environment 'PSUConfig' -ApiPrefix 'api' -Authentication:$false
```

`Import-PSUEndpoint` uses `Get-ModuleApiEndpoint` to import the target module into the current
configuration runspace and scan its exported functions for the `APIEndpoint` attribute. It then
builds a wrapper scriptblock per function via
`Get-ModuleApiEndpointScriptblock`, and calls `New-PSUEndpoint -Endpoint {scriptblock} ...` for
each one -- no separate PSU Script resource is required, since `New-PSUEndpoint` accepts an inline
scriptblock directly.

The target module must still be available in the PSU environment selected for endpoint execution.
Automatic import here ensures discovery during resource configuration; it does not replace the
environment's module preload configuration for endpoint runspaces.

## PowerShell class parameters

PowerShell classes defined in a consuming module are compiled into a dynamic, session-local
assembly. Registering the class as a type accelerator in the module suffix makes the type
available after that module is imported into the current PowerShell process, but it does not
make the type available to a separate PSU parser process or to a session that has not imported
the consuming module. Copying a parameter such as `[MyRequest] $Request` into the endpoint
wrapper can therefore make PSU reject the complete parameter contract or display no parameters
in the administration UI. This also applies when ModuleBuilder merges the class from
`source/Classes` and `source/suffix.ps1` exports its type accelerator.

Generated endpoint wrappers expose PowerShell class parameters as `[object]` and class arrays as
`[object[]]`. The wrapper still splats the values into the original strongly typed module
function. PowerShell parameter binding converts a deserialized `PSCustomObject`, hashtable, or
ordered dictionary to the target class by using its default constructor and writable properties:

```powershell
class MyRequest
{
    [string] $Name
    [int] $Count
}

function Invoke-MyRequest
{
    [CmdletBinding()]
    [APIEndpoint(Name = 'invokeMyRequest', Path = '/request', Method = 'POST')]
    param
    (
        [Parameter(Mandatory = $true)]
        [MyRequest]
        $Request
    )

    $Request
}
```

Keep endpoint input classes data-oriented: provide a parameterless constructor and public,
writable properties. Constructor-only invariants, static factory calls, and custom conversion
logic are not represented by the wrapper contract and should be validated explicitly inside the
target command. PSU's HTTP deserializer must still produce an object or dictionary for the
parameter; a JSON string containing an object is not equivalent to a deserialized object.

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
different from the [AI Tool Attribute](AI-Tool-Attribute) pattern, where `New-PSUAiTool` only
accepts `-ScriptFullPath` referencing an already-registered PSU Script resource, so
`Import-PSUAiTool` must also declare that backing script.
