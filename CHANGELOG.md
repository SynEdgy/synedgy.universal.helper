# Changelog for synedgy.universal.helper

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added `New-UDPsuJobHeader` and `New-UDPsuJobTerminalView` public functions
  under `UDComponents`, providing reusable Universal Dashboard components to
  render a PSU job summary header and a terminal-style job output view.
- Added supporting private helpers `Convert-PlainTextToHtml`, `Convert-AnsiToHtml`,
  and `ConvertFrom-PsuJobOutputEntry` used by the new components.
- Added `images/synedgy_pwsh` branding assets used by the new components.
- Added automatic light/dark theming to `New-UDPsuJobHeader` and
  `New-UDPsuJobTerminalView` via a new `-Theme` parameter (`Auto` (default), `Light`,
  `Dark`). `Auto` follows PSU's own theme switch live (no page reload), using the
  `data-theme` attribute PSU sets on `<html>`. The light palette is inspired by the
  classic PowerShell ISE / VS Code light theme colors. Added a `-CustomCss`
  parameter on both components for further customizing the look with raw CSS,
  which is appended after (and can override) the theme rules.
- Added private helpers `Get-UDPsuJobThemePalette`, `Get-UDPsuJobThemeStyleBlock`,
  and `ConvertTo-UDPsuThemedIconMarkup` supporting the new theming feature. The
  themed icon helper always uses the plain monochrome `pwsh_custom_black.svg`
  icon for light theme and `pwsh_custom_white.svg` for dark theme.
- Added `-HideLineNumbers` and `-HideTimestamps` switch parameters to
  `New-UDPsuJobTerminalView` to control whether line numbers and timestamps are
  shown by default for a first-time viewer (shown by default when omitted). A
  viewer's own manual toggle choice, remembered in `localStorage`, still takes
  precedence over these defaults on later visits.
- Added an `AiTool` class attribute (mirroring the existing `APIEndpoint` attribute
  pattern) that can decorate a public function to expose it as a PowerShell
  Universal AI tool. Added `Get-ModuleAiTool`, which scans a module's exported
  functions for `[AiTool()]`-decorated commands and builds their registration
  metadata (`Name`, `Description`, `ScriptFullPath`, `Authenticated`, `Role`,
  `Mcp`, `Environment`), and `Import-PSUAiTool`, which registers each discovered
  function as a PSU Script (`New-PSUScript`) and AI tool (`New-PSUAiTool`) in one
  call, analogous to how `Import-PSUEndpoint` wires up `[APIEndpoint()]`-decorated
  functions.
- Added `source/WikiSource` (Home, UD Job Components, API Endpoint Attribute, AI
  Tool Attribute, PSU Platform Notes pages, and screenshots) as the canonical
  source for the published GitHub wiki, and wired the `DscResource.DocGenerator`
  tasks (`Create_Wiki_Output_Folder`, `Generate_Conceptual_Help`,
  `Generate_Markdown_For_Public_Commands`,
  `Generate_External_Help_File_For_Public_Commands`,
  `Clean_Markdown_Of_Public_Commands`, `Copy_Source_Wiki_Folder`,
  `Generate_Wiki_Sidebar`, `Clean_Markdown_Metadata`) into the `build` workflow, a
  new `docs` workflow (`Package_Wiki_Content`) into `pack`, and enabled
  `Publish_GitHub_Wiki_Content` in the `publish` workflow in `build.yaml`. Added
  `PlatyPS` to `RequiredModules.psd1` (required for command markdown generation).

### Changed

- `ConvertFrom-PsuJobOutputEntry`'s `StreamColor` property now returns a CSS
  `var(--psu-term-stream-*)` reference instead of a literal hex color, so job
  output stream coloring follows the light/dark theme instead of being fixed to
  one palette. This is a private helper; the change is only user-visible via the
  themed rendering of `New-UDPsuJobTerminalView`.

- Changed Warning messages to Debug messages when overriding type accelerators.
  This is to reduce noise in the output and only show warnings for actual issues.

### Fixed

- Fixed `Import-PSUAiTool` leaking `New-PSUScript`'s return object onto its output
  pipeline alongside the intended `New-PSUAiTool` result. Since a module's
  `.universal/aiTools.ps1` resource file is expected by PSU to emit only `AiTool`
  objects, the leaked `PowerShellUniversal.Script` object caused PSU to fail
  loading the configuration with `Cannot convert the "<Module>\<Command>" value of
  type "PowerShellUniversal.Script" to type
  "PowerShellUniversal.Models.Intelligence.AiTool"`, silently preventing all AI
  tools declared in that file from registering. `New-PSUScript`'s result is now
  suppressed with `$null =`.
- Changed `Import-PSUAiTool` to only create a backing PSU Script when one doesn't
  already exist for the `<Module>\<Command>` identity (via `Get-PSUScript`), instead
  of unconditionally re-declaring it on every config reload. A script may already be
  explicitly declared elsewhere (e.g. `scripts.ps1`) with more specific settings
  (Role, Timeout, Tags, etc.); the previous unconditional call would have silently
  overwritten that configuration with a bare-bones one every time PSU reloaded its
  config.
- Fixed the themed icon (top-right/title-bar `>_` icon) in `New-UDPsuJobHeader` and
  `New-UDPsuJobTerminalView` always rendering the light (black) variant regardless
  of PSU's active theme when `-Theme Auto` (the default). `ConvertTo-UDPsuThemedIconMarkup`
  was setting the light/dark icon spans' default visibility via an inline `style`
  attribute, which always takes precedence over stylesheet rules regardless of CSS
  specificity -- so `Get-UDPsuJobThemeStyleBlock`'s `html[data-theme="dark"]` override
  rule could never actually flip visibility. The default and dark-mode-override
  display rules are now both defined in the `<style>` block instead, so the icon
  correctly switches color when the PSU theme switch is toggled live.
- Fixed how the ApiVersion is set and can be overridden.
- Fixed how the Documentation is set and can be overridden.

## [0.1.2] - 2025-12-05

### Fixed

- Fixed issue with URL generation in `Get-ModuleApiEndpoint` function to correctly
  include API prefix.
- Fixed issue with `${}` notation in parameter names ([[#1](https://github.com/SynEdgy/synedgy.universal.helper/issues/1)]).
- Fixing typo in `Import-ModuleApiEndpoint` function documentation. ([#3](https://github.com/SynEdgy/synedgy.universal.helper/issues/3))
- Fixed bug in `Get-HttpMethodFromPSVerb` function to correctly map PowerShell
  verbs to HTTP methods.
- Fixed issue with `ApiPrefix` property not being applied correctly in URL generation.
- Fixed issue where `Authentication` property in `APIEndpoint` attribute was not
working.
- Fixed changelog git config to publish PR.

### Added

- Adding APIEndpoint attribute.
- Adding `Import-ModuleApiEndpoint` function to import API endpoints from a module.
- Adding `Get-HttpMethodFromPSVerb` function to convert PowerShell verbs to HTTP
  methods (GET, POST, PUT, DELETE).
- Adding support for `Documentation` property in API endpoint metadata. ([#2](https://github.com/SynEdgy/synedgy.universal.helper/issues/2))
- Adding `ApiPrefix` and `Version` properties to `APIEndpoint` attribute for better
  URL structuring.
- Adding `[APIInput]` and `[APIOutput]` attributes for defining input and output
  schemas for API endpoint documentation (Not yet implemented).
