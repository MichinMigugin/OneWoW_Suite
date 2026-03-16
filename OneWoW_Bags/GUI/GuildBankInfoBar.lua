local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankInfoBar = {}
local GBInfoBar = OneWoW_Bags.GuildBankInfoBar

local infoBarFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib

local function T(key)
    if OneWoW_GUI then return OneWoW_GUI:GetThemeColor(key) end
    if OneWoW_Bags.Constants and OneWoW_Bags.Constants.THEME and OneWoW_Bags.Constants.THEME[key] then
        return unpack(OneWoW_Bags.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local function S(key)
    if OneWoW_GUI then return OneWoW_GUI:GetSpacing(key) end
    return 8
end

function GBInfoBar:Create(parent)
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
            name = "OneWoW_GuildBankSearch",
            width = 160,
            height = 22,
            placeholderText = L["GUILD_BANK_SEARCH_PLACEHOLDER"],
            onTextChanged = function(text)
                if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.OnSearchChanged then
                    OneWoW_Bags.GuildBankGUI:OnSearchChanged(text)
                end
            end,
        })
    else
        searchBox = CreateFrame("EditBox", "OneWoW_GuildBankSearch", infoBarFrame, "BackdropTemplate")
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
            if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.OnSearchChanged then
                OneWoW_Bags.GuildBankGUI:OnSearchChanged(self:GetText())
            end
        end)
        function searchBox:GetSearchText() return self:GetText() or "" end
    end
    searchBox:SetPoint("LEFT", infoBarFrame, "LEFT", S("SM"), 0)
    infoBarFrame.searchBox = searchBox

    local viewList = GBInfoBar:CreateViewBtn(infoBarFrame, L["BANK_VIEW_LIST"])
    viewList:SetPoint("RIGHT", infoBarFrame, "RIGHT", -S("SM"), 0)
    viewList:SetScript("OnClick", function()
        OneWoW_Bags.db.global.guildBankViewMode = "list"
        GBInfoBar:UpdateViewButtons()
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            OneWoW_Bags.GuildBankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewList = viewList

    local viewTabs = GBInfoBar:CreateViewBtn(infoBarFrame, L["BANK_VIEW_TABS"])
    viewTabs:SetPoint("RIGHT", viewList, "LEFT", -3, 0)
    viewTabs:SetScript("OnClick", function()
        OneWoW_Bags.db.global.guildBankViewMode = "tabs"
        GBInfoBar:UpdateViewButtons()
        if OneWoW_Bags.GuildBankGUI and OneWoW_Bags.GuildBankGUI.RefreshLayout then
            OneWoW_Bags.GuildBankGUI:RefreshLayout()
        end
    end)
    infoBarFrame.viewTabs = viewTabs

    GBInfoBar:UpdateViewButtons()
    return infoBarFrame
end

function GBInfoBar:CreateViewBtn(parent, label)
    if OneWoW_GUI then
        local btn = OneWoW_GUI:CreateFitTextButton(parent, { text = label, height = 22, minWidth = 36 })
        btn.isActive = false
        btn._defaultEnter = btn:GetScript("OnEnter")
        btn._defaultLeave = btn:GetScript("OnLeave")
        btn:SetScript("OnEnter", function(self) if not self.isActive and self._defaultEnter then self._defaultEnter(self) end end)
        btn:SetScript("OnLeave", function(self) if not self.isActive and self._defaultLeave then self._defaultLeave(self) end end)
        return btn
    end

    local BACKDROP = { bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } }
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetHeight(22)
    btn:SetBackdrop(BACKDROP)
    btn:SetBackdropColor(T("BTN_NORMAL"))
    btn:SetBackdropBorderColor(T("BTN_BORDER"))
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    btn.text:SetPoint("CENTER", 0, 0)
    btn.text:SetText(label)
    btn.text:SetTextColor(T("TEXT_PRIMARY"))
    btn:SetWidth(math.max(btn.text:GetStringWidth() + 16, 36))
    btn.isActive = false
    btn:SetScript("OnEnter", function(self) if not self.isActive then self:SetBackdropColor(T("BTN_HOVER")) end end)
    btn:SetScript("OnLeave", function(self) if not self.isActive then self:SetBackdropColor(T("BTN_NORMAL")) end end)
    return btn
end

function GBInfoBar:UpdateViewButtons()
    if not infoBarFrame then return end
    local mode = OneWoW_Bags.db and OneWoW_Bags.db.global.guildBankViewMode or "tabs"
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

function GBInfoBar:GetSearchText()
    if infoBarFrame and infoBarFrame.searchBox then
        if infoBarFrame.searchBox.GetSearchText then return infoBarFrame.searchBox:GetSearchText() end
        return infoBarFrame.searchBox:GetText() or ""
    end
    return ""
end

function GBInfoBar:GetFrame() return infoBarFrame end

function GBInfoBar:Reset()
    if infoBarFrame then infoBarFrame:Hide(); infoBarFrame:SetParent(UIParent) end
    infoBarFrame = nil
end
