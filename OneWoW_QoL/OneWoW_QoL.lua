local addonName, ns = ...

local OneWoW_GUI = OneWoW_GUI

local DB = OneWoW_GUI.DB

OneWoW_QoL = {}
local addon = OneWoW_QoL

ns.oneWoWHubActive = false

local function RegisterWithOneWoW()
    if not OneWoW then return false end
    if not OneWoW.RegisterModule then return false end

    local tabs = {
        { name = "features",    displayName = function() return ns.L["TAB_FEATURES"] end, create = function(p) ns.UI.CreateFeaturesTab(p) end },
        { name = "toggles",     displayName = function() return ns.L["TAB_TOGGLES"]  end, create = function(p) ns.UI.CreateTogglesTab(p) end },
        -- Feature settings tabs moved from core (MIGRATION steps 9a/9b);
        -- locale keys stay in core OneWoW.L per the step-9 shared rules.
        { name = "toastalerts", displayName = function() return OneWoW.L["TOAST_ALERTS_SUBTAB"] end, create = function(p) ns.UI.CreateToastAlertsTab(p) end },
        { name = "tooltips",    displayName = function() return OneWoW.L["TOOLTIPS_SUBTAB"]     end, create = function(p) ns.UI.CreateTooltipsTab(p) end },
        { name = "portals",     displayName = function() return OneWoW.L["PORTALS_SUBTAB"]      end, create = function(p) ns.UI.CreatePortalsTab(p) end },
    }
    if OneWoW.UI and OneWoW.UI.GetQoLFeatureTabs then
        for _, tab in ipairs(OneWoW.UI:GetQoLFeatureTabs()) do
            table.insert(tabs, tab)
        end
    end
    OneWoW:RegisterModule({
        name = "qol",
        displayName = function() return ns.L["ADDON_TITLE_SHORT"] end,
        addonName = "OneWoW_QoL",
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
    addon:InitializeDatabase()

    OneWoW_GUI:MigrateSettings(addon.db.global)

    OneWoW_GUI:ApplyTheme(addon)
    if ns.ApplyLanguage then ns.ApplyLanguage() end

    local function slashHandler() addon:SlashCommandHandler() end
    DB:RegisterSlashCommand("owqol", slashHandler)
    DB:RegisterSlashCommand("onewowqol", slashHandler)
    DB:RegisterSlashCommand("1wqol", slashHandler)

    if OneWoW_GUI.RegisterSettingsCallback then
        OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", addon, function(myself)
            OneWoW_GUI:ApplyTheme(myself)
        end)
        OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", addon, function()
            if ns.ApplyLanguage then ns.ApplyLanguage() end
        end)
    end

    local _ver = C_AddOns.GetAddOnMetadata(addonName, "Version") or ""
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("QoL", _ver, "/1wqol")
    end
end

function addon:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function addon:ApplyLanguage()
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
        OneWoW:RegisterMinimap("OneWoW_QoL", (OneWoW.L and OneWoW.L["CTX_OPEN_QOL"]) or "Open QoL", "qol", nil)
    end

    addon.PlayMountsModule = ns.PlayMountsModule
    addon.ModuleRegistry = ns.ModuleRegistry
    addon.UI = ns.UI
end

function addon:SlashCommandHandler()
    if ns.oneWoWHubActive and OneWoW and OneWoW.UI then
        OneWoW.UI:Show("qol")
        return
    end
    if ns.UI and ns.UI.Toggle then
        ns.UI:Toggle()
    end
end

function addon:CopyTextKeybind()
    if ns.CopyTextModule then
        ns.CopyTextModule:Capture()
    end
end

function addon:InitializeDatabase()
    ns.InitializeDatabase(self)
end

-- Core-driven init: the suite loader calls _G["OneWoW_QoL"]:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net below a no-op when already run.
local didInit = false
function addon:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(addon)
    -- Toast types (moved from core, MIGRATION step 9a) export their arming
    -- functions on ns; the handler registry doesn't exist at their file scope.
    addon:RegisterLoginHandler("toast-loot", ns.ToastLoot.OnLogin)
    addon:RegisterEnteringWorldHandler("toast-instance", ns.ToastInstance.OnEnteringWorld)
    -- Portal Hub (moved from core, MIGRATION step 9c); same order as the
    -- original core registrations (module before esc-menu integration).
    addon:RegisterLoginHandler("portalhub", function() ns.PortalHubModule:Initialize() end)
    addon:RegisterLoginHandler("portalhub-esc", function() ns.PortalHubEsc:Initialize() end)
    OnInitialize()
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN at
-- startup, or is driven by the loader (OneWoW:EnsureLoaded) for a mid-session
-- enable, when PLAYER_LOGIN has already fired and won't reach this module.
local didLogin = false
function addon:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    OnEnable()
    if addon.FireLoginHandlers then
        addon:FireLoginHandlers()
    end
end

function addon:OnPlayerEnteringWorld(isLogin, isReload, isZoning)
    if addon.FireEnteringWorldHandlers then
        addon:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
    end
end
