local addonName, ns = ...

ns.Guild = {}
local Module = ns.Guild

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if not IsInGuild() then
        charData.guild = nil
        return true
    end

    local guildData = {}

    local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")

    guildData.name = guildName
    guildData.rank = guildRankName
    guildData.rankIndex = guildRankIndex

    local guildFactionData = C_Reputation.GetGuildFactionData()
    if guildFactionData then
        guildData.factionID = guildFactionData.factionID
        guildData.standingID = guildFactionData.reaction
        guildData.currentStanding = guildFactionData.currentStanding
        guildData.reputation = guildFactionData.currentReactionThreshold
    end

    charData.guild = guildData

    return true
end
