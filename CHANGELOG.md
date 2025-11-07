# Changelog for synedgy.universal.helper

The format is based on and uses the types of changes according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Fixed issue with URL generation in `Get-ModuleApiEndpoint` function to correctly
  include API prefix.

### Added

- Adding APIEndpoint attribute.
- Adding `Import-ModuleApiEndpoint` function to import API endpoints from a module.
- Adding `Get-HttpMethodFromPSVerb` function to convert PowerShell verbs to HTTP
  methods (GET, POST, PUT, DELETE).
