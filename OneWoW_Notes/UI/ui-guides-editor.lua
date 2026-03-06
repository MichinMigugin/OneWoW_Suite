local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local OBJECTIVE_TYPES = {
    { value = "manual",         text = L["GUIDES_OBJ_MANUAL"] },
    { value = "level",          text = L["GUIDES_OBJ_LEVEL"] },
    { value = "quest_complete", text = L["GUIDES_OBJ_QUEST_COMPLETE"] },
    { value = "quest_active",   text = L["GUIDES_OBJ_QUEST_ACTIVE"] },
    { value = "item_count",     text = L["GUIDES_OBJ_ITEM_COUNT"] },
    { value = "location",       text = L["GUIDES_OBJ_LOCATION"] },
    { value = "achievement",    text = L["GUIDES_OBJ_ACHIEVEMENT"] },
    { value = "reputation",     text = L["GUIDES_OBJ_REPUTATION"] },
    { value = "spell_known",    text = L["GUIDES_OBJ_SPELL_KNOWN"] },
    { value = "ilvl",           text = L["GUIDES_OBJ_ILVL"] },
    { value = "currency",       text = L["GUIDES_OBJ_CURRENCY"] },
}

local FACTION_OPTIONS = {
    { value = "both",     text = L["GUIDES_FACTION_BOTH"] },
    { value = "horde",    text = L["GUIDES_FACTION_HORDE"] },
    { value = "alliance", text = L["GUIDES_FACTION_ALLIANCE"] },
}

local PARAM_FIELDS = {
    level          = { { key = "level",         label = "GUIDES_PARAM_LEVEL" } },
    quest_complete = { { key = "questID",       label = "GUIDES_PARAM_QUEST_ID" } },
    quest_active   = { { key = "questID",       label = "GUIDES_PARAM_QUEST_ID" } },
    item_count     = { { key = "itemID",        label = "GUIDES_PARAM_ITEM_ID" },
                       { key = "count",         label = "GUIDES_PARAM_COUNT" } },
    location       = { { key = "mapID",         label = "GUIDES_PARAM_MAP_ID" } },
    achievement    = { { key = "achievementID", label = "GUIDES_PARAM_ACHIEVEMENT_ID" } },
    reputation     = { { key = "factionID",     label = "GUIDES_PARAM_FACTION_ID" },
                       { key = "standing",      label = "GUIDES_PARAM_STANDING" } },
    spell_known    = { { key = "spellID",       label = "GUIDES_PARAM_SPELL_ID" } },
    ilvl           = { { key = "ilvl",          label = "GUIDES_PARAM_ILVL" } },
    currency       = { { key = "currencyID",    label = "GUIDES_PARAM_CURRENCY_ID" },
                       { key = "amount",        label = "GUIDES_PARAM_AMOUNT" } },
}

local function MakeEditBox(parent, x, y, w, h, defaultText)
    local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
    box:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    box:SetSize(w, h)
    box:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    box:SetBackdropColor(T("BG_TERTIARY"))
    box:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    box:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    box:SetTextColor(T("TEXT_PRIMARY"))
    box:SetTextInsets(8, 8, 0, 0)
    box:SetAutoFocus(false)
    box:SetText(defaultText or "")
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return box
end

local function MakeLabel(parent, text, x, y)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(T("TEXT_SECONDARY"))
    return lbl
end

function ns.UI.ShowGuideEditorDialog(guideID, onSaveCallback)
    local isEdit = guideID ~= nil
    local guide = isEdit and ns.GuidesData:GetGuide(guideID) or nil

    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_GuideEditor",
        title = isEdit and L["GUIDES_EDIT"] or L["GUIDES_NEW"],
        width = 700,
        height = 600,
        destroyOnClose = true,
        buttons = {
            {
                text = L["NOTES_SAVE"],
                onClick = function(frame)
                    local markupText = frame._markupBox:GetText()
                    if not markupText or markupText == "" then return end

                    local parsed = ns.GuidesData:ParseMarkupGuide(markupText)
                    if not parsed then
                        print("|cFFFFD100OneWoW Notes:|r " .. L["GUIDES_PARSE_FAILED"])
                        return
                    end

                    local cat = frame._catDD:GetValue() or "General"

                    if isEdit then
                        ns.GuidesData:UpdateGuide(guideID, {
                            title = parsed.title ~= "" and parsed.title or (guide and guide.title or ""),
                            description = parsed.description or "",
                            category = cat,
                            steps = parsed.steps,
                        })
                    else
                        guideID = ns.GuidesData:AddGuide({
                            title = parsed.title ~= "" and parsed.title or "Untitled",
                            description = parsed.description or "",
                            category = cat,
                            steps = parsed.steps,
                        })
                    end

                    if onSaveCallback then onSaveCallback(guideID) end
                    frame:Hide()
                    frame:SetParent(nil)
                end,
            },
            {
                text = L["BUTTON_CANCEL"],
                onClick = function(frame)
                    frame:Hide()
                    frame:SetParent(nil)
                end,
            },
        },
    })

    local content = dialog.content
    local yOff = 0

    MakeLabel(content, L["LABEL_CATEGORY"], 10, yOff)
    local catDD = ns.UI.CreateThemedDropdown(content, "", 200, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", 100, yOff + 2)
    local catOpts = {}
    for _, c in ipairs(ns.GuidesData:GetCategories()) do
        table.insert(catOpts, { text = c, value = c })
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(guide and guide.category or "General")
    dialog._catDD = catDD

    yOff = yOff - 34
    local hintLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    hintLabel:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOff)
    hintLabel:SetJustifyH("LEFT")
    hintLabel:SetText(L["GUIDES_MARKUP_HINT"])
    hintLabel:SetTextColor(T("TEXT_MUTED"))
    hintLabel:SetWordWrap(true)

    yOff = yOff - 24
    local markupScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    markupScroll:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    markupScroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -30, 10)

    local markupBox = CreateFrame("EditBox", nil, markupScroll)
    markupBox:SetWidth(markupScroll:GetWidth())
    markupBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    markupBox:SetTextColor(T("TEXT_PRIMARY"))
    markupBox:SetMultiLine(true)
    markupBox:SetAutoFocus(false)
    markupBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    markupScroll:SetScrollChild(markupBox)

    if isEdit and guideID then
        markupBox:SetText(ns.GuidesData:GuideToMarkup(guideID))
    end

    dialog._markupBox = markupBox

    dialog:Show()
    return dialog
end

function ns.UI.ShowStepEditorDialog(guideID, stepIndex, onSaveCallback)
    local guide = ns.GuidesData:GetGuide(guideID)
    if not guide then return end

    local isEdit = stepIndex ~= nil
    local step = isEdit and guide.steps[stepIndex] or nil

    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_StepEditor",
        title = isEdit and L["GUIDES_EDIT_STEP"] or L["GUIDES_ADD_STEP"],
        width = 500,
        height = 320,
        destroyOnClose = true,
        buttons = {
            {
                text = L["NOTES_SAVE"],
                onClick = function(frame)
                    local stepTitle = frame._titleBox:GetText() or ""
                    local stepDesc = frame._descBox:GetText() or ""
                    local faction = frame._factionDD:GetValue() or "both"
                    local optional = frame._optionalCB:GetChecked() or false

                    if isEdit then
                        guide.steps[stepIndex].title = stepTitle
                        guide.steps[stepIndex].description = stepDesc
                        guide.steps[stepIndex].faction = faction
                        guide.steps[stepIndex].optional = optional
                        guide.modified = GetServerTime()
                    else
                        ns.GuidesData:AddStep(guideID, {
                            title = stepTitle,
                            description = stepDesc,
                            faction = faction,
                            optional = optional,
                        })
                    end

                    if onSaveCallback then onSaveCallback() end
                    frame:Hide()
                    frame:SetParent(nil)
                end,
            },
            {
                text = L["BUTTON_CANCEL"],
                onClick = function(frame)
                    frame:Hide()
                    frame:SetParent(nil)
                end,
            },
        },
    })

    local content = dialog.content
    local yOff = 0

    MakeLabel(content, L["GUIDES_STEP_TITLE"], 10, yOff)
    yOff = yOff - 16
    local titleBox = MakeEditBox(content, 10, yOff, 460, 28, step and step.title or "")
    titleBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOff)
    dialog._titleBox = titleBox

    yOff = yOff - 36
    MakeLabel(content, L["GUIDES_STEP_DESC"], 10, yOff)
    yOff = yOff - 16
    local descScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    descScroll:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    descScroll:SetPoint("TOPRIGHT", content, "TOPRIGHT", -30, yOff)
    descScroll:SetHeight(80)

    local descBox = CreateFrame("EditBox", nil, descScroll)
    descBox:SetWidth(descScroll:GetWidth())
    descBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    descBox:SetTextColor(T("TEXT_PRIMARY"))
    descBox:SetMultiLine(true)
    descBox:SetAutoFocus(false)
    descBox:SetText(step and step.description or "")
    descBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    descScroll:SetScrollChild(descBox)
    dialog._descBox = descBox

    yOff = yOff - 100
    MakeLabel(content, L["GUIDES_FACTION"], 10, yOff)
    local factionDD = ns.UI.CreateThemedDropdown(content, "", 150, 26)
    factionDD:SetPoint("TOPLEFT", content, "TOPLEFT", 100, yOff + 2)
    factionDD:SetOptions(FACTION_OPTIONS)
    factionDD:SetSelected(step and step.faction or "both")
    dialog._factionDD = factionDD

    local optionalCB = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    optionalCB:SetPoint("TOPLEFT", content, "TOPLEFT", 280, yOff + 4)
    optionalCB:SetSize(24, 24)
    optionalCB:SetChecked(step and step.optional or false)
    local optLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    optLabel:SetPoint("LEFT", optionalCB, "RIGHT", 4, 0)
    optLabel:SetText(L["GUIDES_OPTIONAL"])
    optLabel:SetTextColor(T("TEXT_SECONDARY"))
    dialog._optionalCB = optionalCB

    dialog:Show()
    return dialog
end

function ns.UI.ShowObjectiveEditorDialog(guideID, stepIndex, objIndex, onSaveCallback)
    local guide = ns.GuidesData:GetGuide(guideID)
    if not guide or not guide.steps[stepIndex] then return end

    local isEdit = objIndex ~= nil
    local obj = isEdit and guide.steps[stepIndex].objectives[objIndex] or nil

    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_ObjEditor",
        title = isEdit and L["GUIDES_EDIT_OBJECTIVE"] or L["GUIDES_ADD_OBJECTIVE"],
        width = 500,
        height = 380,
        destroyOnClose = true,
        buttons = {
            {
                text = L["NOTES_SAVE"],
                onClick = function(frame)
                    local objType = frame._typeDD:GetValue() or "manual"
                    local desc = frame._descBox:GetText() or ""
                    local params = {}

                    local fields = PARAM_FIELDS[objType]
                    if fields and frame._paramBoxes then
                        for i, field in ipairs(fields) do
                            if frame._paramBoxes[i] then
                                params[field.key] = tonumber(frame._paramBoxes[i]:GetText()) or 0
                            end
                        end
                    end

                    if isEdit then
                        guide.steps[stepIndex].objectives[objIndex] = {
                            type = objType,
                            description = desc,
                            params = params,
                        }
                        guide.modified = GetServerTime()
                    else
                        ns.GuidesData:AddObjective(guideID, stepIndex, {
                            type = objType,
                            description = desc,
                            params = params,
                        })
                    end

                    if onSaveCallback then onSaveCallback() end
                    frame:Hide()
                    frame:SetParent(nil)
                end,
            },
            {
                text = L["BUTTON_CANCEL"],
                onClick = function(frame)
                    frame:Hide()
                    frame:SetParent(nil)
                end,
            },
        },
    })

    local content = dialog.content
    local yOff = 0

    MakeLabel(content, L["GUIDES_OBJ_TYPE"], 10, yOff)
    yOff = yOff - 16
    local typeDD = ns.UI.CreateThemedDropdown(content, "", 250, 26)
    typeDD:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    typeDD:SetOptions(OBJECTIVE_TYPES)
    typeDD:SetSelected(obj and obj.type or "manual")
    dialog._typeDD = typeDD

    yOff = yOff - 36
    MakeLabel(content, L["GUIDES_OBJ_DESC"], 10, yOff)
    yOff = yOff - 16
    local descBox = MakeEditBox(content, 10, yOff, 460, 28, obj and obj.description or "")
    descBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOff)
    dialog._descBox = descBox

    yOff = yOff - 40

    local paramContainer = CreateFrame("Frame", nil, content)
    paramContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOff)
    paramContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOff)
    paramContainer:SetHeight(200)

    dialog._paramBoxes = {}

    local function BuildParamFields(objType)
        for _, child in ipairs({paramContainer:GetChildren()}) do
            child:Hide()
            child:ClearAllPoints()
        end
        for _, fs in ipairs({paramContainer:GetRegions()}) do
            if fs.Hide then fs:Hide() end
        end
        wipe(dialog._paramBoxes)

        local fields = PARAM_FIELDS[objType]
        if not fields then return end

        local pY = 0
        local existingParams = (obj and obj.type == objType) and obj.params or {}

        for i, field in ipairs(fields) do
            local lbl = paramContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetPoint("TOPLEFT", paramContainer, "TOPLEFT", 10, pY)
            lbl:SetText(L[field.label] or field.label)
            lbl:SetTextColor(T("TEXT_SECONDARY"))

            pY = pY - 16
            local box = MakeEditBox(paramContainer, 10, pY, 200, 28, tostring(existingParams[field.key] or ""))
            box:SetNumeric(true)
            dialog._paramBoxes[i] = box
            pY = pY - 36
        end
    end

    BuildParamFields(obj and obj.type or "manual")

    typeDD.onSelect = function(value)
        BuildParamFields(value)
    end

    dialog:Show()
    return dialog
end

function ns.UI.ShowGuideImportDialog(onImportCallback)
    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_GuideImport",
        title = L["GUIDES_IMPORT"],
        width = 600,
        height = 500,
        destroyOnClose = true,
        buttons = {
            {
                text = L["GUIDES_IMPORT"],
                onClick = function(frame)
                    local text = frame._importBox:GetText()
                    if not text or text == "" then return end

                    local parsed = ns.GuidesData:ParseMarkupGuide(text)
                    if parsed and parsed.steps and #parsed.steps > 0 then
                        local guideID = ns.GuidesData:AddGuide({
                            title = parsed.title ~= "" and parsed.title or (frame._titleBox and frame._titleBox:GetText() or ""),
                            description = parsed.description or "",
                            category = frame._catDD and frame._catDD:GetValue() or "General",
                            steps = parsed.steps,
                        })
                        if guideID then
                            print("|cFFFFD100OneWoW Notes:|r " .. string.format(L["GUIDES_PARSED_STEPS"], #parsed.steps))
                            if onImportCallback then onImportCallback(guideID) end
                            frame:Hide()
                            frame:SetParent(nil)
                            return
                        end
                    end

                    local guideID, err = ns.GuidesData:ImportGuide(text)
                    if guideID then
                        print("|cFFFFD100OneWoW Notes:|r " .. L["GUIDES_IMPORT_SUCCESS"])
                        if onImportCallback then onImportCallback(guideID) end
                        frame:Hide()
                        frame:SetParent(nil)
                    else
                        print("|cFFFFD100OneWoW Notes:|r " .. L["GUIDES_IMPORT_FAILED"] .. ": " .. (err or ""))
                    end
                end,
            },
            {
                text = L["BUTTON_CANCEL"],
                onClick = function(frame)
                    frame:Hide()
                    frame:SetParent(nil)
                end,
            },
        },
    })

    local content = dialog.content
    local yOff = 0

    MakeLabel(content, L["LABEL_NOTE_TITLE"], 10, yOff)
    yOff = yOff - 16
    local titleBox = MakeEditBox(content, 10, yOff, 360, 28, "")
    dialog._titleBox = titleBox

    local catDD = ns.UI.CreateThemedDropdown(content, "", 180, 28)
    catDD:SetPoint("LEFT", titleBox, "RIGHT", 8, 0)
    local catOpts = {}
    for _, c in ipairs(ns.GuidesData:GetCategories()) do
        table.insert(catOpts, { text = c, value = c })
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected("General")
    dialog._catDD = catDD

    yOff = yOff - 40
    local hintText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintText:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    hintText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOff)
    hintText:SetJustifyH("LEFT")
    hintText:SetText(L["GUIDES_IMPORT_HINT"])
    hintText:SetTextColor(T("TEXT_SECONDARY"))
    hintText:SetWordWrap(true)

    yOff = yOff - 20
    local markupHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    markupHint:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    markupHint:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOff)
    markupHint:SetJustifyH("LEFT")
    markupHint:SetText(L["GUIDES_MARKUP_HINT"])
    markupHint:SetTextColor(T("TEXT_MUTED"))
    markupHint:SetWordWrap(true)

    yOff = yOff - 30
    local importScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    importScroll:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    importScroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -30, 10)

    local importBox = CreateFrame("EditBox", nil, importScroll)
    importBox:SetWidth(importScroll:GetWidth())
    importBox:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    importBox:SetTextColor(T("TEXT_PRIMARY"))
    importBox:SetMultiLine(true)
    importBox:SetAutoFocus(false)
    importBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    importScroll:SetScrollChild(importBox)
    dialog._importBox = importBox

    dialog:Show()
    return dialog
end

function ns.UI.ShowGuideExportDialog(guideID)
    local exportStr = ns.GuidesData:ExportGuide(guideID)
    if not exportStr then return end

    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_GuideExport",
        title = L["GUIDES_EXPORT"],
        width = 500,
        height = 350,
        destroyOnClose = true,
        buttons = {
            {
                text = L["BUTTON_CLOSE"],
                onClick = function(frame)
                    frame:Hide()
                    frame:SetParent(nil)
                end,
            },
        },
    })

    local content = dialog.content

    local hintText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hintText:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    hintText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, -10)
    hintText:SetJustifyH("LEFT")
    hintText:SetText(L["GUIDES_EXPORT_HINT"])
    hintText:SetTextColor(T("TEXT_SECONDARY"))
    hintText:SetWordWrap(true)

    local exportScroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    exportScroll:SetPoint("TOPLEFT", hintText, "BOTTOMLEFT", 0, -10)
    exportScroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -30, 10)

    local exportBox = CreateFrame("EditBox", nil, exportScroll)
    exportBox:SetWidth(exportScroll:GetWidth())
    exportBox:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    exportBox:SetTextColor(T("TEXT_PRIMARY"))
    exportBox:SetMultiLine(true)
    exportBox:SetAutoFocus(false)
    exportBox:SetText(exportStr)
    exportBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    exportScroll:SetScrollChild(exportBox)

    exportBox:HighlightText()
    exportBox:SetFocus()

    dialog:Show()
    return dialog
end
