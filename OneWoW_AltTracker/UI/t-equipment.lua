local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local currentSortColumn = nil
local currentSortAscending = true
local characterRows = {}

local enchantableSlots = {
    [1] = true,
    [3] = true,
    [5] = true,
    [7] = true,
    [8] = true,
    [9] = true,
    [11] = true,
    [12] = true,
    [15] = true,
    [16] = true,
}

local softEnchantSlots = {
    [9] = true,
    [15] = true,
}

local OFFHAND_SLOT = 17

local function IsOffHandWeaponFromLink(item)
    if not item or not item.itemID then return false end
    local _, _, _, itemEquipLoc = C_Item.GetItemInfoInstant(item.itemID)
    if not itemEquipLoc then return false end
    return itemEquipLoc == "INVTYPE_WEAPON"
        or itemEquipLoc == "INVTYPE_WEAPONOFFHAND"
        or itemEquipLoc == "INVTYPE_WEAPONMAINHAND"
        or itemEquipLoc == "INVTYPE_2HWEAPON"
end

local function IsSlotEnchantable(slotId, equipment)
    if enchantableSlots[slotId] then return true end
    if slotId == OFFHAND_SLOT and equipment then
        return IsOffHandWeaponFromLink(equipment[OFFHAND_SLOT])
    end
    return false
end

local function IsSoftEnchantSlot(slotId)
    return softEnchantSlots[slotId] or false
end

function ns.UI.CreateEquipmentTab(parent)
    local overview = OneWoW_GUI:CreateOverviewPanel(parent, {
        title = L["EQUIPMENT_OVERVIEW"],
        height = 110,
        columns = 5,
        stats = {
            {label = L["EQUIPMENT_ATTENTION"],       value = "0", ttTitle = L["TT_EQUIPMENT_ATTENTION"],       ttDesc = L["TT_EQUIPMENT_ATTENTION_DESC"]},
            {label = L["EQUIPMENT_CHARACTERS"],      value = "0", ttTitle = L["TT_EQUIPMENT_CHARACTERS"],      ttDesc = L["TT_EQUIPMENT_CHARACTERS_DESC"]},
            {label = L["EQUIPMENT_AVG_ILVL"],        value = "0", ttTitle = L["TT_EQUIPMENT_AVG_ILVL"],        ttDesc = L["TT_EQUIPMENT_AVG_ILVL_DESC"]},
            {label = L["EQUIPMENT_HIGHEST_ILVL"],    value = "0", ttTitle = L["TT_EQUIPMENT_HIGHEST_ILVL"],    ttDesc = L["TT_EQUIPMENT_HIGHEST_ILVL_DESC"]},
            {label = L["EQUIPMENT_LOWEST_ILVL"],     value = "0", ttTitle = L["TT_EQUIPMENT_LOWEST_ILVL"],     ttDesc = L["TT_EQUIPMENT_LOWEST_ILVL_DESC"]},
            {label = L["EQUIPMENT_MISSING_ENCHANTS"], value = "0", ttTitle = L["TT_EQUIPMENT_MISSING_ENCHANTS"], ttDesc = L["TT_EQUIPMENT_MISSING_ENCHANTS_DESC"]},
            {label = L["EQUIPMENT_MISSING_GEMS"],    value = "0", ttTitle = L["TT_EQUIPMENT_MISSING_GEMS"],    ttDesc = L["TT_EQUIPMENT_MISSING_GEMS_DESC"]},
            {label = L["EQUIPMENT_LOW_DURABILITY"],  value = "0", ttTitle = L["TT_EQUIPMENT_LOW_DURABILITY"],  ttDesc = L["TT_EQUIPMENT_LOW_DURABILITY_DESC"]},
            {label = L["EQUIPMENT_SET_BONUSES"],     value = "0", ttTitle = L["TT_EQUIPMENT_SET_BONUSES"],     ttDesc = L["TT_EQUIPMENT_SET_BONUSES_DESC"]},
        },
    })

    local rosterPanel = OneWoW_GUI:CreateRosterPanel(parent, overview.panel)

    local columnsConfig = {
        {key = "expand",    label = "",                          width = 25,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_EXPAND"],            ttDesc = L["TT_COL_EXPAND_DESC"]},
        {key = "star",      label = "",                          width = 30,  fixed = true,  align = "icon",   sortable = false, ttTitle = L["TT_COL_STAR"],              ttDesc = L["TT_COL_STAR_DESC"]},
        {key = "faction",   label = L["COL_FACTION"],            width = 25,  fixed = true,  align = "center", sortable = false, ttTitle = L["TT_COL_FACTION"],           ttDesc = L["TT_COL_FACTION_DESC"]},
        {key = "mail",      label = L["COL_MAIL"],               width = 35,  fixed = true,  align = "center", sortable = false, ttTitle = L["TT_COL_MAIL"],              ttDesc = L["TT_COL_MAIL_DESC"]},
        {key = "name",      label = L["COL_CHARACTER"],          width = 135, fixed = false, align = "left",                     ttTitle = L["TT_COL_CHARACTER"],         ttDesc = L["TT_COL_CHARACTER_DESC"]},
        {key = "level",     label = L["COL_LEVEL"],              width = 40,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_LEVEL"],             ttDesc = L["TT_COL_LEVEL_DESC"]},
        {key = "itemLevel", label = L["EQUIPMENT_COL_ILVL"],     width = 50,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_ILVL"],             ttDesc = L["TT_COL_ILVL_DESC"]},
        {key = "durability", label = L["EQUIPMENT_COL_DURABILITY"], width = 50, fixed = false, align = "center",                  ttTitle = L["TT_COL_DURABILITY"],       ttDesc = L["TT_COL_DURABILITY_DESC"]},
        {key = "enchants",  label = L["EQUIPMENT_COL_ENCHANTS"], width = 55,  fixed = false, align = "center",                   ttTitle = L["TT_COL_ENCHANTS"],         ttDesc = L["TT_COL_ENCHANTS_DESC"]},
        {key = "gems",      label = L["EQUIPMENT_COL_GEMS"],    width = 50,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_GEMS"],             ttDesc = L["TT_COL_GEMS_DESC"]},
        {key = "tierSet",   label = L["EQUIPMENT_COL_TIER_SET"], width = 45,  fixed = false, align = "center",                   ttTitle = L["TT_COL_TIER_SET"],         ttDesc = L["TT_COL_TIER_SET_DESC"]},
        {key = "str",       label = L["EQUIPMENT_COL_STR"],      width = 45,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_STR"],              ttDesc = L["TT_COL_STR_DESC"]},
        {key = "agi",       label = L["EQUIPMENT_COL_AGI"],      width = 45,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_AGI"],              ttDesc = L["TT_COL_AGI_DESC"]},
        {key = "sta",       label = L["EQUIPMENT_COL_STA"],      width = 45,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_STA"],              ttDesc = L["TT_COL_STA_DESC"]},
        {key = "int",       label = L["EQUIPMENT_COL_INT"],      width = 45,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_INT"],              ttDesc = L["TT_COL_INT_DESC"]},
        {key = "armor",     label = L["EQUIPMENT_COL_ARMOR"],    width = 50,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_ARMOR"],            ttDesc = L["TT_COL_ARMOR_DESC"]},
        {key = "ap",        label = L["EQUIPMENT_COL_AP"],       width = 50,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_AP"],               ttDesc = L["TT_COL_AP_DESC"]},
        {key = "crit",      label = L["EQUIPMENT_COL_CRIT"],     width = 45,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_CRIT"],             ttDesc = L["TT_COL_CRIT_DESC"]},
        {key = "haste",     label = L["EQUIPMENT_COL_HASTE"],    width = 50,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_HASTE"],            ttDesc = L["TT_COL_HASTE_DESC"]},
        {key = "mastery",   label = L["EQUIPMENT_COL_MASTERY"],  width = 60,  fixed = false, align = "center",                   ttTitle = L["TT_COL_MASTERY"],          ttDesc = L["TT_COL_MASTERY_DESC"]},
        {key = "vers",      label = L["EQUIPMENT_COL_VERS"],     width = 50,  fixed = true,  align = "center",                   ttTitle = L["TT_COL_VERS"],             ttDesc = L["TT_COL_VERS_DESC"]},
        {key = "status",    label = L["EQUIPMENT_COL_STATUS"],   width = 40,  fixed = false, align = "center",                   ttTitle = L["TT_COL_STATUS"],           ttDesc = L["TT_COL_STATUS_DESC"]}
    }

    local onHeaderCreate = function(btn, col, index)
        if col.key == "expand" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(14, 14)
            icon:SetPoint("CENTER")
            icon:SetAtlas("Gamepad_Rev_Plus_64")
            btn.icon = icon
            if btn.text then btn.text:SetText("") end
        elseif col.key == "mail" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(12, 12)
            icon:SetPoint("CENTER")
            icon:SetTexture("Interface\\Minimap\\Tracking\\Mailbox")
            btn.icon = icon
            if btn.text then btn.text:SetText("") end
        elseif col.key == "star" then
            local icon = btn:CreateTexture(nil, "ARTWORK")
            icon:SetSize(12, 12)
            icon:SetPoint("CENTER")
            OneWoW_GUI:SetFavoriteAtlasTexture(icon)
            btn.icon = icon
            if btn.text then btn.text:SetText("") end
        end
    end

    local dt
    dt = OneWoW_GUI:CreateDataTable(rosterPanel, {
        columns = columnsConfig,
        headerHeight = 26,
        rowHeight = 32,
        onHeaderCreate = onHeaderCreate,
        onSort = function(sortColumn, sortAscending)
            currentSortColumn = sortColumn
            currentSortAscending = sortAscending
            ns.UI.RefreshEquipmentTab(parent)
            C_Timer.After(0.1, function() dt.UpdateSortIndicators() end)
        end,
    })

    parent.dataTable = dt
    parent.columnsConfig = columnsConfig

    local status = OneWoW_GUI:CreateStatusBar(parent, rosterPanel, {
        text = string.format(L["CHARACTERS_TRACKED"], 0, ""),
    })

    parent.overviewPanel = overview.panel
    parent.statsContainer = overview.statsContainer
    parent.statBoxes = overview.statBoxes
    parent.rosterPanel = rosterPanel
    parent.headerRow = dt.headerRow
    parent.scrollContent = dt.scrollContent
    parent.statusBar = status.bar
    parent.statusText = status.text

    OneWoW_GUI:ApplyFontToFrame(parent)

    C_Timer.After(0.5, function()
        if ns.UI.RefreshEquipmentTab then
            ns.UI.RefreshEquipmentTab(parent)
        end
    end)

    local equipEventFrame = CreateFrame("Frame")
    equipEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    equipEventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
    equipEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
    equipEventFrame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_INVENTORY_CHANGED" and unit ~= "player" then return end
        if parent:IsVisible() and ns.UI.RefreshEquipmentTab then
            C_Timer.After(1, function()
                if parent:IsVisible() then
                    ns.UI.RefreshEquipmentTab(parent)
                end
            end)
        end
    end)
    parent:HookScript("OnHide", function()
        equipEventFrame:UnregisterAllEvents()
    end)
    parent:HookScript("OnShow", function()
        equipEventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
        equipEventFrame:RegisterEvent("PLAYER_AVG_ITEM_LEVEL_UPDATE")
        equipEventFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
        if ns.UI.RefreshEquipmentTab then
            ns.UI.RefreshEquipmentTab(parent)
        end
    end)

    if ns.UI.RegisterRosterTabFrame then
        ns.UI.RegisterRosterTabFrame("equipment", parent)
    end
end

local function GetEquipmentStats(charKey, charData)
    local equipment = (_G.OneWoW_AltTracker_Character_DB.characters[charKey] and _G.OneWoW_AltTracker_Character_DB.characters[charKey].equipment)
    local totalDurability, durabilityItems, missingEnchants, missingGems, tierCount = 0, 0, 0, 0, 0
    local hardMissingEnchants = 0
    if equipment then
        for slotId = 1, 19 do
            if slotId ~= 4 and slotId ~= 18 and slotId ~= 19 then
                local item = equipment[slotId]
                if item and item.itemLink then
                    if item.durability and item.maxDurability then
                        totalDurability = totalDurability + (item.durability / item.maxDurability * 100)
                        durabilityItems = durabilityItems + 1
                    end
                    if IsSlotEnchantable(slotId, equipment) and charData.level and charData.level >= 70 then
                        local enchantId = item.itemLink:match("item:%d+:(%d+)")
                        if not enchantId or enchantId == "0" or enchantId == "" then
                            missingEnchants = missingEnchants + 1
                            if not IsSoftEnchantSlot(slotId) then
                                hardMissingEnchants = hardMissingEnchants + 1
                            end
                        end
                    end
                    local itemSockets = item.numSockets or 0
                    missingGems = missingGems + math.max(0, itemSockets - (item.socketsWithGems or 0))
                    if item.setID and item.setID > 0 then
                        tierCount = tierCount + 1
                    end
                end
            end
        end
    end
    local durabilityPct = durabilityItems > 0 and math.floor(totalDurability / durabilityItems) or 100
    local statusScore = 0
    if durabilityPct < 30 or hardMissingEnchants >= 5 or missingGems >= 5 then
        statusScore = 2
    elseif hardMissingEnchants > 0 or missingGems > 0 or durabilityPct < 70 then
        statusScore = 1
    end
    return durabilityPct, missingEnchants, missingGems, tierCount, statusScore
end

function ns.UI.RefreshEquipmentTab(equipmentTab)
    if not equipmentTab then return end
    if not _G.OneWoW_AltTracker_Character_DB or not _G.OneWoW_AltTracker_Character_DB.characters then return end

    local allChars = ns.UI.GetSortedCharacters(function(charKey, charData, col)
        if col == "name" then
            return charData.name or ""
        elseif col == "level" then
            return charData.level or 0
        elseif col == "itemLevel" then
            return charData.itemLevel or 0
        elseif col == "durability" then
            return GetEquipmentStats(charKey, charData)
        elseif col == "enchants" then
            local _, enchants = GetEquipmentStats(charKey, charData)
            return enchants
        elseif col == "gems" then
            local _, _, gems = GetEquipmentStats(charKey, charData)
            return gems
        elseif col == "tierSet" then
            local _, _, _, tier = GetEquipmentStats(charKey, charData)
            return tier
        elseif col == "status" then
            local _, _, _, _, status = GetEquipmentStats(charKey, charData)
            return status
        elseif col == "str" then
            return (charData.stats and charData.stats.strength) or 0
        elseif col == "agi" then
            return (charData.stats and charData.stats.agility) or 0
        elseif col == "sta" then
            return (charData.stats and charData.stats.stamina) or 0
        elseif col == "int" then
            return (charData.stats and charData.stats.intellect) or 0
        elseif col == "armor" then
            return (charData.stats and charData.stats.armor) or 0
        elseif col == "ap" then
            return (charData.stats and charData.stats.attackPower) or 0
        elseif col == "crit" then
            return (charData.stats and charData.stats.critChance) or 0
        elseif col == "haste" then
            return (charData.stats and charData.stats.haste) or 0
        elseif col == "mastery" then
            return (charData.stats and charData.stats.mastery) or 0
        elseif col == "vers" then
            return (charData.stats and charData.stats.versatility) or 0
        else
            return charData.name or ""
        end
    end, currentSortColumn, currentSortAscending)
    if #allChars == 0 then return end

    local scrollContent = equipmentTab.scrollContent
    if not scrollContent then return end

    local dt = equipmentTab.dataTable
    local columnsConfig = equipmentTab.columnsConfig
    local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

    OneWoW_GUI:ClearDataRows(scrollContent)
    wipe(characterRows)
    if dt then dt:ClearRows() end

    local rowHeight = 32
    local rowGap = 2

    local totalILevel = 0
    local charCount = 0

    for charIndex, charInfo in ipairs(allChars) do
        local charKey = charInfo.key
        local charData = charInfo.data

        local ilvl = charData.itemLevel or 0
        if ilvl > 0 then
            totalILevel = totalILevel + ilvl
            charCount = charCount + 1
        end

        local equipment = (_G.OneWoW_AltTracker_Character_DB.characters[charKey] and _G.OneWoW_AltTracker_Character_DB.characters[charKey].equipment)

        local totalDurability = 0
        local durabilityItems = 0
        local missingEnchants = 0
        local hardMissingEnchants = 0
        local totalEnchantableSlots = 0
        local missingGems = 0
        local totalGemSlots = 0
        local tierCount = 0
        local tierPieces = {}

        if equipment then
            for slotId = 1, 19 do
                if slotId ~= 4 and slotId ~= 18 and slotId ~= 19 then
                    local item = equipment[slotId]
                    if item and item.itemLink then
                        if item.durability and item.maxDurability then
                            totalDurability = totalDurability + (item.durability / item.maxDurability * 100)
                            durabilityItems = durabilityItems + 1
                        end

                        if IsSlotEnchantable(slotId, equipment) and charData.level and charData.level >= 70 then
                            totalEnchantableSlots = totalEnchantableSlots + 1
                            local enchantId = item.itemLink:match("item:%d+:(%d+)")
                            if not enchantId or enchantId == "0" or enchantId == "" then
                                missingEnchants = missingEnchants + 1
                                if not IsSoftEnchantSlot(slotId) then
                                    hardMissingEnchants = hardMissingEnchants + 1
                                end
                            end
                        end

                        local itemSockets = item.numSockets or 0
                        totalGemSlots = totalGemSlots + itemSockets
                        missingGems = missingGems + math.max(0, itemSockets - (item.socketsWithGems or 0))

                        if item.setID and item.setID > 0 then
                            tierCount = tierCount + 1
                            if item.name then
                                table.insert(tierPieces, item.name)
                            end
                        end
                    end
                end
            end
        end

        local durabilityPct = 100
        if durabilityItems > 0 then
            durabilityPct = math.floor(totalDurability / durabilityItems)
        end

        local charRow = OneWoW_GUI:CreateDataRow(scrollContent, {
            rowHeight = rowHeight,
            expandedHeight = 70,
            rowGap = rowGap,
            data = { charKey = charKey, charData = charData },
            createDetails = function(ef, d)
                local cKey = d.charKey
                local eq = (_G.OneWoW_AltTracker_Character_DB.characters[cKey] and _G.OneWoW_AltTracker_Character_DB.characters[cKey].equipment)
                if eq then
                    local slotOrder = {1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 4, 19}
                    local iconSize = 48
                    local iconGap = 4
                    local largeGap = 12
                    local startX = 10
                    local startY = -10

                    for i, slotID in ipairs(slotOrder) do
                        local item = eq[slotID]
                        local xPos = startX + (i - 1) * (iconSize + iconGap)

                        if i == 17 then
                            xPos = xPos + (largeGap - iconGap)
                        elseif i >= 18 then
                            xPos = xPos + (largeGap - iconGap) + (largeGap - iconGap)
                        end

                        local iconFrame = OneWoW_GUI:CreateSkinnedIcon(ef, {
                            size = iconSize,
                            preset = "clean",
                            showIlvl = true,
                            itemLink = item and item.itemLink,
                            itemID = item and item.itemID,
                            quality = item and item.quality or 1,
                            itemLevel = item and item.itemLevel,
                            iconTexture = (item and item.itemLink) and GetItemIcon(item.itemID) or nil,
                        })
                        iconFrame:SetPoint("TOPLEFT", ef, "TOPLEFT", xPos, startY)
                    end
                end
                OneWoW_GUI:ApplyFontToFrame(ef)
            end,
        })
        charRow.charKey = charKey

        ns.UI.AddCommonCells(charRow, charKey, charData)
        ns.UI.AddLevelCell(charRow, charData)

        local ilvlText = OneWoW_GUI:CreateFS(charRow, 12)
        ilvlText:SetText(tostring(ilvl))
        ilvlText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, ilvlText)

        local durabilityText = OneWoW_GUI:CreateFS(charRow, 12)
        durabilityText:SetText(durabilityPct .. "%")
        if durabilityPct < 30 then
            durabilityText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        elseif durabilityPct < 70 then
            durabilityText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            durabilityText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        end
        durabilityText:SetJustifyH("CENTER")
        table.insert(charRow.cells, durabilityText)

        local enchantsCell = CreateFrame("Frame", nil, charRow)
        enchantsCell:SetHeight(32)
        enchantsCell:EnableMouse(true)
        enchantsCell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if missingEnchants > 0 then
                GameTooltip:SetText(string.format(L["TT_ENCHANTS_MISSING_OF"], missingEnchants, totalEnchantableSlots), 1, 0.35, 0.13)
            else
                GameTooltip:SetText(string.format(L["TT_ENCHANTS_ALL_OK"], totalEnchantableSlots), 0.30, 0.69, 0.31)
            end
            GameTooltip:AddLine(L["TT_ENCHANTS_SLOT_LIST"], 1, 1, 1)
            GameTooltip:AddLine(L["TT_ENCHANTS_QUALITY_NOTE"], 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        enchantsCell:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        local enchantsText = OneWoW_GUI:CreateFS(enchantsCell, 12)
        enchantsText:SetPoint("CENTER", enchantsCell, "CENTER", 0, 0)
        if missingEnchants > 0 then
            enchantsText:SetText(tostring(missingEnchants))
            if missingEnchants >= 5 then
                enchantsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            else
                enchantsText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end
        else
            enchantsText:SetText("0")
            enchantsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        end
        table.insert(charRow.cells, enchantsCell)

        local gemsCell = CreateFrame("Frame", nil, charRow)
        gemsCell:SetHeight(32)
        gemsCell:EnableMouse(true)
        gemsCell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if missingGems > 0 then
                GameTooltip:SetText(string.format(L["TT_GEMS_MISSING_OF"], missingGems, totalGemSlots), 1, 0.35, 0.13)
            else
                GameTooltip:SetText(string.format(L["TT_GEMS_ALL_OK"], totalGemSlots), 0.30, 0.69, 0.31)
            end
            GameTooltip:Show()
        end)
        gemsCell:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        local gemsText = OneWoW_GUI:CreateFS(gemsCell, 12)
        gemsText:SetPoint("CENTER", gemsCell, "CENTER", 0, 0)
        if missingGems > 0 then
            gemsText:SetText(tostring(missingGems))
            if missingGems >= 5 then
                gemsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            else
                gemsText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end
        else
            gemsText:SetText("0")
            gemsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        end
        table.insert(charRow.cells, gemsCell)

        local tierCell = CreateFrame("Frame", nil, charRow)
        tierCell:SetHeight(32)
        tierCell:EnableMouse(true)
        tierCell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if tierCount >= 5 then
                GameTooltip:SetText(string.format(L["TT_TIER_TITLE"], tierCount), 0.30, 0.69, 0.31)
            elseif tierCount > 0 then
                GameTooltip:SetText(string.format(L["TT_TIER_TITLE"], tierCount), 1, 1, 0)
            else
                GameTooltip:SetText(string.format(L["TT_TIER_TITLE"], tierCount), 1, 0.34, 0.13)
            end
            if #tierPieces > 0 then
                GameTooltip:AddLine(L["TT_TIER_FOUND"], 1, 1, 1)
                for _, pieceName in ipairs(tierPieces) do
                    GameTooltip:AddLine("  " .. pieceName, 1, 0.82, 0)
                end
            end
            GameTooltip:AddLine(L["TT_TIER_TRACKING"], 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        tierCell:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        local tierSetText = OneWoW_GUI:CreateFS(tierCell, 12)
        tierSetText:SetPoint("CENTER", tierCell, "CENTER", 0, 0)
        tierSetText:SetText(tierCount .. "/5")
        if tierCount == 0 then
            tierSetText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        elseif tierCount < 5 then
            tierSetText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            tierSetText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        end
        table.insert(charRow.cells, tierCell)

        local strText = OneWoW_GUI:CreateFS(charRow, 12)
        strText:SetText(tostring((charData.stats and charData.stats.strength) or 0))
        strText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, strText)

        local agiText = OneWoW_GUI:CreateFS(charRow, 12)
        agiText:SetText(tostring((charData.stats and charData.stats.agility) or 0))
        agiText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, agiText)

        local staText = OneWoW_GUI:CreateFS(charRow, 12)
        staText:SetText(tostring((charData.stats and charData.stats.stamina) or 0))
        staText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, staText)

        local intText = OneWoW_GUI:CreateFS(charRow, 12)
        intText:SetText(tostring((charData.stats and charData.stats.intellect) or 0))
        intText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, intText)

        local armorText = OneWoW_GUI:CreateFS(charRow, 12)
        armorText:SetText(tostring((charData.stats and charData.stats.armor) or 0))
        armorText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, armorText)

        local apText = OneWoW_GUI:CreateFS(charRow, 12)
        apText:SetText(tostring((charData.stats and charData.stats.attackPower) or 0))
        apText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, apText)

        local critText = OneWoW_GUI:CreateFS(charRow, 12)
        local critValue = (charData.stats and charData.stats.critChance) or 0
        critText:SetText(string.format("%.1f%%", critValue))
        critText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, critText)

        local hasteText = OneWoW_GUI:CreateFS(charRow, 12)
        local hasteValue = (charData.stats and charData.stats.haste) or 0
        hasteText:SetText(string.format("%.1f%%", hasteValue))
        hasteText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, hasteText)

        local masteryText = OneWoW_GUI:CreateFS(charRow, 12)
        local masteryValue = (charData.stats and charData.stats.mastery) or 0
        masteryText:SetText(string.format("%.1f%%", masteryValue))
        masteryText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        masteryText:SetJustifyH("CENTER")
        table.insert(charRow.cells, masteryText)

        local versText = OneWoW_GUI:CreateFS(charRow, 12)
        local versValue = (charData.stats and charData.stats.versatility) or 0
        versText:SetText(string.format("%.1f%%", versValue))
        versText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        table.insert(charRow.cells, versText)

        local statusCell = CreateFrame("Frame", nil, charRow)
        statusCell:SetHeight(32)
        statusCell:EnableMouse(true)
        statusCell:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            if durabilityPct < 30 or hardMissingEnchants >= 5 or missingGems >= 5 then
                GameTooltip:SetText(L["STATUS_ATTENTION"], 1, 0.34, 0.13)
            elseif hardMissingEnchants > 0 or missingGems > 0 or durabilityPct < 70 then
                GameTooltip:SetText(L["STATUS_REVIEW"], 1, 1, 0)
            else
                GameTooltip:SetText(L["STATUS_OK"], 0.30, 0.69, 0.31)
            end
            if durabilityPct < 70 then
                GameTooltip:AddLine(string.format(L["TT_STATUS_REASON_DUR"], durabilityPct), 1, 1, 1)
            end
            if missingEnchants > 0 then
                GameTooltip:AddLine(string.format(L["TT_STATUS_REASON_ENCHANT"], missingEnchants), 1, 1, 1)
            end
            if missingGems > 0 then
                GameTooltip:AddLine(string.format(L["TT_STATUS_REASON_GEM"], missingGems), 1, 1, 1)
            end
            if durabilityPct >= 70 and missingEnchants == 0 and missingGems == 0 then
                GameTooltip:AddLine(L["TT_STATUS_ALL_OK"], 0.30, 0.69, 0.31)
            end
            GameTooltip:Show()
        end)
        statusCell:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
        end)
        local statusIcon = statusCell:CreateTexture(nil, "OVERLAY")
        statusIcon:SetSize(14, 14)
        statusIcon:SetPoint("CENTER", statusCell, "CENTER", 0, 0)
        if durabilityPct < 30 or hardMissingEnchants >= 5 or missingGems >= 5 then
            statusIcon:SetTexture("Interface\\FriendsFrame\\StatusIcon-DnD")
        elseif hardMissingEnchants > 0 or missingGems > 0 or durabilityPct < 70 then
            statusIcon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Away")
        else
            statusIcon:SetTexture("Interface\\FriendsFrame\\StatusIcon-Online")
        end
        table.insert(charRow.cells, statusCell)

        if dt and dt.headerRow and dt.headerRow.columnButtons and columnsConfig then
            for i, cell in ipairs(charRow.cells) do
                local btn = dt.headerRow.columnButtons[i]
                if btn and btn.columnWidth and btn.columnX then
                    local width = btn.columnWidth
                    local x = btn.columnX
                    local col = columnsConfig[i]
                    cell:ClearAllPoints()
                    if col and col.align == "icon" then
                        cell:SetSize(width, rowHeight)
                        cell:SetPoint("LEFT", charRow, "LEFT", x, 0)
                    elseif col and col.align == "center" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("CENTER", charRow, "LEFT", x + width / 2, 0)
                    elseif col and col.align == "right" then
                        cell:SetWidth(width - 6)
                        cell:SetPoint("RIGHT", charRow, "LEFT", x + width - 3, 0)
                    else
                        cell:SetWidth(width - 6)
                        cell:SetPoint("LEFT", charRow, "LEFT", x + 3, 0)
                    end
                end
            end
        end

        table.insert(characterRows, charRow)
        if dt then dt:RegisterRow(charRow) end
    end

    OneWoW_GUI:LayoutDataRows(scrollContent, { rowHeight = rowHeight, rowGap = rowGap })

    if equipmentTab.statusText then
        equipmentTab.statusText:SetText(string.format(L["CHARACTERS_TRACKED"], #allChars, ""))
    end

    ns.UI.RefreshEquipmentStats(equipmentTab, allChars, charCount, totalILevel)

    OneWoW_GUI:ApplyFontToFrame(equipmentTab)
end

function ns.UI.RefreshEquipmentStats(equipmentTab, allChars, charCount, totalILevel)
    if not equipmentTab or not equipmentTab.statBoxes then return end

    local stats = {
        attention = 0,
        characters = #allChars,
        avgIlvl = 0,
        highestIlvl = 0,
        lowestIlvl = 999,
        missingEnchants = 0,
        missingGems = 0,
        lowDurability = 0,
        tierSets = 0
    }

    if charCount > 0 then
        stats.avgIlvl = math.floor(totalILevel / charCount)
    end

    for _, charInfo in ipairs(allChars) do
        local charData = charInfo.data
        local charKey = charInfo.key
        local equipment = (_G.OneWoW_AltTracker_Character_DB.characters[charKey] and _G.OneWoW_AltTracker_Character_DB.characters[charKey].equipment)

        local ilvl = charData.itemLevel or 0
        if ilvl > 0 then
            if ilvl > stats.highestIlvl then
                stats.highestIlvl = ilvl
            end
            if ilvl < stats.lowestIlvl then
                stats.lowestIlvl = ilvl
            end
        end

        if equipment then
            local charMissingEnchants = 0
            local charHardMissingEnchants = 0
            local charMissingGems = 0
            local charLowDurability = 0
            local charTierCount = 0

            for slotId = 1, 19 do
                if slotId ~= 4 and slotId ~= 18 and slotId ~= 19 then
                    local item = equipment[slotId]
                    if item and item.itemLink then
                        if item.durability and item.maxDurability then
                            if item.durability < item.maxDurability * 0.3 then
                                charLowDurability = charLowDurability + 1
                            end
                        end

                        if IsSlotEnchantable(slotId, equipment) and charData.level and charData.level >= 70 then
                            local enchantId = item.itemLink:match("item:%d+:(%d+)")
                            if not enchantId or enchantId == "0" or enchantId == "" then
                                charMissingEnchants = charMissingEnchants + 1
                                if not IsSoftEnchantSlot(slotId) then
                                    charHardMissingEnchants = charHardMissingEnchants + 1
                                end
                            end
                        end

                        charMissingGems = charMissingGems + math.max(0, (item.numSockets or 0) - (item.socketsWithGems or 0))

                        if item.setID and item.setID > 0 then
                            charTierCount = charTierCount + 1
                        end

                    end
                end
            end

            if charMissingEnchants > 0 then
                stats.missingEnchants = stats.missingEnchants + 1
            end
            if charMissingGems > 0 then
                stats.missingGems = stats.missingGems + 1
            end
            if charLowDurability >= 3 then
                stats.lowDurability = stats.lowDurability + 1
            end
            if charTierCount >= 2 then
                stats.tierSets = stats.tierSets + 1
            end
            if charLowDurability >= 3 or charHardMissingEnchants >= 5 or charMissingGems >= 5 then
                stats.attention = stats.attention + 1
            end
        end
    end

    if stats.lowestIlvl == 999 then
        stats.lowestIlvl = 0
    end

    local statBoxes = equipmentTab.statBoxes
    if statBoxes then
        if statBoxes[1] then statBoxes[1].value:SetText(tostring(stats.attention)) end
        if statBoxes[2] then statBoxes[2].value:SetText(tostring(stats.characters)) end
        if statBoxes[3] then statBoxes[3].value:SetText(tostring(stats.avgIlvl)) end
        if statBoxes[4] then statBoxes[4].value:SetText(tostring(stats.highestIlvl)) end
        if statBoxes[5] then statBoxes[5].value:SetText(tostring(stats.lowestIlvl)) end
        if statBoxes[6] then statBoxes[6].value:SetText(tostring(stats.missingEnchants)) end
        if statBoxes[7] then statBoxes[7].value:SetText(tostring(stats.missingGems)) end
        if statBoxes[8] then statBoxes[8].value:SetText(tostring(stats.lowDurability)) end
        if statBoxes[9] then statBoxes[9].value:SetText(tostring(stats.tierSets)) end
    end
end
