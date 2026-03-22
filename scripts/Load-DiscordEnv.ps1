# Dot-source this script so Discord env vars apply to the current PowerShell session:
#   . .\scripts\Load-DiscordEnv.ps1
# Then use $env:DISCORD_BOT_TOKEN with curl or Invoke-RestMethod.

param(
    [string] $EnvFile = (Join-Path (Split-Path $PSScriptRoot -Parent) '.env.local')
)

if (-not (Test-Path -LiteralPath $EnvFile)) {
    Write-Error "Missing '$EnvFile'. Create it at the repo root with DISCORD_BOT_TOKEN= (and optional GUILD_ID / ANNOUNCE_CHANNEL_ID). This file must stay gitignored."
    return
}

Get-Content -LiteralPath $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -match '^\s*#' -or $line -eq '') {
        return
    }
    if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        if ($value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        Set-Item -Path "Env:$name" -Value $value
    }
}

Write-Host "Loaded environment from: $EnvFile"
