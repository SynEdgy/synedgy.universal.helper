---
applyTo: "source/**/*.ps1,source/**/*.psd1,tests/**/*.ps1"
---

# Localization

- Reusable components own a `<Module>.<Component>.strings.psd1` bundle in each
  supported culture directory.
- Accept `Language` and `DefaultUILanguage`; do not add one parameter per
  translated label.
- Load component strings with `Get-PSUComponentLocalizedData`. Resolution order
  is requested exact/parent culture, module-configured default, then mandatory
  English.
- Resolve strings once when creating a component. Preserve the selected
  dictionary in `$Page:` for deferred callbacks or serialize it through
  `ArgumentList` when the component already uses explicit deferred arguments.
- Keep page-owned text in page bundles and component-owned text in component
  bundles.
- Use `{0}` placeholders in resources and the `-f` operator at call sites.
- HTML-encode localized text inserted into markup. JSON-encode localized text
  inserted into JavaScript.
- English and translated resources must expose identical keys. Add focused
  tests for key parity, fallback behavior, and deferred language propagation.
- Resource files may be grouped in subfolders beneath each culture directory.
  Preserve root-level lookup priority, and keep each bundle filename unique
  within a culture to avoid ambiguous recursive discovery.
- Save PowerShell files containing non-ASCII localized text as UTF-8 with BOM
  so Windows PowerShell 5.1 does not decode translations as ANSI.
- Ensure module build configuration copies every culture directory containing
  localization resources.
