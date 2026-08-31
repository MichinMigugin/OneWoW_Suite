local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local Constants = ns.Constants
local L = ns.L
local BagTypes = OneWoW.Inventory.BagTypes
local BagEquip = ns.BagEquip
local WH = ns.WindowHelpers

local tinsert, sort = tinsert, sort
local pairs, ipairs = pairs, ipairs
local min, max, ceil, floor = math.min, math.max, math.ceil, math.floor
local C_Timer = C_Timer
local C_Item = C_Item
local C_CurrencyInfo = C_CurrencyInfo
local C_Container = C_Container

ns.BagsBar = {}
local BagsBar = ns.BagsBar

local bagsBarFrame = nil
local bagButtons = {}
local eventFrame = nil

local EMPTY_BAG_TEXTURE = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"

---@param btn Button
---@param bagIndex number
local function ApplyBagButtonIcon(btn, bagIndex)
    if not BagTypes:IsSwappableBag(bagIndex) then
        return
    end
    local invSlotID = C_Container.ContainerIDToInventoryID(bagIndex)
    if not invSlotID then
        return
    end

    local texID = GetInventoryItemTexture("player", invSlotID)
    if BagTypes:IsBagEquipped(bagIndex) and texID then
        OneWoW_GUI:UpdateIconTexture(btn, texID)
        OneWoW_GUI:SetIconDesaturated(btn, false)
    else
        OneWoW_GUI:UpdateIconTexture(btn, EMPTY_BAG_TEXTURE)
        OneWoW_GUI:SetIconDesaturated(btn, true)
    end
end
local trackerDialog = nil

local ROW1_HEIGHT = 32
local ROW2_HEIGHT = 26
local MAX_ALT_DISPLAY = 10
local trackerRelayoutPending = false

-- Shared reorder-drag controller for the tracker row. Built lazily once the
-- bags bar exists so callbacks can close over bagsBarFrame.trackerFrames.
local trackerReorder = nil

local function GetDB()
    return ns:GetDB()
end

local function GetController()
    return ns.BagsController
end

local function SyncBagsBarOuterHeight()
    if not bagsBarFrame then return end
    local db = GetDB()
    local altShow = ns:IsAltShowActive()
    local showBagsBar = db.global.showBagsBar ~= false
    local showRow1 = showBagsBar
    if altShow then
        showRow1 = true
    end
    local h = 0
    if showRow1 and bagsBarFrame.row1Frame and bagsBarFrame.row1Frame:IsShown() then
        h = h + ROW1_HEIGHT
    end
    if bagsBarFrame.row2Frame and bagsBarFrame.row2Frame:IsShown() then
        h = h + bagsBarFrame.row2Frame:GetHeight()
    end
    bagsBarFrame:SetHeight(max(h, 1))
end

local function ShowTrackerDialog()
    if not trackerDialog then
        local function doAdd()
            if not trackerDialog or not trackerDialog.editBox or not trackerDialog.frame then
                return
            end
            local controller = GetController()
            if controller then
                if controller:AddTrackedEntryFromID(strtrim(trackerDialog.editBox:GetText())) then
                    trackerDialog.editBox:SetText("")
                    trackerDialog.frame:Hide()
                end
            end
        end

        local dialog = OneWoW_GUI:CreateDialog({
            name = "OneWoW_BagsTrackerDialog",
            title = L["TRACKER_ADD"],
            width = 380,
            height = 170,
            strata = "DIALOG",
            movable = false,
            escClose = true,
            buttons = {
                { text = ADD, onClick = function() doAdd() end },
                { text = CANCEL, onClick = function(frame) frame:Hide() end },
            },
        })

        local content = dialog.contentFrame

        local label = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -10)
        label:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, -10)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetText(L["TRACKER_ADD_ID"])
        label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local editBox = OneWoW_GUI:CreateEditBox(content, {
            name = "OneWoW_BagsTrackerInput",
            height = 22,
            maxLetters = 10,
        })
        editBox:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
        editBox:SetPoint("TOPRIGHT", label, "BOTTOMRIGHT", 0, -8)
        editBox:SetNumeric(true)
        editBox:SetScript("OnEnterPressed", function() doAdd() end)

        dialog.editBox = editBox
        trackerDialog = dialog
    end

    if not trackerDialog or not trackerDialog.frame or not trackerDialog.editBox then
        return
    end
    trackerDialog.frame:Show()
    trackerDialog.editBox:SetText("")
    C_Timer.After(0, function()
        if trackerDialog and trackerDialog.editBox then
            trackerDialog.editBox:SetFocus()
        end
    end)
end

function BagsBar:UpdateGoldDisplay()
    if not bagsBarFrame or not bagsBarFrame.goldText then return end
    bagsBarFrame.goldText:SetText(OneWoW.Format.FormatGold(GetMoney()))
    if bagsBarFrame.goldBtn then
        bagsBarFrame.goldBtn:SetWidth(max(bagsBarFrame.goldText:GetStringWidth() + 4, 60))
    end
end

function BagsBar:Create(parent)
    if bagsBarFrame then return bagsBarFrame end

    bagsBarFrame = CreateFrame("Frame", "OneWoW_BagsBar", parent, "BackdropTemplate")
    bagsBarFrame:SetHeight(Constants.GUI.BAGSBAR_HEIGHT)
    bagsBarFrame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bagsBarFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    bagsBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    bagsBarFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    bagsBarFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    -- Row 1: bag icons | free slots right
    local row1Frame = CreateFrame("Frame", nil, bagsBarFrame)
    row1Frame:SetPoint("TOPLEFT", bagsBarFrame, "TOPLEFT", 0, 0)
    row1Frame:SetPoint("TOPRIGHT", bagsBarFrame, "TOPRIGHT", 0, 0)
    row1Frame:SetHeight(ROW1_HEIGHT)
    bagsBarFrame.row1Frame = row1Frame

    local row2Frame = CreateFrame("Frame", nil, bagsBarFrame, "BackdropTemplate")
    row2Frame:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", 0, 0)
    row2Frame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", 0, 0)
    row2Frame:SetHeight(ROW2_HEIGHT)
    row2Frame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row2Frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row2Frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    bagsBarFrame.row2Frame = row2Frame

    local toolbarBand = CreateFrame("Frame", nil, row2Frame)
    toolbarBand:SetPoint("TOPLEFT", row2Frame, "TOPLEFT", 0, 0)
    toolbarBand:SetPoint("TOPRIGHT", row2Frame, "TOPRIGHT", 0, 0)
    toolbarBand:SetHeight(ROW2_HEIGHT)
    bagsBarFrame.toolbarBand = toolbarBand

    local dbCreate = GetDB()
    local bagsBarLeftInset, bagsBarRightInset = WH:GetItemGridChromeInsets(dbCreate.global.hideScrollBar)

    local controlCluster = CreateFrame("Frame", nil, toolbarBand)
    controlCluster:SetPoint("LEFT", toolbarBand, "LEFT", bagsBarLeftInset, 0)
    controlCluster:SetHeight(ROW2_HEIGHT)
    controlCluster:SetWidth(20)
    bagsBarFrame.trackerControlCluster = controlCluster

    -- Bag icon buttons (row 1, left)
    local xOffset = bagsBarLeftInset

    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        if not BagTypes:IsReagentBag(bagID) then
            local bagSlot = BagsBar:CreateBagButton(row1Frame, bagID, xOffset)
            bagButtons[bagID] = bagSlot
            xOffset = xOffset + 30
        else
            -- This works since reagent bag is the highest index in the list
            local sep = row1Frame:CreateTexture(nil, "ARTWORK")
            sep:SetSize(1, 20)
            sep:SetPoint("LEFT", row1Frame, "LEFT", xOffset + 2, 0)
            sep:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            bagsBarFrame.reagentSeparator = sep
            xOffset = xOffset + 6
            local bagSlot = BagsBar:CreateBagButton(row1Frame, bagID, xOffset)
            bagButtons[bagID] = bagSlot
        end
    end

    local freeSlots = row1Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", row1Frame, "RIGHT", -bagsBarRightInset, 0)
    freeSlots:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    bagsBarFrame.freeSlots = freeSlots

    local addTrackerBtn = OneWoW_GUI:CreateAtlasIconButton(controlCluster, {
        atlas = "Garr_Building-AddFollowerPlus",
        width = 20,
        height = 20,
    })
    addTrackerBtn:SetPoint("LEFT", controlCluster, "LEFT", 0, 0)
    addTrackerBtn:SetScript("OnClick", function()
        ShowTrackerDialog()
    end)
    addTrackerBtn:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        GameTooltip:SetText(L["TRACKER_ADD"], 1, 1, 1)
        GameTooltip:AddLine(L["TRACKER_ADD_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addTrackerBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    addTrackerBtn:RegisterForDrag("LeftButton")
    addTrackerBtn:SetScript("OnReceiveDrag", function()
        local cursorType, itemID, itemLink = GetCursorInfo()
        if cursorType ~= "item" then return end
        local id = itemID
        if (not id or id == 0) and itemLink then
            id = C_Item.GetItemInfoInstant(itemLink)
        end
        if (not id or id == 0) and itemLink then
            id = tonumber(itemLink:match("item:(%d+)"))
        end
        if id and id > 0 then
            local controller = GetController()
            if controller then
                controller:AddTrackedItem(id)
            end
        end
        ClearCursor()
    end)
    bagsBarFrame.addTrackerBtn = addTrackerBtn

    local goldBtn = CreateFrame("Button", nil, toolbarBand)
    goldBtn:SetHeight(20)
    goldBtn:SetPoint("RIGHT", toolbarBand, "RIGHT", -bagsBarRightInset, 0)

    local goldText = goldBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", goldBtn, "RIGHT", 0, 0)
    goldText:SetTextColor(1, 1, 1)
    bagsBarFrame.goldText = goldText
    BagsBar:UpdateGoldDisplay()

    goldBtn:SetWidth(max(goldText:GetStringWidth() + 4, 60))
    goldBtn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        BagsBar:ShowGoldTooltip()
        GameTooltip:Show()
    end)
    goldBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    bagsBarFrame.goldBtn = goldBtn

    local trackerLayoutHost = CreateFrame("Frame", nil, row2Frame)
    trackerLayoutHost:SetPoint("TOPLEFT", toolbarBand, "BOTTOMLEFT", 0, 0)
    trackerLayoutHost:SetPoint("TOPRIGHT", toolbarBand, "BOTTOMRIGHT", 0, 0)
    trackerLayoutHost:SetHeight(0)
    bagsBarFrame.trackerLayoutHost = trackerLayoutHost

    bagsBarFrame.trackerFrames = {}
    BagsBar:UpdateTrackers()

    bagsBarFrame:SetScript("OnSizeChanged", function()
        if trackerRelayoutPending then return end
        trackerRelayoutPending = true
        C_Timer.After(0, function()
            trackerRelayoutPending = false
            BagsBar:UpdateTrackers()
        end)
    end)

    eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("PLAYER_MONEY")
    eventFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_MONEY" then
            BagsBar:UpdateGoldDisplay()
        end
    end)

    return bagsBarFrame
end

function BagsBar:ShowGoldTooltip()
    local personalCopper = GetMoney()

    if not OneWoW_AltTracker_Character_API then
        GameTooltip:SetText(L["GOLD_TOOLTIP_PERSONAL"], 1, 0.82, 0)
        GameTooltip:AddLine(OneWoW.Format.FormatGold(personalCopper), 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["GOLD_TOOLTIP_NO_CHARACTER_DATA"], 0.5, 0.5, 0.5, true)
        return
    end

    local allChars = OneWoW_AltTracker_Character_API.GetAllCharacters()
    local currentKey = OneWoW_AltTracker_Character_API.GetCurrentCharacterKey()
    local warbandGold = (OneWoW_AltTracker_Storage_API and OneWoW_AltTracker_Storage_API.GetWarbandBankGold()) or 0

    local altList = {}
    local totalGold = 0
    for charKey, charData in pairs(allChars) do
        local money = charData.money or 0
        totalGold = totalGold + money
        if charKey ~= currentKey then
            tinsert(altList, { name = charKey:match("^([^%-]+)") or charKey, money = money })
        end
    end
    totalGold = totalGold + warbandGold

    sort(altList, function(a, b) return a.money > b.money end)

    GameTooltip:SetText(L["GOLD_TOOLTIP_PERSONAL"] .. " - " .. OneWoW.Format.FormatGold(personalCopper), 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["GOLD_TOTAL"] .. " - " .. OneWoW.Format.FormatGold(totalGold), 0.2, 1, 0.2)
    GameTooltip:AddLine(" ")

    if warbandGold > 0 then
        GameTooltip:AddLine(L["GOLD_TOOLTIP_WARBAND"] .. " - " .. OneWoW.Format.FormatGold(warbandGold), 0.6, 0.8, 1)
    end

    local displayCount = min(#altList, MAX_ALT_DISPLAY)
    local othersCount = #altList - displayCount
    local othersGold = 0

    for i = 1, #altList do
        if i <= displayCount then
            GameTooltip:AddLine(altList[i].name .. " - " .. OneWoW.Format.FormatGold(altList[i].money), 0.8, 0.8, 0.8)
        else
            othersGold = othersGold + altList[i].money
        end
    end

    if othersCount > 0 then
        GameTooltip:AddLine(string.format(L["GOLD_TOOLTIP_OTHERS"], othersCount) .. " - " .. OneWoW.Format.FormatGold(othersGold), 0.5, 0.5, 0.5)
    end
end

-- Shared 75/80/90/95/100% bands for wallet, weekly earn, and seasonal total-earned pressure.
local function GetCapStyleLevelFromRatio(current, maxQ)
    if not maxQ or maxQ <= 0 then
        return 0
    end
    local q = current or 0
    if q >= maxQ then
        return 5
    end
    local pct = q / maxQ
    if pct < 0.75 then
        return 0
    end
    if pct < 0.80 then
        return 1
    end
    if pct < 0.90 then
        return 2
    end
    if pct < 0.95 then
        return 3
    end
    return 4
end

local function GetWalletCapStyleLevel(info)
    if not info or not info.maxQuantity or info.maxQuantity <= 0 then
        return 0
    end
    return GetCapStyleLevelFromRatio(info.quantity, info.maxQuantity)
end

local function GetWeeklyEarnCapStyleLevel(info)
    if not info or not info.canEarnPerWeek or not info.maxWeeklyQuantity or info.maxWeeklyQuantity <= 0 then
        return 0
    end
    return GetCapStyleLevelFromRatio(info.quantityEarnedThisWeek, info.maxWeeklyQuantity)
end

-- Seasonal / moving cap: totalEarned vs maxQuantity when useTotalEarnedForMaxQty (not weekly fields).
local function GetSeasonEarnCapStyleLevel(info)
    if not info or not info.useTotalEarnedForMaxQty or not info.maxQuantity or info.maxQuantity <= 0 then
        return 0
    end
    return GetCapStyleLevelFromRatio(info.totalEarned, info.maxQuantity)
end

local function GetCurrencyCapStyleLevel(info)
    if not info then
        return 0
    end
    return max(
        GetWalletCapStyleLevel(info),
        GetWeeklyEarnCapStyleLevel(info),
        GetSeasonEarnCapStyleLevel(info)
    )
end

local function GetTrackerDisplayState(entry)
    local countValue, iconTexture, capLevel = 0, nil, 0
    if entry.type == "item" then
        countValue = C_Item.GetItemCount(entry.id, true)
        iconTexture = C_Item.GetItemIconByID(entry.id)
    elseif entry.type == "currency" then
        local info = C_CurrencyInfo.GetCurrencyInfo(entry.id)
        if info then
            iconTexture = info.iconFileID
            countValue = info.quantity or 0
            if GetDB().global.showCurrencyTrackerCapHighlight then
                capLevel = GetCurrencyCapStyleLevel(info)
            end
        end
    end
    return countValue, iconTexture, capLevel
end

local function EnsureCurrencyCapGlow(tf)
    if tf.capGlowTex then
        return
    end
    local glowCfg = Constants.TRACKER_CURRENCY_CAP_GLOW
    local tex = tf:CreateTexture(nil, "BACKGROUND", nil, 1)
    tex:SetPoint("TOPLEFT", tf, "TOPLEFT", -3, 3)
    tex:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", 3, -3)
    tex:SetAtlas("bags-glow-white")
    tex:SetBlendMode("ADD")
    tex:SetVertexColor(glowCfg.vertex[1], glowCfg.vertex[2], glowCfg.vertex[3])
    tex:Hide()
    tf.capGlowTex = tex

    local ag = tex:CreateAnimationGroup()
    local up = ag:CreateAnimation("Alpha")
    up:SetOrder(1)
    up:SetDuration(0.85)
    up:SetSmoothing("IN_OUT")
    up:SetFromAlpha(glowCfg.alphaMin)
    up:SetToAlpha(glowCfg.alphaMax)
    local down = ag:CreateAnimation("Alpha")
    down:SetOrder(2)
    down:SetDuration(0.85)
    down:SetSmoothing("IN_OUT")
    down:SetFromAlpha(glowCfg.alphaMax)
    down:SetToAlpha(glowCfg.alphaMin)
    ag:SetLooping("REPEAT")
    tf.capGlowAnim = ag
end

local function ApplyCurrencyCapTrackerStyle(tf)
    if not tf or not tf.trackType or not tf.trackId or not tf.countText then
        return
    end
    local entry = { type = tf.trackType, id = tf.trackId }
    local _, _, capLevel = GetTrackerDisplayState(entry)

    if entry.type ~= "currency" or capLevel == 0 then
        tf:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        tf:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        tf.countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        if tf.capGlowTex then
            tf.capGlowTex:Hide()
            if tf.capGlowAnim and tf.capGlowAnim:IsPlaying() then
                tf.capGlowAnim:Stop()
            end
        end
        return
    end

    local pack = Constants.TRACKER_CURRENCY_CAP[capLevel]
    if not pack then
        return
    end
    tf:SetBackdropColor(unpack(pack.bg))
    tf:SetBackdropBorderColor(unpack(pack.border))
    tf.countText:SetTextColor(unpack(pack.countText))

    if capLevel == 5 then
        EnsureCurrencyCapGlow(tf)
        local glowCfg = Constants.TRACKER_CURRENCY_CAP_GLOW
        tf.capGlowTex:SetVertexColor(glowCfg.vertex[1], glowCfg.vertex[2], glowCfg.vertex[3])
        tf.capGlowTex:SetAlpha(glowCfg.alphaMin)
        tf.capGlowTex:Show()
        if tf.capGlowAnim and not tf.capGlowAnim:IsPlaying() then
            tf.capGlowAnim:Play()
        end
    else
        if tf.capGlowTex then
            tf.capGlowTex:Hide()
            if tf.capGlowAnim and tf.capGlowAnim:IsPlaying() then
                tf.capGlowAnim:Stop()
            end
        end
    end
end

local function EnsureTrackerReorder()
    if trackerReorder then return trackerReorder end
    trackerReorder = OneWoW_GUI:CreateReorderDrag({
        getItems = function()
            return bagsBarFrame and bagsBarFrame.trackerFrames or nil
        end,
        onReorder = function(from, to)
            local controller = GetController()
            if controller and controller.MoveTrackedEntry then
                controller:MoveTrackedEntry(from, to)
            end
        end,
        onPickup = function(tf)
            ---@diagnostic disable-next-line: undefined-field
            tf:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
        end,
        onRestore = function(tf)
            ApplyCurrencyCapTrackerStyle(tf)
        end,
        onHover = function(tf)
            ---@diagnostic disable-next-line: undefined-field
            tf:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end,
        onUnhover = function(tf)
            ApplyCurrencyCapTrackerStyle(tf)
        end,
    })
    return trackerReorder
end

function BagsBar:CreateTrackerFrame(parentFrame, index, entry)
    local cellW = Constants.GUI.TRACKER_CELL_WIDTH
    local cellH = Constants.GUI.TRACKER_CELL_HEIGHT
    local tf = OneWoW_GUI:CreateFrame(parentFrame, {
        width = cellW,
        height = cellH,
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })

    local countValue, iconTexture = GetTrackerDisplayState(entry)

    local iconFrame = OneWoW_GUI:CreateSkinnedIcon(tf, {
        size = 16,
        preset = "clean",
        iconTexture = iconTexture,
    })
    iconFrame:SetPoint("LEFT", tf, "LEFT", 4, 0)
    iconFrame:EnableMouse(false)
    tf.iconFrame = iconFrame

    local countText = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("RIGHT", tf, "RIGHT", -4, 0)
    countText:SetJustifyH("RIGHT")
    countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    countText:SetText(L["COUNT_PREFIX"] .. countValue)
    tf.countText = countText

    tf.trackType = entry.type
    tf.trackId = entry.id
    tf.trackerIndex = index

    local capturedIdx = index
    local reorder = EnsureTrackerReorder()
    tf:EnableMouse(true)
    tf:SetScript("OnMouseDown", function(myself, button)
        if button == "RightButton" then
            MenuUtil.CreateContextMenu(myself, function(_, rootDescription)
                rootDescription:CreateButton(L["TRACKER_MENU_REMOVE"], function()
                    local controller = GetController()
                    if controller and controller.RemoveTrackedEntry then
                        controller:RemoveTrackedEntry(capturedIdx)
                    end
                end)
            end)
        end
    end)
    reorder:Attach(tf, capturedIdx)

    if entry.type == "item" then
        tf:SetScript("OnEnter", function(myself)
            if reorder:IsActive() then
                return
            end
            GameTooltip:SetOwner(myself, "ANCHOR_TOP")
            GameTooltip:SetItemByID(entry.id)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["TRACKER_HINT_DRAG_REORDER"], 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(L["TRACKER_HINT_REMOVE"], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
    elseif entry.type == "currency" then
        tf:SetScript("OnEnter", function(myself)
            if reorder:IsActive() then
                return
            end
            GameTooltip:SetOwner(myself, "ANCHOR_TOP")
            GameTooltip:SetCurrencyByID(entry.id)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["TRACKER_HINT_DRAG_REORDER"], 0.7, 0.7, 0.7, true)
            GameTooltip:AddLine(L["TRACKER_HINT_REMOVE"], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
    end
    tf:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    ApplyCurrencyCapTrackerStyle(tf)

    return tf
end

function BagsBar:RefreshTrackerCounts()
    if not bagsBarFrame or not bagsBarFrame.trackerFrames then return end
    for _, tf in ipairs(bagsBarFrame.trackerFrames) do
        if tf.countText and tf.trackType and tf.trackId then
            local entry = { type = tf.trackType, id = tf.trackId }
            local countValue = select(1, GetTrackerDisplayState(entry))
            tf.countText:SetText(L["COUNT_PREFIX"] .. countValue)
            ApplyCurrencyCapTrackerStyle(tf)
        end
    end
end

function BagsBar:UpdateTrackers()
    if not bagsBarFrame or not bagsBarFrame.trackerLayoutHost then return end

    local db = GetDB()
    local host = bagsBarFrame.trackerLayoutHost
    local row2Frame = bagsBarFrame.row2Frame

    local barW = host:GetWidth()
    if barW < 1 then
        barW = row2Frame:GetWidth()
    end
    if barW < 1 then
        barW = bagsBarFrame:GetWidth()
    end

    if barW < 1 then
        if not bagsBarFrame._trackerLayoutRetry then
            bagsBarFrame._trackerLayoutRetry = true
            C_Timer.After(0, function()
                if bagsBarFrame then
                    bagsBarFrame._trackerLayoutRetry = nil
                end
                BagsBar:UpdateTrackers()
            end)
        end
        return
    end

    for _, tf in ipairs(bagsBarFrame.trackerFrames) do
        tf:Hide()
        tf:ClearAllPoints()
        tf:SetParent(UIParent)
    end
    bagsBarFrame.trackerFrames = {}

    local trackers = db.global.trackedCurrencies
    local n = #trackers

    local cellW = Constants.GUI.TRACKER_CELL_WIDTH
    local cellH = Constants.GUI.TRACKER_CELL_HEIGHT
    local cellGap = Constants.GUI.TRACKER_CELL_GAP
    local cellStride = cellW + cellGap
    local leftInset, rightInset = WH:GetItemGridChromeInsets(db.global.hideScrollBar)

    local innerW = barW - leftInset - rightInset
    local perRow = max(1, floor(innerW / cellStride))
    local trackerRows = 0
    if n > 0 then
        trackerRows = ceil(n / perRow)
    end

    local trackerBandH = trackerRows * ROW2_HEIGHT
    host:SetHeight(trackerBandH)
    row2Frame:SetHeight(ROW2_HEIGHT + trackerBandH)

    local yPad = (ROW2_HEIGHT - cellH) / 2
    for i = 1, n do
        local tf = BagsBar:CreateTrackerFrame(host, i, trackers[i])
        local row = ceil(i / perRow)
        local col = (i - 1) % perRow + 1
        local x = leftInset + (col - 1) * cellStride
        local y = -((row - 1) * ROW2_HEIGHT) - yPad
        tf:SetPoint("TOPLEFT", host, "TOPLEFT", x, y)
        tinsert(bagsBarFrame.trackerFrames, tf)
        tf:Show()
    end

    SyncBagsBarOuterHeight()
end

local function GetBagLabel(bagIndex)
    return L[BagTypes:GetBagName(bagIndex)]
end

local function GetCompatibleBagEntries(targetBagIndex)
    local entries = {}
    BagEquip:EnumerateCompatibleBags(targetBagIndex, function(sourceBagID, slot, itemID)
        tinsert(entries, {
            sourceBagID = sourceBagID,
            slot = slot,
            itemID = itemID,
            name = C_Item.GetItemNameByID(itemID) or ("#" .. itemID),
        })
    end)
    sort(entries, function(a, b)
        return a.name < b.name
    end)
    return entries
end

local function AddDisabledMenuButton(parentDescription, label)
    local buttonDescription = parentDescription:CreateButton(label, function() end)
    if buttonDescription and buttonDescription.SetEnabled then
        buttonDescription:SetEnabled(false)
    end
end

local function AddEmptyBagMenu(rootDescription, bagIndex)
    if not BagTypes:IsBagEquipped(bagIndex) then
        return
    end

    if not BagEquip:CanEmpty(bagIndex) then
        AddDisabledMenuButton(rootDescription, L["BAG_MENU_EMPTY"])
        return
    end

    local emptySub = rootDescription:CreateButton(L["BAG_MENU_EMPTY"], function() end)
    if BagEquip:CanEmptyTo(bagIndex, nil) then
        emptySub:CreateButton(L["BAG_MENU_EMPTY_AUTO"], function()
            BagEquip:EmptyBag(bagIndex, nil)
        end)
    else
        AddDisabledMenuButton(emptySub, L["BAG_MENU_EMPTY_AUTO"])
    end

    for _, dest in ipairs(BagEquip:GetEmptyDestinations(bagIndex)) do
        if BagEquip:CanEmptyTo(bagIndex, dest.bagIndex) then
            emptySub:CreateButton(dest.label, function()
                BagEquip:EmptyBag(bagIndex, dest.bagIndex)
            end)
        else
            AddDisabledMenuButton(emptySub, dest.label)
        end
    end
end

local function ShowBagSlotContextMenu(owner, bagIndex)
    local controller = GetController()
    if not controller then
        return
    end

    MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
        rootDescription:CreateTitle(GetBagLabel(bagIndex))

        local selected = controller:GetSelectedBag()
        local canFilter = not BagTypes:IsSwappableBag(bagIndex) or BagTypes:IsBagEquipped(bagIndex)

        if canFilter then
            if selected == bagIndex then
                rootDescription:CreateButton(L["BAG_MENU_SHOW_ALL"], function()
                    controller:ClearBagFilter()
                end)
            else
                rootDescription:CreateButton(L["BAG_MENU_SHOW_ONLY"], function()
                    controller:ShowOnlyBag(bagIndex)
                end)
            end
        end

        AddEmptyBagMenu(rootDescription, bagIndex)

        if not BagTypes:IsSwappableBag(bagIndex) then
            return
        end

        if BagTypes:IsBagEquipped(bagIndex) then
            if BagEquip:CanPickup(bagIndex) then
                rootDescription:CreateButton(L["BAG_MENU_PICKUP"], function()
                    BagEquip:PickupEquipped(bagIndex)
                end)
            else
                AddDisabledMenuButton(rootDescription, L["BAG_MENU_PICKUP"])
            end
        end

        if not BagEquip:CanSwap(bagIndex) then
            AddDisabledMenuButton(rootDescription, L["BAG_MENU_SWAP"])
        else
            local swapSub = rootDescription:CreateButton(L["BAG_MENU_SWAP"], function() end)
            local compatible = GetCompatibleBagEntries(bagIndex)
            if #compatible == 0 then
                AddDisabledMenuButton(swapSub, L["BAG_SWAP_NONE"])
            else
                for _, entry in ipairs(compatible) do
                    swapSub:CreateButton(entry.name, function()
                        BagEquip:EquipFromContainer(entry.sourceBagID, entry.slot, bagIndex)
                    end)
                end
            end
        end
    end)
end

function BagsBar:CreateBagButton(parent, bagIndex, xOffset)
    local iconTexture = "Interface\\Buttons\\Button-Backpack-Up"
    if BagTypes:IsSwappableBag(bagIndex) then
        iconTexture = EMPTY_BAG_TEXTURE
    end

    local btn = CreateFrame("Button", "OneWoW_BagSlot" .. bagIndex, parent)
    btn:SetSize(26, 26)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconTexture)
    btn.icon = icon
    btn.Icon = icon
    btn._skinnedIcon = icon
    OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })
    if ns.Masque then
        ns.Masque:SkinBagBarButton(btn, "bags")
    end

    btn:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    btn.bagIndex = bagIndex

    ApplyBagButtonIcon(btn, bagIndex)

    btn:SetScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_TOP")
        local controller = GetController()
        local selected = controller and controller.GetSelectedBag and controller:GetSelectedBag() or nil
        if myself.bagIndex == 0 then
            GameTooltip:SetText(BACKPACK_TOOLTIP or L["BAG_BACKPACK"], 1.0, 1.0, 1.0)
        else
            local invID = C_Container.ContainerIDToInventoryID(myself.bagIndex)
            if invID and BagTypes:IsBagEquipped(myself.bagIndex) and GetInventoryItemTexture("player", invID) then
                GameTooltip:SetInventoryItem("player", invID)
            else
                local title = BagTypes:IsReagentBag(myself.bagIndex) and EQUIP_CONTAINER_REAGENT or EQUIP_CONTAINER
                GameTooltip:SetText(title, 1.0, 1.0, 1.0)
                GameTooltip:AddLine(L["BAG_SLOT_EMPTY"], 0.7, 0.7, 0.7, true)
            end
        end
        if BagTypes:IsBagEquipped(myself.bagIndex) then
            if selected == myself.bagIndex then
                GameTooltip:AddLine(L["BAG_FILTER_ACTIVE"]:format(OneWoW.Locale:GetOptional(ADDON_NAME, "BAG_" .. myself.bagIndex) or ("Bag " .. myself.bagIndex)), 0.5, 1, 0.5, true)
                GameTooltip:AddLine(L["BAG_SHOW_ALL"], 0.7, 0.7, 0.7, true)
            else
                GameTooltip:AddLine(L["BAG_SHOW_ONLY"], 0.7, 0.7, 0.7, true)
            end
            if BagTypes:IsSwappableBag(myself.bagIndex) then
                GameTooltip:AddLine(L["BAG_HINT_DRAG_PICKUP"], 0.7, 0.7, 0.7, true)
            end
            GameTooltip:AddLine(L["RIGHT_CLICK_FOR_MORE_OPTIONS"], 0.7, 0.7, 0.7, true)
        elseif BagTypes:IsSwappableBag(myself.bagIndex) then
            GameTooltip:AddLine(L["RIGHT_CLICK_FOR_MORE_OPTIONS"], 0.7, 0.7, 0.7, true)
        end
        if BagTypes:IsSwappableBag(myself.bagIndex) or not BagTypes:IsBagEquipped(myself.bagIndex) then
            GameTooltip:AddLine(L["BAG_HINT_DRAG_EQUIP"], 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(myself, button)
        if button == "RightButton" then
            ShowBagSlotContextMenu(myself, myself.bagIndex)
            return
        end
        if BagTypes:IsSwappableBag(myself.bagIndex) and BagEquip:CursorHasItem() then
            BagEquip:EquipCursorBag(myself.bagIndex)
            return
        end
        local controller = GetController()
        if controller and controller.ToggleSelectedBag then
            controller:ToggleSelectedBag(myself.bagIndex)
        end
    end)

    if BagTypes:IsSwappableBag(bagIndex) then
        btn:RegisterForDrag("LeftButton")
        btn:SetScript("OnDragStart", function(myself)
            BagEquip:PickupEquipped(myself.bagIndex)
        end)
        btn:SetScript("OnReceiveDrag", function(myself)
            BagEquip:EquipCursorBag(myself.bagIndex)
        end)
    end

    return btn
end

function BagsBar:UpdateBagHighlights()
    local controller = GetController()
    local selected = controller and controller.GetSelectedBag and controller:GetSelectedBag() or nil
    local masque = ns.Masque
    local masqueActive = masque and masque:IsActive()
    for idx, btn in pairs(bagButtons) do
        local isSelected = selected ~= nil and selected == idx
        if masqueActive then
            masque:UpdateBagBarSelection(btn, isSelected)
        elseif btn._skinBorder then
            if isSelected then
                btn._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                btn._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            end
        elseif btn.border then
            if isSelected then
                btn.border:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                btn.border:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
            end
        end
    end
end

function BagsBar:UpdateIcons()
    for bagIndex, btn in pairs(bagButtons) do
        ApplyBagButtonIcon(btn, bagIndex)
    end
end

function BagsBar:UpdateFreeSlots(free, total)
    if not bagsBarFrame or not bagsBarFrame.freeSlots then return end
    bagsBarFrame.freeSlots:SetText(string.format("%d/%d", free, total))
end

function BagsBar:GetFrame()
    return bagsBarFrame
end

function BagsBar:SetShown(show)
    if bagsBarFrame then
        if not show and trackerReorder then
            trackerReorder:Cancel()
        end
        bagsBarFrame:SetShown(show)
    end
end

function BagsBar:UpdateChromeAnchors()
    if not bagsBarFrame or not bagsBarFrame.row1Frame then return end
    local db = GetDB()
    local leftInset, rightInset = WH:GetItemGridChromeInsets(db.global.hideScrollBar)
    local row1Frame = bagsBarFrame.row1Frame
    local toolbarBand = bagsBarFrame.toolbarBand

    if bagsBarFrame.trackerControlCluster and toolbarBand then
        bagsBarFrame.trackerControlCluster:ClearAllPoints()
        bagsBarFrame.trackerControlCluster:SetPoint("LEFT", toolbarBand, "LEFT", leftInset, 0)
    end

    local xOffset = leftInset
    for _, bagID in ipairs(BagTypes:GetPlayerBagIDs()) do
        if not BagTypes:IsReagentBag(bagID) then
            local bagSlot = bagButtons[bagID]
            if bagSlot then
                bagSlot:ClearAllPoints()
                bagSlot:SetPoint("LEFT", row1Frame, "LEFT", xOffset, 0)
            end
            xOffset = xOffset + 30
        else
            if bagsBarFrame.reagentSeparator then
                bagsBarFrame.reagentSeparator:ClearAllPoints()
                bagsBarFrame.reagentSeparator:SetPoint("LEFT", row1Frame, "LEFT", xOffset + 2, 0)
            end
            xOffset = xOffset + 6
            local bagSlot = bagButtons[bagID]
            if bagSlot then
                bagSlot:ClearAllPoints()
                bagSlot:SetPoint("LEFT", row1Frame, "LEFT", xOffset, 0)
            end
            xOffset = xOffset + 30
        end
    end

    if bagsBarFrame.freeSlots then
        bagsBarFrame.freeSlots:ClearAllPoints()
        bagsBarFrame.freeSlots:SetPoint("RIGHT", row1Frame, "RIGHT", -rightInset, 0)
    end
    if bagsBarFrame.goldBtn and toolbarBand then
        bagsBarFrame.goldBtn:ClearAllPoints()
        bagsBarFrame.goldBtn:SetPoint("RIGHT", toolbarBand, "RIGHT", -rightInset, 0)
    end
end

function BagsBar:UpdateRowVisibility()
    if not bagsBarFrame then return end

    local db = GetDB()
    local altShow = ns:IsAltShowActive()
    local showBagsBar = db.global.showBagsBar ~= false
    local showMoney = db.global.showMoneyBar ~= false
    local showRow1 = showBagsBar
    if altShow then
        showRow1 = true
        showMoney = true
    end

    if bagsBarFrame.row1Frame then
        bagsBarFrame.row1Frame:SetShown(showRow1)
    end

    if bagsBarFrame.goldBtn then
        bagsBarFrame.goldBtn:SetShown(showMoney)
    end

    if bagsBarFrame.row2Frame then
        bagsBarFrame.row2Frame:SetShown(true)
    end

    bagsBarFrame:Show()

    bagsBarFrame.row2Frame:ClearAllPoints()
    bagsBarFrame.row2Frame:SetPoint("BOTTOMLEFT", bagsBarFrame, "BOTTOMLEFT", 0, 0)
    bagsBarFrame.row2Frame:SetPoint("BOTTOMRIGHT", bagsBarFrame, "BOTTOMRIGHT", 0, 0)

    if showRow1 then
        bagsBarFrame.row1Frame:ClearAllPoints()
        bagsBarFrame.row1Frame:SetPoint("TOPLEFT", bagsBarFrame, "TOPLEFT", 0, 0)
        bagsBarFrame.row1Frame:SetPoint("TOPRIGHT", bagsBarFrame, "TOPRIGHT", 0, 0)
    end

    BagsBar:UpdateChromeAnchors()
    BagsBar:UpdateTrackers()
end

function BagsBar:GetTrackerControlCluster()
    return bagsBarFrame and bagsBarFrame.trackerControlCluster or nil
end

function BagsBar:Reset()
    if trackerReorder then
        trackerReorder:Cancel()
    end
    if trackerDialog then
        trackerDialog.frame:Hide()
    end
    if bagsBarFrame then
        bagsBarFrame:Hide()
        bagsBarFrame:SetParent(UIParent)
    end
    bagsBarFrame = nil
    bagButtons = {}
    if eventFrame then
        eventFrame:UnregisterAllEvents()
        eventFrame = nil
    end
end
