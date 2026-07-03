# Known PowerShell Universal Platform Behaviors

These are general PSU platform quirks worth knowing when building on top of this module or PSU
apps that consume it.

## Script and resource naming

- `Get-PSUScript -Name` requires the full `<ModuleName>\<Command>` path (e.g.
  `'PSUConfig\Get-myUser'`), not just the command name. This is by design (namespacing), not a
  bug.
- PSU only auto-discovers `.universal/*.ps1` resource files by their exact expected filename per
  resource type (e.g. AI tools must be in `aiTools.ps1`, scripts in `scripts.ps1`, endpoints in
  `endpoints.ps1`). A wrongly-named file is silently ignored -- use the `psu-list_resource_types`
  MCP tool to confirm the exact expected filename for a resource type.
- Each `.universal/*.ps1` resource declaration file is processed independently by PSU and must
  `Import-Module` its own dependencies; imports are not shared across resource files.

## Job invocation

- `Invoke-PSUScript -Integrated -Wait` reliably returns a job object with an empty `Id` on this
  PSU version (100% reproducible across 130 test invocations). Omit `-Wait` when the job `Id` is
  needed immediately (e.g. to redirect to a job detail page) -- without `-Wait`, `Id` is reliably
  populated.

## Deployment safety

- Never directly modify files under PSU's live Repository folder
  (`C:\ProgramData\UniversalAutomation\Repository` on Windows); only a build-driven deploy task
  should change files there. Direct edits can corrupt state while PSU holds file locks.
- When deploying a Sampler-built module to PSU, always run the `pack` task explicitly before
  `deploy` -- Invoke-Build's incremental build detection can silently skip `pack`, leaving stale or
  missing `.nupkg` files and causing PSU deployment to fail without a clear error in the build
  output.
- `New-PSUScript`/`New-PSUAiTool`/`New-PSUEndpoint` are idempotent when called repeatedly with the
  same identifying parameters (module/command, name, etc.), which is why `Import-PSUEndpoint` and
  `Import-PSUAiTool` can be safely re-run on every PSU config reload.

## Theming

- PSU sets a `data-theme="light"` or `data-theme="dark"` attribute on `<html>` and updates it
  live (no page reload) via its built-in Material-UI theme switch (class `.MuiSwitch-input`),
  persisted per-origin in `localStorage.theme`. CSS attribute selectors
  (`html[data-theme="dark"] #elementId {...}`) pick this up automatically with zero JavaScript.
- Browser extensions that alter page colors (e.g. Dark Reader) can make PSU's own theming look
  broken by double-darkening the page. When debugging apparent theming issues, verify with the
  extension disabled and by checking `getComputedStyle` values for the relevant CSS custom
  properties before assuming a real bug.
