local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB

OneWoW_Notes = {}

function OneWoW_Notes:ApplyTheme()
    OneWoW_GUI:ApplyTheme(ns)

    if ns.NotesPins and ns.NotesPins.RefreshSyncPins then
        ns.NotesPins:RefreshSyncPins()
    end
    if ns.ZonePins and ns.ZonePins.RefreshSyncPins then
        ns.ZonePins:RefreshSyncPins()
    end
end

function OneWoW_Notes:ApplyLanguage()
    ns.ApplyLanguage()
end

function OneWoW_Notes:CloseHelpPanel()
    if ns.UI and ns.UI.notesHelpPanel and ns.UI.notesHelpPanel:IsShown() then
        ns.UI.notesHelpPanel:Hide()
    end
end

function OneWoW_Notes:SlashCommandHandler(msg)
    if ns.SlashCommandHandler then
        ns:SlashCommandHandler(msg)
    end
end

local function RegisterWithOneWoW()
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
        addonName = ADDON_NAME,
        order = OneWoW:GetModuleTabOrder("notes"),
        tabs = tabs,
    })
    OneWoW:RegisterSettingsPanel({
        name        = "notes",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        order       = OneWoW:GetModuleTabOrder("notes"),
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(ns.db.global)

    OneWoW_Notes:ApplyTheme()
    ns.ApplyLanguage()

    local function slashHandler(msg) ns:SlashCommandHandler(msg) end
    DB:RegisterSlashCommand("own", slashHandler)
    DB:RegisterSlashCommand("onewownotes", slashHandler)
    DB:RegisterSlashCommand("1wn", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_Notes, function(myself)
        myself:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_Notes, function()
        ns.ApplyLanguage()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_Notes, function()
        if ns.NotesPins and ns.NotesPins.RefreshAllPinFonts then
            ns.NotesPins:RefreshAllPinFonts()
        end
        if ns.ZonePins and ns.ZonePins.RefreshAllPinFonts then
            ns.ZonePins:RefreshAllPinFonts()
        end
    end)
    OneWoW:RegisterLoadComponent("Notes",  OneWoW:GetAddonVersion(ADDON_NAME), "/1wn")
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
    OneWoW:RegisterMinimap("OneWoW_Notes", ns.L["CTX_OPEN_NOTES"], "notes", nil)

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

function ns:CloseHelpPanel()
    OneWoW_Notes:CloseHelpPanel()
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
    OneWoW.UI:Show("notes")
end

-- Core-driven init: the suite loader calls _G["OneWoW_Notes"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function OneWoW_Notes:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_Notes)
    OnInitialize()
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN /
-- PLAYER_ENTERING_WORLD at startup, or is driven by the loader
-- (OneWoW:EnsureLoaded) for a mid-session enable, when those one-shot events
-- have already fired and won't reach this module. OnPlayerEnteringWorld is
-- passed isInitialLogin=false for a mid-session enable, so the login-only note
-- reset is skipped while pins/todos still initialize.
local didLogin = false
function OneWoW_Notes:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    if OneWoW_Notes.FireLoginHandlers then
        OneWoW_Notes:FireLoginHandlers()
    end
end

local pewArmed = false
function OneWoW_Notes:OnPlayerEnteringWorld(isLogin, isReload, isZoning)
    if not pewArmed then
        pewArmed = true
        OnPlayerEnteringWorld(isLogin)
    end
    if OneWoW_Notes.FireEnteringWorldHandlers then
        OneWoW_Notes:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
    end
end
