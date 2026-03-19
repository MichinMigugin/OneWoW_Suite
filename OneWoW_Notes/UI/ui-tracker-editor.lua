local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerEditor = {}
local TE_UI = ns.TrackerEditor

local format, tinsert, tonumber, tostring = format, tinsert, tonumber, tostring
local strtrim, sort, wipe, pairs, ipairs = strtrim, sort, wipe, pairs, ipairs

local BACKDROP_SOFT = OneWoW_GUI.Constants.BACKDROP_SOFT or OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

local function MakeLabel(parent, text, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetText(text)
    fs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    return fs
end

local QUICK_START = {
    {
        key = "weekly",
        title = "Weekly Checklist",
        desc = "Track weekly tasks like Great Vault, world bosses, and weekly quests. Resets every Tuesday.",
        icon = "Interface\\Icons\\Achievement_General_100kQuests",
        listType = "weekly",
        category = "Weeklies",
        preset = "midnight_weeklies",
    },
    {
        key = "daily",
        title = "Daily Tasks",
        desc = "Daily chores that reset every day. World quests, daily hubs, profession cooldowns.",
        icon = "Interface\\Icons\\Spell_Holy_BorrowedTime",
        listType = "daily",
        category = "Dailies",
        preset = "daily_tasks",
    },
    {
        key = "todo",
        title = "To-Do List",
        desc = "A simple checklist. Check things off as you go. Never resets.",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
        listType = "todo",
        category = "General",
        preset = "todo_template",
    },
    {
        key = "vault",
        title = "Great Vault Tracker",
        desc = "Track your raid, dungeon, and world content progress for the weekly vault.",
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        listType = "weekly",
        category = "Weeklies",
        preset = "great_vault",
    },
    {
        key = "professions",
        title = "Profession Tracker",
        desc = "Track skill, concentration, knowledge, and weekly tasks for your professions.",
        icon = "Interface\\Icons\\Trade_BlackSmithing",
        listType = "weekly",
        category = "Professions",
        showProfPicker = true,
    },
    {
        key = "renown",
        title = "Renown Tracker",
        desc = "Track your renown levels with all Midnight factions.",
        icon = "Interface\\Icons\\Achievement_Reputation_08",
        listType = "weekly",
        category = "Reputation",
        preset = "renown_tracking",
    },
    {
        key = "guide",
        title = "Custom Guide",
        desc = "Build a step-by-step guide with auto-tracking objectives. Quests, locations, NPCs, items, and more.",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
        listType = "guide",
        category = "General",
        showCustomForm = true,
    },
    {
        key = "blank",
        title = "Blank List",
        desc = "Start from scratch. Pick your own type and add sections and steps manually.",
        icon = "Interface\\Icons\\INV_Scroll_03",
        listType = "todo",
        category = "General",
        showCustomForm = true,
    },
}

local STEP_CATEGORIES = {
    {
        key = "checkbox",
        title = "Checkbox",
        desc = "A simple task you check off manually.",
        trackType = "manual",
        fields = {},
    },
    {
        key = "quest",
        title = "Complete a Quest",
        desc = "Auto-completes when you finish a quest. Enter the Quest ID (find it on Wowhead in the URL).",
        trackType = "quest",
        fields = { { key = "questID", label = "Quest ID", hint = "e.g. 86387", width = 160 } },
    },
    {
        key = "item",
        title = "Collect Items",
        desc = "Tracks how many of an item you have in your bags. Great for farming.",
        trackType = "item",
        fields = {
            { key = "itemID", label = "Item ID", hint = "e.g. 211515", width = 160 },
            { key = "count", label = "How Many?", hint = "e.g. 10", width = 80 },
        },
    },
    {
        key = "currency",
        title = "Earn Currency",
        desc = "Tracks a currency amount. Valor, Resonance Crystals, etc.",
        trackType = "currency",
        fields = {
            { key = "currencyID", label = "Currency ID", hint = "e.g. 3220", width = 160 },
            { key = "amount", label = "Target Amount", hint = "e.g. 500", width = 100 },
        },
    },
    {
        key = "achievement",
        title = "Earn Achievement",
        desc = "Auto-completes when you earn a specific achievement.",
        trackType = "achievement",
        fields = { { key = "achievementID", label = "Achievement ID", hint = "e.g. 19559", width = 160 } },
    },
    {
        key = "coordinates",
        title = "Visit a Location",
        desc = "Auto-completes when you get close to specific coordinates. Great for collection routes.",
        trackType = "coordinates",
        fields = {
            { key = "mapID", label = "Map ID", hint = "e.g. 2369", width = 100 },
            { key = "x", label = "X", hint = "0-100", width = 60 },
            { key = "y", label = "Y", hint = "0-100", width = 60 },
            { key = "radius", label = "Range", hint = "15", width = 50, default = "15" },
        },
    },
    {
        key = "npc",
        title = "Talk to an NPC",
        desc = "Auto-completes when you open a dialog with a specific NPC.",
        trackType = "npc_interact",
        fields = { { key = "npcID", label = "NPC ID", hint = "e.g. 224561", width = 160 } },
    },
    {
        key = "kill",
        title = "Kill Creatures",
        desc = "Tracks kills of a specific creature type. Uses target detection.",
        trackType = "kill_count",
        fields = {
            { key = "creatureID", label = "Creature ID", hint = "e.g. 218237", width = 160 },
            { key = "count", label = "How Many?", hint = "e.g. 10", width = 80 },
        },
    },
    {
        key = "mount",
        title = "Collect a Mount",
        desc = "Auto-completes when you own a specific mount.",
        trackType = "mount",
        fields = { { key = "mountID", label = "Mount ID", hint = "e.g. 2240", width = 160 } },
    },
    {
        key = "pet",
        title = "Collect a Battle Pet",
        desc = "Auto-completes when you own a specific pet species.",
        trackType = "pet",
        fields = { { key = "speciesID", label = "Species ID", hint = "e.g. 3541", width = 160 } },
    },
    {
        key = "toy",
        title = "Collect a Toy",
        desc = "Auto-completes when you own a specific toy.",
        trackType = "toy",
        fields = { { key = "itemID", label = "Toy Item ID", hint = "e.g. 224562", width = 160 } },
    },
    {
        key = "transmog",
        title = "Collect Transmog",
        desc = "Auto-completes when you learn a specific appearance.",
        trackType = "transmog",
        fields = { { key = "itemModifiedAppearanceID", label = "Appearance ID", hint = "from Wowhead", width = 160 } },
    },
    {
        key = "reputation",
        title = "Reach Reputation",
        desc = "Tracks your standing with a faction.",
        trackType = "reputation",
        fields = {
            { key = "factionID", label = "Faction ID", hint = "e.g. 2710", width = 160 },
            { key = "standing", label = "Standing (1-8)", hint = "e.g. 8", width = 60 },
        },
    },
    {
        key = "renown",
        title = "Reach Renown Level",
        desc = "Tracks renown level with a major faction.",
        trackType = "renown",
        fields = {
            { key = "factionID", label = "Faction ID", hint = "e.g. 2710", width = 160 },
            { key = "level", label = "Renown Level", hint = "e.g. 20", width = 60 },
        },
    },
    {
        key = "level",
        title = "Reach Player Level",
        desc = "Auto-completes when you reach a specific character level.",
        trackType = "level",
        fields = { { key = "level", label = "Level", hint = "e.g. 80", width = 60 } },
    },
    {
        key = "ilvl",
        title = "Reach Item Level",
        desc = "Auto-completes when your average equipped item level reaches the target.",
        trackType = "ilvl",
        fields = { { key = "ilvl", label = "Item Level", hint = "e.g. 639", width = 80 } },
    },
    {
        key = "spell_known",
        title = "Learn a Spell",
        desc = "Auto-completes when you know a specific spell or ability.",
        trackType = "spell_known",
        fields = { { key = "spellID", label = "Spell ID", hint = "e.g. 1459", width = 160 } },
    },
    {
        key = "buff",
        title = "Have a Buff",
        desc = "Tracks whether you currently have a specific buff or debuff.",
        trackType = "buff",
        fields = { { key = "spellID", label = "Buff Spell ID", hint = "e.g. 1459", width = 160 } },
    },
}

function TE_UI:ShowNewListDialog(callback)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    local TP = ns.TrackerPresets
    if not TD or not TE then return end

    local dialog = ns.UI.CreateThemedDialog({
        name = "TrackerNewListWizard",
        title = "Create New Tracker",
        width = 700,
        height = 600,
        destroyOnClose = true,
        buttons = {
            { text = L["BUTTON_CANCEL"] or "Cancel", onClick = function(frame) frame:Hide(); frame:SetParent(nil) end },
        },
    })
    if not dialog then return end
    local content = dialog.content

    local headerLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    headerLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    headerLabel:SetText("What do you want to track?")
    headerLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local descLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    descLabel:SetPoint("TOPLEFT", headerLabel, "BOTTOMLEFT", 0, -4)
    descLabel:SetText("Pick a template to get started quickly, or create a blank list.")
    descLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(content, {})
    scrollFrame:SetPoint("TOPLEFT", descLabel, "BOTTOMLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -6, 4)

    local yOfs = 0
    local CARD_HEIGHT = 60
    local CARD_GAP = 4

    for _, qs in ipairs(QUICK_START) do
        local card = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        card:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOfs)
        card:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOfs)
        card:SetHeight(CARD_HEIGHT)
        card:SetBackdrop(BACKDROP_SIMPLE)
        card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

        local icon = card:CreateTexture(nil, "ARTWORK")
        icon:SetSize(36, 36)
        icon:SetPoint("LEFT", card, "LEFT", 12, 0)
        icon:SetTexture(qs.icon)

        local titleFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -4)
        titleFS:SetText(qs.title)
        titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local descFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -2)
        descFS:SetPoint("RIGHT", card, "RIGHT", -12, 0)
        descFS:SetJustifyH("LEFT")
        descFS:SetWordWrap(true)
        descFS:SetText(qs.desc)
        descFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        card:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end)
        card:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end)

        card:SetScript("OnClick", function()
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
                    title = qs.title,
                    listType = qs.listType,
                    category = qs.category,
                })
                TD:AddSection(list.id, { label = "Tasks" })
                dialog:Hide(); dialog:SetParent(nil)
                if callback then callback(list) end
            end
        end)

        yOfs = yOfs - CARD_HEIGHT - CARD_GAP
    end

    yOfs = yOfs - 12
    local importCard = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
    importCard:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOfs)
    importCard:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOfs)
    importCard:SetHeight(CARD_HEIGHT)
    importCard:SetBackdrop(BACKDROP_SIMPLE)
    importCard:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    importCard:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local impIcon = importCard:CreateTexture(nil, "ARTWORK")
    impIcon:SetSize(36, 36)
    impIcon:SetPoint("LEFT", importCard, "LEFT", 12, 0)
    impIcon:SetTexture("Interface\\Icons\\INV_Letter_15")

    local impTitle = importCard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    impTitle:SetPoint("TOPLEFT", impIcon, "TOPRIGHT", 10, -4)
    impTitle:SetText("Import from Text")
    impTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local impDesc = importCard:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    impDesc:SetPoint("TOPLEFT", impTitle, "BOTTOMLEFT", 0, -2)
    impDesc:SetText("Paste an exported list or guide markup shared by another player.")
    impDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    importCard:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        impTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
    end)
    importCard:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        impTitle:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)
    importCard:SetScript("OnClick", function()
        dialog:Hide(); dialog:SetParent(nil)
        TE_UI:ShowImportDialog(callback)
    end)

    yOfs = yOfs - CARD_HEIGHT - CARD_GAP
    scrollChild:SetHeight(math.abs(yOfs) + 20)

    dialog:Show()
end

function TE_UI:ShowCustomListForm(defaultType, defaultCategory, callback)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    if not TD or not TE then return end

    local dialog = ns.UI.CreateThemedDialog({
        name = "TrackerCustomListForm",
        title = "Create Custom List",
        width = 480,
        height = 300,
        destroyOnClose = true,
        buttons = {
            {
                text = "Create",
                onClick = function(frame)
                    local title = strtrim(frame._titleBox:GetText() or "")
                    if title == "" then title = "My List" end
                    local list = TD:CreateList({
                        title = title,
                        description = strtrim(frame._descBox:GetText() or ""),
                        listType = frame._typeDD:GetValue() or defaultType or "todo",
                        category = frame._catDD:GetValue() or defaultCategory or "General",
                    })
                    TD:AddSection(list.id, { label = "Tasks" })
                    frame:Hide(); frame:SetParent(nil)
                    if callback then callback(list) end
                end,
            },
            {
                text = L["BUTTON_CANCEL"] or "Cancel",
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content
    local yOfs = -10

    MakeLabel(content, "Title:", 10, yOfs)
    yOfs = yOfs - 16
    local titleBox = OneWoW_GUI:CreateEditBox(content, { width = 440, height = 26, placeholderText = "My List..." })
    titleBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    dialog._titleBox = titleBox
    yOfs = yOfs - 36

    MakeLabel(content, "Description (optional):", 10, yOfs)
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

    MakeLabel(content, "Type:", 10, yOfs)
    local typeDD = ns.UI.CreateThemedDropdown(content, "", 180, 26)
    typeDD:SetPoint("TOPLEFT", content, "TOPLEFT", 60, yOfs)
    local typeOpts = {}
    for _, lt in ipairs(TD:GetListTypes()) do
        tinsert(typeOpts, { text = TE:GetListTypeDisplayName(lt), value = lt })
    end
    typeDD:SetOptions(typeOpts)
    typeDD:SetSelected(defaultType or "todo")
    dialog._typeDD = typeDD

    MakeLabel(content, "Category:", 260, yOfs)
    local catDD = ns.UI.CreateThemedDropdown(content, "", 140, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", 330, yOfs)
    local catOpts = {}
    for _, cat in ipairs(TD:GetCategories()) do
        tinsert(catOpts, { text = cat, value = cat })
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(defaultCategory or "General")
    dialog._catDD = catDD

    dialog:Show()
end

function TE_UI:ShowProfessionPicker(callback)
    local TP = ns.TrackerPresets
    if not TP then return end

    local dialog = ns.UI.CreateThemedDialog({
        name = "TrackerProfPicker",
        title = "Pick Your Professions",
        width = 400,
        height = 460,
        destroyOnClose = true,
        buttons = {
            {
                text = "Create Tracker",
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
                text = L["BUTTON_CANCEL"] or "Cancel",
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content
    dialog._selectedProfs = {}

    local hintLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    hintLabel:SetText("Select the professions you want to track. Each will get its own section with skill, concentration, knowledge, and weekly tasks.")
    hintLabel:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    hintLabel:SetJustifyH("LEFT")
    hintLabel:SetWordWrap(true)
    hintLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local yOfs = -46
    local profPresets = TP:GetProfessionPresets()

    for _, prof in ipairs(profPresets) do
        local check = OneWoW_GUI:CreateCheckbox(content, { label = prof.name })
        check:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
        check:SetScript("OnClick", function(self)
            if self:GetChecked() then
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

    local dialog = ns.UI.CreateThemedDialog({
        name = "TrackerEditListDialog",
        title = "Edit List",
        width = 480,
        height = 300,
        destroyOnClose = true,
        buttons = {
            {
                text = L["NOTES_SAVE"] or "Save",
                onClick = function(frame)
                    TD:UpdateList(listID, {
                        title = strtrim(frame._titleBox:GetText() or "Untitled"),
                        description = strtrim(frame._descBox:GetText() or ""),
                        listType = frame._typeDD:GetValue() or "todo",
                        category = frame._catDD:GetValue() or "General",
                    })
                    frame:Hide(); frame:SetParent(nil)
                    if callback then callback() end
                end,
            },
            {
                text = L["BUTTON_CANCEL"] or "Cancel",
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content
    local yOfs = -10

    MakeLabel(content, "Title:", 10, yOfs)
    yOfs = yOfs - 16
    local titleBox = OneWoW_GUI:CreateEditBox(content, { width = 440, height = 26 })
    titleBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    titleBox:SetText(list.title or "")
    dialog._titleBox = titleBox
    yOfs = yOfs - 36

    MakeLabel(content, "Description:", 10, yOfs)
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

    MakeLabel(content, "Type:", 10, yOfs)
    local typeDD = ns.UI.CreateThemedDropdown(content, "", 180, 26)
    typeDD:SetPoint("TOPLEFT", content, "TOPLEFT", 60, yOfs)
    local typeOpts = {}
    for _, lt in ipairs(TD:GetListTypes()) do
        tinsert(typeOpts, { text = TE:GetListTypeDisplayName(lt), value = lt })
    end
    typeDD:SetOptions(typeOpts)
    typeDD:SetSelected(list.listType or "todo")
    dialog._typeDD = typeDD

    MakeLabel(content, "Category:", 260, yOfs)
    local catDD = ns.UI.CreateThemedDropdown(content, "", 140, 26)
    catDD:SetPoint("TOPLEFT", content, "TOPLEFT", 330, yOfs)
    local catOpts = {}
    for _, cat in ipairs(TD:GetCategories()) do
        tinsert(catOpts, { text = cat, value = cat })
    end
    catDD:SetOptions(catOpts)
    catDD:SetSelected(list.category or "General")
    dialog._catDD = catDD

    dialog:Show()
end

function TE_UI:ShowSectionEditor(listID, sectionKey, callback)
    local TD = ns.TrackerData
    if not TD then return end

    local existing = sectionKey and TD:GetSection(listID, sectionKey) or nil
    local isEdit = existing ~= nil

    local dialog = ns.UI.CreateThemedDialog({
        name = "TrackerSectionDialog",
        title = isEdit and "Edit Section" or "Add Section",
        width = 400,
        height = 200,
        destroyOnClose = true,
        buttons = {
            {
                text = L["NOTES_SAVE"] or "Save",
                onClick = function(frame)
                    local name = strtrim(frame._nameBox:GetText() or "")
                    if name == "" then name = "Section" end
                    local resetVal = frame._resetDD:GetValue()
                    local resetOverride = (resetVal and resetVal ~= "none") and resetVal or nil

                    if isEdit then
                        TD:UpdateSection(listID, sectionKey, { label = name, resetOverride = resetOverride })
                    else
                        TD:AddSection(listID, { label = name, resetOverride = resetOverride })
                    end
                    frame:Hide(); frame:SetParent(nil)
                    if callback then callback() end
                end,
            },
            {
                text = L["BUTTON_CANCEL"] or "Cancel",
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content
    local yOfs = -10

    MakeLabel(content, "Section Name:", 10, yOfs)
    yOfs = yOfs - 16
    local nameBox = OneWoW_GUI:CreateEditBox(content, { width = 360, height = 26, placeholderText = "e.g. Weekly Quests" })
    nameBox:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOfs)
    if existing then nameBox:SetText(existing.label or "") end
    dialog._nameBox = nameBox
    yOfs = yOfs - 36

    MakeLabel(content, "Reset:", 10, yOfs)
    local resetDD = ns.UI.CreateThemedDropdown(content, "", 220, 26)
    resetDD:SetPoint("TOPLEFT", content, "TOPLEFT", 60, yOfs)
    resetDD:SetOptions({
        { text = "Same as list (default)", value = "none" },
        { text = "Daily - resets every day", value = "daily" },
        { text = "Weekly - resets Tuesday", value = "weekly" },
        { text = "Never - manual only", value = "todo" },
    })
    resetDD:SetSelected(existing and existing.resetOverride or "none")
    dialog._resetDD = resetDD

    dialog:Show()
end

function TE_UI:ShowStepEditor(listID, sectionKey, stepKey, callback)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    if not TD or not TE then return end

    local existing = stepKey and TD:GetStep(listID, sectionKey, stepKey) or nil
    local isEdit = existing ~= nil

    local dialog = ns.UI.CreateThemedDialog({
        name = "TrackerStepWizard",
        title = isEdit and "Edit Step" or "Add Step",
        width = 650,
        height = 580,
        destroyOnClose = true,
        buttons = {
            { text = L["BUTTON_CANCEL"] or "Cancel", onClick = function(frame) frame:Hide(); frame:SetParent(nil) end },
        },
    })
    if not dialog then return end
    local content = dialog.content

    local nameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    nameLabel:SetText("Step Name:")
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local nameBox = OneWoW_GUI:CreateEditBox(content, { width = 610, height = 26, placeholderText = "e.g. Kill 10 Spiders, Visit the Tavern, Complete quest..." })
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -2)
    if existing then nameBox:SetText(existing.label or "") end

    local typeHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeHeader:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -12)
    typeHeader:SetText("How should this step be tracked?")
    typeHeader:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(content, {})
    scrollFrame:SetPoint("TOPLEFT", typeHeader, "BOTTOMLEFT", 0, -6)
    scrollFrame:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -6, 4)

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
            if c ~= keepCard and c._expanded and c._cat and #c._cat.fields > 0 then
                c._expanded = false
                if c._fieldRow then c._fieldRow:Hide() end
                local baseH = 28 + (c._descHeight or 14) + 8
                c:SetHeight(baseH)
                c:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                c:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                if c._titleFS then c._titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
            end
        end
    end

    for _, cat in ipairs(STEP_CATEGORIES) do
        local isActive = existing and existing.trackType == cat.trackType

        local card = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
        card:SetBackdrop(BACKDROP_SIMPLE)

        if isActive then
            card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            card:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            card:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end

        local titleFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titleFS:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -6)
        titleFS:SetText(cat.title)
        if isActive then
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local descFS = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -2)
        descFS:SetPoint("RIGHT", card, "RIGHT", -10, 0)
        descFS:SetJustifyH("LEFT")
        descFS:SetWordWrap(true)
        descFS:SetText(cat.desc)
        descFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local descHeight = descFS:GetStringHeight() or 14
        local cardHeight = 28 + descHeight + 8

        card._cat = cat
        card._descHeight = descHeight
        card._titleFS = titleFS

        if #cat.fields > 0 then
            local fieldY = -(cardHeight)
            local fieldRow = CreateFrame("Frame", nil, card)
            fieldRow:SetPoint("TOPLEFT", card, "TOPLEFT", 10, fieldY)
            fieldRow:SetPoint("TOPRIGHT", card, "TOPRIGHT", -10, fieldY)
            fieldRow:SetHeight(30)
            card._fieldRow = fieldRow

            local saveFieldBtn = OneWoW_GUI:CreateFitTextButton(card, { text = isEdit and "Save" or "Add Step", height = 22 })
            card._saveFieldBtn = saveFieldBtn

            local fx = 0
            for _, field in ipairs(cat.fields) do
                local flbl = fieldRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                flbl:SetPoint("TOPLEFT", fieldRow, "TOPLEFT", fx, 0)
                flbl:SetText(field.label .. ":")
                flbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

                local fbox = OneWoW_GUI:CreateEditBox(fieldRow, {
                    width = field.width or 120,
                    height = 22,
                    placeholderText = field.hint or "",
                    maxLetters = 12,
                })
                fbox:SetPoint("TOPLEFT", flbl, "BOTTOMLEFT", 0, -1)
                fbox._fieldKey = field.key

                if existing and existing.trackParams and existing.trackType == cat.trackType then
                    local val = existing.trackParams[field.key]
                    if val then fbox:SetText(tostring(val)) end
                end
                if not existing and field.default then
                    fbox:SetText(field.default)
                end

                card["_field_" .. field.key] = fbox
                fx = fx + (field.width or 120) + 20
            end

            saveFieldBtn:SetPoint("TOPLEFT", fieldRow, "BOTTOMLEFT", 0, -4)
            local expandedHeight = cardHeight + 42 + 30

            if isActive then
                cardHeight = expandedHeight
                saveFieldBtn:Show()
            else
                fieldRow:Hide()
                saveFieldBtn:Hide()
            end

            saveFieldBtn:SetScript("OnClick", function()
                local stepName = strtrim(nameBox:GetText() or "")
                if stepName == "" then stepName = cat.title end

                local trackParams = {}
                for _, field in ipairs(cat.fields) do
                    local w = card["_field_" .. field.key]
                    if w then
                        local val = strtrim(w:GetText() or "")
                        if val ~= "" then
                            trackParams[field.key] = tonumber(val) or val
                        end
                    end
                end

                local hasRequired = true
                for _, field in ipairs(cat.fields) do
                    if not field.default then
                        local w = card["_field_" .. field.key]
                        if w then
                            local val = strtrim(w:GetText() or "")
                            if val == "" then hasRequired = false; break end
                        end
                    end
                end
                if not hasRequired then return end

                local max = 1
                if cat.trackType == "kill_count" or cat.trackType == "item" then
                    max = tonumber(trackParams.count) or 1
                end

                local changes = {
                    label = stepName,
                    trackType = cat.trackType,
                    trackParams = trackParams,
                    max = max,
                }

                if cat.trackType == "coordinates" then
                    changes.mapID = trackParams.mapID
                    changes.coordX = trackParams.x
                    changes.coordY = trackParams.y
                    changes.waypointRadius = trackParams.radius or 15
                end

                if isEdit then
                    TD:UpdateStep(listID, sectionKey, stepKey, changes)
                else
                    TD:AddStep(listID, sectionKey, changes)
                end

                dialog:Hide(); dialog:SetParent(nil)
                if callback then callback() end
            end)
        end

        card:SetHeight(cardHeight)
        card._expanded = isActive

        card:SetScript("OnClick", function(self)
            if #cat.fields == 0 then
                local stepName = strtrim(nameBox:GetText() or "")
                if stepName == "" then stepName = cat.title end

                local changes = {
                    label = stepName,
                    trackType = cat.trackType,
                    trackParams = {},
                    max = 1,
                }

                if isEdit then
                    TD:UpdateStep(listID, sectionKey, stepKey, changes)
                else
                    TD:AddStep(listID, sectionKey, changes)
                end

                dialog:Hide(); dialog:SetParent(nil)
                if callback then callback() end
                return
            end

            if not self._expanded then
                CollapseAllExcept(self)
                self._expanded = true
                if self._fieldRow then self._fieldRow:Show() end
                if self._saveFieldBtn then self._saveFieldBtn:Show() end
                local newH = 28 + (descHeight) + 8 + 42 + 30
                self:SetHeight(newH)
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
                titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                ReflowCards()
                return
            end
        end)

        card:SetScript("OnEnter", function(self)
            if not self._expanded then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
                titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        card:SetScript("OnLeave", function(self)
            if not self._expanded then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                titleFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)

        tinsert(allCards, card)
    end

    ReflowCards()
    dialog:Show()
end

function TE_UI:ShowExportDialog(listID)
    local TD = ns.TrackerData
    if not TD then return end

    local exportStr = TD:ExportList(listID)
    if not exportStr then return end

    local dialog = ns.UI.CreateThemedDialog({
        name = "TrackerExportDialog",
        title = "Export List",
        width = 600,
        height = 350,
        destroyOnClose = true,
        buttons = {
            { text = L["BUTTON_CLOSE"] or "Close", onClick = function(frame) frame:Hide(); frame:SetParent(nil) end },
        },
    })
    if not dialog then return end
    local content = dialog.content

    local hintLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    hintLabel:SetText("Copy the text below and share it with others. They can import it using the Import option.")
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

    local dialog = ns.UI.CreateThemedDialog({
        name = "TrackerImportDialog",
        title = "Import List",
        width = 600,
        height = 400,
        destroyOnClose = true,
        buttons = {
            {
                text = "Import",
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
                        print("|cFFFF6666Import failed. Check that the text is a valid export string or guide markup.|r")
                    end
                end,
            },
            {
                text = L["BUTTON_CANCEL"] or "Cancel",
                onClick = function(frame) frame:Hide(); frame:SetParent(nil) end,
            },
        },
    })
    if not dialog then return end
    local content = dialog.content

    local hintLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -6)
    hintLabel:SetPoint("RIGHT", content, "RIGHT", -10, 0)
    hintLabel:SetJustifyH("LEFT")
    hintLabel:SetWordWrap(true)
    hintLabel:SetText("Paste an exported list string or guide markup text below. Supports both the export format (starts with OWT1:) and the markup format (# Title, ## Section, ### Step).")
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

function TE_UI:ShowPresetDialog(callback)
    self:ShowNewListDialog(callback)
end
