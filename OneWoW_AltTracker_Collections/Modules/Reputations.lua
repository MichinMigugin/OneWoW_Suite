local addonName, ns = ...

ns.Reputations = {}
local Module = ns.Reputations

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if not charData.reputations then
        charData.reputations = {}
    end

    local repsData = charData.reputations
    local factions = {}

    local numFactions = C_Reputation.GetNumFactions()
    for i = 1, numFactions do
        local factionData = C_Reputation.GetFactionDataByIndex(i)
        if factionData then
            local factionInfo = {
                factionID = factionData.factionID,
                name = factionData.name,
                reaction = factionData.reaction,
                currentStanding = factionData.currentStanding,
                currentReactionThreshold = factionData.currentReactionThreshold,
                nextReactionThreshold = factionData.nextReactionThreshold,
                isHeader = factionData.isHeader,
                isCollapsed = factionData.isCollapsed,
                isHeaderWithRep = factionData.isHeaderWithRep,
                isWatched = factionData.isWatched,
                hasBonusRepGain = factionData.hasBonusRepGain,
                canToggleAtWar = factionData.canToggleAtWar,
                isAtWar = factionData.isAtWar,
            }

            local factionID = factionData.factionID
            if factionID and C_Reputation.IsFactionParagon(factionID) then
                local currentValue, threshold = C_Reputation.GetFactionParagonInfo(factionID)
                if currentValue and threshold then
                    factionInfo.isParagon = true
                    factionInfo.paragonValue = currentValue
                    factionInfo.paragonThreshold = threshold
                end
            end

            table.insert(factions, factionInfo)
        end
    end

    repsData.factions = factions
    repsData.count = #factions

    charData.lastUpdate = time()

    return true
end

function Module:GetFactionStanding(factionID)
    if not factionID then return nil end

    local factionData = C_Reputation.GetFactionDataByID(factionID)
    if not factionData then return nil end

    return {
        name = factionData.name,
        reaction = factionData.reaction,
        currentStanding = factionData.currentStanding,
        currentReactionThreshold = factionData.currentReactionThreshold,
        nextReactionThreshold = factionData.nextReactionThreshold,
    }
end
