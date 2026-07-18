local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.ShipmentsUI = {}
local ShipmentsUI = ns.ShipmentsUI

local listChild
local detailFrame
local selectedId
local listRows = {} -- pooled list row buttons (WoW never GCs frames)
local dw -- detail widgets, built once per detailFrame (see EnsureDetailWidgets)
local newBtn
local renameBtn
local deleteBtn

local function AttachTooltip(frame, title, body)
    frame:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.85, 0.85, 0.85, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function SetWidgetEnabled(widget, on)
    if not widget then
        return
    end
    if on then
        widget:Enable()
        widget:SetAlpha(1)
    else
        widget:Disable()
        widget:SetAlpha(0.45)
    end
end

local function GetShipment(id)
    for _, s in ipairs(ns.db.global.mail.shipments) do
        if s.id == id then
            return s
        end
    end
end

local function GetShipmentIndex(id)
    for i, s in ipairs(ns.db.global.mail.shipments) do
        if s.id == id then
            return i
        end
    end
end

local function NewShipmentId()
    return "ship_" .. tostring(time()) .. "_" .. tostring(math.random(1000, 9999))
end

local function MakeShipment(name)
    return {
        id = NewShipmentId(),
        name = name,
        mode = "manual",
        match = "",
        target = "",
        keepQty = 0,
        maxQtyEnabled = false,
        maxQty = 0,
        restock = false,
        restockSources = { bags = true, bank = true, guild = false },
        exclusions = {},
    }
end

local function CreateShipment(name)
    name = strtrim(name or "")
    if name == "" then
        return nil, "ERR_SHIPMENT_NAME_EMPTY"
    end
    local shipment = MakeShipment(name)
    tinsert(ns.db.global.mail.shipments, shipment)
    return shipment.id
end

local function RenameShipment(id, name)
    name = strtrim(name or "")
    if name == "" then
        return false, "ERR_SHIPMENT_NAME_EMPTY"
    end
    local shipment = GetShipment(id)
    if not shipment then
        return false, "ERR_SHIPMENT_MISSING"
    end
    shipment.name = name
    return true
end

local function DeleteShipment(id)
    local index = GetShipmentIndex(id)
    if not index then
        return false
    end
    tremove(ns.db.global.mail.shipments, index)
    return true
end

local function SyncCrudButtons()
    local has = selectedId and GetShipment(selectedId) and true or false
    SetWidgetEnabled(renameBtn, has)
    SetWidgetEnabled(deleteBtn, has)
end

-- Bags Category Manager pattern: StaticPopup name prompts + delete confirm.
StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_CREATE"] = {
    text = "",
    hasEditBox = true,
    button1 = L["CREATE"],
    button2 = CANCEL,
    OnShow = function(self)
        self.Text:SetText(L["SHIPMENT_CREATE_ENTER"])
        self.EditBox:SetText("")
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self)
        local name = strtrim(self.EditBox:GetText() or "")
        if name == "" then
            return
        end
        local id, err = CreateShipment(name)
        if not id then
            if err then
                UIErrorsFrame:AddMessage(L[err], 1, 0, 0)
            end
            C_Timer.After(0, function()
                local d = StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_CREATE")
                if d and d.EditBox then
                    d.EditBox:SetText(name)
                    d.EditBox:SetFocus()
                end
            end)
            return
        end
        selectedId = id
        ShipmentsUI:Refresh()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_CREATE"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_RENAME"] = {
    text = "",
    hasEditBox = true,
    button1 = L["RENAME"],
    button2 = CANCEL,
    OnShow = function(self, data)
        self.Text:SetText(L["SHIPMENT_RENAME_ENTER"])
        local shipment = data and GetShipment(data)
        if shipment then
            self.EditBox:SetText(shipment.name or "")
            self.EditBox:HighlightText()
        end
        self.EditBox:SetFocus()
    end,
    OnAccept = function(self, data)
        local name = strtrim(self.EditBox:GetText() or "")
        if name == "" or not data then
            return
        end
        local ok, err = RenameShipment(data, name)
        if not ok then
            if err then
                UIErrorsFrame:AddMessage(L[err], 1, 0, 0)
            end
            C_Timer.After(0, function()
                local d = StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_RENAME", nil, nil, data)
                if d and d.EditBox then
                    d.EditBox:SetText(name)
                    d.EditBox:SetFocus()
                end
            end)
            return
        end
        ShipmentsUI:Refresh()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_RENAME"].OnAccept(parent, parent.data)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["ONEWOW_MAIL_SHIPMENT_DELETE"] = {
    text = "",
    button1 = DELETE,
    button2 = CANCEL,
    OnShow = function(self, data)
        local shipment = data and GetShipment(data)
        self.Text:SetText(string.format(L["SHIPMENT_DELETE_CONFIRM"], shipment and shipment.name or "?"))
    end,
    OnAccept = function(_, data)
        if not data then
            return
        end
        DeleteShipment(data)
        if selectedId == data then
            selectedId = nil
        end
        ShipmentsUI:Refresh()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- List rows are pooled: WoW never garbage-collects frames, so recreating them
-- on every refresh (each selection click) leaks frames and their scripts.
local function AcquireListRow()
    for _, row in ipairs(listRows) do
        if not row:IsShown() then
            row:Show()
            return row
        end
    end
    local row = CreateFrame("Button", nil, listChild, "BackdropTemplate")
    row:SetHeight(28)
    row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row.label = OneWoW_GUI:CreateFS(row, 12)
    row.label:SetPoint("LEFT", row, "LEFT", 8, 0)
    row:SetScript("OnClick", function(myself)
        selectedId = myself.shipmentId
        ShipmentsUI:Refresh()
    end)
    tinsert(listRows, row)
    return row
end

local function RefreshList()
    if not listChild then
        return
    end
    for _, row in ipairs(listRows) do
        row:Hide()
        row:ClearAllPoints()
    end
    local y = 0
    for _, s in ipairs(ns.db.global.mail.shipments) do
        local row = AcquireListRow()
        row.shipmentId = s.id
        row:SetPoint("TOPLEFT", listChild, "TOPLEFT", 0, -y)
        row:SetPoint("TOPRIGHT", listChild, "TOPRIGHT", 0, -y)
        if s.id == selectedId then
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        end
        local mode = s.mode or "manual"
        local mark
        if mode == "auto" then
            mark = "|cff00ff00●|r " -- runs on mailbox open
        elseif mode == "auto_preview" then
            mark = "|cffffd100●|r " -- held for review on mailbox open
        else
            mark = "|cff888888○|r " -- manual only
        end
        row.label:SetText(mark .. (s.name or s.id))
        y = y + 30
    end
    listChild:SetHeight(math.max(1, y))
end

--- Resolve the currently selected shipment at call time. Detail widgets are
--- built once and outlive any particular shipment (reselect/rename/delete),
--- so their handlers must never capture a shipment table.
local function Current()
    return selectedId and GetShipment(selectedId)
end

-- Detail widgets: build-once/bind. WoW never garbage-collects frames, so the
-- old create-on-every-refresh pattern leaked widgets and their scripts on
-- each selection click.
local function EnsureDetailWidgets()
    if dw then
        return
    end
    dw = {}

    dw.empty = OneWoW_GUI:CreateFS(detailFrame, 12)
    dw.empty:SetPoint("TOPLEFT", detailFrame, "TOPLEFT", 8, -8)
    dw.empty:SetText(L["SHIPMENT_SELECT"])
    dw.empty:Hide()

    local content = CreateFrame("Frame", nil, detailFrame)
    content:SetAllPoints(detailFrame)
    dw.content = content

    local SyncActionButtons -- forward: referenced by target commit/typing

    local y = -8
    local function nextY(delta)
        y = y - delta
        return y
    end

    -- Header: name, then auto-run mode (list dot mirrors the mode).
    dw.nameFs = OneWoW_GUI:CreateFS(content, 13)
    dw.nameFs:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.nameFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    nextY(20)

    dw.modeLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.modeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.modeLabel:SetText(L["SHIPMENT_MODE"] .. ":")
    nextY(16)

    -- Tri-state: three checkboxes acting as a radio group.
    dw.modeButtons = {}

    --- Check exactly the button for `mode`.
    function dw.SetModeChecked(mode)
        for key, cb in pairs(dw.modeButtons) do
            cb:SetChecked(key == mode)
        end
    end

    for _, def in ipairs({
        { key = "manual", label = L["MODE_MANUAL"], tt = L["TT_MODE_MANUAL"] },
        { key = "auto_preview", label = L["MODE_AUTO_PREVIEW"], tt = L["TT_MODE_AUTO_PREVIEW"] },
        { key = "auto", label = L["MODE_AUTO"], tt = L["TT_MODE_AUTO"] },
    }) do
        local cb = OneWoW_GUI:CreateCheckbox(content, { label = def.label })
        cb:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
        cb:SetScript("OnClick", function()
            local s = Current()
            if s then
                s.mode = def.key
            end
            dw.SetModeChecked(def.key)
            RefreshList()
        end)
        AttachTooltip(cb, def.label, def.tt)
        dw.modeButtons[def.key] = cb
        nextY(24)
    end
    nextY(6)

    dw.matchLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.matchLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.matchLabel:SetText(L["SHIPMENT_MATCH"] .. ":")
    AttachTooltip(dw.matchLabel, L["SHIPMENT_MATCH"], L["TT_SHIPMENT_MATCH"])
    nextY(16)

    dw.matchBox = OneWoW_GUI:CreateEditBox(content, {
        width = 360,
        height = 24,
        placeholderText = "",
    })
    dw.matchBox:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.matchBox:HookScript("OnEnterPressed", function(myself)
        local s = Current()
        if s then
            s.match = myself:GetSearchText()
        end
        myself:ClearFocus()
    end)
    dw.matchBox:HookScript("OnEditFocusLost", function(myself)
        local s = Current()
        if s then
            s.match = myself:GetSearchText()
        end
    end)
    AttachTooltip(dw.matchBox, L["SHIPMENT_MATCH"], L["TT_SHIPMENT_MATCH"])
    nextY(32)

    dw.targetLabel = OneWoW_GUI:CreateFS(content, 11)
    dw.targetLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.targetLabel:SetText(TARGET .. ":")
    AttachTooltip(dw.targetLabel, TARGET, L["TT_SHIPMENT_TARGET"])
    nextY(16)

    dw.targetBox = OneWoW_GUI:CreateEditBox(content, {
        width = 280,
        height = 24,
        placeholderText = "",
    })
    dw.targetBox:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.targetSuggest = ns.AddressSuggest:Attach(dw.targetBox, {
        onCommit = function(text)
            local s = Current()
            if s then
                s.target = text
            end
            if SyncActionButtons then
                SyncActionButtons()
            end
        end,
    })
    dw.targetBox:HookScript("OnTextChanged", function(_, userInput)
        if userInput and SyncActionButtons then
            SyncActionButtons()
        end
    end)
    AttachTooltip(dw.targetBox, TARGET, L["TT_SHIPMENT_TARGET"])
    nextY(36)

    dw.rulesHeader = OneWoW_GUI:CreateFS(content, 12)
    dw.rulesHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.rulesHeader:SetText(L["SHIPMENT_RULES"])
    dw.rulesHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    nextY(22)

    -- Keep: label + qty on one row.
    dw.keepLabel = OneWoW_GUI:CreateFS(content, 12)
    dw.keepLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - 2)
    dw.keepLabel:SetText(L["SHIPMENT_KEEP"] .. ":")
    AttachTooltip(dw.keepLabel, L["SHIPMENT_KEEP"], L["TT_SHIPMENT_KEEP"])

    dw.keepBox = OneWoW_GUI:CreateEditBox(content, {
        width = 56,
        height = 22,
        placeholderText = "0",
    })
    dw.keepBox:SetPoint("LEFT", dw.keepLabel, "RIGHT", 8, 0)
    dw.keepBox:SetNumeric(true)
    -- Commit on every user keystroke, not just focus loss — clicking Send
    -- does not steal EditBox focus, so an OnEditFocusLost-only commit would
    -- plan the send with a stale quantity.
    dw.keepBox:HookScript("OnEditFocusLost", function(myself)
        local s = Current()
        if s then
            s.keepQty = tonumber(myself:GetSearchText()) or 0
        end
    end)
    dw.keepBox:HookScript("OnTextChanged", function(myself, userInput)
        local s = Current()
        if userInput and s then
            s.keepQty = tonumber(myself:GetSearchText()) or 0
        end
    end)
    AttachTooltip(dw.keepBox, L["SHIPMENT_KEEP"], L["TT_SHIPMENT_KEEP"])
    nextY(30)

    -- Cap: checkbox + qty on one row.
    dw.maxEnable = OneWoW_GUI:CreateCheckbox(content, {
        label = L["SHIPMENT_MAX"] .. ":",
    })
    dw.maxEnable:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    AttachTooltip(dw.maxEnable, L["SHIPMENT_MAX"], L["TT_SHIPMENT_MAX"])

    dw.maxBox = OneWoW_GUI:CreateEditBox(content, {
        width = 56,
        height = 22,
        placeholderText = "0",
    })
    dw.maxBox:SetPoint("LEFT", dw.maxEnable.label, "RIGHT", 8, 0)
    dw.maxBox:SetNumeric(true)
    dw.maxBox:HookScript("OnEditFocusLost", function(myself)
        local s = Current()
        if s then
            s.maxQty = tonumber(myself:GetSearchText()) or 0
        end
    end)
    dw.maxBox:HookScript("OnTextChanged", function(myself, userInput)
        local s = Current()
        if userInput and s then
            s.maxQty = tonumber(myself:GetSearchText()) or 0
        end
    end)
    AttachTooltip(dw.maxBox, L["SHIPMENT_MAX"], L["TT_SHIPMENT_MAX"])
    nextY(30)

    dw.restock = OneWoW_GUI:CreateCheckbox(content, {
        label = L["SHIPMENT_RESTOCK"],
    })
    dw.restock:SetPoint("TOPLEFT", content, "TOPLEFT", 4, y)
    dw.restock:SetScript("OnClick", function(myself)
        local s = Current()
        if s then
            s.restock = myself:GetChecked() and true or false
        end
    end)
    AttachTooltip(dw.restock, L["SHIPMENT_RESTOCK"], L["TT_SHIPMENT_RESTOCK"])
    nextY(36)

    local function CommitDetailFields()
        local s = Current()
        if not s then
            return
        end
        s.target = dw.targetSuggest:GetText()
        s.match = dw.matchBox:GetSearchText()
        s.keepQty = tonumber(dw.keepBox:GetSearchText()) or 0
        s.maxQty = tonumber(dw.maxBox:GetSearchText()) or 0
        s.maxQtyEnabled = dw.maxEnable:GetChecked() and true or false
        s.restock = dw.restock:GetChecked() and true or false
        dw.keepBox:ClearFocus()
        dw.maxBox:ClearFocus()
        dw.matchBox:ClearFocus()
        dw.targetBox:ClearFocus()
    end

    dw.previewBtn = OneWoW_GUI:CreateFitTextButton(content, { text = PREVIEW, height = 26 })
    dw.previewBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.previewBtn:SetScript("OnClick", function()
        local s = Current()
        if not s then
            return
        end
        CommitDetailFields()
        local result = ns.ShipmentEvaluator:Preview(s.id)
        local lines = {}
        for _, plan in ipairs(result.plans) do
            for _, entry in ipairs(plan.entries or {}) do
                local name = C_Item.GetItemNameByID(entry.itemID) or tostring(entry.itemID)
                tinsert(lines, string.format("%s x%d → %s", name, entry.quantity, plan.target or "?"))
            end
        end
        for _, err in ipairs(result.errors) do
            tinsert(lines, "|cffff8800" .. err .. "|r")
        end
        if #lines == 0 then
            tinsert(lines, L["PREVIEW_EMPTY"])
        end
        dw.previewText:SetText(table.concat(lines, "\n"))
    end)

    dw.sendBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["BTN_SEND_SHIPMENT"], height = 26 })
    dw.sendBtn:SetPoint("LEFT", dw.previewBtn, "RIGHT", 6, 0)
    dw.sendBtn:SetScript("OnClick", function()
        local s = Current()
        if not s then
            return
        end
        CommitDetailFields()
        local to = s.target or ""
        if to == "" then
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["ERR_NO_TARGET"])
            return
        end
        local isAlt = ns.AddressBook:IsSuiteAlt(to)
        if not isAlt then
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["WARN_NON_ROSTER"])
        end
        ns.ShipmentEvaluator:Run({ shipmentId = s.id }, function(ok, _, summary)
            -- Failures already print their own reason via RunLog.
            if ok then
                print(L["ADDON_CHAT_PREFIX"] .. " " .. string.format(L["SEND_DONE"], summary.sent))
            end
        end)
    end)
    nextY(40)

    dw.previewText = OneWoW_GUI:CreateFS(content, 11)
    dw.previewText:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y)
    dw.previewText:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 8)
    dw.previewText:SetJustifyH("LEFT")
    dw.previewText:SetJustifyV("TOP")
    dw.previewText:SetText("")

    SyncActionButtons = function()
        local hasTarget = strtrim(dw.targetSuggest:GetText() or "") ~= ""
        SetWidgetEnabled(dw.previewBtn, hasTarget)
        SetWidgetEnabled(dw.sendBtn, hasTarget)
    end
    dw.SyncActionButtons = SyncActionButtons

    local function SyncCapDependent()
        local s = Current()
        local capOn = dw.maxEnable:GetChecked() and true or false
        if s then
            s.maxQtyEnabled = capOn
        end
        if capOn then
            SetWidgetEnabled(dw.maxBox, true)
            SetWidgetEnabled(dw.restock, true)
        else
            SetWidgetEnabled(dw.maxBox, false)
            dw.restock:SetChecked(false)
            if s then
                s.restock = false
            end
            SetWidgetEnabled(dw.restock, false)
        end
    end
    dw.SyncCapDependent = SyncCapDependent

    dw.maxEnable:SetScript("OnClick", SyncCapDependent)
end

--- Bind the selected shipment's values into the (already built) widgets.
local function RefreshDetail()
    if not detailFrame then
        return
    end
    EnsureDetailWidgets()
    local s = Current()
    if not s then
        dw.content:Hide()
        dw.empty:Show()
        return
    end
    dw.empty:Hide()
    dw.content:Show()

    dw.nameFs:SetText(NAME .. ": " .. (s.name or ""))
    dw.SetModeChecked(s.mode or "manual")
    dw.matchBox:SetText(s.match or "")
    dw.matchBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dw.targetSuggest:SetText(s.target or "")
    dw.keepBox:SetText(tostring(s.keepQty or 0))
    dw.keepBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dw.maxEnable:SetChecked(s.maxQtyEnabled and true or false)
    dw.maxBox:SetText(tostring(s.maxQty or 0))
    dw.maxBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dw.restock:SetChecked(s.restock and true or false)
    dw.previewText:SetText("") -- stale preview belongs to the previous binding
    dw.SyncCapDependent()
    dw.SyncActionButtons()
end

function ShipmentsUI:Reset()
    listChild = nil
    detailFrame = nil
    wipe(listRows)
    dw = nil
    newBtn = nil
    renameBtn = nil
    deleteBtn = nil
end

function ShipmentsUI:Create(parent)
    local listWidth = 220
    local actionH = 30
    local listScroll
    listScroll, listChild = OneWoW_GUI:CreateScrollFrame(parent, { width = listWidth })
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    listScroll:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, actionH)
    listScroll:SetWidth(listWidth)

    -- Buttons only — no full-width backdrop (FitText widths vary by locale).
    newBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = NEW, height = 24 })
    newBtn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 2)
    newBtn:SetScript("OnClick", function()
        StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_CREATE")
    end)

    renameBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = L["RENAME"], height = 24 })
    renameBtn:SetPoint("LEFT", newBtn, "RIGHT", 4, 0)
    renameBtn:SetScript("OnClick", function()
        if not selectedId or not GetShipment(selectedId) then
            return
        end
        StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_RENAME", nil, nil, selectedId)
    end)

    deleteBtn = OneWoW_GUI:CreateFitTextButton(parent, { text = DELETE, height = 24 })
    deleteBtn:SetPoint("LEFT", renameBtn, "RIGHT", 4, 0)
    deleteBtn:SetScript("OnClick", function()
        if not selectedId or not GetShipment(selectedId) then
            return
        end
        StaticPopup_Show("ONEWOW_MAIL_SHIPMENT_DELETE", nil, nil, selectedId)
    end)

    detailFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    detailFrame:SetPoint("TOPLEFT", listScroll, "TOPRIGHT", 16, 0)
    detailFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    detailFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    detailFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    detailFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
end

function ShipmentsUI:Refresh()
    if selectedId and not GetShipment(selectedId) then
        selectedId = nil
    end
    if not selectedId and ns.db.global.mail.shipments[1] then
        selectedId = ns.db.global.mail.shipments[1].id
    end
    RefreshList()
    RefreshDetail()
    SyncCrudButtons()
end
