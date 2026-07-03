# synedgy.universal.helper

A bunch of PowerShell Universal (PSU) helpers to make your experience more productive.

## Start here

- [UD Job Components](UD-Job-Components.md) - shared Universal Dashboard components for
  rendering PSU job status/output, with light/dark theming.
- [API Endpoint Attribute](API-Endpoint-Attribute.md) - declaratively expose module functions as
  PSU REST API endpoints with `[APIEndpoint()]` and `Import-PSUEndpoint`.
- [AI Tool Attribute](AI-Tool-Attribute.md) - declaratively expose module functions as PSU AI
  tools (MCP) with `[AiTool()]` and `Import-PSUAiTool`.
- [PSU Platform Notes](PSU-Platform-Notes.md) - known PowerShell Universal platform behaviors and
  gotchas worth knowing when building on top of this module or consuming PSU apps.

## Command reference

Generated command pages in the published wiki include all of this module's public functions,
including `New-UDPsuJobHeader`, `New-UDPsuJobTerminalView`, `Import-PSUEndpoint`,
`Get-ModuleApiEndpoint`, `Import-PSUAiTool`, and `Get-ModuleAiTool`.

## Notes

- Generated command pages and `_Sidebar.md` are rebuilt from `build.yaml`; keep custom wiki
  content in `source/WikiSource`.
