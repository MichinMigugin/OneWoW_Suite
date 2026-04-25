local ADDON_NAME, OneWoW = ...

local ID_LABELS = {
    itemID           = "ItemID",
    spellID          = "SpellID",
    npcID            = "NPC ID",
    achievementID    = "AchievementID",
    questID          = "QuestID",
    currencyID       = "CurrencyID",
    mountID          = "MountID",
    petID            = "SpeciesID",
    enchantID        = "EnchantID",
    iconID           = "IconID",
    expansionID      = "ExpansionID",
    setID            = "SetID",
    decorEntryID     = "DecorEntryID",
    recipeID         = "RecipeID",
    equipmentSetID   = "EquipSetID",
    essenceID        = "EssenceID",
    conduitID        = "ConduitID",
    outfitID         = "OutfitID",
    macroID          = "MacroID",
    objectID         = "ObjectID",
    abilityID       = "AbilityID",
    areaPoiID       = "AreaPoiID",
    artifactPowerID = "ArtifactPowerID",
    bonusID         = "BonusID",
    companionID     = "CompanionID",
    criteriaID      = "CriteriaID",
    gemID           = "GemID",
    sourceID        = "SourceID",
    talentID        = "TalentID",
    traitDefinitionID = "TraitDefinitionID",
    traitEntryID    = "TraitEntryID",
    traitNodeID     = "TraitNodeID",
    vignetteID      = "VignetteID",
    visualID        = "VisualID",
}

local ID_ORDER = {
    "itemID", "spellID", "npcID", "achievementID", "questID",
    "currencyID", "mountID", "petID",
    "enchantID", "iconID", "expansionID", "setID",
    "decorEntryID", "recipeID", "equipmentSetID",
    "essenceID", "conduitID", "outfitID", "macroID", "objectID",
    "abilityID", "areaPoiID", "artifactPowerID", "bonusID", "companionID",
    "criteriaID", "gemID", "sourceID", "talentID",
    "traitDefinitionID", "traitEntryID", "traitNodeID",
    "vignetteID", "visualID",
}

local EXPANSION_FALLBACKS = {
    [0]  = "Classic Era",
    [1]  = "The Burning Crusade",
    [2]  = "Wrath of the Lich King",
    [3]  = "Cataclysm",
    [4]  = "Mists of Pandaria",
    [5]  = "Warlords of Draenor",
    [6]  = "Legion",
    [7]  = "Battle for Azeroth",
    [8]  = "Shadowlands",
    [9]  = "Dragonflight",
    [10] = "The War Within",
    [11] = "Midnight",
    [12] = "The Last Titan",
}

local EXPANSION_VERSIONS = {
    [0] = "v1", [1] = "v2", [2] = "v3", [3] = "v4", [4] = "v5",
    [5] = "v6", [6] = "v7", [7] = "v8", [8] = "v9", [9] = "v10",
    [10] = "v11", [11] = "v12", [12] = "v13",
}

local function GetExpansionName(id)
    return _G["EXPANSION_NAME" .. id] or EXPANSION_FALLBACKS[id]
end

local function GetExpansionVersion(id)
    return EXPANSION_VERSIONS[id]
end

local GetItemLinkByGUID = C_Item and C_Item.GetItemLinkByGUID
local GetItemGem = C_Item and C_Item.GetItemGem

local function ExtractItemIDs(itemID, tooltip, data, itemLinkFromTooltip)
    local detectedIDs = {}

    if itemID then
        detectedIDs.itemID = itemID
    end

    -- Prefer GetItemLinkByGUID when we have data.guid (equipped, inventory).
    -- Fall back to tooltip:GetItem() link for vendor, quest preview, etc.
    local itemLink = itemLinkFromTooltip
    if data and data.guid and GetItemLinkByGUID then
        local guidLink = GetItemLinkByGUID(data.guid)
        if guidLink then
            itemLink = guidLink
        end
    end

    if itemLink then
        local itemString = string.match(itemLink, "item:([%-?%d:]+)")
        if itemString then
            local itemSplit = { strsplit(":", itemString) }
            if itemSplit[2] and tonumber(itemSplit[2]) and tonumber(itemSplit[2]) ~= 0 then
                detectedIDs.enchantID = tonumber(itemSplit[2])
            end
            -- BonusID: index 13 = count, indices 14..13+count = IDs
            local bonusCount = itemSplit[13] and tonumber(itemSplit[13])
            if bonusCount and bonusCount > 0 then
                local bonuses = {}
                for i = 1, bonusCount do
                    local bid = itemSplit[13 + i] and tonumber(itemSplit[13 + i])
                    if bid then
                        table.insert(bonuses, bid)
                    end
                end
                if #bonuses > 0 then
                    detectedIDs.bonusID = bonuses
                end
            end
        end

        -- GemID from C_Item.GetItemGem (returns itemName, itemLink)
        if GetItemGem then
            local gems = {}
            for i = 1, 4 do
                local _, gemLink = GetItemGem(itemLink, i)
                if gemLink then
                    local gemID = tonumber(string.match(gemLink, "item:(%d+)"))
                    if gemID then
                        table.insert(gems, gemID)
                    end
                end
            end
            if #gems > 0 then
                detectedIDs.gemID = gems
            end
        end

        local expansionID = select(15, C_Item.GetItemInfo(itemID))
        if expansionID and expansionID ~= 254 then
            detectedIDs.expansionID = expansionID
        end

        local setID = select(16, C_Item.GetItemInfo(itemID))
        if setID and setID ~= 0 then
            detectedIDs.setID = setID
        end
    end

    local iconID = C_Item.GetItemIconByID(itemID)
    if iconID then
        detectedIDs.iconID = iconID
    end

    local _, spellID = C_Item.GetItemSpell(itemID)
    if spellID then
        detectedIDs.spellID = spellID
    end

    local housingCatalogEntryInfo = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, false)

    if housingCatalogEntryInfo and housingCatalogEntryInfo.entryID then
        detectedIDs.decorEntryID = housingCatalogEntryInfo.entryID.recordID
    end

    return detectedIDs
end

local function FormatIDLine(idKey, idValue)
    local label = ID_LABELS[idKey] or idKey

    if type(idValue) == "table" then
        return {
            type = "double",
            left  = string.format("  |cFFFFDD00%s|r", label),
            right = string.format("|cFFFFFFFF%s|r", table.concat(idValue, ", ")),
            lr = 1, lg = 1, lb = 1, rr = 1, rg = 1, rb = 1,
        }
    end

    if idKey == "expansionID" then
        local expName = GetExpansionName(idValue)
        local expVersion = GetExpansionVersion(idValue)
        if expName then
            return {
                type = "double",
                left  = string.format("  |cFFFFDD00%s|r  |cFF6699FF%s|r |cFFB3B3B3(%s)|r", label, expName, expVersion or ""),
                right = string.format("|cFFFFFFFF%d|r", idValue),
                lr = 1, lg = 1, lb = 1,
                rr = 1, rg = 1, rb = 1,
            }
        end
    end

    local rightFmt = (type(idValue) == "number") and ("|cFFFFFFFF%d|r") or ("|cFFFFFFFF%s|r")
    return {
        type = "double",
        left  = string.format("  |cFFFFDD00%s|r", label),
        right = string.format(rightFmt, idValue),
        lr = 1, lg = 1, lb = 1,
        rr = 1, rg = 1, rb = 1,
    }
end

local ID_SETTING_KEYS = {
    itemID           = "showItemID",
    spellID          = "showSpellID",
    npcID            = "showNpcID",
    achievementID    = "showAchievementID",
    questID          = "showQuestID",
    currencyID       = "showCurrencyID",
    mountID          = "showMountID",
    petID            = "showPetID",
    enchantID        = "showEnchantID",
    iconID           = "showIconID",
    expansionID      = "showExpansionID",
    setID            = "showSetID",
    decorEntryID     = "showDecorEntryID",
    recipeID         = "showRecipeID",
    equipmentSetID   = "showEquipmentSetID",
    essenceID        = "showEssenceID",
    conduitID        = "showConduitID",
    outfitID         = "showOutfitID",
    macroID          = "showMacroID",
    objectID         = "showObjectID",
    abilityID       = "showAbilityID",
    areaPoiID       = "showAreaPoiID",
    artifactPowerID = "showArtifactPowerID",
    bonusID         = "showBonusID",
    companionID     = "showCompanionID",
    criteriaID      = "showCriteriaID",
    gemID           = "showGemID",
    sourceID        = "showSourceID",
    talentID        = "showTalentID",
    traitDefinitionID = "showTraitDefinitionID",
    traitEntryID    = "showTraitEntryID",
    traitNodeID     = "showTraitNodeID",
    vignetteID      = "showVignetteID",
    visualID        = "showVisualID",
}

local function IsIDEnabled(idKey)
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local tid = db and db.tooltips and db.tooltips.technicalids
    if not tid then return true end
    local settingKey = ID_SETTING_KEYS[idKey]
    if not settingKey then return true end
    if tid[settingKey] == nil then return true end
    return tid[settingKey] == true
end

local function TechnicalIDsProvider(tooltip, context)
    local detectedIDs = {}

    if context.type == "item" and context.itemID then
        detectedIDs = ExtractItemIDs(context.itemID, tooltip, context.data, context.itemLink)

    elseif context.type == "unit" then
        if context.npcID then
            detectedIDs.npcID = context.npcID
        end

    elseif context.type == "spell" and context.spellID then
        -- Skip for talent tooltips; the SetTooltipInternal hook adds everything
        -- so our IDs aren't split by game lines ("Right click to unlearn", etc.)
        local owner = tooltip and tooltip.GetOwner and tooltip:GetOwner()
        local focus = GetMouseFocus and GetMouseFocus()
        local check = owner or focus
        if check and (check.entryID or check.definitionID) then
            return nil
        end
        detectedIDs.spellID = context.spellID
        if C_Spell and C_Spell.GetSpellTexture then
            local iconID = C_Spell.GetSpellTexture(context.spellID)
            if iconID then detectedIDs.iconID = iconID end
        end

    elseif context.type == "mount" and context.mountID then
        detectedIDs.mountID = context.mountID
        if C_MountJournal and C_MountJournal.GetMountInfoByID then
            local _, spellID, iconID = C_MountJournal.GetMountInfoByID(context.mountID)
            if spellID then detectedIDs.spellID = spellID end
            if iconID then detectedIDs.iconID = iconID end
        end

    elseif context.type == "currency" and context.currencyID then
        detectedIDs.currencyID = context.currencyID
    elseif context.type == "pet" and context.petID then
        detectedIDs.petID = context.petID
        if C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
            local iconID = select(2, C_PetJournal.GetPetInfoBySpeciesID(context.petID))
            if iconID then detectedIDs.iconID = iconID end
            local npcID = select(4, C_PetJournal.GetPetInfoBySpeciesID(context.petID))
            if npcID then detectedIDs.npcID = npcID end
        end

    elseif context.type == "achievement" and context.achievementID then
        detectedIDs.achievementID = context.achievementID
        if GetAchievementInfo then
            local iconID = select(10, GetAchievementInfo(context.achievementID))
            if iconID then detectedIDs.iconID = iconID end
        end

    elseif context.type == "quest" and context.questID then
        detectedIDs.questID = context.questID

    elseif context.type == "toy" and context.itemID then
        detectedIDs = ExtractItemIDs(context.itemID, tooltip, context.data)

    elseif context.type == "unitaura" and context.spellID then
        detectedIDs.spellID = context.spellID
        if C_Spell and C_Spell.GetSpellTexture then
            local iconID = C_Spell.GetSpellTexture(context.spellID)
            if iconID then detectedIDs.iconID = iconID end
        end

    elseif context.type == "companionpet" and context.petID then
        detectedIDs.petID = context.petID
        if C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
            local iconID = select(2, C_PetJournal.GetPetInfoBySpeciesID(context.petID))
            if iconID then detectedIDs.iconID = iconID end
            local npcID = select(4, C_PetJournal.GetPetInfoBySpeciesID(context.petID))
            if npcID then detectedIDs.npcID = npcID end
        end

    elseif context.type == "totem" and context.spellID then
        detectedIDs.spellID = context.spellID
        if C_Spell and C_Spell.GetSpellTexture then
            local iconID = C_Spell.GetSpellTexture(context.spellID)
            if iconID then detectedIDs.iconID = iconID end
        end

    elseif context.type == "questpartyprogress" and context.questID then
        detectedIDs.questID = context.questID

    elseif context.type == "recipe" and context.recipeID then
        detectedIDs.recipeID = context.recipeID
        if C_Spell and C_Spell.GetSpellTexture then
            local iconID = C_Spell.GetSpellTexture(context.recipeID)
            if iconID then detectedIDs.iconID = iconID end
        end

    elseif context.type == "equipmentset" and context.equipmentSetID then
        detectedIDs.equipmentSetID = context.equipmentSetID

    elseif context.type == "azeriteessence" and context.essenceID then
        detectedIDs.essenceID = context.essenceID
        if C_Spell and C_Spell.GetSpellTexture then
            local spellID = C_AzeriteEssence and C_AzeriteEssence.GetEssenceSpell and C_AzeriteEssence.GetEssenceSpell(context.essenceID)
            if spellID then
                detectedIDs.spellID = spellID
                local iconID = C_Spell.GetSpellTexture(spellID)
                if iconID then detectedIDs.iconID = iconID end
            end
        end

    elseif context.type == "conduit" and context.conduitID then
        detectedIDs.conduitID = context.conduitID

        local spellID = C_Soulbinds.GetConduitSpellID(context.conduitID, C_Soulbinds.GetConduitRank(context.conduitID))
        if spellID then
            detectedIDs.spellID = spellID
            local iconID = C_Spell.GetSpellTexture(spellID)
            if iconID then detectedIDs.iconID = iconID end
        end

    elseif context.type == "outfit" and context.outfitID then
        detectedIDs.outfitID = context.outfitID

    elseif context.type == "macro" and context.macroID then
        detectedIDs.macroID = context.macroID
        local _, iconID = GetMacroInfo(context.macroID)
        if iconID then detectedIDs.iconID = iconID end
        if tooltip and tooltip.GetSpell then
            local _, spellID = tooltip:GetSpell()
            if spellID then detectedIDs.spellID = spellID end
        end
        if not detectedIDs.spellID and tooltip and tooltip.GetPrimaryTooltipData then
            local data = tooltip:GetPrimaryTooltipData()
            if data and data.lines and data.lines[1] and data.lines[1].tooltipID then
                detectedIDs.spellID = data.lines[1].tooltipID
            end
        end

    elseif context.type == "object" and context.objectID then
        detectedIDs.objectID = context.objectID
    end

    local lines = {}
    for _, idKey in ipairs(ID_ORDER) do
        local idValue = detectedIDs[idKey]
        if idValue and IsIDEnabled(idKey) then
            table.insert(lines, FormatIDLine(idKey, idValue))
        end
    end

    if #lines == 0 then return nil end
    return lines
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "technicalids",
    order = 900,
    featureId = "technicalids",
    callback = TechnicalIDsProvider,
})

-- Hook layer for IDs that don't come from TooltipDataProcessor
local TOOLTIP_CONFIG = OneWoW.TooltipEngine and OneWoW.TooltipEngine.TOOLTIP_CONFIG or {}

local function AddHookIDBlock(tooltip, idPairs)
    if not OneWoW.TooltipEngine or not OneWoW.TooltipEngine:IsEnabled() then return end
    if not OneWoW.TooltipEngine:IsFeatureEnabled("technicalids") then return end
    if not tooltip or not tooltip.AddDoubleLine then return end

    local lines = {}
    for _, idKey in ipairs(ID_ORDER) do
        local idValue = idPairs[idKey]
        if idValue and IsIDEnabled(idKey) then
            table.insert(lines, FormatIDLine(idKey, idValue))
        end
    end
    if #lines == 0 then return end

    local hasSection = OneWoW.TooltipEngine:TooltipHasOneWoWSection(tooltip)
    if not hasSection then
        tooltip:AddLine(" ")
        local _gui = LibStub and LibStub("OneWoW_GUI-1.0", true)
        local iconTheme = (_gui and _gui:GetSetting("minimap.theme")) or "neutral"
        local addonIcon = CreateTextureMarkup("Interface\\AddOns\\OneWoW\\Media\\OneWoWMini-" .. iconTheme, 64, 64, 16, 16, 0, 1, 0, 1)
        local hc = TOOLTIP_CONFIG.headerColor or {0.2, 1.0, 0.2}
        tooltip:AddLine(addonIcon .. " OneWoW", hc[1], hc[2], hc[3])
    end

    for _, line in ipairs(lines) do
        if line.type == "double" then
            tooltip:AddDoubleLine(
                line.left, line.right,
                line.lr or 0.9, line.lg or 0.9, line.lb or 0.9,
                line.rr or 1, line.rg or 1, line.rb or 1
            )
        end
    end

    tooltip:Show()
end

local function hook(tableOrGlobal, fn, cb)
    if not tableOrGlobal or not fn then return end
    local target = type(tableOrGlobal) == "string" and _G[tableOrGlobal] or tableOrGlobal
    if target and target[fn] then
        hooksecurefunc(target, fn, cb)
    end
end

-- Defer talent/trait tooltip additions so our lines appear after the game's
-- ("Right click to unlearn", "Click to learn", etc.) instead of being split.
-- When addSpellFromTooltip is true, fetches spellID from tooltip:GetSpell() in the callback.
local function AddHookIDBlockDeferred(tooltip, idPairs, addSpellFromTooltip)
    C_Timer.After(0, function()
        if tooltip and tooltip:IsVisible() then
            if addSpellFromTooltip and tooltip.GetSpell then
                local _, spellID = tooltip:GetSpell()
                if spellID then
                    idPairs = idPairs or {}
                    idPairs.spellID = spellID
                end
            end
            AddHookIDBlock(tooltip, idPairs)
        end
    end)
end

-- Talents
if GetTalentInfoByID then
    hook(GameTooltip, "SetTalent", function(tooltip, id)
        if not id then return end
        local ok, result = pcall(GetTalentInfoByID, id)
        if not ok then return end
        local spellID = result and select(6, result)
        AddHookIDBlockDeferred(tooltip, { talentID = id, spellID = spellID })
    end)
end
if GetPvpTalentInfoByID then
    hook(GameTooltip, "SetPvpTalent", function(tooltip, id)
        if not id then return end
        local spellID = select(6, GetPvpTalentInfoByID(id))
        AddHookIDBlockDeferred(tooltip, { talentID = id, spellID = spellID })
    end)
end

-- Traits (TalentDisplayMixin.SetTooltipInternal)
if TalentDisplayMixin then
    hooksecurefunc(TalentDisplayMixin, "SetTooltipInternal", function(btn)
        if not btn then return end
        local ids = {}
        if btn.entryID then ids.traitEntryID = btn.entryID end
        if btn.definitionID then ids.traitDefinitionID = btn.definitionID end
        if btn.GetNodeInfo then
            local nodeInfo = btn:GetNodeInfo()
            if nodeInfo and nodeInfo.ID then ids.traitNodeID = nodeInfo.ID end
        end
        if next(ids) then
            AddHookIDBlockDeferred(GameTooltip, ids, true)
        end
    end)
end

-- Map pins
if AreaPOIPinMixin then
    hook(AreaPOIPinMixin, "TryShowTooltip", function(pin)
        if pin and pin.areaPoiID then
            AddHookIDBlock(GameTooltip, { areaPoiID = pin.areaPoiID })
        end
    end)
end
if VignettePinMixin then
    hook(VignettePinMixin, "OnMouseEnter", function(pin)
        if pin and pin.vignetteInfo and pin.vignetteInfo.vignetteID then
            AddHookIDBlock(GameTooltip, { vignetteID = pin.vignetteInfo.vignetteID })
        end
    end)
end

-- Quest list (side of map) and quest POIs on map
if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
    hook(_G, "QuestMapLogTitleButton_OnEnter", function(btn)
        if btn and btn.questLogIndex then
            local questID = C_QuestLog.GetQuestIDForLogIndex(btn.questLogIndex)
            if questID then
                AddHookIDBlock(GameTooltip, { questID = questID })
            end
        end
    end)
end
hook(_G, "TaskPOI_OnEnter", function(btn)
    if btn and btn.questID then
        AddHookIDBlock(GameTooltip, { questID = btn.questID })
    end
end)

-- Companion pet (SetCompanionPet = pet instance ID)
if C_PetJournal and C_PetJournal.GetPetInfoByPetID then
    hook(GameTooltip, "SetCompanionPet", function(tooltip, petId)
        if not petId then return end
        local speciesId = select(1, C_PetJournal.GetPetInfoByPetID(petId))
        local ids = { companionID = petId }
        if speciesId and C_PetJournal.GetPetInfoBySpeciesID then
            ids.petID = speciesId
            local _, iconID, _, npcID = C_PetJournal.GetPetInfoBySpeciesID(speciesId)
            if npcID then ids.npcID = npcID end
            if iconID then ids.iconID = iconID end
        end
        AddHookIDBlock(tooltip, ids)
    end)
end

-- Action bar: pets/macros on action bar (GetActionInfo returns type, id)
if GetActionInfo then
    hook(GameTooltip, "SetAction", function(tooltip, slot)
        local actionType, id = GetActionInfo(slot)
        if not id then return end
        if actionType == "companion" then
            local ids = { companionID = id }
            if C_PetJournal and C_PetJournal.GetPetInfoBySpeciesID then
                ids.petID = id
                local _, iconID, _, npcID = C_PetJournal.GetPetInfoBySpeciesID(id)
                if npcID then ids.npcID = npcID end
                if iconID then ids.iconID = iconID end
            end
            AddHookIDBlock(tooltip, ids)
        end
    end)
end

-- Artifact
if C_ArtifactUI and C_ArtifactUI.GetPowerInfo then
    hook(GameTooltip, "SetArtifactPowerByID", function(tooltip, powerID)
        if not powerID then return end
        local powerInfo = C_ArtifactUI.GetPowerInfo(powerID)
        local ids = { artifactPowerID = powerID }
        if powerInfo and powerInfo.spellID then ids.spellID = powerInfo.spellID end
        AddHookIDBlock(tooltip, ids)
    end)
end

-- Wardrobe (Blizzard_Collections)
local function hookWardrobe()
    if not CollectionWardrobeUtil or not CollectionWardrobeUtil.SetAppearanceTooltip then return end
    hooksecurefunc(CollectionWardrobeUtil, "SetAppearanceTooltip", function(frame, sources)
        if not sources or #sources == 0 then return end
        local visualIDs, sourceIDs, itemIDs = {}, {}, {}
        for i = 1, #sources do
            if sources[i].visualID and not tContains(visualIDs, sources[i].visualID) then
                table.insert(visualIDs, sources[i].visualID)
            end
            if sources[i].sourceID and not tContains(sourceIDs, sources[i].sourceID) then
                table.insert(sourceIDs, sources[i].sourceID)
            end
            if sources[i].itemID and not tContains(itemIDs, sources[i].itemID) then
                table.insert(itemIDs, sources[i].itemID)
            end
        end
        local ids = {}
        if #visualIDs == 1 then ids.visualID = visualIDs[1]
        elseif #visualIDs > 1 then ids.visualID = visualIDs end
        if #sourceIDs == 1 then ids.sourceID = sourceIDs[1]
        elseif #sourceIDs > 1 then ids.sourceID = sourceIDs end
        if #itemIDs == 1 then ids.itemID = itemIDs[1]
        elseif #itemIDs > 1 then ids.itemID = itemIDs end
        if next(ids) then AddHookIDBlock(GameTooltip, ids) end
    end)
end
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
    hookWardrobe()
else
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, _, addon)
        if addon == "Blizzard_Collections" then
            hookWardrobe()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- Achievement criteria (Blizzard_AchievementUI)
local function hookAchievementCriteria()
    if not AchievementTemplateMixin then return end
    local objectiveFrame = AchievementTemplateMixin.GetObjectiveFrame and AchievementTemplateMixin:GetObjectiveFrame()
    if not objectiveFrame then return end
    local hooked = {}
    local function hookCriteria(index)
        return function(criteriaFrame)
            if not criteriaFrame or hooked[criteriaFrame] then return end
            hooked[criteriaFrame] = true
            criteriaFrame.___index = index
            criteriaFrame:HookScript("OnEnter", function()
                local btn = criteriaFrame:GetParent() and criteriaFrame:GetParent():GetParent()
                if not btn or not btn.id then return end
                local achievementId = btn.id
                local idx = criteriaFrame.___index or index
                if GetAchievementNumCriteria and idx > GetAchievementNumCriteria(achievementId) then return end
                local criteriaId = GetAchievementCriteriaInfo and select(10, GetAchievementCriteriaInfo(achievementId, idx))
                if criteriaId then
                    if not GameTooltip:IsVisible() then
                        GameTooltip:SetOwner(btn:GetParent(), "ANCHOR_NONE")
                    end
                    GameTooltip:SetPoint("TOPLEFT", btn, "TOPRIGHT", 0, 0)
                    AddHookIDBlock(GameTooltip, { achievementID = achievementId, criteriaID = criteriaId })
                end
            end)
            criteriaFrame:HookScript("OnLeave", GameTooltip_Hide)
        end
    end
    if objectiveFrame.GetCriteria then
        hooksecurefunc(objectiveFrame, "GetCriteria", function(self, idx)
            local frame = self.criterias and self.criterias[idx]
            if frame then hookCriteria(idx)(frame) end
        end)
    end
    if objectiveFrame.GetMiniAchievement then
        hooksecurefunc(objectiveFrame, "GetMiniAchievement", function(self, idx)
            local frame = self.miniAchivements and self.miniAchivements[idx]
            if frame then hookCriteria(idx)(frame) end
        end)
    end
    if objectiveFrame.GetMeta then
        hooksecurefunc(objectiveFrame, "GetMeta", function(self, idx)
            local frame = self.metas and self.metas[idx]
            if frame then hookCriteria(idx)(frame) end
        end)
    end
    if objectiveFrame.GetProgressBar then
        hooksecurefunc(objectiveFrame, "GetProgressBar", function(self, idx)
            local frame = self.progressBars and self.progressBars[idx]
            if frame then hookCriteria(idx)(frame) end
        end)
    end
end
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_AchievementUI") then
    hookAchievementCriteria()
else
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, _, addon)
        if addon == "Blizzard_AchievementUI" then
            hookAchievementCriteria()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end)
end

-- AbilityID (Pet battles, Garrison)
if C_PetBattles and C_PetBattles.GetAbilityInfo then
    hook(_G, "PetBattleAbilityButton_OnEnter", function(btn)
        if not btn or btn:GetEffectiveAlpha() <= 0 then return end
        local petIndex = C_PetBattles.GetActivePet and C_PetBattles.GetActivePet(LE_BATTLE_PET_ALLY)
        if not petIndex then return end
        local id = select(1, C_PetBattles.GetAbilityInfo(LE_BATTLE_PET_ALLY, petIndex, btn:GetID()))
        if id then AddHookIDBlock(PetBattlePrimaryAbilityTooltip or GameTooltip, { abilityID = id }) end
    end)
end
local function hookGarrisonAbility()
    if AddAutoCombatSpellToTooltip then
        hook(_G, "AddAutoCombatSpellToTooltip", function(tooltip, info)
            if info and info.autoCombatSpellID then
                AddHookIDBlock(tooltip or GameTooltip, { abilityID = info.autoCombatSpellID })
            end
        end)
    end
end
if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_GarrisonUI") then
    hookGarrisonAbility()
else
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("ADDON_LOADED")
    frame:SetScript("OnEvent", function(_, _, addon)
        if addon == "Blizzard_GarrisonUI" then
            hookGarrisonAbility()
            frame:UnregisterEvent("ADDON_LOADED")
        end
    end)
end
