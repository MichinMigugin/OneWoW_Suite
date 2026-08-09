local _, ns = ...
local CharInfoModule, L = ns.ModuleRegistry:Current()
if not CharInfoModule then return end

local OneWoW_GUI = OneWoW_GUI

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

local SECONDARY_HAND_SLOT = GetInventorySlotInfo("SECONDARYHANDSLOT")

local enchantSlotDefaults = {
    [1]  = true,
    [2]  = false,
    [3]  = true,
    [5]  = true,
    [6]  = false,
    [7]  = true,
    [8]  = true,
    [9]  = true,
    [10] = false,
    [11] = true,
    [12] = true,
    [15] = true,
    [16] = true,
    [17] = true,
}

local function IsOffHandWeapon()
    local itemID = GetInventoryItemID("player", SECONDARY_HAND_SLOT)
    if not itemID then return false end
    local invType = C_Item.GetItemInventoryTypeByID(itemID)
    if not invType then return false end
    return invType == Enum.InventoryType.IndexWeaponType
        or invType == Enum.InventoryType.IndexWeaponoffhandType
        or invType == Enum.InventoryType.IndexWeaponmainhandType
end

local function GetSlotEnchantToggle(slotId)
    local defaultVal = enchantSlotDefaults[slotId]
    if defaultVal == nil then return false end
    local modData = ns.db.global.modules["charinfo"]
    if modData and modData.toggles and modData.toggles["enchant_slot_" .. slotId] ~= nil then
        return modData.toggles["enchant_slot_" .. slotId]
    end
    return defaultVal
end

local function IsSlotEnchantable(slotId)
    if not GetSlotEnchantToggle(slotId) then return false end
    if slotId == SECONDARY_HAND_SLOT then return IsOffHandWeapon() end
    return true
end

-- Cross-addon: AltTracker Equipment tab uses the same slot toggles as this panel.
-- Off-hand weapon checks stay caller-side (live player vs stored alt gear).
function OneWoW_QoL_API.IsEnchantSlotEnabled(slotId)
    return GetSlotEnchantToggle(slotId)
end

local slotNames = {
    [1] = "Head",
    [2] = "Neck",
    [3] = "Shoulder",
    [4] = "Shirt",
    [5] = "Chest",
    [6] = "Waist",
    [7] = "Legs",
    [8] = "Feet",
    [9] = "Wrist",
    [10] = "Hands",
    [11] = "Finger0",
    [12] = "Finger1",
    [13] = "Trinket0",
    [14] = "Trinket1",
    [15] = "Back",
    [16] = "MainHand",
    [17] = "SecondaryHand",
    [18] = "Ranged",
    [19] = "Tabard",
}

local function CreateInfoPanel(button)
    if button.onewow_charInfoPanel then
        return button.onewow_charInfoPanel
    end

    local panel = CreateFrame("Frame", nil, button)
    panel:SetSize(42, 42)
    panel:SetFrameLevel(button:GetFrameLevel() + 5)

    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(panel)
    bg:SetColorTexture(0.05, 0.08, 0.12, 0.9)
    panel.bg = bg

    local border = panel:CreateTexture(nil, "BORDER")
    border:SetAllPoints(panel)
    border:SetAtlas("Forge-ColorSwatchSelection")
    border:SetVertexColor(0.3, 0.4, 0.5, 0.8)
    panel.border = border

    panel.ilvlText = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    panel.ilvlText:SetPoint("TOP", panel, "TOP", 0, -8)
    panel.ilvlText:SetText("")

    panel.enchantIcon = CreateFrame("Frame", nil, panel)
    panel.enchantIcon:SetSize(16, 16)
    panel.enchantIcon:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 6)
    panel.enchantIcon.texture = panel.enchantIcon:CreateTexture(nil, "OVERLAY")
    panel.enchantIcon.texture:SetAllPoints(panel.enchantIcon)
    panel.enchantIcon:EnableMouse(true)
    panel.enchantIcon:Hide()

    panel.gemIcon = CreateFrame("Frame", nil, panel)
    panel.gemIcon:SetSize(16, 16)
    panel.gemIcon:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 6)
    panel.gemIcon.texture = panel.gemIcon:CreateTexture(nil, "OVERLAY")
    panel.gemIcon.texture:SetAllPoints(panel.gemIcon)
    panel.gemIcon:EnableMouse(true)
    panel.gemIcon:Hide()

    if not button.onewow_durabilityText then
        button.onewow_durabilityText = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        local _guiLib = OneWoW_GUI
        local fontPath = (_guiLib and _guiLib.GetFont and _guiLib:GetFont()) or "Fonts\\FRIZQT__.TTF"
        button.onewow_durabilityText:SetFont(fontPath, 10, "OUTLINE")
    end

    button.onewow_charInfoPanel = panel
    return panel
end

local function HidePanel(button)
    if button.onewow_charInfoPanel then
        button.onewow_charInfoPanel:Hide()
    end
    if button.onewow_durabilityText then
        button.onewow_durabilityText:Hide()
    end
end

local function UpdateInfoPanel(button, itemLink, slotId, item)
    local showDurability = ns.ModuleRegistry:GetToggleValue("charinfo", "show_durability")
    local showSockets = ns.ModuleRegistry:GetToggleValue("charinfo", "show_sockets")

    if not itemLink then
        HidePanel(button)
        return
    end

    local panel = CreateInfoPanel(button)

    local layoutType = "LeftColumn"
    if slotId == 16 then
        layoutType = "MainHand"
    elseif slotId == 17 then
        layoutType = "OffHand"
    elseif (slotId >= 6 and slotId <= 8) or (slotId >= 10 and slotId <= 14) then
        layoutType = "RightColumn"
    end

    panel:ClearAllPoints()
    if layoutType == "MainHand" then
        panel:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 2)
    elseif layoutType == "OffHand" then
        panel:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 0, 2)
    elseif layoutType == "LeftColumn" then
        panel:SetPoint("LEFT", button, "RIGHT", 2, 0)
    else
        panel:SetPoint("RIGHT", button, "LEFT", -2, 0)
    end

    local actualILvl = nil
    local quality = nil

    if item and not item:IsItemEmpty() then
        item:ContinueOnItemLoad(function()
            actualILvl = item:GetCurrentItemLevel()
            quality = item:GetItemQuality()

            if actualILvl and actualILvl > 0 then
                local colorString = "|cffffffff"
                if quality then
                    local _, _, _, hex = C_Item.GetItemQualityColor(quality)
                    if hex then colorString = "|c" .. hex end
                end
                panel.ilvlText:SetText(colorString .. actualILvl .. "|r")
            else
                panel.ilvlText:SetText("")
            end
        end)
    else
        actualILvl = C_Item.GetDetailedItemLevelInfo(itemLink)
        quality = C_Item.GetItemQualityByID(itemLink)
    end

    panel.gemIcon:Hide()
    panel.enchantIcon:Hide()

    local itemString = string.match(itemLink, "item:([%-?%d:]+)")
    if not itemString then
        panel:Show()
        return
    end

    local itemSplit = {strsplit(":", itemString)}
    local enchantID = tonumber(itemSplit[2]) or 0

    local showEnchantIcon = false
    local showGemIcon = false

    if IsSlotEnchantable(slotId) then
        showEnchantIcon = true
        if enchantID > 0 then
            panel.enchantIcon.texture:SetAtlas("Perks-PreviewOn")
            panel.enchantIcon.texture:SetDesaturated(false)
            panel.enchantIcon.texture:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            panel.enchantIcon:SetScript("OnEnter", function(ic)
                GameTooltip:SetOwner(ic, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["CHARINFO_ENCHANTED"], 0.2, 1, 0.2)
                GameTooltip:Show()
            end)
        else
            panel.enchantIcon.texture:SetAtlas("Perks-PreviewOff")
            panel.enchantIcon.texture:SetDesaturated(false)
            panel.enchantIcon.texture:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            panel.enchantIcon:SetScript("OnEnter", function(ic)
                GameTooltip:SetOwner(ic, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["CHARINFO_MISSING_ENCHANT"], 1, 0.2, 0.2)
                GameTooltip:Show()
            end)
        end
        panel.enchantIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local stats = C_Item.GetItemStats(itemLink)
    local totalSockets = 0
    if showSockets and stats then
        for statKey, value in pairs(stats) do
            if string.find(statKey, "EMPTY_SOCKET_") then
                totalSockets = totalSockets + value
            end
        end
    end

    if showSockets and totalSockets > 0 then
        showGemIcon = true
        local filledGems = 0
        for i = 3, 6 do
            local gemID = tonumber(itemSplit[i])
            if gemID and gemID > 0 then
                filledGems = filledGems + 1
            end
        end

        local emptyGems = totalSockets - filledGems

        panel.gemIcon.texture:SetAtlas("soulbinds_tree_conduit_icon_utility")

        if emptyGems == totalSockets then
            panel.gemIcon.texture:SetDesaturated(false)
            panel.gemIcon.texture:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            panel.gemIcon:SetScript("OnEnter", function(ic)
                GameTooltip:SetOwner(ic, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["CHARINFO_ALL_SOCKETS_EMPTY"], 1, 0.2, 0.2)
                GameTooltip:AddLine(totalSockets .. " empty socket(s)", 1, 1, 1)
                GameTooltip:Show()
            end)
        elseif emptyGems > 0 then
            panel.gemIcon.texture:SetDesaturated(false)
            panel.gemIcon.texture:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            panel.gemIcon:SetScript("OnEnter", function(ic)
                GameTooltip:SetOwner(ic, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["CHARINFO_SOME_SOCKETS_EMPTY"], 1, 0.7, 0.2)
                GameTooltip:AddLine(filledGems .. " filled, " .. emptyGems .. " empty", 1, 1, 1)
                GameTooltip:Show()
            end)
        else
            panel.gemIcon.texture:SetDesaturated(false)
            panel.gemIcon.texture:SetVertexColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
            panel.gemIcon:SetScript("OnEnter", function(ic)
                GameTooltip:SetOwner(ic, "ANCHOR_RIGHT")
                GameTooltip:AddLine(L["CHARINFO_ALL_SOCKETS_FILLED"], 0.2, 1, 0.2)
                GameTooltip:AddLine(totalSockets .. " gem(s) socketed", 1, 1, 1)
                GameTooltip:Show()
            end)
        end
        panel.gemIcon:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    panel.enchantIcon:ClearAllPoints()
    panel.gemIcon:ClearAllPoints()
    if showEnchantIcon and showGemIcon then
        panel.enchantIcon:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 4, 6)
        panel.enchantIcon:Show()
        panel.gemIcon:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -4, 6)
        panel.gemIcon:Show()
    elseif showEnchantIcon then
        panel.enchantIcon:SetPoint("BOTTOM", panel, "BOTTOM", 0, 6)
        panel.enchantIcon:Show()
    elseif showGemIcon then
        panel.gemIcon:SetPoint("BOTTOM", panel, "BOTTOM", 0, 6)
        panel.gemIcon:Show()
    end

    local current, maximum = GetInventoryItemDurability(slotId)
    if showDurability and maximum and maximum > 0 then
        local ratio = current / maximum
        local percent = math.floor(ratio * 100)
        local color
        if ratio == 0 then
            color = "|cffFF3333"
        elseif ratio < 0.25 then
            color = "|cffFF8833"
        elseif ratio < 0.50 then
            color = "|cffFFDD33"
        else
            color = "|cff33FF33"
        end

        button.onewow_durabilityText:SetText(color .. percent .. "%|r")
        button.onewow_durabilityText:ClearAllPoints()
        if layoutType == "LeftColumn" or layoutType == "MainHand" then
            button.onewow_durabilityText:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3)
        else
            button.onewow_durabilityText:SetPoint("TOPRIGHT", button, "TOPRIGHT", -3, -3)
        end
        button.onewow_durabilityText:Show()
    else
        if button.onewow_durabilityText then
            button.onewow_durabilityText:Hide()
        end
    end

    panel.ilvlText:ClearAllPoints()
    if not showEnchantIcon and not showGemIcon then
        panel.ilvlText:SetPoint("CENTER", panel, "CENTER", 0, 0)
    else
        panel.ilvlText:SetPoint("TOP", panel, "TOP", 0, -8)
    end

    if not item or item:IsItemEmpty() then
        if actualILvl and actualILvl > 0 then
            local colorString = "|cffffffff"
            if quality then
                local _, _, _, hex = C_Item.GetItemQualityColor(quality)
                if hex then colorString = "|c" .. hex end
            end
            panel.ilvlText:SetText(colorString .. actualILvl .. "|r")
        else
            panel.ilvlText:SetText("")
        end
    end

    panel:Show()
end

local function RefreshAllSlots()
    for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local slotName = slotNames[slotID]
        if slotName then
            local button = _G["Character" .. slotName .. "Slot"]
            if button and button:IsVisible() then
                local itemLink = GetInventoryItemLink("player", slotID)
                local item = Item:CreateFromEquipmentSlot(slotID)
                UpdateInfoPanel(button, itemLink, slotID, item)
            end
        end
    end
end

local function HideAllSlots()
    for slotID = INVSLOT_FIRST_EQUIPPED, INVSLOT_LAST_EQUIPPED do
        local slotName = slotNames[slotID]
        if slotName then
            local button = _G["Character" .. slotName .. "Slot"]
            if button then
                HidePanel(button)
            end
        end
    end
end

function CharInfoModule:OnEnable()
    if not self._hooked and PaperDollItemSlotButton_Update then
        hooksecurefunc("PaperDollItemSlotButton_Update", function(button)
            if not ns.ModuleRegistry:IsEnabled("charinfo") then return end
            local slotID = button:GetID()
            if slotID and slotID >= INVSLOT_FIRST_EQUIPPED and slotID <= INVSLOT_LAST_EQUIPPED then
                local itemLink = GetInventoryItemLink("player", slotID)
                local item = Item:CreateFromEquipmentSlot(slotID)
                UpdateInfoPanel(button, itemLink, slotID, item)
            end
        end)
        self._hooked = true
    end

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_CharInfo")
        self._eventFrame:SetScript("OnEvent", function()
            if ns.ModuleRegistry:IsEnabled("charinfo") then
                RefreshAllSlots()
            end
        end)
    end
    self._eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    self._eventFrame:RegisterEvent("UPDATE_INVENTORY_DURABILITY")

    RefreshAllSlots()
end

function CharInfoModule:OnDisable()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
    end
    HideAllSlots()
end

function CharInfoModule:OnToggle()
    RefreshAllSlots()
end

local enchantSlotOrder = {
    left  = {1, 2, 3, 15, 5, 9, 16},
    right = {10, 6, 7, 8, 11, 12, 17},
}

local enchantSlotLabels = {
    [1]  = "CHARINFO_SLOT_HEAD",
    [2]  = "CHARINFO_SLOT_NECK",
    [3]  = "CHARINFO_SLOT_SHOULDER",
    [5]  = "CHARINFO_SLOT_CHEST",
    [6]  = "CHARINFO_SLOT_WAIST",
    [7]  = "CHARINFO_SLOT_LEGS",
    [8]  = "CHARINFO_SLOT_FEET",
    [9]  = "CHARINFO_SLOT_WRIST",
    [10] = "CHARINFO_SLOT_HANDS",
    [11] = "CHARINFO_SLOT_RING1",
    [12] = "CHARINFO_SLOT_RING2",
    [15] = "CHARINFO_SLOT_BACK",
    [16] = "CHARINFO_SLOT_MAINHAND",
    [17] = "CHARINFO_SLOT_OFFHAND",
}

function CharInfoModule:CreateCustomDetail(detailScrollChild, yOffset, isEnabled, registerRefresh)
    local cardsHost = CreateFrame("Frame", nil, detailScrollChild)
    cardsHost:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if detailScrollChild.UpdateDetailHeight then
            detailScrollChild:SetHeight(h)
            detailScrollChild.UpdateDetailHeight()
        else
            detailScrollChild:SetHeight(math.abs(yOffset) + h + 20)
            if detailScrollChild.updateThumb then
                detailScrollChild.updateThumb()
            end
        end
    end
    stack.OnRelayout = applyHostHeight

    local allSlotRefreshes = {}

    stack:AddCard("charinfo:enchant_slots", L["CHARINFO_ENCHANT_SLOTS_HEADER"], function(content, contentWidth)
        wipe(allSlotRefreshes)

        local gap = 8
        local descText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetSpacing(2)
        local w = tonumber(contentWidth) or 0
        if w < 1 then
            w = content:GetWidth() or 0
        end
        if w >= 1 then
            descText:SetWidth(w)
        else
            descText:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
        end
        descText:SetText(L["CHARINFO_ENCHANT_SLOTS_DESC"])
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local descH = descText:GetStringHeight() or 14
        local columnsTop = -(descH + gap)

        local leftContainer = CreateFrame("Frame", nil, content)
        leftContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, columnsTop)
        leftContainer:SetPoint("RIGHT", content, "CENTER", 0, 0)
        leftContainer:SetHeight(1)

        local rightContainer = CreateFrame("Frame", nil, content)
        rightContainer:SetPoint("TOPLEFT", content, "TOP", 0, columnsTop)
        rightContainer:SetPoint("RIGHT", content, "RIGHT", 0, 0)
        rightContainer:SetHeight(1)

        local colWidth = 0
        if w >= 1 then
            colWidth = math.max(50, (w / 2) - 4)
        end

        local leftY = 0
        for _, slotId in ipairs(enchantSlotOrder.left) do
            local capturedSlotId = slotId
            local currentVal = GetSlotEnchantToggle(slotId)
            local rowRefresh
            leftY, rowRefresh = OneWoW_GUI:CreateToggleRow(leftContainer, {
                yOffset = leftY,
                contentWidth = colWidth > 0 and colWidth or nil,
                label = L[enchantSlotLabels[slotId]] or enchantSlotLabels[slotId],
                value = currentVal,
                isEnabled = isEnabled,
                onValueChange = function(newVal)
                    ns.ModuleRegistry:SetToggleValue("charinfo", "enchant_slot_" .. capturedSlotId, newVal)
                end,
                onLabel = L["FEATURES_ON"],
                offLabel = L["FEATURES_OFF"],
                buttonWidth = 40,
            })
            if rowRefresh then
                tinsert(allSlotRefreshes, { refresh = rowRefresh, slotId = capturedSlotId })
            end
        end

        local rightY = 0
        for _, slotId in ipairs(enchantSlotOrder.right) do
            local capturedSlotId = slotId
            local currentVal = GetSlotEnchantToggle(slotId)
            local rowRefresh
            rightY, rowRefresh = OneWoW_GUI:CreateToggleRow(rightContainer, {
                yOffset = rightY,
                contentWidth = colWidth > 0 and colWidth or nil,
                label = L[enchantSlotLabels[slotId]] or enchantSlotLabels[slotId],
                value = currentVal,
                isEnabled = isEnabled,
                onValueChange = function(newVal)
                    ns.ModuleRegistry:SetToggleValue("charinfo", "enchant_slot_" .. capturedSlotId, newVal)
                end,
                onLabel = L["FEATURES_ON"],
                offLabel = L["FEATURES_OFF"],
                buttonWidth = 40,
            })
            if rowRefresh then
                tinsert(allSlotRefreshes, { refresh = rowRefresh, slotId = capturedSlotId })
            end
        end

        local maxHeight = math.max(math.abs(leftY), math.abs(rightY))
        leftContainer:SetHeight(maxHeight)
        rightContainer:SetHeight(maxHeight)

        return math.max(1, descH + gap + maxHeight + 4)
    end)

    stack:Finish()
    applyHostHeight()

    if registerRefresh then
        registerRefresh(function()
            local nowEnabled = ns.ModuleRegistry:IsEnabled("charinfo")
            for _, entry in ipairs(allSlotRefreshes) do
                local val = GetSlotEnchantToggle(entry.slotId)
                entry.refresh(nowEnabled, val)
            end
        end)
    end

    return yOffset - cardsHost:GetHeight()
end
