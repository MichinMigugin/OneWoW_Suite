local addonName, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

OneWoW_Notes_API = {}

--- Returns an NPC note.
---@param npcID number
---@return table|nil npcData
function OneWoW_Notes_API.GetNPC(npcID)
    return ns.NPCs:GetNPC(npcID)
end

--- Adds or updates an NPC note.
---@param npcID number
---@param npcData table
---@return boolean saved
function OneWoW_Notes_API.AddOrUpdateNPC(npcID, npcData)
    npcID = tonumber(npcID)
    if not npcID then
        return false
    end

    local existing = ns.NPCs:GetNPC(npcID)
    if existing then
        for key, value in pairs(npcData) do
            if value ~= nil then
                existing[key] = value
            end
        end
        ns.NPCs:SaveNPC(npcID, existing)
    else
        ns.NPCs:AddNPC(npcID, npcData)
    end

    return true
end

--- Opens an NPC note, selecting it when the NPCs tab is ready.
---@param npcID number
---@return boolean opened
function OneWoW_Notes_API.OpenNPC(npcID)
    npcID = tonumber(npcID)
    if not npcID then
        return false
    end

    ns.pendingNPCSelect = npcID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "npcs")

    local tabFrame = OneWoW.UI:GetContentFrame("notes", "npcs")
    if tabFrame and tabFrame.SelectNPC then
        tabFrame.SelectNPC(npcID)
        ns.pendingNPCSelect = nil
    end

    return true
end

--- Returns an item note.
---@param itemID number
---@return table|nil itemData
function OneWoW_Notes_API.GetItem(itemID)
    return ns.Items:GetItem(itemID)
end

--- Adds or updates an item note.
---@param itemID number
---@param itemData table
---@return boolean saved
function OneWoW_Notes_API.AddOrUpdateItem(itemID, itemData)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    local existing = ns.Items:GetItem(itemID)
    if existing then
        for key, value in pairs(itemData) do
            if value ~= nil then
                existing[key] = value
            end
        end
        ns.Items:SaveItem(itemID, existing)
    else
        ns.Items:AddItem(itemID, itemData)
    end

    return true
end

--- Opens an item note, selecting it when the Items tab is ready.
---@param itemID number
---@return boolean opened
function OneWoW_Notes_API.OpenItem(itemID)
    itemID = tonumber(itemID)
    if not itemID then
        return false
    end

    ns.pendingItemSelect = itemID
    OneWoW.UI:Show("notes")
    OneWoW.UI:SelectSubTab("notes", "items")

    if ns.UI.OpenNotesItem and ns.UI.OpenNotesItem(itemID) then
        ns.pendingItemSelect = nil
    end

    return true
end

-- We use _G[""] form since _G.OneWoW_Notes would get caught in pre-commit hook.
_G["OneWoW_Notes"] = ns

ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    if not OneWoW then return false end
    if not OneWoW.RegisterModule then return false end

    local tabs = {
        { name = "notes",   displayName = function() return ns.L["TAB_NOTES"]   end, create = function(p) ns.UI.CreateNotesTab(p) end },
        { name = "players", displayName = function() return ns.L["TAB_PLAYERS"] end, create = function(p) ns.UI.CreatePlayersTab(p) end },
        { name = "npcs",    displayName = function() return ns.L["TAB_NPCS"]    end, create = function(p) ns.UI.CreateNPCsTab(p) end },
        { name = "zones",   displayName = function() return ns.L["TAB_ZONES"]   end, create = function(p) ns.UI.CreateZonesTab(p) end },
        { name = "items",   displayName = function() return ns.L["TAB_ITEMS"]   end, create = function(p) ns.UI.CreateItemsTab(p) end },
    }

    OneWoW:RegisterModule({
        name = "notes",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName = "OneWoW_Notes",
        order = OneWoW:GetModuleTabOrder("notes"),
        tabs = tabs,
    })
    OneWoW:RegisterSettingsPanel({
        name        = "notes",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        order       = OneWoW:GetModuleTabOrder("notes"),
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(ns.db.global)

    ns:ApplyTheme()
    ns.ApplyLanguage()

    local function slashHandler(msg) ns:SlashCommandHandler(msg) end
    DB:RegisterSlashCommand("own", slashHandler)
    DB:RegisterSlashCommand("onewownotes", slashHandler)
    DB:RegisterSlashCommand("1wn", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", ns, function()
        if ns.ApplyTheme then ns.ApplyTheme() end
        if ns.NotesPins and ns.NotesPins.RefreshSyncPins then
            ns.NotesPins:RefreshSyncPins()
        end
        if ns.ZonePins and ns.ZonePins.RefreshSyncPins then
            ns.ZonePins:RefreshSyncPins()
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", ns, function()
        ns.ApplyLanguage()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", ns, function()
        if ns.NotesPins and ns.NotesPins.RefreshAllPinFonts then
            ns.NotesPins:RefreshAllPinFonts()
        end
        if ns.ZonePins and ns.ZonePins.RefreshAllPinFonts then
            ns.ZonePins:RefreshAllPinFonts()
        end
    end)
    local _ver = OneWoW:GetAddonVersion(addonName)
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("Notes", _ver, "/1wn")
    end
end

function ns:CloseHelpPanel()
    if ns.UI and ns.UI.notesHelpPanel and ns.UI.notesHelpPanel:IsShown() then
        ns.UI.notesHelpPanel:Hide()
    end
end

function ns:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)

    if ns.NotesPins and ns.NotesPins.RefreshSyncPins then
        ns.NotesPins:RefreshSyncPins()
    end
    if ns.ZonePins and ns.ZonePins.RefreshSyncPins then
        ns.ZonePins:RefreshSyncPins()
    end
end

local function OnEnable()
    if ns.NotesData then
        local allNotes = ns.NotesData:GetAllNotes()
        if allNotes then
            for _, note in pairs(allNotes) do
                if type(note) == "table" and note.noteType == "escpanel" then
                    note.noteType = "standard"
                    note.category = "General"
                    note.modified = GetServerTime()
                end
            end
        end
    end

    RegisterWithOneWoW()

    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_Notes", ns.L["CTX_OPEN_NOTES"], "notes", nil)
    end

    if ns.ZonePins and ns.ZonePins.Initialize then
        ns.ZonePins:Initialize()
    end
    if ns.Zones and ns.Zones.Initialize then
        ns.Zones:Initialize()
    end
    if ns.Players and ns.Players.Initialize then
        ns.Players:Initialize()
    end
    if ns.NPCs and ns.NPCs.Initialize then
        ns.NPCs:Initialize()
    end
    if ns.Items and ns.Items.Initialize then
        ns.Items:Initialize()
    end

    ns.notePins    = ns.notePins    or {}
    ns.windowStack = ns.windowStack or {}
end

local function OnPlayerEnteringWorld(isInitialLogin)
    if isInitialLogin and ns.NotesData then
        local allNotes = ns.NotesData:GetAllNotes()
        if allNotes then
            for _, note in pairs(allNotes) do
                if type(note) == "table" then
                    note.manuallyHidden = false
                end
            end
        end
    end

    if ns.NotesPins and ns.NotesPins.Initialize then
        ns.NotesPins:Initialize()
    end

    if ns.NotesTodos and ns.NotesTodos.CheckAndPerformResets then
        ns.NotesTodos:CheckAndPerformResets()
    end
end

function ns:FormatResetTimer(seconds)
    if seconds <= 0 then return "<0m>" end
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    if days > 0 then
        if hours > 0 then return string.format("<%dd %dhr>", days, hours)
        else return string.format("<%dd>", days) end
    elseif hours > 0 then
        return string.format("<%dhr>", hours)
    else
        return string.format("<%dm>", minutes)
    end
end

function ns:RegisterWindow(frame, windowType, closeCallback)
    if not frame then return end
    if not self.windowStack then self.windowStack = {} end
    local windowInfo = {
        frame = frame,
        type = windowType or "generic",
        closeCallback = closeCallback,
        originalLevel = frame:GetFrameLevel(),
        originalStrata = frame:GetFrameStrata()
    }
    table.insert(self.windowStack, windowInfo)
    self:UpdateWindowLayering()
    return windowInfo
end

function ns:UnregisterWindow(frame)
    if not frame or not self.windowStack then return end
    for i = #self.windowStack, 1, -1 do
        if self.windowStack[i].frame == frame then
            table.remove(self.windowStack, i)
            break
        end
    end
    self:UpdateWindowLayering()
end

function ns:BringWindowToFront(frame)
    if not frame or not self.windowStack then return end
    local windowInfo = nil
    local oldIndex = nil
    for i, info in ipairs(self.windowStack) do
        if info.frame == frame then
            windowInfo = info
            oldIndex = i
            break
        end
    end
    if not windowInfo then return end
    table.remove(self.windowStack, oldIndex)
    table.insert(self.windowStack, windowInfo)
    self:UpdateWindowLayering()
end

function ns:UpdateWindowLayering()
    if not self.windowStack then return end
    local baseLevel = 100
    for i, info in ipairs(self.windowStack) do
        if info.frame and info.frame.SetFrameLevel then
            pcall(function() info.frame:SetFrameLevel(baseLevel + (i * 10)) end)
        end
    end
end

function ns:SlashCommandHandler()
    if ns.oneWoWHubActive and OneWoW and OneWoW.UI then
        OneWoW.UI:Show("notes")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

-- Core-driven init: the suite loader calls _G["OneWoW_Notes"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function ns:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(ns)
    OnInitialize()
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN /
-- PLAYER_ENTERING_WORLD at startup, or is driven by the loader
-- (OneWoW:EnsureLoaded) for a mid-session enable, when those one-shot events
-- have already fired and won't reach this module. OnPlayerEnteringWorld is
-- passed isInitialLogin=false for a mid-session enable, so the login-only note
-- reset is skipped while pins/todos still initialize.
local didLogin = false
function ns:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    if ns.FireLoginHandlers then
        ns:FireLoginHandlers()
    end
end

local pewArmed = false
function ns:OnPlayerEnteringWorld(isLogin, isReload, isZoning)
    if not pewArmed then
        pewArmed = true
        OnPlayerEnteringWorld(isLogin)
    end
    if ns.FireEnteringWorldHandlers then
        ns:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
    end
end
