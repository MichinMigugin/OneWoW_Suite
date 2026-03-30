local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankInfoBar = {}
local BankInfoBar = OneWoW_Bags.BankInfoBar

local infoBarFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib
local T = OneWoW_Bags.T
local S = OneWoW_Bags.S

local ROW1_H = 28
local ROW2_H = 28

function BankInfoBar:Create(parent)
    if infoBarFrame then return infoBarFrame end

    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local C = Constants.GUI

    infoBarFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    infoBarFrame:SetHeight(C.INFOBAR_HEIGHT)
    infoBarFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    infoBarFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    infoBarFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    infoBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    infoBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local btnY   = -math.floor((ROW1_H - 22) / 2)
    local searchY = -(ROW1_H + math.floor((ROW2_H - 22) / 2))

    local viewList = BankInfoBar:CreateViewBtn(infoBarFrame, L["VIEW_LIST"])
    viewList:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", S("SM"), btnY)
    viewList:SetScript("OnClick", function()
        OneWoW_Bags.db.global.bankViewMode = "list"
        BankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewList = viewList

    local viewCat = BankInfoBar:CreateViewBtn(infoBarFrame, L["VIEW_CATEGORY"])
    viewCat:SetPoint("TOPLEFT", viewList, "TOPRIGHT", 3, 0)
    viewCat:SetScript("OnClick", function()
        OneWoW_Bags.db.global.bankViewMode = "category"
        BankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewCat = viewCat

    local viewTab = BankInfoBar:CreateViewBtn(infoBarFrame, L["VIEW_BAG"] or "Tab")
    viewTab:SetPoint("TOPLEFT", viewCat, "TOPRIGHT", 3, 0)
    viewTab:SetScript("OnClick", function()
        OneWoW_Bags.db.global.bankViewMode = "tab"
        BankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewTab = viewTab

    local expacDropdown, expacText = OneWoW_GUI:CreateDropdown(infoBarFrame, {
        width = 130, height = 22, text = L["EXPAC_FILTER_BTN"],
    })
    expacDropdown:SetPoint("TOPLEFT", viewTab, "TOPRIGHT", 8, 0)
    OneWoW_GUI:AttachFilterMenu(expacDropdown, {
        searchable = false,
        buildItems = function()
            local SE = OneWoW_Bags.SearchEngine
            local BankSet = OneWoW_Bags.BankSet
            local items = { { text = L["EXPAC_FILTER_ALL"], value = "ALL" } }
            if not BankSet or not BankSet.isBuilt then return items end
            local found = {}
            for _, btn in ipairs(BankSet:GetAllButtons()) do
                if btn.owb_hasItem and btn.owb_itemInfo and btn.owb_itemInfo.itemID then
                    local enriched = SE:EnrichItemInfo(btn.owb_itemInfo.itemID, btn.owb_bagID, btn.owb_slotID, btn.owb_itemInfo)
                    if enriched._expansionID ~= nil then
                        found[enriched._expansionID] = true
                    end
                end
            end
            local ids = {}
            for id in pairs(found) do table.insert(ids, id) end
            table.sort(ids)
            for _, id in ipairs(ids) do
                table.insert(items, { text = SE:GetExpansionName(id) or ("Expansion " .. id), value = id })
            end
            return items
        end,
        getActiveValue = function()
            local v = OneWoW_Bags.activeBankExpansionFilter
            return (v == nil) and "ALL" or v
        end,
        onSelect = function(value, text)
            if value == "ALL" then
                OneWoW_Bags.activeBankExpansionFilter = nil
                expacText:SetText(OneWoW_Bags.L["EXPAC_FILTER_BTN"])
            else
                OneWoW_Bags.activeBankExpansionFilter = value
                expacText:SetText(text)
            end
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
                OneWoW_Bags.BankGUI:RefreshLayout()
            end
        end,
    })
    infoBarFrame.expacDropdown = expacDropdown
    infoBarFrame.expacText = expacText

    local cleanupBtn = BankInfoBar:CreateViewBtn(infoBarFrame, L["CLEANUP"] or "Cleanup")
    cleanupBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -S("SM"), btnY)
    cleanupBtn:SetScript("OnClick", function()
        if not OneWoW_Bags.bankOpen then return end
        local db = OneWoW_Bags.db
        local showWarband = db and db.global and db.global.bankShowWarband
        if showWarband then
            C_Container.SortBank(Enum.BankType.Account)
        else
            C_Container.SortBank(Enum.BankType.Character)
        end
    end)
    infoBarFrame.cleanupBtn = cleanupBtn

    local emptyToggleBtn = CreateFrame("Button", nil, infoBarFrame)
    emptyToggleBtn:SetSize(22, 22)
    emptyToggleBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -S("SM"), searchY)
    local emptyIcon = emptyToggleBtn:CreateTexture(nil, "ARTWORK")
    emptyIcon:SetAllPoints()
    emptyIcon:SetTexture("Interface\\COMMON\\FavoritesIcon")
    emptyToggleBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db.global
        db.showEmptySlots = not db.showEmptySlots
        BankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)
    emptyToggleBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        local showing = OneWoW_Bags.db.global.showEmptySlots
        if showing == nil then showing = true end
        if showing then
            GameTooltip:SetText(L["EMPTY_SLOTS_HIDE"], 1, 1, 1)
        else
            GameTooltip:SetText(L["EMPTY_SLOTS_SHOW"], 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    emptyToggleBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    infoBarFrame.emptyToggleBtn = emptyToggleBtn

    local searchBox = OneWoW_GUI:CreateEditBox(infoBarFrame, {
        name = "OneWoW_BankSearch",
        height = 22,
        placeholderText = L["SEARCH_PLACEHOLDER"],
        onTextChanged = function(text)
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.OnSearchChanged then
                OneWoW_Bags.BankGUI:OnSearchChanged(text)
            end
        end,
    })
    searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", S("SM"), searchY)
    searchBox:SetPoint("TOPRIGHT", emptyToggleBtn, "TOPLEFT", -3, 0)
    infoBarFrame.searchBox = searchBox

    BankInfoBar:UpdateViewButtons()

    return infoBarFrame
end

function BankInfoBar:CreateViewBtn(parent, label)
    local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = label, height = 22, minWidth = 36 })
    btn.isActive = false

    btn._defaultEnter = btn:GetScript("OnEnter")
    btn._defaultLeave = btn:GetScript("OnLeave")

    btn:SetScript("OnEnter", function(self)
        if not self.isActive and self._defaultEnter then
            self._defaultEnter(self)
        end
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.isActive and self._defaultLeave then
            self._defaultLeave(self)
        end
    end)

    return btn
end

function BankInfoBar:UpdateViewButtons()
    if not infoBarFrame then return end
    local mode = OneWoW_Bags.db and OneWoW_Bags.db.global.bankViewMode or "list"

    local buttons = {
        { btn = infoBarFrame.viewList, mode = "list" },
        { btn = infoBarFrame.viewCat,  mode = "category" },
        { btn = infoBarFrame.viewTab,  mode = "tab" },
    }

    for _, entry in ipairs(buttons) do
        local btn = entry.btn
        if btn then
            if entry.mode == mode then
                btn.isActive = true
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                btn.text:SetTextColor(T("TEXT_ACCENT"))
            else
                btn.isActive = false
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                btn.text:SetTextColor(T("TEXT_PRIMARY"))
            end
        end
    end

    if infoBarFrame.emptyToggleBtn then
        local showing = OneWoW_Bags.db and OneWoW_Bags.db.global.showEmptySlots
        if showing == nil then showing = true end
        infoBarFrame.emptyToggleBtn:SetAlpha(showing and 1.0 or 0.35)
        infoBarFrame.emptyToggleBtn:SetShown(mode == "list" or mode == "tab")
    end

    if infoBarFrame.expacDropdown then
        local db = OneWoW_Bags.db
        local showExpac = db and db.global.enableBankExpansionFilter == true
        infoBarFrame.expacDropdown:SetShown(showExpac == true)
        if not showExpac then
            OneWoW_Bags.activeBankExpansionFilter = nil
        elseif infoBarFrame.expacText then
            local activeFilter = OneWoW_Bags.activeBankExpansionFilter
            if activeFilter == nil then
                infoBarFrame.expacText:SetText(OneWoW_Bags.L["EXPAC_FILTER_BTN"])
            else
                local SE = OneWoW_Bags.SearchEngine
                local expName = SE and SE:GetExpansionName(activeFilter) or tostring(activeFilter)
                infoBarFrame.expacText:SetText(expName)
            end
        end
    end
end

function BankInfoBar:GetSearchText()
    if infoBarFrame and infoBarFrame.searchBox then
        if infoBarFrame.searchBox.GetSearchText then
            return infoBarFrame.searchBox:GetSearchText()
        end
        return infoBarFrame.searchBox:GetText() or ""
    end
    return ""
end

function BankInfoBar:ClearSearch()
    if infoBarFrame and infoBarFrame.searchBox then
        infoBarFrame.searchBox:SetText("")
        infoBarFrame.searchBox:ClearFocus()
        if infoBarFrame.searchBox.RestorePlaceholder then
            infoBarFrame.searchBox:RestorePlaceholder()
        elseif infoBarFrame.searchBox.placeholderText and infoBarFrame.searchBox.placeholderText ~= "" then
            infoBarFrame.searchBox:SetText(infoBarFrame.searchBox.placeholderText)
            infoBarFrame.searchBox:SetTextColor(OneWoW_Bags.GUILib:GetThemeColor("TEXT_MUTED"))
        end
    end
end

function BankInfoBar:GetFrame()
    return infoBarFrame
end

function BankInfoBar:Reset()
    if infoBarFrame then
        infoBarFrame:Hide()
        infoBarFrame:SetParent(UIParent)
    end
    infoBarFrame = nil
end
