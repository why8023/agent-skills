#Requires -Version 7.0
param([Parameter(Mandatory)][string]$WorkDirectory)
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'These checks require Windows PowerShell 7.' }
if (-not [IO.Path]::IsPathFullyQualified($WorkDirectory)) { throw 'Use an absolute workspace directory for test artifacts.' }
New-Item -ItemType Directory -Path $WorkDirectory -Force | Out-Null
$entrypoint = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts/Invoke-BrowserSkillRemote.ps1'
$fakeCli = Join-Path $WorkDirectory 'fake-bsk.ps1'
@'
$fixture = Get-Content -LiteralPath (Join-Path $env:BSK_HOME 'fixture.json') -Raw | ConvertFrom-Json
[pscustomobject]@{home=$env:BSK_HOME;auto_start=$env:BSK_AUTO_START;args=@($args)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $env:BSK_HOME 'last-call.json')
$global:LASTEXITCODE = $fixture.exit_code
switch ($args -join ' ') {
    'status --json' { $fixture.status | ConvertTo-Json -Depth 6 }
    'daemon devices --json' { ConvertTo-Json -InputObject @($fixture.devices) -Depth 6 }
    default { @($args) | ConvertTo-Json -Compress }
}
'@ | Set-Content -LiteralPath $fakeCli -Encoding utf8
$configFile = Join-Path $WorkDirectory 'config.json'
$config = [pscustomobject]@{ControllerMachine=$env:COMPUTERNAME;TargetMachine='test-remote';ExpectedDeviceId='device-target';ExpectedBrowser='edge';BskExecutable=$fakeCli;BskHome=$WorkDirectory;PublicUrl='wss://controller.example/extension'}
$other = [pscustomobject]@{instance_id='other-browser';browser_name='edge';session_count=0;unresponsive=$false;version_skew=$false}
$target = [pscustomobject]@{instance_id='current-browser';browser_name='edge';session_count=0;unresponsive=$false;version_skew=$false}
$device = [pscustomobject]@{device_id='device-target';browser_id=$target.instance_id;expires_at=[DateTimeOffset]::UtcNow.AddDays(90).ToString('o')}
$fixture = [pscustomobject]@{exit_code=0;status=[pscustomobject]@{protocol_version='1.3';browsers=@($other,$target)};devices=@([pscustomobject]@{device_id='other-device';browser_id=$other.instance_id},$device)}
function Save-Fixture {
    $config | ConvertTo-Json | Set-Content -LiteralPath $configFile -Encoding utf8
    $fixture | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $WorkDirectory 'fixture.json') -Encoding utf8
}
function Assert-Rejected([string]$Pattern) {
    $caught = $false
    try { & $entrypoint discover | Out-Null } catch {
        $caught = $true
        if ($_.Exception.Message -notmatch $Pattern) { throw }
    }
    if (-not $caught) { throw "Expected discovery to reject: $Pattern" }
    if ($env:BSK_HOME -ne 'previous-home' -or $env:BSK_AUTO_START -ne 'previous-auto-start') { throw 'Failure changed the caller environment.' }
}
$saved = @{}
foreach ($key in @('BSK_REMOTE_CONFIG','BSK_HOME','BSK_AUTO_START')) { $saved[$key] = [Environment]::GetEnvironmentVariable($key,'Process') }
try {
    $env:BSK_REMOTE_CONFIG = $configFile
    $env:BSK_HOME = 'previous-home'
    $env:BSK_AUTO_START = 'previous-auto-start'
    Save-Fixture
    $ready = (& $entrypoint discover) | ConvertFrom-Json
    if (-not $ready.ready -or $ready.browser_id -ne $target.instance_id -or $ready.target -ne 'test-remote') { throw 'Discovery selected the wrong device.' }
    $target.instance_id = 'changed-browser'
    $device.browser_id = $target.instance_id
    Save-Fixture
    if (((& $entrypoint discover) | ConvertFrom-Json).browser_id -ne 'changed-browser') { throw 'Discovery reused a stale browser ID.' }
    if ($env:BSK_HOME -ne 'previous-home' -or $env:BSK_AUTO_START -ne 'previous-auto-start') { throw 'Successful discovery changed the caller environment.' }
    & $entrypoint navigate 'https://example.invalid/' --session 'test-session' --timeout '2s' | Out-Null
    $call = Get-Content -LiteralPath (Join-Path $WorkDirectory 'last-call.json') -Raw | ConvertFrom-Json
    if (($call.args -join '|') -ne 'navigate|https://example.invalid/|--session|test-session|--timeout|2s' -or $call.home -ne $WorkDirectory -or $call.auto_start -ne '0') { throw 'Native arguments or per-call environment were not preserved.' }
    $fixture.status.browsers = @($other)
    Save-Fixture
    Assert-Rejected 'offline'
    $fixture.status.browsers = @($other,$target)
    $config.ExpectedDeviceId = 'unknown-device'
    Save-Fixture
    Assert-Rejected 'missing or ambiguous'
    $config.ExpectedDeviceId = $device.device_id
    $device.expires_at = [DateTimeOffset]::UtcNow.AddDays(-1).ToString('o')
    Save-Fixture
    Assert-Rejected 'expired'
    $device.expires_at = [DateTimeOffset]::UtcNow.AddDays(90).ToString('o')
    $target.unresponsive = $true
    Save-Fixture
    Assert-Rejected 'unresponsive'
    $target.unresponsive = $false
    $fixture.exit_code = 7
    Save-Fixture
    Assert-Rejected 'unavailable'
    $fixture.exit_code = 0
    $config.ControllerMachine = 'different-controller'
    Save-Fixture
    Assert-Rejected 'belongs to controller'
    $config.ControllerMachine = $env:COMPUTERNAME
    $config.BskHome = Split-Path $PSScriptRoot -Parent
    Save-Fixture
    Assert-Rejected 'outside the managed Skill'
    $config.BskHome = $WorkDirectory
    $config.PublicUrl = 'wss://controller.example/extension#test-pairing-secret'
    Save-Fixture
    Assert-Rejected 'without credentials'
    'PASS: device identity, changing browser IDs, native arguments, offline/expired/unresponsive targets, server failure, controller binding, external state, secret-free endpoint, environment restoration'
} finally {
    foreach ($key in $saved.Keys) { [Environment]::SetEnvironmentVariable($key,$saved[$key],'Process') }
}
