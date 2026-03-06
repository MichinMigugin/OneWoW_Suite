local addonName, ns = ...

ns.SettingsProfiles = {}
local Module = ns.SettingsProfiles

-- ============================================================
-- Capture
-- ============================================================

function Module:CaptureKeybinds()
    local bindings = {}
    for i = 1, GetNumBindings() do
        local command, _, key1, key2 = GetBinding(i)
        if command and (key1 or key2) then
            table.insert(bindings, { command = command, key1 = key1, key2 = key2 })
        end
    end
    return { bindings = bindings, count = #bindings, capturedAt = time() }
end

function Module:CaptureMacros()
    local account = {}
    local accountCount = 0
    for i = 1, MAX_ACCOUNT_MACROS do
        local name, iconTexture, body = GetMacroInfo(i)
        if name then
            local macroIcon
            if type(iconTexture) == "number" then
                macroIcon = iconTexture
            elseif type(iconTexture) == "string" then
                macroIcon = iconTexture:gsub("^Interface\\Icons\\", "")
            else
                macroIcon = "INV_Misc_QuestionMark"
            end
            account[i] = { id = i, name = name, icon = macroIcon, body = body }
            accountCount = accountCount + 1
        end
    end

    local character = {}
    local charCount = 0
    for i = MAX_ACCOUNT_MACROS + 1, MAX_ACCOUNT_MACROS + MAX_CHARACTER_MACROS do
        local name, iconTexture, body = GetMacroInfo(i)
        if name then
            local macroIcon
            if type(iconTexture) == "number" then
                macroIcon = iconTexture
            elseif type(iconTexture) == "string" then
                macroIcon = iconTexture:gsub("^Interface\\Icons\\", "")
            else
                macroIcon = "INV_Misc_QuestionMark"
            end
            character[i] = { id = i, name = name, icon = macroIcon, body = body }
            charCount = charCount + 1
        end
    end

    return {
        account = account,
        character = character,
        accountCount = accountCount,
        charCount = charCount,
        capturedAt = time(),
    }
end

function Module:CaptureGameSettings()
    if not ConsoleGetAllCommands or not GetCVar then return nil end
    local commands = ConsoleGetAllCommands()
    if not commands then return nil end
    local cvars = {}
    local count = 0
    for _, cmdInfo in ipairs(commands) do
        if cmdInfo.commandType == 0 and cmdInfo.command then
            local value = GetCVar(cmdInfo.command)
            if value ~= nil then
                cvars[cmdInfo.command] = value
                count = count + 1
            end
        end
    end
    if count == 0 then return nil end
    return { cvars = cvars, count = count, capturedAt = time() }
end

function Module:CaptureAddonSet()
    if not C_AddOns then return nil end
    local addons = {}
    local total = C_AddOns.GetNumAddOns()
    local charName = UnitName("player")
    for i = 1, total do
        local name, title = C_AddOns.GetAddOnInfo(i)
        if name then
            local state = C_AddOns.GetAddOnEnableState(name, charName)
            table.insert(addons, { name = name, title = title or name, enabled = (state == 2) })
        end
    end
    return { addons = addons, count = #addons, capturedAt = time() }
end

local ADDON_SETTINGS_MAP = {
    {
        dbName = "OneWoW_DB",
        displayName = "OneWoW",
        keys = {"language", "theme", "minimap", "mainFrameSize", "mainFramePosition", "portalHub", "settings", "toasts"},
    },
    {
        dbName = "OneWoW_AltTracker_DB",
        displayName = "AltTracker",
        acedb = true,
        keys = {"language", "theme", "minimap", "mainFrameSize", "mainFramePosition", "altTrackerSettings", "overrides", "favorites", "seasonChecklist"},
    },
    {
        dbName = "OneWoW_QoL_DB",
        displayName = "QoL",
        acedb = true,
        keys = {"language", "theme", "lastTab", "minimap", "modules"},
    },
    {
        dbName = "OneWoW_Notes_DB",
        displayName = "Notes",
        acedb = true,
        keys = {"language", "theme", "minimap", "lastTab", "mainFrameSize", "mainFramePosition", "sortCompletedTasks", "zoneAlertsEnabled", "npcScanEnabled", "playerScanEnabled"},
    },
    {
        dbName = "OneWoW_Catalog_DB",
        displayName = "Catalog",
        acedb = true,
        keys = {"language", "theme", "lastTab", "minimap", "mainFrameSize", "mainFramePosition"},
    },
    {
        dbName = "OneWoW_Bags_DB",
        displayName = "Bags",
        keys = {"language", "theme", "minimap", "viewMode", "columns", "scale", "iconSize", "autoOpen", "autoClose", "locked", "showBagsBar", "rarityColor", "rarityIntensity", "showNewItems", "recentItemDuration", "categorySort", "showEmptySlots"},
    },
    {
        dbName = "OneWoW_DirectDeposit_DB",
        displayName = "DirectDeposit",
        keys = {"language", "theme", "minimap", "directDeposit"},
    },
    {
        dbName = "OneWoW_ShoppingList_DB",
        displayName = "ShoppingList",
        globalWrap = true,
        keys = {"settings", "minimap"},
    },
    {
        dbName = "OneWoW_AltTracker_Character_DB",
        displayName = "AltTracker Character",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Accounting_DB",
        displayName = "AltTracker Accounting",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Auctions_DB",
        displayName = "AltTracker Auctions",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Professions_DB",
        displayName = "AltTracker Professions",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Collections_DB",
        displayName = "AltTracker Collections",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Endgame_DB",
        displayName = "AltTracker Endgame",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_AltTracker_Storage_DB",
        displayName = "AltTracker Storage",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_CatalogData_Journal_DB",
        displayName = "CatalogData Journal",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_CatalogData_Tradeskills_DB",
        displayName = "CatalogData Tradeskills",
        keys = {"settings"},
    },
    {
        dbName = "OneWoW_CatalogData_Vendors_DB",
        displayName = "CatalogData Vendors",
        keys = {"settings"},
    },
}

function Module:CaptureAddonSettings()
    local captured = {}
    local count = 0
    for _, entry in ipairs(ADDON_SETTINGS_MAP) do
        local db = _G[entry.dbName]
        if db then
            local source = db
            if (entry.acedb or entry.globalWrap) and type(db.global) == "table" then
                source = db.global
            end
            local settings = {}
            local hasData = false
            for _, key in ipairs(entry.keys) do
                if source[key] ~= nil then
                    if type(source[key]) == "table" then
                        settings[key] = CopyTable(source[key])
                    else
                        settings[key] = source[key]
                    end
                    hasData = true
                end
            end
            if hasData then
                captured[entry.dbName] = {
                    displayName = entry.displayName,
                    acedb = entry.acedb or false,
                    globalWrap = entry.globalWrap or false,
                    settings = settings,
                }
                count = count + 1
            end
        end
    end
    return { addons = captured, count = count, capturedAt = time() }
end

-- ============================================================
-- Restore
-- ============================================================

function Module:RestoreKeybinds(keybindData)
    if not keybindData or not keybindData.bindings then return 0 end
    LoadBindings(2)
    local count = 0
    for _, bindData in ipairs(keybindData.bindings) do
        if bindData.key1 then
            local ctx = 1
            if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
                ctx = C_KeyBindings.GetBindingContextForAction(bindData.command)
            end
            SetBinding(bindData.key1, bindData.command, ctx)
        end
        if bindData.key2 then
            local ctx = 1
            if C_KeyBindings and C_KeyBindings.GetBindingContextForAction then
                ctx = C_KeyBindings.GetBindingContextForAction(bindData.command)
            end
            SetBinding(bindData.key2, bindData.command, ctx)
        end
        count = count + 1
    end
    SaveBindings(2)
    return count
end

function Module:RestoreMacros(macroData, doAccount, doCharacter)
    if not macroData then return 0 end
    local count = 0

    local function FindOrCreate(macroInfo, isChar)
        if not macroInfo or not macroInfo.name then return end
        local existing = GetMacroIndexByName(macroInfo.name)
        if existing and existing > 0 then
            count = count + 1
            return
        end
        local numGlobal, numPerChar = GetNumMacros()
        local canCreate = isChar and (numPerChar < MAX_CHARACTER_MACROS) or (numGlobal < MAX_ACCOUNT_MACROS)
        if canCreate then
            local icon = macroInfo.icon or "INV_Misc_QuestionMark"
            if macroInfo.body and macroInfo.body:sub(1, 12) == "#showtooltip" then
                icon = "INV_Misc_QuestionMark"
            end
            local newId = CreateMacro(macroInfo.name, icon, macroInfo.body or "", isChar)
            if newId then count = count + 1 end
        else
            print(string.format("|cFFFFD100OneWoW - AltTracker:|r Macro limit reached, skipped: %s", macroInfo.name))
        end
    end

    if doAccount and macroData.account then
        for _, macroInfo in pairs(macroData.account) do
            FindOrCreate(macroInfo, false)
        end
    end
    if doCharacter and macroData.character then
        for _, macroInfo in pairs(macroData.character) do
            FindOrCreate(macroInfo, true)
        end
    end
    return count
end

function Module:RestoreGameSettings(gameData)
    if not gameData or not gameData.cvars or not SetCVar then return 0 end
    local count = 0
    for cvarName, value in pairs(gameData.cvars) do
        SetCVar(cvarName, value)
        count = count + 1
    end
    return count
end

function Module:RestoreAddonSet(addonData)
    if not addonData or not addonData.addons or not C_AddOns then return 0 end
    local charName = UnitName("player")
    local count = 0
    for _, addonInfo in ipairs(addonData.addons) do
        if C_AddOns.GetAddOnInfo(addonInfo.name) then
            local currentState = C_AddOns.GetAddOnEnableState(addonInfo.name, charName)
            local isEnabled = (currentState == 2)
            if addonInfo.enabled ~= isEnabled then
                if addonInfo.enabled then
                    C_AddOns.EnableAddOn(addonInfo.name, charName)
                else
                    C_AddOns.DisableAddOn(addonInfo.name, charName)
                end
                count = count + 1
            end
        end
    end
    return count
end

function Module:RestoreAddonSettings(addonData)
    if not addonData or not addonData.addons then return 0 end
    local count = 0
    for dbName, entry in pairs(addonData.addons) do
        local db = _G[dbName]
        if db then
            local target = db
            if (entry.acedb or entry.globalWrap) and type(db.global) == "table" then
                target = db.global
            end
            for key, value in pairs(entry.settings) do
                if type(value) == "table" then
                    target[key] = CopyTable(value)
                else
                    target[key] = value
                end
            end
            count = count + 1
        end
    end
    return count
end

-- ============================================================
-- Save / Delete / List  (all DB access via ns:GetSettingsProfiles)
-- ============================================================

function Module:SaveProfile(name, options)
    if not name or name == "" then
        print("|cFFFFD100OneWoW - AltTracker:|r Profile name cannot be empty.")
        return false
    end

    local profile = { name = name, timestamp = time(), savedBy = ns:GetCharacterKey() }

    if options.keybinds then
        profile.keybinds = self:CaptureKeybinds()
    end
    if options.accountMacros or options.characterMacros then
        local macros = self:CaptureMacros()
        if options.accountMacros then
            profile.accountMacros = { data = macros.account, count = macros.accountCount, capturedAt = macros.capturedAt }
        end
        if options.characterMacros then
            profile.characterMacros = { data = macros.character, count = macros.charCount, capturedAt = macros.capturedAt }
        end
    end
    if options.gameSettings then
        profile.gameSettings = self:CaptureGameSettings()
    end
    if options.addonSet then
        profile.addonSet = self:CaptureAddonSet()
    end
    if options.addonSettings then
        profile.addonSettings = self:CaptureAddonSettings()
    end

    ns:GetSettingsProfiles()[name] = profile
    print("|cFFFFD100OneWoW - AltTracker:|r Profile saved: " .. name)
    return true
end

function Module:DeleteProfile(name)
    local profiles = ns:GetSettingsProfiles()
    if not profiles[name] then return false end
    profiles[name] = nil
    print("|cFFFFD100OneWoW - AltTracker:|r Profile deleted: " .. name)
    return true
end

function Module:GetProfilesList()
    local profiles = ns:GetSettingsProfiles()
    local list = {}
    for name, data in pairs(profiles) do
        if type(data) == "table" and data.name and data.timestamp then
            table.insert(list, { name = name, data = data })
        end
    end
    table.sort(list, function(a, b)
        return (a.data.timestamp or 0) > (b.data.timestamp or 0)
    end)
    return list
end

function Module:GetCurrentCounts()
    local counts = {}
    local bindCount = 0
    for i = 1, GetNumBindings() do
        local cmd, _, k1, k2 = GetBinding(i)
        if cmd and (k1 or k2) then bindCount = bindCount + 1 end
    end
    counts.keybinds = bindCount
    local numGlobal, numPerChar = GetNumMacros()
    counts.accountMacros = numGlobal or 0
    counts.characterMacros = numPerChar or 0
    counts.addonSet = C_AddOns and C_AddOns.GetNumAddOns() or 0
    return counts
end

-- ============================================================
-- Serialize / Deserialize / Import
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

function Module:SerializeProfile(profile)
    local body = SerializeVal(profile, 0)
    if not body then return nil end
    return "-- OneWoW AltTracker Settings Profile\n-- Version: 1\n" .. body
end

function Module:DeserializeProfile(str)
    if not str or str == "" then return nil, "Empty input" end
    local cleaned = str:gsub("%-%-[^\n]*\n?", "")
    local func, err = loadstring("return " .. cleaned)
    if not func then return nil, "Parse error" end
    local ok, data = pcall(func)
    if not ok then return nil, "Execution error" end
    if type(data) ~= "table" then return nil, "Invalid format" end
    if type(data.name) ~= "string" or data.name == "" then return nil, "Missing profile name" end
    return data, nil
end

function Module:ImportProfile(str)
    local data, err = self:DeserializeProfile(str)
    if not data then return false, err end
    local profiles = ns:GetSettingsProfiles()
    local name = data.name
    if profiles[name] then
        local base = name
        local i = 2
        while profiles[name] do
            name = base .. " (" .. i .. ")"
            i = i + 1
        end
        data.name = name
    end
    data.timestamp = data.timestamp or time()
    profiles[name] = data
    return true, name
end
