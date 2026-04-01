local addonName, ns = ...
local OneWoWAltTracker = OneWoW_AltTracker
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.UI = ns.UI or {}

local function CollectAllCharacterKeys()
    local charMap = {}

    if _G.OneWoW_AltTracker_Character_DB and _G.OneWoW_AltTracker_Character_DB.characters then
        for charKey, data in pairs(_G.OneWoW_AltTracker_Character_DB.characters) do
            if type(charKey) == "string" then
                if not charMap[charKey] then
                    charMap[charKey] = {
                        key = charKey,
                        name = data.name or charKey:match("^(.+)-"),
                        realm = data.realm or charKey:match("-(.+)$"),
                        class = data.class,
                        className = data.className,
                        level = data.level,
                        lastLogin = data.lastLogin,
                        sources = {},
                    }
                end
                charMap[charKey].sources["Character"] = true
            end
        end
    end

    local simpleDBs = {
        { global = "OneWoW_AltTracker_Professions_DB", label = "Professions" },
        { global = "OneWoW_AltTracker_Endgame_DB",     label = "Endgame" },
        { global = "OneWoW_AltTracker_Storage_DB",      label = "Storage" },
        { global = "OneWoW_AltTracker_Auctions_DB",     label = "Auctions" },
        { global = "OneWoW_AltTracker_Collections_DB",  label = "Collections" },
    }

    for _, dbInfo in ipairs(simpleDBs) do
        local db = _G[dbInfo.global]
        if db and db.characters then
            for charKey, _ in pairs(db.characters) do
                if type(charKey) == "string" then
                    if not charMap[charKey] then
                        charMap[charKey] = {
                            key = charKey,
                            name = charKey:match("^(.+)-"),
                            realm = charKey:match("-(.+)$"),
                            sources = {},
                        }
                    end
                    charMap[charKey].sources[dbInfo.label] = true
                end
            end
        end
    end

    if _G.OneWoW_AltTracker_Accounting_DB and _G.OneWoW_AltTracker_Accounting_DB.transactions then
        local seen = {}
        for _, tx in ipairs(_G.OneWoW_AltTracker_Accounting_DB.transactions) do
            if tx.character and not seen[tx.character] then
                seen[tx.character] = true
                if not charMap[tx.character] then
                    charMap[tx.character] = {
                        key = tx.character,
                        name = tx.character:match("^(.+)-"),
                        realm = tx.character:match("-(.+)$"),
                        sources = {},
                    }
                end
                charMap[tx.character].sources["Accounting"] = true
            end
        end
    end

    if _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.db and _G.OneWoW_AltTracker.db.global then
        local favorites = _G.OneWoW_AltTracker.db.global.favorites
        if favorites then
            for charKey, _ in pairs(favorites) do
                if type(charKey) == "string" then
                    if not charMap[charKey] then
                        charMap[charKey] = {
                            key = charKey,
                            name = charKey:match("^(.+)-"),
                            realm = charKey:match("-(.+)$"),
                            sources = {},
                        }
                    end
                    charMap[charKey].sources["Favorites"] = true
                end
            end
        end
    end

    if _G.OneWoW_CatalogData_Quests_DB and _G.OneWoW_CatalogData_Quests_DB.completion then
        for charKey, _ in pairs(_G.OneWoW_CatalogData_Quests_DB.completion) do
            if type(charKey) == "string" then
                if not charMap[charKey] then
                    charMap[charKey] = {
                        key = charKey,
                        name = charKey:match("^(.+)-"),
                        realm = charKey:match("-(.+)$"),
                        sources = {},
                    }
                end
                charMap[charKey].sources["Quest Completion"] = true
            end
        end
    end

    if _G.OneWoW_CatalogData_Tradeskills_DB and _G.OneWoW_CatalogData_Tradeskills_DB.scanCache then
        for charKey, _ in pairs(_G.OneWoW_CatalogData_Tradeskills_DB.scanCache) do
            local name, realm = strsplit("-", charKey)
            if name and realm then
                if not charMap[charKey] then
                    charMap[charKey] = {
                        key = charKey,
                        name = name,
                        realm = realm,
                        sources = {},
                    }
                end
                charMap[charKey].sources["Tradeskill Scans"] = true
            end
        end
    end

    local sorted = {}
    for _, info in pairs(charMap) do
        table.insert(sorted, info)
    end
    table.sort(sorted, function(a, b)
        if (a.lastLogin or 0) ~= (b.lastLogin or 0) then
            return (a.lastLogin or 0) > (b.lastLogin or 0)
        end
        return (a.name or "") < (b.name or "")
    end)

    return sorted
end

local function PurgeCharacter(charKey)
    local purgedFrom = {}

    local simpleDBs = {
        { global = "OneWoW_AltTracker_Character_DB",    label = "Character" },
        { global = "OneWoW_AltTracker_Professions_DB",  label = "Professions" },
        { global = "OneWoW_AltTracker_Endgame_DB",      label = "Endgame" },
        { global = "OneWoW_AltTracker_Storage_DB",       label = "Storage" },
        { global = "OneWoW_AltTracker_Auctions_DB",      label = "Auctions" },
        { global = "OneWoW_AltTracker_Collections_DB",   label = "Collections" },
    }

    for _, dbInfo in ipairs(simpleDBs) do
        local db = _G[dbInfo.global]
        if db and db.characters and db.characters[charKey] then
            db.characters[charKey] = nil
            table.insert(purgedFrom, dbInfo.label)
        end
    end

    if _G.OneWoW_AltTracker_Accounting_DB and _G.OneWoW_AltTracker_Accounting_DB.transactions then
        local txs = _G.OneWoW_AltTracker_Accounting_DB.transactions
        local removed = 0
        for i = #txs, 1, -1 do
            if txs[i].character == charKey then
                table.remove(txs, i)
                removed = removed + 1
            end
        end
        if removed > 0 then
            table.insert(purgedFrom, "Accounting (" .. removed .. " transactions)")
        end
    end

    if _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.db and _G.OneWoW_AltTracker.db.global then
        local favorites = _G.OneWoW_AltTracker.db.global.favorites
        if favorites and favorites[charKey] then
            favorites[charKey] = nil
            table.insert(purgedFrom, "Favorites")
        end
    end

    if _G.OneWoW_CatalogData_Quests_DB and _G.OneWoW_CatalogData_Quests_DB.completion then
        if _G.OneWoW_CatalogData_Quests_DB.completion[charKey] then
            _G.OneWoW_CatalogData_Quests_DB.completion[charKey] = nil
            table.insert(purgedFrom, "Quest Completion")
        end
    end

    if _G.OneWoW_CatalogData_Tradeskills_DB and _G.OneWoW_CatalogData_Tradeskills_DB.scanCache then
        if _G.OneWoW_CatalogData_Tradeskills_DB.scanCache[charKey] then
            _G.OneWoW_CatalogData_Tradeskills_DB.scanCache[charKey] = nil
            table.insert(purgedFrom, "Tradeskill Scans")
        end
    end

    return purgedFrom
end

local function ShowManageAltsDialog()
    if _G.OneWoW_AT_ManageAltsDialog then
        _G.OneWoW_AT_ManageAltsDialog:Show()
        _G.OneWoW_AT_ManageAltsDialog:Raise()
        return
    end

    local characters = CollectAllCharacterKeys()

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_AT_ManageAltsDialog",
        title = "Manage Characters",
        width = 620,
        height = 560,
        onClose = function(frame) frame:Hide() end,
    })
    local dialog = result.frame
    dialog:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    dialog:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    _G.OneWoW_AT_ManageAltsDialog = dialog

    local content = result.contentFrame

    local descText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descText:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -10)
    descText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -10)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetSpacing(3)
    descText:SetText("Select characters to permanently remove from all OneWoW databases. This is for characters you have deleted or renamed in-game. A UI reload is required after removal.")
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local selectAllBtn = OneWoW_GUI:CreateButton(content, { text = "Select All", width = 90, height = 25 })
    selectAllBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -52)

    local deselectAllBtn = OneWoW_GUI:CreateButton(content, { text = "Deselect All", width = 90, height = 25 })
    deselectAllBtn:SetPoint("LEFT", selectAllBtn, "RIGHT", 6, 0)

    local countText = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    countText:SetPoint("RIGHT", content, "TOPRIGHT", -14, -64)
    countText:SetText(#characters .. " characters found across all databases")
    countText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local listBg = CreateFrame("Frame", nil, content, "BackdropTemplate")
    listBg:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -80)
    listBg:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 56)
    listBg:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    listBg:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    listBg:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local scrollFrame = CreateFrame("ScrollFrame", "OneWoW_AT_ManageAltsScroll", listBg, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", listBg, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", listBg, "BOTTOMRIGHT", -4, 4)

    OneWoW_GUI:StyleScrollBar(scrollFrame, { container = listBg })

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth() - 16)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w - 16)
    end)

    local ROW_H = 30
    local allCheckboxes = {}
    local yPos = 0

    if #characters == 0 then
        local emptyText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        emptyText:SetPoint("TOP", scrollChild, "TOP", 0, -40)
        emptyText:SetText("No characters found in any database.")
        emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end

    for i, charInfo in ipairs(characters) do
        charInfo.checked = false

        local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yPos)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, -yPos)
        row:SetHeight(ROW_H)
        row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)
        if i % 2 == 0 then
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        else
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        end

        local cb = OneWoW_GUI:CreateCheckbox(row, { label = "" })
        cb:SetSize(20, 20)
        cb:SetPoint("LEFT", row, "LEFT", 4, 0)
        if cb.label then cb.label:SetText("") end
        cb:SetScript("OnClick", function(self) charInfo.checked = self:GetChecked() end)
        allCheckboxes[#allCheckboxes + 1] = { cb = cb, info = charInfo }

        local nameFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameFS:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        local displayName = charInfo.name or charInfo.key
        nameFS:SetText(displayName)
        local classColor = charInfo.class and RAID_CLASS_COLORS[charInfo.class]
        if classColor then
            nameFS:SetTextColor(classColor.r, classColor.g, classColor.b)
        else
            nameFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end

        local realmFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        realmFS:SetPoint("LEFT", nameFS, "RIGHT", 6, 0)
        realmFS:SetText(charInfo.realm or "")
        realmFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        local infoStr = ""
        if charInfo.level and charInfo.level > 0 then
            infoStr = "Lv" .. charInfo.level
        end
        if charInfo.className then
            if infoStr ~= "" then infoStr = infoStr .. " " end
            infoStr = infoStr .. charInfo.className
        end

        local sourceCount = 0
        for _ in pairs(charInfo.sources) do sourceCount = sourceCount + 1 end
        if infoStr ~= "" then infoStr = infoStr .. "  " end
        infoStr = infoStr .. "(" .. sourceCount .. " db" .. (sourceCount > 1 and "s" or "") .. ")"

        local infoFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        infoFS:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        infoFS:SetText(infoStr)
        infoFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row:EnableMouse(true)
        row:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            local sources = {}
            for src, _ in pairs(charInfo.sources) do table.insert(sources, src) end
            table.sort(sources)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(charInfo.key, 1, 0.82, 0)
            GameTooltip:AddLine("Found in:", OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            for _, src in ipairs(sources) do
                GameTooltip:AddLine("  " .. src, OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            if i % 2 == 0 then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            else
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
            end
            GameTooltip:Hide()
        end)
        row:SetScript("OnMouseDown", function()
            charInfo.checked = not charInfo.checked
            cb:SetChecked(charInfo.checked)
        end)

        yPos = yPos + ROW_H + 1
    end

    scrollChild:SetHeight(math.max(1, yPos))

    selectAllBtn:SetScript("OnClick", function()
        for _, entry in ipairs(allCheckboxes) do
            entry.info.checked = true
            entry.cb:SetChecked(true)
        end
    end)

    deselectAllBtn:SetScript("OnClick", function()
        for _, entry in ipairs(allCheckboxes) do
            entry.info.checked = false
            entry.cb:SetChecked(false)
        end
    end)

    local btnDivider = content:CreateTexture(nil, "ARTWORK")
    btnDivider:SetHeight(1)
    btnDivider:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 1, 50)
    btnDivider:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -1, 50)
    btnDivider:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local deleteBtn = OneWoW_GUI:CreateButton(content, { text = "Delete Selected", width = 160, height = 32 })
    deleteBtn:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 14, 10)
    deleteBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
    deleteBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
    deleteBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    deleteBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)
    deleteBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
        self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end)

    local cancelBtn = OneWoW_GUI:CreateButton(content, { text = "Cancel", width = 120, height = 32 })
    cancelBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 10)
    cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

    deleteBtn:SetScript("OnClick", function()
        local selected = {}
        for _, charInfo in ipairs(characters) do
            if charInfo.checked then
                table.insert(selected, charInfo)
            end
        end

        if #selected == 0 then
            print("|cFFFFD100OneWoW - AltTracker:|r No characters selected.")
            return
        end

        local nameList = {}
        for idx, info in ipairs(selected) do
            if idx <= 5 then
                table.insert(nameList, info.key)
            end
        end
        local displayNames = table.concat(nameList, ", ")
        if #selected > 5 then
            displayNames = displayNames .. " (+" .. (#selected - 5) .. " more)"
        end

        StaticPopupDialogs["ONEWOW_AT_DELETE_CHARACTERS"] = {
            text = "Permanently delete " .. #selected .. " character(s) from ALL OneWoW databases?\n\n|cFFFF6666" .. displayNames .. "|r\n\nThis cannot be undone. A UI reload will follow.",
            button1 = "Delete",
            button2 = "Cancel",
            OnAccept = function()
                local totalPurged = 0
                for _, charInfo in ipairs(selected) do
                    local purgedFrom = PurgeCharacter(charInfo.key)
                    if #purgedFrom > 0 then
                        totalPurged = totalPurged + 1
                    end
                end
                print("|cFFFFD100OneWoW - AltTracker:|r Removed " .. totalPurged .. " character(s). Reloading...")
                ReloadUI()
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("ONEWOW_AT_DELETE_CHARACTERS")
    end)

    ns.UI.ApplyFontToFrame(result.frame)
    dialog:Show()
end

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(parent, { width = parent:GetWidth(), height = parent:GetHeight() })
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local yOffset = -10

    if not _G.OneWoW then
        yOffset = OneWoW_GUI:CreateSettingsPanel(scrollContent, { yOffset = yOffset, addonName = "OneWoW_AltTracker" })
    end

    local manageSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = "Manage Characters", yOffset = yOffset })
    yOffset = manageSection.bottomY - 8

    local manageDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    manageDesc:SetPoint("TOPLEFT", 15, yOffset)
    manageDesc:SetPoint("TOPRIGHT", -15, yOffset)
    manageDesc:SetJustifyH("LEFT")
    manageDesc:SetWordWrap(true)
    manageDesc:SetText("Remove deleted or renamed characters from all OneWoW databases. Opens a dialog to select which characters to purge.")
    manageDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    manageDesc:SetSpacing(3)

    C_Timer.After(0.01, function()
        local textHeight = manageDesc:GetStringHeight()
        yOffset = yOffset - textHeight - 12
    end)
    yOffset = yOffset - 20

    local manageBtn = OneWoW_GUI:CreateButton(scrollContent, { text = "Manage Characters", width = 200, height = 35 })
    manageBtn:SetPoint("TOPLEFT", 25, yOffset)
    manageBtn:SetScript("OnClick", function()
        ShowManageAltsDialog()
    end)

    yOffset = yOffset - 50

    local dbSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = "Database Manager", yOffset = yOffset })
    yOffset = dbSection.bottomY - 8

    local dbDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dbDesc:SetPoint("TOPLEFT", 15, yOffset)
    dbDesc:SetPoint("TOPRIGHT", -15, yOffset)
    dbDesc:SetJustifyH("LEFT")
    dbDesc:SetWordWrap(true)
    dbDesc:SetText("Manage addon databases. Click Reset to completely clear a database and force a UI reload.")
    dbDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    dbDesc:SetSpacing(3)

    C_Timer.After(0.01, function()
        local textHeight = dbDesc:GetStringHeight()
        yOffset = yOffset - textHeight - 12
    end)
    yOffset = yOffset - 25

    local databases = {
        { key = "OneWoW_AltTracker", name = "AltTracker Core", desc = "Main addon settings and UI state" },
        { key = "OneWoW_AltTracker_Character", name = "Character Data", desc = "Character info, stats, equipment, and progression" },
        { key = "OneWoW_AltTracker_Storage", name = "Storage & Mail", desc = "Bags, banks, guild banks, and mail data" },
        { key = "OneWoW_AltTracker_Professions", name = "Professions", desc = "Profession data for all characters" },
        { key = "OneWoW_AltTracker_Endgame", name = "Endgame Content", desc = "Mythic+, raids, currencies, and gear" },
        { key = "OneWoW_AltTracker_Accounting", name = "Accounting", desc = "Gold tracking and transactions" },
        { key = "OneWoW_AltTracker_Auctions", name = "Auctions", desc = "Auction house history" },
        { key = "OneWoW_AltTracker_Collections", name = "Collections", desc = "Mounts, pets, and transmog" },
    }

    local function GetTableSize(dbKey)
        if not _G[dbKey .. "_DB"] then return 0 end
        local db = _G[dbKey .. "_DB"]

        if db.characters then
            local size = 0
            for _ in pairs(db.characters) do size = size + 1 end
            return size
        else
            local size = 0
            for _ in pairs(db) do size = size + 1 end
            return math.max(0, size - 5)
        end
    end

    local function CreateDatabaseEntry(parent, dbData, yPos)
        local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        container:SetPoint("TOPLEFT", parent, "TOPLEFT", 15, yPos)
        container:SetSize(770, 60)
        container:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
        container:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        container:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))

        local nameText = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("TOPLEFT", 12, -10)
        nameText:SetText(dbData.name)
        nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

        local descText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        descText:SetPoint("TOPLEFT", 12, -28)
        descText:SetText(dbData.desc)
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        descText:SetWidth(400)

        local sizeText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        sizeText:SetPoint("TOPLEFT", 450, -18)

        local function UpdateSize()
            local db = _G[dbData.key .. "_DB"]
            if db then
                local size = GetTableSize(dbData.key)
                sizeText:SetText("Entries: " .. size)
                sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            else
                sizeText:SetText("Not Loaded")
                sizeText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
            end
        end
        UpdateSize()

        local resetBtn = OneWoW_GUI:CreateButton(container, { text = "Reset", width = 75, height = 28 })
        resetBtn:SetPoint("TOPRIGHT", -12, -16)
        resetBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
        resetBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
        if resetBtn.text then resetBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end

        resetBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
            if self.text then self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
        end)

        resetBtn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
            if self.text then self.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
        end)

        resetBtn:SetScript("OnClick", function()
            StaticPopupDialogs["WNAT_RESET_DB_CONFIRM"] = {
                text = "Are you sure you want to reset " .. dbData.name .. "?\n\nThis will permanently delete all data in this database.",
                button1 = "Reset",
                button2 = "Cancel",
                OnAccept = function()
                    _G[dbData.key .. "_DB"] = nil
                    C_UI.Reload()
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
                preferredIndex = 3,
            }
            StaticPopup_Show("WNAT_RESET_DB_CONFIRM")
        end)

        return 65
    end

    for _, dbData in ipairs(databases) do
        local height = CreateDatabaseEntry(scrollContent, dbData, yOffset)
        yOffset = yOffset - height - 8
    end

    yOffset = yOffset - 10

    local overrideSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = L["OVERRIDE_BTN"], yOffset = yOffset })
    yOffset = overrideSection.bottomY - 8

    local overrideDesc = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    overrideDesc:SetPoint("TOPLEFT", 15, yOffset)
    overrideDesc:SetPoint("TOPRIGHT", -15, yOffset)
    overrideDesc:SetJustifyH("LEFT")
    overrideDesc:SetWordWrap(true)
    overrideDesc:SetText(L["OVERRIDE_SYSTEM_DESC"])
    overrideDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    overrideDesc:SetSpacing(3)

    C_Timer.After(0.01, function()
        local textHeight = overrideDesc:GetStringHeight()
        yOffset = yOffset - textHeight - 12
    end)
    yOffset = yOffset - 50

    local overrideBtn = OneWoW_GUI:CreateButton(scrollContent, { text = L["OVERRIDE_BTN"], width = 280, height = 35 })
    overrideBtn:SetPoint("TOPLEFT", 25, yOffset)
    overrideBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    if overrideBtn.text then overrideBtn.text:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")) end

    local overrideDialog = nil

    local KNOWN_BOSS_NAMES = {}

    local function GetCurrencyIDs()
        if OneWoWAltTracker.db.global.overrides and
           OneWoWAltTracker.db.global.overrides.progress and
           OneWoWAltTracker.db.global.overrides.progress.trackedCurrencyIDs then
            return OneWoWAltTracker.db.global.overrides.progress.trackedCurrencyIDs
        end
        return {}
    end

    local function GetBossQuestIDs()
        if OneWoWAltTracker.db.global.overrides and
           OneWoWAltTracker.db.global.overrides.progress and
           OneWoWAltTracker.db.global.overrides.progress.worldBossQuestIDs then
            return OneWoWAltTracker.db.global.overrides.progress.worldBossQuestIDs
        end
        return {}
    end

    local function GetOrCreateOverrideDialog()
        if overrideDialog and overrideDialog:IsShown() then
            overrideDialog:Raise()
            return
        end

        if overrideDialog then
            overrideDialog:Show()
            overrideDialog:Raise()
            return
        end

        local result = OneWoW_GUI:CreateDialog({
            name = "OneWoWOverrideDialog",
            title = L["OVERRIDE_SYSTEM_TITLE"],
            width = 600,
            height = 660,
            titleHeight = 26,
            showScrollFrame = true,
        })
        overrideDialog = result.frame
        local scrollFrame = result.scrollFrame
        local sc = result.scrollContent

        local dy = -8

        local descText = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        descText:SetPoint("TOPLEFT", 10, dy)
        descText:SetPoint("TOPRIGHT", -10, dy)
        descText:SetJustifyH("LEFT")
        descText:SetWordWrap(true)
        descText:SetText(L["OVERRIDE_SYSTEM_DESC"])
        descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        descText:SetSpacing(3)
        dy = dy - 55

        local function MakeListRow(parent, col1, col2, yPos, r, g, b)
            local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
            row:SetPoint("TOPLEFT", 8, yPos)
            row:SetPoint("TOPRIGHT", -8, yPos)
            row:SetHeight(28)
            row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

            local t1 = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            t1:SetPoint("LEFT", row, "LEFT", 8, 0)
            t1:SetWidth(80)
            t1:SetText(col1)
            t1:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local t2 = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            t2:SetPoint("LEFT", row, "LEFT", 92, 0)
            t2:SetPoint("RIGHT", row, "RIGHT", -90, 0)
            t2:SetJustifyH("LEFT")
            t2:SetText(col2)
            t2:SetTextColor(r or OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            row.nameText = t2

            return row
        end

        local function MakeRemoveBtn(parent, row, onClick)
            local btn = OneWoW_GUI:CreateButton(row, { text = L["OVERRIDE_REMOVE"] .. " Remove", width = 60, height = 20 })
            btn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
            btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
            if btn.text then btn.text:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")) end
            btn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER")) end)
            btn:SetScript("OnLeave", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL")) end)
            btn:SetScript("OnClick", onClick)
            return btn
        end

        local currencyListFrames = {}
        local bossListFrames = {}

        local function RebuildCurrencyList()
            for _, f in ipairs(currencyListFrames) do f:Hide(); f:SetParent(nil) end
            wipe(currencyListFrames)

            local ids = GetCurrencyIDs()
            local startDY = sc.currencyListStartDY or dy
            local ldY = startDY
            for i, id in ipairs(ids) do
                local info = C_CurrencyInfo.GetCurrencyInfo(id)
                local nm = (info and info.name) or ("Currency ID: " .. id)
                local row = MakeListRow(sc, "ID: " .. id, nm, ldY)
                MakeRemoveBtn(sc, row, function()
                    table.remove(ids, i)
                    RebuildCurrencyList()
                end)
                ldY = ldY - 32
                table.insert(currencyListFrames, row)
            end
            if sc.currencyAddRow then
                sc.currencyAddRow:ClearAllPoints()
                sc.currencyAddRow:SetPoint("TOPLEFT", 8, ldY)
                sc.currencyAddRow:SetPoint("TOPRIGHT", -8, ldY)
                ldY = ldY - 36
            end
            sc.currencyListEndDY = ldY
            if sc.bossListStartDY then
                local bossStartDY = ldY - 8
                sc.bossListStartDY = bossStartDY
                RebuildBossList()
            end
        end

        local function RebuildBossList()
            for _, f in ipairs(bossListFrames) do f:Hide(); f:SetParent(nil) end
            wipe(bossListFrames)

            local ids = GetBossQuestIDs()
            local startDY = sc.bossListStartDY or (sc.currencyListEndDY or dy) - 80
            local ldY = startDY
            for i, id in ipairs(ids) do
                local nm = KNOWN_BOSS_NAMES[id] or C_QuestLog.GetTitleForQuestID(id) or ("Quest ID: " .. id)
                local done = C_QuestLog.IsQuestFlaggedCompleted(id)
                local r, g, b
                if done then
                    r, g, b = OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED")
                else
                    r, g, b = OneWoW_GUI:GetThemeColor("TEXT_PRIMARY")
                end
                local row = MakeListRow(sc, "Quest: " .. id, nm, ldY, r, g, b)
                if done then
                    local doneTag = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    doneTag:SetPoint("RIGHT", row, "RIGHT", -70, 0)
                    doneTag:SetText("Done")
                    doneTag:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                end
                MakeRemoveBtn(sc, row, function()
                    table.remove(ids, i)
                    RebuildBossList()
                end)
                ldY = ldY - 32
                table.insert(bossListFrames, row)
            end
            if sc.bossAddRow then
                sc.bossAddRow:ClearAllPoints()
                sc.bossAddRow:SetPoint("TOPLEFT", 8, ldY)
                sc.bossAddRow:SetPoint("TOPRIGHT", -8, ldY)
                ldY = ldY - 36
            end
            local noteText = sc.noteText
            if noteText then
                noteText:ClearAllPoints()
                noteText:SetPoint("TOPLEFT", 12, ldY - 4)
                ldY = ldY - 26
            end
            sc:SetHeight(math.abs(ldY) + 20)
        end

        local sec1 = OneWoW_GUI:CreateSectionHeader(sc, { title = L["OVERRIDE_SECTION_SUMMARY"], yOffset = dy })
        dy = sec1.bottomY - 6
        local noneText = sc:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        noneText:SetPoint("TOPLEFT", 15, dy)
        noneText:SetText(L["OVERRIDE_NO_SETTINGS"])
        noneText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        dy = dy - 26

        local sec2 = OneWoW_GUI:CreateSectionHeader(sc, { title = L["OVERRIDE_TRACKED_CURRENCIES"], yOffset = dy })
        dy = sec2.bottomY - 6
        sc.currencyListStartDY = dy

        local addCurrRow = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        addCurrRow:SetHeight(28)
        addCurrRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
        addCurrRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        addCurrRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        local addCurrLabel = addCurrRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        addCurrLabel:SetPoint("LEFT", 8, 0)
        addCurrLabel:SetText("Add Currency ID:")
        addCurrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        local addCurrBox = OneWoW_GUI:CreateEditBox(addCurrRow, { width = 90, height = 22 })
        addCurrBox:SetPoint("LEFT", addCurrLabel, "RIGHT", 8, 0)
        addCurrBox:SetNumeric(true)
        addCurrBox:SetMaxLetters(8)
        local addCurrBtn = OneWoW_GUI:CreateButton(addCurrRow, { text = "Add", width = 50, height = 22 })
        addCurrBtn:SetPoint("LEFT", addCurrBox, "RIGHT", 6, 0)
        addCurrBtn:SetScript("OnClick", function()
            local val = tonumber(addCurrBox:GetText()) or 0
            if val > 0 then
                local ids = GetCurrencyIDs()
                local exists = false
                for _, v in ipairs(ids) do if v == val then exists = true; break end end
                if not exists then
                    table.insert(ids, val)
                    addCurrBox:SetText("")
                    RebuildCurrencyList()
                end
            end
        end)
        addCurrBox:SetScript("OnEnterPressed", function(self) addCurrBtn:Click() end)
        sc.currencyAddRow = addCurrRow

        local sec3StartDY = dy
        RebuildCurrencyList()

        local sec3DY = (sc.currencyListEndDY or dy) - 12
        local sec3 = OneWoW_GUI:CreateSectionHeader(sc, { title = L["OVERRIDE_WORLD_BOSS_QUEST"], yOffset = sec3DY })
        sc.bossListStartDY = sec3.bottomY - 6
        sc.bossSecHeader = sec3

        local addBossRow = CreateFrame("Frame", nil, sc, "BackdropTemplate")
        addBossRow:SetHeight(28)
        addBossRow:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
        addBossRow:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        addBossRow:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        local addBossLabel = addBossRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        addBossLabel:SetPoint("LEFT", 8, 0)
        addBossLabel:SetText("Add Quest ID:")
        addBossLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        local addBossBox = OneWoW_GUI:CreateEditBox(addBossRow, { width = 90, height = 22 })
        addBossBox:SetPoint("LEFT", addBossLabel, "RIGHT", 8, 0)
        addBossBox:SetNumeric(true)
        addBossBox:SetMaxLetters(8)
        local addBossBtn = OneWoW_GUI:CreateButton(addBossRow, { text = "Add", width = 50, height = 22 })
        addBossBtn:SetPoint("LEFT", addBossBox, "RIGHT", 6, 0)
        addBossBtn:SetScript("OnClick", function()
            local val = tonumber(addBossBox:GetText()) or 0
            if val > 0 then
                local ids = GetBossQuestIDs()
                local exists = false
                for _, v in ipairs(ids) do if v == val then exists = true; break end end
                if not exists then
                    table.insert(ids, val)
                    addBossBox:SetText("")
                    RebuildBossList()
                end
            end
        end)
        addBossBox:SetScript("OnEnterPressed", function(self) addBossBtn:Click() end)
        sc.bossAddRow = addBossRow

        local noteText = sc:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        noteText:SetWidth(540)
        noteText:SetJustifyH("LEFT")
        noteText:SetWordWrap(true)
        noteText:SetText(L["OVERRIDE_CURRENCY_LOGIN_NOTE"])
        noteText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        sc.noteText = noteText

        RebuildBossList()

        local resetBtn = OneWoW_GUI:CreateButton(overrideDialog, { text = L["OVERRIDE_RESET_DEFAULTS"], width = 160, height = 30 })
        resetBtn:ClearAllPoints()
        resetBtn:SetPoint("BOTTOMLEFT", overrideDialog, "BOTTOMLEFT", 10, 10)
        resetBtn:SetScript("OnClick", function()
            OneWoWAltTracker.db.global.overrides.progress.trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316}
            OneWoWAltTracker.db.global.overrides.progress.worldBossQuestIDs = {}
            RebuildCurrencyList()
            RebuildBossList()
        end)

        local closeBtn2 = OneWoW_GUI:CreateButton(overrideDialog, { text = L["OVERRIDE_CLOSE"], width = 100, height = 30 })
        closeBtn2:ClearAllPoints()
        closeBtn2:SetPoint("BOTTOMRIGHT", overrideDialog, "BOTTOMRIGHT", -10, 10)
        closeBtn2:SetScript("OnClick", function() overrideDialog:Hide() end)

        ns.UI.ApplyFontToFrame(overrideDialog)
        overrideDialog:Show()
        overrideDialog:Raise()
    end

    overrideBtn:SetScript("OnClick", GetOrCreateOverrideDialog)

    yOffset = yOffset - 50

    local checklistSection = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = L["SEASON_CHECKLIST_BTN"], yOffset = yOffset })
    yOffset = checklistSection.bottomY - 8

    local checklistDescText = scrollContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    checklistDescText:SetPoint("TOPLEFT", 15, yOffset)
    checklistDescText:SetPoint("TOPRIGHT", -15, yOffset)
    checklistDescText:SetJustifyH("LEFT")
    checklistDescText:SetWordWrap(true)
    checklistDescText:SetText(L["SEASON_CHECKLIST_DESC"])
    checklistDescText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    checklistDescText:SetSpacing(3)
    yOffset = yOffset - 50

    local checklistBtn = OneWoW_GUI:CreateButton(scrollContent, { text = L["SEASON_CHECKLIST_BTN"], width = 280, height = 35 })
    checklistBtn:ClearAllPoints()
    checklistBtn:SetPoint("TOPLEFT", 25, yOffset)
    checklistBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local checklistDialog = nil

    local function GetCurrencyIDsDisplay()
        local ids = (OneWoWAltTracker.db.global.overrides and
                     OneWoWAltTracker.db.global.overrides.progress and
                     OneWoWAltTracker.db.global.overrides.progress.trackedCurrencyIDs) or {}
        local parts = {}
        for _, id in ipairs(ids) do
            local info = C_CurrencyInfo.GetCurrencyInfo(id)
            table.insert(parts, (info and info.name or "ID " .. id) .. " (" .. id .. ")")
        end
        return #parts > 0 and table.concat(parts, ", ") or "None"
    end

    local function GetBossQuestIDsDisplay()
        local BOSS_NAMES = {}
        local ids = (OneWoWAltTracker.db.global.overrides and
                     OneWoWAltTracker.db.global.overrides.progress and
                     OneWoWAltTracker.db.global.overrides.progress.worldBossQuestIDs) or {}
        local parts = {}
        for _, id in ipairs(ids) do
            table.insert(parts, (BOSS_NAMES[id] or C_QuestLog.GetTitleForQuestID(id) or "Unknown") .. " (Q:" .. id .. ")")
        end
        return #parts > 0 and table.concat(parts, ", ") or "None"
    end

    local CHECKLIST_ITEMS = {
        {section = "Summary Tab"},
        {key = "s_maxlevel",  label = "Verify Max Player Level",                   auto = true,  value = function() return "Level " .. (GetMaxPlayerLevel and GetMaxPlayerLevel() or "?") end, file = "Auto-detected via API"},
        {key = "s_ilvl",      label = "Verify iLvl range for new content",          auto = false, value = function() return "Manual check required" end, file = "No single file - check new content tooltips"},
        {key = "s_toc",       label = "Update ## Interface in all TOC files",        auto = false, value = function() local v, b = GetBuildInfo(); return "Current build: " .. (b or "?") end, file = "All .toc files"},

        {section = "Progress Tab"},
        {key = "p_currencies", label = "Verify Tracked Currency IDs (change per season)", auto = false, value = GetCurrencyIDsDisplay, file = "OneWoW_AltTracker/Core/Database.lua + Override System"},
        {key = "p_bosses",    label = "Verify World Boss Quest IDs",                auto = false, value = GetBossQuestIDsDisplay, file = "OneWoW_AltTracker_Endgame/Modules/WorldBoss.lua + Database.lua"},
        {key = "p_boss_names",label = "Update KNOWN_BOSS_NAMES lookup table",       auto = false, value = function() return "See WorldBoss.lua and t-progress.lua" end, file = "OneWoW_AltTracker_Endgame/Modules/WorldBoss.lua, UI/t-progress.lua, UI/t-settings.lua"},
        {key = "p_dungeons",  label = "M+ Dungeon List",                            auto = true,  value = function() return "Auto via C_ChallengeMode.GetMapTable()" end, file = "No change needed"},
        {key = "p_raids",     label = "Raid Lockout Tracking",                      auto = true,  value = function() return "Auto via GetSavedInstanceInfo()" end, file = "No change needed"},
        {key = "p_vault",     label = "Great Vault Activity Types",                 auto = true,  value = function() return "Auto via C_WeeklyRewards.GetActivities()" end, file = "No change needed"},

        {section = "Bank / Storage Tab"},
        {key = "b_bags",      label = "Bag container IDs: 0=Backpack, 1-4=Bags, 5=Reagent", auto = true, value = function() return "Verified - using C_Container.GetContainerNumSlots(0-5)" end, file = "OneWoW_AltTracker_Storage/Modules/Bags.lua"},
        {key = "b_pbank",     label = "Personal Bank bag IDs (6-10)",               auto = true,  value = function() return "Using bankBagID = 5 + tabIndex" end, file = "OneWoW_AltTracker_Storage/Modules/PersonalBank.lua"},
        {key = "b_warband",   label = "Warband Bank bag IDs (12+)",                 auto = true,  value = function() return "Using warbandBagID = 11 + tabIndex" end, file = "OneWoW_AltTracker_Storage/Modules/WarbandBank.lua"},
        {key = "b_maxslots",  label = "Verify max bag/bank slot counts still valid", auto = false, value = function() return "Manual check - Blizzard may add new bank tabs" end, file = "Check above files if new tab types added"},

        {section = "Equipment Tab"},
        {key = "e_slots",     label = "Verify equipment slot IDs 1-19 still valid", auto = false, value = function() return "Standard slots (Head=1 through Tabard=19)" end, file = "OneWoW_AltTracker_Character/Modules/Equipment.lua"},
        {key = "e_tier",      label = "Update tier set item tracking for new season", auto = false, value = function() return "Check if new tier bonuses use new slot IDs" end, file = "UI/t-equipment.lua"},
        {key = "e_ilvl",      label = "Verify GetAverageItemLevel() still returns correct values", auto = true, value = function() return "API call - verify in-game accuracy" end, file = "OneWoW_AltTracker_Character/Modules/Equipment.lua"},

        {section = "Professions Tab"},
        {key = "pr_cooldowns", label = "Verify profession cooldown names/IDs",       auto = false, value = function() return "Manual check - cooldowns change per expansion" end, file = "OneWoW_AltTracker_Character/Modules/ (professions file)"},
        {key = "pr_maxskill",  label = "Verify max skill level (100 per expansion)", auto = false, value = function() return "Check if max profession level changed" end, file = "Professions collection module"},
        {key = "pr_tools",     label = "Verify tool/accessory slot IDs unchanged",   auto = false, value = function() return "Tool slots can change each expansion" end, file = "Professions collection module"},
        {key = "pr_new",       label = "Check for any new professions added",        auto = false, value = function() return "Unlikely but verify with GetNumSkillLines()" end, file = "Professions collection module"},

        {section = "Auctions Tab"},
        {key = "au_nothing",   label = "No seasonal updates required",               auto = true,  value = function() return "Auction API is stable" end, file = "Nothing to change"},

        {section = "Financials Tab"},
        {key = "fi_events",    label = "Verify gold tracking events still fire",     auto = false, value = function() return "PLAYER_MONEY, MAIL_SEND_SUCCESS, AUCTION_HOUSE_SHOW" end, file = "OneWoW_AltTracker_Accounting/"},
        {key = "fi_costs",     label = "Verify repair/vendor cost event names",      auto = false, value = function() return "MERCHANT_CLOSED and related events" end, file = "OneWoW_AltTracker_Accounting/"},

        {section = "Items Tab"},
        {key = "it_ah",        label = "Verify AH scan connection still works",       auto = false, value = function() return "Test with /at then Items tab" end, file = "OneWoW_AltTracker_Storage/Modules/AHScanner.lua"},

        {section = "Profiles / Settings"},
        {key = "ps_backup",    label = "Verify saved variable backup and restore",    auto = false, value = function() return "Test export/import of profile data" end, file = "OneWoW_AltTracker/Core/"},
        {key = "ps_keybinds",  label = "Check for new WoW keybind categories",       auto = false, value = function() return "GetNumBindings() - check for new binding types" end, file = "OneWoW_AltTracker_Character/Modules/ActionBars.lua"},
        {key = "ps_settings",  label = "Check for new WoW settings modules/panels",  auto = false, value = function() return "Blizzard may add new CVars or settings panels" end, file = "OneWoW_AltTracker_Character/Modules/"},

        {section = "General / Compatibility"},
        {key = "g_interface",  label = "Update ## Interface version in all TOC files", auto = false, value = function() local _, _, _, intVersion = GetBuildInfo(); return "Current: " .. (intVersion or "?") end, file = "All .toc files - ## Interface line"},
        {key = "g_midnight",   label = "Check MIDNIGHT.md for Midnight compatibility changes", auto = false, value = function() return "Secure buttons, action handling, etc." end, file = "See /home/pals/w2xyz/wow/MIDNIGHT.md"},
        {key = "g_api",        label = "Run full API verification pass on new APIs used", auto = false, value = function() return "Verify all WoW APIs on warcraft.wiki.gg" end, file = "All collection module files"},
    }

    local function OpenChecklistDialog()
        if checklistDialog and checklistDialog:IsShown() then
            checklistDialog:Raise()
            return
        end
        if checklistDialog then
            checklistDialog:Show()
            checklistDialog:Raise()
            return
        end

        local clResult = OneWoW_GUI:CreateDialog({
            name = "OneWoWSeasonChecklist",
            title = L["SEASON_CHECKLIST_TITLE"],
            width = 780,
            height = 700,
            titleHeight = 26,
            showScrollFrame = true,
        })
        checklistDialog = clResult.frame
        local scrollFrame2 = clResult.scrollFrame
        local sc2 = clResult.scrollContent

        local cdy = -8
        local ROW_H = 54
        local checkedBoxes = {}

        for _, item in ipairs(CHECKLIST_ITEMS) do
            if item.section then
                local sh = OneWoW_GUI:CreateSectionHeader(sc2, { title = item.section, yOffset = cdy })
                cdy = sh.bottomY - 6
            else
                local row = CreateFrame("Frame", nil, sc2, "BackdropTemplate")
                row:SetPoint("TOPLEFT", 8, cdy)
                row:SetPoint("TOPRIGHT", -8, cdy)
                row:SetHeight(ROW_H)
                row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)

                local isChecked = OneWoWAltTracker.db.global.seasonChecklist[item.key] == true
                local isAuto = item.auto == true

                if isChecked then
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                elseif isAuto then
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    local br, bg, bb = OneWoW_GUI:GetThemeColor("BTN_BORDER")
                    row:SetBackdropBorderColor(br, bg, bb, 0.5)
                else
                    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                end

                local checkBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                checkBtn:SetSize(22, 22)
                checkBtn:SetPoint("LEFT", row, "LEFT", 6, 0)
                checkBtn:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
                if isChecked then
                    checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                    checkBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                elseif isAuto then
                    checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_HOVER"))
                    local br, bg, bb = OneWoW_GUI:GetThemeColor("BTN_BORDER")
                    checkBtn:SetBackdropBorderColor(br, bg, bb, 0.5)
                else
                    checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    checkBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
                end
                local checkMark = checkBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                checkMark:SetPoint("CENTER")
                checkMark:SetText(isChecked and "X" or (isAuto and "A" or " "))
                if isChecked then
                    checkMark:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                elseif isAuto then
                    checkMark:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_DISABLED"))
                else
                    checkMark:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                end

                local labelText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                labelText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -6)
                labelText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -6)
                labelText:SetJustifyH("LEFT")
                labelText:SetText(item.label)
                if isChecked then
                    labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                else
                    labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end

                local valStr = item.value and item.value() or ""
                local valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                valueText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -22)
                valueText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -22)
                valueText:SetJustifyH("LEFT")
                valueText:SetWordWrap(true)
                valueText:SetText(L["SEASON_CURRENT"] .. " " .. valStr)
                if isAuto then
                    valueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                else
                    valueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                end

                local fileText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                fileText:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -37)
                fileText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -37)
                fileText:SetJustifyH("LEFT")
                fileText:SetText(L["SEASON_FILE"] .. " " .. item.file)
                fileText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                if not isAuto then
                    checkBtn:EnableMouse(true)
                    checkBtn:SetScript("OnClick", function()
                        local nowChecked = not (OneWoWAltTracker.db.global.seasonChecklist[item.key] == true)
                        OneWoWAltTracker.db.global.seasonChecklist[item.key] = nowChecked
                        if nowChecked then
                            checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                            checkBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER_HOVER"))
                            checkMark:SetText("X")
                            checkMark:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_FEATURES_ENABLED"))
                            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_BORDER"))
                            labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                        else
                            checkBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                            checkBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
                            checkMark:SetText(" ")
                            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                            labelText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                        end
                    end)
                    checkBtn:SetScript("OnEnter", function(self) self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER")) end)
                    checkBtn:SetScript("OnLeave", function(self)
                        local c = OneWoWAltTracker.db.global.seasonChecklist[item.key]
                        if c then
                            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_NORMAL"))
                        else
                            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                        end
                    end)
                end

                table.insert(checkedBoxes, {key = item.key, btn = checkBtn, mark = checkMark, rowFrame = row, label = labelText, isAuto = isAuto})
                cdy = cdy - (ROW_H + 4)
            end
        end

        sc2:SetHeight(math.abs(cdy) + 20)

        local clearBtn = OneWoW_GUI:CreateButton(checklistDialog, { text = L["SEASON_CHECKLIST_CLEAR"], width = 130, height = 30 })
        clearBtn:ClearAllPoints()
        clearBtn:SetPoint("BOTTOMLEFT", checklistDialog, "BOTTOMLEFT", 10, 10)
        clearBtn:SetScript("OnClick", function()
            OneWoWAltTracker.db.global.seasonChecklist = {}
            for _, entry in ipairs(checkedBoxes) do
                if not entry.isAuto then
                    entry.btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                    entry.btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
                    entry.mark:SetText(" ")
                    entry.rowFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                    entry.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end
            end
        end)

        local closeBtnCL = OneWoW_GUI:CreateButton(checklistDialog, { text = L["OVERRIDE_CLOSE"], width = 100, height = 30 })
        closeBtnCL:ClearAllPoints()
        closeBtnCL:SetPoint("BOTTOMRIGHT", checklistDialog, "BOTTOMRIGHT", -10, 10)
        closeBtnCL:SetScript("OnClick", function() checklistDialog:Hide() end)

        local legendText = checklistDialog:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        legendText:SetPoint("BOTTOM", checklistDialog, "BOTTOM", 0, 14)
        legendText:SetText("[X] = Verified this season    [A] = Auto-detected, no action needed    [ ] = Needs manual verification")
        legendText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

        ns.UI.ApplyFontToFrame(checklistDialog)
        checklistDialog:Show()
        checklistDialog:Raise()
    end

    checklistBtn:SetScript("OnClick", OpenChecklistDialog)

    yOffset = yOffset - 50

    scrollContent:SetHeight(math.abs(yOffset) + 20)

    ns.UI.ApplyFontToFrame(parent)
    parent.scrollFrame = scrollFrame
    parent.scrollContent = scrollContent
end
