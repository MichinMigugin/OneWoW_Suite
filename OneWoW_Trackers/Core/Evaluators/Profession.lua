local _, ns = ...

local E = ns.TrackerEvaluators
local ipairs, tonumber = ipairs, tonumber

E.Register("prof_skill", function(op)
    local baseID = tonumber(op.baseSkillLineID)
    if not baseID then return end
    local prof1, prof2 = GetProfessions()
    for _, idx in ipairs({ prof1, prof2 }) do
        if idx then
            local _, _, skillLevel, maxSkillLevel, _, _, skillLineID = GetProfessionInfo(idx)
            if skillLineID == baseID then
                return skillLevel or 0, maxSkillLevel or 1
            end
        end
    end
end)

E.Register("prof_concentration", function(op)
    local currID = tonumber(op.currencyID)
    if not currID then return end
    local info = C_CurrencyInfo.GetCurrencyInfo(currID)
    if info then
        return info.quantity or 0, info.maxQuantity or 1000
    end
end)

E.Register("prof_knowledge", function(op)
    local skillLineVariantID = tonumber(op.skillLineVariantID)
    if not skillLineVariantID then return end
    local configID = C_ProfSpecs.GetConfigIDForSkillLine(skillLineVariantID)
    if not configID then return end
    local configInfo = C_Traits.GetConfigInfo(configID)
    if not (configInfo and configInfo.treeIDs) then return end
    local treeID = configInfo.treeIDs[1]
    if not treeID then return end
    local nodes = C_Traits.GetTreeNodes(treeID)
    local totalSpent = 0
    if nodes then
        for _, nodeID in ipairs(nodes) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
            if nodeInfo and nodeInfo.currentRank then
                totalSpent = totalSpent + nodeInfo.currentRank
            end
        end
    end
    local currencyInfo = C_Traits.GetTreeCurrencyInfo(configID, treeID, false)
    local unspent = 0
    if currencyInfo then
        for _, ci in ipairs(currencyInfo) do
            unspent = unspent + (ci.quantity or 0)
        end
    end
    return totalSpent + unspent, 0
end)

E.Register("prof_firstcraft", function(op)
    local spellIDs = op.spellIDs or (op.spellID and { op.spellID }) or {}
    local done = 0
    for _, sid in ipairs(spellIDs) do
        sid = tonumber(sid)
        if sid and C_TradeSkillUI.IsRecipeFirstCraft(sid) == false then
            done = done + 1
        end
    end
    return done, #spellIDs
end)

E.Register("prof_catchup", function(op)
    local currID = tonumber(op.currencyID)
    if not currID then return end
    local info = C_CurrencyInfo.GetCurrencyInfo(currID)
    if not info then return end
    local max = info.maxQuantity or 0
    if max > 0 then
        return info.quantity or 0, max
    end
    return info.quantity or 0, 0
end)
