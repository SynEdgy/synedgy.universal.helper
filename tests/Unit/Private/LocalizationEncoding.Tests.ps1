BeforeDiscovery {
    $projectPath = $PSScriptRoot
    while (-not (Test-Path -Path (Join-Path -Path $projectPath -ChildPath 'build.ps1')))
    {
        $parentPath = Split-Path -Path $projectPath -Parent
        if ($parentPath -eq $projectPath)
        {
            throw 'Could not locate repository root containing build.ps1.'
        }

        $projectPath = $parentPath
    }

    $script:nonAsciiPowerShellFiles = @(
        Get-ChildItem -Path (
            Join-Path -Path $projectPath -ChildPath 'source'
        ), (
            Join-Path -Path $projectPath -ChildPath 'tests'
        ) -Recurse -File -Include '*.ps1', '*.psd1' |
            Where-Object {
                $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
                $bytes.Where({ $_ -gt 127 }, 'First').Count -gt 0
            }
    )
}

Describe 'Localization file encoding' {
    It 'Should use a UTF-8 BOM for Windows PowerShell compatibility: <Name>' -ForEach $script:nonAsciiPowerShellFiles {
        $bytes = [System.IO.File]::ReadAllBytes($_.FullName)

        $bytes.Length | Should -BeGreaterOrEqual 3
        $bytes[0] | Should -Be 0xEF
        $bytes[1] | Should -Be 0xBB
        $bytes[2] | Should -Be 0xBF
    }
}
