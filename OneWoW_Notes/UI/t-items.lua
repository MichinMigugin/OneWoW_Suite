local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI

ns.UI = ns.UI or {}

local selectedItem  = nil
local itemListItems = {}
local categoryFilter = "All"
local storageFilter  = "All"
local searchFilter   = ""
local currentSort    = { by = "name", ascending = true }

local detailPanel    = nil
local emptyMessage   = nil
local leftStatusText = nil
local scrollChild    = nil

local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE
local Detail = ns.Constants.Detail

function ns.UI.CreateItemsTab(parent)
    do
        local p = ns.db.global.tabSortPrefs.items
        currentSort.by        = ns.UI.NormalizeSortBy(p.by) or "name"
        currentSort.ascending = p.ascending ~= false
        if p.by == "manual" then
            ns.db.global.tabSortPrefs.items = { by = "custom", ascending = p.ascending ~= false }
        end
    end

    local controlPanel = ns.UI.CreateThemedBar(nil, parent)
    controlPanel:SetPoint("TOPLEFT",  parent, "TOPLEFT",  0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(45)
    controlPanel:EnableMouse(true)

    local addItemBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["ADD_ITEM"], height = 25, minWidth = 80 })
    addItemBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -10)
    addItemBtn:RegisterForDrag("LeftButton")
    addItemBtn:SetScript("OnClick", function()
        local cursorType, itemID = GetCursorInfo()
        if cursorType == "item" and itemID then
            if ns.Items then
                local itemName = C_Item.GetItemNameByID(itemID)
                if ns.Items:GetItem(itemID) then
                    print("|cFFFFD100OneWoW - Items:|r " .. string.format(L["MSG_ITEM_EXISTS"], (itemName or itemID)))
                    ClearCursor()
                    return
                end
                ns.Items:AddItem(itemID, { category = "General", storage = "account" })
                parent.RefreshItemsList()
                ClearCursor()
            end
        else
            print("|cFFFFD100OneWoW - Items:|r " .. (L["MSG_DRAG_ITEM"]))
        end
    end)
    addItemBtn:SetScript("OnReceiveDrag", function()
        local cursorType, itemID = GetCursorInfo()
        if cursorType == "item" and itemID and ns.Items then
            ns.Items:AddItem(itemID, { category = "General", storage = "account" })
            parent.RefreshItemsList()
            ClearCursor()
        end
    end)
    addItemBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["ADD_ITEM"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_ITEM_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addItemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    controlPanel:SetScript("OnReceiveDrag", function()
        local cursorType, itemID = GetCursorInfo()
        if cursorType == "item" and itemID and ns.Items then
            ns.Items:AddItem(itemID, { category = "General", storage = "account" })
            parent.RefreshItemsList()
            ClearCursor()
        end
        controlPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    end)
    controlPanel:SetScript("OnEnter", function()
        if GetCursorInfo() == "item" then
            controlPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        end
    end)
    controlPanel:SetScript("OnLeave", function()
        controlPanel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    end)

    local addByIDBtn = OneWoW_GUI:CreateFitTextButton(controlPanel, { text = L["ADD_BY_ID"], height = 25, minWidth = 70 })
    addByIDBtn:SetPoint("LEFT", addItemBtn, "RIGHT", 5, 0)
    addByIDBtn:SetScript("OnClick", function()
        if ns.UI and ns.UI.ShowAddItemByIDDialog then
            ns.UI.ShowAddItemByIDDialog(parent)
        end
    end)
    addByIDBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TOOLTIP_BUTTON_ADD_BY_ID"], 1, 1, 1)
        GameTooltip:AddLine(L["TOOLTIP_BUTTON_ADD_BY_ID_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    addByIDBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, CATEGORY, 140, 25)
    catDD:SetPoint("LEFT", addByIDBtn, "RIGHT", 8, 0)
    local storeDD
    local function CountItemsForFilters(ignoreDim)
        local counts = { all = 0, byCategory = {}, byStorage = { All = 0, account = 0, character = 0 } }
        if not ns.Items then return counts end
        local searchLower = (searchFilter or ""):lower()
        for _, itemData in pairs(ns.Items:GetAllItems()) do
            if type(itemData) == "table" then
                local ok = true
                if ignoreDim ~= "category" and categoryFilter ~= "All"
                    and itemData.category ~= categoryFilter then
                    ok = false
                end
                if ignoreDim ~= "storage" and storageFilter ~= "All"
                    and itemData.storage ~= storageFilter then
                    ok = false
                end
                if searchLower ~= "" then
                    local nameLower = (itemData.name or ""):lower()
                    if not nameLower:find(searchLower, 1, true) then
                        ok = false
                    end
                end
                if ok then
                    counts.all = counts.all + 1
                    local cat = itemData.category or "General"
                    counts.byCategory[cat] = (counts.byCategory[cat] or 0) + 1
                    local stor = itemData.storage == "character" and "character" or "account"
                    counts.byStorage[stor] = (counts.byStorage[stor] or 0) + 1
                    counts.byStorage.All = counts.byStorage.All + 1
                end
            end
        end
        return counts
    end
    local function RefreshCatOptions()
        local catCounts = CountItemsForFilters("category")
        local opts = {{
            text = ALL,
            value = "All",
            rightText = ns.UI.FormatSectionCount(catCounts.all),
        }}
        if ns.Items then
            for _, c in ipairs(ns.Items:GetCategories()) do
                opts[#opts + 1] = {
                    text = c,
                    value = c,
                    rightText = ns.UI.FormatSectionCount(catCounts.byCategory[c] or 0),
                }
            end
        end
        catDD:SetOptions(opts)
        catDD:SetSelected(categoryFilter)
    end
    RefreshCatOptions()
    catDD.onSelect = function(value)
        categoryFilter = value
        parent.RefreshItemsList()
    end

    local manageCategoriesBtn = OneWoW_GUI:CreateIconButton(controlPanel, {
        iconTexture = MEDIA .. "icon-gears.png",
        size = 20,
        texCoord = { 0.1, 0.9, 0.1, 0.9 },
        tooltipTitle = L["CATMGR_TITLE"],
        tooltipText = L["UI_MANAGE_CATEGORIES_DESC"],
        onClick = function()
            ns.UI.ShowCategoryManager("items")
        end,
    })
    manageCategoriesBtn:SetPoint("LEFT", catDD, "RIGHT", 4, 0)

    storeDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_STORAGE"], 130, 25)
    storeDD:SetPoint("LEFT", manageCategoriesBtn, "RIGHT", 4, 0)
    local function RefreshStorageOpts()
        local storCounts = CountItemsForFilters("storage")
        storeDD:SetOptions({
            {text = ALL, value = "All",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.All)},
            {text = L["UI_STORAGE_ACCOUNT"], value = "account",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.account)},
            {text = CHARACTER, value = "character",
                rightText = ns.UI.FormatSectionCount(storCounts.byStorage.character)},
        })
        storeDD:SetSelected(storageFilter)
    end
    RefreshStorageOpts()
    storeDD.onSelect = function(value)
        storageFilter = value
        parent.RefreshItemsList()
    end

    local itemSortHandle = OneWoW_GUI:CreateSortControls(controlPanel, {
        sortFields = {
            {key = "name",     label = NAME},
            {key = "category", label = CATEGORY},
            {key = "custom",   label = CUSTOM},
        },
        defaultField  = currentSort.by,
        defaultAsc    = currentSort.ascending,
        dropdownWidth = 100,
        onChange = function(field, ascending)
            currentSort.by        = field
            currentSort.ascending = ascending
            ns.db.global.tabSortPrefs.items = { by = field, ascending = ascending }
            parent.RefreshItemsList()
        end,
    })
    itemSortHandle.dropdown:SetPoint("LEFT", storeDD, "RIGHT", 6, 0)
    itemSortHandle.dirBtn:SetPoint("LEFT", itemSortHandle.dropdown, "RIGHT", 4, 0)

    local helpButton = CreateFrame("Button", nil, controlPanel)
    helpButton:SetSize(28, 28)
    helpButton:SetPoint("TOPRIGHT", controlPanel, "TOPRIGHT", -10, -10)
    local helpIcon = helpButton:CreateTexture(nil, "ARTWORK")
    helpIcon:SetSize(24, 24)
    helpIcon:SetPoint("CENTER", helpButton, "CENTER", 0, 0)
    helpIcon:SetAtlas("CampaignActiveQuestIcon")
    helpButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["UI_HELP_PANEL_TITLE"], 1, 1, 1)
        GameTooltip:AddLine(L["UI_NOTES_HYPERLINK_HINT"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    helpButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    helpButton:SetScript("OnClick", function()
        if not ns.UI.notesHelpPanel and ns.UI.CreateNotesHelpPanel then
            ns.UI.notesHelpPanel = ns.UI.CreateNotesHelpPanel()
        end
        if ns.UI.notesHelpPanel then
            if ns.UI.notesHelpPanel:IsShown() then
                ns.UI.notesHelpPanel:Hide()
            else
                ns.UI.notesHelpPanel:Show()
            end
        end
    end)

    local listingPanel = ns.UI.CreateThemedPanel(nil, parent)
    listingPanel:SetPoint("TOPLEFT",  controlPanel, "BOTTOMLEFT",  0, -10)
    listingPanel:SetPoint("BOTTOMLEFT", parent,     "BOTTOMLEFT",  0, 35)
    listingPanel:SetWidth(OneWoW_GUI.Constants.GUI.LEFT_PANEL_WIDTH)

    local listingTitle = OneWoW_GUI:CreateFS(listingPanel, 16)
    listingTitle:SetPoint("TOP", listingPanel, "TOP", 0, -10)
    listingTitle:SetText(L["ITEMS_LIST"])
    listingTitle:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local searchBox = OneWoW_GUI:CreateEditBox(listingPanel, {
        placeholderText = L["SEARCH"],
        onTextChanged = function(text)
            searchFilter = text
            if parent.RefreshItemsList then parent.RefreshItemsList() end
        end,
    })
    searchBox:SetPoint("TOPLEFT",  listingPanel, "TOPLEFT",  8, -30)
    searchBox:SetPoint("TOPRIGHT", listingPanel, "TOPRIGHT", -8, -30)

    function parent.ClearItemSearch()
        searchFilter = ""
        searchBox:SetText("")
    end

    local listScroll = ns.UI.CreateCustomScroll(listingPanel)
    scrollChild = listScroll.scrollChild
    listScroll.container:SetPoint("TOPLEFT",     listingPanel, "TOPLEFT",     10, -62)
    listScroll.container:SetPoint("BOTTOMRIGHT", listingPanel, "BOTTOMRIGHT", -10, 10)

    local sectionRowFrames = {}
    local sectionDataBags = {}
    local sectionReorders = {}
    local function GetOrCreateSectionReorder(sectionKey)
        if sectionReorders[sectionKey] then
            return sectionReorders[sectionKey]
        end
        local ctrl = ns.UI.CreateNotesListReorderDrag({
            getItems = function()
                return sectionRowFrames[sectionKey]
            end,
            getScrollFrame = function()
                return listScroll.scrollFrame
            end,
            onReorder = function(fromIdx, toIdx, insertBefore)
                local bag = sectionDataBags[sectionKey]
                if ns.UI.ApplySectionReorder(bag, fromIdx, toIdx, insertBefore) then
                    ns.UI.EnsureCustomSort(itemSortHandle, currentSort, "items")
                    parent.RefreshItemsList()
                end
            end,
        })
        sectionReorders[sectionKey] = ctrl
        return ctrl
    end
    local function IsAnyItemsReorderActive()
        for _, ctrl in pairs(sectionReorders) do
            if ctrl:IsActive() or ctrl:ShouldSuppressClick() then
                return true
            end
        end
        return false
    end

    detailPanel = ns.UI.CreateThemedPanel(nil, parent)
    detailPanel:SetPoint("TOPLEFT",     listingPanel, "TOPRIGHT",    10, 0)
    detailPanel:SetPoint("BOTTOMRIGHT", parent,       "BOTTOMRIGHT",  0, 35)
    detailPanel:SetClipsChildren(true)

    emptyMessage = OneWoW_GUI:CreateFS(detailPanel, 16)
    emptyMessage:SetPoint("CENTER", detailPanel, "CENTER")
    emptyMessage:SetText(L["ITEMS_SELECT"])
    emptyMessage:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local leftStatusBar = ns.UI.CreateThemedBar(nil, parent)
    leftStatusBar:SetPoint("TOPLEFT",  listingPanel, "BOTTOMLEFT",  0, -5)
    leftStatusBar:SetPoint("TOPRIGHT", listingPanel, "BOTTOMRIGHT", 0, -5)
    leftStatusBar:SetHeight(25)

    leftStatusText = OneWoW_GUI:CreateFS(leftStatusBar, 10)
    leftStatusText:SetPoint("LEFT", leftStatusBar, "LEFT", 10, 0)
    leftStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_ITEMS"], 0))

    local rightStatusBar = ns.UI.CreateThemedBar(nil, parent)
    rightStatusBar:SetPoint("TOPLEFT",     detailPanel, "BOTTOMLEFT",  0, -5)
    rightStatusBar:SetPoint("TOPRIGHT",    detailPanel, "BOTTOMRIGHT", 0, -5)
    rightStatusBar:SetHeight(25)

    local rightStatusText = OneWoW_GUI:CreateFS(rightStatusBar, 10)
    rightStatusText:SetPoint("LEFT", rightStatusBar, "LEFT", 10, 0)
    rightStatusText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rightStatusText:SetText(READY)

    local function ShowEditor()
        emptyMessage:Hide()

        for _, child in ipairs({detailPanel:GetChildren()}) do
            if child ~= emptyMessage then child:Hide() end
        end

        if not detailPanel.editorContent then
            local editorHeader = ns.UI.CreateDetailHeader(detailPanel)

            local itemIconFrame = CreateFrame("Frame", nil, editorHeader)
            itemIconFrame:SetSize(48, 48)
            itemIconFrame:SetPoint("TOPLEFT", editorHeader, "TOPLEFT", 10, -10)
            itemIconFrame:EnableMouse(true)
            editorHeader.itemIconFrame = itemIconFrame

            local itemIcon = itemIconFrame:CreateTexture(nil, "ARTWORK")
            itemIcon:SetAllPoints()
            itemIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            editorHeader.itemIcon = itemIcon

            local nameText = OneWoW_GUI:CreateFS(editorHeader, 16)
            nameText:SetPoint("LEFT",  itemIconFrame, "RIGHT", 10, 4)
            nameText:SetPoint("RIGHT", editorHeader,  "RIGHT", -100, 0)
            nameText:SetJustifyH("LEFT")
            nameText:SetText("")
            nameText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            editorHeader.nameText = nameText

            local categoryLine = OneWoW_GUI:CreateFS(editorHeader, 10)
            categoryLine:SetPoint("BOTTOMRIGHT", editorHeader, "BOTTOMRIGHT", -12, Detail.META_LINE_Y_LOWER)
            categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], GENERAL))
            categoryLine:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            categoryLine:SetJustifyH("RIGHT")
            editorHeader.categoryLine = categoryLine

            local deleteBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-trash.png",
            })
            deleteBtn:SetScript("OnClick", function()
                if selectedItem then
                    StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_ITEM"] = {
                        text = string.format(L["POPUP_DELETE_ITEM"]),
                        button1 = DELETE, button2 = CANCEL,
                        OnAccept = function()
                            if ns.Items then
                                ns.Items:RemoveItem(selectedItem)
                                selectedItem = nil
                                if detailPanel.editorContent then
                                    for _, f in pairs(detailPanel.editorContent) do
                                        if f and f.Hide then f:Hide() end
                                    end
                                end
                                parent.RefreshItemsList()
                                emptyMessage:Show()
                            end
                        end,
                        timeout = 0, whileDead = true, hideOnEscape = true
                    }
                    StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_ITEM")
                end
            end)
            deleteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_ITEM_DELETE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ITEM_DELETE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            deleteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.deleteBtn = deleteBtn

            local propertiesBtn = ns.UI.CreateHeaderIconButton(editorHeader, {
                texture = "icon-gears.png",
                relativeTo = deleteBtn,
            })
            propertiesBtn:SetScript("OnClick", function()
                if selectedItem and ns.UI and ns.UI.ShowItemPropertiesDialog then
                    ns.UI.ShowItemPropertiesDialog(selectedItem, parent)
                end
            end)
            propertiesBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["DIALOG_ITEM_PROPERTIES"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ITEM_PROPERTIES_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            propertiesBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.propertiesBtn = propertiesBtn

            local alertBtn = CreateFrame("CheckButton", nil, editorHeader)
            alertBtn:SetSize(22, 22)
            alertBtn:SetPoint("RIGHT", propertiesBtn, "LEFT", -2, 0)

            local alertNormal = alertBtn:CreateTexture(nil, "BACKGROUND")
            alertNormal:SetAllPoints()
            alertNormal:SetTexture(MEDIA .. "icon-alert.png")
            alertNormal:SetDesaturated(true)
            alertNormal:SetAlpha(0.3)
            alertBtn:SetNormalTexture(alertNormal)

            local alertHL = alertBtn:CreateTexture(nil, "HIGHLIGHT")
            alertHL:SetAllPoints()
            alertHL:SetTexture(MEDIA .. "icon-alert.png")
            alertHL:SetAlpha(0.5)
            alertBtn:SetHighlightTexture(alertHL)

            alertBtn:SetScript("OnClick", function(self)
                if selectedItem and ns.Items then
                    local itemData = ns.Items:GetItem(selectedItem)
                    if itemData then
                        itemData.alertOnLoot = not itemData.alertOnLoot
                        self:GetNormalTexture():SetDesaturated(not itemData.alertOnLoot)
                        self:GetNormalTexture():SetAlpha(itemData.alertOnLoot and 1.0 or 0.3)
                        self:SetChecked(itemData.alertOnLoot)
                        ns.Items:SaveItem(selectedItem, itemData)
                        parent.RefreshItemsList()
                    end
                end
            end)
            alertBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["ITEM_ALERT_ON_LOOT"], 1, 1, 1)
                GameTooltip:AddLine(L["ITEM_ALERT_ON_LOOT_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            alertBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.alertBtn = alertBtn

            local favoriteBtn = CreateFrame("CheckButton", nil, editorHeader)
            favoriteBtn:SetSize(22, 22)
            favoriteBtn:SetPoint("RIGHT", alertBtn, "LEFT", -2, 0)

            local favNormal = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            favNormal:SetAllPoints()
            favNormal:SetTexture(MEDIA .. "icon-fav.png")
            favNormal:SetDesaturated(true)
            favNormal:SetAlpha(0.3)
            favoriteBtn:SetNormalTexture(favNormal)

            local favChecked = favoriteBtn:CreateTexture(nil, "BACKGROUND")
            favChecked:SetAllPoints()
            favChecked:SetTexture(MEDIA .. "icon-fav.png")
            favoriteBtn:SetCheckedTexture(favChecked)

            local favHL = favoriteBtn:CreateTexture(nil, "HIGHLIGHT")
            favHL:SetAllPoints()
            favHL:SetTexture(MEDIA .. "icon-fav.png")
            favHL:SetAlpha(0.5)
            favoriteBtn:SetHighlightTexture(favHL)

            favoriteBtn:SetScript("OnClick", function(self)
                if selectedItem and ns.Items then
                    local itemData = ns.Items:GetItem(selectedItem)
                    if itemData then
                        itemData.favorite = not itemData.favorite
                        self:GetNormalTexture():SetDesaturated(not itemData.favorite)
                        self:GetNormalTexture():SetAlpha(itemData.favorite and 1.0 or 0.3)
                        self:SetChecked(itemData.favorite)
                        ns.Items:SaveItem(selectedItem, itemData)
                        parent.RefreshItemsList()
                    end
                end
            end)
            favoriteBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["TOOLTIP_ITEM_FAVORITE"], 1, 1, 1)
                GameTooltip:AddLine(L["TOOLTIP_ITEM_FAVORITE_DESC"], 0.8, 0.8, 0.8, true)
                GameTooltip:Show()
            end)
            favoriteBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            editorHeader.favoriteBtn = favoriteBtn

            local body = ns.UI.CreateDetailBody(detailPanel, editorHeader, {
                onTextChanged = function(self, userInput)
                    if userInput and selectedItem and ns.Items then
                        local itemData = ns.Items:GetItem(selectedItem)
                        if itemData then
                            itemData.content  = self:GetText()
                            itemData.modified = GetServerTime()
                        end
                    end
                end,
            })
            local contentBg = body.contentBg
            local contentScroll = body.contentScroll
            local contentEditBox = body.contentEditBox
            contentEditBox:SetHyperlinksEnabled(true)
            contentEditBox:SetScript("OnHyperlinkClick", function(_, link, text, button)
                SetItemRef(link, text, button)
            end)
            contentEditBox:SetScript("OnReceiveDrag", function(self)
                local cursorType, _, itemLink = GetCursorInfo()
                if cursorType == "item" and itemLink then
                    self:Insert(itemLink)
                    ClearCursor()
                end
            end)
            contentEditBox:SetScript("OnMouseUp", function(self, button)
                if button == "RightButton" and ns.NotesContextMenu then
                    ns.NotesContextMenu:ShowEditBoxContextMenu(self)
                end
            end)
            if ns.NotesHyperlinks then ns.NotesHyperlinks:EnhanceEditBox(contentEditBox) end
            contentEditBox._skipGlobalFont = true
            detailPanel.contentEditBox = contentEditBox

            contentBg:SetScript("OnMouseDown", function(_, button)
                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetFocus()
                    if button == "RightButton" and ns.NotesContextMenu then
                        ns.NotesContextMenu:ShowEditBoxContextMenu(detailPanel.contentEditBox)
                    end
                end
            end)

            local tip = ns.UI.CreateTooltipLinesSection(detailPanel, contentBg, {
                onLineChanged = function(index, text, userInput)
                    if userInput and selectedItem and ns.Items then
                        local itemData = ns.Items:GetItem(selectedItem)
                        if itemData then
                            if not itemData.tooltipLines then itemData.tooltipLines = {"","","",""} end
                            itemData.tooltipLines[index] = text
                        end
                    end
                end,
            })
            local tooltipSection = tip.section
            local tooltipEdits = tip.edits

            detailPanel.editorContent = {
                header         = editorHeader,
                contentBg      = contentBg,
                contentScroll  = contentScroll,
                tooltipSection = tooltipSection,
                tooltipEdits   = tooltipEdits,
            }
        end

        for _, f in pairs(detailPanel.editorContent) do
            if f and f.Show then f:Show() end
        end
        if detailPanel.contentEditBox then detailPanel.contentEditBox:Show() end
        ns.UI.activeContentEditBox = detailPanel.contentEditBox

        if selectedItem and ns.Items then
            local itemData = ns.Items:GetItem(selectedItem)
            if itemData then
                local header = detailPanel.editorContent.header

                if header.itemIcon then
                    header.itemIcon:SetTexture(itemData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
                end
                if header.nameText then
                    header.nameText:SetText(itemData.name or ("Item " .. selectedItem))
                end
                if header.categoryLine then
                    header.categoryLine:SetText(string.format(L["UI_CATEGORY_WITH_VALUE"], itemData.category or GENERAL))
                end
                if header.itemIconFrame then
                    header.itemIconFrame:SetScript("OnEnter", function(self)
                        if itemData.link then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetHyperlink(itemData.link)
                            GameTooltip:Show()
                        end
                    end)
                    header.itemIconFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
                end

                if header.alertBtn then
                    header.alertBtn:GetNormalTexture():SetDesaturated(not itemData.alertOnLoot)
                    header.alertBtn:GetNormalTexture():SetAlpha(itemData.alertOnLoot and 1.0 or 0.3)
                    header.alertBtn:SetChecked(itemData.alertOnLoot)
                end
                if header.favoriteBtn then
                    header.favoriteBtn:GetNormalTexture():SetDesaturated(not itemData.favorite)
                    header.favoriteBtn:GetNormalTexture():SetAlpha(itemData.favorite and 1.0 or 0.3)
                    header.favoriteBtn:SetChecked(itemData.favorite)
                end

                if detailPanel.contentEditBox then
                    detailPanel.contentEditBox:SetText(itemData.content or "")
                end

                if detailPanel.editorContent.tooltipEdits and itemData.tooltipLines then
                    for i = 1, 4 do
                        if detailPanel.editorContent.tooltipEdits[i] then
                            detailPanel.editorContent.tooltipEdits[i]:SetText(itemData.tooltipLines[i] or "")
                        end
                    end
                end
            end
        end
    end

    local function CreateSectionHeader(text, yPos, count)
        local section = OneWoW_GUI:CreateSectionHeader(scrollChild, {
            title = text,
            yOffset = yPos,
            rightText = ns.UI.FormatSectionCount(count),
        })
        table.insert(itemListItems, section)
        return section
    end

    function parent.RefreshItemsList()
        if scrollChild then
            scrollChild._onewowZebraSeq = nil
        end
        for _, ctrl in pairs(sectionReorders) do
            ctrl:Cancel()
        end
        for _, item in pairs(itemListItems) do
            item:Hide()
        end
        itemListItems = {}
        wipe(sectionRowFrames)
        wipe(sectionDataBags)

        RefreshCatOptions()
        RefreshStorageOpts()

        if not ns.Items then
            if leftStatusText then leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_ITEMS"], 0)) end
            return
        end

        local allItems = ns.Items:GetAllItems()
        local itemsList = {}

        for itemID, itemData in pairs(allItems) do
            if type(itemData) == "table" then
                local matches = true
                if categoryFilter ~= "All" and itemData.category ~= categoryFilter then matches = false end
                if storageFilter  ~= "All" and itemData.storage  ~= storageFilter  then matches = false end
                if searchFilter ~= "" then
                    local nameLower = (itemData.name or ""):lower()
                    if not nameLower:find(searchFilter:lower(), 1, true) then matches = false end
                end
                if matches then
                    table.insert(itemsList, {id = tonumber(itemID), data = itemData})
                end
            end
        end

        local favorites = {}
        local regular   = {}
        for _, item in ipairs(itemsList) do
            if item.data.favorite then
                table.insert(favorites, item)
            else
                table.insert(regular, item)
            end
        end

        local function sortItems(a, b)
            local nameA = a.data.name or ""
            local nameB = b.data.name or ""
            if currentSort.by == "category" then
                local ca = a.data.category or ""
                local cb = b.data.category or ""
                if ca == cb then return nameA < nameB end
                if currentSort.ascending then return ca < cb else return ca > cb end
            elseif currentSort.by == "custom" then
                local sa = a.data.sortOrder or 0
                local sb = b.data.sortOrder or 0
                if sa == sb then return nameA < nameB end
                if currentSort.ascending then return sa < sb else return sa > sb end
            elseif currentSort.by == "modified" then
                if currentSort.ascending then return (a.data.modified or 0) < (b.data.modified or 0)
                else return (a.data.modified or 0) > (b.data.modified or 0) end
            else
                if currentSort.ascending then return nameA < nameB else return nameA > nameB end
            end
        end
        table.sort(favorites, sortItems)
        table.sort(regular,   sortItems)

        local function BuildItemRow(item, yOffset, sectionKey)
            local barColor
            local qc = ITEM_QUALITY_COLORS[item.data.rarity or 1]
            if qc then
                -- Dim the (full-bright) quality color to match the other tabs' bars.
                barColor = { qc.r * 0.7, qc.g * 0.7, qc.b * 0.7 }
            end

            local rowOpts = {
                yOffset     = yOffset,
                barColor    = barColor,
                icon        = item.data.icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                title       = item.data.name or ("Item " .. item.id),
                storageText = item.data.storage == "character" and CHARACTER or L["UI_STORAGE_ACCOUNT"],
                selected    = (selectedItem == item.id),
                shouldSuppressSelect = IsAnyItemsReorderActive,
                onSelect    = function()
                    selectedItem = item.id
                    ShowEditor()
                    parent.RefreshItemsList()
                end,
                alert = {
                    active  = item.data.alertOnLoot and true or false,
                    tooltip = { title = L["ITEM_ALERT_ON_LOOT"], desc = L["ITEM_ALERT_ON_LOOT_DESC"] },
                    onToggle = function(state)
                        if not ns.Items then return end
                        local itemData = ns.Items:GetItem(item.id)
                        if not itemData then return end
                        itemData.alertOnLoot = state
                        ns.Items:SaveItem(item.id, itemData)
                        if detailPanel.editorContent and detailPanel.editorContent.header then
                            local h = detailPanel.editorContent.header
                            if h.alertBtn and selectedItem == item.id then
                                h.alertBtn:GetNormalTexture():SetDesaturated(not state)
                                h.alertBtn:GetNormalTexture():SetAlpha(state and 1.0 or 0.3)
                                h.alertBtn:SetChecked(state)
                            end
                        end
                    end,
                },
                fav = {
                    active  = item.data.favorite and true or false,
                    tooltip = { title = L["TOOLTIP_ITEM_FAVORITE"], desc = L["TOOLTIP_ITEM_FAVORITE_DESC"] },
                    onToggle = function(state)
                        if not ns.Items then return end
                        local itemData = ns.Items:GetItem(item.id)
                        if itemData then
                            itemData.favorite = state
                            ns.Items:SaveItem(item.id, itemData)
                            parent.RefreshItemsList()
                        end
                    end,
                },
                props = {
                    tooltip = { title = L["TOOLTIP_ITEM_PROPERTIES_DESC"] },
                    onClick = function()
                        if ns.UI.ShowItemPropertiesDialog then ns.UI.ShowItemPropertiesDialog(item.id, parent) end
                    end,
                },
                delete = {
                    tooltip = { title = L["TOOLTIP_ITEM_DELETE"], desc = L["TOOLTIP_ITEM_DELETE_DESC"] },
                    onClick = function()
                        StaticPopupDialogs["ONEWOW_NOTES_CONFIRM_DELETE_ITEM"] = {
                            text = string.format(L["POPUP_DELETE_ITEM"]),
                            button1 = DELETE, button2 = CANCEL,
                            OnAccept = function()
                                if ns.Items then
                                    ns.Items:RemoveItem(item.id)
                                    if selectedItem == item.id then
                                        selectedItem = nil
                                        emptyMessage:Show()
                                        if detailPanel.editorContent then
                                            for _, f in pairs(detailPanel.editorContent) do
                                                if f and f.Hide then f:Hide() end
                                            end
                                        end
                                    end
                                    parent.RefreshItemsList()
                                end
                            end,
                            timeout = 0, whileDead = true, hideOnEscape = true,
                        }
                        StaticPopup_Show("ONEWOW_NOTES_CONFIRM_DELETE_ITEM")
                    end,
                },
            }

            local row = ns.UI.CreateNotesListRow(scrollChild, rowOpts)
            table.insert(itemListItems, row)
            local frames = sectionRowFrames[sectionKey]
            frames[#frames + 1] = row
            GetOrCreateSectionReorder(sectionKey):Attach(row, #frames)
        end

        local function PaintSection(sectionKey, title, bag, yOffset)
            if #bag == 0 then
                return yOffset
            end
            sectionDataBags[sectionKey] = bag
            sectionRowFrames[sectionKey] = {}
            CreateSectionHeader(title, yOffset, #bag)
            yOffset = yOffset - 30
            for _, item in ipairs(bag) do
                BuildItemRow(item, yOffset, sectionKey)
                yOffset = yOffset - ns.UI.LIST_ROW_SPACING
            end
            return yOffset
        end

        local yOffset = 0
        yOffset = PaintSection("favorites", FAVORITES, favorites, yOffset)
        yOffset = PaintSection("items", L["TAB_ITEMS"], regular, yOffset)

        scrollChild:SetHeight(math.abs(yOffset) + 50)
        if leftStatusText then
            leftStatusText:SetText(string.format(L["UI_COUNT_FORMAT"], L["TAB_ITEMS"], #favorites + #regular))
        end
    end

    local function OpenItemEditor(itemID)
        itemID = tonumber(itemID)
        if not itemID or not ns.Items:GetItem(itemID) then
            return false
        end

        selectedItem = itemID
        searchFilter = ""
        categoryFilter = "All"
        storageFilter = "All"
        searchBox:SetText("")
        parent.RefreshItemsList()
        ShowEditor()
        parent.RefreshItemsList()
        return true
    end

    -- Opens a specific item's editor; used by cross-addon navigation.
    function parent.SelectItem(itemID)
        itemID = tonumber(itemID)
        if not itemID then return end
        selectedItem = itemID
        ShowEditor()
        parent.RefreshItemsList()
    end

    ns.UI.RefreshItemsList = parent.RefreshItemsList

    ns.UI.OpenNotesItem = function(itemID)
        itemID = tonumber(itemID)
        if not itemID then return false end
        return OpenItemEditor(itemID)
    end

    function parent.Activate()
        if ns.pendingItemSelect then
            local id = ns.pendingItemSelect
            ns.pendingItemSelect = nil
            OpenItemEditor(id)
        else
            parent.RefreshItemsList()
        end
    end

    parent.RefreshItemsList()

    if ns.pendingItemSelect then
        local id = ns.pendingItemSelect
        ns.pendingItemSelect = nil
        OpenItemEditor(id)
    end
end

local function MakeItemLabel(parent, text, x, y)
    local lbl = OneWoW_GUI:CreateFS(parent, 12)
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return lbl
end

local RARITY_COLORS = {
    [0] = {0.62, 0.62, 0.62},
    [1] = {1.00, 1.00, 1.00},
    [2] = {0.12, 1.00, 0.00},
    [3] = {0.00, 0.44, 0.87},
    [4] = {0.64, 0.21, 0.93},
    [5] = {1.00, 0.50, 0.00},
    [6] = {0.90, 0.80, 0.50},
    [7] = {0.00, 0.80, 1.00},
    [8] = {0.00, 0.80, 1.00},
}

function ns.UI.ShowAddItemByIDDialog(refreshParent)
    local COL1_X = 10
    local COL2_X = 240
    local COL_W  = 200

    local dialog = ns.UI.CreateThemedDialog({
        name            = "OneWoW_NotesAddItemByID",
        title           = L["DIALOG_ADD_ITEM_BY_ID"],
        width           = 450,
        height          = 340,
        destroyOnClose  = true,
        buttons = {
            {
                text = L["BUTTON_ADD_NOTE"],
                onClick = function(dlg)
                    if not dlg._validated then
                        print("|cFFFFD100OneWoW - Items:|r " .. (L["ITEM_VALIDATE_FIRST"]))
                        return
                    end

                    local id = dlg._validatedID
                    if not id then return end

                    local cat   = dlg._catDD   and dlg._catDD:GetValue()   or "General"
                    local store = dlg._storeDD and dlg._storeDD:GetValue() or "account"

                    if ns.Items then
                        local ok, err = ns.Items:AddItem(id, { category = cat, storage = store })
                        if ok then
                            dlg:Hide()
                            if refreshParent and refreshParent.RefreshItemsList then
                                refreshParent.RefreshItemsList()
                            end
                        else
                            print("|cFFFFD100OneWoW - Items:|r " .. (err or L["NOTES_ITEM_INVALID_ID"]))
                        end
                    end
                end,
            },
            { text = CANCEL, onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local yPos = -10
    dialog._validated = false
    dialog._validatedID = nil

    MakeItemLabel(content, L["ITEM_ID"], COL1_X, yPos)

    local idInput = OneWoW_GUI:CreateEditBox(content, {
        width = 160,
        height = 26,
    })
    idInput:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - 18)
    idInput:SetAutoFocus(true)
    idInput:SetNumeric(true)
    idInput:SetText("")
    idInput:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    idInput:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    dialog._idInput = idInput

    local validateBtn = OneWoW_GUI:CreateButton(content, { text = L["ITEM_VALIDATE"], width = 80, height = 26 })
    validateBtn:SetPoint("LEFT", idInput, "RIGHT", 6, 0)

    local resultFrame = ns.UI.CreateThemedBar(nil, content)
    resultFrame:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - 56)
    resultFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -COL1_X, yPos - 56)
    resultFrame:SetHeight(40)
    resultFrame:EnableMouse(true)
    resultFrame:Hide()
    resultFrame:SetScript("OnEnter", function(self)
        if dialog._validatedID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(dialog._validatedID)
            GameTooltip:Show()
        end
    end)
    resultFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local resultIcon = resultFrame:CreateTexture(nil, "ARTWORK")
    resultIcon:SetSize(32, 32)
    resultIcon:SetPoint("LEFT", resultFrame, "LEFT", 4, 0)

    local resultName = OneWoW_GUI:CreateFS(resultFrame, 12)
    resultName:SetPoint("LEFT", resultIcon, "RIGHT", 8, 0)
    resultName:SetPoint("RIGHT", resultFrame, "RIGHT", -8, 0)
    resultName:SetJustifyH("LEFT")

    local statusFS = OneWoW_GUI:CreateFS(content, 10)
    statusFS:SetPoint("TOPLEFT", idInput, "BOTTOMLEFT", 0, -4)
    statusFS:SetText("")

    validateBtn:SetScript("OnClick", function()
        local idText = idInput:GetText()
        local id = tonumber(idText)
        if not id or id <= 0 then
            statusFS:SetText(L["NOTES_ITEM_INVALID_ID"])
            statusFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
            resultFrame:Hide()
            dialog._validated = false
            return
        end

        if ns.Items and ns.Items:GetItem(id) then
            statusFS:SetText(string.format(L["MSG_ITEM_EXISTS"], id))
            statusFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            resultFrame:Hide()
            dialog._validated = false
            return
        end

        statusFS:SetText(L["ITEM_LOADING"])
        statusFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))

        local itemName, _, itemRarity, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(id)
        if itemName then
            resultIcon:SetTexture(itemTexture)
            local rc = RARITY_COLORS[itemRarity] or RARITY_COLORS[1]
            resultName:SetText(itemName)
            resultName:SetTextColor(rc[1], rc[2], rc[3], 1)
            resultFrame:Show()
            statusFS:SetText("")
            dialog._validated = true
            dialog._validatedID = id
        else
            statusFS:SetText(L["ITEM_LOADING"])
            statusFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            resultFrame:Hide()
            dialog._validated = false

            C_Timer.After(2, function()
                local n2, _, r2, _, _, _, _, _, _, t2 = C_Item.GetItemInfo(id)
                if n2 then
                    resultIcon:SetTexture(t2)
                    local rc2 = RARITY_COLORS[r2] or RARITY_COLORS[1]
                    resultName:SetText(n2)
                    resultName:SetTextColor(rc2[1], rc2[2], rc2[3], 1)
                    resultFrame:Show()
                    statusFS:SetText("")
                    dialog._validated = true
                    dialog._validatedID = id
                else
                    statusFS:SetText(L["NOTES_ITEM_INVALID_ID"])
                    statusFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
                    resultFrame:Hide()
                    dialog._validated = false
                end
            end)
        end
    end)

    yPos = yPos - 110

    MakeItemLabel(content, CATEGORY, COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - 18)
    local catOpts = {}
    if ns.Items then
        for _, c in ipairs(ns.Items:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected("General")
    dialog._catDD = catDD

    MakeItemLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - 18)
    storeDD:SetOptions({
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = CHARACTER, value = "character"},
    })
    storeDD:SetSelected("account")
    dialog._storeDD = storeDD

    dialog:Show()
end

function ns.UI.ShowItemPropertiesDialog(itemID, refreshParent)
    if not itemID or not ns.Items then return end
    local itemData = ns.Items:GetItem(itemID)
    if not itemData then return end

    local COL1_X  = 10
    local COL2_X  = 240
    local COL_W   = 200
    local ROW_H   = 50
    local LBL_GAP = 18

    local dialog = ns.UI.CreateThemedDialog({
        name            = "OneWoW_NotesItemProperties",
        title           = (L["DIALOG_ITEM_PROPERTIES"]) .. ": " .. (itemData.name or ""),
        width           = 450,
        height          = 420,
        destroyOnClose  = true,
        buttons = {
            { text = CLOSE, onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local yPos = -10

    local function SaveField(field, value)
        local d = ns.Items:GetItem(itemID)
        if d then
            d[field] = value
            ns.Items:SaveItem(itemID, d)
        end
        if refreshParent and refreshParent.RefreshItemsList then refreshParent.RefreshItemsList() end
    end

    local itemHeader = ns.UI.CreateThemedBar(nil, content)
    itemHeader:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos)
    itemHeader:SetPoint("TOPRIGHT", content, "TOPRIGHT", -COL1_X, yPos)
    itemHeader:SetHeight(42)
    itemHeader:EnableMouse(true)
    itemHeader:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetItemByID(itemID)
        GameTooltip:Show()
    end)
    itemHeader:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local icon = itemHeader:CreateTexture(nil, "ARTWORK")
    icon:SetSize(34, 34)
    icon:SetPoint("LEFT", itemHeader, "LEFT", 4, 0)
    icon:SetTexture(itemData.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

    local nameFS = OneWoW_GUI:CreateFS(itemHeader, 12)
    nameFS:SetPoint("LEFT", icon, "RIGHT", 8, 6)
    nameFS:SetPoint("RIGHT", itemHeader, "RIGHT", -8, 6)
    nameFS:SetJustifyH("LEFT")
    nameFS:SetText(itemData.name or "Unknown")
    local rc = RARITY_COLORS[itemData.rarity] or RARITY_COLORS[1]
    nameFS:SetTextColor(rc[1], rc[2], rc[3], 1)

    local subFS = OneWoW_GUI:CreateFS(itemHeader, 10)
    subFS:SetPoint("LEFT", icon, "RIGHT", 8, -8)
    local subText = string.format("ID: %s", itemID)
    if itemData.type and itemData.type ~= "" then subText = subText .. "  |  " .. itemData.type end
    if itemData.subType and itemData.subType ~= "" then subText = subText .. " / " .. itemData.subType end
    subFS:SetText(subText)
    subFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    yPos = yPos - 54

    MakeItemLabel(content, CATEGORY, COL1_X, yPos)
    local catDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos - 18)
    local catOpts = {}
    if ns.Items then
        for _, c in ipairs(ns.Items:GetCategories()) do
            catOpts[#catOpts + 1] = {text = c, value = c}
        end
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(itemData.category or "General")
    catDD.onSelect = function(value) SaveField("category", value) end

    MakeItemLabel(content, L["LABEL_STORAGE"], COL2_X, yPos)
    local storeDD = ns.UI.CreateThemedDropdown(content, "", COL_W, 26)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", COL2_X, yPos - 18)
    storeDD:SetOptions({
        {text = L["UI_STORAGE_ACCOUNT"],   value = "account"},
        {text = CHARACTER, value = "character"},
    })
    storeDD:SetSelected(itemData.storage or "account")
    storeDD.onSelect = function(value)
        local d = ns.Items:GetItem(itemID)
        if d then
            local oldDB = ns.Items:GetNotesDB(d.storage or "account")
            if oldDB then oldDB[itemID] = nil end
            d.storage = value
            ns.Items:SaveItem(itemID, d)
        end
        if refreshParent and refreshParent.RefreshItemsList then refreshParent.RefreshItemsList() end
    end
    yPos = yPos - ROW_H - 8

    local alertCB = OneWoW_GUI:CreateCheckbox(content, { label = L["ITEM_ALERT_ON_LOOT"] })
    alertCB:SetPoint("TOPLEFT", content, "TOPLEFT", COL1_X, yPos)
    alertCB:SetChecked(itemData.alertOnLoot or false)
    alertCB:SetScript("OnClick", function(self)
        SaveField("alertOnLoot", self:GetChecked())
    end)
    alertCB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["ITEM_ALERT_ON_LOOT"], 1, 1, 1)
        GameTooltip:AddLine(L["ITEM_ALERT_ON_LOOT_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    alertCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    yPos = yPos - 30

    MakeItemLabel(content, L["LABEL_NOTE_PREVIEW"], COL1_X, yPos)
    yPos = yPos - LBL_GAP

    local noteBg = ns.UI.CreateThemedBar(nil, content)
    noteBg:SetPoint("TOPLEFT",     content, "TOPLEFT",     COL1_X, yPos)
    noteBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -COL1_X, 6)

    local noteScroll, noteEditBox = OneWoW_GUI:CreateScrollEditBox(noteBg, {})
    noteScroll:ClearAllPoints()
    noteScroll:SetPoint("TOPLEFT",     noteBg, "TOPLEFT",     4, -4)
    noteScroll:SetPoint("BOTTOMRIGHT", noteBg, "BOTTOMRIGHT", -26, 4)
    noteEditBox:SetText(itemData.content or "")
    noteEditBox:EnableMouse(false)

    dialog:Show()
end
