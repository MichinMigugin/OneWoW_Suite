local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Location = OneWoW.Location
local Schema = ns.TrackerTypeSchema
local TP = ns.TrackerPresets

ns.TrackerEditor = {}
local TE_UI = ns.TrackerEditor

local tinsert, tremove, tonumber, tostring = tinsert, tremove, tonumber, tostring
local strtrim, sort, pairs, ipairs, format = strtrim, sort, pairs, ipairs, format
local floor = math.floor
local CreateVector2D = CreateVector2D
local C_MapExplorationInfo = C_MapExplorationInfo
local UnitExists, UnitGUID, UnitName = UnitExists, UnitGUID, UnitName
local GetInstanceInfo, GetExpansionLevel = GetInstanceInfo, GetExpansionLevel
local C_Map = C_Map

local BACKDROP_SOFT = OneWoW_GUI.Constants.BACKDROP_SOFT or OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE
local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE

local DEFAULT_REPEAT_HOURS = 24
local LIST_FORM_HEIGHT = 484
local LIST_FORM_HEIGHT_REPEAT = 534
local TYPE_LIST_H = 300
local STEP_EDITOR_HEIGHT = 700
local stepEditorCollapsed = {}

local function MakeLabel(parent, text, x, y)
    local fs = OneWoW_GUI:CreateFS(parent, 10)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return fs
end

local function FillMsg(key)
    print(L["ADDON_CHAT_PREFIX"] .. " " .. L[key])
end

local function GetTargetCreatureID()
    if not UnitExists("target") then return nil, "none" end
    local guid = UnitGUID("target")
    if not guid then return nil, "none" end
    if OneWoW.Restriction.IsSecret(guid) then return nil, "restricted" end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType ~= "Creature" and unitType ~= "Vehicle" then return nil, "invalid" end
    return tonumber(npcID)
end

local function FillCreatureFromTarget(card, fieldKey, isKill)
    local cid, reason = GetTargetCreatureID()
    if not cid then
        if reason == "restricted" then
            FillMsg("TRACKER_FILL_TARGET_RESTRICTED")
            if isKill then FillMsg("TRACKER_FILL_KILL_USE_ENCOUNTER") end
        else
            FillMsg("TRACKER_FILL_NO_TARGET")
        end
        return
    end
    local box = card["_field_" .. fieldKey]
    if box then box:SetText(tostring(cid)) end
end

local function WriteQuestID(card, questID)
    local text = tostring(questID)
    if card._field_questIDs then card._field_questIDs:SetText(text) end
    if card._field_questID then card._field_questID:SetText(text) end
end

local function WriteLockWaypoint(card, lock)
    if not lock.mapID or not lock.x or not lock.y then return end
    if card._wpMap then card._wpMap:SetText(tostring(lock.mapID)) end
    if card._wpX then
        card._wpX:SetText(format("%.1f", lock.x))
        card._wpX:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    if card._wpY then
        card._wpY:SetText(format("%.1f", lock.y))
        card._wpY:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

local function RareLabel(lock)
    local name = OneWoW.Collectibles.ResolveNPCName(lock.npcID)
    if not name then
        name = format(L["TRACKER_RARE_FALLBACK"], lock.npcID)
    end
    if lock.mapID then
        local info = C_Map.GetMapInfo(lock.mapID)
        if info and info.name then
            return info.name .. " - " .. name, name
        end
    end
    return name, name
end

local function RareSearchOptions()
    local opts = {}
    local locks = OneWoW.Collectibles.GetRareLocks({ expansion = GetExpansionLevel() })
    for _, lock in ipairs(locks) do
        local text = RareLabel(lock)
        tinsert(opts, { value = lock.npcID, text = text })
    end
    sort(opts, function(a, b) return a.text < b.text end)
    return opts
end

local function FillRareFromTarget(card)
    local cid, reason = GetTargetCreatureID()
    if not cid then
        if reason == "restricted" then
            FillMsg("TRACKER_FILL_TARGET_RESTRICTED")
        else
            FillMsg("TRACKER_FILL_NO_TARGET")
        end
        return
    end
    local lock = OneWoW.Collectibles.GetRareLockByNpc(cid)
    if not lock then
        FillMsg("TRACKER_FILL_NO_RARE_LOCK")
        return
    end
    WriteQuestID(card, lock.questID)
    WriteLockWaypoint(card, lock)
    local nameBox = card._nameBox
    local _, shortName = RareLabel(lock)
    local targetName = UnitName("target")
    if nameBox then
        if targetName and not OneWoW.Restriction.IsSecret(targetName) then
            nameBox:SetText(targetName)
        elseif shortName then
            nameBox:SetText(shortName)
        end
    end
end

local function UpdateTitleFromTarget(nameBox)
    local name = UnitName("target")
    if not name then FillMsg("TRACKER_FILL_NO_TARGET"); return end
    if OneWoW.Restriction.IsSecret(name) then FillMsg("TRACKER_FILL_TARGET_RESTRICTED"); return end
    nameBox:SetText(format(L["TRACKER_TALK_TO_FORMAT"], name))
end

local function IsDungeonOrRaid()
    local _, instanceType = GetInstanceInfo()
    return instanceType == "party" or instanceType == "raid"
end

local function FillEncounterFromCurrent(card, nameBox)
    local info = ns.TrackerEncounter.GetFillable()
    if not info or not info.dungeonEncounterID then
        FillMsg("TRACKER_FILL_NO_ENCOUNTER")
        return
    end
    local displayID = ns.TrackerEncounter.DisplayID(info)
    local box = card._field_encounterID
    if box then box:SetText(tostring(displayID)) end
    card._encounterFill = info
    if nameBox and info.name then
        nameBox:SetText(info.name)
        nameBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
end

local function FillCoordsFromPosition(card)
    local mapID, x, y = Location.GetPlayerLocation()
    if not mapID or not x then FillMsg("TRACKER_FILL_NO_POSITION"); return end
    if card._field_mapID then card._field_mapID:SetText(tostring(mapID)) end
    if card._field_x then card._field_x:SetText(format("%.1f", x)) end
    if card._field_y then card._field_y:SetText(format("%.1f", y)) end
end

local function FillMapFromPosition(card)
    local mapID = Location.GetPlayerMapID()
    if not mapID then FillMsg("TRACKER_FILL_NO_POSITION"); return end
    if card._field_mapID then card._field_mapID:SetText(tostring(mapID)) end
end

local function FillAreaFromPosition(card)
    local mapID, x, y = Location.GetPlayerLocation()
    if not mapID or not x then FillMsg("TRACKER_FILL_NO_POSITION"); return end
    local ids = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(
        mapID, CreateVector2D(x / 100, y / 100))
    if not ids or not ids[1] then FillMsg("TRACKER_FILL_NO_AREA"); return end
    if card._field_areaID then card._field_areaID:SetText(tostring(ids[1])) end
end

local function FillInstanceFromCurrent(card)
    local _, instanceType, _, _, _, _, _, instanceID = GetInstanceInfo()
    if instanceType == "none" or not instanceID then FillMsg("TRACKER_FILL_NO_INSTANCE"); return end
    if card._field_instanceID then card._field_instanceID:SetText(tostring(instanceID)) end
end

local dialogCache = {}

local function CreateDialog(config)
    local dialogName = config.name or "OneWoW_TrackersDialog"
    local destroyOnClose = config.destroyOnClose
    local cached = dialogCache[dialogName]
    if destroyOnClose and cached then
        cached:Hide()
        cached:SetParent(nil)
        dialogCache[dialogName] = nil
        cached = nil
    end
    if cached then
        if cached:IsShown() then cached:Raise() return cached end
        cached:Show()
        cached:Raise()
        return cached
    end

    local result = OneWoW_GUI:CreateDialog({
        name = dialogName,
        title = config.title or "",
        width = config.width or 500,
        height = config.height or 400,
        showBrand = true,
        showScrollFrame = config.showScrollFrame,
        relayout = config.relayout,
        buttons = config.buttons,
        onClose = function()
            if config.onClose then config.onClose() end
            if destroyOnClose then
                dialogCache[dialogName] = nil
            end
        end,
    })

    local frame = result.frame
    frame.content = result.scrollContent or result.contentFrame
    frame.scrollFrame = result.scrollFrame
    dialogCache[dialogName] = frame
    frame:HookScript("OnHide", function()
        OneWoW_GUI:CloseAttachFilterMenu()
    end)
    frame:HookScript("OnShow", function(myself)
        C_Timer.After(0, function()
            OneWoW_GUI:ApplyFontToFrame(myself)
        end)
    end)
    frame:Hide()
    return frame
end

local function IsStepCardCollapsed(key, existing)
    if stepEditorCollapsed[key] ~= nil then
        return stepEditorCollapsed[key]
    end
    if key == "tracking" then
        return false
    end
    if not existing then
        return true
    end
    if key == "gates" then
        local req = existing.requiresSteps
        return not ((existing.faction and existing.faction ~= "both")
            or existing.professionRequired
            or existing.eventRequired
            or (req and #req > 0))
    end
    if key == "notes" then
        local note = existing.userNote
        local desc = existing.description
        return not ((note and note ~= "") or (desc and desc ~= ""))
    end
    if key == "waypoint" then
        return not existing.mapID
    end
    if key == "objectives" then
        local objs = existing.objectives
        return not (objs and #objs > 0)
    end
    return false
end

local function MakeEditorCard(stack, parent, key, title, existing)
    local card = OneWoW_GUI:CreateCard(parent, {
        title = title,
        collapsed = IsStepCardCollapsed(key, existing),
        onToggle = function(collapsed)
            stepEditorCollapsed[key] = collapsed
            stack:Relayout()
        end,
    })
    stack:AddFrame(card)
    return card
end

local function HintHeight(fs, wrapW)
    if wrapW and wrapW > 50 then
        fs:SetWidth(wrapW)
    end
    return fs:GetStringHeight() or 14
end

local function CreateDropdown(parent, width, height, searchable)
    local dropdown, textFS = OneWoW_GUI:CreateDropdown(parent, {
        width = width or 150,
        height = height or 26,
    })
    dropdown._value = nil
    dropdown._options = {}
    dropdown.onSelect = nil

    function dropdown:SetOptions(options)
        self._options = options
    end

    function dropdown:SetSelected(value)
        for _, opt in ipairs(self._options) do
            if opt.value == value then
                self._value = value
                self._activeValue = value
                textFS:SetText(opt.text)
                return
            end
        end
    end

    function dropdown:GetValue()
        return self._value
    end

    OneWoW_GUI:AttachFilterMenu(dropdown, {
        searchable = searchable == true,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(dropdown._options) do
                tinsert(items, { value = opt.value, text = opt.text })
            end
            return items
        end,
        onSelect = function(value, displayText)
            dropdown._value = value
            dropdown._activeValue = value
            textFS:SetText(displayText)
            if dropdown.onSelect then dropdown.onSelect(value, displayText) end
        end,
        getActiveValue = function()
            return dropdown._value
        end,
    })
    return dropdown
end

local FIELD_ROW_INNER = 590
local FIELD_ROW_GAP = 20
local FIELD_ROW_H = 38
local FIELD_ENTITY_ROW_H = 56
local SAVE_ROW_H = 26
-- Title pad + 12pt title + gap before desc. Nested type-card wrap is narrower
-- than the dialog hero (LEFT+RIGHT is not laid out at measure time).
local CARD_TITLE_H = 28
local CARD_DESC_PAD = 14
local TYPE_CARD_DESC_WRAP = 500

local function CardHeaderHeight(descHeight)
    return CARD_TITLE_H + (descHeight or 14) + CARD_DESC_PAD
end

local function RecalcQuestRareUI(card)
    local isRare = card._scopeDD and card._scopeDD:GetValue() == "rare_quest"
    local pane = card._rarePane
    if pane then
        if isRare then
            pane:Show()
            pane:SetHeight(FIELD_ROW_H)
            if card._rareSearch then
                card._rareSearch:SetOptions(RareSearchOptions())
            end
        else
            pane:Hide()
            pane:SetHeight(0)
        end
    end
    if card._fillBtn then
        if isRare and card._expanded then
            card._fillBtn:Show()
        else
            card._fillBtn:Hide()
        end
    end
    if card._fieldRow then
        local paneH = (isRare and pane) and FIELD_ROW_H or 0
        card._expandedHeight = CardHeaderHeight(card._descHeight) + card._fieldRow:GetHeight() + paneH + SAVE_ROW_H
        if card._expanded then
            card:SetHeight(card._expandedHeight)
            if card._reflow then card._reflow() end
        end
    end
end

local function FieldSlotHeight(field)
    if field.widgetType == "entityId" and OneWoW_GUI:HasEntityResolver(field.entityKind) then
        return FIELD_ENTITY_ROW_H
    end
    return FIELD_ROW_H
end

local LIST_FIELD_QUEST_IDS = {
    key = "questIDs",
    labelKey = "TRACKER_FL_QUEST_IDS",
    hintKey = "TRACKER_FH_QUEST_IDS",
    width = 320,
    isList = true,
    maxLetters = 400,
    widgetType = "editbox",
}

local LIST_FIELD_SPELL_IDS = {
    key = "spellIDs",
    labelKey = "TRACKER_FL_SPELL_ID",
    hintKey = "TRACKER_FH_SPELL_ID",
    width = 320,
    isList = true,
    maxLetters = 400,
    widgetType = "editbox",
}

local FIELD_CATCHUP_CURRENCY = {
    key = "currencyID",
    labelKey = "TRACKER_FL_CURRENCY_ID",
    hintKey = "TRACKER_FH_CURRENCY_ID",
    width = 160,
    widgetType = "entityId",
    entityKind = "currency",
}

local QUEST_SCOPE_TYPES = {
    "quest", "quest_account", "quest_world", "quest_active", "rare_quest",
}

local function CategoryMatches(cat, trackType)
    if cat.trackType == trackType then return true end
    if cat.matchesTypes then
        for _, t in ipairs(cat.matchesTypes) do
            if t == trackType then return true end
        end
    end
    return false
end

local function CardHasEditor(cat, fields)
    return #fields > 0 or cat.extra ~= nil
end

local function PlaceFieldSlot(layout, fieldRow, field, widget)
    local w = field.width or 120
    local slotH = FieldSlotHeight(field)
    if layout.fx > 0 and layout.fx + w > FIELD_ROW_INNER then
        layout.fx = 0
        layout.fy = layout.fy - layout.rowH
        layout.rowH = slotH
    elseif slotH > layout.rowH then
        layout.rowH = slotH
    end

    local flbl = OneWoW_GUI:CreateFS(fieldRow, 10)
    flbl:SetPoint("TOPLEFT", fieldRow, "TOPLEFT", layout.fx, layout.fy)
    flbl:SetText(L[field.labelKey] .. ":")
    flbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    widget:SetPoint("TOPLEFT", flbl, "BOTTOMLEFT", 0, -1)
    layout.fx = layout.fx + w + FIELD_ROW_GAP
end

local function FieldLayoutHeight(layout)
    return -layout.fy + layout.rowH
end

local function ProfessionDisplayName(prof)
    local name = C_TradeSkillUI.GetTradeSkillDisplayName(prof.baseSkillLineID)
    if name and name ~= "" then return name end
    return prof.name
end

local function ProfessionBySkillLine(skillLineID)
    for _, prof in ipairs(TP:GetProfessionPresets()) do
        if prof.baseSkillLineID == skillLineID then return prof end
    end
end

local PROF_REQ_NONE = "none"

local function FactionOptions()
    return {
        { text = L["OVR_EFFECT_BOTH"], value = "both" },
        { text = FACTION_ALLIANCE, value = "alliance" },
        { text = FACTION_HORDE, value = "horde" },
    }
end

local function ProfessionRequiredOptions(existingID)
    local opts = { { text = NONE, value = PROF_REQ_NONE } }
    local seen = false
    for _, prof in ipairs(TP:GetProfessionPresets()) do
        tinsert(opts, { text = ProfessionDisplayName(prof), value = prof.baseSkillLineID })
        if existingID and prof.baseSkillLineID == existingID then
            seen = true
        end
    end
    if existingID and not seen then
        tinsert(opts, { text = tostring(existingID), value = existingID })
    end
    return opts
end

local function CollectRequiresKeys(selected)
    local keys = {}
    for key, on in pairs(selected) do
        if on then tinsert(keys, key) end
    end
    return keys
end

local function ReadVisibilityGates(dialog)
    local faction = dialog._factionDD:GetValue() or "both"
    local profVal = dialog._profReqDD:GetValue()
    local professionRequired = (type(profVal) == "number") and profVal or false
    local eventID = tonumber(strtrim(dialog._eventBox:GetSearchText() or ""))
    return faction, professionRequired, eventID or false
end

--- Faction / profession / calendar-event gates. These hide the step or
--- section; an unknown event ID fail-opens in the engine.
--- opts.anchor + opts.dx: section editor (relative to a prior widget).
--- No anchor: pack from the top of content (step-editor card).
local function WireVisibilityGates(dialog, content, existing, opts)
    opts = opts or {}
    local factionLabel = OneWoW_GUI:CreateFS(content, 10)
    if opts.anchor then
        factionLabel:SetPoint("TOPLEFT", opts.anchor, "BOTTOMLEFT", opts.dx or 0, -8)
    else
        factionLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    end
    factionLabel:SetText(FACTION .. ":")
    factionLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local factionDD = CreateDropdown(content, 160, 26)
    factionDD:SetPoint("TOPLEFT", factionLabel, "BOTTOMLEFT", 0, -2)
    factionDD:SetOptions(FactionOptions())
    factionDD:SetSelected((existing and existing.faction) or "both")
    dialog._factionDD = factionDD

    local profLabel = OneWoW_GUI:CreateFS(content, 10)
    profLabel:SetPoint("TOPLEFT", factionLabel, "TOPLEFT", 180, 0)
    profLabel:SetText(L["PROFESSION"] .. ":")
    profLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local existingProf = existing and tonumber(existing.professionRequired)
    local profDD = CreateDropdown(content, 200, 26)
    profDD:SetPoint("TOPLEFT", profLabel, "BOTTOMLEFT", 0, -2)
    profDD:SetOptions(ProfessionRequiredOptions(existingProf))
    profDD:SetSelected(existingProf or PROF_REQ_NONE)
    dialog._profReqDD = profDD

    local eventLabel = OneWoW_GUI:CreateFS(content, 10)
    eventLabel:SetPoint("TOPLEFT", factionDD, "BOTTOMLEFT", 0, -8)
    eventLabel:SetText(L["TRACKER_FL_EVENT_ID"] .. ":")
    eventLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local eventBox = OneWoW_GUI:CreateEditBox(content, {
        width = 120,
        height = 26,
        placeholderText = L["TRACKER_FH_EVENT_ID"],
        maxLetters = 8,
        showClear = false,
    })
    eventBox:SetPoint("TOPLEFT", eventLabel, "BOTTOMLEFT", 0, -2)
    if existing and existing.eventRequired then
        eventBox:SetText(tostring(existing.eventRequired))
    end
    dialog._eventBox = eventBox

    local gateHint = OneWoW_GUI:CreateFS(content, 10)
    gateHint:SetPoint("TOPLEFT", eventBox, "BOTTOMLEFT", 0, -2)
    gateHint:SetPoint("RIGHT", content, "RIGHT", opts.rightInset or -10, 0)
    gateHint:SetJustifyH("LEFT")
    gateHint:SetWordWrap(true)
    gateHint:SetText(L["TRACKER_GATE_HINT"])
    gateHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    return gateHint
end

local function RefreshRequiresLabel(dialog)
    local keys = CollectRequiresKeys(dialog._requiresSelected)
    local textFS = dialog._requiresText
    if #keys == 0 then
        textFS:SetText(NONE)
        return
    end
    if #keys == 1 then
        textFS:SetText(dialog._requiresLabels[keys[1]] or keys[1])
        return
    end
    textFS:SetText(format(L["TRACKER_REQUIRES_COUNT"], #keys))
end

--- Sibling-step picker. requiresSteps blocks user check-off; it does not hide.
local function WireRequiresPicker(dialog, content, anchor, listID, excludeKey, existing, opts)
    opts = opts or {}
    local selected = {}
    local labels = {}
    local siblings = {}
    for _, row in ipairs(ns.TrackerData:GetAllStepsFlat(listID)) do
        local step = row.step
        labels[step.key] = step.label or L["TRACKER_STEP_FALLBACK"]
        if step.key ~= excludeKey then
            tinsert(siblings, step)
        end
    end
    if existing and existing.requiresSteps then
        for _, key in ipairs(existing.requiresSteps) do
            selected[key] = true
        end
    end
    dialog._requiresSelected = selected
    dialog._requiresLabels = labels

    local reqLabel = OneWoW_GUI:CreateFS(content, 10)
    reqLabel:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    reqLabel:SetText(L["TRACKER_FL_REQUIRES"] .. ":")
    reqLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local dd, textFS = OneWoW_GUI:CreateDropdown(content, { width = 320, height = 26 })
    dd:SetPoint("TOPLEFT", reqLabel, "BOTTOMLEFT", 0, -2)
    dialog._requiresText = textFS
    RefreshRequiresLabel(dialog)

    dd:SetScript("OnClick", function()
        OneWoW_GUI:CloseAttachFilterMenu()
        MenuUtil.CreateContextMenu(dd, function(_, rootDescription)
            rootDescription:CreateTitle(L["TRACKER_FL_REQUIRES"])
            if #siblings == 0 then
                rootDescription:CreateTitle(L["TRACKER_REQUIRES_EMPTY"])
                return
            end
            for _, step in ipairs(siblings) do
                local key = step.key
                rootDescription:CreateCheckbox(labels[key], function()
                    return selected[key] == true
                end, function()
                    selected[key] = not selected[key]
                    RefreshRequiresLabel(dialog)
                end)
            end
        end)
    end)

    local reqHint = OneWoW_GUI:CreateFS(content, 10)
    reqHint:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
    reqHint:SetPoint("RIGHT", content, "RIGHT", opts.rightInset or -10, 0)
    reqHint:SetJustifyH("LEFT")
    reqHint:SetWordWrap(true)
    reqHint:SetText(L["TRACKER_REQUIRES_HINT"])
    reqHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    return reqHint
end

local function MatchProfessionFromStep(trackType, params)
    params = params or {}
    for _, prof in ipairs(TP:GetProfessionPresets()) do
        if trackType == "prof_skill" and tonumber(params.baseSkillLineID) == prof.baseSkillLineID then
            return prof
        elseif trackType == "prof_concentration" and tonumber(params.currencyID) == prof.currencyConc then
            return prof
        elseif trackType == "prof_knowledge" and tonumber(params.skillLineVariantID) == prof.skillVariant then
            return prof
        end
    end
    return TP:GetProfessionPresets()[1]
end

local function ProfessionTaskOptions(prof)
    local opts = {
        { text = L["TRACKER_TYPE_PROF_SKILL"], value = "prof_skill" },
    }
    if prof and prof.currencyConc then
        tinsert(opts, { text = L["TRACKER_TYPE_PROF_CONC"], value = "prof_concentration" })
    end
    if prof and prof.skillVariant then
        tinsert(opts, { text = L["TRACKER_TYPE_PROF_KNOW"], value = "prof_knowledge" })
    end
    tinsert(opts, { text = L["TRACKER_TYPE_PROF_FIRST"], value = "prof_firstcraft" })
    tinsert(opts, { text = L["TRACKER_TYPE_PROF_CATCHUP"], value = "prof_catchup" })
    return opts
end

local function TaskAllowedForProfession(task, prof)
    if task == "prof_concentration" then return prof and prof.currencyConc ~= nil end
    if task == "prof_knowledge" then return prof and prof.skillVariant ~= nil end
    return task ~= nil
end

local function PlaceLabeledDropdown(layout, fieldRow, labelKey, width, dropdown)
    PlaceFieldSlot(layout, fieldRow, {
        key = "_dd",
        labelKey = labelKey,
        width = width,
        widgetType = "dropdown",
    }, dropdown)
end

--- Editbox, dropdown, or entity ID field from a schema descriptor.
--- Unregistered entity kinds degrade to a plain numeric box.
local function CreateFieldWidget(parent, field, existingVal, isNew)
    if field.widgetType == "dropdown" then
        local dd = CreateDropdown(parent, field.width or 160, 22)
        local opts = field.options
        if type(opts) == "function" then opts = opts() end
        dd:SetOptions(opts or {})
        if existingVal ~= nil then
            dd:SetSelected(existingVal)
        elseif isNew and field.default ~= nil then
            dd:SetSelected(field.default)
        end
        return dd
    end

    if field.widgetType == "entityId" and OneWoW_GUI:HasEntityResolver(field.entityKind) then
        local widget = OneWoW_GUI:CreateEntityIdField(parent, {
            width = field.width or 160,
            height = 22,
            placeholderText = field.hintKey and L[field.hintKey] or nil,
            maxLetters = field.maxLetters or 12,
            kind = field.entityKind,
        })
        if existingVal ~= nil then
            widget:SetText(tostring(existingVal))
        elseif isNew and field.default ~= nil then
            widget:SetText(tostring(field.default))
        end
        return widget
    end

    local fbox = OneWoW_GUI:CreateEditBox(parent, {
        width = field.width or 120,
        height = 22,
        placeholderText = field.hintKey and L[field.hintKey] or nil,
        maxLetters = field.maxLetters or 12,
    })
    if existingVal ~= nil then
        if field.isList and type(existingVal) == "table" then
            local parts = {}
            for _, v in ipairs(existingVal) do
                tinsert(parts, tostring(v))
            end
            fbox:SetText(table.concat(parts, ", "))
        else
            fbox:SetText(tostring(existingVal))
        end
    elseif isNew and field.default ~= nil then
        fbox:SetText(tostring(field.default))
    end
    return fbox
end

local function ReadFieldWidget(widget, field)
    if not widget then return nil end
    if field.widgetType == "dropdown" then
        return widget:GetValue()
    end
    local val = strtrim(widget:GetText() or "")
    if val == "" then return nil end
    if field.isList then
        local list = {}
        for part in val:gmatch("[^,%s]+") do
            local n = tonumber(part)
            if n then tinsert(list, n) end
        end
        return #list > 0 and list or nil
    end
    return tonumber(val) or val
end

local function AttachCardExtra(card, cat, fieldRow, layout, existing, isNew)
    if cat.extra == "quest" then
        local scopeDD = CreateDropdown(fieldRow, 200, 22)
        local scopeOpts = {}
        for _, t in ipairs(QUEST_SCOPE_TYPES) do
            tinsert(scopeOpts, { text = ns.TrackerEngine:GetTrackTypeDisplayName(t), value = t })
        end
        scopeDD:SetOptions(scopeOpts)
        local selected = (existing and CategoryMatches(cat, existing.trackType)) and existing.trackType or "quest"
        scopeDD:SetSelected(selected)
        card._scopeDD = scopeDD
        PlaceLabeledDropdown(layout, fieldRow, "TRACKER_FL_QUEST_SCOPE", 200, scopeDD)

        local idsVal
        if existing and existing.trackParams and CategoryMatches(cat, existing.trackType) then
            idsVal = existing.trackParams.questIDs
        end
        local idsWidget = CreateFieldWidget(fieldRow, LIST_FIELD_QUEST_IDS, idsVal, isNew)
        card._field_questIDs = idsWidget
        PlaceFieldSlot(layout, fieldRow, LIST_FIELD_QUEST_IDS, idsWidget)

        local rarePane = CreateFrame("Frame", nil, card)
        rarePane:SetHeight(0)
        card._rarePane = rarePane

        local rareLabel = OneWoW_GUI:CreateFS(rarePane, 10)
        rareLabel:SetPoint("TOPLEFT", rarePane, "TOPLEFT", 0, 0)
        rareLabel:SetText(L["TRACKER_FL_RARE_SEARCH"] .. ":")
        rareLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        local rareSearch = CreateDropdown(rarePane, 320, 22, true)
        rareSearch:SetPoint("TOPLEFT", rareLabel, "BOTTOMLEFT", 0, -1)
        rareSearch:SetOptions(RareSearchOptions())
        if rareSearch._text then
            rareSearch._text:SetText(L["TRACKER_FH_RARE_SEARCH"])
        end
        rareSearch.onSelect = function(npcID)
            local lock = OneWoW.Collectibles.GetRareLockByNpc(npcID)
            if not lock then return end
            WriteQuestID(card, lock.questID)
            WriteLockWaypoint(card, lock)
            local nameBox = card._nameBox
            if nameBox then
                local _, shortName = RareLabel(lock)
                nameBox:SetText(shortName)
            end
        end
        card._rareSearch = rareSearch

        scopeDD.onSelect = function()
            RecalcQuestRareUI(card)
        end
        return
    end

    if cat.extra == "vault" then
        local vaultDD = CreateDropdown(fieldRow, 220, 22)
        vaultDD:SetOptions({
            { text = L["TRACKER_TYPE_VAULT_RAID"], value = "vault_raid" },
            { text = L["TRACKER_TYPE_VAULT_DUNGEON"], value = "vault_dungeon" },
            { text = L["TRACKER_TYPE_VAULT_WORLD"], value = "vault_world" },
        })
        vaultDD:SetSelected((existing and CategoryMatches(cat, existing.trackType)) and existing.trackType or "vault_raid")
        card._vaultDD = vaultDD
        PlaceLabeledDropdown(layout, fieldRow, "SLOT", 220, vaultDD)
        return
    end

    if cat.extra == "profession" then
        local params = existing and existing.trackParams or {}
        local prof = MatchProfessionFromStep(existing and existing.trackType, params)
        local profDD = CreateDropdown(fieldRow, 200, 22)
        local profOpts = {}
        for _, p in ipairs(TP:GetProfessionPresets()) do
            tinsert(profOpts, { text = ProfessionDisplayName(p), value = p.baseSkillLineID })
        end
        profDD:SetOptions(profOpts)
        profDD:SetSelected(prof and prof.baseSkillLineID)
        card._profDD = profDD
        PlaceLabeledDropdown(layout, fieldRow, "PROFESSION", 200, profDD)

        local taskDD = CreateDropdown(fieldRow, 200, 22)
        taskDD:SetOptions(ProfessionTaskOptions(prof))
        local task = (existing and CategoryMatches(cat, existing.trackType)) and existing.trackType or "prof_skill"
        if not TaskAllowedForProfession(task, prof) then task = "prof_skill" end
        taskDD:SetSelected(task)
        card._taskDD = taskDD
        PlaceLabeledDropdown(layout, fieldRow, "TRACKER_FL_PROF_TASK", 200, taskDD)

        local spellVal = params.spellIDs or params.spellID
        local spellWidget = CreateFieldWidget(fieldRow, LIST_FIELD_SPELL_IDS, spellVal, isNew)
        card._field_spellIDs = spellWidget
        PlaceFieldSlot(layout, fieldRow, LIST_FIELD_SPELL_IDS, spellWidget)

        local currVal = (existing and existing.trackType == "prof_catchup") and params.currencyID or nil
        local currWidget = CreateFieldWidget(fieldRow, FIELD_CATCHUP_CURRENCY, currVal, isNew)
        card._field_catchupCurrency = currWidget
        PlaceFieldSlot(layout, fieldRow, FIELD_CATCHUP_CURRENCY, currWidget)

        profDD.onSelect = function(skillLineID)
            local nextProf = ProfessionBySkillLine(skillLineID)
            local currentTask = taskDD:GetValue()
            taskDD:SetOptions(ProfessionTaskOptions(nextProf))
            if not TaskAllowedForProfession(currentTask, nextProf) then
                currentTask = "prof_skill"
            end
            taskDD:SetSelected(currentTask)
        end
        return
    end

    if cat.extra == "timer" then
        local hoursBox = OneWoW_GUI:CreateEditBox(fieldRow, {
            width = 80,
            height = 22,
            maxLetters = 4,
            showClear = false,
        })
        hoursBox:SetNumeric(true)
        local hours = 1
        if existing and existing.trackParams and CategoryMatches(cat, existing.trackType) then
            local n = tonumber(existing.trackParams.interval)
            if n and n > 0 then
                hours = floor(n / 3600 + 0.5)
                if hours < 1 then hours = 1 end
            end
        end
        hoursBox:SetText(tostring(hours))
        card._hoursBox = hoursBox
        PlaceFieldSlot(layout, fieldRow, {
            key = "intervalHours",
            labelKey = "TRACKER_REPEAT_HOURS",
            hintKey = "TRACKER_REPEAT_HINT",
            width = 140,
        }, hoursBox)
    end
end

local function ReadQuestCard(card)
    local trackType = card._scopeDD and card._scopeDD:GetValue() or "quest"
    local questIDs = ReadFieldWidget(card._field_questIDs, LIST_FIELD_QUEST_IDS)
    local questID = ReadFieldWidget(card._field_questID, { widgetType = "entityId" })
    if questIDs and #questIDs > 0 then
        return trackType, { questIDs = questIDs }
    end
    if questID then
        return trackType, { questID = questID }
    end
    return nil, nil
end

local function ReadProfessionCard(card)
    local skillLineID = card._profDD and card._profDD:GetValue()
    local task = card._taskDD and card._taskDD:GetValue() or "prof_skill"
    local prof = ProfessionBySkillLine(skillLineID)
    if not prof or not TaskAllowedForProfession(task, prof) then return nil, nil end
    if task == "prof_skill" then
        return task, { baseSkillLineID = prof.baseSkillLineID }
    elseif task == "prof_concentration" then
        return task, { currencyID = prof.currencyConc }
    elseif task == "prof_knowledge" then
        return task, { skillLineVariantID = prof.skillVariant }
    elseif task == "prof_firstcraft" then
        local spellIDs = ReadFieldWidget(card._field_spellIDs, LIST_FIELD_SPELL_IDS)
        if not spellIDs or #spellIDs == 0 then return nil, nil end
        return task, { spellIDs = spellIDs }
    elseif task == "prof_catchup" then
        local currencyID = ReadFieldWidget(card._field_catchupCurrency, FIELD_CATCHUP_CURRENCY)
        if not currencyID then return nil, nil end
        return task, { currencyID = currencyID }
    end
    return nil, nil
end

local function ReadVaultCard(card)
    return card._vaultDD and card._vaultDD:GetValue() or "vault_raid", {}
end

local function ReadTimerCard(card)
    local hours = tonumber(card._hoursBox and card._hoursBox:GetText())
    if not hours or hours <= 0 then
        hours = 1
    end
    return "custom_timer", { interval = hours * 3600 }
end

local OBJ_HOST_EMPTY_H = 8
local OBJ_HOST_MAX_H = 180
local OBJ_ROW_GAP = 4

local function ObjectiveTypeOptions()
    local TE = ns.TrackerEngine
    local opts = {}
    for _, trackType in ipairs(ns.TrackerData:GetTrackTypes()) do
        tinsert(opts, { text = TE:GetTrackTypeDisplayName(trackType), value = trackType })
    end
    return opts
end

local function ReadObjectiveRow(row)
    local objType = row._typeDD:GetValue() or "manual"
    local params = {}
    for _, field in ipairs(row._fields or {}) do
        local val = ReadFieldWidget(row["_field_" .. field.key], field)
        if val ~= nil then
            params[field.key] = val
        elseif field.default ~= nil then
            params[field.key] = field.default
        end
    end
    if objType == "kill_encounter" then
        params = ns.TrackerEncounter.EnrichParams(params, row._encounterFill)
    end
    local desc = strtrim(row._descBox:GetSearchText() or "")
    return objType, params, desc
end

local function SizeObjectiveRow(row)
    local h = 30
    row._descBox:ClearAllPoints()
    if row._paramHost and row._fields and #row._fields > 0 then
        h = h + (row._paramHost:GetHeight() or 0) + 4
        row._descBox:SetPoint("TOPLEFT", row._paramHost, "BOTTOMLEFT", 0, -4)
    else
        row._descBox:SetPoint("TOPLEFT", row._typeDD, "BOTTOMLEFT", 0, -4)
    end
    row._descBox:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    h = h + 26
    row:SetHeight(h)
end

local function SyncObjHostHeight(dialog)
    local contentH = dialog._objScrollChild:GetHeight() or 0
    local h = OBJ_HOST_EMPTY_H
    if #(dialog._objRows or {}) > 0 then
        h = math.min(OBJ_HOST_MAX_H, math.max(40, contentH))
    end
    dialog._objHost:SetHeight(h)
    if dialog._objCard and dialog._objChromeH then
        dialog._objCard:SetContentHeight(dialog._objChromeH + h)
    end
    if dialog._stepStack then
        dialog._stepStack:Relayout()
    end
end

local function ReflowObjectiveRows(dialog)
    local y = 0
    for _, row in ipairs(dialog._objRows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", dialog._objScrollChild, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", dialog._objScrollChild, "TOPRIGHT", 0, y)
        y = y - row:GetHeight() - OBJ_ROW_GAP
    end
    dialog._objScrollChild:SetHeight(math.max(1, math.abs(y)))
    SyncObjHostHeight(dialog)
end

local function RebuildObjectiveParams(row, trackType, params)
    if row._fields then
        for _, field in ipairs(row._fields) do
            row["_field_" .. field.key] = nil
        end
    end
    if row._paramHost then
        row._paramHost:Hide()
        row._paramHost:SetParent(nil)
        row._paramHost = nil
    end

    local fields = Schema.GetFields(trackType)
    row._fields = fields
    local host = OneWoW_GUI:CreateLayoutFrame(row, {})
    host:SetPoint("TOPLEFT", row._typeDD, "BOTTOMLEFT", 0, -4)
    host:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row._paramHost = host

    if #fields == 0 then
        host:SetHeight(1)
        host:Hide()
        SizeObjectiveRow(row)
        return
    end

    local layout = { fx = 0, fy = 0, rowH = FIELD_ROW_H }
    for _, field in ipairs(fields) do
        local existingVal = params and params[field.key]
        local widget = CreateFieldWidget(host, field, existingVal, existingVal == nil)
        row["_field_" .. field.key] = widget
        PlaceFieldSlot(layout, host, field, widget)
    end
    host:SetHeight(FieldLayoutHeight(layout))
    host:Show()
    SizeObjectiveRow(row)
end

local function AddObjectiveRow(dialog, obj)
    local row = OneWoW_GUI:CreateFrame(dialog._objScrollChild, { backdrop = BACKDROP_SOFT })
    row._objKey = obj and obj.key or nil

    local typeDD = CreateDropdown(row, 220, 22, true)
    typeDD:SetPoint("TOPLEFT", row, "TOPLEFT", 6, -6)
    typeDD:SetOptions(dialog._objTypeOpts)
    local objType = (obj and obj.type) or "manual"
    typeDD:SetSelected(objType)
    row._typeDD = typeDD

    local removeBtn = OneWoW_GUI:CreateIconButton(row, {
        iconTexture = MEDIA .. "icon-trash.png",
        size = 18,
        tooltipTitle = DELETE,
        onClick = function()
            for i, r in ipairs(dialog._objRows) do
                if r == row then
                    tremove(dialog._objRows, i)
                    break
                end
            end
            row:Hide()
            row:SetParent(nil)
            ReflowObjectiveRows(dialog)
        end,
    })
    removeBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)

    local descBox = OneWoW_GUI:CreateEditBox(row, {
        width = 1,
        height = 22,
        placeholderText = L["TRACKER_FH_OBJECTIVE_DESC"],
        maxLetters = 200,
        showClear = false,
    })
    row._descBox = descBox
    if obj and obj.description and obj.description ~= "" then
        descBox:SetText(obj.description)
    end

    typeDD.onSelect = function(value)
        RebuildObjectiveParams(row, value, nil)
        ReflowObjectiveRows(dialog)
    end

    RebuildObjectiveParams(row, objType, obj and obj.params)
    tinsert(dialog._objRows, row)
    ReflowObjectiveRows(dialog)
    return row
end

--- Draft rows live on the dialog; UpdateStep skips objectives, so save
--- flushes through AddObjective / UpdateObjective / RemoveObjective.
local function FlushObjectives(dialog, listID, sectionKey, stepKey)
    local TD = ns.TrackerData
    local keep = {}
    for _, row in ipairs(dialog._objRows or {}) do
        local objType, params, desc = ReadObjectiveRow(row)
        local isBlankNew = not row._objKey
            and objType == "manual"
            and desc == ""
            and (not row._fields or #row._fields == 0)
        if not isBlankNew then
            if row._objKey then
                TD:UpdateObjective(listID, sectionKey, stepKey, row._objKey, {
                    type = objType,
                    params = params,
                    description = desc,
                })
                keep[row._objKey] = true
            else
                local added = TD:AddObjective(listID, sectionKey, stepKey, {
                    type = objType,
                    params = params,
                    description = desc,
                })
                if added then keep[added.key] = true end
            end
        end
    end
    local step = TD:GetStep(listID, sectionKey, stepKey)
    if not step then return end
    local stale = {}
    for _, obj in ipairs(step.objectives or {}) do
        if not keep[obj.key] then
            tinsert(stale, obj.key)
        end
    end
    for _, objKey in ipairs(stale) do
        TD:RemoveObjective(listID, sectionKey, stepKey, objKey)
    end
end

local function CommitStep(dialog, listID, sectionKey, stepKey, isEdit, changes, callback)
    local TD = ns.TrackerData
    local step
    if isEdit then
        TD:UpdateStep(listID, sectionKey, stepKey, changes)
        step = TD:GetStep(listID, sectionKey, stepKey)
    else
        step = TD:AddStep(listID, sectionKey, changes)
    end
    if step then
        FlushObjectives(dialog, listID, sectionKey, step.key)
    end
    dialog:Hide(); dialog:SetParent(nil)
    if callback then callback() end
end

local function WireObjectivesEditor(dialog, content, existing)
    local addBtn = OneWoW_GUI:CreateFitTextButton(content, { text = ADD, height = 22 })
    addBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)

    local hint = OneWoW_GUI:CreateFS(content, 10)
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -2)
    hint:SetPoint("RIGHT", addBtn, "LEFT", -8, 0)
    hint:SetJustifyH("LEFT")
    hint:SetWordWrap(true)
    hint:SetText(L["TRACKER_OBJECTIVES_HINT"])
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local host = OneWoW_GUI:CreateFrame(content, { backdrop = BACKDROP_SIMPLE })
    host:ClearAllPoints()
    host:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -4)
    host:SetPoint("RIGHT", content, "RIGHT", 0, 0)
    host:SetHeight(OBJ_HOST_EMPTY_H)
    dialog._objHost = host

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(host, {})
    scrollFrame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    dialog._objScrollChild = scrollChild
    dialog._objRows = {}
    dialog._objTypeOpts = ObjectiveTypeOptions()

    addBtn:SetScript("OnClick", function()
        AddObjectiveRow(dialog, nil)
    end)

    if existing and existing.objectives then
        for _, obj in ipairs(existing.objectives) do
            AddObjectiveRow(dialog, obj)
        end
    end

    local hintH = hint:GetStringHeight() or 14
    dialog._objChromeH = math.max(22, hintH + 4) + 4
    return dialog._objChromeH + (host:GetHeight() or OBJ_HOST_EMPTY_H)
end

--- Explicit max box wins; otherwise derive from type params (item count, pool pick, ...).
local function ReadStepCount(dialog, trackType, trackParams)
    if dialog._noMaxCheck:GetChecked() then
        return 0, true
    end
    local explicit = tonumber(strtrim(dialog._maxBox:GetText() or ""))
    if explicit then
        return explicit, false
    end
    local max = 1
    if trackType == "item" then
        max = tonumber(trackParams and trackParams.count) or 1
    elseif trackType == "quest_pool" or trackType == "quest_pool_account" then
        max = tonumber(trackParams and trackParams.pick) or 1
    elseif trackParams then
        if trackParams.amount then
            max = tonumber(trackParams.amount) or 1
        elseif trackParams.level then
            max = tonumber(trackParams.level) or 1
        elseif trackParams.ilvl then
            max = tonumber(trackParams.ilvl) or 1
        elseif trackParams.standing then
            max = tonumber(trackParams.standing) or 1
        end
    end
    return max, false
end

local function ApplySharedStepFields(dialog, changes)
    local resetVal = dialog._resetDD:GetValue()
    changes.optional = not dialog._trackCheck:GetChecked()
    changes.rosterMode = dialog._rosterCheck:GetChecked() and true or false
    changes.resetOverride = (resetVal and resetVal ~= "none") and resetVal or false
    changes.userNote = strtrim(dialog._notesBox:GetText() or "")
    changes.description = strtrim(dialog._descBox:GetText() or "")
    local mapID = tonumber(strtrim(dialog._wpMap:GetSearchText() or ""))
    local x = tonumber(strtrim(dialog._wpX:GetSearchText() or ""))
    local y = tonumber(strtrim(dialog._wpY:GetSearchText() or ""))
    changes.mapID = mapID or false
    changes.coordX = x or false
    changes.coordY = y or false
    local radius = tonumber(strtrim(dialog._wpRadius:GetText() or ""))
    changes.waypointRadius = radius or 15
    local max, noMax = ReadStepCount(dialog, changes.trackType, changes.trackParams)
    changes.max = max
    changes.noMax = noMax
    local faction, professionRequired, eventRequired = ReadVisibilityGates(dialog)
    changes.faction = faction
    changes.professionRequired = professionRequired
    changes.eventRequired = eventRequired
    if dialog._requiresSelected then
        changes.requiresSteps = CollectRequiresKeys(dialog._requiresSelected)
    end
end

local function FillSharedWaypoint(dialog)
    local mapID, x, y = Location.GetPlayerLocation()
    if not mapID or not x then FillMsg("TRACKER_FILL_NO_POSITION"); return end
    dialog._wpMap:SetText(tostring(mapID))
    dialog._wpX:SetText(format("%.1f", x))
    dialog._wpX:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dialog._wpY:SetText(format("%.1f", y))
    dialog._wpY:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
end

local function HoursFromInterval(seconds)
    local n = tonumber(seconds)
    if not n or n <= 0 then return DEFAULT_REPEAT_HOURS end
    local hours = n / 3600
    if hours < 1 then hours = 1 end
    return floor(hours + 0.5)
end

local function RepeatSecondsFromHoursText(text)
    local hours = tonumber(text)
    if not hours or hours <= 0 then
        hours = DEFAULT_REPEAT_HOURS
    end
    return hours * 3600
end

--- Hours field under type/category. Shown only for repeating lists; grows the
--- dialog and shifts the account-wide checkbox down so the row does not overlap.
local function WireRepeatInterval(dialog, content, typeDD, intervalY, accountWideCheck, listType, resetInterval)
    local hoursLabel = MakeLabel(content, L["TRACKER_REPEAT_EVERY"], 10, intervalY)
    local hoursBox = OneWoW_GUI:CreateEditBox(content, {
        width = 56,
        height = 26,
        showClear = false,
        maxLetters = 4,
    })
    hoursBox:SetPoint("LEFT", hoursLabel, "RIGHT", 8, 0)
    hoursBox:SetNumeric(true)
    hoursBox:SetText(tostring(HoursFromInterval(resetInterval)))
    hoursBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    dialog._hoursBox = hoursBox

    local hoursUnit = OneWoW_GUI:CreateFS(content, 10)
    hoursUnit:SetPoint("LEFT", hoursBox, "RIGHT", 8, 0)
    hoursUnit:SetText(L["TRACKER_REPEAT_HOURS"])
    hoursUnit:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local hoursHint = OneWoW_GUI:CreateFS(content, 10)
    hoursHint:SetPoint("TOPLEFT", hoursBox, "BOTTOMLEFT", 0, -2)
    hoursHint:SetText(L["TRACKER_REPEAT_HINT"])
    hoursHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local function applyRepeatRow(isRepeating)
        hoursLabel:SetShown(isRepeating)
        hoursBox:SetShown(isRepeating)
        hoursUnit:SetShown(isRepeating)
        hoursHint:SetShown(isRepeating)
        accountWideCheck:ClearAllPoints()
        if isRepeating then
            accountWideCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, intervalY - 44)
            dialog:SetHeight(LIST_FORM_HEIGHT_REPEAT)
        else
            accountWideCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, intervalY)
            dialog:SetHeight(LIST_FORM_HEIGHT)
        end
    end

    typeDD.onSelect = function(value)
        applyRepeatRow(value == "repeating")
    end
    applyRepeatRow(listType == "repeating")
end

local function OpenRolesAndAltsTab()
    OneWoW.UI:Show("settings")
    OneWoW.UI:SelectSubTab("settings", "rolesandalts")
end

local function PinScopeSummaryText(roles)
    local parts = {}
    for _, role in ipairs(OneWoW.AltScope:GetRolesSorted()) do
        if roles[role.id] then
            tinsert(parts, role.name or role.id)
        end
    end
    if #parts == 0 then
        return L["TRACKER_PIN_SCOPE_PICK"]
    end
    return table.concat(parts, ", ")
end

--- All-characters vs selected-roles pin visibility. Anchors below the
--- account-wide hint so the repeating-hours row can shift that block down.
local function WirePinScope(dialog, content, accountWideHint, existing)
    local scopeRoles = {}
    local modeSelected = false
    if type(existing) == "table" and existing.mode == "selected" then
        modeSelected = true
        if type(existing.roles) == "table" then
            for id, on in pairs(existing.roles) do
                if on then scopeRoles[id] = true end
            end
        end
    end

    local scopeLabel = MakeLabel(content, L["TRACKER_PIN_SCOPE"], 10, 0)
    scopeLabel:ClearAllPoints()
    scopeLabel:SetPoint("TOPLEFT", accountWideHint, "BOTTOMLEFT", -18, -12)

    local allCb = OneWoW_GUI:CreateCheckbox(content, { label = L["TRACKER_PIN_SCOPE_ALL"] })
    allCb:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", -4, -4)

    local rolesCb = OneWoW_GUI:CreateCheckbox(content, { label = L["TRACKER_PIN_SCOPE_ROLES"] })
    rolesCb:SetPoint("LEFT", allCb, "LEFT", (allCb:GetMeasuredWidth() or 140) + 16, 0)

    local roleDD = OneWoW_GUI:CreateDropdown(content, {
        width = 280,
        height = 24,
        text = PinScopeSummaryText(scopeRoles),
    })
    roleDD:SetPoint("TOPLEFT", allCb, "BOTTOMLEFT", 4, -6)

    local linkBtn = OneWoW_GUI:CreateFitTextButton(content, { text = L["TRACKER_PIN_SCOPE_MANAGE"], height = 22 })
    linkBtn:SetPoint("TOPLEFT", roleDD, "BOTTOMLEFT", 0, -6)
    linkBtn:SetScript("OnClick", OpenRolesAndAltsTab)

    local function ScopeTooltip(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["TRACKER_PIN_SCOPE"], 1, 1, 1)
        GameTooltip:AddLine(L["TRACKER_PIN_SCOPE_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end
    local function HideTip()
        GameTooltip:Hide()
    end
    allCb:SetScript("OnEnter", ScopeTooltip)
    allCb:SetScript("OnLeave", HideTip)
    if allCb.label then
        allCb.label:SetScript("OnEnter", ScopeTooltip)
        allCb.label:SetScript("OnLeave", HideTip)
    end
    rolesCb:SetScript("OnEnter", ScopeTooltip)
    rolesCb:SetScript("OnLeave", HideTip)
    if rolesCb.label then
        rolesCb.label:SetScript("OnEnter", ScopeTooltip)
        rolesCb.label:SetScript("OnLeave", HideTip)
    end
    roleDD:HookScript("OnEnter", ScopeTooltip)
    roleDD:HookScript("OnLeave", HideTip)

    local function ApplyMode(selected)
        modeSelected = selected
        allCb:SetChecked(not selected)
        rolesCb:SetChecked(selected)
        if selected then
            roleDD:Enable()
            roleDD._text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        else
            roleDD:Disable()
            roleDD._text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    allCb:SetScript("OnClick", function()
        ApplyMode(false)
    end)
    rolesCb:SetScript("OnClick", function()
        ApplyMode(true)
    end)

    OneWoW_GUI:AttachFilterMenu(roleDD, {
        searchable = false,
        menuHeight = 200,
        buildItems = function()
            local items = {}
            local roles = OneWoW.AltScope:GetRolesSorted()
            if #roles == 0 then
                tinsert(items, { type = "header", text = L["TRACKER_PIN_SCOPE_NONE"] })
                return items
            end
            for _, role in ipairs(roles) do
                local roleId = role.id
                tinsert(items, {
                    type = "checkbox",
                    text = role.name or role.id,
                    checked = scopeRoles[roleId] and true or false,
                    onToggle = function(isOn)
                        scopeRoles[roleId] = isOn and true or nil
                        roleDD._text:SetText(PinScopeSummaryText(scopeRoles))
                    end,
                })
            end
            return items
        end,
    })

    ApplyMode(modeSelected)

    dialog._pinScopeGet = function()
        if not modeSelected then return nil end
        return { mode = "selected", roles = CopyTable(scopeRoles), chars = {} }
    end
end

local QUICK_START = {
    {
        key = "weekly",
        titleKey = "TRACKER_QS_WEEKLY_TITLE",
        descKey = "TRACKER_QS_WEEKLY_DESC",
        icon = "Interface\\Icons\\Achievement_General_100kQuests",
        listType = "weekly",
        category = "General",
        preset = "midnight_weeklies",
    },
    {
        key = "midnight_rares",
        titleKey = "TRACKER_QS_MIDNIGHT_RARES_TITLE",
        descKey = "TRACKER_QS_MIDNIGHT_RARES_DESC",
        icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
        listType = "daily",
        category = "General",
        preset = "midnight_rares",
    },
    {
        key = "daily",
        titleKey = "TRACKER_QS_DAILY_TITLE",
        descKey = "TRACKER_QS_DAILY_DESC",
        icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
        listType = "daily",
        category = "General",
        preset = "daily_tasks",
    },
    {
        key = "todo",
        titleKey = "TRACKER_QS_TODO_TITLE",
        descKey = "TRACKER_QS_TODO_DESC",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        listType = "todo",
        category = "General",
        preset = "todo_template",
    },
    {
        key = "repeating",
        titleKey = "TRACKER_LIST_REPEATING",
        descKey = "TRACKER_QS_REPEATING_DESC",
        icon = "Interface\\Icons\\INV_Misc_PocketWatch_01",
        listType = "repeating",
        category = "General",
        showCustomForm = true,
    },
    {
        key = "farmvalue",
        titleKey = "TRACKER_QS_FARMVALUE_TITLE",
        descKey = "TRACKER_QS_FARMVALUE_DESC",
        icon = "Interface\\Icons\\INV_Misc_Coin_01",
        listType = "farmvalue",
        category = "Farming",
        preset = "farm_value",
    },
    {
        key = "vault",
        titleKey = "TRACKER_QS_VAULT_TITLE",
        descKey = "TRACKER_QS_VAULT_DESC",
        atlas = "greatVault-whole-normal",
        listType = "weekly",
        category = "Gearing",
        preset = "great_vault",
    },
    {
        key = "professions",
        titleKey = "TRACKER_QS_PROF_TITLE",
        descKey = "TRACKER_QS_PROF_DESC",
        icon = "Interface\\Icons\\Trade_BlackSmithing",
        listType = "weekly",
        category = "Profession",
        showProfPicker = true,
    },
    {
        key = "renown",
        titleKey = "TRACKER_QS_RENOWN_TITLE",
        descKey = "TRACKER_QS_RENOWN_DESC",
        icon = "Interface\\Icons\\Achievement_Reputation_08",
        listType = "weekly",
        category = "Reputation",
        preset = "renown_tracking",
    },
    {
        key = "guide",
        titleKey = "TRACKER_QS_GUIDE_TITLE",
        descKey = "TRACKER_QS_GUIDE_DESC",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        listType = "guide",
        category = "General",
        showCustomForm = true,
    },
    {
        key = "blank",
        titleKey = "TRACKER_QS_BLANK_TITLE",
        descKey = "TRACKER_QS_BLANK_DESC",
        icon = "Interface\\Icons\\INV_Scroll_03",
        listType = "todo",
        category = "General",
        showCustomForm = true,
    },
}

-- Presentation-only. Param widgets come from Schema.GetFields(trackType).
-- extra + matchesTypes: one card covers a family (quest scopes, vault slots, professions).
local STEP_CATEGORIES = {
    { key = "checkbox",            titleKey = "TRACKER_SC_CHECKBOX_TITLE",            descKey = "TRACKER_SC_CHECKBOX_DESC",            trackType = "manual" },
    {
        key = "quest",
        titleKey = "TRACKER_SC_QUEST_TITLE",
        descKey = "TRACKER_SC_QUEST_DESC",
        trackType = "quest",
        extra = "quest",
        matchesTypes = QUEST_SCOPE_TYPES,
    },
    { key = "quest_pool",          titleKey = "TRACKER_SC_QUEST_POOL_TITLE",          descKey = "TRACKER_SC_QUEST_POOL_DESC",          trackType = "quest_pool" },
    { key = "quest_pool_account",  titleKey = "TRACKER_SC_QUEST_POOL_ACCOUNT_TITLE",  descKey = "TRACKER_SC_QUEST_POOL_ACCOUNT_DESC",  trackType = "quest_pool_account" },
    { key = "quest_progress",      titleKey = "TRACKER_TYPE_QUEST_PROGRESS",          descKey = "TRACKER_SC_QUEST_PROGRESS_DESC",      trackType = "quest_progress" },
    {
        key = "campaign",
        titleText = L["CAMPAIGN"],
        descKey = "TRACKER_SC_CAMPAIGN_DESC",
        trackType = "campaign",
    },
    { key = "item",                titleKey = "TRACKER_SC_ITEM_TITLE",                descKey = "TRACKER_SC_ITEM_DESC",                trackType = "item" },
    { key = "currency",            titleKey = "TRACKER_SC_CURRENCY_TITLE",            descKey = "TRACKER_SC_CURRENCY_DESC",            trackType = "currency" },
    { key = "achievement",         titleKey = "TRACKER_SC_ACHIEVEMENT_TITLE",         descKey = "TRACKER_SC_ACHIEVEMENT_DESC",         trackType = "achievement" },
    {
        key = "vault",
        titleText = DELVES_GREAT_VAULT_LABEL,
        descKey = "TRACKER_SC_VAULT_DESC",
        trackType = "vault_raid",
        extra = "vault",
        matchesTypes = { "vault_raid", "vault_dungeon", "vault_world" },
    },
    {
        key = "coordinates",
        titleKey = "TRACKER_SC_COORD_TITLE",
        descKey = "TRACKER_SC_COORD_DESC",
        trackType = "coordinates",
        fillKey = "TRACKER_FILL_FROM_POSITION",
        onFill = function(card) FillCoordsFromPosition(card) end,
    },
    {
        key = "location",
        titleKey = "TRACKER_SC_ZONE_TITLE",
        descKey = "TRACKER_SC_ZONE_DESC",
        trackType = "location",
        fillKey = "TRACKER_FILL_FROM_POSITION",
        onFill = function(card) FillMapFromPosition(card) end,
    },
    {
        key = "exploration",
        titleKey = "TRACKER_TYPE_EXPLORATION",
        descKey = "TRACKER_SC_EXPLORATION_DESC",
        trackType = "exploration",
        fillKey = "TRACKER_FILL_FROM_POSITION",
        onFill = function(card) FillAreaFromPosition(card) end,
    },
    {
        key = "npc",
        titleKey = "TRACKER_SC_NPC_TITLE",
        descKey = "TRACKER_SC_NPC_DESC",
        trackType = "npc_interact",
        fillKey = "TRACKER_FILL_FROM_TARGET",
        onFill = function(card) FillCreatureFromTarget(card, "npcID") end,
    },
    {
        key = "enter_instance",
        titleKey = "TRACKER_SC_INSTANCE_TITLE",
        descKey = "TRACKER_SC_INSTANCE_DESC",
        trackType = "enter_instance",
        fillKey = "TRACKER_FILL_FROM_INSTANCE",
        onFill = function(card) FillInstanceFromCurrent(card) end,
    },
    {
        key = "kill_encounter",
        titleKey = "TRACKER_SC_ENCOUNTER_TITLE",
        descKey = "TRACKER_SC_ENCOUNTER_DESC",
        trackType = "kill_encounter",
        fillKey = "TRACKER_FILL_FROM_ENCOUNTER",
        onFill = function(card, nameBox) FillEncounterFromCurrent(card, nameBox) end,
    },
    {
        key = "kill_creature",
        titleKey = "TRACKER_SC_KILL_TITLE",
        descKey = "TRACKER_SC_KILL_DESC",
        trackType = "kill_creature",
        fillKey = "TRACKER_FILL_FROM_TARGET",
        onFill = function(card) FillCreatureFromTarget(card, "creatureID", true) end,
    },
    { key = "loot_item",   titleKey = "TRACKER_TYPE_LOOT_ITEM",    descKey = "TRACKER_SC_LOOT_DESC",     trackType = "loot_item" },
    { key = "mount",       titleKey = "TRACKER_SC_MOUNT_TITLE",    descKey = "TRACKER_SC_MOUNT_DESC",    trackType = "mount" },
    { key = "pet",         titleKey = "TRACKER_SC_PET_TITLE",      descKey = "TRACKER_SC_PET_DESC",      trackType = "pet" },
    { key = "toy",         titleKey = "TRACKER_SC_TOY_TITLE",      descKey = "TRACKER_SC_TOY_DESC",      trackType = "toy" },
    { key = "transmog",    titleKey = "TRACKER_SC_TRANSMOG_TITLE", descKey = "TRACKER_SC_TRANSMOG_DESC", trackType = "transmog" },
    { key = "reputation",  titleKey = "TRACKER_SC_REP_TITLE",      descKey = "TRACKER_SC_REP_DESC",      trackType = "reputation" },
    { key = "renown",      titleKey = "TRACKER_SC_RENOWN_TITLE",   descKey = "TRACKER_SC_RENOWN_DESC",   trackType = "renown" },
    { key = "level",       titleKey = "TRACKER_SC_LEVEL_TITLE",    descKey = "TRACKER_SC_LEVEL_DESC",    trackType = "level" },
    { key = "ilvl",        titleKey = "TRACKER_SC_ILVL_TITLE",     descKey = "TRACKER_SC_ILVL_DESC",     trackType = "ilvl" },
    { key = "spell_known", titleKey = "TRACKER_SC_SPELL_TITLE",    descKey = "TRACKER_SC_SPELL_DESC",    trackType = "spell_known" },
    {
        key = "profession",
        titleText = L["PROFESSION"],
        descKey = "TRACKER_SC_PROF_DESC",
        trackType = "prof_skill",
        extra = "profession",
        matchesTypes = { "prof_skill", "prof_concentration", "prof_knowledge", "prof_firstcraft", "prof_catchup" },
    },
    {
        key = "custom_timer",
        titleKey = "TRACKER_TYPE_CUSTOM_TIMER",
        descKey = "TRACKER_SC_TIMER_DESC",
        trackType = "custom_timer",
        extra = "timer",
    },
}

local function HasTypeCard(trackType)
    for _, cat in ipairs(STEP_CATEGORIES) do
        if CategoryMatches(cat, trackType) then return true end
    end
    return false
end

local WIZARD_CARD_H = 60
local WIZARD_CARD_PAD = 12
local WIZARD_CARD_ICON = 36

--- Icon + title + wrapped description card used by the new-list wizard.
--- One click action per card; hover chrome comes from CreateListRowBasic.
local function CreateWizardCard(parent, opts)
    local card = OneWoW_GUI:CreateListRowBasic(parent, {
        height = WIZARD_CARD_H,
        label = opts.title,
        onClick = opts.onClick,
    })

    local icon = card:CreateTexture(nil, "ARTWORK")
    icon:SetSize(WIZARD_CARD_ICON, WIZARD_CARD_ICON)
    icon:SetPoint("LEFT", card, "LEFT", WIZARD_CARD_PAD, 0)
    -- atlas takes precedence over a texture path; both stretch to the icon slot.
    if opts.atlas then
        icon:SetAtlas(opts.atlas)
    else
        icon:SetTexture(opts.icon)
    end

    card.label:ClearAllPoints()
    card.label:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -4)
    card.label:SetPoint("RIGHT", card, "RIGHT", -WIZARD_CARD_PAD, 0)
    card.label:SetJustifyH("LEFT")
    card.label:SetWordWrap(false)

    local desc = OneWoW_GUI:CreateFS(card, 10)
    desc:SetPoint("TOPLEFT", card.label, "BOTTOMLEFT", 0, -2)
    desc:SetPoint("RIGHT", card, "RIGHT", -WIZARD_CARD_PAD, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(opts.desc)
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    return card
end

function TE_UI:ShowNewListDialog(callback)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    if not TD or not TE then return end

    local dialog = CreateDialog({
        name = "TrackerNewListWizard",
        title = L["TRACKER_NEW_LIST"],
        width = 700,
        height = 600,
        destroyOnClose = true,
        buttons = {
            { text = CANCEL, onClick = function(frame) frame:Hide(); frame:SetParent(nil) end },
        },
    })
    if not dialog then return end
    local content = dialog.content

    local headerLabel = OneWoW_GUI:CreateFS(content, 12)
    headerLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    headerLabel:SetText(L["TRACKER_WIZARD_HEADER"])
    headerLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local descLabel = OneWoW_GUI:CreateFS(content, 10)
    descLabel:SetPoint("TOPLEFT", headerLabel, "BOTTOMLEFT", 0, -4)
    descLabel:SetText(L["TRACKER_WIZARD_DESC"])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(content, {})
    scrollFrame:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -6, 4)

    local yOfs = 0
    local CARD_GAP = 4

    for _, qs in ipairs(QUICK_START) do
        local card = CreateWizardCard(scrollChild, {
            title = L[qs.titleKey],
            desc = L[qs.descKey],
            icon = qs.icon,
            atlas = qs.atlas,
            onClick = function()
                if qs.showProfPicker then
                    dialog:Hide(); dialog:SetParent(nil)
                    TE_UI:ShowProfessionPicker(callback)
                elseif qs.showCustomForm then
                    dialog:Hide(); dialog:SetParent(nil)
                    TE_UI:ShowCustomListForm(qs.listType, qs.category, callback)
                elseif qs.preset and TP then
                    local list = TP:CreateListFromPreset(qs.preset)
                    if list then
                        dialog:Hide(); dialog:SetParent(nil)
                        if callback then callback(list) end
                    end
                else
                    local list = TD:CreateList({
                        title = L[qs.titleKey],
                        listType = qs.listType,
                        category = qs.category,
                    })
                    TD:AddSection(list.id, { label = L["TRACKER_DEFAULT_SECTION"] })
                    dialog:Hide(); dialog:SetParent(nil)
                    if callback then callback(list) end
                end
            end,
        })
        card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOfs)
        card:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOfs)

        yOfs = yOfs - WIZARD_CARD_H - CARD_GAP
    end

    yOfs = yOfs - 12
    local importCard = CreateWizardCard(scrollChild, {
        title = L["TRACKER_QS_IMPORT_TITLE"],
        desc = L["TRACKER_QS_IMPORT_DESC"],
        icon = "Interface\\Icons\\INV_Letter_15",
        onClick = function()
            dialog:Hide(); dialog:SetParent(nil)
            TE_UI:ShowImportDialog(callback)
        end,
    })
    importCard:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOfs)
    importCard:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOfs)

    yOfs = yOfs - WIZARD_CARD_H - CARD_GAP
    scrollChild:SetHeight(math.abs(yOfs) + 20)

    dialog:Show()
end

function TE_UI:ShowCustomListForm(defaultType, defaultCategory, callback)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    if not TD or not TE then return end

    local dialog = CreateDialog({
        name = "TrackerCustomListForm",
        title = L["TRACKER_CUSTOM_LIST_TITLE"],
        width = 480,
        height = LIST_FORM_HEIGHT,
        destroyOnClose = true,
        buttons = {
            {
                text = L["TRACKER_CREATE"],
                onClick = function(frame)
                    local title = strtrim(frame._titleBox:GetText() or "")
                    if title == "" then title = L["TRACKER_TITLE_PLACEHOLDER"] end
                    local listType = frame._typeDD:GetValue() or defaultType or "todo"
                    local opts = {
                        title = title,
                        description = strtrim(frame._descBox:GetText() or ""),
                        listType = listType,
                        category = frame._catDD:GetValue() or defaultCategory or "General",
                        accountWide = frame._accountWideCheck:GetChecked(),
                        pinScope = frame._pinScopeGet(),
                    }
                    if listType == "repeating" then
                        opts.resetInterval = RepeatSecondsFromHoursText(frame._hoursBox:GetText())
                    end
                    local list = TD:CreateList(opts)
                    TD:AddSection(list.id, { label = L["TRACKER_DEFAULT_SECTION"] })
                    frame:Hide(); frame:SetParent(nil)
                    if callback then callback(list) end
                end,
            },
            {
                text = CANCEL,
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content
    local yOfs = -10

    MakeLabel(content, L["TRACKER_TITLE_LABEL"], 10, yOfs)
    yOfs = yOfs - 16
    local titleBox = OneWoW_GUI:CreateEditBox(content, { width = 440, height = 26, placeholderText = L["TRACKER_TITLE_PLACEHOLDER"] })
    titleBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    dialog._titleBox = titleBox
    yOfs = yOfs - 36

    MakeLabel(content, L["TRACKER_DESCRIPTION_OPTIONAL"], 10, yOfs)
    yOfs = yOfs - 16
    local descContainer = OneWoW_GUI:CreateFrame(content, { width = 1, height = 1, backdrop = BACKDROP_SOFT })
    descContainer:ClearAllPoints()
    descContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    descContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOfs)
    descContainer:SetHeight(50)
    local descScroll, descBox = OneWoW_GUI:CreateScrollEditBox(descContainer, { name = "TrackerCustomDesc", maxLetters = 1000 })
    descScroll:SetAllPoints(descContainer)
    dialog._descBox = descBox
    yOfs = yOfs - 60

    local typeLabel = MakeLabel(content, L["TRACKER_LIST_TYPE_LABEL"], 10, yOfs)
    local typeDD = CreateDropdown(content, 180, 26)
    typeDD:SetPoint("LEFT", typeLabel, "RIGHT", 8, 0)
    local typeOpts = {}
    for _, lt in ipairs(TD:GetListTypes()) do
        tinsert(typeOpts, { text = TE:GetListTypeDisplayName(lt), value = lt })
    end
    typeDD:SetOptions(typeOpts)
    typeDD:SetSelected(defaultType or "todo")
    dialog._typeDD = typeDD
    yOfs = yOfs - 36

    local catLabel = MakeLabel(content, L["TRACKER_CATEGORY_LABEL"], 10, yOfs)
    local catDD = CreateDropdown(content, 180, 26)
    catDD:SetPoint("LEFT", catLabel, "RIGHT", 8, 0)
    catDD:SetOptions(TD:GetCategoryOptions())
    catDD:SetSelected(defaultCategory or "General")
    dialog._catDD = catDD
    yOfs = yOfs - 36
    local intervalY = yOfs

    local accountWideCheck = OneWoW_GUI:CreateCheckbox(content, { label = L["TRACKER_ACCOUNT_WIDE"] })
    accountWideCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    dialog._accountWideCheck = accountWideCheck

    local accountWideHint = OneWoW_GUI:CreateFS(content, 10)
    accountWideHint:SetPoint("TOPLEFT", accountWideCheck, "BOTTOMLEFT", 18, -2)
    accountWideHint:SetText(L["TRACKER_ACCOUNT_WIDE_HINT"])
    accountWideHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    WireRepeatInterval(dialog, content, typeDD, intervalY, accountWideCheck, defaultType or "todo", nil)
    WirePinScope(dialog, content, accountWideHint, nil)

    dialog:Show()
end

function TE_UI:ShowProfessionPicker(callback)
    local dialog = CreateDialog({
        name = "TrackerProfPicker",
        title = L["TRACKER_PROF_PICKER_TITLE"],
        width = 400,
        height = 460,
        destroyOnClose = true,
        buttons = {
            {
                text = L["TRACKER_CREATE"],
                onClick = function(frame)
                    local profList = {}
                    for name in pairs(frame._selectedProfs or {}) do
                        tinsert(profList, name)
                    end
                    if #profList == 0 then return end
                    sort(profList)
                    local list = TP:CreateProfessionList(profList)
                    if list then
                        frame:Hide(); frame:SetParent(nil)
                        if callback then callback(list) end
                    end
                end,
            },
            {
                text = CANCEL,
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content
    dialog._selectedProfs = {}

    local hintLabel = OneWoW_GUI:CreateFS(content, 10)
    hintLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    hintLabel:SetText(L["TRACKER_PROF_PICKER_HINT"])
    hintLabel:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    hintLabel:SetJustifyH("LEFT")
    hintLabel:SetWordWrap(true)
    hintLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local yOfs = -46
    local profPresets = TP:GetProfessionPresets()

    for _, prof in ipairs(profPresets) do
        local check = OneWoW_GUI:CreateCheckbox(content, { label = prof.name })
        check:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
        check:SetScript("OnClick", function(myself)
            if myself:GetChecked() then
                dialog._selectedProfs[prof.name] = true
            else
                dialog._selectedProfs[prof.name] = nil
            end
        end)
        yOfs = yOfs - 28
    end

    dialog:Show()
end

function TE_UI:ShowListEditor(listID, callback)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    if not TD or not TE then return end

    local list = TD:GetList(listID)
    if not list then return end

    local dialog = CreateDialog({
        name = "TrackerEditListDialog",
        title = L["TRACKER_EDIT_LIST"],
        width = 480,
        height = LIST_FORM_HEIGHT,
        destroyOnClose = true,
        buttons = {
            {
                text = SAVE,
                onClick = function(frame)
                    local listType = frame._typeDD:GetValue() or "todo"
                    local changes = {
                        title = strtrim(frame._titleBox:GetText() or L["TRACKER_UNTITLED"]),
                        description = strtrim(frame._descBox:GetText() or ""),
                        listType = listType,
                        category = frame._catDD:GetValue() or "General",
                        accountWide = frame._accountWideCheck:GetChecked(),
                    }
                    if listType == "repeating" then
                        changes.resetInterval = RepeatSecondsFromHoursText(frame._hoursBox:GetText())
                    end
                    TD:UpdateList(listID, changes)
                    local edited = TD:GetList(listID)
                    edited.pinScope = TD:NormalizePinScope(frame._pinScopeGet())
                    TE:SyncAllPinnedOverlays()
                    frame:Hide(); frame:SetParent(nil)
                    if callback then callback() end
                end,
            },
            {
                text = CANCEL,
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content
    local yOfs = -10

    MakeLabel(content, L["TRACKER_TITLE_LABEL"], 10, yOfs)
    yOfs = yOfs - 16
    local titleBox = OneWoW_GUI:CreateEditBox(content, { width = 440, height = 26 })
    titleBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    titleBox:SetText(list.title or "")
    dialog._titleBox = titleBox
    yOfs = yOfs - 36

    MakeLabel(content, L["TRACKER_DESCRIPTION_LABEL"], 10, yOfs)
    yOfs = yOfs - 16
    local descContainer = OneWoW_GUI:CreateFrame(content, { width = 1, height = 1, backdrop = BACKDROP_SOFT })
    descContainer:ClearAllPoints()
    descContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    descContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOfs)
    descContainer:SetHeight(50)
    local descScroll, descBox = OneWoW_GUI:CreateScrollEditBox(descContainer, { name = "TrackerEditDesc", maxLetters = 1000 })
    descScroll:SetAllPoints(descContainer)
    descBox:SetText(list.description or "")
    dialog._descBox = descBox
    yOfs = yOfs - 60

    local typeLabel = MakeLabel(content, L["TRACKER_LIST_TYPE_LABEL"], 10, yOfs)
    local typeDD = CreateDropdown(content, 180, 26)
    typeDD:SetPoint("LEFT", typeLabel, "RIGHT", 8, 0)
    local typeOpts = {}
    for _, lt in ipairs(TD:GetListTypes()) do
        tinsert(typeOpts, { text = TE:GetListTypeDisplayName(lt), value = lt })
    end
    typeDD:SetOptions(typeOpts)
    typeDD:SetSelected(list.listType or "todo")
    dialog._typeDD = typeDD
    yOfs = yOfs - 36

    local catLabel = MakeLabel(content, L["TRACKER_CATEGORY_LABEL"], 10, yOfs)
    local catDD = CreateDropdown(content, 180, 26)
    catDD:SetPoint("LEFT", catLabel, "RIGHT", 8, 0)
    catDD:SetOptions(TD:GetCategoryOptions())
    catDD:SetSelected(list.category or "General")
    dialog._catDD = catDD
    yOfs = yOfs - 36
    local intervalY = yOfs

    local accountWideCheck = OneWoW_GUI:CreateCheckbox(content, { label = L["TRACKER_ACCOUNT_WIDE"] })
    accountWideCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    accountWideCheck:SetChecked(list.accountWide or false)
    dialog._accountWideCheck = accountWideCheck

    local accountWideHint = OneWoW_GUI:CreateFS(content, 10)
    accountWideHint:SetPoint("TOPLEFT", accountWideCheck, "BOTTOMLEFT", 18, -2)
    accountWideHint:SetText(L["TRACKER_ACCOUNT_WIDE_HINT"])
    accountWideHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    WireRepeatInterval(dialog, content, typeDD, intervalY, accountWideCheck, list.listType or "todo", list.resetInterval)
    WirePinScope(dialog, content, accountWideHint, list.pinScope)

    dialog:Show()
end

function TE_UI:ShowSectionEditor(listID, sectionKey, callback)
    local TD = ns.TrackerData
    if not TD then return end

    local existing = sectionKey and TD:GetSection(listID, sectionKey) or nil
    local isEdit = existing ~= nil

    local dialog = CreateDialog({
        name = "TrackerSectionDialog",
        title = isEdit and L["TRACKER_EDIT_SECTION"] or L["TRACKER_ADD_SECTION"],
        width = 480,
        height = 380,
        destroyOnClose = true,
        buttons = {
            {
                text = SAVE,
                onClick = function(frame)
                    local name = strtrim(frame._nameBox:GetText() or "")
                    if name == "" then name = L["TRACKER_SECTION_FALLBACK"] end
                    local resetVal = frame._resetDD:GetValue()
                    local resetOverride = (resetVal and resetVal ~= "none") and resetVal or false
                    local faction, professionRequired, eventRequired = ReadVisibilityGates(frame)

                    if isEdit then
                        TD:UpdateSection(listID, sectionKey, {
                            label = name,
                            resetOverride = resetOverride,
                            faction = faction,
                            professionRequired = professionRequired,
                            eventRequired = eventRequired,
                        })
                    else
                        TD:AddSection(listID, {
                            label = name,
                            resetOverride = resetOverride,
                            faction = faction,
                            professionRequired = professionRequired,
                            eventRequired = eventRequired,
                        })
                    end
                    frame:Hide(); frame:SetParent(nil)
                    if callback then callback() end
                end,
            },
            {
                text = CANCEL,
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content
    local yOfs = -10

    MakeLabel(content, L["TRACKER_SECTION_NAME"], 10, yOfs)
    yOfs = yOfs - 16
    local nameBox = OneWoW_GUI:CreateEditBox(content, { width = 440, height = 26, placeholderText = L["TRACKER_SECTION_NAME_PLACEHOLDER"] })
    nameBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    if existing then nameBox:SetText(existing.label or "") end
    dialog._nameBox = nameBox
    yOfs = yOfs - 36

    MakeLabel(content, L["TRACKER_RESET_LABEL"], 10, yOfs)
    local resetDD = CreateDropdown(content, 220, 26)
    resetDD:SetPoint("TOPLEFT", content, "TOPLEFT", 60, yOfs)
    resetDD:SetOptions({
        { text = L["TRACKER_RESET_DEFAULT"], value = "none" },
        { text = L["TRACKER_RESET_DAILY"], value = "daily" },
        { text = L["TRACKER_RESET_WEEKLY"], value = "weekly" },
        { text = L["TRACKER_RESET_NEVER"], value = "todo" },
    })
    resetDD:SetSelected(existing and existing.resetOverride or "none")
    dialog._resetDD = resetDD

    WireVisibilityGates(dialog, content, existing, { anchor = resetDD, dx = -50 })

    dialog:Show()
end

function TE_UI:ShowStepEditor(listID, sectionKey, stepKey, callback)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    if not TD or not TE then return end

    local existing = stepKey and TD:GetStep(listID, sectionKey, stepKey) or nil
    local isEdit = existing ~= nil

    local stackRelayout = {}
    local dialog = CreateDialog({
        name = "TrackerStepWizard",
        title = isEdit and L["TRACKER_EDIT_STEP"] or L["TRACKER_ADD_STEP"],
        width = 650,
        height = STEP_EDITOR_HEIGHT,
        showScrollFrame = true,
        relayout = function()
            if stackRelayout.fn then stackRelayout.fn() end
        end,
        destroyOnClose = true,
        buttons = {
            {
                text = SAVE,
                onClick = function(frame)
                    -- Route through the selected category card so its track type
                    -- and fields are saved, not a blank checkbox.
                    if frame._activeCard and frame._activeCard._doSave then
                        frame._activeCard._doSave()
                        return
                    end
                    local stepName = strtrim(frame._nameBox:GetText() or "")
                    if stepName == "" then stepName = existing and existing.label or L["TRACKER_NEW_STEP"] end
                    local changes = { label = stepName }
                    if isEdit then
                        changes.trackType = existing.trackType
                        changes.trackParams = existing.trackParams
                    else
                        changes.trackType = "manual"
                        changes.trackParams = {}
                    end
                    ApplySharedStepFields(frame, changes)
                    CommitStep(frame, listID, sectionKey, stepKey, isEdit, changes, callback)
                end,
            },
            { text = CANCEL, onClick = function(frame) frame:Hide(); frame:SetParent(nil) end },
        },
    })
    if not dialog then return end
    local host = dialog.content
    local wrapW = 560

    local stack = OneWoW_GUI:CreateCardStack(host, {
        getCollapsed = function(key) return IsStepCardCollapsed(key, existing) end,
        setCollapsed = function(key, collapsed) stepEditorCollapsed[key] = collapsed end,
        marginX = 4,
        startY = -4,
        gap = 8,
    })
    dialog._stepStack = stack
    stack.OnRelayout = function()
        local h = host:GetHeight() or 1
        host:SetHeight(h + 20)
    end
    stackRelayout.fn = function() stack:Relayout() end

    local hero = CreateFrame("Frame", nil, host)
    hero:SetHeight(260)
    stack:AddFrame(hero)

    local nameLabel = OneWoW_GUI:CreateFS(hero, 10)
    nameLabel:SetPoint("TOPLEFT", hero, "TOPLEFT", 0, -2)
    nameLabel:SetText(L["TRACKER_STEP_LABEL"])
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local nameBox = OneWoW_GUI:CreateEditBox(hero, { height = 26, placeholderText = L["TRACKER_STEP_NAME_PLACEHOLDER"] })
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -2)
    nameBox:SetPoint("RIGHT", hero, "RIGHT", 0, 0)
    if existing then nameBox:SetText(existing.label or "") end
    dialog._nameBox = nameBox

    local trackCheck = OneWoW_GUI:CreateCheckbox(hero, { label = L["TRACKER_TRACK_AS_TASK"] })
    trackCheck:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -8)
    trackCheck:SetChecked(not existing or not existing.optional)
    dialog._trackCheck = trackCheck

    local trackHint = OneWoW_GUI:CreateFS(hero, 10)
    trackHint:SetPoint("TOPLEFT", trackCheck, "BOTTOMLEFT", 18, -2)
    trackHint:SetText(L["TRACKER_TRACK_HINT"])
    trackHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local rosterCheck = OneWoW_GUI:CreateCheckbox(hero, { label = L["TRACKER_ROSTER_MODE"] })
    rosterCheck:SetPoint("TOPLEFT", trackHint, "BOTTOMLEFT", -18, -8)
    rosterCheck:SetChecked(existing and existing.rosterMode or false)
    dialog._rosterCheck = rosterCheck

    local rosterHint = OneWoW_GUI:CreateFS(hero, 10)
    rosterHint:SetPoint("TOPLEFT", rosterCheck, "BOTTOMLEFT", 18, -2)
    rosterHint:SetPoint("RIGHT", hero, "RIGHT", 0, 0)
    rosterHint:SetJustifyH("LEFT")
    rosterHint:SetWordWrap(true)
    rosterHint:SetText(L["TRACKER_ROSTER_HINT"])
    rosterHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local resetLabel = OneWoW_GUI:CreateFS(hero, 10)
    resetLabel:SetPoint("TOPLEFT", rosterHint, "BOTTOMLEFT", -18, -8)
    resetLabel:SetText(L["TRACKER_RESET_LABEL"])
    resetLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local resetDD = CreateDropdown(hero, 220, 26)
    resetDD:SetPoint("LEFT", resetLabel, "RIGHT", 8, 0)
    resetDD:SetOptions({
        { text = L["TRACKER_RESET_DEFAULT"], value = "none" },
        { text = L["TRACKER_RESET_DAILY"], value = "daily" },
        { text = L["TRACKER_RESET_WEEKLY"], value = "weekly" },
        { text = L["TRACKER_RESET_NEVER"], value = "todo" },
    })
    resetDD:SetSelected(existing and existing.resetOverride or "none")
    dialog._resetDD = resetDD

    local maxLabel = OneWoW_GUI:CreateFS(hero, 10)
    maxLabel:SetPoint("TOPLEFT", resetLabel, "TOPLEFT", 0, -36)
    maxLabel:SetText(L["TRACKER_MAX_COUNT"])
    maxLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local maxBox = OneWoW_GUI:CreateEditBox(hero, {
        width = 70,
        height = 26,
        maxLetters = 6,
    })
    maxBox:SetPoint("LEFT", maxLabel, "RIGHT", 8, 0)
    maxBox:SetNumeric(true)
    dialog._maxBox = maxBox

    local noMaxCheck = OneWoW_GUI:CreateCheckbox(hero, {
        label = L["TRACKER_NO_MAX"],
        onClick = function(myself)
            if myself:GetChecked() then
                maxBox:Disable()
            else
                maxBox:Enable()
            end
        end,
    })
    noMaxCheck:SetPoint("LEFT", maxBox, "RIGHT", 16, 0)
    dialog._noMaxCheck = noMaxCheck

    local maxHint = OneWoW_GUI:CreateFS(hero, 10)
    maxHint:SetPoint("TOP", maxBox, "BOTTOM", 0, -4)
    maxHint:SetPoint("LEFT", maxLabel, "LEFT", 0, 0)
    maxHint:SetPoint("RIGHT", hero, "RIGHT", 0, 0)
    maxHint:SetJustifyH("LEFT")
    maxHint:SetWordWrap(true)
    maxHint:SetText(L["TRACKER_NO_MAX_HINT"])
    maxHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    if existing and existing.noMax then
        noMaxCheck:SetChecked(true)
        maxBox:Disable()
    elseif existing and existing.max then
        maxBox:SetText(tostring(existing.max))
    end

    local rosterH = HintHeight(rosterHint, wrapW)
    local maxHintH = HintHeight(maxHint, wrapW)
    hero:SetHeight(6 + 14 + 2 + 26 + 8 + 22 + 2 + 14 + 8 + 22 + 2 + rosterH + 8 + 26 + 10 + 26 + 4 + maxHintH)

    local cardOpts = { rightInset = 0 }
    local gatesCard = MakeEditorCard(stack, host, "gates", L["TRACKER_CARD_VISIBILITY"], existing)
    local gateBottom = WireVisibilityGates(dialog, gatesCard.content, existing, cardOpts)
    local reqBottom = WireRequiresPicker(dialog, gatesCard.content, gateBottom, listID, existing and existing.key, existing, cardOpts)
    local gateHintH = HintHeight(gateBottom, wrapW)
    local reqHintH = HintHeight(reqBottom, wrapW)
    gatesCard:SetContentHeight(94 + gateHintH + 52 + reqHintH)

    local notesCard = MakeEditorCard(stack, host, "notes", L["TRACKER_CARD_NOTES"], existing)
    local ncontent = notesCard.content
    local notesLabel = OneWoW_GUI:CreateFS(ncontent, 10)
    notesLabel:SetPoint("TOPLEFT", ncontent, "TOPLEFT", 0, 0)
    notesLabel:SetText(L["TRACKER_NOTES_LABEL"])
    notesLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local notesContainer = OneWoW_GUI:CreateFrame(ncontent, { backdrop = BACKDROP_SOFT })
    notesContainer:ClearAllPoints()
    notesContainer:SetPoint("TOPLEFT", notesLabel, "BOTTOMLEFT", 0, -2)
    notesContainer:SetPoint("RIGHT", ncontent, "RIGHT", 0, 0)
    notesContainer:SetHeight(50)
    local notesScroll, notesBox = OneWoW_GUI:CreateScrollEditBox(notesContainer, { name = "TrackerStepNotes", maxLetters = 500 })
    notesScroll:SetAllPoints(notesContainer)
    if existing and existing.userNote and existing.userNote ~= "" then notesBox:SetText(existing.userNote) end
    dialog._notesBox = notesBox

    local descLabel = OneWoW_GUI:CreateFS(ncontent, 10)
    descLabel:SetPoint("TOPLEFT", notesContainer, "BOTTOMLEFT", 0, -8)
    descLabel:SetText(L["TRACKER_STEP_DESC"])
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local descContainer = OneWoW_GUI:CreateFrame(ncontent, { backdrop = BACKDROP_SOFT })
    descContainer:ClearAllPoints()
    descContainer:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -2)
    descContainer:SetPoint("RIGHT", ncontent, "RIGHT", 0, 0)
    descContainer:SetHeight(50)
    local descScroll, descBox = OneWoW_GUI:CreateScrollEditBox(descContainer, { name = "TrackerStepDesc", maxLetters = 500 })
    descScroll:SetAllPoints(descContainer)
    if existing and existing.description and existing.description ~= "" then descBox:SetText(existing.description) end
    dialog._descBox = descBox
    notesCard:SetContentHeight(14 + 2 + 50 + 8 + 14 + 2 + 50)

    local wpCard = MakeEditorCard(stack, host, "waypoint", L["TRACKER_CARD_WAYPOINT"], existing)
    local wcontent = wpCard.content
    local wpMapField = {
        key = "mapID",
        labelKey = "TRACKER_FL_MAP_ID",
        hintKey = "TRACKER_FH_MAP_ID",
        width = 100,
        widgetType = "entityId",
        entityKind = "map",
    }
    local wpMap = CreateFieldWidget(wcontent, wpMapField, existing and existing.mapID, false)
    wpMap:SetPoint("TOPLEFT", wcontent, "TOPLEFT", 0, 0)
    dialog._wpMap = wpMap

    local wpX = OneWoW_GUI:CreateEditBox(wcontent, {
        width = 60, height = 22, placeholderText = L["TRACKER_FH_XY"], maxLetters = 6, showClear = false,
    })
    wpX:SetPoint("TOPLEFT", wpMap, "TOPRIGHT", 20, 0)
    dialog._wpX = wpX

    local wpY = OneWoW_GUI:CreateEditBox(wcontent, {
        width = 60, height = 22, placeholderText = L["TRACKER_FH_XY"], maxLetters = 6, showClear = false,
    })
    wpY:SetPoint("TOPLEFT", wpX, "TOPRIGHT", 8, 0)
    dialog._wpY = wpY

    local wpRadius = OneWoW_GUI:CreateEditBox(wcontent, {
        width = 50, height = 22, placeholderText = L["TRACKER_FL_RANGE"], maxLetters = 4, showClear = false,
    })
    wpRadius:SetPoint("TOPLEFT", wpY, "TOPRIGHT", 8, 0)
    dialog._wpRadius = wpRadius

    if existing then
        if existing.coordX then
            wpX:SetText(tostring(existing.coordX))
            wpX:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        if existing.coordY then
            wpY:SetText(tostring(existing.coordY))
            wpY:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
        if existing.waypointRadius and existing.waypointRadius ~= 15 then
            wpRadius:SetText(tostring(existing.waypointRadius))
            wpRadius:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    local wpFill = OneWoW_GUI:CreateFitTextButton(wcontent, { text = L["TRACKER_FILL_FROM_POSITION"], height = 22 })
    wpFill:SetPoint("LEFT", wpRadius, "RIGHT", 8, 0)
    wpFill:SetScript("OnClick", function() FillSharedWaypoint(dialog) end)
    wpCard:SetContentHeight(wpMap:GetHeight() or 40)

    local objCard = MakeEditorCard(stack, host, "objectives", OBJECTIVES_LABEL, existing)
    dialog._objCard = objCard
    local objH = WireObjectivesEditor(dialog, objCard.content, existing)
    objCard:SetContentHeight(objH)

    local trackingCard = MakeEditorCard(stack, host, "tracking", L["TRACKER_STEP_TRACK_HEADER"], existing)
    local tcontent = trackingCard.content
    local typeListTop = 0
    if existing and not HasTypeCard(existing.trackType) then
        local trackedFS = OneWoW_GUI:CreateFS(tcontent, 10)
        trackedFS:SetPoint("TOPLEFT", tcontent, "TOPLEFT", 0, 0)
        trackedFS:SetPoint("RIGHT", tcontent, "RIGHT", 0, 0)
        trackedFS:SetJustifyH("LEFT")
        trackedFS:SetText(format(L["TRACKER_TRACKED_AS"], TE:GetTrackTypeDisplayName(existing.trackType)))
        trackedFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
        typeListTop = -20
    end

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(tcontent, {})
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", tcontent, "TOPLEFT", 0, typeListTop)
    scrollFrame:SetPoint("TOPRIGHT", tcontent, "TOPRIGHT", 0, typeListTop)
    scrollFrame:SetHeight(TYPE_LIST_H)
    trackingCard:SetContentHeight((-typeListTop) + TYPE_LIST_H)

    local allCards = {}
    local CARD_GAP = 3

    local function ReflowCards()
        local y = 0
        for _, c in ipairs(allCards) do
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
            c:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, y)
            y = y - c:GetHeight() - CARD_GAP
        end
        scrollChild:SetHeight(math.max(1, math.abs(y) + 20))
    end

    local function CollapseAllExcept(keepCard)
        for _, c in ipairs(allCards) do
            if c ~= keepCard and c._expanded and c._cat and CardHasEditor(c._cat, Schema.GetFields(c._cat.trackType)) then
                c._expanded = false
                if c._fieldRow then c._fieldRow:Hide() end
                if c._saveFieldBtn then c._saveFieldBtn:Hide() end
                if c._fillBtn then c._fillBtn:Hide() end
                if c._titleBtn then c._titleBtn:Hide() end
                if c._rarePane then c._rarePane:Hide() end
                local baseH = CardHeaderHeight(c._descHeight)
                c:SetHeight(baseH)
                c:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                c:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                if c._titleFS then c._titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
            end
        end
    end

    for _, cat in ipairs(STEP_CATEGORIES) do
        local isActive = existing and CategoryMatches(cat, existing.trackType)
        local fields = Schema.GetFields(cat.trackType)
        if cat.extra == "profession" or cat.extra == "vault" then
            fields = {}
        end

        local card = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        card:SetBackdrop(BACKDROP_SIMPLE)

        if isActive then
            card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end

        local titleFS = OneWoW_GUI:CreateFS(card, 12)
        titleFS:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -6)
        titleFS:SetText(cat.titleText or L[cat.titleKey])
        if isActive then
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local descFS = OneWoW_GUI:CreateFS(card, 10)
        descFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -2)
        descFS:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        descFS:SetJustifyH("LEFT")
        descFS:SetWordWrap(true)
        local descKey = cat.descKey
        if IsDungeonOrRaid() then
            if cat.trackType == "kill_creature" then
                descKey = "TRACKER_SC_KILL_INSTANCE_NOTE"
            elseif cat.trackType == "npc_interact" then
                descKey = "TRACKER_SC_NPC_INSTANCE_NOTE"
            end
        end
        descFS:SetText(L[descKey])
        descFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local descHeight = HintHeight(descFS, TYPE_CARD_DESC_WRAP)
        local cardHeight = CardHeaderHeight(descHeight)

        card._cat = cat
        card._descHeight = descHeight
        card._titleFS = titleFS
        card._nameBox = nameBox
        card._wpMap = dialog._wpMap
        card._wpX = dialog._wpX
        card._wpY = dialog._wpY
        card._reflow = ReflowCards

        if CardHasEditor(cat, fields) then
            local fieldY = -(cardHeight)
            local fieldRow = CreateFrame("Frame", nil, card)
            fieldRow:SetPoint("TOPLEFT", card, "TOPLEFT", 10, fieldY)
            fieldRow:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, fieldY)
            fieldRow:SetHeight(FIELD_ROW_H)
            card._fieldRow = fieldRow

            local saveFieldBtn = OneWoW_GUI:CreateFitTextButton(card, { text = isEdit and SAVE or L["TRACKER_ADD_STEP"], height = 22 })
            card._saveFieldBtn = saveFieldBtn

            local layout = { fx = 0, fy = 0, rowH = FIELD_ROW_H }
            local isNew = not existing
            if cat.extra ~= "timer" then
                for _, field in ipairs(fields) do
                    local existingVal
                    if existing and existing.trackParams and CategoryMatches(cat, existing.trackType) then
                        existingVal = existing.trackParams[field.key]
                    end
                    local widget = CreateFieldWidget(fieldRow, field, existingVal, isNew)
                    widget._fieldKey = field.key
                    card["_field_" .. field.key] = widget
                    PlaceFieldSlot(layout, fieldRow, field, widget)
                end
            end
            AttachCardExtra(card, cat, fieldRow, layout, existing, isNew)
            fieldRow:SetHeight(FieldLayoutHeight(layout))

            local rarePane = card._rarePane
            if rarePane then
                rarePane:SetPoint("TOPLEFT", fieldRow, "BOTTOMLEFT", 0, 0)
                rarePane:SetPoint("TOPRIGHT", fieldRow, "BOTTOMRIGHT", 0, 0)
                saveFieldBtn:SetPoint("TOPLEFT", rarePane, "BOTTOMLEFT", 0, -4)
            else
                saveFieldBtn:SetPoint("TOPLEFT", fieldRow, "BOTTOMLEFT", 0, -4)
            end
            local expandedHeight = cardHeight + fieldRow:GetHeight() + SAVE_ROW_H
            card._expandedHeight = expandedHeight

            local fillBtn
            if cat.onFill then
                fillBtn = OneWoW_GUI:CreateFitTextButton(card, { text = L[cat.fillKey], height = 22 })
                fillBtn:SetPoint("LEFT", saveFieldBtn, "RIGHT", 8, 0)
                fillBtn:SetScript("OnClick", function()
                    cat.onFill(card, nameBox)
                    if cat.trackType == "coordinates" then
                        FillSharedWaypoint(dialog)
                    end
                end)
                card._fillBtn = fillBtn
            elseif cat.extra == "quest" then
                fillBtn = OneWoW_GUI:CreateFitTextButton(card, { text = L["TRACKER_FILL_FROM_TARGET"], height = 22 })
                fillBtn:SetPoint("LEFT", saveFieldBtn, "RIGHT", 8, 0)
                fillBtn:SetScript("OnClick", function() FillRareFromTarget(card) end)
                card._fillBtn = fillBtn
            end

            local titleBtn
            if cat.trackType == "npc_interact" then
                titleBtn = OneWoW_GUI:CreateFitTextButton(card, { text = L["TRACKER_UPDATE_TITLE"], height = 22 })
                titleBtn:SetPoint("LEFT", fillBtn or saveFieldBtn, "RIGHT", 8, 0)
                titleBtn:SetScript("OnClick", function() UpdateTitleFromTarget(nameBox) end)
                card._titleBtn = titleBtn
            end

            if isActive then
                cardHeight = expandedHeight
                saveFieldBtn:Show()
                if fillBtn then fillBtn:Show() end
                if titleBtn then titleBtn:Show() end
                dialog._activeCard = card
            else
                fieldRow:Hide()
                saveFieldBtn:Hide()
                if fillBtn then fillBtn:Hide() end
                if titleBtn then titleBtn:Hide() end
                if rarePane then rarePane:Hide() end
            end

            card._doSave = function()
                local stepName = strtrim(nameBox:GetText() or "")
                if stepName == "" then stepName = cat.titleText or L[cat.titleKey] end

                local trackType = cat.trackType
                local trackParams = {}
                if cat.extra == "vault" then
                    trackType, trackParams = ReadVaultCard(card)
                elseif cat.extra == "profession" then
                    trackType, trackParams = ReadProfessionCard(card)
                    if not trackParams then return end
                elseif cat.extra == "quest" then
                    trackType, trackParams = ReadQuestCard(card)
                    if not trackParams then return end
                elseif cat.extra == "timer" then
                    trackType, trackParams = ReadTimerCard(card)
                else
                    local hasRequired = true
                    for _, field in ipairs(fields) do
                        local w = card["_field_" .. field.key]
                        local val = ReadFieldWidget(w, field)
                        if val ~= nil then
                            trackParams[field.key] = val
                        elseif not field.default then
                            hasRequired = false
                        end
                    end
                    if not hasRequired then return end
                    if cat.trackType == "kill_encounter" then
                        local prev = existing and existing.trackParams
                        if prev and CategoryMatches(cat, existing.trackType) then
                            trackParams.dungeonEncounterID = trackParams.dungeonEncounterID or prev.dungeonEncounterID
                            trackParams.mapID = trackParams.mapID or prev.mapID
                        end
                        trackParams = ns.TrackerEncounter.EnrichParams(trackParams, card._encounterFill)
                    end
                end

                local changes = {
                    label = stepName,
                    trackType = trackType,
                    trackParams = trackParams,
                }
                ApplySharedStepFields(dialog, changes)

                if cat.trackType == "coordinates" then
                    changes.mapID = trackParams.mapID
                    changes.coordX = trackParams.x
                    changes.coordY = trackParams.y
                    changes.waypointRadius = trackParams.radius or 15
                end

                CommitStep(dialog, listID, sectionKey, stepKey, isEdit, changes, callback)
            end

            saveFieldBtn:SetScript("OnClick", card._doSave)
        end

        card:SetHeight(cardHeight)
        card._expanded = isActive
        if isActive and cat.extra == "quest" then
            RecalcQuestRareUI(card)
            card:SetHeight(card._expandedHeight or cardHeight)
        end

        card:SetScript("OnClick", function(myself)
            if not CardHasEditor(cat, fields) then
                local stepName = strtrim(nameBox:GetText() or "")
                if stepName == "" then stepName = cat.titleText or L[cat.titleKey] end

                local changes = {
                    label = stepName,
                    trackType = cat.trackType,
                    trackParams = {},
                }
                ApplySharedStepFields(dialog, changes)

                CommitStep(dialog, listID, sectionKey, stepKey, isEdit, changes, callback)
                return
            end

            if not myself._expanded then
                CollapseAllExcept(myself)
                myself._expanded = true
                dialog._activeCard = myself
                if myself._fieldRow then myself._fieldRow:Show() end
                if myself._saveFieldBtn then myself._saveFieldBtn:Show() end
                if myself._titleBtn then myself._titleBtn:Show() end
                RecalcQuestRareUI(myself)
                myself:SetHeight(myself._expandedHeight or (CardHeaderHeight(descHeight) + FIELD_ROW_H + SAVE_ROW_H))
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                myself:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                ReflowCards()
                return
            end
        end)

        card:SetScript("OnEnter", function(myself)
            if not myself._expanded then
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        card:SetScript("OnLeave", function(myself)
            if not myself._expanded then
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)

        tinsert(allCards, card)
    end

    ReflowCards()
    stack:Finish()
    dialog:Show()
end

function TE_UI:ShowExportDialog(listID)
    local TD = ns.TrackerData
    if not TD then return end

    local exportStr = TD:ExportList(listID)
    if not exportStr then return end

    local dialog = CreateDialog({
        name = "TrackerExportDialog",
        title = L["TRACKER_EXPORT_TITLE"],
        width = 600,
        height = 350,
        destroyOnClose = true,
        buttons = {
            { text = CLOSE, onClick = function(frame) frame:Hide(); frame:SetParent(nil) end },
        },
    })
    if not dialog then return end
    local content = dialog.content

    local hintLabel = OneWoW_GUI:CreateFS(content, 10)
    hintLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    hintLabel:SetText(L["TRACKER_EXPORT_HINT"])
    hintLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local container = OneWoW_GUI:CreateFrame(content, { width = 1, height = 1, backdrop = BACKDROP_SOFT })
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -28)
    container:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 4)
    local scrollFrame, editBox = OneWoW_GUI:CreateScrollEditBox(container, { name = "TrackerExportText", maxLetters = 0 })
    scrollFrame:SetAllPoints(container)
    editBox:SetText(exportStr)
    editBox:HighlightText()

    dialog:Show()
end

function TE_UI:ShowImportDialog(callback)
    local TD = ns.TrackerData
    if not TD then return end

    local dialog = CreateDialog({
        name = "TrackerImportDialog",
        title = L["TRACKER_IMPORT_TITLE"],
        width = 600,
        height = 400,
        destroyOnClose = true,
        buttons = {
            {
                text = L["TRACKER_IMPORT"],
                onClick = function(frame)
                    local text = strtrim(frame._importBox:GetText() or "")
                    if text == "" then return end

                    local result = TD:ImportList(text)
                    if not result then
                        local parsed = TD:ParseMarkup(text)
                        if parsed then
                            result = TD:CreateListFromParsed(parsed)
                        end
                    end

                    if result then
                        frame:Hide(); frame:SetParent(nil)
                        if callback then callback(result) end
                    else
                        print("|cFFFF6666" .. L["TRACKER_IMPORT_FAILED"] .. "|r")
                    end
                end,
            },
            {
                text = CANCEL,
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content

    local hintLabel = OneWoW_GUI:CreateFS(content, 10)
    hintLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    hintLabel:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    hintLabel:SetJustifyH("LEFT")
    hintLabel:SetWordWrap(true)
    hintLabel:SetText(L["TRACKER_IMPORT_HINT"])
    hintLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local container = OneWoW_GUI:CreateFrame(content, { width = 1, height = 1, backdrop = BACKDROP_SOFT })
    container:ClearAllPoints()
    container:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -46)
    container:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 4)
    local scrollFrame, editBox = OneWoW_GUI:CreateScrollEditBox(container, { name = "TrackerImportText", maxLetters = 0 })
    scrollFrame:SetAllPoints(container)
    dialog._importBox = editBox

    dialog:Show()
end
