#Requires -Version 7.0
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Run this server entrypoint on the configured Windows controller.' }
$configPath = if ($env:BSK_REMOTE_CONFIG) { $env:BSK_REMOTE_CONFIG } else { Join-Path $env:USERPROFILE '.bsk/browser-skill-remote.json' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ($config.Listen -ne '127.0.0.1') { throw 'This server entrypoint expects a loopback listener behind the configured TLS proxy.' }
& (Join-Path $PSScriptRoot 'Invoke-BrowserSkillRemote.ps1') daemon start --mode server --listen $config.Listen --port $config.Port --public-url $config.PublicUrl
