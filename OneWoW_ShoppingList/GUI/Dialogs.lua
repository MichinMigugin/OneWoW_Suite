local ADDON_NAME, ns = ...
local L = ns.L

ns.Dialogs = {}
local Dialogs = ns.Dialogs

local function T(key)
    if ns.Constants and ns.Constants.THEME and ns.Constants.THEME[key] then
        return unpack(ns.Constants.THEME[key])
    end
    return 0.5, 0.5, 0.5, 1.0
end

local BACKDROP_INNER = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
}

local activeDialog = nil

local function CloseActive()
    if activeDialog then
        activeDialog:Hide()
        activeDialog = nil
    end
end

local function CreateBaseDialog(parent, width, height)
    if activeDialog then CloseActive() end

    local dlg = CreateFrame("Frame", nil, parent or UIParent, "BackdropTemplate")
    dlg:SetSize(width or 360, height or 200)
    dlg:SetPoint("CENTER", UIParent, "CENTER")
    dlg:SetFrameLevel(300)
    dlg:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile     = true,
        tileEdge = true,
        tileSize = 16,
        edgeSize = 14,
        insets   = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    dlg:SetBackdropColor(T("BG_SECONDARY"))
    dlg:SetBackdropBorderColor(T("BORDER_ACCENT"))
    dlg:EnableMouse(true)
    dlg:SetMovable(true)
    dlg:RegisterForDrag("LeftButton")
    dlg:SetScript("OnDragStart", function(self) self:StartMoving() end)
    dlg:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local closeBtn = CreateFrame("Button", nil, dlg)
    closeBtn:SetSize(18, 18)
    closeBtn:SetPoint("TOPRIGHT", dlg, "TOPRIGHT", -8, -8)
    closeBtn:SetNormalTexture("Interface\\BUTTONS\\UI-StopButton")
    closeBtn:SetScript("OnClick", CloseActive)

    activeDialog = dlg
    return dlg
end

local function CreateLabel(parent, text, fontObj, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", fontObj or "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 16, y or -16)
    fs:SetText(text or "")
    fs:SetTextColor(T("TEXT_PRIMARY"))
    return fs
end

local function CreateInput(parent, width, height, y)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetSize(width or 300, height or 28)
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y or -44)
    box:SetBackdrop(BACKDROP_INNER)
    box:SetBackdropColor(T("BG_TERTIARY"))
    box:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    box:SetFontObject(GameFontHighlight)
    box:SetTextInsets(8, 8, 0, 0)
    box:SetAutoFocus(true)
    box:SetTextColor(T("TEXT_PRIMARY"))
    box:SetScript("OnEscapePressed", CloseActive)
    return box
end

local function CreateBtn(parent, text, w, h, x, y)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w or 100, h or 28)
    btn:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", x or 16, y or 12)
    btn:SetBackdrop(BACKDROP_INNER)
    btn:SetBackdropColor(T("BTN_NORMAL"))
    btn:SetBackdropBorderColor(T("BTN_BORDER"))
    btn.text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.text:SetPoint("CENTER")
    btn.text:SetText(text or "")
    btn.text:SetTextColor(T("TEXT_PRIMARY"))
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BTN_HOVER"))
        self.text:SetTextColor(T("TEXT_ACCENT"))
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BTN_NORMAL"))
        self.text:SetTextColor(T("TEXT_PRIMARY"))
    end)
    return btn
end

function Dialogs:InputDialog(labelText, defaultVal, onConfirm, parent)
    local dlg = CreateBaseDialog(parent, 360, 130)

    CreateLabel(dlg, labelText, "GameFontNormal", 16, -16)

    local input = CreateInput(dlg, 328, 28, -40)
    input:SetText(defaultVal or "")
    input:HighlightText()

    local okBtn = CreateBtn(dlg, L["OWSL_BTN_CREATE"], 100, 28, 16, 12)
    okBtn:SetScript("OnClick", function()
        local val = input:GetText()
        if val and val ~= "" then
            CloseActive()
            if onConfirm then onConfirm(val) end
        end
    end)

    input:SetScript("OnEnterPressed", function()
        okBtn:Click()
    end)

    local cancelBtn = CreateBtn(dlg, L["OWSL_BTN_CANCEL"], 80, 28, 124, 12)
    cancelBtn:SetScript("OnClick", CloseActive)

    dlg:Show()
    return dlg
end

function Dialogs:ConfirmDialog(titleText, bodyText, onConfirm, confirmLabel, parent)
    local dlg = CreateBaseDialog(parent, 360, 140)

    CreateLabel(dlg, titleText, "GameFontNormalLarge", 16, -16)
    local bodyLabel = CreateLabel(dlg, bodyText, "GameFontNormal", 16, -44)
    bodyLabel:SetTextColor(T("TEXT_SECONDARY"))

    local confirmBtn = CreateBtn(dlg, confirmLabel or L["OWSL_BTN_DELETE"], 100, 28, 16, 12)
    confirmBtn.text:SetTextColor(1, 0.3, 0.3)
    confirmBtn:SetScript("OnClick", function()
        CloseActive()
        if onConfirm then onConfirm() end
    end)

    local cancelBtn = CreateBtn(dlg, L["OWSL_BTN_CANCEL"], 80, 28, 124, 12)
    cancelBtn:SetScript("OnClick", CloseActive)

    dlg:Show()
    return dlg
end

function Dialogs:ExportDialog(title, exportText, parent)
    local dlg = CreateBaseDialog(parent, 480, 280)

    CreateLabel(dlg, title, "GameFontNormalLarge", 16, -16)
    CreateLabel(dlg, L["OWSL_DIALOG_EXPORT_INSTRUCTIONS"], "GameFontNormal", 16, -44)

    local scrollArea = CreateFrame("ScrollFrame", nil, dlg, "UIPanelScrollFrameTemplate")
    scrollArea:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -70)
    scrollArea:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -34, 52)

    local editBox = CreateFrame("EditBox", nil, dlg)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:SetWidth(430)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetTextColor(T("TEXT_PRIMARY"))
    editBox:SetText(exportText or "")
    editBox:SetScript("OnEscapePressed", CloseActive)
    scrollArea:SetScrollChild(editBox)

    C_Timer.After(0.05, function()
        editBox:SetFocus()
        editBox:HighlightText()
    end)

    local closeBtn = CreateBtn(dlg, L["OWSL_BTN_CLOSE"], 100, 28, 190, 12)
    closeBtn:SetScript("OnClick", CloseActive)

    dlg:Show()
    return dlg
end

function Dialogs:ImportDialog(onImport, parent)
    local dlg = CreateBaseDialog(parent, 480, 320)

    CreateLabel(dlg, L["OWSL_IMPORT_TITLE"], "GameFontNormalLarge", 16, -16)
    CreateLabel(dlg, L["OWSL_DIALOG_IMPORT_INSTRUCTIONS"], "GameFontNormal", 16, -44)
    local formatLabel = CreateLabel(dlg, L["OWSL_DIALOG_IMPORT_FORMAT"], "GameFontNormalSmall", 16, -66)
    formatLabel:SetTextColor(T("TEXT_MUTED"))

    local scrollArea = CreateFrame("ScrollFrame", nil, dlg, "UIPanelScrollFrameTemplate")
    scrollArea:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -118)
    scrollArea:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -34, 52)

    local editBox = CreateFrame("EditBox", nil, dlg)
    editBox:SetMultiLine(true)
    editBox:SetMaxLetters(0)
    editBox:SetWidth(430)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetTextColor(T("TEXT_PRIMARY"))
    editBox:SetAutoFocus(true)
    editBox:SetScript("OnEscapePressed", CloseActive)
    scrollArea:SetScrollChild(editBox)

    local importBtn = CreateBtn(dlg, L["OWSL_BTN_IMPORT"], 100, 28, 16, 12)
    importBtn:SetScript("OnClick", function()
        local text = editBox:GetText()
        if text and text ~= "" then
            CloseActive()
            if onImport then onImport(text) end
        else
            print("|cFFFFD100OneWoW Shopping List:|r " .. L["OWSL_MSG_PASTE_TEXT"])
        end
    end)

    local cancelBtn = CreateBtn(dlg, L["OWSL_BTN_CANCEL"], 80, 28, 124, 12)
    cancelBtn:SetScript("OnClick", CloseActive)

    dlg:Show()
    return dlg
end

function Dialogs:RecipeSelectDialog(recipes, knownByData, onSelect, parent)
    local dlg = CreateBaseDialog(parent, 480, 360)
    CreateLabel(dlg, L["OWSL_DIALOG_SELECT_RECIPE"], "GameFontNormalLarge", 16, -16)

    local listContainer = CreateFrame("Frame", nil, dlg)
    listContainer:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -50)
    listContainer:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -16, 52)

    local SBW = 10
    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
    scrollFrame:SetPoint("TOPLEFT",     listContainer, "TOPLEFT",     0,    0)
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -SBW, 0)
    scrollFrame:EnableMouseWheel(true)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)
    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollContent:SetWidth(w)
    end)

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local mx  = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(mx, cur - delta * 30)))
    end)

    local yOffset = 0
    for _, recipe in ipairs(recipes) do
        local knownBy = knownByData and knownByData[recipe.recipeID] or {}
        local knownStr = ""
        if #knownBy > 0 then
            knownStr = string.format(L["OWSL_DIALOG_KNOWN_BY"], knownBy[1].characterName)
            if #knownBy > 1 then
                knownStr = string.format(L["OWSL_DIALOG_KNOWN_BY_MULTI"], knownBy[1].characterName, #knownBy - 1)
            end
        else
            knownStr = L["OWSL_DIALOG_UNKNOWN"]
        end

        local btn = CreateFrame("Button", nil, scrollContent, "BackdropTemplate")
        btn:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        btn:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        btn:SetHeight(36)
        btn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        btn:SetBackdropColor(T("BTN_NORMAL"))
        btn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local recipeName = recipe.name or (string.format(L["OWSL_RECIPE_UNKNOWN"], recipe.recipeID))
        local nameText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
        nameText:SetText(recipeName)
        nameText:SetTextColor(T("TEXT_PRIMARY"))

        local knownText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        knownText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 6)
        knownText:SetText(knownStr)
        knownText:SetTextColor(T("TEXT_MUTED"))

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BTN_HOVER"))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(T("BTN_NORMAL"))
        end)

        local capturedRecipe = recipe
        btn:SetScript("OnClick", function()
            CloseActive()
            if onSelect then onSelect(capturedRecipe) end
        end)

        yOffset = yOffset - 40
    end

    scrollContent:SetHeight(math.abs(yOffset) + 4)

    local cancelBtn = CreateBtn(dlg, L["OWSL_BTN_CANCEL"], 80, 28, 16, 12)
    cancelBtn:SetScript("OnClick", CloseActive)

    dlg:Show()
    return dlg
end

function Dialogs:CraftablesDialog(craftableItems, listName, onCraft, parent)
    local dlg = CreateBaseDialog(parent, 480, 400)
    local title = string.format(L["OWSL_CRAFTABLES_TITLE"], listName)
    CreateLabel(dlg, title, "GameFontNormalLarge", 16, -16)

    local countLabel = CreateLabel(dlg,
        string.format(L["OWSL_DIALOG_FOUND_CRAFTABLES"], #craftableItems),
        "GameFontNormal", 16, -44)
    countLabel:SetTextColor(T("TEXT_SECONDARY"))

    local listContainer = CreateFrame("Frame", nil, dlg)
    listContainer:SetPoint("TOPLEFT", dlg, "TOPLEFT", 16, -70)
    listContainer:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -16, 52)

    local SBW = 10
    local scrollFrame = CreateFrame("ScrollFrame", nil, listContainer)
    scrollFrame:SetPoint("TOPLEFT", listContainer, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", listContainer, "BOTTOMRIGHT", -SBW, 0)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local mx  = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(mx, cur - delta * 30)))
    end)

    local scrollContent = CreateFrame("Frame", nil, scrollFrame)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)
    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollContent:SetWidth(w)
    end)

    local yOffset = 0
    for _, itemInfo in ipairs(craftableItems) do
        local row = CreateFrame("Frame", nil, scrollContent, "BackdropTemplate")
        row:SetPoint("TOPLEFT", scrollContent, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        row:SetHeight(36)
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        row:SetBackdropColor(T("BG_TERTIARY"))
        row:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        icon:SetTexture(itemInfo.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", icon, "RIGHT", 6, 4)
        nameText:SetText(itemInfo.name or (string.format(L["OWSL_ITEM_PREFIX"], itemInfo.itemID or 0)))
        nameText:SetTextColor(T("TEXT_PRIMARY"))

        local qtyText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        qtyText:SetPoint("LEFT", icon, "RIGHT", 6, -8)
        qtyText:SetText(string.format(L["OWSL_DIALOG_QTY_NEEDED"], itemInfo.quantity or 1))
        qtyText:SetTextColor(T("TEXT_SECONDARY"))

        local craftBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
        craftBtn:SetSize(60, 24)
        craftBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        craftBtn:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        craftBtn:SetBackdropColor(T("BTN_NORMAL"))
        craftBtn:SetBackdropBorderColor(T("BTN_BORDER"))
        craftBtn.text = craftBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        craftBtn.text:SetPoint("CENTER")
        craftBtn.text:SetText(L["OWSL_BTN_CRAFT"])
        craftBtn.text:SetTextColor(T("TEXT_PRIMARY"))
        craftBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(T("BTN_HOVER")) end)
        craftBtn:SetScript("OnLeave", function(self) self:SetBackdropColor(T("BTN_NORMAL")) end)

        local capturedItem = itemInfo
        craftBtn:SetScript("OnClick", function()
            if onCraft then onCraft(capturedItem) end
        end)

        yOffset = yOffset - 40
    end

    scrollContent:SetHeight(math.abs(yOffset) + 4)

    local closeBtn = CreateBtn(dlg, L["OWSL_BTN_CLOSE"], 100, 28, 16, 12)
    closeBtn:SetScript("OnClick", CloseActive)

    dlg:Show()
    return dlg
end

function Dialogs:Close()
    CloseActive()
end

function Dialogs:IsOpen()
    return activeDialog ~= nil and activeDialog:IsShown()
end
