-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/ui-category-manager.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T

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
    local scrollChild = nil

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
    addContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    addContainer:SetBackdropColor(T("BG_SECONDARY"))
    addContainer:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local addInput = CreateFrame("EditBox", nil, addContainer, "BackdropTemplate")
    addInput:SetPoint("TOPLEFT", addContainer, "TOPLEFT", 4, -3)
    addInput:SetPoint("BOTTOMRIGHT", addContainer, "BOTTOMRIGHT", -84, 3)
    addInput:SetHeight(24)
    addInput:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    addInput:SetBackdropColor(T("BG_PRIMARY"))
    addInput:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    addInput:SetFontObject("GameFontNormalSmall")
    addInput:SetTextColor(T("TEXT_PRIMARY"))
    addInput:SetTextInsets(6, 6, 2, 2)
    addInput:SetAutoFocus(false)

    local addBtn = ns.UI.CreateButton(nil, addContainer, L["CATMGR_ADD"], 76, 24)
    addBtn:SetPoint("RIGHT", addContainer, "RIGHT", -3, 0)

    local statusLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    statusLabel:SetPoint("TOPLEFT", addContainer, "BOTTOMLEFT", 2, -4)
    statusLabel:SetTextColor(T("TEXT_SECONDARY"))
    statusLabel:SetText("")

    local scrollContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    scrollContainer:SetPoint("TOPLEFT", addContainer, "BOTTOMLEFT", 0, -22)
    scrollContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -8, 4)
    scrollContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    scrollContainer:SetBackdropColor(T("BG_SECONDARY"))
    scrollContainer:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local TRACK_WIDTH = 10

    local scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer)
    scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -TRACK_WIDTH - 2, 2)
    scrollFrame:EnableMouseWheel(true)

    local scrollTrack = CreateFrame("Frame", nil, scrollContainer, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", scrollContainer, "TOPRIGHT", -2, -2)
    scrollTrack:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -2, 2)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollTrack:SetBackdropColor(T("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(30)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

    scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local scroll      = scrollFrame:GetVerticalScroll()
        local frameH      = scrollFrame:GetHeight()
        local contentH    = scrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            scrollThumb:SetHeight(scrollTrack:GetHeight())
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH  = scrollTrack:GetHeight()
        local thumbH  = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        local pct       = scroll / scrollRange
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(pct * maxOffset))
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current   = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        if delta > 0 then
            self:SetVerticalScroll(math.max(0, current - 30))
        else
            self:SetVerticalScroll(math.min(maxScroll, current + 30))
        end
        UpdateThumb()
    end)

    scrollFrame:SetScript("OnVerticalScroll", function() UpdateThumb() end)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
        UpdateThumb()
    end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnMouseUp",  function(self) self.dragging = false end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY      = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta     = self.dragStartY - curY
        local trackH    = scrollTrack:GetHeight()
        local thumbH    = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local newScroll   = self.dragStartScroll + (delta / maxOffset) * scrollRange
        scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateThumb()
    end)

    local function RefreshCategoryList()
        for _, row in ipairs(categoryRows) do
            row:Hide()
            row:SetParent(nil)
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
            row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })

            if isBuiltin then
                row:SetBackdropColor(T("BG_SECONDARY"))
            else
                row:SetBackdropColor(T("BG_PRIMARY"))
            end

            local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            nameFS:SetPoint("LEFT", row, "LEFT", 8, 0)
            nameFS:SetPoint("RIGHT", row, "RIGHT", -32, 0)
            nameFS:SetJustifyH("LEFT")
            nameFS:SetText(catName)

            if isBuiltin then
                nameFS:SetTextColor(T("TEXT_SECONDARY"))
            else
                nameFS:SetTextColor(T("TEXT_PRIMARY"))
            end

            if not isBuiltin then
                local delBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                delBtn:SetSize(20, 20)
                delBtn:SetPoint("RIGHT", row, "RIGHT", -4, 0)
                delBtn:SetBackdrop({
                    bgFile   = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8",
                    edgeSize = 1,
                })
                delBtn:SetBackdropColor(T("BTN_NORMAL"))
                delBtn:SetBackdropBorderColor(T("BTN_BORDER"))

                local delX = delBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                delX:SetPoint("CENTER")
                delX:SetText("X")
                delX:SetTextColor(T("TEXT_PRIMARY"))

                delBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(0.6, 0.1, 0.1, 1)
                    self:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
                    delX:SetTextColor(1, 1, 1, 1)
                end)
                delBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(T("BTN_NORMAL"))
                    self:SetBackdropBorderColor(T("BTN_BORDER"))
                    delX:SetTextColor(T("TEXT_PRIMARY"))
                end)
                delBtn:SetScript("OnClick", function()
                    local ok, err = RemoveCustomCategory(currentSection, catName)
                    if ok then
                        statusLabel:SetText(string.format(L["CATMGR_REMOVED"], catName))
                        statusLabel:SetTextColor(T("ACCENT_PRIMARY"))
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
        scrollFrame:SetVerticalScroll(0)
        UpdateThumb()
    end

    local function SetActiveSection(sectionKey)
        currentSection = sectionKey
        statusLabel:SetText("")
        addInput:SetText("")
        addInput:ClearFocus()

        for _, btn in ipairs(sectionButtons) do
            if btn.sectionKey == sectionKey then
                btn:SetBackdropColor(T("BG_ACTIVE"))
                btn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                btn.text:SetTextColor(T("ACCENT_PRIMARY"))
            else
                btn:SetBackdropColor(T("BTN_NORMAL"))
                btn:SetBackdropBorderColor(T("BTN_BORDER"))
                btn.text:SetTextColor(T("TEXT_PRIMARY"))
            end
        end

        RefreshCategoryList()
    end

    for i, sectionDef in ipairs(SECTIONS) do
        local btn = ns.UI.CreateButton(nil, sectionBtnContainer, L[sectionDef.label], btnWidth, 26)
        btn:SetPoint("TOPLEFT", sectionBtnContainer, "TOPLEFT", (i - 1) * (btnWidth + btnGap), 0)
        btn.sectionKey = sectionDef.key

        btn:SetScript("OnClick", function()
            SetActiveSection(sectionDef.key)
        end)
        btn:SetScript("OnEnter", function(self)
            if currentSection ~= self.sectionKey then
                self:SetBackdropColor(T("BTN_HOVER"))
                self:SetBackdropBorderColor(T("BTN_BORDER_HOVER"))
                self.text:SetTextColor(T("TEXT_ACCENT"))
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if currentSection ~= self.sectionKey then
                self:SetBackdropColor(T("BTN_NORMAL"))
                self:SetBackdropBorderColor(T("BTN_BORDER"))
                self.text:SetTextColor(T("TEXT_PRIMARY"))
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
            statusLabel:SetTextColor(T("ACCENT_PRIMARY"))
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
