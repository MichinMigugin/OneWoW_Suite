local addonName, ns = ...

ns.ProfessionConcentration = {}
local Module = ns.ProfessionConcentration

local CONCENTRATION_RATE = 1 / 360

function Module:CollectFromTradeSkill(charKey, charData)
    if not charKey or not charData then return false end

    local professions = charData.professions or {}
    charData.concentration = charData.concentration or {}

    local professionInfos = C_TradeSkillUI.GetChildProfessionInfos()
    if not professionInfos or #professionInfos == 0 then return false end

    local bestPerSlot = {}

    for _, profInfo in pairs(professionInfos) do
        local concentrationCurrencyID = C_TradeSkillUI.GetConcentrationCurrencyID(profInfo.professionID)
        if concentrationCurrencyID and concentrationCurrencyID > 0 then
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(concentrationCurrencyID)
            if currencyInfo then
                local slotName = self:MatchProfessionSlot(profInfo.professionName, professions)
                if slotName then
                    local prev = bestPerSlot[slotName]
                    if not prev or profInfo.professionID > prev.professionID then
                        bestPerSlot[slotName] = {
                            professionID = profInfo.professionID,
                            currencyID = concentrationCurrencyID,
                            value = currencyInfo.quantity,
                            max = currencyInfo.maxQuantity,
                        }
                    end
                end
            end
        end
    end

    local found = false
    for slotName, best in pairs(bestPerSlot) do
        local existing = charData.concentration[slotName]
        local entry = {
            value = best.value,
            max = best.max,
            ts = time(),
            currencyID = best.currencyID,
            professionID = best.professionID,
        }
        if existing and existing.value == best.value then
            entry.ts = existing.ts
        end
        charData.concentration[slotName] = entry
        found = true
    end

    return found
end

function Module:RefreshFromCurrency(charKey, charData)
    if not charKey or not charData then return false end
    if not charData.concentration then return false end

    local updated = false
    for slotName, concData in pairs(charData.concentration) do
        if concData.currencyID and concData.currencyID > 0 then
            local currencyInfo = C_CurrencyInfo.GetCurrencyInfo(concData.currencyID)
            if currencyInfo then
                if concData.value ~= currencyInfo.quantity then
                    concData.ts = time()
                end
                concData.value = currencyInfo.quantity
                concData.max = currencyInfo.maxQuantity
                updated = true
            end
        end
    end

    return updated
end

function Module:CollectData(charKey, charData)
    if not charKey or not charData then return false end

    if self:CollectFromTradeSkill(charKey, charData) then
        return true
    end

    return self:RefreshFromCurrency(charKey, charData)
end

function Module:MatchProfessionSlot(childProfName, professions)
    if not childProfName or not professions then return nil end

    for slotName, profData in pairs(professions) do
        if profData and profData.name and childProfName:find(profData.name) then
            return slotName
        end
    end

    return nil
end

function Module:GetConcentration(charData, slotName)
    if not charData or not charData.concentration then return nil end

    local concData = charData.concentration[slotName]
    if not concData then return nil end

    local timeSince = time() - concData.ts
    local estimated = math.min(concData.max, math.floor(concData.value + (timeSince * CONCENTRATION_RATE)))

    return {
        current = estimated,
        max = concData.max,
        storedValue = concData.value,
        timestamp = concData.ts,
    }
end
