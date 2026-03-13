local ADDON_NAME, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local backdrop = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = false,
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
}

ns.MainWindow = {}
local MainWindow = ns.MainWindow

local C = function()
    return ns.Constants and ns.Constants.GUI or {
        WINDOW_WIDTH = 820, WINDOW_HEIGHT = 580,
        SIDEBAR_WIDTH = 300, PADDING = 12,
        BUTTON_HEIGHT = 28, SEARCH_HEIGHT = 28,
        ROW_HEIGHT = 38, ROW_GAP = 2, SCROLLBAR_W = 10,
    }
end

local POOL_SIZE     = 32
local listRowPool   = {}
local itemRows      = {}

local mainFrame
local sidebarPanel
local contentPanel
local settingsPanel
local listScrollArea
local searchBox
local searchAltsBtn
local currentListLabel
local statusLabel
local currentView     = "items"
local expandedItems   = {}
local searchFilter    = ""
local searchAltsOn    = false
local inSettingsView  = false
local contentHeaderFrame
local addButtonRowFrame

local function GetDB()
    return _G.OneWoW_ShoppingList_DB
end

local function GetSettings()
    local db = GetDB()
    if db and db.global and db.global.settings then return db.global.settings end
    return {}
end

local function HideAllRows(pool)
    for _, row in ipairs(pool) do
        row:Hide()
        row:ClearAllPoints()
    end
end

local function CreateListRow(parent)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(32)
    row:SetBackdrop(BACKDROP_INNER)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    row.starBtn = CreateFrame("Button", nil, row)
    row.starBtn:SetSize(16, 16)
    row.starBtn:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.starTex = row.starBtn:CreateTexture(nil, "OVERLAY")
    row.starTex:SetAllPoints()
    row.starTex:SetAtlas("VignetteStar")
    row.starTex:SetAlpha(0.3)
    row.starBtn:SetNormalTexture(row.starTex)

    row.deleteBtn = CreateFrame("Button", nil, row)
    row.deleteBtn:SetSize(14, 14)
    row.deleteBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    local delTex = row.deleteBtn:CreateTexture(nil, "OVERLAY")
    delTex:SetAllPoints()
    delTex:SetAtlas("common-icon-redx")
    row.deleteBtn:SetNormalTexture(delTex)
    row.deleteBtn:GetNormalTexture():SetAlpha(0.5)
    row.deleteBtn:SetScript("OnEnter", function(self) self:GetNormalTexture():SetAlpha(1.0) end)
    row.deleteBtn:SetScript("OnLeave", function(self)
        self:GetNormalTexture():SetAlpha(0.5)
        if not MouseIsOver(row) then
            self:Hide()
            if not row.data or not row.data.isSelected then
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            end
        end
    end)
    row.deleteBtn:Hide()

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row, "LEFT", 24, 0)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -48, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    row.countText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.countText:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    row.countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    row.selectedBar = row:CreateTexture(nil, "ARTWORK")
    row.selectedBar:SetWidth(3)
    row.selectedBar:SetPoint("LEFT",        row, "LEFT",        0, 0)
    row.selectedBar:SetPoint("TOP",         row, "TOP",         0, 0)
    row.selectedBar:SetPoint("BOTTOM",      row, "BOTTOM",      0, 0)
    row.selectedBar:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    row.selectedBar:Hide()

    row:SetScript("OnEnter", function(self)
        if not self.data or not self.data.isSelected then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end
    end)
    row:SetScript("OnLeave", function(self)
        if not self.data or not self.data.isSelected then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        end
    end)

    row.data = {}
    return row
end


local function ConfigureListRow(row, listName, isSelected, isDefault, childCount, craftOrderCount)
    row:Show()
    row.data.listName    = listName
    row.data.isSelected  = isSelected
    row.data.isDefault   = isDefault

    local list = ns.ShoppingList:GetList(listName)
    local displayName = listName

    if list and list.isCraftOrder then
        local prefix = "Craft: "
        displayName = listName:sub(#prefix + 1)
    end

    row.nameText:SetText(displayName)
    row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local totalItems = 0
    if list and list.items then
        for _ in pairs(list.items) do totalItems = totalItems + 1 end
    end
    if list and list.unresolvedItems then
        for _ in pairs(list.unresolvedItems) do totalItems = totalItems + 1 end
    end

    if childCount and childCount > 0 then
        row.countText:SetText(string.format("(%d+%d)", totalItems, childCount))
    else
        row.countText:SetText(tostring(totalItems))
    end

    if isSelected then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        row.selectedBar:Show()
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    else
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row.selectedBar:Hide()
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end

    row.starTex:Show()
    row.starTex:SetAlpha(isDefault and 1.0 or 0.3)

    if list and list.isCraftOrder then
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
    end
end



function MainWindow:Create()
    if mainFrame then return end

    local G = C()

    mainFrame = CreateFrame("Frame", "OneWoW_ShoppingList_MainFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(G.WINDOW_WIDTH, G.WINDOW_HEIGHT)
    if not OneWoW_GUI:RestoreWindowPosition(mainFrame, GetDB().global.mainFramePosition or {}) then
        mainFrame:SetPoint("CENTER")
    end
    mainFrame:SetFrameStrata("MEDIUM")
    mainFrame:SetToplevel(true)
    mainFrame:SetMovable(true)
    mainFrame:EnableMouse(true)
    mainFrame:SetClampedToScreen(true)
    mainFrame:RegisterForDrag("LeftButton")
    mainFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    mainFrame:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    mainFrame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileEdge = true, tileSize = 16, edgeSize = 14,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    mainFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    mainFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    mainFrame:SetScript("OnHide", function()
        local db = GetDB().global
        db.mainFramePosition = db.mainFramePosition or {}
        OneWoW_GUI:SaveWindowPosition(mainFrame, db.mainFramePosition)
    end)
    mainFrame:Hide()

    tinsert(UISpecialFrames, "OneWoW_ShoppingList_MainFrame")

    local titleBar = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
    titleBar:SetHeight(20)
    titleBar:SetPoint("TOPLEFT",  mainFrame, "TOPLEFT",  4, -4)
    titleBar:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -4, -4)
    titleBar:SetBackdrop(BACKDROP_SIMPLE)
    titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
    titleBar:SetFrameLevel(mainFrame:GetFrameLevel() + 1)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() mainFrame:StopMovingOrSizing() end)

    local brandIcon = titleBar:CreateTexture(nil, "OVERLAY")
    brandIcon:SetSize(14, 14)
    brandIcon:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    brandIcon:SetAtlas("Perks-ShoppingCart")

    local brandText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    brandText:SetPoint("LEFT", brandIcon, "RIGHT", 4, 0)
    brandText:SetText("OneWoW")
    brandText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    titleText:SetText(L["OWSL_WINDOW_TITLE"])
    titleText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local closeBtn = OneWoW_GUI:CreateButton(titleBar, { text = "X", width = 20, height = 20 })
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    closeBtn:SetScript("OnClick", function() mainFrame:Hide() end)

    local settingsToggleBtn = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    settingsToggleBtn:SetSize(70, 16)
    settingsToggleBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
    settingsToggleBtn:SetBackdrop(BACKDROP_INNER)
    settingsToggleBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    settingsToggleBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    local settingsBtnLabel = settingsToggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    settingsBtnLabel:SetPoint("CENTER")
    settingsBtnLabel:SetText(L["OWSL_BTN_SETTINGS"])
    settingsBtnLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    settingsToggleBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        settingsBtnLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["OWSL_BTN_SETTINGS"], 1, 1, 1)
        GameTooltip:Show()
    end)
    settingsToggleBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        settingsBtnLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    settingsToggleBtn:SetScript("OnClick", function()
        MainWindow:ToggleSettings()
    end)

    local sidebarW = G.SIDEBAR_WIDTH
    local dividerX = sidebarW + 4

    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOP",    mainFrame, "TOPLEFT",  dividerX, -28)
    divider:SetPoint("BOTTOM", mainFrame, "BOTTOMLEFT", dividerX, 4)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    sidebarPanel = CreateFrame("Frame", nil, mainFrame)
    sidebarPanel:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     4,  -28)
    sidebarPanel:SetPoint("BOTTOMLEFT",  mainFrame, "BOTTOMLEFT",  4,  4)
    sidebarPanel:SetWidth(sidebarW)

    local sidebarHeader = CreateFrame("Frame", nil, sidebarPanel, "BackdropTemplate")
    sidebarHeader:SetHeight(30)
    sidebarHeader:SetPoint("TOPLEFT",  sidebarPanel, "TOPLEFT",  0, 0)
    sidebarHeader:SetPoint("TOPRIGHT", sidebarPanel, "TOPRIGHT", 0, 0)
    sidebarHeader:SetBackdrop(BACKDROP_INNER)
    sidebarHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    sidebarHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local sidebarTitle = sidebarHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sidebarTitle:SetPoint("LEFT", sidebarHeader, "LEFT", 8, 0)
    sidebarTitle:SetText(L["OWSL_SIDEBAR_TITLE"])
    sidebarTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local newListBtn = CreateFrame("Button", nil, sidebarHeader, "BackdropTemplate")
    newListBtn:SetSize(76, 22)
    newListBtn:SetPoint("RIGHT", sidebarHeader, "RIGHT", -4, 0)
    newListBtn:SetBackdrop(BACKDROP_INNER)
    newListBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    newListBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    newListBtn.text = newListBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    newListBtn.text:SetPoint("CENTER")
    newListBtn.text:SetText(L["OWSL_BTN_NEW_LIST"])
    newListBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    newListBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    end)
    newListBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)
    newListBtn:SetScript("OnClick", function()
        ns.Dialogs:InputDialog(L["OWSL_DIALOG_NEW_LIST"], "", function(name)
            if name == "" then
                print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ENTER_LIST_NAME"])
                return
            end
            local ok, err = ns.ShoppingList:CreateList(name)
            if not ok then
                print("|cFFFFD100OneWoW Shopping List:|r " .. (err or ""))
            else
                ns.ShoppingList:SetActiveList(name)
                MainWindow:RefreshSidebar()
                MainWindow:RefreshItemList()
            end
        end, mainFrame)
    end)

    local sidebarScroll = ns.GUI:CreateScrollArea(
        sidebarPanel, "OWSL_SidebarScroll",
        0, 0, -30, 0
    )
    sidebarPanel.scrollArea = sidebarScroll

    for i = 1, POOL_SIZE do
        listRowPool[i] = CreateListRow(sidebarScroll.scrollContent)
    end

    contentPanel = CreateFrame("Frame", nil, mainFrame)
    contentPanel:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     dividerX + 1, -28)
    contentPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -4, 4)

    local contentHeader = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    contentHeader:SetHeight(34)
    contentHeader:SetPoint("TOPLEFT",  contentPanel, "TOPLEFT",  0, 0)
    contentHeader:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", 0, 0)
    contentHeader:SetBackdrop(BACKDROP_INNER)
    contentHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    contentHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    currentListLabel = contentHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    currentListLabel:SetPoint("LEFT", contentHeader, "LEFT", 8, 0)
    currentListLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local btnRight = -4
    local importBtn = CreateFrame("Button", nil, contentHeader, "BackdropTemplate")
    importBtn:SetSize(60, 22)
    importBtn:SetPoint("RIGHT", contentHeader, "RIGHT", btnRight, 0)
    importBtn:SetBackdrop(BACKDROP_INNER)
    importBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    importBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    importBtn.text = importBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    importBtn.text:SetPoint("CENTER")
    importBtn.text:SetText(L["OWSL_BTN_IMPORT"])
    importBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    importBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER")) self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end)
    importBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL")) self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end)
    importBtn:SetScript("OnClick", function()
        ns.Dialogs:ImportDialog(function(text)
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok, count, nameOnly = ns.ShoppingList:ImportTextFormat(text, activeList)
            if ok then
                print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_IMPORTED_SUMMARY"], count - (nameOnly or 0), nameOnly or 0))
                if nameOnly and nameOnly > 0 then
                    print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ADDED_BY_NAME_NOTE"], nameOnly))
                end
                MainWindow:RefreshItemList()
                if nameOnly and nameOnly > 0 then
                    C_Timer.After(0.5, function()
                        ns.ShoppingList:ScanUnresolvedItems(activeList)
                        MainWindow:RefreshItemList()
                    end)
                end
            else
                print("|cFFFFD100OneWoW Shopping List:|r " .. (count or L["OWSL_MSG_NO_VALID_ITEMS"]))
            end
        end, mainFrame)
    end)
    btnRight = btnRight - 64

    local scanBtn = CreateFrame("Button", nil, contentHeader, "BackdropTemplate")
    scanBtn:SetSize(70, 22)
    scanBtn:SetPoint("RIGHT", contentHeader, "RIGHT", btnRight, 0)
    scanBtn:SetBackdrop(BACKDROP_INNER)
    scanBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    scanBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    scanBtn.text = scanBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scanBtn.text:SetPoint("CENTER")
    scanBtn.text:SetText(L["OWSL_BTN_SCAN_ALL"])
    scanBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    scanBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["OWSL_TT_SCAN_ALL_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_SCAN_ALL_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(L["OWSL_TT_SCAN_ALL_AUTO"], 0.7, 0.7, 0.7, true)
        GameTooltip:AddLine(L["OWSL_TT_SCAN_ALL_IMPORTANT"], 1, 0.82, 0, true)
        GameTooltip:Show()
    end)
    scanBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        GameTooltip:Hide()
    end)
    scanBtn:SetScript("OnClick", function()
        local activeList = ns.ShoppingList:GetActiveListName()
        ns.ShoppingList:ScanUnresolvedItems(activeList)
        MainWindow:RefreshItemList()
    end)
    btnRight = btnRight - 74

    searchAltsBtn = CreateFrame("CheckButton", nil, contentHeader, "UICheckButtonTemplate")
    searchAltsBtn:SetSize(18, 18)
    searchAltsBtn:SetPoint("RIGHT", contentHeader, "RIGHT", btnRight, 0)
    searchAltsBtn:SetChecked(searchAltsOn)
    searchAltsBtn:SetScript("OnClick", function(self)
        searchAltsOn = self:GetChecked()
        local activeList = ns.ShoppingList:GetActiveListName()
        local list = ns.ShoppingList:GetList(activeList)
        if list then list.searchAlts = searchAltsOn end
        MainWindow:RefreshItemList()
    end)
    searchAltsBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["OWSL_TT_SEARCH_ALTS_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_SEARCH_ALTS_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    searchAltsBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btnRight = btnRight - 22

    local altLabel = contentHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    altLabel:SetPoint("RIGHT", searchAltsBtn, "LEFT", -2, 0)
    altLabel:SetText(L["OWSL_LABEL_SEARCH_ALTS"])
    altLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    searchBox = OneWoW_GUI:CreateEditBox(contentHeader, { name = "OWSL_SearchBox", width = 120, height = 22 })
    searchBox:SetPoint("RIGHT", altLabel, "LEFT", -8, 0)
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            searchFilter = self:GetText():lower()
            MainWindow:RefreshItemList()
        end
    end)

    local searchLabel = contentHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    searchLabel:SetPoint("RIGHT", searchBox, "LEFT", -4, 0)
    searchLabel:SetText(L["OWSL_LABEL_SEARCH"])
    searchLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    contentHeaderFrame = contentHeader

    local addButtonRow = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    addButtonRow:SetHeight(32)
    addButtonRow:SetPoint("BOTTOMLEFT",  contentPanel, "BOTTOMLEFT",  0, 0)
    addButtonRow:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", 0, 0)
    addButtonRow:SetBackdrop(BACKDROP_INNER)
    addButtonRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    addButtonRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    addButtonRowFrame = addButtonRow

    statusLabel = addButtonRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLabel:SetPoint("LEFT", addButtonRow, "LEFT", 8, 0)
    statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local dragBtn = CreateFrame("Button", nil, addButtonRow, "BackdropTemplate")
    dragBtn:SetSize(110, 24)
    dragBtn:SetPoint("RIGHT", addButtonRow, "RIGHT", -4, 0)
    dragBtn:SetBackdrop(BACKDROP_INNER)
    dragBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    dragBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    dragBtn.text = dragBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dragBtn.text:SetPoint("CENTER")
    dragBtn.text:SetText(L["OWSL_BTN_DRAG_ITEM"])
    dragBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    dragBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    end)
    dragBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)

    dragBtn:SetScript("OnReceiveDrag", function()
        local dragType, id = GetCursorInfo()
        if dragType == "item" then
            ClearCursor()
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok, err = ns.ShoppingList:AddItemToList(activeList, id, 1)
            if ok then
                local name = C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            end
        end
    end)
    dragBtn:SetScript("OnClick", function()
        local dragType, id = GetCursorInfo()
        if dragType == "item" then
            ClearCursor()
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok = ns.ShoppingList:AddItemToList(activeList, id, 1)
            if ok then
                local name = C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            end
        end
    end)

    local addByIdBtn = CreateFrame("Button", nil, addButtonRow, "BackdropTemplate")
    addByIdBtn:SetSize(80, 24)
    addByIdBtn:SetPoint("RIGHT", dragBtn, "LEFT", -4, 0)
    addByIdBtn:SetBackdrop(BACKDROP_INNER)
    addByIdBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    addByIdBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    addByIdBtn.text = addByIdBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    addByIdBtn.text:SetPoint("CENTER")
    addByIdBtn.text:SetText(L["OWSL_BTN_ADD_BY_ID"])
    addByIdBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    addByIdBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER")) self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end)
    addByIdBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL")) self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end)
    addByIdBtn:SetScript("OnClick", function()
        ns.Dialogs:InputDialog(L["OWSL_DIALOG_ADD_BY_ID"], "", function(val)
            local id = tonumber(val)
            if not id or id <= 0 then
                print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ENTER_VALID_ID"])
                return
            end
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok = ns.ShoppingList:AddItemToList(activeList, id, 1)
            if ok then
                local name = C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            else
                print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_INVALID_ID"])
            end
        end, mainFrame)
    end)

    local listContainer = CreateFrame("Frame", nil, contentPanel)
    listContainer:SetPoint("TOPLEFT", contentHeader, "BOTTOMLEFT", 0, -2)
    listContainer:SetPoint("BOTTOMRIGHT", addButtonRow, "TOPRIGHT", 0, 2)

    local scrollBarWidth = 10

    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
    scrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -scrollBarWidth, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 40))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 40))
        end
    end)

    local scrollTrack = CreateFrame("Frame", nil, listContainer, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop(BACKDROP_SIMPLE)
    scrollTrack:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(30)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop(BACKDROP_SIMPLE)
    scrollThumb:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local function UpdateScrollThumb()
        local maxScroll = scrollFrame:GetVerticalScrollRange()
        if maxScroll <= 0 then
            scrollThumb:Hide()
            return
        end
        scrollThumb:Show()
        local viewHeight = scrollFrame:GetHeight()
        local trackHeight = scrollTrack:GetHeight()
        local thumbHeight = math.max(20, trackHeight * (viewHeight / (viewHeight + maxScroll)))
        local thumbRange = trackHeight - thumbHeight
        local thumbPos = (scrollFrame:GetVerticalScroll() / maxScroll) * thumbRange
        scrollThumb:SetHeight(thumbHeight)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -thumbPos)
    end

    scrollFrame:SetScript("OnVerticalScroll", function() UpdateScrollThumb() end)
    scrollFrame:SetScript("OnScrollRangeChanged", function() UpdateScrollThumb() end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnDragStart", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackHeight = scrollTrack:GetHeight()
        local thumbRange = trackHeight - self:GetHeight()
        if thumbRange > 0 then
            local maxScroll = scrollFrame:GetVerticalScrollRange()
            local newScroll = self.dragStartScroll + (delta / thumbRange) * maxScroll
            scrollFrame:SetVerticalScroll(math.max(0, math.min(maxScroll, newScroll)))
        end
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetWidth(scrollFrame:GetWidth())
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        scrollContent:SetWidth(width)
        UpdateScrollThumb()
    end)

    contentPanel.listContainer = listContainer
    contentPanel.scrollFrame = scrollFrame
    contentPanel.scrollContent = scrollContent
    contentPanel.scrollTrack = scrollTrack
    contentPanel.scrollThumb = scrollThumb

    self:BuildSettingsPanel()

    self:RegisterDragDrop(mainFrame)

    ns.ShoppingList:SetActiveList(ns.ShoppingList:GetActiveListName())
end

function MainWindow:BuildSettingsPanel()
    settingsPanel = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    settingsPanel:SetAllPoints(contentPanel)
    settingsPanel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true, tileEdge = true, tileSize = 16, edgeSize = 14,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    settingsPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    settingsPanel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    settingsPanel:Hide()

    local G = C()
    local pad = G.PADDING
    local yOff = -pad

    local settingsTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    settingsTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", pad, yOff)
    settingsTitle:SetText(L["OWSL_SETTINGS_TITLE"])
    settingsTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    yOff = yOff - 28

    local backBtn = CreateFrame("Button", nil, settingsPanel, "BackdropTemplate")
    backBtn:SetSize(60, 24)
    backBtn:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -pad, -pad)
    backBtn:SetBackdrop(BACKDROP_INNER)
    backBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
    backBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
    backBtn.text = backBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    backBtn.text:SetPoint("CENTER")
    backBtn.text:SetText(L["OWSL_BTN_BACK"])
    backBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    backBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER")) self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT")) end)
    backBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL")) self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end)
    backBtn:SetScript("OnClick", function() MainWindow:ToggleSettings() end)

    local settingsScroll = ns.GUI:CreateScrollArea(settingsPanel, nil, 0, 0, -40, 0)
    local scrollContent = settingsScroll.scrollContent
    yOff = -pad

    local function AddSectionHeader(text, y)
        local h = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        h:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        h:SetText(text)
        h:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        return h
    end

    local function AddRow(labelKey, y)
        local lbl = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        lbl:SetText(L[labelKey] or labelKey)
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        return lbl
    end

    local splitContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    splitContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    splitContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -pad, yOff)
    splitContainer:SetHeight(165)
    splitContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    splitContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    splitContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local leftPanel = CreateFrame("Frame", nil, splitContainer)
    leftPanel:SetPoint("TOPLEFT", splitContainer, "TOPLEFT", 0, 0)
    leftPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOM", 0, 0)

    local langTitle = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    langTitle:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -12)
    langTitle:SetText(L["OWSL_SETTINGS_LANGUAGE_TITLE"])
    langTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local langDesc = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDesc:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -38)
    langDesc:SetPoint("TOPRIGHT", leftPanel, "TOPRIGHT", -10, -38)
    langDesc:SetJustifyH("LEFT")
    langDesc:SetWordWrap(true)
    langDesc:SetText(L["OWSL_SETTINGS_LANGUAGE_DESC"])
    langDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local langNames = {
        { code = "enUS", key = "OWSL_LANG_ENGLISH" },
        { code = "koKR", key = "OWSL_LANG_KOREAN"  },
        { code = "frFR", key = "OWSL_LANG_FRENCH"  },
        { code = "deDE", key = "OWSL_LANG_GERMAN"  },
        { code = "ruRU", key = "OWSL_LANG_RUSSIAN" },
        { code = "esES", key = "OWSL_LANG_SPANISH" },
    }
    local currentLang = GetDB() and GetDB().global.settings.language or "enUS"
    local currentLangName = L["OWSL_LANG_ENGLISH"]
    for _, entry in ipairs(langNames) do
        if entry.code == currentLang then currentLangName = L[entry.key] or entry.code break end
    end

    local langCurrentLabel = leftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langCurrentLabel:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -90)
    langCurrentLabel:SetText(L["OWSL_SETTINGS_LANGUAGE"] .. " " .. currentLangName)
    langCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local langDropdown = CreateFrame("Button", nil, leftPanel, "BackdropTemplate")
    langDropdown:SetSize(190, 30)
    langDropdown:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 15, -115)
    langDropdown:SetBackdrop(backdrop)
    langDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    langDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local langDropText = langDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    langDropText:SetPoint("CENTER")
    langDropText:SetText(currentLangName)
    langDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local langDropArrow = langDropdown:CreateTexture(nil, "OVERLAY")
    langDropArrow:SetSize(16, 16)
    langDropArrow:SetPoint("RIGHT", langDropdown, "RIGHT", -5, 0)
    langDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    langDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS")) end)
    langDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")) end)

    local langMenu
    local langMenuTimer
    local function CreateLangMenu()
        if langMenu then return langMenu end
        langMenu = CreateFrame("Frame", nil, langDropdown, "BackdropTemplate")
        langMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        langMenu:SetSize(190, #langNames * 27 + 10)
        langMenu:SetPoint("TOPLEFT", langDropdown, "BOTTOMLEFT", 0, -2)
        langMenu:SetBackdrop(backdrop)
        langMenu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        langMenu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        langMenu:EnableMouse(true)
        langMenu:Hide()
        for i, entry in ipairs(langNames) do
            local btn = CreateFrame("Button", nil, langMenu, "BackdropTemplate")
            btn:SetSize(180, 25)
            btn:SetPoint("TOP", langMenu, "TOP", 0, -(5 + (i - 1) * 27))
            btn:SetBackdrop(BACKDROP_SIMPLE)
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
            local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("CENTER")
            txt:SetText(L[entry.key] or entry.code)
            txt:SetTextColor(0.9, 0.9, 0.9)
            btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
            btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
            local capturedCode = entry.code
            btn:SetScript("OnClick", function()
                local db = GetDB()
                if db then db.global.settings.language = capturedCode end
                ns.SetLocale(capturedCode)
                langMenu:Hide()
                MainWindow:Rebuild()
                C_Timer.After(0.1, function() MainWindow:Show() end)
            end)
        end
        return langMenu
    end

    local function StartLangMenuAutoHide(menu)
        if langMenuTimer then langMenuTimer:Cancel() end
        local function CheckMouse()
            if not menu:IsShown() then return end
            if not MouseIsOver(menu) and not MouseIsOver(langDropdown) then
                menu:Hide()
                return
            end
            langMenuTimer = C_Timer.NewTimer(0.5, CheckMouse)
        end
        langMenuTimer = C_Timer.NewTimer(0.5, CheckMouse)
    end

    langDropdown:SetScript("OnClick", function(self)
        local menu = CreateLangMenu()
        if menu:IsShown() then
            menu:Hide()
        else
            menu:Show()
            StartLangMenuAutoHide(menu)
        end
    end)

    local vertDivider = splitContainer:CreateTexture(nil, "ARTWORK")
    vertDivider:SetWidth(1)
    vertDivider:SetPoint("TOP", splitContainer, "TOP", 0, -8)
    vertDivider:SetPoint("BOTTOM", splitContainer, "BOTTOM", 0, 8)
    vertDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local rightPanel = CreateFrame("Frame", nil, splitContainer)
    rightPanel:SetPoint("TOPLEFT", splitContainer, "TOP", 0, 0)
    rightPanel:SetPoint("BOTTOMRIGHT", splitContainer, "BOTTOMRIGHT", 0, 0)

    local themeTitle = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    themeTitle:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -12)
    themeTitle:SetText(L["OWSL_SETTINGS_THEME_TITLE"])
    themeTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDescText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDescText:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -38)
    themeDescText:SetPoint("TOPRIGHT", rightPanel, "TOPRIGHT", -10, -38)
    themeDescText:SetJustifyH("LEFT")
    themeDescText:SetWordWrap(true)
    themeDescText:SetText(L["OWSL_SETTINGS_THEME_DESC"])
    themeDescText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local themeOrder = OneWoW_GUI.Constants.THEMES_ORDER
    local currentTheme = OneWoW_GUI:GetSetting("theme") or (GetDB() and GetDB().global.settings.theme) or OneWoW_GUI.Constants.DEFAULT_THEME_KEY
    local guiThemes = OneWoW_GUI.Constants.THEMES
    local currentThemeData = guiThemes[currentTheme]
    local currentThemeName = (currentThemeData and currentThemeData.name) or currentTheme

    local themeCurrentLabel = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeCurrentLabel:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -90)
    themeCurrentLabel:SetText(L["OWSL_SETTINGS_THEME"] .. " " .. currentThemeName)
    themeCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropdown = CreateFrame("Button", nil, rightPanel, "BackdropTemplate")
    themeDropdown:SetSize(210, 30)
    themeDropdown:SetPoint("TOPLEFT", rightPanel, "TOPLEFT", 15, -115)
    themeDropdown:SetBackdrop(backdrop)
    themeDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    themeDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local themeDropText = themeDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeDropText:SetPoint("LEFT", themeDropdown, "LEFT", 25, 0)
    themeDropText:SetText(currentThemeName)
    themeDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local themeColorPreview = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeColorPreview:SetSize(14, 14)
    themeColorPreview:SetPoint("LEFT", themeDropdown, "LEFT", 6, 0)
    themeColorPreview:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local themeDropArrow = themeDropdown:CreateTexture(nil, "OVERLAY")
    themeDropArrow:SetSize(16, 16)
    themeDropArrow:SetPoint("RIGHT", themeDropdown, "RIGHT", -5, 0)
    themeDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    themeDropdown:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS")) end)
    themeDropdown:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE")) end)

    local themeMenu
    local themeMenuTimer
    local function CreateThemeMenu()
        if themeMenu then return themeMenu end
        themeMenu = CreateFrame("Frame", nil, themeDropdown, "BackdropTemplate")
        themeMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        themeMenu:SetSize(240, 318)
        themeMenu:SetPoint("TOPLEFT", themeDropdown, "BOTTOMLEFT", 0, -2)
        themeMenu:SetBackdrop(backdrop)
        themeMenu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        themeMenu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        themeMenu:EnableMouse(true)
        themeMenu:Hide()

        local scrollFrame = CreateFrame("ScrollFrame", nil, themeMenu)
        scrollFrame:SetPoint("TOPLEFT", themeMenu, "TOPLEFT", 2, -2)
        scrollFrame:SetPoint("BOTTOMRIGHT", themeMenu, "BOTTOMRIGHT", -15, 2)

        local scrollChild = CreateFrame("Frame", nil, scrollFrame)
        scrollChild:SetWidth(210)
        scrollFrame:SetScrollChild(scrollChild)

        local scrollBar = CreateFrame("Slider", nil, scrollFrame, "BackdropTemplate")
        scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, -2)
        scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, 2)
        scrollBar:SetWidth(12)
        scrollBar:SetBackdrop(BACKDROP_SIMPLE)
        scrollBar:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        scrollBar:EnableMouse(true)
        scrollBar:SetScript("OnValueChanged", function(self, value) scrollFrame:SetVerticalScroll(value) end)

        local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(8, 40)
        thumb:SetPoint("TOP", scrollBar, "TOP", 0, -2)
        thumb:SetColorTexture(0.5, 0.5, 0.5)
        scrollBar:SetThumbTexture(thumb)

        scrollFrame:EnableMouseWheel(true)
        scrollFrame:SetScript("OnMouseWheel", function(self, direction)
            local currentScroll = scrollFrame:GetVerticalScroll()
            local maxScroll = scrollChild:GetHeight() - scrollFrame:GetHeight()
            local newScroll = math.max(0, math.min(maxScroll, currentScroll - (direction * 30)))
            scrollFrame:SetVerticalScroll(newScroll)
            scrollBar:SetValue(newScroll)
        end)

        for i, themeKey in ipairs(themeOrder) do
            local themeData = guiThemes[themeKey]
            if themeData then
                local btn = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
                btn:SetSize(230, 26)
                btn:SetPoint("TOP", scrollChild, "TOP", 0, -(5 + (i - 1) * 28))
                btn:SetBackdrop(BACKDROP_SIMPLE)
                btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                local dot = btn:CreateTexture(nil, "OVERLAY")
                dot:SetSize(14, 14)
                dot:SetPoint("LEFT", btn, "LEFT", 8, 0)
                dot:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                local txt = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                txt:SetPoint("LEFT", btn, "LEFT", 28, 0)
                txt:SetText(themeData.name)
                txt:SetTextColor(0.9, 0.9, 0.9)
                btn:SetScript("OnEnter", function(s) s:SetBackdropColor(0.2, 0.2, 0.2, 1) txt:SetTextColor(1, 0.82, 0) end)
                btn:SetScript("OnLeave", function(s) s:SetBackdropColor(0.1, 0.1, 0.1, 0.8) txt:SetTextColor(0.9, 0.9, 0.9) end)
                local capturedKey = themeKey
                btn:SetScript("OnClick", function()
                    OneWoW_GUI:SetSetting("theme", capturedKey)
                    themeMenu:Hide()
                    -- OnThemeChanged callback handles ApplyTheme + Rebuild
                end)
            end
        end
        scrollChild:SetHeight(#themeOrder * 28 + 10)
        local maxScroll = math.max(0, scrollChild:GetHeight() - scrollFrame:GetHeight())
        scrollBar:SetMinMaxValues(0, maxScroll)

        themeMenu.scrollFrame = scrollFrame
        return themeMenu
    end

    local function StartThemeMenuAutoHide(menu)
        if themeMenuTimer then themeMenuTimer:Cancel() end
        local function CheckMouse()
            if not menu:IsShown() then return end
            if not MouseIsOver(menu) and not MouseIsOver(themeDropdown) then
                menu:Hide()
                return
            end
            themeMenuTimer = C_Timer.NewTimer(0.5, CheckMouse)
        end
        themeMenuTimer = C_Timer.NewTimer(0.5, CheckMouse)
    end

    themeDropdown:SetScript("OnClick", function(self)
        local menu = CreateThemeMenu()
        if menu:IsShown() then
            menu:Hide()
        else
            if menu.scrollFrame then
                menu.scrollFrame:SetVerticalScroll(0)
            end
            menu:Show()
            StartThemeMenuAutoHide(menu)
        end
    end)

    yOff = yOff - 180

    local tooltipCb = CreateFrame("CheckButton", nil, scrollContent, "UICheckButtonTemplate")
    tooltipCb:SetSize(20, 20)
    tooltipCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff + 2)
    local tooltipLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tooltipLabel:SetPoint("LEFT", tooltipCb, "RIGHT", 4, 0)
    tooltipLabel:SetText(L["OWSL_SETTINGS_ENABLE_TOOLTIP"])
    tooltipLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local db = GetDB()
    tooltipCb:SetChecked(db and db.global.settings.enableTooltips or true)
    tooltipCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then dbRef.global.settings.enableTooltips = self:GetChecked() end
    end)
    yOff = yOff - 28

    local dividerTex = scrollContent:CreateTexture(nil, "ARTWORK")
    dividerTex:SetHeight(1)
    dividerTex:SetPoint("LEFT",  scrollContent, "LEFT",  pad,  0)
    dividerTex:SetPoint("RIGHT", scrollContent, "RIGHT", -pad, 0)
    dividerTex:SetPoint("TOP", scrollContent, "TOPLEFT", 0, yOff - 4)
    dividerTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    yOff = yOff - 16

    AddSectionHeader(L["OWSL_SETTINGS_OVERLAY"], yOff)
    yOff = yOff - 22

    local overlayCb = CreateFrame("CheckButton", nil, scrollContent, "UICheckButtonTemplate")
    overlayCb:SetSize(20, 20)
    overlayCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff + 2)
    local overlayLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overlayLabel:SetPoint("LEFT", overlayCb, "RIGHT", 4, 0)
    overlayLabel:SetText(L["OWSL_SETTINGS_ENABLE_OVERLAY"])
    overlayLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local settings = db and db.global.settings or {}
    local overlay = settings.overlay or {}
    overlayCb:SetChecked(overlay.enabled ~= false)
    overlayCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.overlay.enabled = self:GetChecked()
            ns.BagOverlays:UpdateAllSettings()
        end
    end)
    yOff = yOff - 28

    local curS = GetSettings()

    local mmContainer = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
    mmContainer:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    mmContainer:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", -pad, yOff)
    mmContainer:SetHeight(130)
    mmContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    mmContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    mmContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mmLeftPanel = CreateFrame("Frame", nil, mmContainer)
    mmLeftPanel:SetPoint("TOPLEFT", mmContainer, "TOPLEFT", 0, 0)
    mmLeftPanel:SetPoint("BOTTOMRIGHT", mmContainer, "BOTTOM", 0, 0)

    local mmLeftTitle = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmLeftTitle:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -12)
    mmLeftTitle:SetText(L["OWSL_SETTINGS_MINIMAP_TITLE"])
    mmLeftTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmLeftDesc = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmLeftDesc:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 15, -38)
    mmLeftDesc:SetPoint("TOPRIGHT", mmLeftPanel, "TOPRIGHT", -10, -38)
    mmLeftDesc:SetJustifyH("LEFT")
    mmLeftDesc:SetWordWrap(true)
    mmLeftDesc:SetText(L["OWSL_SETTINGS_MINIMAP_DESC"])
    mmLeftDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local mmShowCheck = CreateFrame("CheckButton", nil, mmLeftPanel, "UICheckButtonTemplate")
    mmShowCheck:SetSize(20, 20)
    mmShowCheck:SetPoint("TOPLEFT", mmLeftPanel, "TOPLEFT", 10, -85)
    local mmShowLabel = mmLeftPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmShowLabel:SetPoint("LEFT", mmShowCheck, "RIGHT", 4, 0)
    mmShowLabel:SetText(L["OWSL_SETTINGS_SHOW_MINIMAP"])
    mmShowLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    local isMMHidden = GetDB() and GetDB().global and GetDB().global.minimap and GetDB().global.minimap.hide
    mmShowCheck:SetChecked(not isMMHidden)
    mmShowCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            ns.Minimap:Show()
        else
            ns.Minimap:Hide()
        end
    end)

    local mmVertDivider = mmContainer:CreateTexture(nil, "ARTWORK")
    mmVertDivider:SetWidth(1)
    mmVertDivider:SetPoint("TOP", mmContainer, "TOP", 0, -8)
    mmVertDivider:SetPoint("BOTTOM", mmContainer, "BOTTOM", 0, 8)
    mmVertDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mmRightPanel = CreateFrame("Frame", nil, mmContainer)
    mmRightPanel:SetPoint("TOPLEFT", mmContainer, "TOP", 0, 0)
    mmRightPanel:SetPoint("BOTTOMRIGHT", mmContainer, "BOTTOMRIGHT", 0, 0)

    local mmRightTitle = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    mmRightTitle:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -12)
    mmRightTitle:SetText(L["OWSL_SETTINGS_ICON_TITLE"])
    mmRightTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmRightDesc = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmRightDesc:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -38)
    mmRightDesc:SetPoint("TOPRIGHT", mmRightPanel, "TOPRIGHT", -10, -38)
    mmRightDesc:SetJustifyH("LEFT")
    mmRightDesc:SetWordWrap(true)
    mmRightDesc:SetText(L["OWSL_SETTINGS_ICON_DESC"])
    mmRightDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local currentMMTheme = (GetDB() and GetDB().global and GetDB().global.minimap and GetDB().global.minimap.theme) or "neutral"
    local iconThemeNames = {
        ["horde"]    = L["OWSL_SETTINGS_ICON_HORDE"],
        ["alliance"] = L["OWSL_SETTINGS_ICON_ALLIANCE"],
        ["neutral"]  = L["OWSL_SETTINGS_ICON_NEUTRAL"],
    }

    local mmCurrentLabel = mmRightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmCurrentLabel:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -80)
    mmCurrentLabel:SetText(L["OWSL_SETTINGS_ICON_CURRENT"] .. ": " .. (iconThemeNames[currentMMTheme] or L["OWSL_SETTINGS_ICON_NEUTRAL"]))
    mmCurrentLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local mmIconDropdown = CreateFrame("Button", nil, mmRightPanel, "BackdropTemplate")
    mmIconDropdown:SetSize(180, 30)
    mmIconDropdown:SetPoint("TOPLEFT", mmRightPanel, "TOPLEFT", 15, -100)
    mmIconDropdown:SetBackdrop(backdrop)
    mmIconDropdown:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    mmIconDropdown:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local mmDropIcon = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmDropIcon:SetSize(18, 18)
    mmDropIcon:SetPoint("LEFT", mmIconDropdown, "LEFT", 6, 0)
    local mmDropIconTex
    if currentMMTheme == "alliance" then
        mmDropIconTex = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\alliance-mini.png"
    elseif currentMMTheme == "horde" then
        mmDropIconTex = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\horde-mini.png"
    else
        mmDropIconTex = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\neutral-mini.png"
    end
    mmDropIcon:SetTexture(mmDropIconTex)

    local mmDropText = mmIconDropdown:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mmDropText:SetPoint("LEFT", mmDropIcon, "RIGHT", 4, 0)
    mmDropText:SetText(iconThemeNames[currentMMTheme] or L["OWSL_SETTINGS_ICON_NEUTRAL"])
    mmDropText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local mmDropArrow = mmIconDropdown:CreateTexture(nil, "OVERLAY")
    mmDropArrow:SetSize(16, 16)
    mmDropArrow:SetPoint("RIGHT", mmIconDropdown, "RIGHT", -5, 0)
    mmDropArrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

    mmIconDropdown:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_FOCUS"))
    end)
    mmIconDropdown:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end)

    local mmIconMenu
    local mmIconMenuTimer
    local function CreateMMIconMenu()
        if mmIconMenu then return mmIconMenu end
        mmIconMenu = CreateFrame("Frame", nil, mmIconDropdown, "BackdropTemplate")
        mmIconMenu:SetFrameStrata("FULLSCREEN_DIALOG")
        mmIconMenu:SetSize(180, 100)
        mmIconMenu:SetPoint("TOPLEFT", mmIconDropdown, "BOTTOMLEFT", 0, -2)
        mmIconMenu:SetBackdrop(backdrop)
        mmIconMenu:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
        mmIconMenu:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        mmIconMenu:EnableMouse(true)
        mmIconMenu:Hide()

        local function createIconBtn(parent, themeKey, yPos)
            local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
            btn:SetSize(170, 26)
            btn:SetPoint("TOP", parent, "TOP", 0, yPos)
            btn:SetBackdrop(BACKDROP_SIMPLE)
            btn:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

            local previewIcon = btn:CreateTexture(nil, "OVERLAY")
            previewIcon:SetSize(18, 18)
            previewIcon:SetPoint("LEFT", btn, "LEFT", 8, 0)
            local previewTex
            if themeKey == "alliance" then
                previewTex = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\alliance-mini.png"
            elseif themeKey == "horde" then
                previewTex = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\horde-mini.png"
            else
                previewTex = "Interface\\AddOns\\OneWoW_ShoppingList\\Media\\neutral-mini.png"
            end
            previewIcon:SetTexture(previewTex)

            local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            text:SetPoint("LEFT", btn, "LEFT", 32, 0)
            text:SetText(iconThemeNames[themeKey])
            text:SetTextColor(0.9, 0.9, 0.9)

            btn:SetScript("OnEnter", function(s)
                s:SetBackdropColor(0.2, 0.2, 0.2, 1)
                text:SetTextColor(1, 0.82, 0)
            end)
            btn:SetScript("OnLeave", function(s)
                s:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
                text:SetTextColor(0.9, 0.9, 0.9)
            end)

            btn:SetScript("OnClick", function()
                local db = GetDB()
                if db and db.global and db.global.minimap then
                    db.global.minimap.theme = themeKey
                end
                if ns.Minimap then
                    ns.Minimap:UpdateIcon()
                end
                mmIconMenu:Hide()
                MainWindow:Rebuild()
                C_Timer.After(0.1, function()
                    MainWindow:Show()
                end)
            end)

            return btn
        end

        createIconBtn(mmIconMenu, "horde", -5)
        createIconBtn(mmIconMenu, "alliance", -33)
        createIconBtn(mmIconMenu, "neutral", -61)

        return mmIconMenu
    end

    local function StartMMIconMenuAutoHide(menu)
        if mmIconMenuTimer then mmIconMenuTimer:Cancel() end
        local function CheckMouse()
            if not menu:IsShown() then return end
            if not MouseIsOver(menu) and not MouseIsOver(mmIconDropdown) then
                menu:Hide()
                return
            end
            mmIconMenuTimer = C_Timer.NewTimer(0.5, CheckMouse)
        end
        mmIconMenuTimer = C_Timer.NewTimer(0.5, CheckMouse)
    end

    mmIconDropdown:SetScript("OnClick", function(self)
        local menu = CreateMMIconMenu()
        if menu:IsShown() then
            menu:Hide()
        else
            menu:Show()
            StartMMIconMenuAutoHide(menu)
        end
    end)

    yOff = yOff - 145

    local bagBtnCb = CreateFrame("CheckButton", nil, scrollContent, "UICheckButtonTemplate")
    bagBtnCb:SetSize(20, 20)
    bagBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff + 2)
    local bagBtnCbLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bagBtnCbLabel:SetPoint("LEFT", bagBtnCb, "RIGHT", 4, 0)
    bagBtnCbLabel:SetText(L["OWSL_SETTINGS_SHOW_BAG_BUTTONS"])
    bagBtnCbLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    bagBtnCb:SetChecked(curS.showBagButtons ~= false)
    bagBtnCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.showBagButtons = self:GetChecked()
            ns.BagButton:UpdateVisibility()
        end
    end)
    yOff = yOff - 28

    local profBtnCb = CreateFrame("CheckButton", nil, scrollContent, "UICheckButtonTemplate")
    profBtnCb:SetSize(20, 20)
    profBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff + 2)
    local profBtnCbLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profBtnCbLabel:SetPoint("LEFT", profBtnCb, "RIGHT", 4, 0)
    profBtnCbLabel:SetText(L["OWSL_SETTINGS_SHOW_PROF_BUTTONS"])
    profBtnCbLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    profBtnCb:SetChecked(curS.showProfessionButtons ~= false)
    profBtnCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.showProfessionButtons = self:GetChecked()
            ns.ProfessionUI:UpdateVisibility()
        end
    end)
    yOff = yOff - 28

    local ahBtnCb = CreateFrame("CheckButton", nil, scrollContent, "UICheckButtonTemplate")
    ahBtnCb:SetSize(20, 20)
    ahBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff + 2)
    local ahBtnCbLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ahBtnCbLabel:SetPoint("LEFT", ahBtnCb, "RIGHT", 4, 0)
    ahBtnCbLabel:SetText(L["OWSL_SETTINGS_SHOW_AH_BUTTON"])
    ahBtnCbLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    ahBtnCb:SetChecked(curS.showAHButton ~= false)
    ahBtnCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.showAHButton = self:GetChecked()
            ns.BagButton:UpdateAHVisibility()
        end
    end)
    yOff = yOff - 28

    AddSectionHeader(L["OWSL_SETTINGS_ADDON_STATUS"], yOff)
    yOff = yOff - 22

    local function AddStatusRow(labelText, detected, y)
        local lbl = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        lbl:SetText(labelText)
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local status = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        status:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 220, y)
        if detected then
            status:SetText(L["OWSL_SETTINGS_DETECTED"])
            status:SetTextColor(0.3, 0.9, 0.3)
        else
            status:SetText(L["OWSL_SETTINGS_NOT_DETECTED"])
            status:SetTextColor(0.6, 0.6, 0.6)
        end
    end

    AddStatusRow(L["OWSL_SETTINGS_ALT_ACCESS"],    ns.DataAccess:HasAltData(), yOff); yOff = yOff - 20
    AddStatusRow(L["OWSL_SETTINGS_WARBAND_ACCESS"], ns.DataAccess:HasAltData(), yOff); yOff = yOff - 20
    AddStatusRow(L["OWSL_SETTINGS_RECIPE_DATA"],    _G.WoWNotesData_Professions ~= nil, yOff); yOff = yOff - 20

    AddSectionHeader(L["OWSL_SETTINGS_KEYBINDS"], yOff)
    yOff = yOff - 22

    local function AddKeybindRow(labelText, bindingName, y)
        local lbl = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        lbl:SetText(labelText)
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local binding = GetBindingKey(bindingName)
        local bVal = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        bVal:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 220, y)
        bVal:SetText(binding or L["OWSL_SETTINGS_NO_KEYBIND"])
        if binding then
            bVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            bVal:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    AddKeybindRow(L["OWSL_SETTINGS_TOGGLE_KEY"],   "ONEWOW_SHOPPING_LIST_TOGGLE",   yOff); yOff = yOff - 20
    AddKeybindRow(L["OWSL_SETTINGS_ADD_ITEM_KEY"], "ONEWOW_SHOPPING_LIST_ADD_ITEM", yOff); yOff = yOff - 20

    local bindInfoLabel = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bindInfoLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    bindInfoLabel:SetText(L["OWSL_SETTINGS_KEYBIND_INFO"])
    bindInfoLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    scrollContent:SetHeight(math.abs(yOff) + 20)
end

function MainWindow:Rebuild()
    if mainFrame then mainFrame:Hide() end
    mainFrame = nil
    sidebarPanel = nil
    contentPanel = nil
    settingsPanel = nil
    contentHeaderFrame = nil
    addButtonRowFrame = nil
    searchBox = nil
    searchAltsBtn = nil
    currentListLabel = nil
    statusLabel = nil
    inSettingsView = false
    expandedItems = {}
    listRowPool = {}
    itemRows = {}
end

function MainWindow:ToggleSettings()
    inSettingsView = not inSettingsView
    if inSettingsView then
        settingsPanel:Show()
        if contentPanel.listContainer then contentPanel.listContainer:Hide() end
        if contentPanel.scrollTrack then contentPanel.scrollTrack:Hide() end
        if contentHeaderFrame then contentHeaderFrame:Hide() end
        if addButtonRowFrame then addButtonRowFrame:Hide() end
    else
        settingsPanel:Hide()
        if contentPanel.listContainer then contentPanel.listContainer:Show() end
        if contentPanel.scrollTrack then contentPanel.scrollTrack:Show() end
        if contentHeaderFrame then contentHeaderFrame:Show() end
        if addButtonRowFrame then addButtonRowFrame:Show() end
    end
end

function MainWindow:RegisterDragDrop(frame)
    frame:SetScript("OnReceiveDrag", function()
        local dragType, id = GetCursorInfo()
        if dragType == "item" then
            ClearCursor()
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok = ns.ShoppingList:AddItemToList(activeList, id, 1)
            if ok then
                local name = C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            end
        end
    end)
end

function MainWindow:RefreshSidebar()
    if not sidebarPanel then return end

    HideAllRows(listRowPool)

    local allLists = ns.ShoppingList:GetAllLists()
    local activeList = ns.ShoppingList:GetActiveListName()
    local defaultList = ns.ShoppingList:GetDefaultListName()

    local parentLists = {}
    local childrenOf = {}

    for listName, listData in pairs(allLists) do
        if listData.parentList then
            childrenOf[listData.parentList] = childrenOf[listData.parentList] or {}
            table.insert(childrenOf[listData.parentList], listName)
        else
            table.insert(parentLists, listName)
        end
    end

    table.sort(parentLists, function(a, b)
        if a == ns.MAIN_LIST_KEY then return true end
        if b == ns.MAIN_LIST_KEY then return false end
        return a < b
    end)

    local scrollContent = sidebarPanel.scrollArea.scrollContent
    local rowIdx = 1
    local yOff   = 0

    local INDENT   = { [0] = 0,  [1] = 16, [2] = 28, [3] = 40 }
    local HEIGHT   = { [0] = 32, [1] = 28, [2] = 26, [3] = 24 }
    local YADVANCE = { [0] = 34, [1] = 30, [2] = 28, [3] = 26 }
    local MAX_DEPTH = 3

    local function RenderListEntry(listName, depth)
        if rowIdx > POOL_SIZE then return end

        local row = listRowPool[rowIdx]
        local isSelected     = (listName == activeList)
        local isDefault      = (depth == 0) and (listName == defaultList)
        local childCount     = childrenOf[listName] and #childrenOf[listName] or 0
        ConfigureListRow(row, listName, isSelected, isDefault, childCount, 0)

        local indent   = INDENT[depth]   or 40
        local height   = HEIGHT[depth]   or 24
        local yAdvance = YADVANCE[depth] or 26

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  indent, -yOff)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, -yOff)
        row:SetHeight(height)

        if depth > 0 then
            row.starBtn:Hide()
        else
            row.starBtn:Show()
        end

        local capturedName = listName

        row:SetScript("OnClick", function(self, btn)
            if btn == "RightButton" then
                MainWindow:ShowListContextMenu(capturedName)
            else
                ns.ShoppingList:SetActiveList(capturedName)
                local curList = ns.ShoppingList:GetList(capturedName)
                searchAltsOn = curList and curList.searchAlts or false
                if searchAltsBtn then searchAltsBtn:SetChecked(searchAltsOn) end
                MainWindow:RefreshSidebar()
                MainWindow:RefreshItemList()
            end
        end)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        if depth == 0 then
            row.starBtn:SetScript("OnClick", function()
                ns.ShoppingList:SetDefaultList(capturedName)
                MainWindow:RefreshSidebar()
            end)
        end

        if capturedName ~= ns.MAIN_LIST_KEY then
            row.deleteBtn:SetScript("OnClick", function()
                ns.Dialogs:ConfirmDialog(
                    string.format(L["OWSL_DIALOG_DELETE_CONFIRM"], capturedName),
                    L["OWSL_DIALOG_DELETE_CONFIRM2"],
                    function()
                        ns.ShoppingList:DeleteList(capturedName)
                        MainWindow:RefreshSidebar()
                        MainWindow:RefreshItemList()
                    end,
                    L["OWSL_BTN_DELETE"],
                    mainFrame
                )
            end)
        else
            row.deleteBtn:SetScript("OnClick", nil)
        end

        row:SetScript("OnEnter", function(self)
            if not self.data or not self.data.isSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end
            if self.deleteBtn and capturedName ~= ns.MAIN_LIST_KEY then
                self.deleteBtn:Show()
            end
        end)
        row:SetScript("OnLeave", function(self)
            if not self.data or not self.data.isSelected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            end
            if self.deleteBtn and not MouseIsOver(self.deleteBtn) then
                self.deleteBtn:Hide()
            end
        end)

        row:Show()
        rowIdx = rowIdx + 1
        yOff = yOff + yAdvance

        if depth < MAX_DEPTH then
            local children = childrenOf[listName]
            if children then
                table.sort(children)
                for _, childName in ipairs(children) do
                    RenderListEntry(childName, depth + 1)
                end
            end
        end
    end

    for _, listName in ipairs(parentLists) do
        RenderListEntry(listName, 0)
    end

    scrollContent:SetHeight(math.max(yOff + 4, 1))
    sidebarPanel.scrollArea.UpdateThumb()
end

function MainWindow:RefreshItemList()
    local scrollContent = contentPanel and contentPanel.scrollContent
    if not scrollContent then return end

    for _, row in ipairs(itemRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(itemRows)

    local activeList = ns.ShoppingList:GetActiveListName()
    local list       = ns.ShoppingList:GetList(activeList)

    if currentListLabel then
        local displayName = activeList
        if list and list.isCraftOrder then
            displayName = "Craft: " .. activeList:sub(8)
        end
        currentListLabel:SetText(displayName)
    end

    if not list then
        scrollContent:SetHeight(1)
        return
    end

    local items = {}

    for itemID, itemInfo in pairs(list.items or {}) do
        local displayName = C_Item.GetItemNameByID(itemID)
        if not displayName then
            C_Item.RequestLoadItemDataByID(itemID)
            displayName = string.format(L["OWSL_ITEM_PREFIX"], itemID)
        end
        if searchFilter == "" or displayName:lower():find(searchFilter, 1, true) then
            local _, itemLink, _, _, _, _, _, _, _, iconFile = GetItemInfo(itemID)
            local status               = ns.ShoppingList:GetItemStatus(itemID, activeList)
            local isCraftable, recipes = ns.ShoppingList:IsItemCraftable(itemID)
            table.insert(items, {
                key          = tostring(itemID),
                itemID       = itemID,
                displayName  = displayName,
                quantity     = itemInfo.quantity,
                icon         = iconFile,
                itemLink     = itemLink,
                status       = status,
                isCraftable  = isCraftable,
                recipes      = recipes,
                isUnresolved = false,
            })
        end
    end

    for uid, unresolvedItem in pairs(list.unresolvedItems or {}) do
        local name = unresolvedItem.itemName
        if searchFilter == "" or name:lower():find(searchFilter, 1, true) then
            table.insert(items, {
                key          = uid,
                itemID       = nil,
                displayName  = name,
                quantity     = unresolvedItem.quantity,
                icon         = "Interface\\Icons\\INV_Misc_QuestionMark",
                status       = nil,
                isCraftable  = false,
                isUnresolved = true,
            })
        end
    end

    table.sort(items, function(a, b)
        if a.isUnresolved ~= b.isUnresolved then return b.isUnresolved end
        if a.status and b.status then
            local priority = { red = 0, yellow = 1, blue = 2, green = 3 }
            local pa = priority[a.status.status] or 0
            local pb = priority[b.status.status] or 0
            if pa ~= pb then return pa < pb end
        end
        return (a.displayName or "") < (b.displayName or "")
    end)

    local rowHeight = 32
    local rowGap    = 2
    local yOffset   = -2

    local function RepositionAllRows()
        local y = -2
        for _, r in ipairs(itemRows) do
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, y)
            r:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
            y = y - (rowHeight + rowGap)
            if r.isExpanded and r.expandedFrame and r.expandedFrame:IsShown() then
                y = y - (r.expandedFrame:GetHeight() + rowGap)
            end
        end
        scrollContent:SetHeight(math.abs(y) + 10)
    end

    for _, itemData in ipairs(items) do
        local capturedData  = itemData
        local capturedListN = activeList

        local row = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        row:SetHeight(rowHeight)
        row:SetBackdrop(BACKDROP_SIMPLE)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        row:EnableMouse(true)

        local statusBar = CreateFrame("Button", nil, row)
        statusBar:SetWidth(6)
        statusBar:SetPoint("LEFT", row, "LEFT", 0, 0)
        statusBar:SetPoint("TOP", row, "TOP", 0, 0)
        statusBar:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
        local statusBarTex = statusBar:CreateTexture(nil, "ARTWORK")
        statusBarTex:SetAllPoints()

        local iconFrame = CreateFrame("Button", nil, row)
        iconFrame:SetSize(rowHeight - 4, rowHeight - 4)
        iconFrame:SetPoint("LEFT", statusBar, "RIGHT", 4, 0)

        local iconTex = iconFrame:CreateTexture(nil, "ARTWORK")
        iconTex:SetAllPoints()
        iconTex:SetTexture(itemData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        if capturedData.itemLink then
            iconFrame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(capturedData.itemLink)
                GameTooltip:Show()
            end)
            iconFrame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        nameText:SetWidth(150)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)
        nameText:SetText(itemData.displayName)

        local qtyBox = CreateFrame("EditBox", nil, row, "BackdropTemplate")
        qtyBox:SetSize(45, 20)
        qtyBox:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
        qtyBox:SetBackdrop(BACKDROP_INNER)
        qtyBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        qtyBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        qtyBox:SetFontObject(GameFontHighlightSmall)
        qtyBox:SetTextInsets(4, 4, 0, 0)
        qtyBox:SetAutoFocus(false)
        qtyBox:SetNumeric(true)
        qtyBox:SetMaxLetters(5)
        qtyBox:SetJustifyH("CENTER")
        qtyBox:SetText(tostring(itemData.quantity or 1))
        qtyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        local removeBtn = CreateFrame("Button", nil, row)
        removeBtn:SetSize(18, 18)
        removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
        local removeTex = removeBtn:CreateTexture(nil, "OVERLAY")
        removeTex:SetAllPoints()
        removeTex:SetAtlas("common-icon-redx")
        removeBtn:SetNormalTexture(removeTex)
        removeBtn:GetNormalTexture():SetAlpha(0.5)
        removeBtn:SetScript("OnEnter", function(self) self:GetNormalTexture():SetAlpha(1.0) end)
        removeBtn:SetScript("OnLeave", function(self) self:GetNormalTexture():SetAlpha(0.5) end)

        if itemData.isUnresolved then
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            statusBarTex:SetColorTexture(0.6, 0.6, 0.6, 1)

            local idLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            idLabel:SetPoint("LEFT", qtyBox, "RIGHT", 6, 0)
            idLabel:SetText(L["OWSL_LABEL_ID"])
            idLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local idBox = CreateFrame("EditBox", nil, row, "BackdropTemplate")
            idBox:SetSize(55, 20)
            idBox:SetPoint("LEFT", idLabel, "RIGHT", 4, 0)
            idBox:SetBackdrop(BACKDROP_INNER)
            idBox:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            idBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            idBox:SetFontObject(GameFontHighlightSmall)
            idBox:SetTextInsets(4, 4, 0, 0)
            idBox:SetAutoFocus(false)
            idBox:SetNumeric(true)
            idBox:SetMaxLetters(6)
            idBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
            idBox:SetScript("OnEnterPressed", function(self)
                local idVal = tonumber(self:GetText())
                if idVal and idVal > 0 then
                    local ok, name = ns.ShoppingList:ConvertUnresolvedToResolved(
                        capturedListN, capturedData.key, idVal)
                    if ok then
                        print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_RESOLVED"], capturedData.displayName, name, idVal))
                        MainWindow:RefreshItemList()
                    else
                        print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ENTER_VALID_ID"])
                    end
                else
                    print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ENTER_VALID_ID"])
                end
                self:ClearFocus()
            end)

            qtyBox:SetScript("OnEnterPressed", function(self)
                local qty = tonumber(self:GetText()) or 0
                if qty > 0 then
                    ns.ShoppingList:UpdateUnresolvedQuantity(capturedListN, capturedData.key, qty)
                    self:ClearFocus()
                    MainWindow:RefreshItemList()
                else
                    self:SetText(tostring(capturedData.quantity))
                    self:ClearFocus()
                end
            end)
            removeBtn:SetScript("OnClick", function()
                ns.ShoppingList:RemoveUnresolvedItem(capturedListN, capturedData.key)
                MainWindow:RefreshItemList()
            end)
        else
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            local status = itemData.status
            if status then
                local r, g, b = unpack(status.statusColor)
                statusBarTex:SetColorTexture(r, g, b, 1)
            else
                statusBarTex:SetColorTexture(0.5, 0.5, 0.5, 1)
            end

            local locations = status and status.locations or {}

            local statusBtn = CreateFrame("Button", nil, row)
            statusBtn:SetHeight(rowHeight)
            statusBtn:SetPoint("LEFT", qtyBox, "RIGHT", 4, 0)
            statusBtn:SetPoint("RIGHT", removeBtn, "LEFT", -60, 0)
            local statusText = statusBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            statusText:SetPoint("LEFT", statusBtn, "LEFT", 4, 0)
            statusText:SetJustifyH("LEFT")
            if status then
                local r, g, b = unpack(status.statusColor)
                statusText:SetTextColor(r, g, b)
                if searchAltsOn then
                    statusText:SetText(string.format(L["OWSL_STATUS_ALTS"], status.totalOwned, status.needed))
                else
                    statusText:SetText(string.format(L["OWSL_STATUS_TOTAL"], status.owned, status.needed))
                end
            end

            if #locations > 0 then
                statusBtn:SetScript("OnEnter", function(self)
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    GameTooltip:SetText(capturedData.displayName, 1, 0.82, 0)
                    for _, locStr in ipairs(locations) do
                        GameTooltip:AddLine(locStr, 1, 1, 1)
                    end
                    GameTooltip:Show()
                end)
                statusBtn:SetScript("OnLeave", function(self)
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    GameTooltip:Hide()
                end)
            end

            local function ToggleExpanded()
                if #locations == 0 then return end
                row.isExpanded = not row.isExpanded
                if row.isExpanded then
                    if not row.expandedFrame then
                        row.expandedFrame = CreateFrame("Frame", nil, row, "BackdropTemplate")
                        row.expandedFrame:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 6, -2)
                        row.expandedFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
                        row.expandedFrame:SetBackdrop(BACKDROP_SIMPLE)
                        row.expandedFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

                        local locY = -6
                        for _, locStr in ipairs(locations) do
                            local locText = row.expandedFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                            locText:SetPoint("TOPLEFT", row.expandedFrame, "TOPLEFT", 12, locY)
                            locText:SetText(locStr)
                            locText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                            locY = locY - 16
                        end
                        row.expandedFrame:SetHeight(math.abs(locY) + 6)
                    end
                    row.expandedFrame:Show()
                else
                    if row.expandedFrame then
                        row.expandedFrame:Hide()
                    end
                end
                RepositionAllRows()
            end

            statusBar:SetScript("OnClick", ToggleExpanded)
            if #locations > 0 then
                statusBtn:SetScript("OnClick", ToggleExpanded)
            end

            if itemData.isCraftable then
                local craftBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                craftBtn:SetSize(48, 20)
                craftBtn:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)
                craftBtn:SetBackdrop(BACKDROP_INNER)
                craftBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                craftBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                local craftLabel = craftBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                craftLabel:SetPoint("CENTER")
                craftLabel:SetText(L["OWSL_BTN_CRAFT"])
                craftLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                craftBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER")) end)
                craftBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL")) end)
                craftBtn:SetScript("OnClick", function()
                    local recipes = capturedData.recipes or {}
                    if #recipes == 1 then
                        MainWindow:StartCraftOrder(capturedListN, capturedData.itemID, capturedData.quantity, recipes[1])
                    elseif #recipes > 1 then
                        local knownByData = {}
                        for _, r in ipairs(recipes) do
                            knownByData[r.recipeID] = ns.ShoppingList:GetRecipeKnownBy(r.recipeID)
                        end
                        ns.Dialogs:RecipeSelectDialog(recipes, knownByData, function(recipe)
                            MainWindow:StartCraftOrder(capturedListN, capturedData.itemID, capturedData.quantity, recipe)
                        end, mainFrame)
                    end
                end)
            end

            qtyBox:SetScript("OnEnterPressed", function(self)
                local qty = tonumber(self:GetText()) or 0
                if qty > 0 then
                    ns.ShoppingList:UpdateItemQuantity(capturedListN, capturedData.itemID, qty)
                    self:ClearFocus()
                    MainWindow:RefreshItemList()
                else
                    self:SetText(tostring(capturedData.quantity))
                    self:ClearFocus()
                end
            end)
            removeBtn:SetScript("OnClick", function()
                ns.Dialogs:ConfirmDialog(
                    L["OWSL_DIALOG_DELETE_CONFIRM"]:format(capturedData.displayName),
                    L["OWSL_DIALOG_DELETE_CONFIRM2"],
                    function()
                        ns.ShoppingList:RemoveItemFromList(capturedListN, capturedData.itemID)
                        MainWindow:RefreshItemList()
                    end,
                    L["OWSL_BTN_DELETE"],
                    mainFrame
                )
            end)
            row:SetScript("OnMouseDown", function(self, btn)
                if btn == "RightButton" then
                    MainWindow:ShowItemContextMenu(capturedData.itemID, capturedListN)
                elseif btn == "LeftButton" and IsShiftKeyDown() and capturedData.itemLink then
                    if AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
                        AuctionHouseFrame.SearchBar:SetSearchText(capturedData.displayName)
                        AuctionHouseFrame.SearchBar:StartSearch()
                        print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ADDED_TO_AH"], capturedData.displayName))
                    else
                        print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_OPEN_AH_FIRST"])
                    end
                elseif btn == "LeftButton" then
                    ToggleExpanded()
                end
            end)
            iconFrame:SetScript("OnMouseDown", function(self, btn)
                if btn == "LeftButton" and IsShiftKeyDown() and capturedData.itemLink then
                    if AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
                        AuctionHouseFrame.SearchBar:SetSearchText(capturedData.displayName)
                        AuctionHouseFrame.SearchBar:StartSearch()
                        print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_ADDED_TO_AH"], capturedData.displayName))
                    else
                        print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_OPEN_AH_FIRST"])
                    end
                elseif btn == "LeftButton" then
                    ToggleExpanded()
                end
            end)
        end

        row:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) end)
        row:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY")) end)

        row:Show()
        table.insert(itemRows, row)
        yOffset = yOffset - (rowHeight + rowGap)
    end

    RepositionAllRows()

    if statusLabel then
        local totalItems     = 0
        local completedItems = 0
        for _, itemData in ipairs(items) do
            if not itemData.isUnresolved and itemData.status then
                totalItems = totalItems + 1
                if itemData.status.status == "green" or itemData.status.status == "blue" then
                    completedItems = completedItems + 1
                end
            end
        end
        statusLabel:SetText(string.format(L["OWSL_STATUS_ITEMS_SUMMARY"], totalItems, completedItems))
        statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

function MainWindow:StartCraftOrder(listName, itemID, quantity, recipe)
    local ingredients, _ = ns.ShoppingList:CalculateCraftIngredients(recipe.recipeID, quantity)

    if not ingredients or #ingredients == 0 then
        print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_NO_INGREDIENTS"])
        return
    end

    local ok, craftOrderName, merged = ns.ShoppingList:CreateCraftOrder(
        listName, itemID, quantity, recipe.recipeID, recipe.name)

    if not ok then
        print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_CRAFT_ORDER_FAILED"])
        return
    end

    for _, ingredient in ipairs(ingredients) do
        ns.ShoppingList:AddItemToList(craftOrderName, ingredient.itemID, ingredient.baseQuantity)
    end

    local s = #ingredients ~= 1 and "s" or ""
    print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"],
        craftOrderName, #ingredients, s, merged and " (merged)" or ""))

    MainWindow:RefreshSidebar()
    MainWindow:RefreshItemList()
end

function MainWindow:ShowItemContextMenu(itemID, listName)
    local allLists = ns.ShoppingList:GetAllLists()

    MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, rootDescription)
        rootDescription:CreateTitle(L["OWSL_TT_ITEM_TITLE"])

        local moveToMenu = rootDescription:CreateButton(L["OWSL_MENU_MOVE_TO"])
        for otherListName in pairs(allLists) do
            if otherListName ~= listName then
                local capturedOther = otherListName
                moveToMenu:CreateButton(otherListName, function()
                    local ok, err = ns.ShoppingList:MoveItem(itemID, listName, capturedOther)
                    if ok then
                        local name = C_Item.GetItemNameByID(itemID) or tostring(itemID)
                        print(string.format("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_MOVED_ITEM"], name, listName, capturedOther))
                        MainWindow:RefreshSidebar()
                        MainWindow:RefreshItemList()
                    else
                        print("|cFFFFD100OneWoW Shopping List:|r " .. (err or L["OWSL_MSG_MOVE_FAILED"]:format("")))
                    end
                end)
            end
        end

        rootDescription:CreateButton(L["OWSL_MENU_CREATE_CRAFT_ORDER"], function()
            local recipes = ns.ShoppingList:GetCraftableRecipes(itemID)
            if #recipes == 0 then
                print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_NO_RECIPES"])
                return
            end
            if #recipes == 1 then
                local status = ns.ShoppingList:GetItemStatus(itemID, listName)
                local qty = status and status.needed or 1
                MainWindow:StartCraftOrder(listName, itemID, qty, recipes[1])
            else
                local knownByData = {}
                for _, r in ipairs(recipes) do
                    knownByData[r.recipeID] = ns.ShoppingList:GetRecipeKnownBy(r.recipeID)
                end
                ns.Dialogs:RecipeSelectDialog(recipes, knownByData, function(recipe)
                    local status = ns.ShoppingList:GetItemStatus(itemID, listName)
                    local qty = status and status.needed or 1
                    MainWindow:StartCraftOrder(listName, itemID, qty, recipe)
                end, mainFrame)
            end
        end)
    end)
end

function MainWindow:ShowListContextMenu(listName)
    local list = ns.ShoppingList:GetList(listName)

    MenuUtil.CreateContextMenu(UIParent, function(ownerRegion, rootDescription)
        rootDescription:CreateTitle(listName)

        if listName ~= ns.MAIN_LIST_KEY then
            rootDescription:CreateButton(L["OWSL_MENU_RENAME_LIST"], function()
                ns.Dialogs:InputDialog(
                    string.format(L["OWSL_DIALOG_RENAME"], listName),
                    listName,
                    function(newName)
                        if newName == "" then return end
                        local ok, err = ns.ShoppingList:RenameList(listName, newName)
                        if not ok then
                            print("|cFFFFD100OneWoW Shopping List:|r " .. (err or ""))
                        else
                            MainWindow:RefreshSidebar()
                            MainWindow:RefreshItemList()
                        end
                    end,
                    mainFrame
                )
            end)
        end

        rootDescription:CreateButton(L["OWSL_MENU_EXPORT_LIST"], function()
            local exportText = ns.ShoppingList:ExportList(listName)
            if exportText then
                ns.Dialogs:ExportDialog(
                    string.format(L["OWSL_EXPORT_TITLE"], listName),
                    exportText, mainFrame)
            else
                print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_EXPORT_FAILED"])
            end
        end)

        if not ns.ShoppingList:GetDefaultListName() == listName then
            rootDescription:CreateButton(L["OWSL_TT_SET_DEFAULT"], function()
                ns.ShoppingList:SetDefaultList(listName)
                MainWindow:RefreshSidebar()
            end)
        end

        if listName ~= ns.MAIN_LIST_KEY then
            rootDescription:CreateButton(L["OWSL_MENU_DELETE_LIST"], function()
                local childCount = #ns.ShoppingList:GetChildLists(listName)
                local bodyText   = L["OWSL_DIALOG_DELETE_CONFIRM2"]
                if childCount > 0 then
                    bodyText = string.format(L["OWSL_TT_DELETE_CRAFT_ORDERS"], childCount) .. "\n" .. bodyText
                end

                ns.Dialogs:ConfirmDialog(
                    string.format(L["OWSL_DIALOG_DELETE_CONFIRM"], listName),
                    bodyText,
                    function()
                        ns.ShoppingList:DeleteList(listName)
                        MainWindow:RefreshSidebar()
                        MainWindow:RefreshItemList()
                    end,
                    L["OWSL_BTN_DELETE"],
                    mainFrame
                )
            end)
        end
    end)
end

function MainWindow:Show()
    if not mainFrame then self:Create() end
    mainFrame:Show()
    self:RefreshSidebar()
    self:RefreshItemList()
end

function MainWindow:Hide()
    if mainFrame then mainFrame:Hide() end
end

function MainWindow:Toggle()
    if not mainFrame then
        self:Create()
        mainFrame:Show()
        self:RefreshSidebar()
        self:RefreshItemList()
    elseif mainFrame:IsShown() then
        mainFrame:Hide()
    else
        mainFrame:Show()
        self:RefreshSidebar()
        self:RefreshItemList()
    end
end

function MainWindow:IsShown()
    return mainFrame and mainFrame:IsShown()
end
