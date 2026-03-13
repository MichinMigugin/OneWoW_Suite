local ADDON_NAME, OneWoW = ...

local GUI = OneWoW.GUI

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local Constants = OneWoW_GUI.Constants
local RESERVED_DEFAULT = "Default"

-- ============================================================
-- Utilities
-- ============================================================

local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = type(v) == "table" and DeepCopy(v) or v
    end
    return dst
end

local function DeepMerge(dst, src)
    if type(src) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" and type(dst[k]) == "table" then
            DeepMerge(dst[k], v)
        else
            dst[k] = v
        end
    end
end

local function SyncSettingToChildAddons(settingType, value)
    local integratedAddons = {
        "OneWoW_AltTracker", "OneWoW_Notes", "OneWoW_QoL",
        "OneWoW_Catalog", "OneWoW_DirectDeposit",
        "OneWoW_ShoppingList", "OneWoW_UtilityDevTool",
    }
    for _, globalName in ipairs(integratedAddons) do
        local addon = _G[globalName]
        if addon then
            if settingType == "theme" and addon.ApplyTheme then
                addon:ApplyTheme()
            elseif settingType == "language" and addon.ApplyLanguage then
                if addon.db and addon.db.global then
                    addon.db.global.language = value
                end
                addon:ApplyLanguage()
            end
        end
    end
end

-- ============================================================
-- Backend
-- ============================================================

OneWoW.Profiles = {}

function OneWoW.Profiles.CaptureSettings()
    local snapshot = {}

    if OneWoW.db and OneWoW.db.global then
        local g = OneWoW.db.global
        snapshot.core = {
            language  = g.language,
            theme     = g.theme,
            minimap   = DeepCopy(g.minimap),
            settings  = DeepCopy(g.settings),
            toasts    = DeepCopy(g.toasts),
            portalHub = DeepCopy(g.portalHub),
        }
    end

    local qol = _G.OneWoW_QoL
    if qol and qol.db and qol.db.global then
        local q = qol.db.global
        snapshot.qol = { language = q.language, theme = q.theme, minimap = DeepCopy(q.minimap), modules = {} }
        if q.modules then
            for id, modData in pairs(q.modules) do
                snapshot.qol.modules[id] = DeepCopy(modData)
            end
        end
    end

    snapshot.cvars = {}
    if qol and qol.GetCVarList then
        for _, entry in ipairs(qol.GetCVarList()) do
            local val = C_CVar.GetCVar(entry.cvar)
            if val then snapshot.cvars[entry.cvar] = val end
        end
    end

    return snapshot
end

function OneWoW.Profiles.ApplySettings(snapshot, profileName)
    if not snapshot then return end

    if snapshot.core and OneWoW.db and OneWoW.db.global then
        local g = OneWoW.db.global
        if snapshot.core.language then g.language = snapshot.core.language end
        if snapshot.core.theme    then g.theme    = snapshot.core.theme    end
        if snapshot.core.minimap then
            if snapshot.core.minimap.hide  ~= nil then g.minimap.hide  = snapshot.core.minimap.hide  end
            if snapshot.core.minimap.theme       then g.minimap.theme  = snapshot.core.minimap.theme end
        end
        if snapshot.core.settings then DeepMerge(g.settings,  snapshot.core.settings)  end
        if snapshot.core.toasts   then DeepMerge(g.toasts,    snapshot.core.toasts)    end
        if snapshot.core.portalHub then DeepMerge(g.portalHub, snapshot.core.portalHub) end
    end

    local qol = _G.OneWoW_QoL
    if snapshot.qol and qol and qol.db and qol.db.global then
        local q = qol.db.global
        if snapshot.qol.language then q.language = snapshot.qol.language end
        if snapshot.qol.theme    then q.theme    = snapshot.qol.theme    end
        if snapshot.qol.minimap  then DeepMerge(q.minimap, snapshot.qol.minimap) end
        if snapshot.qol.modules then
            for id, modData in pairs(snapshot.qol.modules) do
                if q.modules and q.modules[id] then DeepMerge(q.modules[id], modData) end
            end
        end
    end

    if snapshot.cvars then
        for cvarName, value in pairs(snapshot.cvars) do
            C_CVar.SetCVar(cvarName, value)
        end
    end

    if snapshot.core and snapshot.core.theme    then SyncSettingToChildAddons("theme",    snapshot.core.theme)    end
    if snapshot.core and snapshot.core.language then SyncSettingToChildAddons("language", snapshot.core.language) end

    if profileName then
        OneWoW.db.global.activeProfile = profileName
    end

    GUI:FullReset()
    C_Timer.After(0.1, function()
        GUI:Show()
        GUI:SelectSubTab("settings", "profiles")
    end)
end

function OneWoW.Profiles.AutoSaveDefault()
    if not OneWoW.db or not OneWoW.db.global then return end
    if not OneWoW.db.global.profiles then OneWoW.db.global.profiles = {} end
    local snap = OneWoW.Profiles.CaptureSettings()
    snap._isDefault = true
    snap._updatedAt = time()
    OneWoW.db.global.profiles[RESERVED_DEFAULT] = snap
    OneWoW.db.global.defaultProfile = RESERVED_DEFAULT
end

-- ============================================================
-- Serialization
-- ============================================================

local function SerializeVal(val, depth)
    local t = type(val)
    if t == "string" then
        return string.format("%q", val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        local parts = {}
        local inner = string.rep("  ", depth + 1)
        local outer = string.rep("  ", depth)
        for k, v in pairs(val) do
            local vStr = SerializeVal(v, depth + 1)
            if vStr ~= nil then
                local keyStr
                if type(k) == "string" and k:match("^[%a_][%a%d_]*$") then
                    keyStr = k
                elseif type(k) == "number" then
                    keyStr = "[" .. tostring(k) .. "]"
                else
                    keyStr = "[" .. string.format("%q", tostring(k)) .. "]"
                end
                table.insert(parts, inner .. keyStr .. " = " .. vStr)
            end
        end
        if #parts == 0 then return "{}" end
        return "{\n" .. table.concat(parts, ",\n") .. "\n" .. outer .. "}"
    end
    return nil
end

function OneWoW.Profiles.SerializeProfile(profileName, profile)
    local exportable = {}
    for k, v in pairs(profile) do
        if k ~= "_isDefault" and k ~= "_updatedAt" then
            exportable[k] = v
        end
    end
    exportable._exportName = profileName
    local body = SerializeVal(exportable, 0)
    if not body then return nil end
    return "-- OneWoW Settings Profile\n-- Version: 1\n" .. body
end

function OneWoW.Profiles.DeserializeProfile(str)
    if not str or str == "" then return nil, "Empty input" end
    local cleaned = str:gsub("%-%-[^\n]*\n?", "")
    local func, err = loadstring("return " .. cleaned)
    if not func then return nil, "Parse error" end
    local ok, data = pcall(func)
    if not ok then return nil, "Execution error" end
    if type(data) ~= "table" then return nil, "Invalid format" end
    return data, nil
end

function OneWoW.Profiles.ImportProfile(str)
    local data, err = OneWoW.Profiles.DeserializeProfile(str)
    if not data then return false, err end
    if not OneWoW.db.global.profiles then OneWoW.db.global.profiles = {} end
    local profiles = OneWoW.db.global.profiles
    local name = data._exportName or "Imported"
    if name == RESERVED_DEFAULT then name = "Imported Default" end
    data._exportName = nil
    if profiles[name] then
        local base, i = name, 2
        while profiles[name] do name = base .. " (" .. i .. ")"; i = i + 1 end
    end
    profiles[name] = data
    return true, name
end

-- ============================================================
-- Auto-save hooks
-- ============================================================

local _autoSaveFrame = CreateFrame("Frame")
_autoSaveFrame:RegisterEvent("PLAYER_LOGOUT")
_autoSaveFrame:RegisterEvent("PLAYER_LOGIN")
_autoSaveFrame:SetScript("OnEvent", function(_, event)
    if OneWoW.Profiles and OneWoW.Profiles.AutoSaveDefault then
        OneWoW.Profiles.AutoSaveDefault()
    end
end)

-- ============================================================
-- Scrollable EditBox helper
-- ============================================================

local function CreateScrollableEditBox(parent, onEscape)
    local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT",     parent, "TOPLEFT",     4,  -4)
    sf:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -20, 4)
    sf:EnableMouseWheel(true)
    OneWoW_GUI:StyleScrollBar(sf, { container = parent, offset = -4 })

    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetMaxLetters(0)
    local fontPath = OneWoW_GUI and OneWoW_GUI.GetFont and OneWoW_GUI:GetFont() or "Fonts\\FRIZQT__.TTF"
    eb:SetFont(fontPath, 12, "")
    eb:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    eb:SetScript("OnEscapePressed", onEscape or function() end)
    eb:SetScript("OnTextChanged", function() sf:UpdateScrollChildRect() end)

    sf:SetScrollChild(eb)
    sf:HookScript("OnSizeChanged", function(self, w) eb:SetWidth(w) end)

    return eb, sf
end

-- ============================================================
-- Export / Import Dialogs
-- ============================================================

function GUI:ShowSettingsProfileExportDialog(profileName, serializedStr)
    local eb
    local result = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_SettingsProfileExportDialog",
        title  = "Export Profile: |cFFFFD100" .. profileName .. "|r",
        width  = 620,
        height = 500,
        strata = "FULLSCREEN_DIALOG",
        buttons = {
            { text = "Select All", onClick = function() eb:SetFocus(); eb:HighlightText() end },
            { text = "Close",      onClick = function(d) d:Hide() end },
        },
    })

    local cf = result.contentFrame

    local hint = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, -8)
    hint:SetText("Select all and copy (Ctrl+A, Ctrl+C) to share this profile:")
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local textBG = OneWoW_GUI:CreateFrame(cf, { width = 600, height = 420, backdrop = Constants.BACKDROP_SOFT })
    textBG:ClearAllPoints()
    textBG:SetPoint("TOPLEFT",     cf, "TOPLEFT",     10, -28)
    textBG:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -10, 4)

    eb = CreateScrollableEditBox(textBG, function() result.frame:Hide() end)
    eb:SetAutoFocus(true)

    result.frame:Show()
    C_Timer.After(0, function()
        eb:SetText(serializedStr or "")
        eb:SetCursorPosition(0)
    end)
end

function GUI:ShowSettingsProfileImportDialog(onImported)
    local eb
    local result = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_SettingsProfileImportDialog",
        title  = "Import UI & Addon Settings Profile",
        width  = 620,
        height = 460,
        strata = "FULLSCREEN_DIALOG",
        buttons = {
            { text = "Import", onClick = function(d)
                local text = eb:GetText()
                local ok, res = OneWoW.Profiles.ImportProfile(text)
                if ok then
                    print(string.format("|cFFFFD100OneWoW:|r Settings profile imported: %s", res))
                    d:Hide()
                    if onImported then onImported() end
                else
                    print(string.format("|cFFFFD100OneWoW:|r Import failed: %s", res or "unknown error"))
                end
            end },
            { text = "Cancel", onClick = function(d) d:Hide() end },
        },
    })

    local cf = result.contentFrame

    local hint = cf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOPLEFT", cf, "TOPLEFT", 10, -8)
    hint:SetText("Paste exported profile data below, then click Import:")
    hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local textBG = OneWoW_GUI:CreateFrame(cf, { width = 600, height = 380, backdrop = Constants.BACKDROP_SOFT })
    textBG:ClearAllPoints()
    textBG:SetPoint("TOPLEFT",     cf, "TOPLEFT",     10, -28)
    textBG:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -10, 4)

    eb = CreateScrollableEditBox(textBG, function() result.frame:Hide() end)
    eb:SetAutoFocus(true)

    result.frame:Show()
end

-- ============================================================
-- Delete Confirmation Dialog (reusable)
-- ============================================================

local _deleteConfirmDialog

local function ShowDeleteConfirm(profileName, onConfirm)
    if _deleteConfirmDialog then
        _deleteConfirmDialog.frame:Hide()
    end
    _deleteConfirmDialog = OneWoW_GUI:CreateConfirmDialog({
        name    = "OneWoW_SettingsProfileDeleteConfirm",
        title   = "Delete Profile",
        message = "Delete settings profile: |cFFFFD100" .. profileName .. "|r?\nThis cannot be undone.",
        width   = 400,
        buttons = {
            { text = "Delete", color = { 0.7, 0.15, 0.15 }, onClick = function(d)
                d:Hide()
                if onConfirm then onConfirm() end
            end },
            { text = "Cancel", onClick = function(d) d:Hide() end },
        },
    })
    _deleteConfirmDialog.frame:Show()
end

-- ============================================================
-- Profiles Tab
-- ============================================================

function GUI:CreateProfilesTab(parent)

    local panelA = CreateFrame("Frame", nil, parent)
    local panelB = CreateFrame("Frame", nil, parent)
    panelB:Hide()

    local tabBtns, tabsBottomY = OneWoW_GUI:CreateFitFrameButtons(parent, {
        yOffset = -4,
        items = {
            { text = "UI & Addon Settings", value = "settings",    isActive = true },
            { text = "Character Backup",    value = "charprofiles"                 },
        },
        height = 30,
        gap    = 6,
        onSelect = function(value)
            panelA:SetShown(value == "settings")
            panelB:SetShown(value == "charprofiles")
        end,
    })

    local contentTop = tabsBottomY - 6

    panelA:SetPoint("TOPLEFT",     parent, "TOPLEFT",     0, contentTop)
    panelA:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    panelB:SetPoint("TOPLEFT",     parent, "TOPLEFT",     0, contentTop)
    panelB:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    if GUI.CreateCharProfilesPanel then
        GUI:CreateCharProfilesPanel(panelB)
    end

    -- ── Panel A: UI & Addon Settings Profiles ─────────────────
    local scrollFrame, content = OneWoW_GUI:CreateScrollFrame(panelA, { name = "OneWoW_ProfilesScroll" })

    local yOffset = -10

    local descText = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    descText:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, yOffset)
    descText:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    descText:SetJustifyH("LEFT")
    descText:SetWordWrap(true)
    descText:SetSpacing(2)
    descText:SetText("Saves your OneWoW theme, language, overlays, portal settings, and all QoL feature toggles. Export to share your setup or import from another player.")
    descText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    yOffset = yOffset - 36

    local saveSection = OneWoW_GUI:CreateSectionHeader(content, { title = "Save New Profile", yOffset = yOffset })
    yOffset = saveSection.bottomY - 8

    local nameInput = OneWoW_GUI:CreateEditBox(content, { name = "OneWoW_ProfileNameInput", width = 280, height = 26 })
    nameInput:SetPoint("TOPLEFT", content, "TOPLEFT", 10, yOffset)
    nameInput:SetAutoFocus(false)

    local saveBtn = OneWoW_GUI:CreateButton(content, { text = "Save Profile", width = 130, height = 26 })
    saveBtn:SetPoint("LEFT", nameInput, "RIGHT", 8, 0)

    yOffset = yOffset - 40

    local listHeaderSection = OneWoW_GUI:CreateSectionHeader(content, { title = "Saved Profiles", yOffset = yOffset })
    yOffset = listHeaderSection.bottomY - 8

    local importBtn = OneWoW_GUI:CreateButton(content, { text = "Import Profile", width = 130, height = 24 })
    importBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset + 32)

    local listContainer = CreateFrame("Frame", nil, content)
    listContainer:SetPoint("TOPLEFT",  content, "TOPLEFT",  10, yOffset)
    listContainer:SetPoint("TOPRIGHT", content, "TOPRIGHT", -10, yOffset)
    listContainer:SetHeight(20)

    local function RefreshListing()
        OneWoW_GUI:ClearFrame(listContainer)

        local profiles = OneWoW.db.global.profiles
        if not profiles then profiles = {} end

        local activeProfile = OneWoW.db.global.activeProfile

        local sorted = {}
        if profiles[RESERVED_DEFAULT] then
            table.insert(sorted, { name = RESERVED_DEFAULT, data = profiles[RESERVED_DEFAULT] })
        end
        for name, data in pairs(profiles) do
            if name ~= RESERVED_DEFAULT and type(data) == "table" then
                table.insert(sorted, { name = name, data = data })
            end
        end
        table.sort(sorted, function(a, b)
            if a.name == RESERVED_DEFAULT then return true end
            if b.name == RESERVED_DEFAULT then return false end
            return a.name:lower() < b.name:lower()
        end)

        if #sorted == 0 then
            local empty = listContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            empty:SetPoint("TOPLEFT", 10, -14)
            empty:SetText("No profiles saved yet. Save one above.")
            empty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            listContainer:SetHeight(40)
            return
        end

        local CARD_H = 76
        local CARD_GAP = 6
        local yOff = 0

        for _, entry in ipairs(sorted) do
            local name = entry.name
            local data = entry.data
            local isDefault = (name == RESERVED_DEFAULT)
            local isActive  = (activeProfile == name)

            local card = OneWoW_GUI:CreateFrame(listContainer, { width = 100, height = CARD_H, backdrop = Constants.BACKDROP_SOFT })
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT",  listContainer, "TOPLEFT",  0, yOff)
            card:SetPoint("TOPRIGHT", listContainer, "TOPRIGHT", 0, yOff)
            card:SetHeight(CARD_H)

            local nameText = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -8)
            nameText:SetText(isDefault and ("|cFFFFD100" .. name .. "|r") or name)
            if isActive then
                nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                nameText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            end

            if isDefault then
                local badge = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                badge:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
                badge:SetText("Account Default - Auto-Updates")
                badge:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_SECONDARY"))
            end

            if isActive and not isDefault then
                local activeBadge = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                activeBadge:SetPoint("LEFT", nameText, "RIGHT", 8, 0)
                activeBadge:SetText("Active")
                activeBadge:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            end

            local dateText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            dateText:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -26)
            local ts = data._updatedAt or 0
            local dateLabel = isDefault and "Updated: " or "Saved: "
            dateText:SetText(dateLabel .. (ts > 0 and date("%Y-%m-%d %H:%M", ts) or "Unknown"))
            dateText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local tags = {}
            if data.core then
                local parts = {}
                if data.core.theme    then table.insert(parts, data.core.theme)    end
                if data.core.language then table.insert(parts, data.core.language) end
                table.insert(tags, "Core" .. (#parts > 0 and (" (" .. table.concat(parts, ", ") .. ")") or ""))
            end
            if data.qol then
                local mc = 0
                if data.qol.modules then for _ in pairs(data.qol.modules) do mc = mc + 1 end end
                table.insert(tags, string.format("QoL (%d modules)", mc))
            end
            if data.cvars then
                local cc = 0
                for _ in pairs(data.cvars) do cc = cc + 1 end
                if cc > 0 then table.insert(tags, string.format("%d CVars", cc)) end
            end

            local tagsText = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            tagsText:SetPoint("TOPLEFT",  card, "TOPLEFT",  10, -44)
            tagsText:SetPoint("TOPRIGHT", card, "TOPRIGHT", -280, -44)
            tagsText:SetJustifyH("LEFT")
            tagsText:SetText(#tags > 0 and table.concat(tags, "  |cFF444444/|r  ") or "")
            tagsText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local btnY = 6

            if not isDefault then
                local delBtn = OneWoW_GUI:CreateButton(card, { text = "Delete", width = 76, height = 26 })
                delBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, btnY)
                delBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
                delBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
                delBtn:SetScript("OnEnter", function(self)
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_HOVER"))
                    self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER_HOVER"))
                end)
                delBtn:SetScript("OnLeave", function(self)
                    self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL"))
                    self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
                end)
                local capturedName = name
                delBtn:SetScript("OnClick", function()
                    ShowDeleteConfirm(capturedName, function()
                        OneWoW.db.global.profiles[capturedName] = nil
                        if OneWoW.db.global.activeProfile == capturedName then
                            OneWoW.db.global.activeProfile = nil
                        end
                        RefreshListing()
                    end)
                end)

                local exportBtn = OneWoW_GUI:CreateButton(card, { text = "Export", width = 76, height = 26 })
                exportBtn:SetPoint("RIGHT", delBtn, "LEFT", -6, 0)
                exportBtn:SetScript("OnClick", function()
                    local serialized = OneWoW.Profiles.SerializeProfile(capturedName, data)
                    if serialized then GUI:ShowSettingsProfileExportDialog(capturedName, serialized) end
                end)

                local loadBtn = OneWoW_GUI:CreateButton(card, { text = "Load", width = 76, height = 26 })
                loadBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)
                loadBtn:SetScript("OnClick", function()
                    OneWoW.Profiles.ApplySettings(data, capturedName)
                end)
            else
                local exportBtn = OneWoW_GUI:CreateButton(card, { text = "Export", width = 90, height = 26 })
                exportBtn:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, btnY)
                exportBtn:SetScript("OnClick", function()
                    local serialized = OneWoW.Profiles.SerializeProfile(RESERVED_DEFAULT, data)
                    if serialized then GUI:ShowSettingsProfileExportDialog(RESERVED_DEFAULT, serialized) end
                end)

                local restoreBtn = OneWoW_GUI:CreateButton(card, { text = "Restore Now", width = 110, height = 26 })
                restoreBtn:SetPoint("RIGHT", exportBtn, "LEFT", -6, 0)
                restoreBtn:SetScript("OnClick", function()
                    OneWoW.Profiles.ApplySettings(data, RESERVED_DEFAULT)
                end)
            end

            yOff = yOff - (CARD_H + CARD_GAP)
        end

        listContainer:SetHeight(math.abs(yOff) + CARD_GAP)
        content:SetHeight(math.abs(yOffset) + listContainer:GetHeight() + 40)
    end

    saveBtn:SetScript("OnClick", function()
        local name = nameInput:GetText():trim()
        if name == "" then
            print("|cFFFFD100OneWoW:|r Profile name cannot be empty.")
            return
        end
        if name == RESERVED_DEFAULT then
            print("|cFFFFD100OneWoW:|r Cannot use the name 'Default' - it is reserved.")
            return
        end
        local snap = OneWoW.Profiles.CaptureSettings()
        snap._updatedAt = time()
        if not OneWoW.db.global.profiles then OneWoW.db.global.profiles = {} end
        OneWoW.db.global.profiles[name] = snap
        OneWoW.db.global.activeProfile  = name
        nameInput:SetText("")
        print(string.format("|cFFFFD100OneWoW:|r Settings profile saved: %s", name))
        RefreshListing()
    end)

    importBtn:SetScript("OnClick", function()
        GUI:ShowSettingsProfileImportDialog(RefreshListing)
    end)

    C_Timer.After(0.05, function()
        OneWoW.Profiles.AutoSaveDefault()
        RefreshListing()
        GUI:ApplyFontToFrame(panelA)
    end)
end
