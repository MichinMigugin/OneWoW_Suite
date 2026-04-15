local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local StorageAPI = _G.StorageAPI

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local BagTypes = OneWoW_Bags.BagTypes
local WH = OneWoW_Bags.WindowHelpers

local tinsert, sort = tinsert, sort
local pairs, ipairs = pairs, ipairs
local min, max, ceil, floor = math.min, math.max, math.ceil, math.floor
local C_Timer = C_Timer
local C_Item = C_Item
local C_CurrencyInfo = C_CurrencyInfo
local C_Container = C_Container

OneWoW_Bags.BagsBar = {}
local BagsBar = OneWoW_Bags.BagsBar

local bagsBarFrame = nil
local bagButtons = {}
local eventFrame = nil
local trackerDialog = nil

local ROW1_HEIGHT = 32
local ROW2_HEIGHT = 26
local MAX_ALT_DISPLAY = 10
local trackerRelayoutPending = false

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetController()
    return OneWoW_Bags.BagsController
end

local function SyncBagsBarOuterHeight()
    if not bagsBarFrame then return end
    local db = GetDB()
    local altShow = OneWoW_Bags:IsAltShowActive()
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
                { text = L["POPUP_ADD"], onClick = function() doAdd() end },
                { text = L["POPUP_CANCEL"], onClick = function(frame) frame:Hide() end },
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
    bagsBarFrame.goldText:SetText(OneWoW_GUI:FormatGold(GetMoney()))
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
    controlCluster:SetWidth(72)
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
    addTrackerBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["TRACKER_ADD"], 1, 1, 1)
        GameTooltip:AddLine(L["TRACKER_ADD_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addTrackerBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    addTrackerBtn:RegisterForDrag("LeftButton")
    addTrackerBtn:SetScript("OnReceiveDrag", function(self)
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

    local cleanupBagsBtn = OneWoW_GUI:CreateAtlasIconButton(controlCluster, {
        atlas = "crosshair_ui-cursor-broom_32",
        width = 20,
        height = 20,
    })
    cleanupBagsBtn:SetPoint("LEFT", addTrackerBtn, "RIGHT", 4, 0)
    cleanupBagsBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.SortBags then
            controller:SortBags()
        end
    end)
    cleanupBagsBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["CLEANUP"], 1, 1, 1)
        GameTooltip:Show()
    end)
    cleanupBagsBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    bagsBarFrame.cleanupBagsBtn = cleanupBagsBtn

    local categoriesBtn = OneWoW_GUI:CreateAtlasIconButton(controlCluster, {
        atlas = "housing-sidetabs-catalog-active",
        width = 20,
        height = 20,
    })
    categoriesBtn:SetPoint("LEFT", cleanupBagsBtn, "RIGHT", 4, 0)
    categoriesBtn:SetScript("OnClick", function()
        local controller = GetController()
        if controller and controller.ToggleCategoryManager then
            controller:ToggleCategoryManager()
        end
    end)
    categoriesBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["CATEGORY_MANAGER_BTN"], 1, 1, 1)
        GameTooltip:Show()
    end)
    categoriesBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
    bagsBarFrame.categoriesBtn = categoriesBtn

    local goldBtn = CreateFrame("Button", nil, toolbarBand)
    goldBtn:SetHeight(20)
    goldBtn:SetPoint("RIGHT", toolbarBand, "RIGHT", -bagsBarRightInset, 0)

    local goldText = goldBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", goldBtn, "RIGHT", 0, 0)
    bagsBarFrame.goldText = goldText
    BagsBar:UpdateGoldDisplay()

    goldBtn:SetWidth(max(goldText:GetStringWidth() + 4, 60))
    goldBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
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

    if not _G.OneWoW_AltTracker_Character_API then
        GameTooltip:SetText(L["GOLD_TOOLTIP_PERSONAL"], 1, 0.82, 0)
        GameTooltip:AddLine(OneWoW_GUI:FormatGold(personalCopper), 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["GOLD_TOOLTIP_NO_ALTTRACKER"], 0.5, 0.5, 0.5, true)
        return
    end

    local allChars = OneWoW_AltTracker_Character_API.GetAllCharacters()
    local currentKey = OneWoW_AltTracker_Character_API.GetCurrentCharacterKey()
    local warbandGold = (StorageAPI and StorageAPI.GetWarbandBankGold) and StorageAPI.GetWarbandBankGold() or 0

    local altList = {}
    local totalGold = 0
    for _, entry in ipairs(allChars) do
        local money = entry.data.money or 0
        totalGold = totalGold + money
        if entry.key ~= currentKey then
            tinsert(altList, { name = entry.key:match("^([^%-]+)") or entry.key, money = money })
        end
    end
    totalGold = totalGold + warbandGold

    sort(altList, function(a, b) return a.money > b.money end)

    GameTooltip:SetText(L["GOLD_TOOLTIP_PERSONAL"] .. " - " .. OneWoW_GUI:FormatGold(personalCopper), 1, 0.82, 0)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L["GOLD_TOOLTIP_TOTAL"] .. " - " .. OneWoW_GUI:FormatGold(totalGold), 0.2, 1, 0.2)
    GameTooltip:AddLine(" ")

    if warbandGold > 0 then
        GameTooltip:AddLine(L["GOLD_TOOLTIP_WARBAND"] .. " - " .. OneWoW_GUI:FormatGold(warbandGold), 0.6, 0.8, 1)
    end

    local displayCount = min(#altList, MAX_ALT_DISPLAY)
    local othersCount = #altList - displayCount
    local othersGold = 0

    for i = 1, #altList do
        if i <= displayCount then
            GameTooltip:AddLine(altList[i].name .. " - " .. OneWoW_GUI:FormatGold(altList[i].money), 0.8, 0.8, 0.8)
        else
            othersGold = othersGold + altList[i].money
        end
    end

    if othersCount > 0 then
        GameTooltip:AddLine(string.format(L["GOLD_TOOLTIP_OTHERS"], othersCount) .. " - " .. OneWoW_GUI:FormatGold(othersGold), 0.5, 0.5, 0.5)
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

    local capturedIdx = index
    tf:EnableMouse(true)
    tf:SetScript("OnMouseDown", function(self, button)
        if button ~= "RightButton" then return end
        MenuUtil.CreateContextMenu(self, function(_, rootDescription)
            rootDescription:CreateButton(L["TRACKER_MENU_REMOVE"], function()
                local controller = GetController()
                if controller and controller.RemoveTrackedEntry then
                    controller:RemoveTrackedEntry(capturedIdx)
                end
            end)
        end)
    end)

    if entry.type == "item" then
        tf:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetItemByID(entry.id)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L["TRACKER_HINT_REMOVE"], 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
    elseif entry.type == "currency" then
        tf:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetCurrencyByID(entry.id)
            GameTooltip:AddLine(" ")
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

function BagsBar:CreateBagButton(parent, bagIndex, xOffset)
    local iconTexture
    if bagIndex == 0 then
        iconTexture = "Interface\\Buttons\\Button-Backpack-Up"
    else
        local invSlotID = C_Container.ContainerIDToInventoryID(bagIndex)
        if invSlotID then
            iconTexture = GetInventoryItemTexture("player", invSlotID) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
        else
            iconTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
        end
    end

    local btn = CreateFrame("Button", "OneWoW_BagSlot" .. bagIndex, parent)
    btn:SetSize(26, 26)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(iconTexture)
    btn.icon = icon
    btn._skinnedIcon = icon
    OneWoW_GUI:SkinIconFrame(btn, { preset = "clean" })

    btn:SetPoint("LEFT", parent, "LEFT", xOffset, 0)
    btn.bagIndex = bagIndex

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local controller = GetController()
        local selected = controller and controller.GetSelectedBag and controller:GetSelectedBag() or nil
        if self.bagIndex == 0 then
            GameTooltip:SetText(BACKPACK_TOOLTIP or L["BAG_BACKPACK"], 1.0, 1.0, 1.0)
        else
            local invID = C_Container.ContainerIDToInventoryID(self.bagIndex)
            if invID then
                GameTooltip:SetInventoryItem("player", invID)
            end
        end
        if selected == self.bagIndex then
            GameTooltip:AddLine(L["BAG_FILTER_ACTIVE"]:format(L["BAG_" .. self.bagIndex] or ("Bag " .. self.bagIndex)), 0.5, 1, 0.5, true)
            GameTooltip:AddLine(L["BAG_SHOW_ALL"], 0.7, 0.7, 0.7, true)
        else
            GameTooltip:AddLine(L["BAG_SHOW_ONLY"], 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function(self)
        local controller = GetController()
        if controller and controller.ToggleSelectedBag then
            controller:ToggleSelectedBag(self.bagIndex)
        end
    end)

    return btn
end

function BagsBar:UpdateBagHighlights()
    local db = GetDB()
    local selected = db.global.selectedBag
    for idx, btn in pairs(bagButtons) do
        if btn._skinBorder then
            if selected ~= nil and selected == idx then
                btn._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                btn._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            end
        elseif btn.border then
            if selected ~= nil and selected == idx then
                btn.border:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                btn.border:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
            end
        end
    end
end

function BagsBar:UpdateIcons()
    for bagIndex, btn in pairs(bagButtons) do
        if bagIndex > 0 then
            local invSlotID = C_Container.ContainerIDToInventoryID(bagIndex)
            if invSlotID then
                local texID = GetInventoryItemTexture("player", invSlotID) or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
                OneWoW_GUI:UpdateIconTexture(btn, texID)
            end
        end
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
    local altShow = OneWoW_Bags:IsAltShowActive()
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

    if bagsBarFrame.cleanupBagsBtn then
        local showCleanup = (db.global.showHeaderBar ~= false) or altShow
        bagsBarFrame.cleanupBagsBtn:SetShown(showCleanup)
    end

    if bagsBarFrame.categoriesBtn then
        local showCategories = (db.global.showHeaderBar ~= false) or altShow
        bagsBarFrame.categoriesBtn:SetShown(showCategories)
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
