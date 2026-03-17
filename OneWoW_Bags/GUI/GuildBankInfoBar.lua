local ADDON_NAME, OneWoW_Bags = ...

OneWoW_Bags.GuildBankInfoBar = {}
local GBInfoBar = OneWoW_Bags.GuildBankInfoBar

local infoBarFrame = nil
local OneWoW_GUI = OneWoW_Bags.GUILib

local T = OneWoW_Bags.T
local S = OneWoW_Bags.S
local CreateViewBtn = OneWoW_Bags.CreateViewBtn

function GBInfoBar:Create(parent)
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
        OneWoW_Bags.db.global.guildBankViewMode = "list"
        GBInfoBar:UpdateViewButtons()
        if OneWoW_Bags.GuildBankGUI then
            OneWoW_Bags.GuildBankGUI:SetContentMode("items")
        end
    end)
    infoBarFrame.viewList = viewList

    local viewTabs = CreateViewBtn(infoBarFrame, L["BANK_VIEW_TABS"])
    viewTabs:SetPoint("RIGHT", viewList, "LEFT", -3, 0)
    viewTabs:SetScript("OnClick", function()
        OneWoW_Bags.db.global.guildBankViewMode = "tabs"
        GBInfoBar:UpdateViewButtons()
        if OneWoW_Bags.GuildBankGUI then
            OneWoW_Bags.GuildBankGUI:SetContentMode("items")
        end
    end)
    infoBarFrame.viewTabs = viewTabs

    local searchBox = OneWoW_GUI:CreateEditBox(infoBarFrame, {
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
    searchBox:ClearAllPoints()
    searchBox:SetPoint("LEFT", infoBarFrame, "LEFT", S("SM"), 0)
    searchBox:SetPoint("RIGHT", viewTabs, "LEFT", -S("SM"), 0)
    infoBarFrame.searchBox = searchBox

    GBInfoBar:UpdateViewButtons()
    return infoBarFrame
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
