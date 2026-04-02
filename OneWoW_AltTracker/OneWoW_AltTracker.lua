local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local DB = OneWoW_GUI.DB

OneWoW_AltTracker = {}
local OneWoWAltTracker = OneWoW_AltTracker

ns.OneWoWAltTracker = OneWoWAltTracker
ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    if not _G.OneWoW then return false end
    if not _G.OneWoW.RegisterModule then return false end

    _G.OneWoW:RegisterModule({
        name = "alttracker",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "AltTracker" end,
        addonName = "OneWoW_AltTracker",
        order = 2,
        tabs = {
            { name = "summary",     displayName = function() return ns.L["SUBTAB_SUMMARY"]     or "Summary"     end, create = function(p) ns.UI.CreateSummaryTab(p) end },
            { name = "progress",    displayName = function() return ns.L["SUBTAB_PROGRESS"]    or "Progress"    end, create = function(p) ns.UI.CreateProgressTab(p) end },
            { name = "bank",        displayName = function() return ns.L["SUBTAB_BANK"]        or "Bank"        end, create = function(p) ns.UI.CreateBankTab(p) end },
            { name = "equipment",   displayName = function() return ns.L["SUBTAB_EQUIPMENT"]   or "Equipment"   end, create = function(p) ns.UI.CreateEquipmentTab(p) end },
            { name = "professions", displayName = function() return ns.L["SUBTAB_PROFESSIONS"] or "Professions" end, create = function(p) ns.UI.CreateProfessionsTab(p) end },
            { name = "auctions",    displayName = function() return ns.L["SUBTAB_AUCTIONS"]    or "Auctions"    end, create = function(p) ns.UI.CreateAuctionsTab(p) end },
            { name = "financials",  displayName = function() return ns.L["SUBTAB_FINANCIALS"]  or "Financials"  end, create = function(p) ns.UI.CreateFinancialsTab(p) end },
            { name = "items",       displayName = function() return ns.L["SUBTAB_ITEMS"]       or "Items"       end, create = function(p) ns.UI.CreateItemsTab(p) end },
            { name = "actionbars",  displayName = function() return "Action Bars" end, create = function(p) ns.UI.CreateActionBarsTab(p) end },
            { name = "lockouts",    displayName = function() return ns.L["SUBTAB_LOCKOUTS"]    or "Lockouts"    end, create = function(p) ns.UI.CreateLockoutsTab(p) end },
        },
    })
    _G.OneWoW:RegisterSettingsPanel({
        name        = "alttracker",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] or "AltTracker" end,
        order       = 2,
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

local function OnInitialize()
    OneWoWAltTracker:InitializeDatabase()
    OneWoW_GUI:MigrateSettings(OneWoWAltTracker.db.global)
    OneWoWAltTracker:ApplyTheme()

    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end

    local function slashHandler(msg) OneWoWAltTracker:SlashCommandHandler(msg) end
    DB:RegisterSlashCommand("onewowat", slashHandler)
    DB:RegisterSlashCommand("owat", slashHandler)
    DB:RegisterSlashCommand("1wat", slashHandler)

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoWAltTracker, function(self2)
        self2:ApplyTheme()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoWAltTracker, function(self2)
        if ns.ApplyLanguage then ns.ApplyLanguage() end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoWAltTracker, function(self2)
        local mainFrame = _G["OneWoWAltTrackerMainFrame"]
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoWAltTracker, function(self2)
        local mainFrame = _G["OneWoWAltTrackerMainFrame"]
        if mainFrame then
            OneWoW_GUI:ApplyFontToFrame(mainFrame)
        end
        if ns.UI.ResizeOverviewPanels then
            ns.UI.ResizeOverviewPanels()
        end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", OneWoWAltTracker, function(owner, hidden)
        if owner.Minimap then owner.Minimap:SetShown(not hidden) end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", OneWoWAltTracker, function(owner)
        if owner.Minimap then owner.Minimap:UpdateIcon() end
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(addonName)
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("AltTracker", _ver, "/1wat")
    end
end

function OneWoWAltTracker:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function OneWoWAltTracker:ApplyLanguage()
    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end
end

local function OnEnable()
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    RegisterWithOneWoW()

    if not ns.oneWoWHubActive then
        OneWoWAltTracker.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_AltTracker", {
            label = "AltTracker",
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
        _G.OneWoW:RegisterMinimap("OneWoW_AltTracker", (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_ALTTRACKER"]) or "Open AltTracker", "alttracker", nil)
    end
end

function OneWoWAltTracker:SlashCommandHandler(input)
    if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("alttracker")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function OneWoWAltTracker:InitializeDatabase()
    local defaults = ns.DatabaseDefaults or {}

    self.db = DB:NewCompat("OneWoW_AltTracker_DB", defaults, true)

    if not self.db.global.altTracker then
        self.db.global.altTracker = {
            characters = {},
            lastUpdate = time(),
            expansionVersion = 11
        }
    end

    if not self.db.global.warbandBankData then
        self.db.global.warbandBankData = {}
    end

    if not self.db.global.guildBanks then
        self.db.global.guildBanks = {}
    end

    if not self.db.global.actionBars then
        self.db.global.actionBars = {}
    end

    if not self.db.global.altTrackerSettings then
        self.db.global.altTrackerSettings = {
            enablePlaytimeTracking = true,
            enableDataCollection = true,
        }
    end

    if self.db.global.migrationStatus == nil then
        self.db.global.migrationStatus = {
            cleanupPerformed = false,
        }
    end

    if not self.db.global.overrides then
        self.db.global.overrides = { progress = { trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316, 3310}, worldBossQuestID = 0 } }
    end
    if not self.db.global.overrides.progress then
        self.db.global.overrides.progress = { trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316, 3310}, worldBossQuestID = 0 }
    end
    if not self.db.global.overrides.progress.trackedCurrencyIDs then
        self.db.global.overrides.progress.trackedCurrencyIDs = {3383, 3341, 3343, 3345, 3347, 3303, 3309, 3378, 3379, 3385, 3316, 3310}
        self.db.global.overrides.progress.currency1ID = nil
        self.db.global.overrides.progress.currency2ID = nil
    end
    if not self.db.global.overrides.progress.worldBossQuestIDs or #self.db.global.overrides.progress.worldBossQuestIDs == 0 then
        self.db.global.overrides.progress.worldBossQuestIDs = {92123, 92560, 92636, 92034}
        self.db.global.overrides.progress.worldBossQuestID = nil
    end
    self.db.global.overrides.progress.primaryRaidName = nil
    self.db.global.overrides.progress.worldBossName = nil
    if not self.db.global.favorites then
        self.db.global.favorites = {}
    end
    if not self.db.global.seasonChecklist then
        self.db.global.seasonChecklist = {}
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" and ... == addonName then
        OnInitialize()
    elseif event == "PLAYER_LOGIN" then
        OnEnable()
    end
end)

_G["1WoW_AltTracker_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if ns.oneWoWHubActive and _G.OneWoW and _G.OneWoW.GUI then
        _G.OneWoW.GUI:Show("alttracker")
        return
    end
    if buttonName == "LeftButton" then
        if ns.UI and ns.UI.Toggle then
            ns.UI:Toggle()
        end
    elseif buttonName == "RightButton" then
        if ns.UI and ns.UI.Show then
            ns.UI:Show("settings")
        end
    end
end

_G["1WoW_AltTracker_OnAddonCompartmentEnter"] = function(addonName, menuButtonFrame)
    GameTooltip:SetOwner(menuButtonFrame, "ANCHOR_LEFT")
    local L = _G.OneWoW_AltTracker and _G.OneWoW_AltTracker.L
    GameTooltip:SetText(L and L["ADDON_TITLE_FRAME"] or "|cFFFFD100OneWoW|r - AltTracker")
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(L and L["UI_MINIMAP_LEFT_CLICK"] or "Left-Click to open AltTracker", 1, 1, 1)
    GameTooltip:AddLine(L and L["UI_MINIMAP_RIGHT_CLICK"] or "Right-Click for options", 1, 1, 1)
    GameTooltip:Show()
end

_G["1WoW_AltTracker_OnAddonCompartmentLeave"] = function(addonName, menuButtonFrame)
    GameTooltip:Hide()
end
