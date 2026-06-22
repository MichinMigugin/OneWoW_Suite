local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

OneWoW_QoL = {}
local OneWoW_QoL = OneWoW_QoL

ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    if not OneWoW then return false end
    if not OneWoW.RegisterModule then return false end

    local tabs = {
        { name = "features",    displayName = function() return ns.L["TAB_FEATURES"] end, create = function(p) ns.UI.CreateFeaturesTab(p) end },
        { name = "toggles",     displayName = function() return ns.L["TAB_TOGGLES"]  end, create = function(p) ns.UI.CreateTogglesTab(p) end },
        -- Feature settings tabs migrated from core; strings live in the QoL scope
        -- (TOAST_ALERTS_SUBTAB resolves via the shared scope).
        { name = "toastalerts", displayName = function() return ns.L["TOAST_ALERTS_SUBTAB"] end, create = function(p) ns.UI.CreateToastAlertsTab(p) end },
        { name = "tooltips",    displayName = function() return ns.L["TOOLTIPS_SUBTAB"]     end, create = function(p) ns.UI.CreateTooltipsTab(p) end },
        { name = "portals",     displayName = function() return ns.L["PORTALS_SUBTAB"]      end, create = function(p) ns.UI.CreatePortalsTab(p) end },
        { name = "overlays",    displayName = function() return ns.L["OVERLAYS_SUBTAB"]     end, create = function(p) ns.UI.CreateOverlaysTab(p) end },
    }
    OneWoW:RegisterModule({
        name = "qol",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName = ADDON_NAME,
        order = OneWoW:GetModuleTabOrder("qol"),
        tabs = tabs,
    })
    OneWoW:RegisterSettingsPanel({
        name        = "qol",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        order       = OneWoW:GetModuleTabOrder("qol"),
        create      = function(p) ns.UI.CreateSettingsTab(p) end,
    })
    ns.oneWoWHubActive = true
    return true
end

local function OnInitialize()
    ns:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(ns.db.global)

    OneWoW_QoL:ApplyTheme()
    if ns.ApplyLanguage then ns.ApplyLanguage() end

    local function slashHandler() OneWoW_QoL:SlashCommandHandler() end
    DB:RegisterSlashCommand("owqol", slashHandler)
    DB:RegisterSlashCommand("onewowqol", slashHandler)
    DB:RegisterSlashCommand("1wqol", slashHandler)

    if OneWoW_GUI.RegisterSettingsCallback then
        OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_QoL, function(self)
            OneWoW_GUI:ApplyTheme(self)
        end)
        OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_QoL, function()
            if ns.ApplyLanguage then ns.ApplyLanguage() end
        end)
    end

    OneWoW:RegisterLoadComponent("QoL", OneWoW:GetAddonVersion(ADDON_NAME), "/1wqol")
end

function OneWoW_QoL:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function OneWoW_QoL:ApplyLanguage()
    if ns.ApplyLanguage then
        ns.ApplyLanguage()
    end
end

local function OnEnable()
    if ns.Core and ns.Core.Initialize then
        ns.Core:Initialize()
    end

    RegisterWithOneWoW()

    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_QoL", ns.L["CTX_OPEN_QOL"], "qol", nil)
    end
end

function OneWoW_QoL:SlashCommandHandler()
    if ns.oneWoWHubActive and OneWoW and OneWoW.UI then
        OneWoW.UI:Show("qol")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function OneWoW_QoL:CopyTextKeybind()
    local ct = ns.ModuleRegistry:GetById("copytext")
    if ct then
        ct:Capture()
    end
end

-- Core-driven init: the suite loader calls _G["OneWoW_QoL"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function OneWoW_QoL:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_QoL)
    -- Toast types export their arming functions on ns; the handler registry
    -- doesn't exist at their file scope.
    OneWoW_QoL:RegisterLoginHandler("toast-loot", ns.ToastLoot.OnLogin)
    OneWoW_QoL:RegisterEnteringWorldHandler("toast-instance", ns.ToastInstance.OnEnteringWorld)
    -- Portal Hub: module before esc-menu integration.
    OneWoW_QoL:RegisterLoginHandler("portalhub", function() ns.PortalHubModule:Initialize() end)
    OneWoW_QoL:RegisterLoginHandler("portalhub-esc", function() ns.PortalHubEsc:Initialize() end)
    OnInitialize()
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN at
-- startup, or is driven by the loader (OneWoW:EnsureLoaded) for a mid-session
-- enable, when PLAYER_LOGIN has already fired and won't reach this module.
local didLogin = false
function OneWoW_QoL:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    if OneWoW_QoL.FireLoginHandlers then
        OneWoW_QoL:FireLoginHandlers()
    end
end

function OneWoW_QoL:OnPlayerEnteringWorld(isLogin, isReload, isZoning)
    if OneWoW_QoL.FireEnteringWorldHandlers then
        OneWoW_QoL:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
    end
end
