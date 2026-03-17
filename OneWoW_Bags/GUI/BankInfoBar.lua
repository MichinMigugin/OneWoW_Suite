local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankInfoBar = {}
local BankInfoBar = OneWoW_Bags.BankInfoBar

local infoBarFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function S(key)
    return OneWoW_GUI:GetSpacing(key)
end

local function CreateViewBtn(parent, label)
    local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = label, height = 22, minWidth = 36 })
    btn.isActive = false
    btn._defaultEnter = btn:GetScript("OnEnter")
    btn._defaultLeave = btn:GetScript("OnLeave")
    btn:SetScript("OnEnter", function(self)
        if not self.isActive and self._defaultEnter then self._defaultEnter(self) end
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.isActive and self._defaultLeave then self._defaultLeave(self) end
    end)
    return btn
end

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

    local viewList = CreateViewBtn(infoBarFrame, L["BANK_VIEW_LIST"])
    viewList:SetPoint("RIGHT", infoBarFrame, "RIGHT", -S("SM"), 0)
    viewList:SetScript("OnClick", function()
        OneWoW_Bags.db.global.bankViewMode = "list"
        BankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewList = viewList

    local viewTabs = CreateViewBtn(infoBarFrame, L["BANK_VIEW_TABS"])
    viewTabs:SetPoint("RIGHT", viewList, "LEFT", -3, 0)
    viewTabs:SetScript("OnClick", function()
        OneWoW_Bags.db.global.bankViewMode = "tabs"
        BankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewTabs = viewTabs

    local cleanupBtn = CreateViewBtn(infoBarFrame, L["BANK_SORT_DEFAULT"])
    cleanupBtn:SetPoint("RIGHT", viewTabs, "LEFT", -3, 0)
    cleanupBtn:SetScript("OnClick", function()
        local db = OneWoW_Bags.db
        if db.global.bankShowWarband then
            C_Container.SortAccountBankBags()
        else
            C_Container.SortBankBags()
        end
    end)
    infoBarFrame.cleanupBtn = cleanupBtn

    local searchBox = OneWoW_GUI:CreateEditBox(infoBarFrame, {
        name = "OneWoW_BankSearch",
        width = 160,
        height = 22,
        placeholderText = L["BANK_SEARCH_PLACEHOLDER"],
        onTextChanged = function(text)
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.OnSearchChanged then
                OneWoW_Bags.BankGUI:OnSearchChanged(text)
            end
        end,
    })
    searchBox:ClearAllPoints()
    searchBox:SetPoint("LEFT", infoBarFrame, "LEFT", S("SM"), 0)
    searchBox:SetPoint("RIGHT", cleanupBtn, "LEFT", -S("SM"), 0)
    infoBarFrame.searchBox = searchBox

    BankInfoBar:UpdateViewButtons()

    return infoBarFrame
end

function BankInfoBar:UpdateViewButtons()
    if not infoBarFrame then return end
    local mode = OneWoW_Bags.db and OneWoW_Bags.db.global.bankViewMode or "tabs"

    local buttons = {
        { btn = infoBarFrame.viewTabs, mode = "tabs" },
        { btn = infoBarFrame.viewList, mode = "list" },
    }

    for _, entry in ipairs(buttons) do
        local btn = entry.btn
        if btn then
            if entry.mode == mode then
                btn.isActive = true
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                if btn.text then btn.text:SetTextColor(T("TEXT_ACCENT")) end
            else
                btn.isActive = false
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                if btn.text then btn.text:SetTextColor(T("TEXT_PRIMARY")) end
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
