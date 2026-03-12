local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local lib = LibStub("OneWoW_GUI-1.0", true)

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

local function MakeLabel(parent, text, x, y)
    local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    lbl:SetText(text)
    lbl:SetTextColor(T("TEXT_SECONDARY"))
    return lbl
end

local function MakeMultiLineScrollBox(parent, font, fontSize)
    local scrollFrame, scrollChild = lib:CreateScrollFrame(nil, parent)
    scrollFrame:ClearAllPoints()
    scrollFrame:SetAllPoints(parent)

    local editBox = CreateFrame("EditBox", nil, scrollFrame)
    editBox:SetWidth(scrollFrame:GetWidth() or 400)
    editBox:SetFont(font or ns.Config:ResolveFontPath(nil), fontSize or 11, "")
    editBox:SetTextColor(T("TEXT_PRIMARY"))
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    scrollFrame:SetScrollChild(editBox)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        editBox:SetWidth(w - 16)
    end)

    return scrollFrame, editBox
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
    local markupContainer = lib:CreateFrame(nil, content, 1, 1)
    markupContainer:ClearAllPoints()
    markupContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    markupContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)

    local _, markupBox = MakeMultiLineScrollBox(markupContainer, ns.Config:ResolveFontPath(nil), 11)

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
                    local stepTitle = frame._titleBox:GetSearchText() or ""
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
    local titleBox = lib:CreateEditBox(nil, content, { width = 460, height = 28 })
    titleBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    titleBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOff)
    if step and step.title then
        titleBox:SetText(step.title)
        titleBox:SetTextColor(T("TEXT_PRIMARY"))
    end
    dialog._titleBox = titleBox

    yOff = yOff - 36
    MakeLabel(content, L["GUIDES_STEP_DESC"], 10, yOff)
    yOff = yOff - 16
    local descContainer = lib:CreateFrame(nil, content, 1, 80)
    descContainer:ClearAllPoints()
    descContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    descContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOff)
    descContainer:SetHeight(80)

    local _, descBox = MakeMultiLineScrollBox(descContainer, ns.Config:ResolveFontPath(nil), 11)
    descBox:SetText(step and step.description or "")
    dialog._descBox = descBox

    yOff = yOff - 100
    MakeLabel(content, L["GUIDES_FACTION"], 10, yOff)
    local factionDD = ns.UI.CreateThemedDropdown(content, "", 150, 26)
    factionDD:SetPoint("TOPLEFT", content, "TOPLEFT", 100, yOff + 2)
    factionDD:SetOptions(FACTION_OPTIONS)
    factionDD:SetSelected(step and step.faction or "both")
    dialog._factionDD = factionDD

    local optionalCB = lib:CreateCheckbox(nil, content, L["GUIDES_OPTIONAL"])
    optionalCB:SetPoint("TOPLEFT", content, "TOPLEFT", 280, yOff + 4)
    optionalCB:SetChecked(step and step.optional or false)
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
                    local desc = frame._descBox:GetSearchText() or ""
                    local params = {}

                    local fields = PARAM_FIELDS[objType]
                    if fields and frame._paramBoxes then
                        for i, field in ipairs(fields) do
                            if frame._paramBoxes[i] then
                                params[field.key] = tonumber(frame._paramBoxes[i]:GetSearchText()) or 0
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
    local descBox = lib:CreateEditBox(nil, content, { width = 460, height = 28 })
    descBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    descBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOff)
    if obj and obj.description then
        descBox:SetText(obj.description)
        descBox:SetTextColor(T("TEXT_PRIMARY"))
    end
    dialog._descBox = descBox

    yOff = yOff - 40

    local paramContainer = CreateFrame("Frame", nil, content)
    paramContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOff)
    paramContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, yOff)
    paramContainer:SetHeight(200)

    dialog._paramBoxes = {}

    local function BuildParamFields(objType)
        if lib then lib:ClearFrame(paramContainer) end
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
            local box = lib:CreateEditBox(nil, paramContainer, { width = 200, height = 28 })
            box:SetPoint("TOPLEFT", paramContainer, "TOPLEFT", 10, pY)
            box:SetNumeric(true)
            local val = tostring(existingParams[field.key] or "")
            if val ~= "" then
                box:SetText(val)
                box:SetTextColor(T("TEXT_PRIMARY"))
            end
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
                            title = parsed.title ~= "" and parsed.title or (frame._titleBox and frame._titleBox:GetSearchText() or ""),
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
    local titleBox = lib:CreateEditBox(nil, content, { width = 360, height = 28 })
    titleBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
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
    local importContainer = lib:CreateFrame(nil, content, 1, 1)
    importContainer:ClearAllPoints()
    importContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOff)
    importContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)

    local _, importBox = MakeMultiLineScrollBox(importContainer, ns.Config:ResolveFontPath(nil), 10)
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

    local exportContainer = lib:CreateFrame(nil, content, 1, 1)
    exportContainer:ClearAllPoints()
    exportContainer:SetPoint("TOPLEFT", hintText, "BOTTOMLEFT", 0, -10)
    exportContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)

    local _, exportBox = MakeMultiLineScrollBox(exportContainer, ns.Config:ResolveFontPath(nil), 10)
    exportBox:SetText(exportStr)
    exportBox:HighlightText()
    exportBox:SetFocus()

    dialog:Show()
    return dialog
end
