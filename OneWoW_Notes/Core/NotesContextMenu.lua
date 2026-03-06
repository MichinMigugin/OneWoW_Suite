-- OneWoW_Notes Addon File
-- OneWoW_Notes/Core/NotesContextMenu.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.NotesContextMenu = {}
local NotesContextMenu = ns.NotesContextMenu

local hyperlinkDialog = nil
local waypointDialog = nil

local function CreateDialogTitleBar(parent, titleText)
    local titleBar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)
    titleBar:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    titleBar:SetBackdropColor(T("TITLEBAR_BG"))
    titleBar:SetBackdropBorderColor(T("TITLEBAR_BORDER"))

    local titleLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleLabel:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    titleLabel:SetText(titleText)
    titleLabel:SetTextColor(T("ACCENT_PRIMARY"))

    local closeBtn = CreateFrame("Button", nil, parent)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    local closeTex = closeBtn:CreateTexture(nil, "ARTWORK")
    closeTex:SetAllPoints()
    closeTex:SetTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    closeBtn:SetScript("OnClick", function()
        parent:Hide()
    end)

    parent:SetMovable(true)
    parent:EnableMouse(true)
    titleBar:EnableMouse(true)
    titleBar:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            parent:StartMoving()
        end
    end)
    titleBar:SetScript("OnMouseUp", function()
        parent:StopMovingOrSizing()
    end)

    return titleBar
end

local function CreateDialogEditBox(parent, width, height, numeric)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(width, height or 26)
    if numeric then eb:SetNumeric(true) end
    eb:SetAutoFocus(false)
    return eb
end

local function GetHyperlinkDialog()
    if hyperlinkDialog then return hyperlinkDialog end

    local dlg = CreateFrame("Frame", "OneWoW_NotesHyperlinkDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(490, 310)
    dlg:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dlg:SetFrameStrata("DIALOG")
    dlg:SetFrameLevel(100)
    dlg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dlg:SetBackdropColor(T("BG_PRIMARY"))
    dlg:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    dlg:Hide()

    CreateDialogTitleBar(dlg, L["CTX_INSERT_HYPERLINK"])

    local typeLbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLbl:SetPoint("TOPLEFT", dlg, "TOPLEFT", 12, -40)
    typeLbl:SetText(L["CTX_LINK_TYPE_LABEL"])
    typeLbl:SetTextColor(T("TEXT_PRIMARY"))

    local typeData = {
        { key = "item",        label = L["CTX_LINK_TYPE_ITEM"],        help = L["CTX_HELP_ITEM"] },
        { key = "spell",       label = L["CTX_LINK_TYPE_SPELL"],       help = L["CTX_HELP_SPELL"] },
        { key = "quest",       label = L["CTX_LINK_TYPE_QUEST"],       help = L["CTX_HELP_QUEST"] },
        { key = "achievement", label = L["CTX_LINK_TYPE_ACHIEVEMENT"], help = L["CTX_HELP_ACHIEVEMENT"] },
        { key = "currency",    label = L["CTX_LINK_TYPE_CURRENCY"],    help = L["CTX_HELP_CURRENCY"] },
        { key = "toy",         label = L["CTX_LINK_TYPE_TOY"],         help = L["CTX_HELP_TOY"] },
        { key = "battlepet",   label = L["CTX_LINK_TYPE_BATTLEPET"],   help = L["CTX_HELP_BATTLEPET"] },
        { key = "mount",       label = L["CTX_LINK_TYPE_MOUNT"],       help = L["CTX_HELP_MOUNT"] },
    }

    dlg.selectedLinkType = "item"
    dlg.typeButtons = {}

    local btnW = 113
    local btnH = 24
    local btnGap = 4

    for i, data in ipairs(typeData) do
        local col = (i - 1) % 4
        local row = math.floor((i - 1) / 4)
        local btn = CreateFrame("Button", nil, dlg, "BackdropTemplate")
        btn:SetSize(btnW, btnH)
        btn:SetPoint("TOPLEFT", dlg, "TOPLEFT", 12 + col * (btnW + btnGap), -58 - row * (btnH + btnGap))
        btn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn.typeKey = data.key
        btn.helpText = data.help

        local btnLabel = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        btnLabel:SetPoint("CENTER")
        btnLabel:SetText(data.label)
        btn.labelText = btnLabel

        btn:SetScript("OnEnter", function(self)
            if dlg.selectedLinkType ~= self.typeKey then
                self:SetBackdropColor(T("BG_HOVER"))
                self:SetBackdropBorderColor(T("BORDER_FOCUS"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if dlg.selectedLinkType ~= self.typeKey then
                self:SetBackdropColor(T("BG_SECONDARY"))
                self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                self.labelText:SetTextColor(T("TEXT_PRIMARY"))
            end
        end)
        btn:SetScript("OnClick", function(self)
            dlg.selectedLinkType = self.typeKey
            for _, tb in ipairs(dlg.typeButtons) do
                if tb.typeKey == dlg.selectedLinkType then
                    tb:SetBackdropColor(T("BG_ACTIVE"))
                    tb:SetBackdropBorderColor(T("BORDER_ACCENT"))
                    tb.labelText:SetTextColor(T("TEXT_ACCENT"))
                else
                    tb:SetBackdropColor(T("BG_SECONDARY"))
                    tb:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                    tb.labelText:SetTextColor(T("TEXT_PRIMARY"))
                end
            end
            if dlg.helpLabel then
                dlg.helpLabel:SetText(self.helpText)
            end
        end)

        table.insert(dlg.typeButtons, btn)
    end

    for _, tb in ipairs(dlg.typeButtons) do
        if tb.typeKey == "item" then
            tb:SetBackdropColor(T("BG_ACTIVE"))
            tb:SetBackdropBorderColor(T("BORDER_ACCENT"))
            tb.labelText:SetTextColor(T("TEXT_ACCENT"))
        else
            tb:SetBackdropColor(T("BG_SECONDARY"))
            tb:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            tb.labelText:SetTextColor(T("TEXT_PRIMARY"))
        end
    end

    local valueLbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    valueLbl:SetPoint("TOPLEFT", dlg, "TOPLEFT", 12, -58 - 2 * (btnH + btnGap) - 14)
    valueLbl:SetText(L["CTX_ID_OR_VALUE"])
    valueLbl:SetTextColor(T("TEXT_PRIMARY"))

    local valueEditBox = CreateDialogEditBox(dlg, 300, 26)
    valueEditBox:SetPoint("TOPLEFT", valueLbl, "BOTTOMLEFT", 0, -6)
    dlg.valueEditBox = valueEditBox

    local helpLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    helpLabel:SetPoint("TOPLEFT", valueEditBox, "BOTTOMLEFT", 0, -8)
    helpLabel:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -12, 0)
    helpLabel:SetJustifyH("LEFT")
    helpLabel:SetWordWrap(true)
    helpLabel:SetText(L["CTX_HELP_ITEM"])
    helpLabel:SetTextColor(T("TEXT_SECONDARY"))
    dlg.helpLabel = helpLabel

    local insertBtn = ns.UI.CreateButton(nil, dlg, L["CTX_BUTTON_INSERT"], 100, 28)
    insertBtn:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 12, 10)
    insertBtn:SetScript("OnClick", function()
        local linkType = dlg.selectedLinkType or "item"
        local linkValue = dlg.valueEditBox:GetText()
        if linkValue and linkValue ~= "" then
            local hyperlinkText = string.format("(%s=%s)", linkType, linkValue)
            if ns.NotesHyperlinks then
                local converted = ns.NotesHyperlinks:ConvertManualLinks(hyperlinkText)
                dlg.targetEditBox:Insert(converted)
            else
                dlg.targetEditBox:Insert(hyperlinkText)
            end
            dlg:Hide()
        end
    end)

    local cancelBtn = ns.UI.CreateButton(nil, dlg, L["CTX_BUTTON_CANCEL"], 100, 28)
    cancelBtn:SetPoint("LEFT", insertBtn, "RIGHT", S("SM"), 0)
    cancelBtn:SetScript("OnClick", function()
        dlg:Hide()
    end)

    hyperlinkDialog = dlg
    return dlg
end

local function GetWaypointDialog()
    if waypointDialog then return waypointDialog end

    local dlg = CreateFrame("Frame", "OneWoW_NotesWaypointDialog", UIParent, "BackdropTemplate")
    dlg:SetSize(380, 360)
    dlg:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    dlg:SetFrameStrata("DIALOG")
    dlg:SetFrameLevel(100)
    dlg:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dlg:SetBackdropColor(T("BG_PRIMARY"))
    dlg:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    dlg:Hide()

    CreateDialogTitleBar(dlg, L["CTX_INSERT_WAYPOINT"])

    local mapLbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mapLbl:SetPoint("TOPLEFT", dlg, "TOPLEFT", 12, -42)
    mapLbl:SetText(L["CTX_MAP_ID"])
    mapLbl:SetTextColor(T("TEXT_PRIMARY"))

    local mapEditBox = CreateDialogEditBox(dlg, 150, 26, true)
    mapEditBox:SetPoint("TOPLEFT", mapLbl, "BOTTOMLEFT", 0, -6)
    dlg.mapEditBox = mapEditBox

    local mapHelp = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mapHelp:SetPoint("TOPLEFT", mapEditBox, "BOTTOMLEFT", 0, -4)
    mapHelp:SetText(L["CTX_MAP_HELP"])
    mapHelp:SetTextColor(T("TEXT_SECONDARY"))

    local xLbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    xLbl:SetPoint("TOPLEFT", mapHelp, "BOTTOMLEFT", 0, -10)
    xLbl:SetText(L["CTX_X_COORDINATE"])
    xLbl:SetTextColor(T("TEXT_PRIMARY"))

    local xEditBox = CreateDialogEditBox(dlg, 150, 26, true)
    xEditBox:SetPoint("TOPLEFT", xLbl, "BOTTOMLEFT", 0, -6)
    dlg.xEditBox = xEditBox

    local yLbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    yLbl:SetPoint("TOPLEFT", xEditBox, "BOTTOMLEFT", 0, -10)
    yLbl:SetText(L["CTX_Y_COORDINATE"])
    yLbl:SetTextColor(T("TEXT_PRIMARY"))

    local yEditBox = CreateDialogEditBox(dlg, 150, 26, true)
    yEditBox:SetPoint("TOPLEFT", yLbl, "BOTTOMLEFT", 0, -6)
    dlg.yEditBox = yEditBox

    local descLbl = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descLbl:SetPoint("TOPLEFT", yEditBox, "BOTTOMLEFT", 0, -10)
    descLbl:SetText(L["CTX_DESCRIPTION"])
    descLbl:SetTextColor(T("TEXT_PRIMARY"))

    local descEditBox = CreateDialogEditBox(dlg, 300, 26)
    descEditBox:SetPoint("TOPLEFT", descLbl, "BOTTOMLEFT", 0, -6)
    dlg.descEditBox = descEditBox

    local insertBtn = ns.UI.CreateButton(nil, dlg, L["CTX_BUTTON_INSERT"], 100, 28)
    insertBtn:SetPoint("BOTTOMLEFT", dlg, "BOTTOMLEFT", 12, 10)
    insertBtn:SetScript("OnClick", function()
        local mapID = dlg.mapEditBox:GetNumber()
        local x = dlg.xEditBox:GetNumber()
        local y = dlg.yEditBox:GetNumber()
        local desc = dlg.descEditBox:GetText()
        if desc == "" then desc = "Waypoint" end

        if x >= 0 and x <= 100 and y >= 0 and y <= 100 then
            if mapID == 0 then
                local currentMapID = C_Map.GetBestMapForUnit("player")
                if not currentMapID then
                    print("|cFFFFD100OneWoW - Notes:|r " .. L["CTX_CANNOT_DETERMINE_ZONE"])
                    return
                end
                mapID = currentMapID
            end
            local waypoint = string.format("(map=%d %.2f %.2f %s)", mapID, x, y, desc)
            if ns.NotesHyperlinks then
                local converted = ns.NotesHyperlinks:ConvertManualLinks(waypoint)
                dlg.targetEditBox:Insert(converted)
            else
                dlg.targetEditBox:Insert(waypoint)
            end
            dlg:Hide()
        else
            print("|cFFFFD100OneWoW - Notes:|r " .. L["CTX_COORDS_OUT_OF_RANGE"])
        end
    end)

    local cancelBtn = ns.UI.CreateButton(nil, dlg, L["CTX_BUTTON_CANCEL"], 100, 28)
    cancelBtn:SetPoint("LEFT", insertBtn, "RIGHT", S("SM"), 0)
    cancelBtn:SetScript("OnClick", function()
        dlg:Hide()
    end)

    waypointDialog = dlg
    return dlg
end

function NotesContextMenu:ShowEditBoxContextMenu(editBox)
    if not UIDropDownMenu_Initialize then return end

    local contextMenu = CreateFrame("Frame", "OneWoW_NotesEditBoxCtxMenu", UIParent, "UIDropDownMenuTemplate")
    UIDropDownMenu_Initialize(contextMenu, function(frame, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text = L["CTX_INSERT_TARGET"]
        info.notCheckable = true
        info.func = function()
            if not UnitExists("target") then
                print("|cFFFFD100OneWoW - Notes:|r " .. L["CTX_NO_TARGET"])
                return
            end
            local targetName = UnitName("target")
            local targetText = targetName
            if UnitIsPlayer("target") then
                local lvl = UnitLevel("target")
                local race = UnitRace("target")
                local class = UnitClass("target")
                if lvl and race and class then
                    targetText = string.format("%s %d %s %s", targetName, lvl, race, class)
                end
            end
            editBox:Insert(targetText)
        end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["CTX_INSERT_DATETIME"]
        info.notCheckable = true
        info.func = function()
            editBox:Insert(date("%Y-%m-%d %H:%M:%S"))
        end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["CTX_INSERT_SELF"]
        info.notCheckable = true
        info.func = function()
            editBox:Insert(UnitName("player"))
        end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["CTX_INSERT_HYPERLINK"]
        info.notCheckable = true
        info.func = function()
            NotesContextMenu:ShowHyperlinkDialog(editBox)
        end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["CTX_INSERT_WAYPOINT"]
        info.notCheckable = true
        info.func = function()
            NotesContextMenu:ShowWaypointDialog(editBox)
        end
        UIDropDownMenu_AddButton(info)

        info = UIDropDownMenu_CreateInfo()
        info.text = L["CTX_ADD_CURRENT_LOCATION"]
        info.notCheckable = true
        info.func = function()
            local mapID = C_Map.GetBestMapForUnit("player")
            if not mapID then
                print("|cFFFFD100OneWoW - Notes:|r " .. L["CTX_CANNOT_DETERMINE_LOCATION"])
                return
            end
            local position = C_Map.GetPlayerMapPosition(mapID, "player")
            if not position then
                print("|cFFFFD100OneWoW - Notes:|r " .. L["CTX_CANNOT_GET_POSITION"])
                return
            end
            local x, y = position:GetXY()
            x = x * 100
            y = y * 100
            local waypoint = string.format("(map=%d %.2f %.2f Location)", mapID, x, y)
            if ns.NotesHyperlinks then
                local converted = ns.NotesHyperlinks:ConvertManualLinks(waypoint)
                editBox:Insert(converted)
            else
                editBox:Insert(waypoint)
            end
            print("|cFFFFD100OneWoW - Notes:|r " .. string.format(L["CTX_LOCATION_INSERTED"], mapID, x, y))
        end
        UIDropDownMenu_AddButton(info)

    end, "MENU")

    ToggleDropDownMenu(1, nil, contextMenu, "cursor", 0, 0)
end

function NotesContextMenu:ShowHyperlinkDialog(editBox)
    local dlg = GetHyperlinkDialog()
    dlg.targetEditBox = editBox
    dlg.selectedLinkType = "item"
    dlg.valueEditBox:SetText("")
    if dlg.helpLabel then
        dlg.helpLabel:SetText(L["CTX_HELP_ITEM"])
    end
    for _, tb in ipairs(dlg.typeButtons) do
        if tb.typeKey == "item" then
            tb:SetBackdropColor(T("BG_ACTIVE"))
            tb:SetBackdropBorderColor(T("BORDER_ACCENT"))
            tb.labelText:SetTextColor(T("TEXT_ACCENT"))
        else
            tb:SetBackdropColor(T("BG_SECONDARY"))
            tb:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            tb.labelText:SetTextColor(T("TEXT_PRIMARY"))
        end
    end
    dlg:Show()
    dlg.valueEditBox:SetFocus()
end

function NotesContextMenu:ShowWaypointDialog(editBox)
    local dlg = GetWaypointDialog()
    dlg.targetEditBox = editBox
    dlg.mapEditBox:SetText("0")
    dlg.xEditBox:SetText("")
    dlg.yEditBox:SetText("")
    dlg.descEditBox:SetText("")
    dlg:Show()
    dlg.mapEditBox:SetFocus()
end
