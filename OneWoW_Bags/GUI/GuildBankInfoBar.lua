local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankInfoBar = {}
local GuildBankInfoBar = OneWoW_Bags.GuildBankInfoBar

local infoBarFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib
local T = OneWoW_Bags.T
local S = OneWoW_Bags.S

local ROW1_H = 28
local ROW2_H = 28

function GuildBankInfoBar:Create(parent)
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

    local viewList = GuildBankInfoBar:CreateViewBtn(infoBarFrame, L["VIEW_LIST"])
    viewList:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", S("SM"), btnY)
    viewList:SetScript("OnClick", function()
        OneWoW_Bags.db.global.guildBankViewMode = "list"
        GuildBankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            OneWoW_Bags.GuildBankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewList = viewList

    local viewCat = GuildBankInfoBar:CreateViewBtn(infoBarFrame, L["VIEW_CATEGORY"])
    viewCat:SetPoint("TOPLEFT", viewList, "TOPRIGHT", 3, 0)
    viewCat:SetScript("OnClick", function()
        OneWoW_Bags.db.global.guildBankViewMode = "category"
        GuildBankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            OneWoW_Bags.GuildBankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewCat = viewCat

    local viewTab = GuildBankInfoBar:CreateViewBtn(infoBarFrame, L["VIEW_BAG"] or "Tab")
    viewTab:SetPoint("TOPLEFT", viewCat, "TOPRIGHT", 3, 0)
    viewTab:SetScript("OnClick", function()
        OneWoW_Bags.db.global.guildBankViewMode = "tab"
        GuildBankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            OneWoW_Bags.GuildBankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewTab = viewTab

    local emptyToggleBtn = CreateFrame("Button", nil, infoBarFrame)
    emptyToggleBtn:SetSize(22, 22)
    emptyToggleBtn:SetPoint("TOPRIGHT", infoBarFrame, "TOPRIGHT", -S("SM"), searchY)
    local emptyIcon = emptyToggleBtn:CreateTexture(nil, "ARTWORK")
    emptyIcon:SetAllPoints()
    emptyIcon:SetTexture("Interface\\COMMON\\FavoritesIcon")
    emptyToggleBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db.global
        db.showEmptySlots = not db.showEmptySlots
        GuildBankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            OneWoW_Bags.GuildBankGUI:RefreshLayout()
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
        name = "OneWoW_GuildBankSearch",
        height = 22,
        placeholderText = L["SEARCH_PLACEHOLDER"],
        onTextChanged = function(text)
            if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.OnSearchChanged then
                OneWoW_Bags.GuildBankGUI:OnSearchChanged(text)
            end
        end,
    })
    searchBox:SetPoint("TOPLEFT", infoBarFrame, "TOPLEFT", S("SM"), searchY)
    searchBox:SetPoint("TOPRIGHT", emptyToggleBtn, "TOPLEFT", -3, 0)
    infoBarFrame.searchBox = searchBox

    GuildBankInfoBar:UpdateViewButtons()

    return infoBarFrame
end

function GuildBankInfoBar:CreateViewBtn(parent, label)
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

function GuildBankInfoBar:UpdateViewButtons()
    if not infoBarFrame then return end
    local mode = OneWoW_Bags.db and OneWoW_Bags.db.global.guildBankViewMode or "list"

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
        infoBarFrame.emptyToggleBtn:SetShown(mode == "list")
    end
end

function GuildBankInfoBar:GetSearchText()
    if infoBarFrame and infoBarFrame.searchBox then
        if infoBarFrame.searchBox.GetSearchText then
            return infoBarFrame.searchBox:GetSearchText()
        end
        return infoBarFrame.searchBox:GetText() or ""
    end
    return ""
end

function GuildBankInfoBar:GetFrame()
    return infoBarFrame
end

function GuildBankInfoBar:Reset()
    if infoBarFrame then
        infoBarFrame:Hide()
        infoBarFrame:SetParent(UIParent)
    end
    infoBarFrame = nil
end
