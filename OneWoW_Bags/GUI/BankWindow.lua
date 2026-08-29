local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local Constants = ns.Constants
local WH = ns.WindowHelpers
local BankInfoBar = ns.BankInfoBar
local BankSet = ns.BankSet
local BankCategoryManager = ns.BankCategoryManager
local BankCategoryView = ns.BankCategoryView
local BankBar = ns.BankBar
local BankTabView = ns.BankTabView
local ListView = ns.ListView

local ipairs, pcall = ipairs, pcall

local C_Bank = C_Bank
local C_Timer = C_Timer
local max = math.max

ns.BankGUI = ns.BankGUI or {}
local BankGUI = ns.BankGUI

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local purchasePromptFrame = nil
local lastBuiltBankType = nil
local lastPurchasedTabCount = nil
local forcedPurchasePromptBankType = nil

local PURCHASE_PROMPT_HEIGHT = 280

local function GetDB()
    return ns:GetDB()
end

local function GetLayoutController()
    return ns.WindowLayoutController
end

local function GetActiveBankType()
    local db = GetDB()
    if db and db.global.bankShowWarband then
        return Enum.BankType.Account
    end
    return Enum.BankType.Character
end

local function GetPurchasedTabCount(bankType)
    return C_Bank.FetchNumPurchasedBankTabs(bankType) or 0
end

local function GetPurchasePromptData(bankType, allowPurchasedTabs)
    if not bankType then
        return nil
    end
    if not allowPurchasedTabs and GetPurchasedTabCount(bankType) > 0 then
        return nil
    end
    if not C_Bank.CanPurchaseBankTab(bankType) then
        return nil
    end
    return C_Bank.FetchNextPurchasableBankTabData(bankType)
end

local function GetRequestedPurchasePrompt()
    local activeBankType = GetActiveBankType()
    if forcedPurchasePromptBankType and forcedPurchasePromptBankType == activeBankType then
        return activeBankType, true
    end

    if GetPurchasedTabCount(activeBankType) == 0 then
        return activeBankType, false
    end

    return nil, false
end

local function ShouldShowPurchasePrompt()
    local bankType, allowPurchasedTabs = GetRequestedPurchasePrompt()
    local tabData = GetPurchasePromptData(bankType, allowPurchasedTabs)
    return tabData ~= nil, tabData, bankType
end

local function TrackBuiltBankState()
    lastBuiltBankType = GetActiveBankType()
    lastPurchasedTabCount = GetPurchasedTabCount(lastBuiltBankType)
end

local function ApplyPurchasePromptTheme(promptFrame)
    if not promptFrame then return end

    promptFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    promptFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    promptFrame.inner:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    promptFrame.inner:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    promptFrame.Title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    promptFrame.PromptText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    promptFrame.TabCostFrame.TabCost:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
end

local function UpdatePurchasePromptFrameLevel(promptFrame)
    if not promptFrame or not contentFrame then return end

    local targetLevel = max(contentFrame:GetFrameLevel() + 100, 100)
    promptFrame:SetFrameStrata(MainWindow and MainWindow:GetFrameStrata() or "DIALOG")
    promptFrame:SetFrameLevel(targetLevel)

    if promptFrame.inner then
        promptFrame.inner:SetFrameStrata(promptFrame:GetFrameStrata())
        promptFrame.inner:SetFrameLevel(targetLevel + 1)
    end

    if promptFrame.TabCostFrame then
        promptFrame.TabCostFrame:SetFrameStrata(promptFrame:GetFrameStrata())
        promptFrame.TabCostFrame:SetFrameLevel(targetLevel + 2)
    end
end

function BankGUI:InitMainWindow()
    if isInitialized then return end

    local db = GetDB()
    MainWindow = WH:CreateWindowShell({
        name = "OneWoW_BankMainWindow",
        positionDBKey = "bankFramePosition",
        defaultHeight = Constants.GUI.WINDOW_HEIGHT,
        onHide = function()
            if not isInitialized then return end
            BankGUI._layoutInProgress = false
            forcedPurchasePromptBankType = nil
            BankGUI:RestoreBlizzardPurchaseButton()
            if purchasePromptFrame then
                purchasePromptFrame:Hide()
            end
            BankGUI:CleanupAllViews()
            BankInfoBar:ClearSearch()
            ns.activeBankExpansionFilter = nil
            OneWoW_GUI:SaveWindowPosition(MainWindow, db.global.bankFramePosition)
            if ns.bankOpen then
                ns.bankOpen = false
                ns:ReleaseBlizzardBankPanel()
                BankSet:ReleaseAll()
                C_Timer.After(0, function()
                    C_Bank.CloseBankFrame()
                end)
            end
        end,
        onDragStop = function()
            if isInitialized then ns:RequestLayoutRefresh("bank", "drag_stop") end
        end,
        getScale = function()
            return ns.BankController:Get("scale")
        end,
    })

    if not MainWindow then return end

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    local bankSettingsBtn
    titleBar, bankSettingsBtn = WH:CreateWindowTitleBar(MainWindow, {
        title = BANK,
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
        settingsText = SETTINGS,
        onSettings = function()
            if ns.Settings then
                ns.Settings:Toggle()
            end
        end,
    })
    WH:AttachSuiteTitleBarButtons(titleBar, bankSettingsBtn)
    contentArea = WH:CreateContentArea(MainWindow)

    local infoBar = BankInfoBar:Create(contentArea)
    local bankBar = BankBar:Create(contentArea)
    BankInfoBar:UpdateVisibility()
    BankBar:SetShown(ns.BankController:Get("showBagsBar") ~= false)

    local hideScrollBar = ns.BankController:Get("hideScrollBar")
    contentScrollFrame, contentFrame = WH:CreateScrollScaffold({
        contentArea = contentArea,
        scrollName = "OneWoW_BankContentScroll",
        topAnchor = infoBar,
        bottomAnchor = bankBar,
        hideScrollBar = hideScrollBar,
    })

    WH:SetupResizeButton(MainWindow, BankGUI, "bankFramePosition")
    WH:AttachLayoutOnShow(MainWindow, "bank", function()
        return BankSet.isBuilt
    end)
    isInitialized = true
end

function BankGUI:EnsurePurchasePrompt()
    if purchasePromptFrame or not contentFrame then
        return purchasePromptFrame
    end

    local promptFrame = OneWoW_GUI:CreateFrame(contentFrame, {
        backdrop = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS,
        bgColor = "BG_PRIMARY",
        borderColor = "BORDER_SUBTLE",
    })
    promptFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, 0)
    promptFrame:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, 0)
    promptFrame:SetHeight(PURCHASE_PROMPT_HEIGHT)
    promptFrame:Hide()

    local inner = OneWoW_GUI:CreateFrame(promptFrame, {
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
        bgColor = "BG_SECONDARY",
        borderColor = "BORDER_DEFAULT",
    })
    inner:SetPoint("TOPLEFT", promptFrame, "TOPLEFT", 18, -18)
    inner:SetPoint("TOPRIGHT", promptFrame, "TOPRIGHT", -18, -18)
    inner:SetPoint("BOTTOMLEFT", promptFrame, "BOTTOMLEFT", 18, 18)
    inner:SetPoint("BOTTOMRIGHT", promptFrame, "BOTTOMRIGHT", -18, 18)
    promptFrame.inner = inner

    local title = inner:CreateFontString(nil, "OVERLAY", "QuestFont_Enormous")
    title:SetPoint("TOPLEFT", inner, "TOPLEFT", 30, -44)
    title:SetPoint("TOPRIGHT", inner, "TOPRIGHT", -30, -44)
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")
    title:SetWordWrap(true)
    promptFrame.Title = title

    local promptText = inner:CreateFontString(nil, "OVERLAY", "Game16Font")
    promptText:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
    promptText:SetPoint("TOPRIGHT", title, "BOTTOMRIGHT", 0, -20)
    promptText:SetJustifyH("CENTER")
    promptText:SetJustifyV("TOP")
    promptText:SetWordWrap(true)
    promptFrame.PromptText = promptText

    local tabCostFrame = CreateFrame("Frame", nil, inner)
    tabCostFrame:SetHeight(30)
    tabCostFrame:SetPoint("TOPLEFT", promptText, "BOTTOMLEFT", 0, -22)
    tabCostFrame:SetPoint("TOPRIGHT", promptText, "BOTTOMRIGHT", 0, -22)
    promptFrame.TabCostFrame = tabCostFrame

    local moneyDisplay = CreateFrame("Frame", nil, tabCostFrame, "SmallMoneyFrameTemplate")
    moneyDisplay:SetPoint("CENTER", tabCostFrame, "CENTER", -30, 0)
    SmallMoneyFrame_OnLoad(moneyDisplay)
    MoneyFrame_SetType(moneyDisplay, "STATIC")
    tabCostFrame.MoneyDisplay = moneyDisplay

    local purchaseButtonAnchor = CreateFrame("Frame", nil, tabCostFrame)
    purchaseButtonAnchor:SetSize(105, 21)
    purchaseButtonAnchor:SetPoint("LEFT", moneyDisplay, "RIGHT", 12, 0)
    tabCostFrame.PurchaseButtonAnchor = purchaseButtonAnchor

    local tabCost = tabCostFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalMed3")
    tabCost:SetPoint("RIGHT", moneyDisplay, "LEFT", -10, 0)
    tabCost:SetJustifyH("RIGHT")
    tabCost:SetText(COSTS_LABEL)
    tabCostFrame.TabCost = tabCost

    promptFrame:SetScript("OnShow", function(myself)
        myself:RegisterEvent("PLAYER_MONEY")
    end)
    promptFrame:SetScript("OnHide", function(myself)
        myself:UnregisterEvent("PLAYER_MONEY")
    end)
    promptFrame:SetScript("OnEvent", function()
        if MainWindow and MainWindow:IsShown() then
            ns:RequestLayoutRefresh("bank", "purchase_money")
        end
    end)

    ApplyPurchasePromptTheme(promptFrame)
    UpdatePurchasePromptFrameLevel(promptFrame)
    purchasePromptFrame = promptFrame
    return purchasePromptFrame
end

function BankGUI:AttachBlizzardPurchaseButton(bankType)
    local promptFrame = self:EnsurePurchasePrompt()
    if not promptFrame then return nil end
    if not (BankFrame and BankFrame.BankPanel and BankFrame.BankPanel.PurchasePrompt) then return nil end

    local blizzardButton = BankFrame.BankPanel.PurchasePrompt.TabCostFrame and BankFrame.BankPanel.PurchasePrompt.TabCostFrame.PurchaseButton
    if not blizzardButton then return nil end

    if not promptFrame._originalPurchaseButtonParent then
        promptFrame._originalPurchaseButtonParent = blizzardButton:GetParent()
    end

    blizzardButton:SetParent(promptFrame.TabCostFrame)
    blizzardButton:ClearAllPoints()
    blizzardButton:SetPoint("TOPLEFT", promptFrame.TabCostFrame.PurchaseButtonAnchor, "TOPLEFT", 0, 0)
    blizzardButton:SetPoint("BOTTOMRIGHT", promptFrame.TabCostFrame.PurchaseButtonAnchor, "BOTTOMRIGHT", 0, 0)
    blizzardButton:SetAttribute("overrideBankType", bankType)
    blizzardButton:SetFrameStrata(promptFrame:GetFrameStrata())
    blizzardButton:SetFrameLevel(promptFrame.TabCostFrame:GetFrameLevel() + 1)
    -- Host neutralize disables mouse on the BankPanel tree; re-enable after
    -- hitchhiking the secure purchase button into our prompt.
    blizzardButton:EnableMouse(true)
    blizzardButton:Show()
    promptFrame.TabCostFrame.PurchaseButton = blizzardButton

    return blizzardButton
end

function BankGUI:RestoreBlizzardPurchaseButton()
    if not purchasePromptFrame then return end
    local blizzardButton = purchasePromptFrame.TabCostFrame and purchasePromptFrame.TabCostFrame.PurchaseButton
    local originalParent = purchasePromptFrame._originalPurchaseButtonParent
    if not blizzardButton or not originalParent then return end

    blizzardButton:SetParent(originalParent)
    blizzardButton:ClearAllPoints()
    blizzardButton:SetPoint("LEFT", originalParent.MoneyDisplay, "RIGHT", 12, 0)
    purchasePromptFrame.TabCostFrame.PurchaseButton = nil
end

function BankGUI:ShowPurchasePrompt(bankType)
    forcedPurchasePromptBankType = bankType or GetActiveBankType()
    ns:RequestLayoutRefresh("bank", "purchase_prompt")
end

function BankGUI:ClearForcedPurchasePrompt()
    forcedPurchasePromptBankType = nil
end

function BankGUI:GetPurchasePromptLayoutHeight()
    local shouldShow = ShouldShowPurchasePrompt()
    if shouldShow then
        return PURCHASE_PROMPT_HEIGHT
    end
    return 0
end

function BankGUI:RefreshPurchasePrompt(layoutHeight)
    if not contentFrame then return false end

    local promptFrame = self:EnsurePurchasePrompt()
    if not promptFrame then
        return false
    end

    local shouldShow, tabData, bankType = ShouldShowPurchasePrompt()
    if not shouldShow or not tabData then
        forcedPurchasePromptBankType = nil
        self:RestoreBlizzardPurchaseButton()
        promptFrame:Hide()
        return false
    end

    local purchaseButton = self:AttachBlizzardPurchaseButton(bankType)
    promptFrame:SetHeight(max(layoutHeight or 0, PURCHASE_PROMPT_HEIGHT))
    UpdatePurchasePromptFrameLevel(promptFrame)
    promptFrame.Title:SetText(tabData.purchasePromptTitle or "")
    promptFrame.PromptText:SetText(tabData.purchasePromptBody or "")
    MoneyFrame_Update(promptFrame.TabCostFrame.MoneyDisplay, tabData.tabCost or 0)
    SetMoneyFrameColorByFrame(promptFrame.TabCostFrame.MoneyDisplay, tabData.canAfford and "white" or "red")
    if purchaseButton then
        purchaseButton:SetEnabled(tabData.canAfford and true or false)
        purchaseButton:SetAttribute("overrideBankType", bankType)
    end
    ApplyPurchasePromptTheme(promptFrame)
    promptFrame:Show()

    return true
end

function BankGUI:SyncBuiltTabState()
    local bankType = GetActiveBankType()
    local purchasedTabCount = GetPurchasedTabCount(bankType)

    if not BankSet.isBuilt then
        lastBuiltBankType = bankType
        lastPurchasedTabCount = purchasedTabCount
        return
    end

    if lastBuiltBankType ~= bankType or lastPurchasedTabCount ~= purchasedTabCount then
        forcedPurchasePromptBankType = nil
        -- Build() materializes any newly-purchased tabs and keeps the
        -- cached opposite mode resident; on a pure type change it's a
        -- near no-op that just toggles container-frame visibility.
        BankSet:Build()
    end

    lastBuiltBankType = bankType
    lastPurchasedTabCount = purchasedTabCount
end

local function ReleaseAllViews()
    if BankSet.isBuilt then
        local allButtons = BankSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    BankCategoryView:ReleaseCompactLabels()
    BankCategoryManager:ReleaseAllSections()
end

function BankGUI:CleanupAllViews()
    -- Releasing pooled section frames / labels and hiding item buttons is not a
    -- protected action, so only defer it during combat lockdown. An instanced-map
    -- restriction (Delve) must NOT block cleanup, or stale category headers linger
    -- over the relayout and overlap.
    if OneWoW.Restriction.IsInCombat() then
        -- Defer until lockdown clears, then re-check the window is still hidden:
        -- a re-show in the meantime means the views are live and must be kept.
        OneWoW.Restriction.RunWhenUnrestricted("lockdown", "OneWoW_Bags.cleanup.bank", function()
            if MainWindow and not MainWindow:IsShown() then
                ReleaseAllViews()
            end
        end)
        return
    end

    ReleaseAllViews()
end

function BankGUI:UpdateWindowWidth()
    if not MainWindow then return end
    local controller = GetLayoutController()
    if controller and controller.UpdateFixedWidth then
        local activeKeys = ns.BankController:ActiveKeys()
        controller:UpdateFixedWidth({
            mainWindow = MainWindow,
            columnsKey = activeKeys.columns,
            defaultColumns = 15,
            hideScrollKey = activeKeys.hideScrollBar,
            outerPadding = OneWoW_GUI:GetSpacing("XS"),
        })
    end
end

function BankGUI:RefreshLayout()
    local LD = ns.LayoutDebug
    if not isInitialized or not MainWindow then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "bank", note = "not initialized" }) end
        return
    end
    if not MainWindow:IsShown() then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "bank", note = "frame hidden" }) end
        return
    end
    local db = GetDB()
    local controller = GetLayoutController()
    if not controller or not controller.Refresh then
        if LD and LD.enabled then LD:Record("refresh_early", { target = "bank", note = "no controller" }) end
        return
    end

    local Profile = ns.Profile
    Profile:Start("BankGUI:RefreshLayout")

    WH:RunGuardedLayoutRefresh(BankGUI, "bank", function()
    self:SyncBuiltTabState()

    controller:Refresh({
        layoutDebugTarget = "bank",
        mainWindow = MainWindow,
        isBuilt = function()
            return BankSet.isBuilt
        end,
        updateWindowWidth = function()
            BankGUI:UpdateWindowWidth()
        end,
        beforeLayout = function()
            Profile:Start("BankGUI:RefreshLayout.beforeLayout")
            BankInfoBar:UpdateVisibility()
            BankBar:SetShown(ns.BankController:Get("showBagsBar") ~= false)
            BankBar:RefreshChromeAnchors()
            controller:BindScrollFrame({
                scrollFrame = contentScrollFrame,
                hideScrollBar = ns.BankController:Get("hideScrollBar"),
                topAnchor = BankInfoBar:GetFrame(),
                bottomAnchor = BankBar:GetFrame(),
                contentArea = contentArea,
            })
            Profile:Stop("BankGUI:RefreshLayout.beforeLayout")
        end,
        contentFrame = contentFrame,
        containerFrames = BankSet.bagContainerFrames,
        cleanup = function()
            Profile:Start("BankGUI:RefreshLayout.cleanup")
            BankGUI:CleanupAllViews()
            Profile:Stop("BankGUI:RefreshLayout.cleanup")
        end,
        getButtons = function()
            Profile:Start("BankGUI:RefreshLayout.getButtons")
            local buttons = BankSet:GetAllButtons()
            Profile:Stop("BankGUI:RefreshLayout.getButtons")
            return buttons
        end,
        filterButtons = function(allButtons)
            Profile:Start("BankGUI:RefreshLayout.filterButtons")
            if ShouldShowPurchasePrompt() then
                Profile:Stop("BankGUI:RefreshLayout.filterButtons")
                return {}
            end
            local visibleButtons = WH:FilterByTab(allButtons, ns.BankController:Get("selectedTab"), WH:GetScratchTable("bankTab"))
            local filteredButtons = WH:FilterBySearch(visibleButtons, BankInfoBar:GetSearchText(), WH:GetScratchTable("bankSearch"))
            local result = WH:FilterByExpansion(filteredButtons, ns.activeBankExpansionFilter, WH:GetScratchTable("bankExpansion"))
            Profile:Stop("BankGUI:RefreshLayout.filterButtons")
            return result
        end,
        layoutButtons = function(filteredButtons)
            Profile:Start("BankGUI:RefreshLayout.layoutButtons")
            if ShouldShowPurchasePrompt() then
                Profile:Stop("BankGUI:RefreshLayout.layoutButtons")
                return PURCHASE_PROMPT_HEIGHT
            end
            local columnsKey = ns.BankController:ActiveKeys().columns
            local _, _, _, contentWidth = WH:GetLayoutMetrics(columnsKey)
            local viewMode = ns.BankController:Get("viewMode")
            local layoutHeight
            local bankShowEmpty = ns.BankController:GetShowEmptySlots()
            local categoryViewContext = controller:CreateViewContext({
                sectionManager = BankCategoryManager,
                containerType = db.global.bankShowWarband and "warband_bank" or "character_bank",
                showEmptySlots = bankShowEmpty,
                sortMode = db.global.itemSort,
                getCollapsed = function(kind, key)
                    if kind == "category" then
                        return db.global.collapsedBankCategorySections[key] or db.global.collapsedBankSections[key]
                    end
                    if kind == "section" then
                        local section = db.global.categorySections and db.global.categorySections[key]
                        return section and section.collapsed or false
                    end
                end,
                setCollapsed = function(kind, key, collapsed)
                    if kind == "category" then
                        db.global.collapsedBankCategorySections[key] = collapsed or nil
                    elseif kind == "section" then
                        local section = db.global.categorySections and db.global.categorySections[key]
                        if section then
                            section.collapsed = collapsed
                        end
                    end
                end,
                requestRelayout = function()
                    ns:RequestLayoutRefresh("bank", "relayout")
                end,
            })
            local tabViewContext = controller:CreateViewContext({
                sectionManager = BankCategoryManager,
                showEmptySlots = bankShowEmpty,
                sortMode = db.global.itemSort,
                getCollapsed = function(kind, key)
                    if kind == "tab" then
                        local tabsKey = ns.BankController:ActiveKeys().collapsedTabs
                        local tabs = db.global[tabsKey]
                        return (tabs and tabs[key]) or db.global.collapsedBankSections[key]
                    end
                end,
                setCollapsed = function(kind, key, collapsed)
                    if kind == "tab" then
                        local tabsKey = ns.BankController:ActiveKeys().collapsedTabs
                        db.global[tabsKey] = db.global[tabsKey] or {}
                        db.global[tabsKey][key] = collapsed or nil
                    end
                end,
                requestRelayout = function()
                    ns:RequestLayoutRefresh("bank", "relayout")
                end,
            })

            if viewMode == "category" then
                layoutHeight = BankCategoryView:Layout(contentFrame, contentWidth, filteredButtons, categoryViewContext)
            elseif viewMode == "tab" then
                layoutHeight = BankTabView:Layout(contentFrame, contentWidth, filteredButtons, tabViewContext)
            else
                layoutHeight = ListView:Layout(contentFrame, filteredButtons, contentWidth, categoryViewContext)
            end

            local result = max(layoutHeight, BankGUI:GetPurchasePromptLayoutHeight())
            Profile:Stop("BankGUI:RefreshLayout.layoutButtons")
            return result
        end,
        afterLayout = function(_, layoutHeight)
            BankBar:UpdateFreeSlots(BankSet:GetFreeSlotCount(), BankSet:GetSlotCount())
            BankGUI:RefreshPurchasePrompt(layoutHeight)
        end,
    })
    end)

    Profile:Stop("BankGUI:RefreshLayout")
end

function BankGUI:OnSearchChanged(text)
    -- Dedupe: the search box fires onTextChanged once during open with empty
    -- text, and can re-fire with unchanged text. Those produce a byte-identical
    -- filter result to the layout that already ran (build_done / warm open), so
    -- skip the redundant full relayout. Search text only ever changes through
    -- this handler, so tracking it here stays in sync with GetSearchText().
    text = text or ""
    if text == (self._lastSearchText or "") then return end
    self._lastSearchText = text
    ns:RequestLayoutRefresh("bank", "search")
end

function BankGUI:OnBankTypeChanged()
    local db = GetDB()
    ns.BankController:Set("selectedTab", nil)

    local showWarband = db.global.bankShowWarband

    local newBankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    ns:PrepareBlizzardBankPanel(newBankType)

    -- Mode toggle: Build() now keeps both modes' buttons resident across
    -- toggles (see BankSet.builtTabs). On the first toggle to a given mode
    -- it materializes that mode's tabs; on subsequent toggles it's a near
    -- no-op that just flips container-frame visibility.
    BankSet:Build()
    TrackBuiltBankState()

    BankBar:BuildTabButtons()
    BankBar:UpdateModeButtons()
end

function BankGUI:Show()
    if not isInitialized then
        local ok, initErr = pcall(function() BankGUI:InitMainWindow() end)
        if not ok then
            print("|cffff4444OneWoW_Bags:|r BankWindow init failed:", initErr)
            return
        end
    end

    if not MainWindow then return end

    WH:ApplySavedScaleToWindow(self, ns.BankController:Get("scale"))

    -- Warm path lays out synchronously below, so suppress the OnShow hook's
    -- redundant coalesced refresh that would otherwise fire during Show().
    local warm = BankSet.isBuilt
    if warm then
        ns:SetOnShowLayoutSuppressed("bank", true)
    end

    MainWindow:Show()

    -- BankSet:Build() emits its own RequestLayoutRefresh("bank") on completion.
    -- For the warm path (already built), lay out synchronously so the open is
    -- independent of the coalescer (which can be wedged after a zone load).
    if not warm then
        BankSet:Build()
    else
        ns:ClearPendingLayoutRefresh("BankGUI")
        ns:RequestLayoutRefreshNow("bank")
        ns:SetOnShowLayoutSuppressed("bank", false)
    end
    TrackBuiltBankState()

    ns.BankBar:UpdateModeButtons()
    ns.BankBar:BuildTabButtons()
    ns.BankBar:UpdateGold()

    -- Safety-net refresh: catches late GET_ITEM_INFO_RECEIVED arrivals that
    -- slipped in around Build, and recovers a blank window if the coalescer
    -- latch was wedged. Runs synchronously so it works even when wedged.
    ns:ScheduleOpenSafetyNet("bank", function()
        return MainWindow and MainWindow:IsShown()
    end)
end

function BankGUI:Hide()
    if MainWindow then
        MainWindow:Hide()
    end
    self:RestoreBlizzardPurchaseButton()
    forcedPurchasePromptBankType = nil
    if purchasePromptFrame then
        purchasePromptFrame:Hide()
    end
end

function BankGUI:Toggle()
    if MainWindow and MainWindow:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function BankGUI:IsShown()
    return MainWindow and MainWindow:IsShown()
end

function BankGUI:FullReset()
    BankGUI._layoutInProgress = false
    OneWoW.Restriction.CancelWhenUnrestricted("OneWoW_Bags.cleanup.bank")
    BankSet:ReleaseAll()
    BankInfoBar:Reset()
    BankBar:Reset()

    if MainWindow then
        MainWindow:Hide()
        MainWindow = nil
    end

    titleBar = nil
    contentArea = nil
    contentScrollFrame = nil
    contentFrame = nil
    purchasePromptFrame = nil
    lastBuiltBankType = nil
    lastPurchasedTabCount = nil
    forcedPurchasePromptBankType = nil
    isInitialized = false
end

function BankGUI:ApplyTheme()
    if not MainWindow then return end

    WH:ApplyBaseTheme(MainWindow, titleBar, BankInfoBar, BankBar)
    ApplyPurchasePromptTheme(purchasePromptFrame)
    BankInfoBar:UpdateViewButtons()
    ns:RequestLayoutRefresh("bank", "theme")
end

function BankGUI:GetMainWindow()
    return MainWindow
end
