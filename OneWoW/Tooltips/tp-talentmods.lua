local ADDON_NAME, OneWoW = ...

local _, playerClass = UnitClass("player")
local classColor = RAID_CLASS_COLORS[playerClass]
local classColorHex = classColor and classColor.colorStr or "ffffffff"

local SPELL_NAME_COLOR = "ffffffff"
local TALENT_NAME_COLOR = classColorHex

local spellModifierCache = {}

local talentsMissingName = {
    [47541] = { [444072] = true },
    [207317] = { [444072] = true },
}

local blacklistedTalents = {
    [339] = { [33891] = true },
    [102693] = { [393371] = true },
    [8936] = { [33891] = true },
    [774] = { [33891] = true },
    [48438] = { [33891] = true },
    [5176] = { [33891] = true },
    [124682] = { [116680] = true, [388491] = true },
    [191837] = { [116680] = true, [388491] = true },
    [322101] = { [116680] = true, [388491] = true },
    [115151] = { [116680] = true, [388491] = true },
    [107428] = { [116680] = true, [388491] = true },
    [116670] = { [116680] = true, [388491] = true },
    [188443] = { [262303] = true },
    [188389] = { [262303] = true, [378270] = true, [114050] = true },
    [196840] = { [262303] = true },
    [51505] = { [262303] = true },
    [188196] = { [262303] = true },
}

local modifierNameExceptions = {
    ["Slam"] = { "Shield Slam" },
    ["Meteor"] = { "Meteorite" },
}

local modifierInheritance = {
    [1242174] = 47541,
    [199786] = 116,
    [200758] = 53,
    [388667] = 686,
    [431443] = 361469,
    [443454] = 378081,
    [467307] = 107428,
}

local function GetSettings()
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    if not db or not db.tooltips then return nil end
    return db.tooltips.talentmods
end

local function isBaseCoveredByException(s, e, text, exList)
    if not exList then return false end
    for _, full in ipairs(exList) do
        local init = 1
        while true do
            local s_full, e_full = string.find(text, full, init, true)
            if not s_full then break end
            if s >= s_full and e <= e_full then return true end
            init = e_full + 1
        end
    end
    return false
end

local function hasUnexceptedMatch(baseName, text)
    if not baseName or not text then return false end
    local exceptions = modifierNameExceptions[baseName]
    local init = 1
    while true do
        local s, e = string.find(text, baseName, init, true)
        if not s then break end
        if not isBaseCoveredByException(s, e, text, exceptions) then
            return true
        end
        init = e + 1
    end
    return false
end

local function colorText(text, color)
    return "|c" .. color .. text .. "|r"
end

local function prettifyText(text, spellName)
    if not text or not spellName then return text end
    local exceptions = modifierNameExceptions[spellName]
    local parts = {}
    local last = 1
    local init = 1
    while true do
        local s, e = string.find(text, spellName, init, true)
        if not s then break end
        if not isBaseCoveredByException(s, e, text, exceptions) then
            if s > last then table.insert(parts, text:sub(last, s - 1)) end
            table.insert(parts, colorText(text:sub(s, e), SPELL_NAME_COLOR))
            last = e + 1
        end
        init = e + 1
    end
    if last <= #text then table.insert(parts, text:sub(last)) end
    return table.concat(parts)
end

local function populateSpellModifiers(spellID)
    if spellModifierCache[spellID] then return end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return end

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo then return end

    local settings = GetSettings()
    local includeActive = settings and settings.includeActive

    for _, treeID in ipairs(configInfo.treeIDs) do
        local nodes = C_Traits.GetTreeNodes(treeID)
        if nodes then
            for _, nodeID in ipairs(nodes) do
                local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
                if nodeInfo then
                    for _, entryID in ipairs(nodeInfo.entryIDs) do
                        local entryInfo = C_Traits.GetEntryInfo(configID, entryID)
                        if entryInfo and entryInfo.definitionID then
                            local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                            if definitionInfo and definitionInfo.spellID and C_SpellBook.IsSpellKnown(definitionInfo.spellID) then
                                local knownTalentID = definitionInfo.spellID
                                if knownTalentID and spellID ~= knownTalentID and (C_Spell.IsSpellPassive(knownTalentID) or includeActive) then
                                    local isNotBlacklisted = not (blacklistedTalents[spellID] and blacklistedTalents[spellID][knownTalentID])
                                    local isTalentMissingName = talentsMissingName[spellID] and talentsMissingName[spellID][knownTalentID]

                                    if isNotBlacklisted then
                                        local spell = C_Spell.GetSpellInfo(spellID)
                                        local knownTalent = Spell:CreateFromSpellID(knownTalentID)

                                        knownTalent:ContinueOnSpellLoad(function()
                                            local talentName = knownTalent:GetSpellName()
                                            local talentDesc = knownTalent:GetSpellDescription()

                                            if spell and spell.name then
                                                if isTalentMissingName or hasUnexceptedMatch(spell.name, talentDesc) then
                                                    talentDesc = prettifyText(talentDesc, spell.name)
                                                    talentDesc = "\n" .. colorText(talentName, TALENT_NAME_COLOR) .. "\n" .. talentDesc
                                                    spellModifierCache[spellID] = spellModifierCache[spellID] or {}
                                                    spellModifierCache[spellID][knownTalentID] = talentDesc
                                                end
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function getCachedModifiers(spellID)
    populateSpellModifiers(spellID)
    return spellModifierCache[spellID] or {}
end

local function OnSpellTooltip(tooltip, data)
    if not OneWoW.TooltipEngine or not OneWoW.TooltipEngine:IsFeatureEnabled("talentmods") then return end
    if not data or not data.lines or not data.type then return end
    if data.type ~= Enum.TooltipDataType.Spell and data.type ~= Enum.TooltipDataType.Macro then return end

    local settings = GetSettings()
    if not settings then return end

    if settings.hideInCombat and UnitAffectingCombat("player") then return end

    local spellID = (data.type == Enum.TooltipDataType.Macro and data.lines[1] and data.lines[1].tooltipID) or data.id
    if not spellID or issecretvalue(spellID) then return end

    local inheritedModifiers = {}
    local baseSpellID = modifierInheritance[spellID]
    if baseSpellID then
        inheritedModifiers = getCachedModifiers(baseSpellID)
    end

    local modifierTooltips = getCachedModifiers(spellID)
    for _, tooltipText in pairs(modifierTooltips) do
        tooltip:AddLine(tooltipText, nil, nil, nil, true)
    end

    if baseSpellID then
        local hasInherited = false
        for modifierID, tooltipText in pairs(inheritedModifiers) do
            if not modifierTooltips[modifierID] then
                if not hasInherited then
                    local baseSpellInfo = C_Spell.GetSpellInfo(baseSpellID)
                    local baseSpellName = baseSpellInfo and baseSpellInfo.name
                    if baseSpellName then
                        tooltip:AddLine("\nFrom " .. colorText(baseSpellName, SPELL_NAME_COLOR) .. ":")
                    end
                    hasInherited = true
                end
                tooltip:AddLine(tooltipText, nil, nil, nil, true)
            end
        end
    end

end

C_Timer.After(2, function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall then
        TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, OnSpellTooltip)
    end

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("SPELLS_CHANGED")
    frame:SetScript("OnEvent", function()
        wipe(spellModifierCache)
    end)
end)
