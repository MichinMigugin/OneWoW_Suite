local ADDON_NAME, OneWoW_DirectDeposit = ...

_G.OneWoW_DirectDeposit = OneWoW_DirectDeposit

local L = OneWoW_DirectDeposit.L

OneWoW_DirectDeposit.oneWoWHubActive = false

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local function DetectOneWoW()
    if _G.OneWoW then
        OneWoW_DirectDeposit.oneWoWHubActive = true
    end
end

local function ApplyTheme()
    OneWoW_GUI:ApplyTheme(OneWoW_DirectDeposit)
end

local function ApplyLanguage()
    local lang
    local hub = _G.OneWoW
    if hub and hub.db and hub.db.global then
        lang = hub.db.global.language or "enUS"
    else
        lang = OneWoW_DirectDeposit.db and OneWoW_DirectDeposit.db.global.language or "enUS"
    end
    if lang == "esMX" then lang = "esES" end
    local localeData = OneWoW_DirectDeposit.Locales[lang] or OneWoW_DirectDeposit.Locales["enUS"]
    local fallback = OneWoW_DirectDeposit.Locales["enUS"]
    for k, v in pairs(fallback) do
        L[k] = localeData[k] or v
    end
end


OneWoW_DirectDeposit.ApplyTheme = ApplyTheme
OneWoW_DirectDeposit.ApplyLanguage = ApplyLanguage

function OneWoW_DirectDeposit:ReinitForLanguage(langCode)
    self.db.global.language = langCode
    ApplyLanguage()
    if self.GUI then
        self.GUI:FullReset()
        C_Timer.After(0.1, function()
            self.GUI:Show()
        end)
    end
end

function OneWoW_DirectDeposit:ValidateAndCleanItemList()
    local itemList = self.db.global.directDeposit.itemList
    if not itemList then return true end

    local L = OneWoW_DirectDeposit.L
    local cleanedList = {}
    local removedCount = 0

    for key, itemData in pairs(itemList) do
        local isStringKey = type(key) == "string"
        local itemIDNum = tonumber(key)

        if itemData and itemIDNum and itemIDNum > 0 then
            local cleanKey = tostring(itemIDNum)
            cleanedList[cleanKey] = itemData
            if not isStringKey then
                removedCount = removedCount + 1
            end
        else
            removedCount = removedCount + 1
        end
    end

    if removedCount > 0 then
        print(L["ADDON_CHAT_PREFIX"] .. " Cleaned " .. removedCount .. " invalid entries from itemList")
        self.db.global.directDeposit.itemList = cleanedList
    end

    return true
end

function OneWoW_DirectDeposit:OnAddonLoaded(loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    self:InitializeDatabase()

    local g = self.db and self.db.global or {}
    OneWoW_GUI:MigrateSettings({
        theme = g.theme,
        language = g.language,
        minimap = g.minimap,
    })

    ApplyTheme()
    ApplyLanguage()
    self:InitializeModules()
    self:RegisterSlashCommands()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function()
        ApplyTheme()
        if self.GUI and self.GUI.FullReset then
            local wasShown = self.GUI:GetMainWindow() and self.GUI:GetMainWindow():IsShown()
            self.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if self.GUI and self.GUI.Show then self.GUI:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(owner, hidden)
        if owner.Minimap then owner.Minimap:SetShown(not hidden) end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner)
        if owner.Minimap then owner.Minimap:UpdateIcon() end
        if owner.GUI and owner.GUI.GetMainWindow then
            local mw = owner.GUI:GetMainWindow()
            if mw and mw.brandIcon then
                mw.brandIcon:SetTexture(OneWoW_GUI:GetBrandIcon(
                    OneWoW_GUI:GetSetting("minimap.theme") or "horde"))
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function()
        if self.GUI then
            local wasShown = self.GUI:GetMainWindow() and self.GUI:GetMainWindow():IsShown()
            self.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if self.GUI and self.GUI.Show then self.GUI:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", self, function()
        if self.GUI then
            local wasShown = self.GUI:GetMainWindow() and self.GUI:GetMainWindow():IsShown()
            self.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if self.GUI and self.GUI.Show then self.GUI:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(owner, langCode)
        owner:ReinitForLanguage(langCode)
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(ADDON_NAME)
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("DirectDeposit", _ver, "/1wdd")
    else
        OneWoW_DirectDeposit._pendingLoadVer = _ver
    end
end

function OneWoW_DirectDeposit:AddHoveredItemToList(bankType)
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

    local itemList = self.db.global.directDeposit.itemList or {}
    local existing = itemList[tostring(itemID)]

    local function bankName(bt)
        return bt == "personal" and L["ITEM_DEPOSIT_PERSONAL"]
            or bt == "warband"  and L["ITEM_DEPOSIT_WARBAND"]
            or L["ITEM_DEPOSIT_GUILD"]
    end

    if existing then
        if existing.bankType == bankType then
            self.DirectDeposit:RemoveItemFromList(itemID)
            print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800Removed|r " .. itemLink .. " |cFFFFFFFFfrom|r " .. bankName(bankType))
        else
            local oldName = bankName(existing.bankType)
            local newName = bankName(bankType)
            self.DirectDeposit:UpdateItemBankType(itemID, bankType)
            print(L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Moved|r " .. itemLink .. " |cFFFFFFFFfrom|r " .. oldName .. " |cFFFFFFFFto|r " .. newName)
        end
        if self.GUI then self.GUI:RefreshCurrentTab() end
    else
        local success, msg = self.DirectDeposit:AddItemToList(itemID, bankType)
        if success then
            print(L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Added|r " .. itemLink .. " |cFFFFFFFFto|r " .. bankName(bankType))
            if self.GUI then self.GUI:RefreshCurrentTab() end
        else
            print(L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800" .. (msg or "Failed") .. "|r")
        end
    end
end

function OneWoW_DirectDeposit:InitTooltipHook()
    local function GetBankTypeDisplay(bankType)
        if bankType == "personal" then
            return L["TOOLTIP_PERSONAL"], 1.0, 1.0, 1.0
        elseif bankType == "warband" then
            return L["TOOLTIP_WARBAND"], 0.4, 0.8, 1.0
        elseif bankType == "guild" then
            return L["TOOLTIP_GUILD"], 1.0, 0.82, 0.0
        end
        return nil
    end

    if self.oneWoWHubActive and _G.OneWoW and _G.OneWoW.TooltipEngine then
        _G.OneWoW.TooltipEngine:RegisterProvider({
            id           = "directdeposit",
            order        = 50,
            tooltipTypes = { "item" },
            callback     = function(tooltip, context)
                if not context.itemID then return nil end
                if not self.db or not self.db.global.directDeposit.tooltipEnabled then return nil end

                local itemList = self.db.global.directDeposit.itemList
                if not itemList then return nil end

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
            if not self.db or not self.db.global.directDeposit.tooltipEnabled then return end
            if not data or not data.id then return end

            local itemList = self.db.global.directDeposit.itemList
            if not itemList then return end

            local itemData = itemList[tostring(data.id)]
            if not itemData then return end

            local bankTypeName, rr, rg, rb = GetBankTypeDisplay(itemData.bankType)
            if bankTypeName then
                tooltip:AddDoubleLine("  " .. L["TOOLTIP_LABEL"], bankTypeName, 0.2, 1.0, 0.2, rr, rg, rb)
            end
        end)
    end
end

function OneWoW_DirectDeposit:InitializeModules()
    if OneWoW_DirectDeposit.DirectDeposit then
        OneWoW_DirectDeposit.DirectDeposit:Initialize()
    end

end

function OneWoW_DirectDeposit:RegisterSlashCommands()
    local existingDD = SlashCmdList["DD"]

    if not existingDD then
        SLASH_ONEWOW_DIRECTDEPOSIT1 = "/dd"
        SLASH_ONEWOW_DIRECTDEPOSIT2 = "/directdeposit"
        SLASH_ONEWOW_DIRECTDEPOSIT3 = "/directdep"
    else
        print(OneWoW_DirectDeposit.L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800/dd is already in use by another addon. Use /directdeposit or /directdep instead.|r")
        SLASH_ONEWOW_DIRECTDEPOSIT1 = "/directdeposit"
        SLASH_ONEWOW_DIRECTDEPOSIT2 = "/directdep"
    end

    SlashCmdList["ONEWOW_DIRECTDEPOSIT"] = function(msg)
        if OneWoW_DirectDeposit.GUI then
            OneWoW_DirectDeposit.GUI:Toggle()
        end
    end

    SLASH_ONEWOW_DD_TOGGLE1 = "/1wdd"
    SlashCmdList["ONEWOW_DD_TOGGLE"] = function(msg)
        if OneWoW_DirectDeposit.GUI then
            OneWoW_DirectDeposit.GUI:Toggle()
        end
    end

    SLASH_ONEWOW_DDEPOSIT1 = "/ddeposit"
    SlashCmdList["ONEWOW_DDEPOSIT"] = function(msg)
        local lowerMsg = strlower(strtrim(msg or ""))

        if lowerMsg == "pause" or lowerMsg == "stop" then
            if not OneWoW_DirectDeposit.DirectDeposit:StopDeposit() then
                print(OneWoW_DirectDeposit.L["ADDON_CHAT_PREFIX"] .. " |cFFFF8800No deposit in progress.|r")
            end
        elseif lowerMsg == "clean" then
            OneWoW_DirectDeposit:ValidateAndCleanItemList()
            print(OneWoW_DirectDeposit.L["ADDON_CHAT_PREFIX"] .. " |cFF00FF00Item list cleaned and validated.|r")
        else
            OneWoW_DirectDeposit.DirectDeposit:ManualDeposit()
        end
    end
end

_G["1WoW_DirectDeposit_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if OneWoW_DirectDeposit.GUI then
        OneWoW_DirectDeposit.GUI:Toggle()
    end
end

_G["1WoW_DirectDeposit_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD100Direct Deposit|r", 1, 1, 1)
    GameTooltip:AddLine("Click to toggle settings", 0.7, 0.7, 0.7)

    local enabled = OneWoW_DirectDeposit.db and OneWoW_DirectDeposit.db.global.directDeposit.enabled
    if enabled then
        local targetGold = OneWoW_DirectDeposit.db.global.directDeposit.targetGold or 0
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFF00FF00Enabled|r", 0.2, 1, 0.2)
        if targetGold > 0 then
            GameTooltip:AddLine("Target: " .. targetGold .. "g", 1, 0.82, 0)
        end
    else
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFFFF0000Disabled|r", 1, 0.3, 0.3)
    end

    GameTooltip:Show()
end

_G["1WoW_DirectDeposit_OnAddonCompartmentLeave"] = function(addonName, button)
    GameTooltip:Hide()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        OneWoW_DirectDeposit:OnAddonLoaded(loadedAddon)
    elseif event == "PLAYER_LOGIN" then
        DetectOneWoW()
        C_Timer.After(0, function()
            OneWoW_DirectDeposit:InitTooltipHook()
        end)
        if not OneWoW_DirectDeposit.oneWoWHubActive then
            OneWoW_DirectDeposit.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_DirectDeposit", {
                label = "Direct Deposit",
                onClick = function()
                    if OneWoW_DirectDeposit.GUI then OneWoW_DirectDeposit.GUI:Toggle() end
                end,
                onRightClick = function()
                    if OneWoW_DirectDeposit.GUI then
                        OneWoW_DirectDeposit.GUI:Show()
                        OneWoW_DirectDeposit.GUI:SelectTab(3)
                    end
                end,
                onTooltip = function(frame)
                    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
                    GameTooltip:AddLine("|cFFFFD100OneWoW|r - Direct Deposit", 1, 0.82, 0, 1)
                    local L = OneWoW_DirectDeposit.L
                    if L and L["MINIMAP_TOOLTIP_HINT"] then
                        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
                    end
                    GameTooltip:Show()
                end,
            })
            if OneWoW_DirectDeposit._pendingLoadVer then
                print("|cFF00FF00OneWoW|r: |cFFFFFFFFDirect Deposit|r |cFF888888-|r v." .. OneWoW_DirectDeposit._pendingLoadVer .. " |cFF888888-|r |cFF00FF00Loaded|r - /1wdd")
            end
        end
        if _G.OneWoW then
            _G.OneWoW:RegisterMinimap("OneWoW_DirectDeposit", (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_DD"]) or "Open Direct Deposit", nil, function()
                if OneWoW_DirectDeposit.GUI then OneWoW_DirectDeposit.GUI:Toggle() end
            end)
        end
    end
end)
