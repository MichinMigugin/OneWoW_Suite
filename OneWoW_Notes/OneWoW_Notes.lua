-- OneWoW_Notes Addon File
-- OneWoW_Notes/OneWoW_Notes.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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
            { name = "tracker", displayName = function() return ns.L["TAB_TRACKER"] or "Tracker" end, create = function(p) ns.UI.CreateTrackerTab(p) end },
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

    OneWoW_GUI:MigrateSettings(self.db.global)

    self:ApplyTheme()
    if ns.ApplyLanguage then ns.ApplyLanguage() end
    self:RegisterChatCommand("own", "SlashCommandHandler")
    self:RegisterChatCommand("onewownotes", "SlashCommandHandler")
    self:RegisterChatCommand("1wn", "SlashCommandHandler")

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(self2)
        if ns.ApplyTheme then ns.ApplyTheme() end
        if ns.NotesPins and ns.NotesPins.RefreshSyncPins then
            ns.NotesPins:RefreshSyncPins()
        end
        if ns.ZonePins and ns.ZonePins.RefreshSyncPins then
            ns.ZonePins:RefreshSyncPins()
        end
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(self2)
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(self2)
        if ns.NotesPins and ns.NotesPins.RefreshAllPinFonts then
            ns.NotesPins:RefreshAllPinFonts()
        end
        if ns.ZonePins and ns.ZonePins.RefreshAllPinFonts then
            ns.ZonePins:RefreshAllPinFonts()
        end
        if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
            ns.TrackerEngine:RefreshAllPinnedWindows()
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(owner, hidden)
        if owner.Minimap then owner.Minimap:SetShown(not hidden) end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner)
        if owner.Minimap then owner.Minimap:UpdateIcon() end
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(addonName)
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("Notes", _ver, "/1wn")
    end
end

function addon:CloseHelpPanel()
    if ns.UI and ns.UI.notesHelpPanel and ns.UI.notesHelpPanel:IsShown() then
        ns.UI.notesHelpPanel:Hide()
    end
end

function addon:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)

    if ns.NotesPins and ns.NotesPins.RefreshSyncPins then
        ns.NotesPins:RefreshSyncPins()
    end
    if ns.ZonePins and ns.ZonePins.RefreshSyncPins then
        ns.ZonePins:RefreshSyncPins()
    end
    if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
        ns.TrackerEngine:RefreshAllPinnedWindows()
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

    if ns.NotesData and ns.NotesData.MigrateFontFamily then
        ns.NotesData:MigrateFontFamily()
    end

    if ns.Zones and ns.Zones.MigrateFontFamily then
        ns.Zones:MigrateFontFamily()
    end

    RegisterWithOneWoW()

    if not ns.oneWoWHubActive then
        self.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_Notes", {
            label = "Notes",
            onClick = function()
                if ns.UI and ns.UI.Toggle then ns.UI:Toggle() end
            end,
            onRightClick = function()
                if ns.UI and ns.UI.Show then ns.UI:Show("settings") end
            end,
            onTooltip = function(frame)
                GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
                GameTooltip:AddLine(ns.L["ADDON_TITLE_FRAME"], 1, 0.82, 0, 1)
                if ns.L["MINIMAP_TOOLTIP_HINT"] then
                    GameTooltip:AddLine(ns.L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
                end
                GameTooltip:Show()
            end,
        })
    end
    if _G.OneWoW then
        _G.OneWoW:RegisterMinimap("OneWoW_Notes", (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_NOTES"]) or "Open Notes", "notes", nil)
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

    if ns.TrackerEngine and ns.TrackerEngine.Initialize then
        ns.TrackerEngine:Initialize()
    end

    if ns.TrackerMigration and ns.TrackerMigration.MigrateAll then
        ns.TrackerMigration:MigrateAll()
    end

    if ns.TrackerPresets and ns.TrackerPresets.LoadBundledContent then
        ns.TrackerPresets:LoadBundledContent()
    end

    if ns.TrackerMapUI and ns.TrackerMapUI.Initialize then
        ns.TrackerMapUI:Initialize()
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
