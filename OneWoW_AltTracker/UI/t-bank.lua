local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S
local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)

ns.UI = ns.UI or {}

function ns.UI.CreateBankTab(parent)
    local contentPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    contentPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    contentPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    contentPanel:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    contentPanel:SetBackdropColor(T("BG_PRIMARY"))
    contentPanel:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local statusBar = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    statusBar:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 0, 0)
    statusBar:SetPoint("TOPRIGHT", contentPanel, "TOPRIGHT", 0, 0)
    statusBar:SetHeight(32)
    statusBar:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    statusBar:SetBackdropColor(T("BG_SECONDARY"))
    statusBar:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local statusText = statusBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    statusText:SetPoint("LEFT", statusBar, "LEFT", 10, 0)
    statusText:SetText(L["CHARACTERS_TRACKED"]:format(0, ""))
    statusText:SetTextColor(T("TEXT_PRIMARY"))
    parent.statusText = statusText

    local headerRow = CreateFrame("Frame", nil, contentPanel, "BackdropTemplate")
    headerRow:SetPoint("TOPLEFT", statusBar, "BOTTOMLEFT", 0, -2)
    headerRow:SetPoint("TOPRIGHT", statusBar, "BOTTOMRIGHT", 0, -2)
    headerRow:SetHeight(28)
    headerRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
    headerRow:SetBackdropColor(T("BG_SECONDARY"))

    local columnDefs = {
        {text = "", width = 30, sortKey = nil},
        {text = "", width = 22, sortKey = nil},
        {text = L["HEADER_NAME"], width = 150, sortKey = "name"},
        {text = L["HEADER_LEVEL"], width = 50, sortKey = "level"},
        {text = L["HEADER_BAGS"], width = 80, sortKey = "bags"},
        {text = L["HEADER_BANK"], width = 80, sortKey = "bank"},
        {text = L["HEADER_WARBAND"], width = 100, sortKey = "warband"},
        {text = L["HEADER_GUILD_BANK"], width = 100, sortKey = "guildbank"},
        {text = L["HEADER_CHARACTER_GOLD"], width = 120, sortKey = "gold"},
        {text = L["HEADER_WARBAND_GOLD"], width = 120, sortKey = "warbandgold"},
        {text = L["HEADER_GUILD_GOLD"], width = 120, sortKey = "guildgold"},
    }

    local columnButtons = {}
    local xOffset = 8

    for i, colDef in ipairs(columnDefs) do
        local btn = CreateFrame("Button", nil, headerRow)
        btn:SetPoint("LEFT", headerRow, "LEFT", xOffset, 0)
        btn:SetSize(colDef.width, 28)

        btn.columnX = xOffset
        btn.columnWidth = colDef.width

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnText:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btnText:SetText(colDef.text)
        btnText:SetTextColor(T("TEXT_SECONDARY"))

        if i == 3 or i == 5 or i == 6 or i == 7 or i == 8 then
            btnText:SetPoint("LEFT", btn, "LEFT", 3, 0)
            btnText:SetJustifyH("LEFT")
        elseif i == 9 or i == 10 or i == 11 then
            btnText:SetPoint("RIGHT", btn, "RIGHT", -3, 0)
            btnText:SetJustifyH("RIGHT")
        else
            btnText:SetJustifyH("CENTER")
        end

        btn.text = btnText
        btn.sortKey = colDef.sortKey

        table.insert(columnButtons, btn)
        xOffset = xOffset + colDef.width
    end

    headerRow.columnButtons = columnButtons
    headerRow:SetScript("OnSizeChanged", function(self, w, h)
        if not self.columnButtons then return end

        for i, btn in ipairs(self.columnButtons) do
            if btn.text then
                local maxWidth = btn.columnWidth - 6
                btn.text:SetWidth(maxWidth)
                btn.text:SetWordWrap(false)
            end
        end
    end)

    parent.headerRow = headerRow

    local scrollFrame = CreateFrame("ScrollFrame", nil, contentPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", headerRow, "BOTTOMLEFT", 0, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -25, 8)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetSize(1, 400)
    scrollFrame:SetScrollChild(scrollContent)

    parent.scrollFrame = scrollFrame
    parent.scrollContent = scrollContent
    parent.contentPanel = contentPanel

    ns.UI.ApplyFontToFrame(parent)

    if ns.UI.RefreshBankTab then
        ns.UI.RefreshBankTab(parent)
    end
end
