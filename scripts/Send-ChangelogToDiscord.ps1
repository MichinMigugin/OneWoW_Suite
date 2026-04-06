# Posts the standard Simple changelog embeds (one per addon dev log channel).
# Requires: dot-source Load-DiscordEnv.ps1 first, or run from repo root after loading .env.local.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $RepoRoot

. (Join-Path $RepoRoot 'scripts\Load-DiscordEnv.ps1')
if (-not $env:DISCORD_BOT_TOKEN) {
    throw 'DISCORD_BOT_TOKEN is not set. Fill .env.local and load it via Load-DiscordEnv.ps1.'
}

$tmp = Join-Path $RepoRoot '.discord-changelog-send.json'

function Send-One([string]$ChannelId, [string]$Description) {
    $body = @{ embeds = @(@{ description = $Description; color = 16168776 }) } | ConvertTo-Json -Depth 10 -Compress
    [System.IO.File]::WriteAllText($tmp, $body, [System.Text.UTF8Encoding]::new($false))
    $bodyFile = "$tmp.bodybin"
    $httpCode = & curl.exe -sS --http1.1 -o $bodyFile -w "%{http_code}" -X POST `
        -H "Authorization: Bot $env:DISCORD_BOT_TOKEN" `
        -H "Content-Type: application/json; charset=utf-8" `
        --data-binary "@$tmp" `
        "https://discord.com/api/v10/channels/$ChannelId/messages"
    Remove-Item -LiteralPath $bodyFile -Force -ErrorAction SilentlyContinue
    if ($httpCode -ne '200') {
        throw "Discord API HTTP $httpCode for channel $ChannelId"
    }
}

try {
    Send-One '1472486712780263576' @'
**AltTracker - Favorites**
- Mark characters as favorites so you can find them faster.
'@

    Send-One '1462071323684634835' @'
**Bags - Sorting & windows**
- Added a "None" sort option when you don't want automatic sorting.
- Bag windows should remember size and position more reliably.
- More language coverage for the addon text.
'@

    Send-One '1475863507449938145' @'
**ShoppingList - Locales**
- Broader language support for the addon.
'@

    Send-One '1472087725816676443' @'
**DevTool - Errors & BugGrabber**
- When BugGrabber is installed, its errors can be brought into the dev tool for easier review.
- If the current session has errors, the tool can open on the Lua tab so you see them right away.

**Error logging & options**
- More options for error alerts (including sounds), how copied errors are formatted, and how many error sessions to keep.

**Layout & locales**
- Pinned memory monitor improvements (sizing and saved position).
- Clearer layout on some tool tabs (for example layout and color-related controls).
- More languages supported overall.
'@

    Send-One '1474738965671051306' @'
**OneWoW - Overlays & gear upgrade**
- Item overlays emphasize rarity more clearly with updated visuals.
- Gear upgrade overlay behavior and wording are clearer; related overlay glitches are addressed.

**GUI**
- Filter-style dropdowns close more predictably when you click outside or back into the game world.
'@

    Write-Host 'Posted 5 changelog embeds to Discord dev log channels.'
}
finally {
    if (Test-Path -LiteralPath $tmp) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}
