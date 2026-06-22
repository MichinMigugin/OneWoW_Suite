local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI

OneWoW_DirectDeposit = {}
local OneWoW_DirectDeposit = OneWoW_DirectDeposit

local L = ns.L

ns.oneWoWHubActive = false

local function DetectOneWoW()
    if OneWoW then
        ns.oneWoWHubActive = true
    end
end

local function ApplyLanguage()
    -- Localization lives in the OneWoW Locale service now (scope "DirectDeposit";
    -- shared vocab in the "shared" scope). SetLanguage refolds every scope in place,
    -- pushes BINDING_* globals, and fires OnApply; ns.L is a stable view.
    -- esMX->esES is normalized inside the service.
    local lang = OneWoW_GUI:GetSetting("language") or "enUS"
    OneWoW.Locale:SetLanguage(lang)
end

function OneWoW_DirectDeposit:ApplyTheme()
    OneWoW_GUI:ApplyTheme(ns)
end

function OneWoW_DirectDeposit:ApplyLanguage()
    ApplyLanguage()
end

function OneWoW_DirectDeposit:ReinitForLanguage(_)
    ApplyLanguage()
    if ns.GUI and ns.GUI.FullReset then
        local mw = ns.GUI:GetMainWindow()
        local wasShown = mw and mw:IsShown()
        ns.GUI:FullReset()
        if wasShown then
            C_Timer.After(0.1, function()
                if ns.GUI and ns.GUI.Show then ns.GUI:Show() end
            end)
        end
    end
end

function ns:AddHoveredItemToList(bankType)
    local _, itemLink = GameTooltip:GetItem()
    if not itemLink then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["KEYBIND_NO_ITEM"])
        return
    end

    local itemID = C_Item.GetItemIDForItemInfo(itemLink)
    if not itemID then
        print(L["ADDON_CHAT_PREFIX"] .. " " .. L["KEYBIND_NO_ITEM"])
        return
    end

    local itemList = ns.db.global.directDeposit.itemList
    local existing = itemList[tostring(itemID)]

    local function bankName(bt)
        return bt == "personal" and L["ITEM_DEPOSIT_PERSONAL"]
            or bt == "warband"  and L["ITEM_DEPOSIT_WARBAND"]
            or GUILD
    end

    if existing then
        if existing.bankType == bankType then
            ns.DirectDeposit:RemoveItemFromList(itemID)
            print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800Removed|r " .. itemLink .. " |cFFFFFFFFfrom|r " .. bankName(bankType))
        else
            local oldName = bankName(existing.bankType)
            local newName = bankName(bankType)
            ns.DirectDeposit:UpdateItemBankType(itemID, bankType)
            print(L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Moved|r " .. itemLink .. " |cFFFFFFFFfrom|r " .. oldName .. " |cFFFFFFFFto|r " .. newName)
        end
        if ns.GUI then ns.GUI:RefreshCurrentTab() end
    else
        local success, msg = ns.DirectDeposit:AddItemToList(itemID, bankType)
        if success then
            print(L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Added|r " .. itemLink .. " |cFFFFFFFFto|r " .. bankName(bankType))
            if ns.GUI then ns.GUI:RefreshCurrentTab() end
        else
            print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800" .. (msg or "Failed") .. "|r")
        end
    end
end

function ns:InitTooltipHook()
    local function GetBankTypeDisplay(bankType)
        if bankType == "personal" then
            return L["TOOLTIP_PERSONAL"], 1.0, 1.0, 1.0
        elseif bankType == "warband" then
            return L["TOOLTIP_WARBAND"], 0.4, 0.8, 1.0
        elseif bankType == "guild" then
            return GUILD, 1.0, 0.82, 0.0
        end
        return nil
    end

    if ns.oneWoWHubActive and OneWoW and OneWoW.TooltipEngine then
        OneWoW.TooltipEngine:RegisterProvider({
            id           = "directdeposit",
            order        = 50,
            tooltipTypes = { "item" },
            callback     = function(_, context)
                if not context.itemID then return nil end
                if not ns.db.global.directDeposit.tooltipEnabled then return nil end

                local itemList = ns.db.global.directDeposit.itemList
                local itemData = itemList[tostring(context.itemID)]
                if not itemData then return nil end

                local bankTypeName, rr, rg, rb = GetBankTypeDisplay(itemData.bankType)
                if not bankTypeName then return nil end

                return {
                    {
                        type  = "double",
                        left  = "  " .. L["TOOLTIP_LABEL"],
                        right = bankTypeName,
                        lr = 0.2, lg = 1.0, lb = 0.2,
                        rr = rr,  rg = rg,  rb = rb,
                    }
                }
            end,
        })
    else
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            if not ns.db.global.directDeposit.tooltipEnabled then return end
            if not data or not data.id then return end

            local itemList = ns.db.global.directDeposit.itemList
            local itemData = itemList[tostring(data.id)]
            if not itemData then return end

            local bankTypeName, rr, rg, rb = GetBankTypeDisplay(itemData.bankType)
            if bankTypeName then
                tooltip:AddDoubleLine("  " .. L["TOOLTIP_LABEL"], bankTypeName, 0.2, 1.0, 0.2, rr, rg, rb)
            end
        end)
    end
end

local function InitializeModules()
    if ns.DirectDeposit then
        ns.DirectDeposit:Initialize()
    end
end

local function RegisterSlashCommands()
    local existingDD = SlashCmdList["DD"]

    if not existingDD then
        SLASH_ONEWOW_DIRECTDEPOSIT1 = "/dd"
        SLASH_ONEWOW_DIRECTDEPOSIT2 = "/directdeposit"
        SLASH_ONEWOW_DIRECTDEPOSIT3 = "/directdep"
    else
        print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800/dd is already in use by another addon. Use /directdeposit or /directdep instead.|r")
        SLASH_ONEWOW_DIRECTDEPOSIT1 = "/directdeposit"
        SLASH_ONEWOW_DIRECTDEPOSIT2 = "/directdep"
    end

    SlashCmdList["ONEWOW_DIRECTDEPOSIT"] = function()
        if ns.GUI then
            ns.GUI:Toggle()
        end
    end

    SLASH_ONEWOW_DD_TOGGLE1 = "/1wdd"
    SlashCmdList["ONEWOW_DD_TOGGLE"] = function()
        if ns.GUI then
            ns.GUI:Toggle()
        end
    end

    SLASH_ONEWOW_DDEPOSIT1 = "/ddeposit"
    SlashCmdList["ONEWOW_DDEPOSIT"] = function(msg)
        local lowerMsg = strlower(strtrim(msg or ""))

        if lowerMsg == "pause" or lowerMsg == "stop" then
            if not ns.DirectDeposit:StopDeposit() then
                print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800No deposit in progress.|r")
            end
        else
            ns.DirectDeposit:ManualDeposit()
        end
    end
end

-- Core-driven init: the suite loader calls OneWoW_DirectDeposit:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). The
-- one-shot guard makes the PLAYER_LOGIN safety net a no-op when already run.
local didInit = false
function OneWoW_DirectDeposit:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_DirectDeposit)
    ns:InitializeDatabase()

    local g = ns.db.global
    OneWoW_GUI:MigrateSettings({
        theme = g.theme,
        language = g.language,
        minimap = g.minimap,
    })

    OneWoW_DirectDeposit:ApplyTheme()
    ApplyLanguage()
    InitializeModules()
    RegisterSlashCommands()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_DirectDeposit, function(myself)
        myself:ApplyTheme()
        if ns.GUI and ns.GUI.FullReset then
            local wasShown = ns.GUI:GetMainWindow() and ns.GUI:GetMainWindow():IsShown()
            ns.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if ns.GUI and ns.GUI.Show then ns.GUI:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", OneWoW_DirectDeposit, function()
        if ns.GUI and ns.GUI.GetMainWindow then
            local mw = ns.GUI:GetMainWindow()
            if mw and mw.brandIcon then
                mw.brandIcon:SetTexture(OneWoW_GUI:GetBrandIcon(
                    OneWoW_GUI:GetSetting("minimap.theme") or "horde"))
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_DirectDeposit, function()
        if ns.GUI then
            local wasShown = ns.GUI:GetMainWindow() and ns.GUI:GetMainWindow():IsShown()
            ns.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if ns.GUI and ns.GUI.Show then ns.GUI:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", OneWoW_DirectDeposit, function()
        if ns.GUI then
            local wasShown = ns.GUI:GetMainWindow() and ns.GUI:GetMainWindow():IsShown()
            ns.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if ns.GUI and ns.GUI.Show then ns.GUI:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_DirectDeposit, function(owner, langCode)
        owner:ReinitForLanguage(langCode)
    end)

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("DirectDeposit", _ver, "/1wdd")
    end
end

-- Core-driven login-phase arming. Runs from the module's own PLAYER_LOGIN at
-- startup, or is driven by the loader (OneWoW:EnsureLoaded) for a mid-session
-- enable, when PLAYER_LOGIN has already fired and won't reach this module.
local didLogin = false
function OneWoW_DirectDeposit:OnPlayerLogin()
    if didLogin then return end
    didLogin = true
    DetectOneWoW()
    C_Timer.After(0, function()
        ns:InitTooltipHook()
    end)
    if OneWoW then
        OneWoW:RegisterMinimap("OneWoW_DirectDeposit", L["CTX_OPEN_DD"], nil, function()
            if ns.GUI then ns.GUI:Toggle() end
        end)
    end
    if OneWoW_DirectDeposit.FireLoginHandlers then
        OneWoW_DirectDeposit:FireLoginHandlers()
    end
end
