-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/ui-category-manager.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.UI = ns.UI or {}

local SECTIONS = {
    { key = "notes",   label = "TAB_NOTES",   getCategories = function() return ns.NotesCategories and ns.NotesCategories:GetCategories() or {} end },
    { key = "players", label = "TAB_PLAYERS",  getCategories = function() return ns.Players and ns.Players:GetCategories() or {} end },
    { key = "npcs",    label = "TAB_NPCS",     getCategories = function() return ns.NPCs and ns.NPCs:GetCategories() or {} end },
    { key = "zones",   label = "TAB_ZONES",    getCategories = function() return ns.Zones and ns.Zones:GetCategories() or {} end },
    { key = "items",   label = "TAB_ITEMS",    getCategories = function() return ns.Items and ns.Items:GetCategories() or {} end },
}

local BUILT_IN_CATEGORIES = {
    notes = {
        "General", "Personal", "Guild", "Raid", "Dungeon", "Quest",
        "Achievement", "Profession", "Gold Making", "PvP", "Shopping List"
    },
    players = {
        "General", "Friend", "Guild Member", "Acquaintance", "Trader",
        "PvP", "Blacklist", "Interesting", "Officer", "Crafter", "Helper", "Other"
    },
    npcs = {
        "Other", "Quest Givers", "Vendors", "Trainers", "Flight Masters",
        "Rare Elites", "Bosses", "Event NPCs", "Auctioneers", "Portals",
        "Repair", "Transmog", "PvP Vendors", "Profession NPCs", "Pet Trainers"
    },
    zones = {
        "General", "Quest", "Farming", "Rare", "Treasure", "Dungeon", "Raid", "PvP", "Event"
    },
    items = {
        "General", "Transmog", "Crafting", "Quest", "Rare", "Collectible"
    },
}

local CUSTOM_DB_KEYS = {
    notes   = "notesCustomCategories",
    players = "playerCustomCategories",
    npcs    = "npcCustomCategories",
    zones   = "zoneCustomCategories",
    items   = "itemCustomCategories",
}

local function IsBuiltIn(sectionKey, categoryName)
    local builtins = BUILT_IN_CATEGORIES[sectionKey]
    if not builtins then return false end
    for _, name in ipairs(builtins) do
        if name == categoryName then return true end
    end
    return false
end

local function GetCustomCategories(sectionKey)
    local addon = _G.OneWoW_Notes
    local dbKey = CUSTOM_DB_KEYS[sectionKey]
    if addon and addon.db and addon.db.global and addon.db.global[dbKey] then
        return addon.db.global[dbKey]
    end
    return {}
end

local function AddCustomCategory(sectionKey, categoryName)
    if not categoryName or categoryName == "" then
        return false, L["NOTES_CATEGORY_EMPTY"]
    end

    if sectionKey == "notes" and ns.NotesCategories then
        return ns.NotesCategories:AddCustomCategory(categoryName)
    end

    local addon = _G.OneWoW_Notes
    local dbKey = CUSTOM_DB_KEYS[sectionKey]
    if not addon.db.global[dbKey] then
        addon.db.global[dbKey] = {}
    end

    local sectionInfo = nil
    for _, s in ipairs(SECTIONS) do
        if s.key == sectionKey then sectionInfo = s break end
    end
    if sectionInfo then
        local allCats = sectionInfo.getCategories()
        for _, existing in ipairs(allCats) do
            if existing:lower() == categoryName:lower() then
                return false, L["NOTES_CATEGORY_EXISTS"]
            end
        end
    end

    table.insert(addon.db.global[dbKey], categoryName)
    return true
end

local function RemoveCustomCategory(sectionKey, categoryName)
    if not categoryName or categoryName == "" then
        return false, L["NOTES_CATEGORY_EMPTY"]
    end

    if IsBuiltIn(sectionKey, categoryName) then
        return false, L["NOTES_CATEGORY_BUILTIN"]
    end

    if sectionKey == "notes" and ns.NotesCategories then
        return ns.NotesCategories:RemoveCustomCategory(categoryName)
    end

    local addon = _G.OneWoW_Notes
    local dbKey = CUSTOM_DB_KEYS[sectionKey]
    if not addon.db.global[dbKey] then
        return false, L["NOTES_CATEGORY_NOT_FOUND"]
    end

    for i = #addon.db.global[dbKey], 1, -1 do
        if addon.db.global[dbKey][i] == categoryName then
            table.remove(addon.db.global[dbKey], i)
            return true
        end
    end

    return false, L["NOTES_CATEGORY_NOT_IN_CUSTOM"]
end

function ns.UI.ShowCategoryManager(initialSection)
    local lib = LibStub("OneWoW_GUI-1.0", true)

    local dialog = ns.UI.CreateThemedDialog({
        name           = "OneWoW_NotesCategoryManager",
        title          = L["CATMGR_TITLE"],
        width          = 450,
        height         = 500,
        destroyOnClose = true,
        buttons        = {
            { text = L["BUTTON_CLOSE"], onClick = function(dlg) dlg:Hide() end },
        },
    })

    if dialog.built then dialog:Show() return end
    dialog.built = true

    local content = dialog.content
    local currentSection = initialSection or "notes"
    local categoryRows = {}

    local sectionBtnContainer = CreateFrame("Frame", nil, content)
    sectionBtnContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -8)
    sectionBtnContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -8, -8)
    sectionBtnContainer:SetHeight(28)

    local sectionButtons = {}
    local btnWidth = 80
    local btnGap = 4

    local addContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    addContainer:SetPoint("TOPLEFT", sectionBtnContainer, "BOTTOMLEFT", 0, -8)
    addContainer:SetPoint("TOPRIGHT", sectionBtnContainer, "BOTTOMRIGHT", 0, -8)
    addContainer:SetHeight(30)
    addContainer:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    addContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    addContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

    local addInput = CreateFrame("EditBox", nil, addContainer, "BackdropTemplate")
    addInput:SetPoint("TOPLEFT", addContainer, "TOPLEFT", 4, -3)
    addInput:SetPoint("BOTTOMRIGHT", addContainer, "BOTTOMRIGHT", -84, 3)
    addInput:SetHeight(24)
    addInput:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    addInput:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    addInput:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    addInput:SetFontObject("GameFontNormalSmall")
    addInput:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    addInput:SetTextInsets(6, 6, 2, 2)
    addInput:SetAutoFocus(false)

    local addBtn = OneWoW_GUI:CreateButton(addContainer, { text = L["CATMGR_ADD"], width = 76, height = 24 })
    addBtn:SetPoint("RIGHT", addContainer, "RIGHT", -3, 0)

    local statusLabel = OneWoW_GUI:CreateFS(content, 10)
    statusLabel:SetPoint("TOPLEFT", addContainer, "BOTTOMLEFT", 2, -4)
    statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    statusLabel:SetText("")

    local scroll = ns.UI.CreateCustomScroll(content)
    scroll.container:SetPoint("TOPLEFT", addContainer, "BOTTOMLEFT", 0, -22)
    scroll.container:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 4)

    local scrollChild = scroll.scrollChild

    local function RefreshCategoryList()
        for _, row in ipairs(categoryRows) do
            row:Hide()
        end
        wipe(categoryRows)

        local sectionInfo = nil
        for _, s in ipairs(SECTIONS) do
            if s.key == currentSection then sectionInfo = s break end
        end
        if not sectionInfo then return end

        local allCategories = sectionInfo.getCategories()
        local ROW_H = 26
        local ROW_GAP = 2
        local yPos = 0

        for i, catName in ipairs(allCategories) do
            local isBuiltin = IsBuiltIn(currentSection, catName)

            local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, -yPos)
            row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -2, -yPos)
            row:SetHeight(ROW_H)
            row:SetBackdrop(BACKDROP_SIMPLE)

            if isBuiltin then
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            else
                row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            end

            local nameFS = OneWoW_GUI:CreateFS(row, 10)
            nameFS:SetPoint("LEFT", row, "LEFT", 8, 0)
            nameFS:SetPoint("RIGHT", row, "RIGHT", -32, 0)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetText(catName)

            if isBuiltin then
                nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            else
                nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            if not isBuiltin then
                local delBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                delBtn:SetSize(20, 20)
                delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                delBtn:SetBackdrop(BACKDROP_INNER_NO_INSETS)
                delBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                delBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))

                local delX = OneWoW_GUI:CreateFS(delBtn, 10)
                delX:SetPoint("CENTER")
                delX:SetText("X")
                delX:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

                delBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0.6, 0.1, 0.1, 1)
                    self:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
                    delX:SetTextColor(1, 1, 1, 1)
                end)
                delBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                    self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                    delX:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end)
                delBtn:SetScript("OnClick", function()
                    local ok, err = RemoveCustomCategory(currentSection, catName)
                    if ok then
                        statusLabel:SetText(string.format(L["CATMGR_REMOVED"], catName))
                        statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                    else
                        statusLabel:SetText(err or L["CATMGR_ERROR"])
                        statusLabel:SetTextColor(0.8, 0.2, 0.2, 1)
                    end
                    RefreshCategoryList()
                end)
            end

            categoryRows[#categoryRows + 1] = row
            yPos = yPos + ROW_H + ROW_GAP
        end

        scrollChild:SetHeight(math.max(1, yPos))
        scroll.scrollFrame:SetVerticalScroll(0)
        scroll.UpdateThumb()
    end

    local function SetActiveSection(sectionKey)
        currentSection = sectionKey
        statusLabel:SetText("")
        addInput:SetText("")
        addInput:ClearFocus()

        for _, btn in ipairs(sectionButtons) do
            if btn.sectionKey == sectionKey then
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end

        RefreshCategoryList()
    end

    for i, sectionDef in ipairs(SECTIONS) do
        local btn = OneWoW_GUI:CreateButton(sectionBtnContainer, { text = L[sectionDef.label], width = btnWidth, height = 26 })
        btn:SetPoint("TOPLEFT", sectionBtnContainer, "TOPLEFT", (i - 1) * (btnWidth + btnGap), 0)
        btn.sectionKey = sectionDef.key

        btn:SetScript("OnClick", function()
            SetActiveSection(sectionDef.key)
        end)
        btn:SetScript("OnEnter", function(self)
            if currentSection ~= self.sectionKey then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if currentSection ~= self.sectionKey then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
        end)

        sectionButtons[#sectionButtons + 1] = btn
    end

    local function DoAdd()
        local name = addInput:GetText()
        if not name then return end
        name = strtrim(name)
        if name == "" then return end

        local ok, err = AddCustomCategory(currentSection, name)
        if ok then
            statusLabel:SetText(string.format(L["CATMGR_ADDED"], name))
            statusLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            addInput:SetText("")
            RefreshCategoryList()
        else
            statusLabel:SetText(err or L["CATMGR_ERROR"])
            statusLabel:SetTextColor(0.8, 0.2, 0.2, 1)
        end
    end

    addBtn:SetScript("OnClick", DoAdd)
    addInput:SetScript("OnEnterPressed", function(self)
        DoAdd()
        self:ClearFocus()
    end)

    SetActiveSection(currentSection)
    dialog:Show()
end
