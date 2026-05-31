local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_Bags.Constants
local L = OneWoW_Bags.L
local WH = OneWoW_Bags.WindowHelpers

local C_Timer = C_Timer

local floor = math.floor
local ipairs = ipairs
local max = math.max
local min = math.min
local strgsub = string.gsub
local strtrim = strtrim
local tinsert = tinsert
local CreateFrame = CreateFrame
local IsMouseButtonDown = IsMouseButtonDown
local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show

OneWoW_Bags.InfoBarFactory = {}

local function SaveSearch(name, query)
    local SS = OneWoW_Bags.SavedSearches
    if not SS then return end

    local ok, err = SS:Set(name, query)
    if not ok and err and L[err] then
        print(L[err])
    end
end

local function ShowSavedSearchOverwrite(name, query)
    StaticPopup_Show("ONEWOW_BAGS_OVERWRITE_SAVED_SEARCH", name, nil, {
        name = name,
        query = query,
    })
end

local function RegisterSavedSearchPopups()
    if StaticPopupDialogs["ONEWOW_BAGS_SAVE_SEARCH"] then return end

    StaticPopupDialogs["ONEWOW_BAGS_SAVE_SEARCH"] = {
        text = L["SAVED_SEARCH_NAME_PROMPT"],
        hasEditBox = true,
        button1 = L["SAVED_SEARCH_SAVE"],
        button2 = L["POPUP_CANCEL"],
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(dialog)
            local SS = OneWoW_Bags.SavedSearches
            local query = dialog.data and dialog.data.query
            if not SS or not query then return end

            local name = dialog.EditBox:GetText()
            local normalized, err = SS:NormalizeName(name)
            if not normalized then
                if err and L[err] then print(L[err]) end
                C_Timer.After(0, function()
                    local reopened = StaticPopup_Show("ONEWOW_BAGS_SAVE_SEARCH", nil, nil, dialog.data)
                    if reopened and reopened.EditBox then
                        reopened.EditBox:SetText(name or "")
                        reopened.EditBox:SetFocus()
                    end
                end)
                return
            end

            local existingKey = SS:FindKey(normalized)
            if existingKey then
                ShowSavedSearchOverwrite(existingKey, query)
                return
            end

            SaveSearch(normalized, query)
        end,
        EditBoxOnEnterPressed = function(editBox)
            local parent = editBox:GetParent()
            StaticPopupDialogs["ONEWOW_BAGS_SAVE_SEARCH"].OnAccept(parent)
            parent:Hide()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
    }

    StaticPopupDialogs["ONEWOW_BAGS_OVERWRITE_SAVED_SEARCH"] = {
        text = L["SAVED_SEARCH_OVERWRITE_CONFIRM"],
        button1 = L["SAVED_SEARCH_OVERWRITE"],
        button2 = L["POPUP_CANCEL"],
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, data)
            if data and data.name and data.query then
                SaveSearch(data.name, data.query)
            end
        end,
    }
end

RegisterSavedSearchPopups()

function OneWoW_Bags.InfoBarFactory:Create(config)
    local bar = {}
    local infoBarFrame = nil
    local searchHistoryMenu = nil

    local ROW1_H = 28
    local ROW2_H = 28

    local function GetShowHeader(db)
        if config.showHeaderFn then return config.showHeaderFn(db) end
        if not config.showHeaderKey then return true end
        return db.global[config.showHeaderKey] ~= false
    end

    local function GetShowSearch(db)
        if config.showSearchFn then return config.showSearchFn(db) end
        if not config.showSearchKey then return true end
        return db.global[config.showSearchKey] ~= false
    end

    local function GetController()
        if config.controller then
            return config.controller
        end
        if config.controllerKey then
            return OneWoW_Bags[config.controllerKey]
        end
        return nil
    end

    local function GetGUI()
        return OneWoW_Bags[config.guiTargetKey]
    end

    local function GetSearchHistoryLimit()
        local db = OneWoW_Bags:GetDB()
        if not db then return 0 end

        return min(max(floor(db.global.searchHistoryLimit or 0), 0), 10)
    end

    local function NormalizeSearchText(searchBox, text)
        text = strtrim(text or "")
        if text == "" or text == searchBox.placeholderText then return nil end
        return text
    end

    local function ApplySingleLineText(fontString)
        fontString:SetWordWrap(false)
        if fontString.SetNonSpaceWrap then
            fontString:SetNonSpaceWrap(false)
        end
        if fontString.SetMaxLines then
            fontString:SetMaxLines(1)
        end
    end

    local function SingleLinePreview(text)
        return strgsub(text or "", "[\r\n]+", " ")
    end

    local function HideSearchHistoryMenu()
        if not searchHistoryMenu then return end
        searchHistoryMenu:SetScript("OnUpdate", nil)
        searchHistoryMenu:Hide()
    end

    local function AddSearchHistory(searchBox, text)
        local limit = GetSearchHistoryLimit()
        if limit <= 0 then return nil end

        text = NormalizeSearchText(searchBox, text)
        if not text then return nil end

        local db = OneWoW_Bags:GetDB()
        local currentHistory = db.global.searchHistory
        local history = { text }
        for _, entry in ipairs(currentHistory) do
            if entry ~= text then
                tinsert(history, entry)
            end
        end

        db.global.searchHistory = history

        while #history > limit do
            history[#history] = nil
        end

        return text
    end

    local function CommitSearchText(searchBox)
        AddSearchHistory(searchBox, searchBox:GetText())
    end

    local function GetRealSearchText(searchBox)
        if not searchBox then return nil end
        local text = searchBox.GetSearchText and searchBox:GetSearchText() or searchBox:GetText()
        return NormalizeSearchText(searchBox, text)
    end

    local function UpdateSaveSearchButton(searchBox)
        if not infoBarFrame or not infoBarFrame.saveSearchBtn then return end

        local canSave = GetRealSearchText(searchBox) ~= nil
        local btn = infoBarFrame.saveSearchBtn
        btn.canSaveSearch = canSave
        btn:SetAlpha(canSave and 1 or 0.35)
        if btn.icon and btn.icon.SetDesaturated then
            btn.icon:SetDesaturated(not canSave)
        end
    end

    local function UpdateSearchTransferButton(searchBox)
        if not infoBarFrame or not infoBarFrame.searchTransferBtn or not config.searchTransfer then return end

        local bankController = OneWoW_Bags.BankController
        local canTransfer = bankController
            and bankController.CanTransferSearch
            and bankController:CanTransferSearch(GetRealSearchText(searchBox), config.searchTransfer.direction)

        local btn = infoBarFrame.searchTransferBtn
        btn.canTransfer = canTransfer
        btn:SetAlpha(canTransfer and 1 or 0.35)
        if btn.icon and btn.icon.SetDesaturated then
            btn.icon:SetDesaturated(not canTransfer)
        end
    end

    local function AnchorSearchRowChrome(searchY, leftInset, rightInset, showSearch)
        if not showSearch then return end

        local helpBtn = infoBarFrame.searchHelpBtn
        local saveBtn = infoBarFrame.saveSearchBtn
        local transferBtn = infoBarFrame.searchTransferBtn
        local searchBox = infoBarFrame.searchBox

        if helpBtn then
            helpBtn:ClearAllPoints()
            helpBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, searchY)
        end

        local rightAnchor = helpBtn
        if saveBtn then
            saveBtn:ClearAllPoints()
            if rightAnchor then
                saveBtn:SetPoint("RIGHT", rightAnchor, "LEFT", -3, 0)
            else
                saveBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, searchY)
            end
            rightAnchor = saveBtn
        end

        if transferBtn then
            transferBtn:ClearAllPoints()
            if rightAnchor then
                transferBtn:SetPoint("RIGHT", rightAnchor, "LEFT", -3, 0)
            else
                transferBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, searchY)
            end
            rightAnchor = transferBtn
        end

        if searchBox then
            searchBox:ClearAllPoints()
            searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", leftInset, searchY)
            if rightAnchor then
                searchBox:SetPoint("TOPRIGHT", rightAnchor, "TOPLEFT", -3, 0)
            else
                searchBox:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, searchY)
            end
        end
    end

    local function ShowSavedSearchNamePopup(searchBox)
        local query = GetRealSearchText(searchBox)
        if not query then return end

        local popup = StaticPopup_Show("ONEWOW_BAGS_SAVE_SEARCH", nil, nil, { query = query })
        if popup and popup.EditBox then
            popup.EditBox:SetText("")
            popup.EditBox:SetFocus()
        end
    end

    local function IsMouseOverSearchHistory(searchBox)
        return (searchHistoryMenu and searchHistoryMenu:IsShown() and searchHistoryMenu:IsMouseOver()) or searchBox:IsMouseOver()
    end

    local function StartHistoryOutsideClickWatcher(searchBox)
        local mouseWasDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
        searchHistoryMenu:SetScript("OnUpdate", function()
            local mouseIsDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
            if mouseIsDown and not mouseWasDown and not IsMouseOverSearchHistory(searchBox) then
                HideSearchHistoryMenu()
            end
            mouseWasDown = mouseIsDown
        end)
    end

    local function ApplySearchHistorySelection(searchBox, text)
        text = AddSearchHistory(searchBox, text)
        if not text then return end

        searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        searchBox:SetText(text)
        HideSearchHistoryMenu()
    end

    local function ShowSearchHistoryMenu(searchBox)
        local limit = GetSearchHistoryLimit()
        if limit <= 0 then
            HideSearchHistoryMenu()
            return
        end

        local db = OneWoW_Bags:GetDB()
        local history = db.global.searchHistory
        if #history == 0 then
            HideSearchHistoryMenu()
            return
        end

        if not searchHistoryMenu then
            searchHistoryMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
            searchHistoryMenu:SetFrameStrata("DIALOG")
            searchHistoryMenu:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            searchHistoryMenu:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            searchHistoryMenu:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            searchHistoryMenu.rows = {}
        end

        HideSearchHistoryMenu()

        local rowHeight = 22
        local width = searchBox:GetWidth()
        local count = min(#history, limit)

        searchHistoryMenu:SetParent(UIParent)
        searchHistoryMenu:ClearAllPoints()
        searchHistoryMenu:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -2)
        searchHistoryMenu:SetSize(width, (count * rowHeight) + 4)

        for i = 1, count do
            local row = searchHistoryMenu.rows[i]
            if not row then
                row = CreateFrame("Button", nil, searchHistoryMenu)
                row:SetHeight(rowHeight)
                row:SetPoint("LEFT", searchHistoryMenu, "LEFT", 2, 0)
                row:SetPoint("RIGHT", searchHistoryMenu, "RIGHT", -2, 0)

                row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                row.text:SetPoint("LEFT", row, "LEFT", 6, 0)
                row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
                row.text:SetJustifyH("LEFT")
                row.text:SetHeight(rowHeight - 4)
                ApplySingleLineText(row.text)

                row:SetScript("OnEnter", function(myself)
                    myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                end)
                row:SetScript("OnLeave", function(myself)
                    myself.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end)
                row:SetScript("OnMouseDown", function(myself)
                    ApplySearchHistorySelection(searchBox, myself.historyText)
                end)

                searchHistoryMenu.rows[i] = row
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", searchHistoryMenu, "TOPLEFT", 2, -2 - ((i - 1) * rowHeight))
            row:SetPoint("TOPRIGHT", searchHistoryMenu, "TOPRIGHT", -2, -2 - ((i - 1) * rowHeight))
            row.historyText = history[i]
            row.text:SetText(SingleLinePreview(history[i]))
            row.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            row:Show()
        end

        for i = count + 1, #searchHistoryMenu.rows do
            searchHistoryMenu.rows[i]:Hide()
        end

        searchHistoryMenu:Show()
        StartHistoryOutsideClickWatcher(searchBox)
    end

    local function GetFactoryChromeInsets()
        local db = OneWoW_Bags:GetDB()
        local hideScroll = false
        if config.hideScrollBarFn then
            hideScroll = config.hideScrollBarFn(db) and true or false
        elseif config.hideScrollBarKey then
            hideScroll = db.global[config.hideScrollBarKey] and true or false
        else
            hideScroll = db.global.hideScrollBar and true or false
        end
        return WH:GetItemGridChromeInsets(hideScroll)
    end

    local function GetExpacEnabled(db)
        if config.expacFilter then
            if config.expacFilter.settingFn then
                return config.expacFilter.settingFn(db) == true
            end
            return db.global[config.expacFilter.settingKey] == true
        end
        return false
    end

    local function effectiveViewMode(raw)
        if raw then
            for _, vm in ipairs(config.viewModes) do
                if vm.mode == raw then
                    return raw
                end
            end
        end
        return config.viewModes[1].mode
    end

    local function viewModeLabel(mode)
        for _, vm in ipairs(config.viewModes) do
            if vm.mode == mode then
                return L[vm.labelKey] or vm.labelKey
            end
        end
        return L[config.viewModes[1].labelKey] or config.viewModes[1].labelKey
    end

    function bar:CreateViewBtn(parent, label)
        local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = label, height = 22, minWidth = 36 })
        btn.isActive = false

        btn._defaultEnter = btn:GetScript("OnEnter")
        btn._defaultLeave = btn:GetScript("OnLeave")

        btn:SetScript("OnEnter", function(myself)
            if not myself.isActive and myself._defaultEnter then myself._defaultEnter(myself) end
        end)
        btn:SetScript("OnLeave", function(myself)
            if not myself.isActive and myself._defaultLeave then myself._defaultLeave(myself) end
        end)

        return btn
    end

    function bar:Create(parent)
        if infoBarFrame then return infoBarFrame end

        infoBarFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        infoBarFrame:SetHeight(Constants.GUI.INFOBAR_HEIGHT)
        infoBarFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
        infoBarFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
        infoBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
        infoBarFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        infoBarFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        infoBarFrame:HookScript("OnHide", HideSearchHistoryMenu)

        local btnY   = -floor((ROW1_H - 22) / 2)
        local searchY = -(ROW1_H + floor((ROW2_H - 22) / 2))

        local leftInset, rightInset = GetFactoryChromeInsets()

        local dropW = config.viewModeDropdownWidth or 170
        local viewModeDropdown, viewModeText = OneWoW_GUI:CreateDropdown(infoBarFrame, {
            width = dropW,
            height = 22,
            text = viewModeLabel(config.viewModes[1].mode),
        })
        viewModeDropdown:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", leftInset, btnY)
        infoBarFrame.viewModeDropdown = viewModeDropdown
        infoBarFrame.viewModeText = viewModeText
        OneWoW_GUI:AttachFilterMenu(viewModeDropdown, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, vm in ipairs(config.viewModes) do
                    tinsert(items, { text = L[vm.labelKey] or vm.labelKey, value = vm.mode })
                end
                return items
            end,
            getActiveValue = function()
                local controller = GetController()
                local raw = controller and controller.GetViewMode and controller:GetViewMode()
                if raw == nil then
                    local d = OneWoW_Bags:GetDB()
                    raw = d and d.global and d.global[config.viewModeDBKey]
                end
                return effectiveViewMode(raw)
            end,
            onSelect = function(value, text)
                local controller = GetController()
                if config.onViewModeChanged then
                    config.onViewModeChanged(value, controller)
                elseif controller and controller.SetViewMode then
                    controller:SetViewMode(value)
                end
                if viewModeText then
                    viewModeText:SetText(text)
                end
                bar:UpdateViewButtons()
            end,
        })

        if config.expacFilter then
            local ef = config.expacFilter
            local expacDropdown, expacText = OneWoW_GUI:CreateDropdown(infoBarFrame, {
                width = 130, height = 22, text = L["EXPAC_FILTER_BTN"],
            })
            expacDropdown:SetPoint("TOPLEFT", viewModeDropdown, "TOPRIGHT", 8, 0)
            OneWoW_GUI:AttachFilterMenu(expacDropdown, {
                searchable = false,
                buildItems = function()
                    local items = { { text = L["EXPAC_FILTER_ALL"], value = "ALL" } }
                    for _, id in ipairs(WH:GetKnownExpansionIDs()) do
                        local expansionName = OneWoW_GUI:GetExpansionName(id)
                        if expansionName then
                            tinsert(items, { text = expansionName, value = id })
                        end
                    end
                    return items
                end,
                getActiveValue = function()
                    local controller = GetController()
                    local v = controller and controller.GetExpansionFilter and controller:GetExpansionFilter() or OneWoW_Bags[ef.filterKey]
                    return (v == nil) and "ALL" or v
                end,
                onSelect = function(value, text)
                    local controller = GetController()
                    if config.onExpansionFilterChanged then
                        config.onExpansionFilterChanged(value, text, controller)
                    elseif controller and controller.SetExpansionFilter then
                        controller:SetExpansionFilter(value)
                    end
                    if value == "ALL" then
                        expacText:SetText(L["EXPAC_FILTER_BTN"])
                    else
                        expacText:SetText(text)
                    end
                end,
            })
            infoBarFrame.expacDropdown = expacDropdown
            infoBarFrame.expacText = expacText
        end

        if config.categoryManagerCallback then
            local categoriesBtn = OneWoW_GUI:CreateAtlasIconButton(infoBarFrame, {
                atlas = "housing-sidetabs-catalog-active",
                width = 20,
                height = 20,
            })
            categoriesBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, btnY)
            categoriesBtn:SetScript("OnClick", function()
                config.categoryManagerCallback(GetController())
            end)
            categoriesBtn:HookScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                GameTooltip:SetText(L["CATEGORY_MANAGER_BTN"], 1, 1, 1)
                GameTooltip:Show()
            end)
            categoriesBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
            infoBarFrame.categoriesBtn = categoriesBtn
        end

        if config.cleanupCallback then
            local cleanupBtn = OneWoW_GUI:CreateAtlasIconButton(infoBarFrame, {
                atlas = "crosshair_ui-cursor-broom_32",
                width = 20,
                height = 20,
            })
            if infoBarFrame.categoriesBtn then
                cleanupBtn:SetPoint("RIGHT", infoBarFrame.categoriesBtn, "LEFT", -4, 0)
            else
                cleanupBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, btnY)
            end
            cleanupBtn:SetScript("OnClick", function()
                config.cleanupCallback(GetController())
            end)
            cleanupBtn:HookScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                GameTooltip:SetText(L["CLEANUP"], 1, 1, 1)
                GameTooltip:Show()
            end)
            cleanupBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
            infoBarFrame.cleanupBtn = cleanupBtn
        end

        local searchBox = OneWoW_GUI:CreateEditBox(infoBarFrame, {
            name = config.searchName,
            height = 22,
            placeholderText = L["SEARCH_PLACEHOLDER"],
            onTextChanged = function(text)
                UpdateSaveSearchButton(infoBarFrame and infoBarFrame.searchBox)
                UpdateSearchTransferButton(infoBarFrame and infoBarFrame.searchBox)
                local controller = GetController()
                if config.onSearchChanged then
                    config.onSearchChanged(text, controller)
                elseif controller and controller.OnSearchChanged then
                    controller:OnSearchChanged(text)
                else
                    local gui = GetGUI()
                    if gui then gui:OnSearchChanged(text) end
                end
            end,
        })

        local saveSearchBtn
        if config.savedSearches then
            saveSearchBtn = OneWoW_GUI:CreateAtlasIconButton(infoBarFrame, {
                atlas = "perks-owned-large",
                width = 20,
                height = 20,
            })
            saveSearchBtn:SetScript("OnClick", function(myself)
                if not myself.canSaveSearch then return end
                ShowSavedSearchNamePopup(searchBox)
            end)
            saveSearchBtn:HookScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                if myself.canSaveSearch then
                    GameTooltip:SetText(L["SAVE_SEARCH_TOOLTIP"], 1, 1, 1)
                else
                    GameTooltip:SetText(L["SAVE_SEARCH_EMPTY_TOOLTIP"], 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            saveSearchBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
            infoBarFrame.saveSearchBtn = saveSearchBtn
        end

        local searchTransferBtn
        local searchTransfer = config.searchTransfer
        if searchTransfer then
            searchTransferBtn = OneWoW_GUI:CreateAtlasIconButton(infoBarFrame, {
                atlas = searchTransfer.atlas,
                width = 20,
                height = 20,
            })
            searchTransferBtn:SetScript("OnClick", function(myself)
                if not myself.canTransfer then return end
                local query = GetRealSearchText(searchBox)
                if not query or not OneWoW_Bags.BankController then return end
                if searchTransfer.direction == "toBank" then
                    OneWoW_Bags.BankController:TransferSearchToBank(query)
                elseif searchTransfer.direction == "fromBank" then
                    OneWoW_Bags.BankController:TransferSearchFromBank(query)
                end
            end)
            searchTransferBtn:HookScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_TOP")
                if myself.canTransfer and searchTransfer.tooltipKey then
                    GameTooltip:SetText(L[searchTransfer.tooltipKey], 1, 1, 1)
                elseif searchTransfer.disabledTooltipKey
                    and searchTransfer.direction == "toBank"
                    and not OneWoW_Bags.bankOpen then
                    GameTooltip:SetText(L[searchTransfer.disabledTooltipKey], 1, 1, 1)
                elseif searchTransfer.emptyTooltipKey then
                    GameTooltip:SetText(L[searchTransfer.emptyTooltipKey], 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            searchTransferBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
            infoBarFrame.searchTransferBtn = searchTransferBtn
        end

        local bagsHelpBtn
        if OneWoW_GUI.CreateKeywordHelpButton then
            bagsHelpBtn = OneWoW_GUI:CreateKeywordHelpButton(infoBarFrame, { editBox = searchBox, size = 20 })
        end

        infoBarFrame.searchHelpBtn = bagsHelpBtn
        AnchorSearchRowChrome(searchY, leftInset, rightInset, true)

        if OneWoW_GUI.AttachSearchTooltip then
            OneWoW_GUI:AttachSearchTooltip(searchBox)
        end
        searchBox:HookScript("OnEditFocusGained", function(myself)
            ShowSearchHistoryMenu(myself)
        end)
        searchBox:HookScript("OnEditFocusLost", function(myself)
            CommitSearchText(myself)
            C_Timer.After(0.05, function()
                if not IsMouseOverSearchHistory(myself) then
                    HideSearchHistoryMenu()
                end
            end)
        end)
        searchBox:HookScript("OnEnterPressed", function(myself)
            CommitSearchText(myself)
            myself:ClearFocus()
        end)
        searchBox:HookScript("OnEscapePressed", function()
            HideSearchHistoryMenu()
        end)
        infoBarFrame.searchBox = searchBox
        UpdateSaveSearchButton(searchBox)
        UpdateSearchTransferButton(searchBox)

        bar:UpdateVisibility()
        return infoBarFrame
    end

    function bar:UpdateViewButtons()
        if not infoBarFrame then return end
        local db = OneWoW_Bags:GetDB()
        local controller = GetController()
        local rawMode = controller and controller.GetViewMode and controller:GetViewMode() or db.global[config.viewModeDBKey] or config.viewModes[1].mode
        local showHeader = GetShowHeader(db)
        local showSearch = GetShowSearch(db)

        if infoBarFrame.viewModeDropdown and infoBarFrame.viewModeText then
            if showHeader then
                infoBarFrame.viewModeDropdown:Show()
                infoBarFrame.viewModeText:SetText(viewModeLabel(effectiveViewMode(rawMode)))
            else
                infoBarFrame.viewModeDropdown:Hide()
            end
        end

        if infoBarFrame.cleanupBtn then
            infoBarFrame.cleanupBtn:SetShown(showHeader)
        end

        if infoBarFrame.categoriesBtn then
            infoBarFrame.categoriesBtn:SetShown(showHeader)
        end

        if infoBarFrame.searchBox then
            if not showSearch then
                HideSearchHistoryMenu()
            end
            infoBarFrame.searchBox:SetShown(showSearch)
            UpdateSaveSearchButton(infoBarFrame.searchBox)
            UpdateSearchTransferButton(infoBarFrame.searchBox)
        end

        if infoBarFrame.saveSearchBtn then
            infoBarFrame.saveSearchBtn:SetShown(showSearch)
        end

        if infoBarFrame.searchTransferBtn then
            infoBarFrame.searchTransferBtn:SetShown(showSearch)
        end

        if infoBarFrame.searchHelpBtn then
            infoBarFrame.searchHelpBtn:SetShown(showSearch)
        end

        if config.expacFilter and infoBarFrame.expacDropdown then
            local ef = config.expacFilter
            local showExpac = showHeader and GetExpacEnabled(db)
            infoBarFrame.expacDropdown:SetShown(showExpac == true)
            if showExpac and infoBarFrame.expacText then
                local activeFilter = controller and controller.GetExpansionFilter and controller:GetExpansionFilter() or OneWoW_Bags[ef.filterKey]
                if activeFilter == nil then
                    infoBarFrame.expacText:SetText(L["EXPAC_FILTER_BTN"])
                else
                    local expName = OneWoW_GUI:GetExpansionName(activeFilter)
                    infoBarFrame.expacText:SetText(expName)
                end
            end
        end

        local newHeight = 0
        if showHeader then newHeight = newHeight + ROW1_H end
        if showSearch then newHeight = newHeight + ROW2_H end

        if newHeight == 0 then
            HideSearchHistoryMenu()
            infoBarFrame:Hide()
        else
            infoBarFrame:SetHeight(newHeight)
            infoBarFrame:Show()
        end
    end

    function bar:UpdateVisibility()
        if not infoBarFrame then return end

        local db = OneWoW_Bags:GetDB()
        local showHeader = GetShowHeader(db)
        local showSearch = GetShowSearch(db)
        local searchY = showHeader and -(ROW1_H + floor((ROW2_H - 22) / 2)) or -floor((ROW2_H - 22) / 2)
        local btnY = -floor((ROW1_H - 22) / 2)
        local leftInset, rightInset = GetFactoryChromeInsets()

        bar:UpdateViewButtons()

        if showHeader and infoBarFrame.viewModeDropdown then
            infoBarFrame.viewModeDropdown:ClearAllPoints()
            infoBarFrame.viewModeDropdown:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", leftInset, btnY)
        end

        if infoBarFrame.categoriesBtn and showHeader then
            infoBarFrame.categoriesBtn:ClearAllPoints()
            infoBarFrame.categoriesBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, btnY)
        end

        if infoBarFrame.cleanupBtn and showHeader then
            infoBarFrame.cleanupBtn:ClearAllPoints()
            if infoBarFrame.categoriesBtn then
                infoBarFrame.cleanupBtn:SetPoint("RIGHT", infoBarFrame.categoriesBtn, "LEFT", -4, 0)
            else
                infoBarFrame.cleanupBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -rightInset, btnY)
            end
        end

        AnchorSearchRowChrome(searchY, leftInset, rightInset, showSearch)
    end

    function bar:GetSearchText()
        if infoBarFrame and infoBarFrame.searchBox then
            if infoBarFrame.searchBox.GetSearchText then
                return infoBarFrame.searchBox:GetSearchText()
            end
            return infoBarFrame.searchBox:GetText() or ""
        end
        return ""
    end

    function bar:ClearSearch()
        if infoBarFrame and infoBarFrame.searchBox then
            HideSearchHistoryMenu()
            infoBarFrame.searchBox:SetText("")
            infoBarFrame.searchBox:ClearFocus()
            if infoBarFrame.searchBox.RestorePlaceholder then
                infoBarFrame.searchBox:RestorePlaceholder()
            elseif infoBarFrame.searchBox.placeholderText and infoBarFrame.searchBox.placeholderText ~= "" then
                infoBarFrame.searchBox:SetText(infoBarFrame.searchBox.placeholderText)
                infoBarFrame.searchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end
        end
    end

    function bar:GetFrame()
        return infoBarFrame
    end

    function bar:Reset()
        if infoBarFrame then
            HideSearchHistoryMenu()
            infoBarFrame:Hide()
            infoBarFrame:SetParent(UIParent)
        end
        infoBarFrame = nil
    end

    return bar
end
