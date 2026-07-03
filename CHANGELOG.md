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

### Changed

- `ConvertFrom-PsuJobOutputEntry`'s `StreamColor` property now returns a CSS
  `var(--psu-term-stream-*)` reference instead of a literal hex color, so job
  output stream coloring follows the light/dark theme instead of being fixed to
  one palette. This is a private helper; the change is only user-visible via the
  themed rendering of `New-UDPsuJobTerminalView`.

- Changed Warning messages to Debug messages when overriding type accelerators.
  This is to reduce noise in the output and only show warnings for actual issues.

### Fixed

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
