#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Run this entrypoint on the configured Windows controller.' }
$configPath = if ($env:BSK_REMOTE_CONFIG) { $env:BSK_REMOTE_CONFIG } else { Join-Path $env:USERPROFILE '.bsk/browser-skill-remote.json' }
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Remote browser is not configured on this controller: $configPath" }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
foreach ($key in @('ControllerMachine', 'BskExecutable', 'BskHome', 'PublicUrl')) {
    if ([string]::IsNullOrWhiteSpace($config.$key)) { throw "Remote browser config is missing $key." }
}
if ($config.ControllerMachine -ne $env:COMPUTERNAME) { throw "This configuration belongs to controller $($config.ControllerMachine), not $env:COMPUTERNAME." }
if (-not [IO.Path]::IsPathFullyQualified($config.BskExecutable) -or -not (Test-Path -LiteralPath $config.BskExecutable -PathType Leaf)) { throw 'Configured bsk executable must be an existing absolute path.' }
if (-not [IO.Path]::IsPathFullyQualified($config.BskHome) -or -not (Test-Path -LiteralPath $config.BskHome -PathType Container)) { throw 'Configured BSK_HOME must be an existing absolute directory.' }
$skillRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\', '/')
foreach ($path in @($configPath, $config.BskHome)) {
    $absolutePath = [IO.Path]::GetFullPath($path).TrimEnd('\', '/')
    if ($absolutePath.Equals($skillRoot, [StringComparison]::OrdinalIgnoreCase) -or $absolutePath.StartsWith($skillRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Configuration and BSK_HOME must be outside the managed Skill directory.' }
}
$endpoint = [uri]$config.PublicUrl
if ($endpoint.Scheme -ne 'wss' -or $endpoint.Fragment -or $endpoint.UserInfo) { throw 'PublicUrl must be a WSS endpoint without credentials or a pairing fragment.' }
$previousHome = $env:BSK_HOME
$previousAutoStart = $env:BSK_AUTO_START
try {
    $env:BSK_HOME = $config.BskHome
    $env:BSK_AUTO_START = '0'
    if ($args.Count -eq 1 -and $args[0] -eq 'discover') {
        foreach ($key in @('TargetMachine', 'ExpectedDeviceId', 'ExpectedBrowser')) {
            if ([string]::IsNullOrWhiteSpace($config.$key)) { throw "Remote browser config is missing $key." }
        }
        $statusText = & $config.BskExecutable status --json
        if ($LASTEXITCODE -ne 0) { throw 'Remote server is unavailable. Inspect its existing supervisor and IPC access.' }
        $status = ($statusText -join "`n") | ConvertFrom-Json
        if ([version]$status.protocol_version -lt [version]'1.3') { throw 'Remote discovery requires daemon protocol 1.3 or newer.' }
        $devicesText = & $config.BskExecutable daemon devices --json
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read remote device authorization records.' }
        $devices = ($devicesText -join "`n") | ConvertFrom-Json
        $matches = @($devices | Where-Object device_id -eq $config.ExpectedDeviceId)
        if ($matches.Count -ne 1) { throw "The registered device for $($config.TargetMachine) is missing or ambiguous. Confirm its pairing before changing the configuration." }
        $device = $matches[0]
        if ([DateTimeOffset]::Parse($device.expires_at) -le [DateTimeOffset]::UtcNow) { throw "Authorization for $($config.TargetMachine) has expired." }
        $browsers = @($status.browsers | Where-Object instance_id -eq $device.browser_id)
        if ($browsers.Count -ne 1) { throw "The registered browser on $($config.TargetMachine) is offline." }
        $browser = $browsers[0]
        if ($browser.browser_name -ne $config.ExpectedBrowser) { throw 'The connected browser type does not match the registered target.' }
        if ($browser.unresponsive -or $browser.version_skew) { throw 'The registered browser is unresponsive or has an incompatible protocol.' }
        [pscustomobject]@{
            ready = $true
            controller = $config.ControllerMachine
            target = $config.TargetMachine
            device_id = $device.device_id
            browser_id = $browser.instance_id
            browser_name = $browser.browser_name
            endpoint = $endpoint.AbsoluteUri
            active_sessions = $browser.session_count
        } | ConvertTo-Json
    } else {
        & $config.BskExecutable @args
        if ($LASTEXITCODE -ne 0) { throw "BrowserSkill failed with exit code $LASTEXITCODE." }
    }
} finally {
    $env:BSK_HOME = $previousHome
    $env:BSK_AUTO_START = $previousAutoStart
}
