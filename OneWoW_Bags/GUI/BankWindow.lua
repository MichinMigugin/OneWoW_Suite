local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local WH = OneWoW_Bags.WindowHelpers
local BankInfoBar = OneWoW_Bags.BankInfoBar
local BankSet = OneWoW_Bags.BankSet
local BankCategoryManager = OneWoW_Bags.BankCategoryManager
local BankCategoryView = OneWoW_Bags.BankCategoryView
local BankBar = OneWoW_Bags.BankBar
local BankTabView = OneWoW_Bags.BankTabView
local ListView = OneWoW_Bags.ListView

local ipairs, pairs, pcall = ipairs, pairs, pcall

local C_Bank = C_Bank
local C_Timer = C_Timer
local C_PlayerInteractionManager = C_PlayerInteractionManager
local InCombatLockdown = InCombatLockdown
local max = math.max

OneWoW_Bags.BankGUI = OneWoW_Bags.BankGUI or {}
local BankGUI = OneWoW_Bags.BankGUI

local MainWindow = nil
local isInitialized = false
local contentScrollFrame = nil
local contentFrame = nil
local titleBar = nil
local contentArea = nil
local needsCleanupAfterCombat = false
local cleanupEventFrame = nil
local purchasePromptFrame = nil
local lastBuiltBankType = nil
local lastPurchasedTabCount = nil
local forcedPurchasePromptBankType = nil

local PURCHASE_PROMPT_HEIGHT = 280

local function GetDB()
    return OneWoW_Bags:GetDB()
end

local function GetLayoutController()
    return OneWoW_Bags.WindowLayoutController
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
            forcedPurchasePromptBankType = nil
            BankGUI:RestoreBlizzardPurchaseButton()
            if purchasePromptFrame then
                purchasePromptFrame:Hide()
            end
            BankGUI:CleanupAllViews()
            BankInfoBar:ClearSearch()
            OneWoW_Bags.activeBankExpansionFilter = nil
            OneWoW_GUI:SaveWindowPosition(MainWindow, db.global.bankFramePosition)
            if OneWoW_Bags.bankOpen then
                OneWoW_Bags.bankOpen = false
                if BankFrame and BankFrame.BankPanel then
                    BankFrame.BankPanel:Hide()
                end
                BankSet:ReleaseAll()
                C_Timer.After(0, function()
                    if C_Bank and C_Bank.CloseBankFrame then
                        C_Bank.CloseBankFrame()
                    end
                end)
            end
        end,
    })

    if not MainWindow then return end

    local factionTheme = OneWoW_GUI:GetSetting("minimap.theme") or "horde"
    local bankSettingsBtn
    titleBar, bankSettingsBtn = WH:CreateWindowTitleBar(MainWindow, {
        title = L["BANK_TITLE"] or "Bank",
        factionTheme = factionTheme,
        onClose = function() MainWindow:Hide() end,
        settingsText = L["SETTINGS"],
        onSettings = function()
            if OneWoW_Bags.Settings then
                OneWoW_Bags.Settings:Toggle()
            end
        end,
    })
    WH:AttachShoppingListCartButton(titleBar, bankSettingsBtn)
    contentArea = WH:CreateContentArea(MainWindow)

    local infoBar = BankInfoBar:Create(contentArea)
    local bankBar = BankBar:Create(contentArea)
    BankInfoBar:UpdateVisibility()
    BankBar:SetShown(db.global.showBankBagsBar ~= false)

    local hideScrollBar = db.global.bankHideScrollBar
    contentScrollFrame, contentFrame = WH:CreateScrollScaffold({
        contentArea = contentArea,
        scrollName = "OneWoW_BankContentScroll",
        topAnchor = infoBar,
        bottomAnchor = bankBar,
        hideScrollBar = hideScrollBar,
    })

    WH:SetupResizeButton(MainWindow, BankGUI, "bankFramePosition")
    isInitialized = true

    if not cleanupEventFrame then
        cleanupEventFrame = WH:RegisterDeferredCleanup({
            shouldCleanup = function()
                return needsCleanupAfterCombat and MainWindow and not MainWindow:IsShown()
            end,
            cleanup = function()
                BankGUI:CleanupAllViews()
            end,
        })
    end
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

    promptFrame:SetScript("OnShow", function(self)
        self:RegisterEvent("PLAYER_MONEY")
    end)
    promptFrame:SetScript("OnHide", function(self)
        self:UnregisterEvent("PLAYER_MONEY")
    end)
    promptFrame:SetScript("OnEvent", function()
        if MainWindow and MainWindow:IsShown() then
            BankGUI:RefreshLayout()
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
    self:RefreshLayout()
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
        BankSet:ReleaseAll()
        BankSet:Build()
    end

    lastBuiltBankType = bankType
    lastPurchasedTabCount = purchasedTabCount
end

function BankGUI:CleanupAllViews()
    if InCombatLockdown() then
        needsCleanupAfterCombat = true
        return
    end
    needsCleanupAfterCombat = false
    if BankSet.isBuilt then
        local allButtons = BankSet:GetAllButtons()
        for _, button in ipairs(allButtons) do
            button:Hide()
            button:ClearAllPoints()
        end
    end

    BankCategoryManager:ReleaseAllSections()
end

function BankGUI:UpdateWindowWidth()
    if not MainWindow then return end
    local controller = GetLayoutController()
    if controller and controller.UpdateFixedWidth then
        controller:UpdateFixedWidth({
            mainWindow = MainWindow,
            columnsKey = "bankColumns",
            defaultColumns = 14,
            hideScrollKey = "bankHideScrollBar",
            outerPadding = OneWoW_GUI:GetSpacing("XS"),
        })
    end
end

function BankGUI:RefreshLayout()
    if not isInitialized or not MainWindow then return end
    if not MainWindow:IsShown() then return end
    local db = GetDB()
    local controller = GetLayoutController()
    if not controller or not controller.Refresh then return end

    self:SyncBuiltTabState()

    controller:Refresh({
        mainWindow = MainWindow,
        isBuilt = function()
            return BankSet.isBuilt
        end,
        updateWindowWidth = function()
            BankGUI:UpdateWindowWidth()
        end,
        beforeLayout = function()
            BankInfoBar:UpdateVisibility()
            BankBar:SetShown(db.global.showBankBagsBar ~= false)
            BankBar:RefreshChromeAnchors()
            controller:BindScrollFrame({
                scrollFrame = contentScrollFrame,
                hideScrollBar = db.global.bankHideScrollBar,
                topAnchor = BankInfoBar:GetFrame(),
                bottomAnchor = BankBar:GetFrame(),
                contentArea = contentArea,
            })
        end,
        contentFrame = contentFrame,
        containerFrames = BankSet.bagContainerFrames,
        cleanup = function()
            BankGUI:CleanupAllViews()
        end,
        getButtons = function()
            return BankSet:GetAllButtons()
        end,
        filterButtons = function(allButtons)
            if ShouldShowPurchasePrompt() then
                return {}
            end
            local visibleButtons = WH:FilterByTab(allButtons, db.global.bankSelectedTab)
            local filteredButtons = WH:FilterBySearch(visibleButtons, BankInfoBar:GetSearchText())
            return WH:FilterByExpansion(filteredButtons, OneWoW_Bags.activeBankExpansionFilter)
        end,
        layoutButtons = function(filteredButtons)
            if ShouldShowPurchasePrompt() then
                return PURCHASE_PROMPT_HEIGHT
            end
            local _, _, _, contentWidth = WH:GetLayoutMetrics("bankColumns", 14)
            local viewMode = db.global.bankViewMode
            local layoutHeight
            local categoryViewContext = controller:CreateViewContext({
                sectionManager = BankCategoryManager,
                sortMode = db.global.itemSort,
                getCollapsed = function(kind, key)
                    if kind == "category" then
                        return db.global.collapsedBankCategorySections[key] or db.global.collapsedBankSections[key]
                    end
                end,
                setCollapsed = function(kind, key, collapsed)
                    if kind == "category" then
                        db.global.collapsedBankCategorySections[key] = collapsed or nil
                    end
                end,
                requestRelayout = function()
                    BankGUI:RefreshLayout()
                end,
            })
            local tabViewContext = controller:CreateViewContext({
                sectionManager = BankCategoryManager,
                sortMode = db.global.itemSort,
                getCollapsed = function(kind, key)
                    if kind == "tab" then
                        return db.global.collapsedBankTabSections[key] or db.global.collapsedBankSections[key]
                    end
                end,
                setCollapsed = function(kind, key, collapsed)
                    if kind == "tab" then
                        db.global.collapsedBankTabSections[key] = collapsed or nil
                    end
                end,
                requestRelayout = function()
                    BankGUI:RefreshLayout()
                end,
            })

            if viewMode == "category" then
                layoutHeight = BankCategoryView:Layout(contentFrame, contentWidth, filteredButtons, categoryViewContext)
            elseif viewMode == "tab" then
                layoutHeight = BankTabView:Layout(contentFrame, contentWidth, filteredButtons, tabViewContext)
            else
                layoutHeight = ListView:Layout(contentFrame, filteredButtons, contentWidth, categoryViewContext)
            end

            return max(layoutHeight, BankGUI:GetPurchasePromptLayoutHeight())
        end,
        afterLayout = function(_, layoutHeight)
            BankBar:UpdateFreeSlots(BankSet:GetFreeSlotCount(), BankSet:GetSlotCount())
            BankGUI:RefreshPurchasePrompt(layoutHeight)
        end,
    })
end

function BankGUI:OnSearchChanged(text)
    self:RefreshLayout()
end

function BankGUI:OnBankTypeChanged()
    local db = GetDB()
    db.global.bankSelectedTab = nil

    local showWarband = db.global.bankShowWarband

    local newBankType = showWarband and Enum.BankType.Account or Enum.BankType.Character
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:Show()
        BankFrame.BankPanel:SetBankType(newBankType)
    end

    BankSet:ReleaseAll()
    BankSet:Build()
    TrackBuiltBankState()

    BankBar:BuildTabButtons()
    BankBar:UpdateModeButtons()

    WH:QueueContentRefresh(contentScrollFrame, contentFrame, function()
        BankGUI:RefreshLayout()
    end)
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

    MainWindow:Show()

    if not BankSet.isBuilt then
        BankSet:Build()
    end
    TrackBuiltBankState()

    OneWoW_Bags.BankBar:UpdateModeButtons()
    OneWoW_Bags.BankBar:BuildTabButtons()
    OneWoW_Bags.BankBar:UpdateGold()

    WH:QueueContentRefresh(contentScrollFrame, contentFrame, function()
        BankGUI:RefreshLayout()
    end)

    C_Timer.After(0.5, function()
        if MainWindow and MainWindow:IsShown() then
            BankGUI:RefreshLayout()
        end
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
    self:RefreshLayout()
end

function BankGUI:GetMainWindow()
    return MainWindow
end
