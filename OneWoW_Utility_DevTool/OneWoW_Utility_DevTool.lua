local AddonName, Addon = ...

OneWoW_UtilityDevTool = Addon

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

Addon.version = "R6.2602.1920"
Addon.frames = {}
Addon.selectedFrame = nil
Addon.pickerActive = false

function Addon:Print(msg)
    local L = self.L or {}
    print("|cFFFFD100OneWoW|r - " .. L["ADDON_TITLE"] .. ": " .. tostring(msg))
end

function Addon:GetFrameInfo(frame)
    if not frame then return nil end

    local info = {
        name = frame.GetName and frame:GetName() or "Anonymous",
        type = frame.GetObjectType and frame:GetObjectType() or "Unknown",
        shown = frame.IsShown and frame:IsShown() or false,
        mouse = frame.IsMouseEnabled and frame:IsMouseEnabled() or false,
        protected = frame.IsProtected and frame:IsProtected() or false,
        forbidden = frame.IsForbidden and frame:IsForbidden() or false,
    }

    if frame.GetFrameStrata then
        info.strata = frame:GetFrameStrata()
    end

    if frame.GetFrameLevel then
        info.level = frame:GetFrameLevel()
    end

    if frame.GetWidth and frame.GetHeight then
        info.width = frame:GetWidth()
        info.height = frame:GetHeight()
    end

    if frame.GetPoint then
        local numPoints = frame:GetNumPoints()
        info.points = {}
        for i = 1, numPoints do
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
            local relName = "nil"
            if relativeTo then
                relName = relativeTo.GetName and relativeTo:GetName() or "Anonymous"
            end
            table.insert(info.points, {
                point = point,
                relativeTo = relName,
                relativePoint = relativePoint,
                x = x,
                y = y,
            })
        end
    end

    return info
end

function Addon:GetParentChain(frame)
    local chain = {}
    local current = frame
    while current do
        table.insert(chain, current)
        if current.GetParent then
            current = current:GetParent()
        else
            break
        end
    end
    return chain
end

function Addon:GetChildren(frame)
    if not frame or not frame.GetChildren then
        return {}
    end

    local children = {frame:GetChildren()}
    return children
end

function Addon:GetAllChildren(frame)
    if not frame then return {} end

    local all = {}
    local function addChildren(f)
        local children = Addon:GetChildren(f)
        for _, child in ipairs(children) do
            table.insert(all, child)
            addChildren(child)
        end
    end
    addChildren(frame)
    return all
end

function Addon:SearchFramesByName(searchText)
    if not searchText or searchText == "" then
        return {}
    end

    searchText = string.lower(searchText)
    local results = {}

    local function searchFrame(frame)
        if not frame then return end

        local name = frame.GetName and frame:GetName()
        if name and string.find(string.lower(name), searchText, 1, true) then
            table.insert(results, frame)
        end

        local children = Addon:GetChildren(frame)
        for _, child in ipairs(children) do
            searchFrame(child)
        end
    end

    searchFrame(UIParent)

    return results
end

function Addon:CopyToClipboard(text)
    if not OneWoW_UtilityDevToolClipboardFrame then
        local cf = CreateFrame("Frame", "OneWoW_UtilityDevToolClipboardFrame", UIParent)
        cf:Hide()
        cf.editBox = CreateFrame("EditBox", nil, cf)
        cf.editBox:Hide()
    end

    OneWoW_UtilityDevToolClipboardFrame.editBox:SetText(text)
    OneWoW_UtilityDevToolClipboardFrame.editBox:HighlightText()
    OneWoW_UtilityDevToolClipboardFrame.editBox:SetFocus()
    C_Timer.After(0.1, function()
        OneWoW_UtilityDevToolClipboardFrame.editBox:ClearFocus()
    end)

    self:Print("Copied to clipboard: " .. text)
end

function Addon:OnInitialize()
    self:InitializeDatabase()

    if self.db and self.db.minimap and not self.db.minimap.theme then
        self.db.minimap.theme = "horde"
    end

    OneWoW_GUI:MigrateSettings({
        theme = self.db.theme,
        language = self.db.language,
        minimap = self.db.minimap,
    })

    self:ApplyTheme()
    self:ApplyLanguage()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function()
        self:ApplyTheme()
        if self.UI and self.UI.FullReset then
            local wasShown = self.UI.mainFrame and self.UI.mainFrame:IsShown()
            self.UI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if self.UI and self.UI.Show then self.UI:Show() end
                end)
            end
        end
    end)

    if self.ErrorLogger then
        self.ErrorLogger:Initialize()
    end

end

function Addon:ApplyTheme()
    OneWoW_GUI:ApplyTheme(self)
end

function Addon:ApplyLanguage()
    local lang
    local hub = _G.OneWoW
    if hub and hub.db and hub.db.global then
        lang = hub.db.global.language or "enUS"
    else
        lang = self.db and self.db.language or "enUS"
    end
    if lang == "esMX" then lang = "esES" end
    local localeData = self.Locales and (self.Locales[lang] or self.Locales["enUS"])
    local fallback = self.Locales and self.Locales["enUS"]
    if localeData and fallback then
        for k, v in pairs(fallback) do
            self.L[k] = localeData[k] or v
        end
    end
end

function Addon:LoadBuiltInAtlases()
    local list = {}
    local count = C_Texture.GetAtlasCount()
    for i = 0, count - 1 do
        local atlasName = C_Texture.GetAtlasByIndex(i)
        if atlasName then
            table.insert(list, atlasName)
        end
    end
    table.sort(list)
    return list
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        Addon:OnInitialize()
        local _ver = C_AddOns.GetAddOnMetadata(AddonName, "Version") or Addon.version
        if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
            _G.OneWoW:RegisterLoadComponent("DevTools", _ver, "/1wdt")
        else
            Addon._pendingLoadVer = _ver
        end
    elseif event == "PLAYER_LOGIN" then
        if _G.OneWoW == nil then
            if Addon.Minimap then
                Addon.Minimap:Initialize()
            end
            if Addon._pendingLoadVer then
                print("|cFF00FF00OneWoW|r: |cFFFFFFFFDev Tools|r |cFF888888\226\128\147 v." .. Addon._pendingLoadVer .. " \226\128\147|r |cFF00FF00Loaded|r - /1wdt")
            end
        end
        if Addon.db and Addon.db.monitor and Addon.db.monitor.showOnLoad then
            C_Timer.After(0.5, function()
                if Addon.UI then
                    Addon.UI:Show()
                    Addon.UI:SelectTab(7)
                end
            end)
        end
    end
end)

SLASH_ONEWOW_DEVTOOL1 = "/dt"
SLASH_ONEWOW_DEVTOOL2 = "/devtool"
SLASH_ONEWOW_DEVTOOL3 = "/devtools"
SLASH_ONEWOW_DEVTOOL4 = "/1wdt"
SlashCmdList["ONEWOW_DEVTOOL"] = function(msg)
    if not Addon.UI then
        Addon:Print("UI not loaded yet")
        return
    end

    if Addon.UI.mainFrame and Addon.UI.mainFrame:IsShown() then
        Addon.UI:Hide()
    else
        Addon.UI:Show()
    end
end

_G["1WoW_UtilityDevTool_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if not Addon.UI then return end
    if Addon.UI.mainFrame and Addon.UI.mainFrame:IsShown() then
        Addon.UI:Hide()
    else
        Addon.UI:Show()
    end
end

_G["1WoW_UtilityDevTool_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD100OneWoW|r - Utility: DevTool", 1, 1, 1)
    GameTooltip:AddLine("Click to toggle window", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

_G["1WoW_UtilityDevTool_OnAddonCompartmentLeave"] = function(addonName, button)
    GameTooltip:Hide()
end
