# Changelog for synedgy.universal.helper

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Fixed issue with URL generation in `Get-ModuleApiEndpoint` function to correctly
  include API prefix.
- Fixing typo in `Import-ModuleApiEndpoint` function documentation. ([#3])
- Fixed bug in `Get-HttpMethodFromPSVerb` function to correctly map PowerShell
  verbs to HTTP methods.
- Fixed issue with `ApiPrefix` property not being applied correctly in URL generation.
- Fixed issue where `Authentication` property in `APIEndpoint` attribute was not
working.

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
