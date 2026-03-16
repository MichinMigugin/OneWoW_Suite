local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.BankInfoBar = {}
local BankInfoBar = OneWoW_Bags.BankInfoBar

local infoBarFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    if OneWoW_GUI then
        return OneWoW_GUI:GetThemeColor(key)
    end
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.THEME and OneWoW_Bags.Constants.THEME[key] then
        return unpack(OneWoW_Bags.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW_GUI then
        return OneWoW_GUI:GetSpacing(key)
    end
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.SPACING then
        return OneWoW_Bags.Constants.SPACING[key] or 8
    end
    return 8
end

function BankInfoBar:Create(parent)
    if infoBarFrame then return infoBarFrame end

    local Constants = OneWoW_Bags.Constants
    local L = OneWoW_Bags.L
    local C = Constants.GUI
    local BACKDROP = OneWoW_GUI and OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS or {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    }

    infoBarFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    infoBarFrame:SetHeight(C.INFOBAR_HEIGHT)
    infoBarFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    infoBarFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    infoBarFrame:SetBackdrop(BACKDROP)
    infoBarFrame:SetBackdropColor(T("BG_TERTIARY"))
    infoBarFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local searchBox
    if OneWoW_GUI then
        searchBox = OneWoW_GUI:CreateEditBox(infoBarFrame, {
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
    else
        searchBox = CreateFrame("EditBox", "OneWoW_BankSearch", infoBarFrame, "BackdropTemplate")
        searchBox:SetSize(160, 22)
        searchBox:SetBackdrop(BACKDROP)
        searchBox:SetBackdropColor(T("BG_TERTIARY"))
        searchBox:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        searchBox:SetFontObject(GameFontHighlight)
        searchBox:SetTextInsets(S("SM") + 2, S("SM"), 0, 0)
        searchBox:SetAutoFocus(false)
        searchBox:EnableMouse(true)
        searchBox:SetTextColor(T("TEXT_PRIMARY"))
        searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        searchBox:SetScript("OnTextChanged", function(self)
            local text = self:GetText()
            if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.OnSearchChanged then
                OneWoW_Bags.BankGUI:OnSearchChanged(text)
            end
        end)
        function searchBox:GetSearchText()
            return self:GetText() or ""
        end
    end
    searchBox:SetPoint("LEFT", infoBarFrame, "LEFT", S("SM"), 0)
    infoBarFrame.searchBox = searchBox

    local viewList = BankInfoBar:CreateViewBtn(infoBarFrame, L["BANK_VIEW_LIST"])
    viewList:SetPoint("RIGHT", infoBarFrame, "RIGHT", -S("SM"), 0)
    viewList:SetScript("OnClick", function()
        OneWoW_Bags.db.global.bankViewMode = "list"
        BankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewList = viewList

    local viewTabs = BankInfoBar:CreateViewBtn(infoBarFrame, L["BANK_VIEW_TABS"])
    viewTabs:SetPoint("RIGHT", viewList, "LEFT", -3, 0)
    viewTabs:SetScript("OnClick", function()
        OneWoW_Bags.db.global.bankViewMode = "tabs"
        BankInfoBar:UpdateViewButtons()
        if OneWoW_Bags.BankGUI and OneWoW_Bags.BankGUI.RefreshLayout then
            OneWoW_Bags.BankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewTabs = viewTabs

    BankInfoBar:UpdateViewButtons()

    return infoBarFrame
end

function BankInfoBar:CreateViewBtn(parent, label)
    if OneWoW_GUI then
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

    local BACKDROP = {
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    }

    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(22)
    btn:SetBackdrop(BACKDROP)
    btn:SetBackdropColor(T("BTN_NORMAL"))
    btn:SetBackdropBorderColor(T("BTN_BORDER"))

    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetText(label)
    btn.text:SetTextColor(T("TEXT_PRIMARY"))

    local textWidth = btn.text:GetStringWidth()
    btn:SetWidth(math.max(textWidth + 16, 36))

    btn.isActive = false

    btn:SetScript("OnEnter", function(self)
        if not self.isActive then
            self:SetBackdropColor(T("BTN_HOVER"))
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if not self.isActive then
            self:SetBackdropColor(T("BTN_NORMAL"))
        end
    end)

    return btn
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
