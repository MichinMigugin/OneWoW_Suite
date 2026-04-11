local ADDON_NAME, OneWoW = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

local function FormatMoneyLine(copper)
    if OneWoW_GUI and OneWoW_GUI.FormatGold then
        return OneWoW_GUI:FormatGold(copper)
    end
    return GetCoinTextureString(copper)
end

local BATTLE_PET_CAGE_ID = 82800

local PET_TYPE_FALLBACKS = {
    [1]  = "Humanoid",
    [2]  = "Dragonkin",
    [3]  = "Flying",
    [4]  = "Undead",
    [5]  = "Critter",
    [6]  = "Magic",
    [7]  = "Elemental",
    [8]  = "Beast",
    [9]  = "Aquatic",
    [10] = "Mechanical",
}

local function GetPetTypeName(petType)
    return _G["BATTLE_PET_NAME_" .. petType] or PET_TYPE_FALLBACKS[petType] or "Unknown"
end

local function GetPetSettings()
    local db = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    return db and db.tooltips and db.tooltips.pets or {}
end

local function IsEnabled()
    if not OneWoW.TooltipEngine:IsEnabled() then return false end
    return OneWoW.SettingsFeatureRegistry:IsEnabled("tooltips", "pets")
end

local function GetVendorPrice()
    local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(BATTLE_PET_CAGE_ID)
    return sellPrice or 0
end

local function GetAHPrice()
    local db = _G.OneWoW_AHPrices
    if not db then return nil end
    return db[BATTLE_PET_CAGE_ID]
end

local function FormatAge(timestamp)
    if not timestamp or timestamp == 0 then return nil end
    local age = time() - timestamp
    local L = OneWoW.L
    if age < 3600 then
        return string.format(L["TIPS_TIME_MINUTES_AGO"] or "%dm ago", math.floor(age / 60))
    elseif age < 86400 then
        return string.format(L["TIPS_TIME_HOURS_AGO"] or "%dh ago", math.floor(age / 3600))
    else
        return string.format(L["TIPS_TIME_DAYS_AGO"] or "%dd ago", math.floor(age / 86400))
    end
end

local function PrepareShoppingTooltip(owner)
    local shoppingTooltips = GameTooltip.shoppingTooltips
    if not shoppingTooltips or not shoppingTooltips[1] then return nil end

    local tip = shoppingTooltips[1]
    tip:SetOwner(owner, "ANCHOR_NONE")
    tip:ClearLines()

    local leftPos = owner:GetLeft() or 0
    local rightPos = owner:GetRight() or 0
    if GetScreenWidth() - rightPos < leftPos then
        tip:SetPoint("TOPRIGHT", owner, "TOPLEFT", 0, -10)
    else
        tip:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, -10)
    end

    return tip
end

local function FillPetTooltip(tip, speciesID)
    if not speciesID or speciesID == 0 then return false end

    local cfg = GetPetSettings()
    local L = OneWoW.L
    local TOOLTIP_CONFIG = OneWoW.TooltipEngine.TOOLTIP_CONFIG

    local name, icon, petType, _, tooltipSource, tooltipDescription, _, canBattle, isTradeable, isUnique =
        C_PetJournal.GetPetInfoBySpeciesID(speciesID)
    if not name then return false end

    local numCollected, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
    local hasLines = false

    local _gui = LibStub and LibStub("OneWoW_GUI-1.0", true)
    local iconTheme = (_gui and _gui:GetSetting("minimap.theme")) or "neutral"
    local addonIcon = CreateTextureMarkup("Interface\\AddOns\\OneWoW\\Media\\OneWoWMini-" .. iconTheme, 64, 64, 16, 16, 0, 1, 0, 1)

    local battlePetsLabel = AUCTION_CATEGORY_BATTLE_PETS or "Battle Pets"

    if cfg.showCollectionStatus ~= false and numCollected ~= nil then
        local collected = numCollected > 0
        local statusText
        if collected then
            statusText = string.format("|cFF66CC66%s|r | %s", L["TIPS_COLLECTIONS_COLLECTED"] or "Collected", battlePetsLabel)
        else
            statusText = string.format("|cFFCC6666%s|r | %s", L["TIPS_COLLECTIONS_NOT_COLLECTED"] or "Not Collected", battlePetsLabel)
        end
        tip:AddDoubleLine(
            addonIcon .. " OneWoW",
            statusText,
            TOOLTIP_CONFIG.headerColor[1], TOOLTIP_CONFIG.headerColor[2], TOOLTIP_CONFIG.headerColor[3],
            0.9, 0.9, 0.9
        )
    else
        tip:AddDoubleLine(
            addonIcon .. " OneWoW",
            battlePetsLabel,
            TOOLTIP_CONFIG.headerColor[1], TOOLTIP_CONFIG.headerColor[2], TOOLTIP_CONFIG.headerColor[3],
            0.9, 0.8, 0.4
        )
    end
    hasLines = true

    if cfg.showPetInfo ~= false then
        local typeName = GetPetTypeName(petType)
        tip:AddDoubleLine(
            "  " .. (L["TIPS_PETS_TYPE"] or "Type"),
            typeName,
            0.4, 0.8, 1.0,
            1.0, 1.0, 1.0
        )

        local traits = {}
        if canBattle then table.insert(traits, L["TIPS_PETS_CAN_BATTLE"] or "Can Battle") end
        if isTradeable then table.insert(traits, L["TIPS_PETS_TRADEABLE"] or "Tradeable") end
        if isUnique then table.insert(traits, L["TIPS_PETS_UNIQUE"] or "Unique") end
        if #traits > 0 then
            tip:AddLine("  " .. table.concat(traits, " | "), 0.7, 0.7, 0.7)
        end
    end

    if cfg.showCollectionStatus ~= false and numCollected ~= nil then
        local countColor
        if numCollected > 0 then
            countColor = {0.4, 0.8, 0.4}
        else
            countColor = {0.8, 0.4, 0.4}
        end
        tip:AddDoubleLine(
            "  " .. (L["TIPS_PETS_OWNED"] or "Owned"),
            string.format("%d / %d", numCollected, limit or 3),
            0.4, 0.8, 1.0,
            countColor[1], countColor[2], countColor[3]
        )
    end

    if cfg.showSource ~= false and tooltipSource and tooltipSource ~= "" then
        tip:AddLine("  " .. (L["TIPS_PETS_SOURCE"] or "Source") .. ": |cFFFFFFFF" .. tooltipSource .. "|r", 0.4, 0.8, 1.0)
    end

    if cfg.showDescription ~= false and tooltipDescription and tooltipDescription ~= "" then
        tip:AddLine(" ")
        tip:AddLine("  " .. tooltipDescription, 0.6, 0.6, 0.6, true)
    end

    if cfg.showValue ~= false then
        local sellPrice = GetVendorPrice()
        if sellPrice and sellPrice > 0 then
            tip:AddDoubleLine(
                "  " .. (L["TIPS_VALUE_VENDOR_PRICE"] or "Vendor Price"),
                FormatMoneyLine(sellPrice),
                0.4, 0.8, 1.0,
                1.0, 1.0, 1.0
            )
        end
    end

    if cfg.showAHValue ~= false then
        local ahPrice, meta
        if OneWoW.ItemPrices then
            ahPrice, meta = OneWoW.ItemPrices:GetUnitAHPriceForSpecies(speciesID, name)
        else
            local ahData = GetAHPrice()
            if ahData and ahData.price and ahData.price > 0 then
                ahPrice = ahData.price
                meta = { source = "onewow", timestamp = ahData.timestamp }
            end
        end
        if ahPrice and ahPrice > 0 then
            local ageText
            if meta and meta.timestamp then
                ageText = FormatAge(meta.timestamp)
            elseif meta and meta.ageDays ~= nil then
                ageText = string.format(L["TIPS_VALUE_AH_AGE_DAYS"] or "%d d ago", meta.ageDays)
            end
            local rightText = FormatMoneyLine(ahPrice)
            if ageText then
                rightText = rightText .. "  |cFF888888(" .. ageText .. ")|r"
            end
            local leftAH = L["TIPS_VALUE_AH_PRICE"] or "AH Price"
            if meta and meta.source == "auctionator" then
                leftAH = L["TIPS_VALUE_AH_PRICE_AUCTIONATOR"] or leftAH
            end
            tip:AddDoubleLine("  " .. leftAH, rightText, 0.4, 0.8, 1.0, 1.0, 1.0, 1.0)
        end
    end

    local valCfg = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings and OneWoW.db.global.settings.tooltips and OneWoW.db.global.settings.tooltips.value
    if valCfg and valCfg.showTSMValue == true and OneWoW.ItemPrices then
        local tsmPrice, srcStr = OneWoW.ItemPrices:GetTSMUnitPriceForSpecies(speciesID, name)
        if tsmPrice and tsmPrice > 0 then
            local tsmRight = FormatMoneyLine(tsmPrice)
            local leftT = L["TIPS_VALUE_TSM_PRICE"] or "TSM"
            if srcStr and srcStr ~= "" then
                leftT = string.format(L["TIPS_VALUE_TSM_PRICE_FMT"] or "TSM (%s)", srcStr)
            end
            tip:AddDoubleLine("  " .. leftT, tsmRight, 0.4, 0.8, 1.0, 1.0, 1.0, 1.0)
        end
    end

    if cfg.showItemStatus ~= false and OneWoW.ItemStatus then
        if OneWoW.ItemStatus:IsItemProtected(BATTLE_PET_CAGE_ID) then
            tip:AddLine(
                L["ITEMSTATUS_TOOLTIP_PROTECTED"] or "Protected Item",
                TOOLTIP_CONFIG.protectedColor[1], TOOLTIP_CONFIG.protectedColor[2], TOOLTIP_CONFIG.protectedColor[3]
            )
        end
        if OneWoW.ItemStatus:IsItemJunk(BATTLE_PET_CAGE_ID) then
            tip:AddLine(
                L["ITEMSTATUS_TOOLTIP_JUNK"] or "Junk Item",
                TOOLTIP_CONFIG.junkColor[1], TOOLTIP_CONFIG.junkColor[2], TOOLTIP_CONFIG.junkColor[3]
            )
        end
    end

    if cfg.showTechnicalIDs ~= false then
        tip:AddLine(" ")
        tip:AddLine(
            string.format("  |cFFFFDD00SpeciesID|r |cFFFFFFFF%d|r  |cFFFFDD00ItemID|r |cFFFFFFFF%d|r", speciesID, BATTLE_PET_CAGE_ID),
            1, 1, 1
        )
    end

    return hasLines
end

local function UpdateBattlePetTooltip(tooltip)
    if not tooltip.owOnUpdateHooked then
        tooltip.owOnUpdateHooked = true
        tooltip:HookScript("OnUpdate", UpdateBattlePetTooltip)
    end

    if not tooltip:IsShown() then return end
    if not IsEnabled() then
        local shoppingTooltips = GameTooltip.shoppingTooltips
        if shoppingTooltips and shoppingTooltips[1] and shoppingTooltips[1]:IsShown() then
            shoppingTooltips[1]:Hide()
        end
        return
    end

    local speciesID = tooltip.owSpeciesID
    if not speciesID then return end

    local tip = PrepareShoppingTooltip(tooltip)
    if not tip then return end

    local ok = FillPetTooltip(tip, speciesID)
    if ok then
        tip:Show()
    else
        tip:Hide()
    end
end

if BattlePetTooltip then
    hooksecurefunc("BattlePetTooltipTemplate_SetBattlePet", function(tooltip, data)
        if data and data.speciesID then
            tooltip.owSpeciesID = data.speciesID
            C_Timer.After(0.01, function()
                UpdateBattlePetTooltip(tooltip)
            end)
        end
    end)

    BattlePetTooltip:HookScript("OnHide", function()
        local shoppingTooltips = GameTooltip.shoppingTooltips
        if shoppingTooltips and shoppingTooltips[1] and shoppingTooltips[1]:IsShown() then
            shoppingTooltips[1]:Hide()
        end
    end)
end
