-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/t-settings.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local backdrop = {
    bgFile   = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    tile = true, tileSize = 16, edgeSize = 1,
}

local function CreateDetectionRow(parent, labelKey, descKey, isEnabled, onToggle, yPos)
    local rowFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    rowFrame:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yPos)
    rowFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yPos)
    rowFrame:SetHeight(62)
    rowFrame:SetBackdrop(backdrop)
    rowFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    rowFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local toggleBtn = CreateFrame("Button", nil, rowFrame, "BackdropTemplate")
    toggleBtn:SetSize(70, 28)
    toggleBtn:SetPoint("LEFT", rowFrame, "LEFT", 10, 0)
    toggleBtn:SetBackdrop(BACKDROP_INNER_NO_INSETS)

    local toggleLabel = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    toggleLabel:SetPoint("CENTER")

    local function RefreshToggle(enabled)
        if enabled then
            toggleBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            toggleBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            toggleLabel:SetText(L["SETTINGS_ENABLED"] or "On")
            toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        else
            toggleBtn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            toggleBtn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            toggleLabel:SetText(L["SETTINGS_DISABLED"] or "Off")
            toggleLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        end
    end

    RefreshToggle(isEnabled())

    toggleBtn:SetScript("OnClick", function()
        local newState = onToggle()
        RefreshToggle(newState)
    end)
    toggleBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
    end)
    toggleBtn:SetScript("OnLeave", function(self)
        RefreshToggle(isEnabled())
    end)

    local label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT",  rowFrame, "TOPLEFT", 90, -12)
    label:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, -12)
    label:SetJustifyH("LEFT")
    label:SetText(L[labelKey] or labelKey)
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    local desc = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT",  label, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(L[descKey] or "")
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    return rowFrame
end

function ns.UI.CreateSettingsTab(parent)
    local scrollObj = ns.UI.CreateCustomScroll(parent)
    if not scrollObj then return end

    scrollObj.container:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollObj.container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local scrollChild = scrollObj.scrollChild

    local addon = _G.OneWoW_Notes
    local yOffset = -20

    if not _G.OneWoW then
        yOffset = OneWoW_GUI:CreateSettingsPanel(scrollChild, { yOffset = yOffset, addonName = "OneWoW_Notes" })
    end

    yOffset = yOffset - 20
    local detectionSection = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = L["SETTINGS_DETECTION"] or "Detection & Alerts", yOffset = yOffset })
    yOffset = detectionSection.bottomY - 16

    local npcRow = CreateDetectionRow(
        scrollChild,
        "SETTINGS_NPC_DETECTION",
        "SETTINGS_NPC_DETECTION_DESC",
        function() return ns.NPCs and ns.NPCs:IsScanning() end,
        function()
            if ns.NPCs then
                if ns.NPCs:IsScanning() then
                    ns.NPCs:DisableScanning()
                    return false
                else
                    ns.NPCs:EnableScanning()
                    return true
                end
            end
            return false
        end,
        yOffset
    )
    yOffset = yOffset - 70

    local playerRow = CreateDetectionRow(
        scrollChild,
        "SETTINGS_PLAYER_DETECTION",
        "SETTINGS_PLAYER_DETECTION_DESC",
        function() return ns.Players and ns.Players:IsScanning() end,
        function()
            if ns.Players then
                if ns.Players:IsScanning() then
                    ns.Players:DisableScanning()
                    return false
                else
                    ns.Players:EnableScanning()
                    return true
                end
            end
            return false
        end,
        yOffset
    )
    yOffset = yOffset - 70

    local zoneRow = CreateDetectionRow(
        scrollChild,
        "SETTINGS_ZONE_ALERTS",
        "SETTINGS_ZONE_ALERTS_DESC",
        function() return ns.Zones and ns.Zones:IsScanning() end,
        function()
            if ns.Zones then
                if ns.Zones:IsScanning() then
                    ns.Zones:DisableScanning()
                    return false
                else
                    ns.Zones:EnableScanning()
                    return true
                end
            end
            return false
        end,
        yOffset
    )
    yOffset = yOffset - 70

    yOffset = yOffset - 20
    local importSection = OneWoW_GUI:CreateSectionHeader(scrollChild, { title = L["SETTINGS_IMPORT_SECTION"] or "Import From WoWNotes", yOffset = yOffset })
    yOffset = importSection.bottomY - 16

    local importContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    importContainer:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  16, yOffset)
    importContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    importContainer:SetHeight(160)
    importContainer:SetBackdrop(backdrop)
    importContainer:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    importContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local importDesc = importContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importDesc:SetPoint("TOPLEFT",  importContainer, "TOPLEFT",  16, -14)
    importDesc:SetPoint("TOPRIGHT", importContainer, "TOPRIGHT", -16, -14)
    importDesc:SetJustifyH("LEFT")
    importDesc:SetWordWrap(true)
    importDesc:SetText(L["SETTINGS_IMPORT_DESC"] or "")
    importDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local importBtn = OneWoW_GUI:CreateButton(importContainer, { text = L["SETTINGS_IMPORT_BUTTON"] or "Import From WoWNotes", width = 200, height = 28 })
    importBtn:SetPoint("BOTTOMLEFT", importContainer, "BOTTOMLEFT", 16, 14)

    local importStatus = importContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importStatus:SetPoint("LEFT",  importBtn,       "RIGHT", 12,   0)
    importStatus:SetPoint("RIGHT", importContainer, "RIGHT", -16,  0)
    importStatus:SetJustifyH("LEFT")
    importStatus:SetWordWrap(true)
    importStatus:SetText("")

    importBtn:SetScript("OnClick", function()
        if not ns.ImportFromWoWNotes then return end
        local success, result = ns.ImportFromWoWNotes:Run()
        if not success then
            importStatus:SetText(L["SETTINGS_IMPORT_NO_DATA"] or "WoWNotes data not found.")
            importStatus:SetTextColor(1, 0.3, 0.3)
        else
            importStatus:SetText(string.format(
                L["SETTINGS_IMPORT_SUCCESS"] or "Done! Notes: %d, Players: %d, NPCs: %d, Zones: %d, Items: %d",
                result.notes, result.players, result.npcs, result.zones, result.items))
            importStatus:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            if ns.UI.Reset then ns.UI:Reset() end
            C_Timer.After(0.05, function()
                if ns.UI.Show then ns.UI:Show("settings") end
            end)
        end
    end)

    yOffset = yOffset - 175

    scrollChild:SetHeight(math.abs(yOffset) + 20)
end
