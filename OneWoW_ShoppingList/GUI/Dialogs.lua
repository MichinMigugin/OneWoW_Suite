local ADDON_NAME, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.Dialogs = {}
local Dialogs = ns.Dialogs

local activeDialogResult = nil

local function CloseActive()
    if activeDialogResult then
        activeDialogResult.frame:Hide()
        activeDialogResult = nil
    end
end

function Dialogs:InputDialog(labelText, defaultVal, onConfirm, parent)
    CloseActive()

    local result = OneWoW_GUI:CreateDialog({
        title     = labelText,
        width     = 380,
        height    = 120,
        showBrand = true,
        strata    = "FULLSCREEN_DIALOG",
        onClose   = function() activeDialogResult = nil end,
        buttons   = {
            { text = L["OWSL_BTN_CREATE"] },
            { text = L["OWSL_BTN_CANCEL"], onClick = function(f)
                f:Hide()
                activeDialogResult = nil
            end },
        },
    })
    activeDialogResult = result

    local input = OneWoW_GUI:CreateEditBox(result.contentFrame, { height = 26 })
    input:SetPoint("TOPLEFT",  result.contentFrame, "TOPLEFT",  16, -14)
    input:SetPoint("TOPRIGHT", result.contentFrame, "TOPRIGHT", -16, -14)
    if defaultVal and defaultVal ~= "" then
        input:SetText(defaultVal)
    end
    C_Timer.After(0, function()
        if input:GetParent() then
            input:SetFocus()
            input:HighlightText()
        end
    end)

    result.buttons[1]:SetScript("OnClick", function()
        local val = input:GetText()
        if val and val ~= "" then
            result.frame:Hide()
            activeDialogResult = nil
            if onConfirm then onConfirm(val) end
        end
    end)

    input:SetScript("OnEnterPressed", function()
        result.buttons[1]:Click()
    end)

    result.frame:Show()
    return result.frame
end

function Dialogs:ConfirmDialog(titleText, bodyText, onConfirm, confirmLabel, parent, opts)
    CloseActive()

    local showDontAsk = opts and opts.showDontAskAgain

    local result = OneWoW_GUI:CreateConfirmDialog({
        addonTitle = L["OWSL_WINDOW_TITLE"],
        title      = titleText,
        message    = bodyText,
        width      = 420,
        checkbox   = showDontAsk and { label = L["OWSL_DIALOG_DONT_ASK_AGAIN"] } or nil,
        buttons    = {
            { text = confirmLabel or L["OWSL_BTN_DELETE"],
              color = { 0.7, 0.15, 0.15 },
              onClick = function(f)
                  local checked = result.checkbox and result.checkbox:GetChecked()
                  f:Hide()
                  activeDialogResult = nil
                  if checked and opts and opts.onDontAskAgain then
                      opts.onDontAskAgain()
                  end
                  if onConfirm then onConfirm() end
              end },
            { text = L["OWSL_BTN_CANCEL"], onClick = function(f)
                  f:Hide()
                  activeDialogResult = nil
              end },
        },
    })

    activeDialogResult = result
    result.frame:Show()
    return result.frame
end

function Dialogs:ExportDialog(title, exportText, parent)
    CloseActive()

    local result = OneWoW_GUI:CreateDialog({
        title     = title,
        width     = 480,
        height    = 280,
        showBrand = true,
        strata    = "FULLSCREEN_DIALOG",
        onClose   = function() activeDialogResult = nil end,
        buttons   = {
            { text = L["OWSL_BTN_CLOSE"], onClick = function(f)
                f:Hide()
                activeDialogResult = nil
            end },
        },
    })
    activeDialogResult = result

    local instrLabel = OneWoW_GUI:CreateFS(result.contentFrame, 12)
    instrLabel:SetPoint("TOPLEFT", result.contentFrame, "TOPLEFT", 16, -10)
    instrLabel:SetText(L["OWSL_DIALOG_EXPORT_INSTRUCTIONS"])
    instrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local editContainer = OneWoW_GUI:CreateFrame(result.contentFrame, {
        bgColor     = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    editContainer:SetPoint("TOPLEFT",     instrLabel,          "BOTTOMLEFT",  0,   -6)
    editContainer:SetPoint("BOTTOMRIGHT", result.contentFrame, "BOTTOMRIGHT", -8,   6)

    local scrollFrame, editBox = OneWoW_GUI:CreateScrollEditBox(editContainer, {
        fontSize = 11,
    })
    editBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    editBox:SetText(exportText or "")
    C_Timer.After(0.05, function()
        if editBox:GetParent() then
            editBox:SetFocus()
            editBox:HighlightText()
        end
    end)

    result.frame:Show()
    return result.frame
end

function Dialogs:ImportDialog(onImport, parent)
    CloseActive()

    local result = OneWoW_GUI:CreateDialog({
        title     = L["OWSL_IMPORT_TITLE"],
        width     = 480,
        height    = 320,
        showBrand = true,
        strata    = "FULLSCREEN_DIALOG",
        onClose   = function() activeDialogResult = nil end,
        buttons   = {
            { text = L["OWSL_BTN_IMPORT"] },
            { text = L["OWSL_BTN_CANCEL"], onClick = function(f)
                f:Hide()
                activeDialogResult = nil
            end },
        },
    })
    activeDialogResult = result

    local instrLabel = OneWoW_GUI:CreateFS(result.contentFrame, 12)
    instrLabel:SetPoint("TOPLEFT", result.contentFrame, "TOPLEFT", 16, -10)
    instrLabel:SetText(L["OWSL_DIALOG_IMPORT_INSTRUCTIONS"])
    instrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local formatLabel = OneWoW_GUI:CreateFS(result.contentFrame, 10)
    formatLabel:SetPoint("TOPLEFT",  instrLabel,          "BOTTOMLEFT", 0, -4)
    formatLabel:SetPoint("TOPRIGHT", result.contentFrame, "TOPRIGHT",  -16, 0)
    formatLabel:SetText(L["OWSL_DIALOG_IMPORT_FORMAT"])
    formatLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    formatLabel:SetJustifyH("LEFT")
    formatLabel:SetWordWrap(true)

    local editContainer = OneWoW_GUI:CreateFrame(result.contentFrame, {
        bgColor     = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    editContainer:SetPoint("TOPLEFT",     formatLabel,         "BOTTOMLEFT",  0,  -6)
    editContainer:SetPoint("BOTTOMRIGHT", result.contentFrame, "BOTTOMRIGHT", -8,  6)

    local scrollFrame, editBox = OneWoW_GUI:CreateScrollEditBox(editContainer, {
        fontSize = 11,
    })
    editBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    editBox:SetAutoFocus(true)

    result.buttons[1]:SetScript("OnClick", function()
        local text = editBox:GetText()
        if text and text ~= "" then
            result.frame:Hide()
            activeDialogResult = nil
            if onImport then onImport(text) end
        else
            print(L["ADDON_CHAT_PREFIX"] .. " " .. L["OWSL_MSG_PASTE_TEXT"])
        end
    end)

    result.frame:Show()
    return result.frame
end

function Dialogs:RecipeSelectDialog(recipes, knownByData, onSelect, parent)
    CloseActive()

    local result = OneWoW_GUI:CreateDialog({
        title     = L["OWSL_DIALOG_SELECT_RECIPE"],
        width     = 480,
        height    = 360,
        showBrand = true,
        strata    = "FULLSCREEN_DIALOG",
        onClose   = function() activeDialogResult = nil end,
        buttons   = {
            { text = L["OWSL_BTN_CANCEL"], onClick = function(f)
                f:Hide()
                activeDialogResult = nil
            end },
        },
    })
    activeDialogResult = result

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(result.contentFrame, {})

    local yOffset = 0
    for _, recipe in ipairs(recipes) do
        local knownBy  = knownByData and knownByData[recipe.recipeID] or {}
        local knownStr
        if #knownBy > 0 then
            if #knownBy > 1 then
                knownStr = string.format(L["OWSL_DIALOG_KNOWN_BY_MULTI"], knownBy[1].characterName, #knownBy - 1)
            else
                knownStr = string.format(L["OWSL_DIALOG_KNOWN_BY"], knownBy[1].characterName)
            end
        else
            knownStr = L["OWSL_DIALOG_UNKNOWN"]
        end

        local btn = OneWoW_GUI:CreateFrame(scrollContent, {
            bgColor     = "BTN_NORMAL",
            borderColor = "BORDER_SUBTLE",
        })
        btn:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, yOffset)
        btn:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        btn:SetHeight(40)
        btn:EnableMouse(true)

        local recipeName = recipe.name or string.format(L["OWSL_RECIPE_UNKNOWN"], recipe.recipeID)

        local nameText = OneWoW_GUI:CreateFS(btn, 12)
        nameText:SetPoint("TOPLEFT", btn, "TOPLEFT", 8, -6)
        nameText:SetText(recipeName)
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local knownText = OneWoW_GUI:CreateFS(btn, 10)
        knownText:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, 6)
        knownText:SetText(knownStr)
        knownText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local capturedRecipe = recipe
        btn:SetScript("OnMouseDown", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_PRESSED"))
        end)
        btn:SetScript("OnMouseUp", function(self, btnName)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
            if btnName == "LeftButton" and self:IsMouseOver() then
                result.frame:Hide()
                activeDialogResult = nil
                if onSelect then onSelect(capturedRecipe) end
            end
        end)
        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
        end)

        yOffset = yOffset - 44
    end

    scrollContent:SetHeight(math.max(math.abs(yOffset) + 4, 1))

    result.frame:Show()
    return result.frame
end

function Dialogs:CraftablesDialog(craftableItems, listName, onCraft, parent)
    CloseActive()

    local result = OneWoW_GUI:CreateDialog({
        title     = string.format(L["OWSL_CRAFTABLES_TITLE"], listName),
        width     = 480,
        height    = 420,
        showBrand = true,
        strata    = "FULLSCREEN_DIALOG",
        onClose   = function() activeDialogResult = nil end,
        buttons   = {
            { text = L["OWSL_BTN_CLOSE"], onClick = function(f)
                f:Hide()
                activeDialogResult = nil
            end },
        },
    })
    activeDialogResult = result

    local countLabel = OneWoW_GUI:CreateFS(result.contentFrame, 12)
    countLabel:SetPoint("TOPLEFT", result.contentFrame, "TOPLEFT", 16, -10)
    countLabel:SetText(string.format(L["OWSL_DIALOG_FOUND_CRAFTABLES"], #craftableItems))
    countLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local listContainer = CreateFrame("Frame", nil, result.contentFrame)
    listContainer:SetPoint("TOPLEFT",     countLabel,          "BOTTOMLEFT",  0, -6)
    listContainer:SetPoint("BOTTOMRIGHT", result.contentFrame, "BOTTOMRIGHT", -4, 4)

    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(listContainer, {})

    local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
    local yOffset = 0

    for _, itemInfo in ipairs(craftableItems) do
        local row = OneWoW_GUI:CreateFrame(scrollContent, {
            bgColor     = "BG_TERTIARY",
            borderColor = "BORDER_SUBTLE",
        })
        row:SetPoint("TOPLEFT",  scrollContent, "TOPLEFT",  0, yOffset)
        row:SetPoint("TOPRIGHT", scrollContent, "TOPRIGHT", 0, yOffset)
        row:SetHeight(38)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", row, "LEFT", 4, 0)
        icon:SetTexture(itemInfo.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

        local nameText = OneWoW_GUI:CreateFS(row, 12)
        nameText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, -2)
        nameText:SetText(itemInfo.name or string.format(L["OWSL_ITEM_PREFIX"], itemInfo.itemID or 0))
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local qtyText = OneWoW_GUI:CreateFS(row, 10)
        qtyText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 6, 2)
        qtyText:SetText(string.format(L["OWSL_DIALOG_QTY_NEEDED"], itemInfo.quantity or 1))
        qtyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local capturedItem = itemInfo
        local craftBtn = OneWoW_GUI:CreateFitTextButton(row, { text = L["OWSL_BTN_CRAFT"], height = 24 })
        craftBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        craftBtn:SetScript("OnClick", function()
            if onCraft then onCraft(capturedItem) end
        end)

        yOffset = yOffset - 42
    end

    scrollContent:SetHeight(math.max(math.abs(yOffset) + 4, 1))

    result.frame:Show()
    return result.frame
end

function Dialogs:Close()
    CloseActive()
end

function Dialogs:IsOpen()
    return activeDialogResult ~= nil and activeDialogResult.frame:IsShown()
end
