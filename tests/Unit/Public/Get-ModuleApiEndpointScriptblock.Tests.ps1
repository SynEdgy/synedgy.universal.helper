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
}

AfterAll {
    $script:typeAccelerators::Remove('EndpointMode')
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

    It 'omits parameters marked DontShow from the endpoint contract' {
        $script:generatedText | Should -Not -Match 'InternalToken'
        $script:generatedText | Should -Not -Match 'InternalFlag'
        $script:generatedText | Should -Not -Match 'InternalCount'
        $script:generatedText | Should -Not -Match 'DontShow'
    }

    It 'disables interactive confirmation for endpoint commands that support ShouldProcess' {
        $script:generatedText | Should -Match 'Invoke-EndpointContract @PSBoundParameters -Confirm:\$false'
    }

    It 'retains strong enum and switch binding when invoking the module command' {
        $result = & $script:generatedScriptblock -mode Second -force $true -modes First, Second

        $result.Mode | Should -Be 'Second'
        $result.ModeType | Should -Be 'EndpointMode'
        $result.Force | Should -BeTrue
        $result.Modes | Should -Be @('First', 'Second')
        $result.ModesType | Should -Be 'EndpointMode'
        $result.DefaultMode | Should -Be 'First'
        $result.DefaultModeType | Should -Be 'EndpointMode'
        $result.DefaultModes | Should -Be @('First', 'Second')
        $result.InternalToken | Should -Be 'module-default'
        $result.InternalFlag | Should -BeFalse
        $result.InternalCount | Should -Be 7
    }

    It 'can execute in a runspace where the custom enum type is unavailable' {
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
        [string[]]$DefaultModes = @('First', 'Second')
    )

    [pscustomobject]@{
        Mode         = $Mode
        Force        = $Force
        Modes        = $Modes
        DefaultMode  = $DefaultMode
        DefaultModes = $DefaultModes
    }
}

& {
__GENERATED_SCRIPTBLOCK__
} -mode Second -force $true -modes First, Second
'@ -replace '__GENERATED_SCRIPTBLOCK__', $script:generatedText

            $result = $isolatedPowerShell.AddScript($scriptUnderTest).Invoke()

            $isolatedPowerShell.Streams.Error | Should -BeNullOrEmpty
            $result.Mode | Should -Be 'Second'
            $result.Force | Should -BeTrue
            $result.Modes | Should -Be @('First', 'Second')
        }
        finally
        {
            $isolatedPowerShell.Dispose()
        }
    }
}
