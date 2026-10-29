BeforeAll {
    $script:moduleName = 'synedgy.universal.helper'

    if (-not (Get-Module -Name $script:moduleName -ListAvailable))
    {
        & "$PSScriptRoot/../../../build.ps1" -Tasks 'noop' 2>&1 4>&1 5>&1 6>&1 > $null
    }

    Import-Module -Name $script:moduleName -Force -ErrorAction Stop

    $script:testModuleName = 'EndpointScriptblockTestModule'
    $script:testModuleRoot = Join-Path -Path $TestDrive -ChildPath $script:testModuleName
    $null = New-Item -Path $script:testModuleRoot -ItemType Directory -Force
    $testModuleFile = Join-Path -Path $script:testModuleRoot -ChildPath "$($script:testModuleName).psm1"

    @'
enum EndpointMode
{
    First
    Second
}

class EndpointPayload
{
    [string] $Name
    [int] $Count
}

function Invoke-EndpointContract
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param
    (
        [Parameter(Mandatory)]
        [EndpointMode]
        $Mode,

        [Parameter(DontShow)]
        [string]
        $InternalToken = 'module-default',

        [Parameter()]
        [switch]
        $Force,

        [Parameter()]
        [EndpointMode[]]
        $Modes,

        [Parameter()]
        [EndpointMode]
        $DefaultMode = [EndpointMode]::First,

        [Parameter()]
        [EndpointMode[]]
        $DefaultModes = @([EndpointMode]::First, [EndpointMode]::Second),

        [Parameter()]
        [EndpointPayload]
        $Payload,

        [Parameter()]
        [EndpointPayload[]]
        $Payloads,

        [Parameter(DontShow)]
        [switch]
        $InternalFlag,

        [Parameter(DontShow)]
        [int]
        $InternalCount = 7
    )

    if ($PSCmdlet.ShouldProcess($Mode, 'Invoke endpoint contract'))
    {
        [pscustomobject]@{
            Mode             = $Mode.ToString()
            ModeType         = $Mode.GetType().FullName
            Force            = $Force.IsPresent
            Modes            = @($Modes | ForEach-Object ToString)
            ModesType        = $Modes.GetType().GetElementType().FullName
            DefaultMode      = $DefaultMode.ToString()
            DefaultModeType  = $DefaultMode.GetType().FullName
            DefaultModes     = @($DefaultModes | ForEach-Object ToString)
            Payload          = $Payload
            PayloadType      = $Payload.GetType().FullName
            Payloads         = $Payloads
            PayloadsType     = $Payloads.GetType().GetElementType().FullName
            InternalToken    = $InternalToken
            InternalFlag     = $InternalFlag.IsPresent
            InternalCount    = $InternalCount
        }
    }
}

Export-ModuleMember -Function 'Invoke-EndpointContract'
'@ | Set-Content -Path $testModuleFile -Encoding utf8

    Import-Module -Name $testModuleFile -Force -Global
    $script:functionInfo = Get-Command -Name 'Invoke-EndpointContract' -Module $script:testModuleName
    $script:typeAccelerators = [psobject].Assembly.GetType(
        'System.Management.Automation.TypeAccelerators'
    )
    $script:typeAccelerators::Add(
        'EndpointMode',
        $script:functionInfo.Parameters['Mode'].ParameterType
    )
    $script:typeAccelerators::Add(
        'EndpointPayload',
        $script:functionInfo.Parameters['Payload'].ParameterType
    )
}

AfterAll {
    $script:typeAccelerators::Remove('EndpointMode')
    $script:typeAccelerators::Remove('EndpointPayload')
    Remove-Module -Name $script:testModuleName -Force -ErrorAction SilentlyContinue
    Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
}

Describe 'Get-ModuleApiEndpointScriptblock' {
    BeforeAll {
        $endpoint = @{
            FunctionInfo = $script:functionInfo
            LogLevel     = @()
            Url          = '/api/v1/endpoint-contract'
        }
        $script:generatedScriptblock = Get-ModuleApiEndpointScriptblock -ModuleApiEndpoint $endpoint
        $script:generatedText = $script:generatedScriptblock.ToString()
    }

    It 'replaces enum types with parser-safe strings and validation metadata' {
        $script:generatedText | Should -Match "\[ValidateSet\('First', 'Second'\)\]\[string\]"
        $script:generatedText | Should -Match "\[ValidateSet\('First', 'Second'\)\]\[string\[\]\]"
        $script:generatedText | Should -Not -Match '\[EndpointMode(?:\[\])?\]'
        $script:generatedText | Should -Match "\`$defaultMode\s*=\s*'First'"
        $script:generatedText | Should -Match "\`$defaultModes\s*=\s*@\('First', 'Second'\)"
    }

    It 'replaces switch parameters with Boolean endpoint parameters' {
        $script:generatedText | Should -Match '\[bool\]\s*\$force'
        $script:generatedText | Should -Not -Match '\[switch\]'
    }

    It 'Should replace PowerShell class parameters with parser-safe objects' {
        $script:generatedText | Should -Match '\[object\]\s*\$payload'
        $script:generatedText | Should -Match '\[object\[\]\]\s*\$payloads'
        $script:generatedText | Should -Not -Match '\[EndpointPayload(?:\[\])?\]'
    }

    It 'omits parameters marked DontShow from the endpoint contract' {
        $script:generatedText | Should -Not -Match 'InternalToken'
        $script:generatedText | Should -Not -Match 'InternalFlag'
        $script:generatedText | Should -Not -Match 'InternalCount'
        $script:generatedText | Should -Not -Match 'DontShow'
    }

    It 'disables interactive confirmation for endpoint commands that support ShouldProcess' {
        $script:generatedText | Should -Match 'Invoke-EndpointContract @PSBoundParameters -Confirm:\$false'
    }

    It 'Should retain strong enum, switch, and class binding when invoking the module command' {
        $payload = [pscustomobject]@{
            Name  = 'Primary'
            Count = 1
        }
        $payloads = @(
            [pscustomobject]@{
                Name  = 'First'
                Count = 2
            }
            [ordered]@{
                Name  = 'Second'
                Count = 3
            }
        )
        $endpointParameters = @{
            mode     = 'Second'
            force    = $true
            modes    = @('First', 'Second')
            payload  = $payload
            payloads = $payloads
        }
        $result = & $script:generatedScriptblock @endpointParameters

        $result.Mode | Should -Be 'Second'
        $result.ModeType | Should -Be 'EndpointMode'
        $result.Force | Should -BeTrue
        $result.Modes | Should -Be @('First', 'Second')
        $result.ModesType | Should -Be 'EndpointMode'
        $result.DefaultMode | Should -Be 'First'
        $result.DefaultModeType | Should -Be 'EndpointMode'
        $result.DefaultModes | Should -Be @('First', 'Second')
        $result.Payload | Should -BeOfType $script:functionInfo.Parameters['Payload'].ParameterType
        $result.Payload.Name | Should -Be 'Primary'
        $result.PayloadType | Should -Be 'EndpointPayload'
        $result.Payloads.Name | Should -Be @('First', 'Second')
        $result.PayloadsType | Should -Be 'EndpointPayload'
        $result.InternalToken | Should -Be 'module-default'
        $result.InternalFlag | Should -BeFalse
        $result.InternalCount | Should -Be 7
    }

    It 'Should reproduce the process-local PowerShell class type failure without normalization' {
        $command = 'param([EndpointPayload] $Payload) $Payload'
        $encodedCommand = [System.Convert]::ToBase64String(
            [System.Text.Encoding]::Unicode.GetBytes($command)
        )
        $powerShellPath = (Get-Process -Id $PID).Path
        $standardOutputPath = Join-Path -Path $TestDrive -ChildPath 'class-parameter-stdout.txt'
        $standardErrorPath = Join-Path -Path $TestDrive -ChildPath 'class-parameter-stderr.txt'

        $processParameters = @{
            FilePath               = $powerShellPath
            ArgumentList           = @('-NoLogo', '-NoProfile', '-EncodedCommand', $encodedCommand)
            Wait                   = $true
            PassThru               = $true
            RedirectStandardOutput = $standardOutputPath
            RedirectStandardError  = $standardErrorPath
        }
        $process = Start-Process @processParameters
        $output = @(
            Get-Content -Path $standardOutputPath -ErrorAction SilentlyContinue
            Get-Content -Path $standardErrorPath -ErrorAction SilentlyContinue
        ) -join [System.Environment]::NewLine

        $process.ExitCode | Should -Not -Be 0
        $output | Should -Match 'Unable to find type \[EndpointPayload\]'
    }

    It 'Should execute in a runspace where custom enum and class types are unavailable' {
        $isolatedPowerShell = [powershell]::Create()
        try
        {
            $scriptUnderTest = @'
function Invoke-EndpointContract
{
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$Mode,
        [bool]$Force,
        [string[]]$Modes,
        [string]$DefaultMode = 'First',
        [string[]]$DefaultModes = @('First', 'Second'),
        [object]$Payload,
        [object[]]$Payloads
    )

    [pscustomobject]@{
        Mode         = $Mode
        Force        = $Force
        Modes        = $Modes
        DefaultMode  = $DefaultMode
        DefaultModes = $DefaultModes
        Payload      = $Payload
        Payloads     = $Payloads
    }
}

& {
__GENERATED_SCRIPTBLOCK__
} -mode Second -force $true -modes First, Second -payload @{ Name = 'Primary'; Count = 1 }
'@ -replace '__GENERATED_SCRIPTBLOCK__', $script:generatedText

            $result = $isolatedPowerShell.AddScript($scriptUnderTest).Invoke()

            $isolatedPowerShell.Streams.Error | Should -BeNullOrEmpty
            $result.Mode | Should -Be 'Second'
            $result.Force | Should -BeTrue
            $result.Modes | Should -Be @('First', 'Second')
            $result.Payload.Name | Should -Be 'Primary'
        }
        finally
        {
            $isolatedPowerShell.Dispose()
        }
    }
}
