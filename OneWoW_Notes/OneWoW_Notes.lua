-- OneWoW_Notes Addon File
-- OneWoW_Notes/OneWoW_Notes.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

OneWoW_Notes = LibStub("AceAddon-3.0"):NewAddon("OneWoW_Notes", "AceEvent-3.0", "AceConsole-3.0")
local addon = OneWoW_Notes

ns.addon = addon
ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    if not _G.OneWoW then return false end
    if not _G.OneWoW.RegisterModule then return false end

    _G.OneWoW:RegisterModule({
        name = "notes",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "Notes" end,
        addonName = "OneWoW_Notes",
        order = 1,
        tabs = {
            { name = "notes",   displayName = function() return ns.L["TAB_NOTES"]   or "Notes"   end, create = function(p) ns.UI.CreateNotesTab(p) end },
            { name = "players", displayName = function() return ns.L["TAB_PLAYERS"] or "Players" end, create = function(p) ns.UI.CreatePlayersTab(p) end },
            { name = "npcs",    displayName = function() return ns.L["TAB_NPCS"]    or "NPCs"    end, create = function(p) ns.UI.CreateNPCsTab(p) end },
            { name = "zones",   displayName = function() return ns.L["TAB_ZONES"]   or "Zones"   end, create = function(p) ns.UI.CreateZonesTab(p) end },
            { name = "items",   displayName = function() return ns.L["TAB_ITEMS"]   or "Items"   end, create = function(p) ns.UI.CreateItemsTab(p) end },
            { name = "guides", displayName = function() return ns.L["TAB_GUIDES"] or "Guides" end, create = function(p) ns.UI.CreateGuidesTab(p) end },
            { name = "routines", displayName = function() return ns.L["TAB_ROUTINES"] or "Routines" end, create = function(p) ns.UI.CreateRoutinesTab(p) end },
        },
    })
    _G.OneWoW:RegisterSettingsPanel({
        name        = "notes",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "Notes" end,
        order       = 1,
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

function addon:OnInitialize()
    self:InitializeDatabase()
    if ns.ApplyTheme then ns.ApplyTheme() end
    if ns.ApplyLanguage then ns.ApplyLanguage() end
    self:RegisterChatCommand("own", "SlashCommandHandler")
    self:RegisterChatCommand("onewownotes", "SlashCommandHandler")
    self:RegisterChatCommand("1wn", "SlashCommandHandler")
    local _ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ns.Constants.VERSION
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("Notes", _ver, "/1wn")
    else
        print("|cFF00FF00OneWoW|r: |cFFFFFFFFNotes|r |cFF888888\226\128\147 v." .. _ver .. " \226\128\147|r |cFF00FF00Loaded|r - /1wn")
    end
end

function addon:CloseHelpPanel()
    if ns.UI and ns.UI.notesHelpPanel and ns.UI.notesHelpPanel:IsShown() then
        ns.UI.notesHelpPanel:Hide()
    end
end

function addon:ApplyTheme()
    if ns.ApplyTheme then
        ns.ApplyTheme()
    end
    if ns.NotesPins and ns.NotesPins.RefreshSyncPins then
        ns.NotesPins:RefreshSyncPins()
    end
    if ns.ZonePins and ns.ZonePins.RefreshSyncPins then
        ns.ZonePins:RefreshSyncPins()
    end
    if ns.RoutinesEngine and ns.RoutinesEngine.RefreshAllPinnedWindows then
        ns.RoutinesEngine:RefreshAllPinnedWindows()
    end
end

function addon:ApplyLanguage()
    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end
end

function addon:OnEnable()
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    if ns.NotesData and ns.NotesData.MigrateDefaultColors then
        ns.NotesData:MigrateDefaultColors()
    end

    if ns.Zones and ns.Zones.MigrateDefaultColors then
        ns.Zones:MigrateDefaultColors()
    end

    RegisterWithOneWoW()

    if not ns.oneWoWHubActive then
        if ns.MinimapButton and ns.MinimapButton.Initialize then
            ns.MinimapButton:Initialize()
        end
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

    self.Players = ns.Players
    self.NPCs    = ns.NPCs
    self.Zones   = ns.Zones
    self.Config  = ns.Config
    self.notePins    = self.notePins    or {}
    self.windowStack = self.windowStack or {}

    if ns.NotesData then
        self.NotesData = ns.NotesData
    end

    if ns.GuidesData and ns.GuidesData.LoadBundledGuides then
        ns.GuidesData:LoadBundledGuides()
    end

    if ns.RoutinesData and ns.RoutinesData.LoadBundledRoutines then
        ns.RoutinesData:LoadBundledRoutines()
    end

    if ns.RoutinesEngine and ns.RoutinesEngine.Initialize then
        ns.RoutinesEngine:Initialize()
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnPlayerEnteringWorld")
end

function addon:OnPlayerEnteringWorld(event, isInitialLogin, isReloading)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")

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

function addon:FormatResetTimer(seconds)
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

function addon:RegisterWindow(frame, windowType, closeCallback)
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

function addon:UnregisterWindow(frame)
    if not frame or not self.windowStack then return end
    for i = #self.windowStack, 1, -1 do
        if self.windowStack[i].frame == frame then
            table.remove(self.windowStack, i)
            break
        end
    end
    self:UpdateWindowLayering()
end

function addon:BringWindowToFront(frame)
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

function addon:UpdateWindowLayering()
    if not self.windowStack then return end
    local baseLevel = 100
    for i, info in ipairs(self.windowStack) do
        if info.frame and info.frame.SetFrameLevel then
            pcall(function() info.frame:SetFrameLevel(baseLevel + (i * 10)) end)
        end
    end
end

function addon:SlashCommandHandler(input)
    if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("notes")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function addon:InitializeDatabase()
    local defaults = ns.DatabaseDefaults or {}
    self.db = LibStub("AceDB-3.0"):New("OneWoW_Notes_DB", defaults, true)
    if not self.db.global.language then
        self.db.global.language = GetLocale()
    end
    if not self.db.global.theme then
        self.db.global.theme = "green"
    end
    if self.db.global.minimapButton and not self.db.global.minimap then
        self.db.global.minimap = {
            hide = self.db.global.minimapButton.hide or false,
            minimapPos = 220,
            theme = "horde",
        }
        self.db.global.minimapButton = nil
    end
    if not self.db.global.minimap then self.db.global.minimap = {} end
    if self.db.global.minimap.hide == nil then self.db.global.minimap.hide = false end
    if self.db.global.minimap.minimapPos == nil then self.db.global.minimap.minimapPos = 220 end
    if not self.db.global.minimap.theme then self.db.global.minimap.theme = "horde" end
end

_G["1WoW_Notes_OnAddonCompartmentClick"] = function(addonName, mouseButton)
    if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("notes")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

_G["1WoW_Notes_OnAddonCompartmentEnter"] = function(addonName, frame)
    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
    GameTooltip:AddLine(ns.L["ADDON_TITLE_FRAME"], 1, 0.82, 0, 1)
    GameTooltip:AddLine(ns.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
    GameTooltip:Show()
end

_G["1WoW_Notes_OnAddonCompartmentLeave"] = function()
    GameTooltip:Hide()
end
