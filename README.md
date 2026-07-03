# synedgy.universal.helper

A bunch of PowerShell Universal (PSU) helpers to make your experience more productive.

## UDComponents

Reusable Universal Dashboard components for rendering PSU job information, shared across
consuming projects (e.g. ComsolCentral, PSUConfig):

- `New-UDPsuJobHeader` - renders a summary header card for a PSU job (script path, status
  badge, created/started/completed timestamps, duration, copy-to-clipboard job id chip).
- `New-UDPsuJobTerminalView` - renders a terminal-style view of a PSU job's output, with an
  optional structured events table tab, auto-refresh while the job is active, line-number and
  timestamp toggles, and ANSI-to-HTML color rendering.

Both components rely on private helpers (`ConvertFrom-PsuJobOutputEntry`, `Convert-AnsiToHtml`,
`Convert-PlainTextToHtml`, `Get-UDPsuJobThemePalette`, `Get-UDPsuJobThemeStyleBlock`,
`ConvertTo-UDPsuThemedIconMarkup`) and branding assets under `images/synedgy_pwsh/` that ship with
this module -- consuming projects do not need to duplicate them.

### Usage

```powershell
$job = Get-PSUJob -Id $jobId
New-UDPsuJobHeader -Job $job
New-UDPsuJobTerminalView -JobId $job.Id -JobStatus ([string]$job.Status) `
    -JobOutputSnapshot @($job.Output) -IncludeStructuredTable
```

`New-UDPsuJobTerminalView`'s live-refresh `New-UDDynamic` content block imports this module
(`synedgy.universal.helper`) and calls its private helpers via `& (Get-Module ...) { ... }`, since
private module functions are not otherwise accessible from a `New-UDDynamic` sync/refresh
runspace. Consuming projects do not need to do anything extra for this to work as long as
`synedgy.universal.helper` is installed/available on the PSU server.

### Theming: light/dark, automatic or forced, with custom CSS overrides

Both components accept a `-Theme` parameter:

- `Auto` (default): follows PSU's own theme switch live. PSU sets a `data-theme="light"` or
  `data-theme="dark"` attribute on `<html>` and updates it instantly (no page reload) when the
  user toggles its built-in theme switch. The component's colors and icon are driven by CSS custom
  properties (`--psu-term-*`) scoped to the component's own element id, defined once in a
  `<style>` block emitted alongside the component (see `Get-UDPsuJobThemeStyleBlock`), so they
  re-cascade automatically whenever PSU flips that attribute.
- `Light` / `Dark`: forces that theme for this component instance regardless of the ambient PSU
  theme (renders only that palette's CSS rule, with no `html[data-theme="dark"]` override rule).

The light palette is inspired by the classic PowerShell ISE / VS Code light theme (white
background, dark text, ISE-style syntax accent colors for the Error/Warning/Information/
Verbose/Debug job output streams). The dark palette preserves the component's original look.

Both components also accept a `-CustomCss` parameter: raw CSS appended after the theme rules in
the same `<style>` block, so it naturally overrides them. For example, to override just the accent
color for a specific instance:

```powershell
New-UDPsuJobTerminalView -JobId $job.Id -ElementId 'my-terminal' `
    -CustomCss '#my-terminal { --psu-term-accent: #ff6600; }'
```

Icon assets always use the plain monochrome variants: `pwsh_custom_black.svg` for light theme and
`pwsh_custom_white.svg` for dark theme. In `Auto` mode, both variants are rendered (wrapped in
`.psu-theme-light-only` / `.psu-theme-dark-only` spans) and shown/hidden via the same CSS rules
that drive the color variables, so the icon also switches live with no JavaScript required.

### Authorization: prefer an app token over -Integrated

When fetching the `$job` passed into these components, prefer an app token via the Management API
(`Get-PSUJob -Id $jobId -AppToken $token -ComputerName $url`) over `-Integrated`. `-Integrated`
bypasses PSU's Management API -- and therefore its role/permission checks -- entirely, so code
using it can read any job in the instance regardless of role configuration. An app token, by
contrast, is bound to whatever role it is assigned, is revocable, and is auditable. Treat
`-Integrated` as a fallback for quick local setups without a configured token, not the default.

This does not yet achieve fine-grained per-script job scoping -- today the only permission that
grants job-read access at all (`automation/read`) grants it for every job in the instance, not
just a specific script's jobs (a known PSU platform limitation, already submitted to Devolutions
and confirmed as being fixed). But using a token still keeps access inside PSU's authorization
model rather than bypassing it altogether, and will become properly scoped once that fix ships.

## Known PowerShell Universal platform behaviors

These are general PSU platform quirks worth knowing when building on top of this module or PSU
apps that consume it:

- `Get-PSUScript -Name` requires the full `<ModuleName>\<Command>` path (e.g.
  `'PSUConfig\Get-myUser'`), not just the command name.
- `Invoke-PSUScript -Integrated -Wait` reliably returns a job object with an empty `Id` on this
  PSU version (100% reproducible across 130 test invocations). Omit `-Wait` when the job `Id` is
  needed immediately (e.g. to redirect to a job detail page) -- without `-Wait`, `Id` is reliably
  populated.
- Never directly modify files under PSU's live Repository folder
  (`C:\ProgramData\UniversalAutomation\Repository` on Windows); only a build-driven deploy task
  should change files there.
- When deploying a Sampler-built module to PSU, always run the `pack` task explicitly before
  `deploy` -- Invoke-Build's incremental build detection can silently skip `pack`, leaving stale or
  missing `.nupkg` files and causing PSU deployment to fail without a clear error in the build
  output.
