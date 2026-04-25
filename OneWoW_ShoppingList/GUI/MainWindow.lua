local ADDON_NAME, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end
local PE = OneWoW_GUI.PredicateEngine

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local function MatchesShoppingSearch(searchText, itemID, itemLink, displayName, quantity)
    if not searchText or searchText == "" then return true end
    if PE and itemID then
        local itemInfo = {
            hyperlink = itemLink,
            count = quantity or 1,
        }
        if C_Item and C_Item.GetItemQualityByID then
            itemInfo.quality = C_Item.GetItemQualityByID(itemID)
        end
        local ok, matched = pcall(PE.CheckItem, PE, searchText, itemID, nil, nil, itemInfo)
        if ok then return matched == true end
    end
    return displayName and displayName:lower():find(searchText:lower(), 1, true) ~= nil
end

ns.MainWindow = {}
local MainWindow = ns.MainWindow

local C = ns.Constants

local POOL_SIZE   = 32
local listRowPool = {}
local itemRows    = {}
local expandedItems = {}

local mainFrame
local sidebarPanel
local contentPanel
local settingsPanel
local searchBox
local searchAltsBtn
local currentListLabel
local statusLabel
local searchFilter   = ""
local searchAltsOn   = false
local inSettingsView = false
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
    row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    row.starBtn = CreateFrame("Button", nil, row)
    row.starBtn:SetSize(16, 16)
    row.starBtn:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.starTex = row.starBtn:CreateTexture(nil, "OVERLAY")
    row.starTex:SetAllPoints()
    row.starTex:SetAtlas("VignetteKill")
    row.starTex:SetAlpha(0.3)
    row.starBtn:SetNormalTexture(row.starTex)
    row.starBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["OWSL_TT_DEFAULT_LIST"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_TT_DEFAULT_LIST_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    row.starBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    row.favBtn = OneWoW_GUI:CreateFavoriteToggleButton(row, {
        size = 16,
        favorite = false,
        tooltipTitle = L["OWSL_TT_FAVORITE_LIST"],
        tooltipText = L["OWSL_TT_FAVORITE_LIST_DESC"],
        onClick = function(btn, isFav)
            local r = btn:GetParent()
            if r and r.data and r.data.listName then
                ns.ShoppingList:SetListFavorite(r.data.listName, isFav)
                MainWindow:RefreshSidebar()
            end
        end,
    })
    row.favBtn:SetPoint("LEFT", row.starBtn, "RIGHT", 2, 0)

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

    row.nameText = OneWoW_GUI:CreateFS(row, 12)
    row.nameText:SetPoint("LEFT",  row, "LEFT",  40, 0)
    row.nameText:SetPoint("RIGHT", row, "RIGHT", -48, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    row.countText = OneWoW_GUI:CreateFS(row, 10)
    row.countText:SetPoint("RIGHT", row, "RIGHT", -18, 0)
    row.countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    row.selectedBar = row:CreateTexture(nil, "ARTWORK")
    row.selectedBar:SetWidth(3)
    row.selectedBar:SetPoint("LEFT",   row, "LEFT",   0, 0)
    row.selectedBar:SetPoint("TOP",    row, "TOP",    0, 0)
    row.selectedBar:SetPoint("BOTTOM", row, "BOTTOM", 0, 0)
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
    row.data.listName   = listName
    row.data.isSelected = isSelected
    row.data.isDefault  = isDefault

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

    if row.favBtn then
        row.favBtn:SetFavorite(ns.ShoppingList:IsListFavorite(listName))
    end

    if list and list.isCraftOrder then
        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
    end
end

function MainWindow:Create()
    if mainFrame then return end

    mainFrame = OneWoW_GUI:CreateFrame(UIParent, {
        name     = "OneWoW_ShoppingList_MainFrame",
        width    = C.GUI.WINDOW_WIDTH,
        height   = C.GUI.WINDOW_HEIGHT,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })
    mainFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    mainFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
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
    mainFrame:SetScript("OnHide", function()
        local db = GetDB().global
        db.mainFramePosition = db.mainFramePosition or {}
        OneWoW_GUI:SaveWindowPosition(mainFrame, db.mainFramePosition)
    end)
    mainFrame:Hide()

    tinsert(UISpecialFrames, "OneWoW_ShoppingList_MainFrame")

    local titleBar = OneWoW_GUI:CreateTitleBar(mainFrame, {
        title     = L["OWSL_WINDOW_TITLE"],
        showBrand = true,
        onClose   = function() mainFrame:Hide() end,
    })
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() mainFrame:StartMoving() end)
    titleBar:SetScript("OnDragStop",  function() mainFrame:StopMovingOrSizing() end)

    local settingsToggleBtn = OneWoW_GUI:CreateFitTextButton(titleBar, { text = L["OWSL_BTN_SETTINGS"], height = 16 })
    settingsToggleBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -6, 0)
    settingsToggleBtn:SetScript("OnClick", function() MainWindow:ToggleSettings() end)

    local sidebarW = C.GUI.SIDEBAR_WIDTH
    local dividerX = sidebarW + 4

    local divider = mainFrame:CreateTexture(nil, "ARTWORK")
    divider:SetWidth(1)
    divider:SetPoint("TOP",    mainFrame, "TOPLEFT",    dividerX, -28)
    divider:SetPoint("BOTTOM", mainFrame, "BOTTOMLEFT", dividerX,   4)
    divider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    sidebarPanel = CreateFrame("Frame", nil, mainFrame)
    sidebarPanel:SetPoint("TOPLEFT",    mainFrame, "TOPLEFT",    4,  -28)
    sidebarPanel:SetPoint("BOTTOMLEFT", mainFrame, "BOTTOMLEFT", 4,    4)
    sidebarPanel:SetWidth(sidebarW)

    local sidebarHeader = OneWoW_GUI:CreateFrame(sidebarPanel, {
        bgColor     = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    sidebarHeader:SetHeight(30)
    sidebarHeader:SetPoint("TOPLEFT",  sidebarPanel, "TOPLEFT",  0, 0)
    sidebarHeader:SetPoint("TOPRIGHT", sidebarPanel, "TOPRIGHT", 0, 0)

    local sidebarTitle = OneWoW_GUI:CreateFS(sidebarHeader, 12)
    sidebarTitle:SetPoint("LEFT", sidebarHeader, "LEFT", 8, 0)
    sidebarTitle:SetText(L["OWSL_SIDEBAR_TITLE"])
    sidebarTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local newListBtn = OneWoW_GUI:CreateFitTextButton(sidebarHeader, { text = L["OWSL_BTN_NEW_LIST"], height = 22 })
    newListBtn:SetPoint("RIGHT", sidebarHeader, "RIGHT", -4, 0)
    newListBtn:SetScript("OnClick", function()
        ns.Dialogs:InputDialog(L["OWSL_DIALOG_NEW_LIST"], "", function(name)
            if name == "" then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_LIST_NAME"])
                return
            end
            local ok, err = ns.ShoppingList:CreateList(name)
            if not ok then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. (err or ""))
            else
                ns.ShoppingList:SetActiveList(name)
                MainWindow:RefreshSidebar()
                MainWindow:RefreshItemList()
            end
        end, mainFrame)
    end)

    local sidebarScrollContainer = CreateFrame("Frame", nil, sidebarPanel)
    sidebarScrollContainer:SetPoint("TOPLEFT",     sidebarPanel, "TOPLEFT",     0, -30)
    sidebarScrollContainer:SetPoint("BOTTOMRIGHT", sidebarPanel, "BOTTOMRIGHT", 0,   0)

    local sidebarScrollFrame, sidebarScrollContent = OneWoW_GUI:CreateScrollFrame(sidebarScrollContainer, {})
    sidebarPanel.scrollFrame   = sidebarScrollFrame
    sidebarPanel.scrollContent = sidebarScrollContent

    for i = 1, POOL_SIZE do
        listRowPool[i] = CreateListRow(sidebarScrollContent)
    end

    contentPanel = CreateFrame("Frame", nil, mainFrame)
    contentPanel:SetPoint("TOPLEFT",     mainFrame, "TOPLEFT",     dividerX + 1, -28)
    contentPanel:SetPoint("BOTTOMRIGHT", mainFrame, "BOTTOMRIGHT", -4, 4)

    local contentHeader = OneWoW_GUI:CreateFrame(contentPanel, {
        bgColor     = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    contentHeader:SetHeight(34)
    contentHeader:SetPoint("TOPLEFT",  contentPanel, "TOPLEFT",  0, 0)
    contentHeader:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", 0, 0)

    currentListLabel = OneWoW_GUI:CreateFS(contentHeader, 12)
    currentListLabel:SetPoint("LEFT", contentHeader, "LEFT", 8, 0)
    currentListLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local btnRight = -4

    local importBtn = OneWoW_GUI:CreateFitTextButton(contentHeader, { text = L["OWSL_BTN_IMPORT"], height = 22 })
    importBtn:SetPoint("RIGHT", contentHeader, "RIGHT", btnRight, 0)
    importBtn:SetScript("OnClick", function()
        ns.Dialogs:ImportDialog(function(text)
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok, count, nameOnly = ns.ShoppingList:ImportTextFormat(text, activeList)
            if ok then
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_IMPORTED_SUMMARY"], count - (nameOnly or 0), nameOnly or 0))
                if nameOnly and nameOnly > 0 then
                    print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_BY_NAME_NOTE"], nameOnly))
                end
                MainWindow:RefreshItemList()
                if nameOnly and nameOnly > 0 then
                    C_Timer.After(0.5, function()
                        ns.ShoppingList:ScanUnresolvedItems(activeList)
                        MainWindow:RefreshItemList()
                    end)
                end
            else
                print(L["ADDON_CHAT_PREFIX"] .. " " .. (count or L["OWSL_MSG_NO_VALID_ITEMS"]))
            end
        end, mainFrame)
    end)
    btnRight = btnRight - importBtn:GetWidth() - 4

    local scanBtn = OneWoW_GUI:CreateFitTextButton(contentHeader, { text = L["OWSL_BTN_SCAN_ALL"], height = 22 })
    scanBtn:SetPoint("RIGHT", importBtn, "LEFT", -4, 0)
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

    searchAltsBtn = OneWoW_GUI:CreateCheckbox(contentHeader, {})
    searchAltsBtn:SetPoint("RIGHT", scanBtn, "LEFT", -24, 0)
    searchAltsBtn:SetChecked(searchAltsOn)
    if searchAltsBtn.label then
        searchAltsBtn.label:ClearAllPoints()
        searchAltsBtn.label:SetPoint("RIGHT", searchAltsBtn, "LEFT", -2, 0)
        searchAltsBtn.label:SetText(L["OWSL_LABEL_SEARCH_ALTS"])
    end
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

    local shopHelpBtn
    if OneWoW_GUI.CreateKeywordHelpButton then
        shopHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(contentHeader, { size = 20 })
        shopHelpBtn:SetPoint("RIGHT", searchAltsBtn.label or searchAltsBtn, "LEFT", -6, 0)
    end

    searchBox = OneWoW_GUI:CreateEditBox(contentHeader, { name = "OWSL_SearchBox", width = 120, height = 22 })
    if shopHelpBtn then
        searchBox:SetPoint("RIGHT", shopHelpBtn, "LEFT", -4, 0)
        shopHelpBtn:SetScript("OnClick", function()
            OneWoW_GUI:ShowKeywordHelp(searchBox)
        end)
    else
        searchBox:SetPoint("RIGHT", searchAltsBtn.label or searchAltsBtn, "LEFT", -6, 0)
    end
    searchBox:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            searchFilter = self:GetText():lower()
            MainWindow:RefreshItemList()
        end
    end)
    if OneWoW_GUI.AttachSearchTooltip then
        OneWoW_GUI:AttachSearchTooltip(searchBox)
    end

    local searchLabel = OneWoW_GUI:CreateFS(contentHeader, 10)
    searchLabel:SetPoint("RIGHT", searchBox, "LEFT", -4, 0)
    searchLabel:SetText(L["OWSL_LABEL_SEARCH"])
    searchLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    contentHeaderFrame = contentHeader

    local addButtonRow = OneWoW_GUI:CreateFrame(contentPanel, {
        bgColor     = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    addButtonRow:SetHeight(32)
    addButtonRow:SetPoint("BOTTOMLEFT",  contentPanel, "BOTTOMLEFT",  0, 0)
    addButtonRow:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", 0, 0)
    addButtonRowFrame = addButtonRow

    statusLabel = OneWoW_GUI:CreateFS(addButtonRow, 10)
    statusLabel:SetPoint("LEFT", addButtonRow, "LEFT", 8, 0)
    statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local dragBtn = OneWoW_GUI:CreateFitTextButton(addButtonRow, { text = L["OWSL_BTN_DRAG_ITEM"], height = 24 })
    dragBtn:SetPoint("RIGHT", addButtonRow, "RIGHT", -4, 0)

    local function HandleDrop()
        local dragType, id = GetCursorInfo()
        if dragType == "item" then
            ClearCursor()
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok = ns.ShoppingList:AddItemToList(activeList, id, 1)
            if ok then
                local name = id and C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            end
        end
    end

    dragBtn:SetScript("OnReceiveDrag", HandleDrop)
    dragBtn:SetScript("OnClick",       HandleDrop)

    local addByIdBtn = OneWoW_GUI:CreateFitTextButton(addButtonRow, { text = L["OWSL_BTN_ADD_BY_ID"], height = 24 })
    addByIdBtn:SetPoint("RIGHT", dragBtn, "LEFT", -4, 0)
    addByIdBtn:SetScript("OnClick", function()
        ns.Dialogs:InputDialog(L["OWSL_DIALOG_ADD_BY_ID"], "", function(val)
            local id = tonumber(val)
            if not id or id <= 0 then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_VALID_ID"])
                return
            end
            local activeList = ns.ShoppingList:GetActiveListName()
            local ok = ns.ShoppingList:AddItemToList(activeList, id, 1)
            if ok then
                local name = C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            else
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_INVALID_ID"])
            end
        end, mainFrame)
    end)

    local listContainer = CreateFrame("Frame", nil, contentPanel)
    listContainer:SetPoint("TOPLEFT",     contentHeader,  "BOTTOMLEFT",  0,  -2)
    listContainer:SetPoint("BOTTOMRIGHT", addButtonRow,   "TOPRIGHT",    0,   2)

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(listContainer, {})
    contentPanel.listContainer  = listContainer
    contentPanel.scrollFrame    = scrollFrame
    contentPanel.scrollContent  = scrollContent

    self:BuildSettingsPanel()
    self:RegisterDragDrop(mainFrame)

    ns.ShoppingList:SetActiveList(ns.ShoppingList:GetActiveListName())
end

function MainWindow:BuildSettingsPanel()
    settingsPanel = OneWoW_GUI:CreateFrame(contentPanel, {
        backdrop    = OneWoW_GUI.Constants.BACKDROP_SOFT,
        bgColor     = "BG_PRIMARY",
        borderColor = "BORDER_DEFAULT",
    })
    settingsPanel:SetAllPoints(contentPanel)
    settingsPanel:Hide()

    local settingsTitle = OneWoW_GUI:CreateFS(settingsPanel, 16)
    settingsTitle:SetPoint("TOPLEFT", settingsPanel, "TOPLEFT", 12, -12)
    settingsTitle:SetText(L["OWSL_SETTINGS_TITLE"])
    settingsTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local backBtn = OneWoW_GUI:CreateFitTextButton(settingsPanel, { text = L["OWSL_BTN_BACK"], height = 24 })
    backBtn:SetPoint("TOPRIGHT", settingsPanel, "TOPRIGHT", -12, -12)
    backBtn:SetScript("OnClick", function() MainWindow:ToggleSettings() end)

    local settingsScrollContainer = CreateFrame("Frame", nil, settingsPanel)
    settingsScrollContainer:SetPoint("TOPLEFT",     settingsPanel, "TOPLEFT",     0, -40)
    settingsScrollContainer:SetPoint("BOTTOMRIGHT", settingsPanel, "BOTTOMRIGHT", 0,   0)

    local _, scrollContent = OneWoW_GUI:CreateScrollFrame(settingsScrollContainer, {})

    local pad  = 12
    local yOff = -pad

    yOff = OneWoW_GUI:CreateSettingsPanel(scrollContent, { yOffset = yOff, addonName = "OneWoW_ShoppingList" })

    local tooltipCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_ENABLE_TOOLTIP"] })
    tooltipCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    local db = GetDB()
    tooltipCb:SetChecked(db and db.global.settings.enableTooltips or true)
    tooltipCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then dbRef.global.settings.enableTooltips = self:GetChecked() end
    end)
    yOff = yOff - 26

    local wrapNamesCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_WRAP_NAMES"] })
    wrapNamesCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    wrapNamesCb:SetChecked(db and db.global.settings.wrapItemNames ~= false)
    wrapNamesCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.wrapItemNames = self:GetChecked()
            MainWindow:RefreshItemList()
        end
    end)
    wrapNamesCb:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["OWSL_SETTINGS_WRAP_NAMES"], 1, 1, 1)
        GameTooltip:AddLine(L["OWSL_SETTINGS_WRAP_NAMES_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    wrapNamesCb:HookScript("OnLeave", function() GameTooltip:Hide() end)
    yOff = yOff - 26

    local overlayCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_ENABLE_OVERLAY"] })
    overlayCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    local settings = db and db.global.settings or {}
    local overlay  = settings.overlay or {}
    overlayCb:SetChecked(overlay.enabled ~= false)
    overlayCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.overlay.enabled = self:GetChecked()
            ns.BagOverlays:UpdateAllSettings()
        end
    end)
    yOff = yOff - 26

    local curS = GetSettings()

    local bagBtnCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_SHOW_BAG_BUTTONS"] })
    bagBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    bagBtnCb:SetChecked(curS.showBagButtons ~= false)
    bagBtnCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.showBagButtons = self:GetChecked()
            ns.BagButton:UpdateVisibility()
        end
    end)
    yOff = yOff - 26

    local profBtnCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_SHOW_PROF_BUTTONS"] })
    profBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    profBtnCb:SetChecked(curS.showProfessionButtons ~= false)
    profBtnCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.showProfessionButtons = self:GetChecked()
            ns.ProfessionUI:UpdateVisibility()
        end
    end)
    yOff = yOff - 26

    local ordersBtnCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_SHOW_ORDERS_BUTTONS"] })
    ordersBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    ordersBtnCb:SetChecked(curS.showOrdersButtons ~= false)
    ordersBtnCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.showOrdersButtons = self:GetChecked()
            if ns.OrdersUI and ns.OrdersUI.UpdateVisibility then
                ns.OrdersUI:UpdateVisibility()
            end
        end
    end)
    yOff = yOff - 26

    local ahBtnCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_SHOW_AH_BUTTON"] })
    ahBtnCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    ahBtnCb:SetChecked(curS.showAHButton ~= false)
    ahBtnCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then
            dbRef.global.settings.showAHButton = self:GetChecked()
            ns.BagButton:UpdateAHVisibility()
        end
    end)
    yOff = yOff - 30

    local function AddSectionHeader(text, y)
        local h = OneWoW_GUI:CreateFS(scrollContent, 11)
        h:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        h:SetText(text)
        h:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        return h
    end

    AddSectionHeader(L["OWSL_SETTINGS_CONFIRMATIONS"], yOff)
    yOff = yOff - 22

    local confirmItemCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_CONFIRM_ITEM_DELETE"] })
    confirmItemCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    confirmItemCb:SetChecked(curS.confirmItemDelete ~= false)
    confirmItemCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then dbRef.global.settings.confirmItemDelete = self:GetChecked() end
    end)
    yOff = yOff - 26

    local confirmListCb = OneWoW_GUI:CreateCheckbox(scrollContent, { label = L["OWSL_SETTINGS_CONFIRM_LIST_DELETE"] })
    confirmListCb:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    confirmListCb:SetChecked(curS.confirmListDelete ~= false)
    confirmListCb:SetScript("OnClick", function(self)
        local dbRef = GetDB()
        if dbRef then dbRef.global.settings.confirmListDelete = self:GetChecked() end
    end)
    yOff = yOff - 30

    local function AddStatusRow(labelText, detected, y)
        local lbl = OneWoW_GUI:CreateFS(scrollContent, 12)
        lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        lbl:SetText(labelText)
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local status = OneWoW_GUI:CreateFS(scrollContent, 12)
        status:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 220, y)
        if detected then
            status:SetText(L["OWSL_SETTINGS_DETECTED"])
            status:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
        else
            status:SetText(L["OWSL_SETTINGS_NOT_DETECTED"])
            status:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    AddSectionHeader(L["OWSL_SETTINGS_ADDON_STATUS"], yOff)
    yOff = yOff - 22

    AddStatusRow(L["OWSL_SETTINGS_ALT_ACCESS"],    ns.DataAccess:HasAltData(), yOff); yOff = yOff - 20
    AddStatusRow(L["OWSL_SETTINGS_WARBAND_ACCESS"], ns.DataAccess:HasAltData(), yOff); yOff = yOff - 20
    AddStatusRow(L["OWSL_SETTINGS_RECIPE_DATA"],    _G.OneWoW_CatalogData_Tradeskills ~= nil, yOff); yOff = yOff - 24

    AddSectionHeader(L["OWSL_SETTINGS_KEYBINDS"], yOff)
    yOff = yOff - 22

    local function AddKeybindRow(labelText, bindingName, y)
        local lbl = OneWoW_GUI:CreateFS(scrollContent, 12)
        lbl:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, y)
        lbl:SetText(labelText)
        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local binding = GetBindingKey(bindingName)
        local bVal = OneWoW_GUI:CreateFS(scrollContent, 12)
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

    local bindInfoLabel = OneWoW_GUI:CreateFS(scrollContent, 10)
    bindInfoLabel:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", pad, yOff)
    bindInfoLabel:SetText(L["OWSL_SETTINGS_KEYBIND_INFO"])
    bindInfoLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    scrollContent:SetHeight(math.abs(yOff) + 20)
end

function MainWindow:Rebuild()
    if mainFrame then mainFrame:Hide() end
    mainFrame          = nil
    sidebarPanel       = nil
    contentPanel       = nil
    settingsPanel      = nil
    contentHeaderFrame = nil
    addButtonRowFrame  = nil
    searchBox          = nil
    searchAltsBtn      = nil
    currentListLabel   = nil
    statusLabel        = nil
    inSettingsView     = false
    expandedItems      = {}
    listRowPool        = {}
    itemRows           = {}
end

function MainWindow:ShowSettings()
    self:Show()
    if not inSettingsView then self:ToggleSettings() end
end

function MainWindow:ToggleSettings()
    inSettingsView = not inSettingsView
    if inSettingsView then
        settingsPanel:Show()
        if contentPanel.listContainer then contentPanel.listContainer:Hide() end
        if contentPanel.scrollFrame   then contentPanel.scrollFrame:Hide() end
        if contentHeaderFrame         then contentHeaderFrame:Hide() end
        if addButtonRowFrame          then addButtonRowFrame:Hide() end
    else
        settingsPanel:Hide()
        if contentPanel.listContainer then contentPanel.listContainer:Show() end
        if contentPanel.scrollFrame   then contentPanel.scrollFrame:Show() end
        if contentHeaderFrame         then contentHeaderFrame:Show() end
        if addButtonRowFrame          then addButtonRowFrame:Show() end
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
                local name = id and C_Item.GetItemNameByID(id) or string.format(L["OWSL_ITEM_PREFIX"], id)
                print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_LIST"], name, activeList))
                MainWindow:RefreshItemList()
            end
        end
    end)
end

function MainWindow:RefreshSidebar()
    if not sidebarPanel then return end

    HideAllRows(listRowPool)

    local allLists    = ns.ShoppingList:GetAllLists()
    local activeList  = ns.ShoppingList:GetActiveListName()
    local defaultList = ns.ShoppingList:GetDefaultListName()

    local parentLists = {}
    local childrenOf  = {}

    for listName, listData in pairs(allLists) do
        if listData.parentList then
            childrenOf[listData.parentList] = childrenOf[listData.parentList] or {}
            table.insert(childrenOf[listData.parentList], listName)
        else
            table.insert(parentLists, listName)
        end
    end

    table.sort(parentLists, function(a, b)
        if a == defaultList then return true end
        if b == defaultList then return false end
        local fa = ns.ShoppingList:IsListFavorite(a)
        local fb = ns.ShoppingList:IsListFavorite(b)
        if fa ~= fb then return fa end
        if a == ns.MAIN_LIST_KEY then return true end
        if b == ns.MAIN_LIST_KEY then return false end
        return a < b
    end)

    local scrollContent = sidebarPanel.scrollContent
    local rowIdx  = 1
    local yOff    = 0

    local INDENT   = { [0] = 0,  [1] = 16, [2] = 28, [3] = 40 }
    local HEIGHT   = { [0] = 32, [1] = 28, [2] = 26, [3] = 24 }
    local YADVANCE = { [0] = 34, [1] = 30, [2] = 28, [3] = 26 }
    local MAX_DEPTH = 3

    local function RenderListEntry(listName, depth)
        if rowIdx > POOL_SIZE then return end

        local row        = listRowPool[rowIdx]
        local isSelected = (listName == activeList)
        local isDefault  = (depth == 0) and (listName == defaultList)
        local childCount = childrenOf[listName] and #childrenOf[listName] or 0
        ConfigureListRow(row, listName, isSelected, isDefault, childCount, 0)

        local indent   = INDENT[depth]   or 40
        local height   = HEIGHT[depth]   or 24
        local yAdvance = YADVANCE[depth] or 26

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  indent, -yOff)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0,      -yOff)
        row:SetHeight(height)

        if depth > 0 then
            row.starBtn:Hide()
            row.favBtn:ClearAllPoints()
            row.favBtn:SetPoint("LEFT", row, "LEFT", 4, 0)
            row.nameText:SetPoint("LEFT", row, "LEFT", 24, 0)
        else
            row.starBtn:Show()
            row.favBtn:ClearAllPoints()
            row.favBtn:SetPoint("LEFT", row.starBtn, "RIGHT", 2, 0)
            row.nameText:SetPoint("LEFT", row, "LEFT", 40, 0)
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
                if GetSettings().confirmListDelete == false then
                    ns.ShoppingList:DeleteList(capturedName)
                    MainWindow:RefreshSidebar()
                    MainWindow:RefreshItemList()
                    return
                end
                ns.Dialogs:ConfirmDialog(
                    string.format(L["OWSL_DIALOG_DELETE_CONFIRM"], capturedName),
                    L["OWSL_DIALOG_DELETE_CONFIRM2"],
                    function()
                        ns.ShoppingList:DeleteList(capturedName)
                        MainWindow:RefreshSidebar()
                        MainWindow:RefreshItemList()
                    end,
                    L["OWSL_BTN_DELETE"],
                    mainFrame,
                    {
                        showDontAskAgain = true,
                        onDontAskAgain = function()
                            local db = GetDB()
                            if db then db.global.settings.confirmListDelete = false end
                        end,
                    }
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
        yOff   = yOff + yAdvance

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
        local _, itemLink, _, _, _, _, _, _, _, iconFile = C_Item.GetItemInfo(itemID)
        if MatchesShoppingSearch(searchFilter, itemID, itemLink, displayName, itemInfo.quantity) then
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
        if searchFilter == "" or (name and name:lower():find(searchFilter, 1, true)) then
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
    local wrapNames = GetSettings().wrapItemNames ~= false

    local function RepositionAllRows()
        local y = -2
        for _, r in ipairs(itemRows) do
            local rH = r.customHeight or rowHeight
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, y)
            r:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, y)
            y = y - (rH + rowGap)
            if r.isExpanded and r.expandedFrame and r.expandedFrame:IsShown() then
                y = y - (r.expandedFrame:GetHeight() + rowGap)
            end
        end
        scrollContent:SetHeight(math.abs(y) + 10)
    end

    for _, itemData in ipairs(items) do
        local capturedData  = itemData
        local capturedListN = activeList

        local row = OneWoW_GUI:CreateFrame(scrollContent, {
            bgColor     = "BG_TERTIARY",
        })
        row:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, yOffset)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        row:SetHeight(rowHeight)
        row:EnableMouse(true)

        local statusBar = CreateFrame("Button", nil, row)
        statusBar:SetWidth(6)
        statusBar:SetPoint("LEFT",   row, "LEFT",   0, 0)
        statusBar:SetPoint("TOP",    row, "TOP",    0, 0)
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
            iconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        local nameText = OneWoW_GUI:CreateFS(row, 12)
        nameText:SetPoint("LEFT", iconFrame, "RIGHT", 6, 0)
        nameText:SetWidth(150)
        nameText:SetJustifyH("LEFT")
        if wrapNames then
            nameText:SetWordWrap(true)
            nameText:SetNonSpaceWrap(true)
            nameText:SetMaxLines(2)
        else
            nameText:SetWordWrap(false)
            nameText:SetNonSpaceWrap(false)
        end
        nameText:SetText(itemData.displayName)

        if wrapNames then
            local nameH      = nameText:GetStringHeight() or 0
            local neededRowH = math.ceil(nameH) + 8
            if neededRowH > rowHeight then
                row:SetHeight(neededRowH)
                row.customHeight = neededRowH
            end
        end

        local qtyBox = OneWoW_GUI:CreateEditBox(row, { width = 45, height = 20 })
        qtyBox:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
        qtyBox:SetNumeric(true)
        qtyBox:SetMaxLetters(5)
        qtyBox:SetJustifyH("CENTER")
        qtyBox:SetText(tostring(itemData.quantity or 1))

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
            statusBarTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local idLabel = OneWoW_GUI:CreateFS(row, 10)
            idLabel:SetPoint("LEFT", qtyBox, "RIGHT", 6, 0)
            idLabel:SetText(L["OWSL_LABEL_ID"])
            idLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            local idBox = OneWoW_GUI:CreateEditBox(row, { width = 55, height = 20 })
            idBox:SetPoint("LEFT", idLabel, "RIGHT", 4, 0)
            idBox:SetNumeric(true)
            idBox:SetMaxLetters(6)
            idBox:SetScript("OnEnterPressed", function(self)
                local idVal = tonumber(self:GetText())
                if idVal and idVal > 0 then
                    local ok, name = ns.ShoppingList:ConvertUnresolvedToResolved(
                        capturedListN, capturedData.key, idVal)
                    if ok then
                        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_RESOLVED"], capturedData.displayName, name, idVal))
                        MainWindow:RefreshItemList()
                    else
                        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_VALID_ID"])
                    end
                else
                    print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ENTER_VALID_ID"])
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
                statusBarTex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end

            local locations = status and status.locations or {}

            local statusBtn = CreateFrame("Button", nil, row)
            statusBtn:SetHeight(rowHeight)
            statusBtn:SetPoint("LEFT",  qtyBox,     "RIGHT", 4,    0)
            statusBtn:SetPoint("RIGHT", removeBtn,  "LEFT",  -60,  0)
            local statusText = OneWoW_GUI:CreateFS(statusBtn, 10)
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
                        row.expandedFrame:SetPoint("TOPLEFT",  row, "BOTTOMLEFT",  6, -2)
                        row.expandedFrame:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
                        row.expandedFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
                        row.expandedFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))

                        local locY = -6
                        for _, locStr in ipairs(locations) do
                            local locText = OneWoW_GUI:CreateFS(row.expandedFrame, 10)
                            locText:SetPoint("TOPLEFT", row.expandedFrame, "TOPLEFT", 12, locY)
                            locText:SetText(locStr)
                            locText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                            locY = locY - 16
                        end
                        row.expandedFrame:SetHeight(math.abs(locY) + 6)
                    end
                    row.expandedFrame:Show()
                else
                    if row.expandedFrame then row.expandedFrame:Hide() end
                end
                RepositionAllRows()
            end

            statusBar:SetScript("OnClick", ToggleExpanded)
            if #locations > 0 then
                statusBtn:SetScript("OnClick", ToggleExpanded)
            end

            if itemData.isCraftable then
                local craftBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["OWSL_BTN_CRAFT"], height = 20 })
                craftBtn:SetPoint("RIGHT", removeBtn, "LEFT", -4, 0)
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
                if GetSettings().confirmItemDelete == false then
                    ns.ShoppingList:RemoveItemFromList(capturedListN, capturedData.itemID)
                    MainWindow:RefreshItemList()
                    return
                end
                ns.Dialogs:ConfirmDialog(
                    L["OWSL_DIALOG_DELETE_CONFIRM"]:format(capturedData.displayName),
                    L["OWSL_DIALOG_DELETE_CONFIRM2"],
                    function()
                        ns.ShoppingList:RemoveItemFromList(capturedListN, capturedData.itemID)
                        MainWindow:RefreshItemList()
                    end,
                    L["OWSL_BTN_DELETE"],
                    mainFrame,
                    {
                        showDontAskAgain = true,
                        onDontAskAgain = function()
                            local db = GetDB()
                            if db then db.global.settings.confirmItemDelete = false end
                        end,
                    }
                )
            end)
            row:SetScript("OnMouseDown", function(self, btn)
                if btn == "RightButton" then
                    MainWindow:ShowItemContextMenu(capturedData.itemID, capturedListN)
                elseif btn == "LeftButton" and IsShiftKeyDown() and capturedData.itemLink then
                    if AuctionHouseFrame and AuctionHouseFrame:IsVisible() then
                        AuctionHouseFrame.SearchBar:SetSearchText(capturedData.displayName)
                        AuctionHouseFrame.SearchBar:StartSearch()
                        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_ADDED_TO_AH"], capturedData.displayName))
                    else
                        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_OPEN_AH_FIRST"])
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
                    else
                        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_OPEN_AH_FIRST"])
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
        yOffset = yOffset - ((row.customHeight or rowHeight) + rowGap)
    end

    RepositionAllRows()

    if statusLabel then
        local totalItems     = 0
        local completedItems = 0
        for _, item in ipairs(items) do
            if not item.isUnresolved and item.status then
                totalItems = totalItems + 1
                if item.status.status == "green" or item.status.status == "blue" then
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
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_NO_INGREDIENTS"])
        return
    end

    local ok, craftOrderName, merged = ns.ShoppingList:CreateCraftOrder(
        listName, itemID, quantity, recipe.recipeID, recipe.name)

    if not ok then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_FAILED"])
        return
    end

    for _, ingredient in ipairs(ingredients) do
        ns.ShoppingList:AddItemToList(craftOrderName, ingredient.itemID, ingredient.baseQuantity)
    end

    local s = #ingredients ~= 1 and "s" or ""
    print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_CRAFT_ORDER_UNDER"],
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
                        print(string.format(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_MOVED_ITEM"], name, listName, capturedOther))
                        MainWindow:RefreshSidebar()
                        MainWindow:RefreshItemList()
                    else
                        print(L["ADDON_CHAT_PREFIX"] .. " " .. (err or L["OWSL_MSG_MOVE_FAILED"]:format("")))
                    end
                end)
            end
        end

        rootDescription:CreateButton(L["OWSL_MENU_CREATE_CRAFT_ORDER"], function()
            local recipes = ns.ShoppingList:GetCraftableRecipes(itemID)
            if #recipes == 0 then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_NO_RECIPES"])
                return
            end
            if #recipes == 1 then
                local status = ns.ShoppingList:GetItemStatus(itemID, listName)
                local qty    = status and status.needed or 1
                MainWindow:StartCraftOrder(listName, itemID, qty, recipes[1])
            else
                local knownByData = {}
                for _, r in ipairs(recipes) do
                    knownByData[r.recipeID] = ns.ShoppingList:GetRecipeKnownBy(r.recipeID)
                end
                ns.Dialogs:RecipeSelectDialog(recipes, knownByData, function(recipe)
                    local status = ns.ShoppingList:GetItemStatus(itemID, listName)
                    local qty    = status and status.needed or 1
                    MainWindow:StartCraftOrder(listName, itemID, qty, recipe)
                end, mainFrame)
            end
        end)
    end)
end

function MainWindow:ShowListContextMenu(listName)
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
                            print(L["ADDON_CHAT_PREFIX"] .. " " .. (err or ""))
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
                ns.Dialogs:ExportDialog(string.format(L["OWSL_EXPORT_TITLE"], listName), exportText, mainFrame)
            else
                print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_EXPORT_FAILED"])
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
                if GetSettings().confirmListDelete == false then
                    ns.ShoppingList:DeleteList(listName)
                    MainWindow:RefreshSidebar()
                    MainWindow:RefreshItemList()
                    return
                end
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
                    mainFrame,
                    {
                        showDontAskAgain = true,
                        onDontAskAgain = function()
                            local db = GetDB()
                            if db then db.global.settings.confirmListDelete = false end
                        end,
                    }
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
