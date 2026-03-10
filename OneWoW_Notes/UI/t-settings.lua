-- OneWoW_Notes Addon File
-- OneWoW_Notes/UI/t-settings.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

local function CreateSectionHeader(parent, text, yOffset)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    header:SetText(text)
    header:SetTextColor(T("ACCENT_PRIMARY"))
    return header
end

local function CreateSectionDivider(parent, yOffset)
    local divider = parent:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, yOffset)
    divider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yOffset)
    divider:SetColorTexture(T("BORDER_SUBTLE"))
    return divider
end

function ns.UI.CreateSettingsTab(parent)
    local scrollBarWidth = 10
    local settingsContainer = CreateFrame("Frame", nil, parent)
    settingsContainer:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    settingsContainer:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -scrollBarWidth, 0)

    local scrollFrame = CreateFrame("ScrollFrame", nil, settingsContainer)
    scrollFrame:SetAllPoints(settingsContainer)
    scrollFrame:EnableMouseWheel(true)

    local scrollTrack = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    scrollTrack:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -2, 0)
    scrollTrack:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -2, 0)
    scrollTrack:SetWidth(8)
    scrollTrack:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollTrack:SetBackdropColor(T("BG_TERTIARY"))

    local scrollThumb = CreateFrame("Frame", nil, scrollTrack, "BackdropTemplate")
    scrollThumb:SetWidth(6)
    scrollThumb:SetHeight(40)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    scrollThumb:SetBackdropColor(T("ACCENT_PRIMARY"))

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    local function UpdateThumb()
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local scroll = scrollFrame:GetVerticalScroll()
        local frameH = scrollFrame:GetHeight()
        local contentH = scrollChild:GetHeight()
        if scrollRange <= 0 or contentH <= 0 then
            scrollThumb:SetHeight(scrollTrack:GetHeight())
            scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
            return
        end
        local trackH = scrollTrack:GetHeight()
        local thumbH = math.max(20, (frameH / contentH) * trackH)
        scrollThumb:SetHeight(thumbH)
        local maxOffset = trackH - thumbH
        scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -(scroll / scrollRange) * maxOffset)
    end

    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(delta > 0 and math.max(0, current - 40) or math.min(maxScroll, current + 40))
        UpdateThumb()
    end)
    scrollFrame:HookScript("OnSizeChanged", function(self, width)
        scrollChild:SetWidth(width)
        UpdateThumb()
    end)

    scrollThumb:EnableMouse(true)
    scrollThumb:RegisterForDrag("LeftButton")
    scrollThumb:SetScript("OnMouseDown", function(self)
        self.dragging = true
        self.dragStartY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        self.dragStartScroll = scrollFrame:GetVerticalScroll()
    end)
    scrollThumb:SetScript("OnMouseUp",  function(self) self.dragging = false end)
    scrollThumb:SetScript("OnDragStop", function(self) self.dragging = false end)
    scrollThumb:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local curY = select(2, GetCursorPosition()) / self:GetEffectiveScale()
        local delta = self.dragStartY - curY
        local trackH = scrollTrack:GetHeight()
        local thumbH = self:GetHeight()
        local maxOffset = trackH - thumbH
        if maxOffset <= 0 then return end
        local scrollRange = scrollFrame:GetVerticalScrollRange()
        local newScroll = self.dragStartScroll + (delta / maxOffset) * scrollRange
        scrollFrame:SetVerticalScroll(math.max(0, math.min(scrollRange, newScroll)))
        UpdateThumb()
    end)

    local addon = _G.OneWoW_Notes
    local yOffset = -20

    -- =============================================
    -- DETECTION & ALERTS SECTION
    -- =============================================
    yOffset = yOffset - 20
    local detectionHeader = CreateSectionHeader(scrollChild, L["SETTINGS_DETECTION"] or "Detection & Alerts", yOffset)
    yOffset = yOffset - detectionHeader:GetStringHeight() - 8
    CreateSectionDivider(scrollChild, yOffset)
    yOffset = yOffset - 16

    local function CreateDetectionRow(parent, labelKey, descKey, isEnabled, onToggle, yPos)
        local rowFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        rowFrame:SetPoint("TOPLEFT",  parent, "TOPLEFT",  16, yPos)
        rowFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, yPos)
        rowFrame:SetHeight(62)
        rowFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            tile = true, tileSize = 16, edgeSize = 1,
        })
        rowFrame:SetBackdropColor(T("BG_SECONDARY"))
        rowFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

        -- Toggle button (left side)
        local toggleBtn = CreateFrame("Button", nil, rowFrame, "BackdropTemplate")
        toggleBtn:SetSize(70, 28)
        toggleBtn:SetPoint("LEFT", rowFrame, "LEFT", 10, 0)
        toggleBtn:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        local toggleLabel = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        toggleLabel:SetPoint("CENTER")

        local function RefreshToggle(enabled)
            if enabled then
                toggleBtn:SetBackdropColor(T("BG_ACTIVE"))
                toggleBtn:SetBackdropBorderColor(T("ACCENT_PRIMARY"))
                toggleLabel:SetText(L["SETTINGS_ENABLED"] or "On")
                toggleLabel:SetTextColor(T("ACCENT_PRIMARY"))
            else
                toggleBtn:SetBackdropColor(T("BG_TERTIARY"))
                toggleBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))
                toggleLabel:SetText(L["SETTINGS_DISABLED"] or "Off")
                toggleLabel:SetTextColor(T("TEXT_MUTED"))
            end
        end

        RefreshToggle(isEnabled())

        toggleBtn:SetScript("OnClick", function()
            local newState = onToggle()
            RefreshToggle(newState)
        end)
        toggleBtn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(T("BG_HOVER"))
        end)
        toggleBtn:SetScript("OnLeave", function(self)
            RefreshToggle(isEnabled())
        end)

        -- Label (right of toggle)
        local label = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT",  rowFrame, "TOPLEFT", 90, -12)
        label:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, -12)
        label:SetJustifyH("LEFT")
        label:SetText(L[labelKey] or labelKey)
        label:SetTextColor(T("TEXT_PRIMARY"))

        -- Description
        local desc = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        desc:SetPoint("TOPLEFT",  label, "BOTTOMLEFT", 0, -4)
        desc:SetPoint("TOPRIGHT", rowFrame, "TOPRIGHT", -10, 0)
        desc:SetJustifyH("LEFT")
        desc:SetWordWrap(true)
        desc:SetText(L[descKey] or "")
        desc:SetTextColor(T("TEXT_MUTED"))

        return rowFrame
    end

    -- NPC Detection
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

    -- Player Detection
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

    -- Zone Alerts
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

    -- =============================================
    -- IMPORT FROM WOWNOTES SECTION
    -- =============================================
    yOffset = yOffset - 20
    local importHeader = CreateSectionHeader(scrollChild, L["SETTINGS_IMPORT_SECTION"] or "Import From WoWNotes", yOffset)
    yOffset = yOffset - importHeader:GetStringHeight() - 8
    CreateSectionDivider(scrollChild, yOffset)
    yOffset = yOffset - 16

    local importContainer = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    importContainer:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  16, yOffset)
    importContainer:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -16, yOffset)
    importContainer:SetHeight(160)
    importContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    importContainer:SetBackdropColor(T("BG_SECONDARY"))
    importContainer:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local importDesc = importContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importDesc:SetPoint("TOPLEFT",  importContainer, "TOPLEFT",  16, -14)
    importDesc:SetPoint("TOPRIGHT", importContainer, "TOPRIGHT", -16, -14)
    importDesc:SetJustifyH("LEFT")
    importDesc:SetWordWrap(true)
    importDesc:SetText(L["SETTINGS_IMPORT_DESC"] or "")
    importDesc:SetTextColor(T("TEXT_SECONDARY"))

    local importBtn = CreateFrame("Button", nil, importContainer, "BackdropTemplate")
    importBtn:SetSize(200, 28)
    importBtn:SetPoint("BOTTOMLEFT", importContainer, "BOTTOMLEFT", 16, 14)
    importBtn:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    importBtn:SetBackdropColor(T("BG_TERTIARY"))
    importBtn:SetBackdropBorderColor(T("BORDER_SUBTLE"))

    local importBtnLabel = importBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    importBtnLabel:SetPoint("CENTER")
    importBtnLabel:SetText(L["SETTINGS_IMPORT_BUTTON"] or "Import From WoWNotes")
    importBtnLabel:SetTextColor(T("TEXT_PRIMARY"))

    importBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(T("BG_HOVER"))
        self:SetBackdropBorderColor(T("BORDER_FOCUS"))
    end)
    importBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(T("BG_TERTIARY"))
        self:SetBackdropBorderColor(T("BORDER_SUBTLE"))
    end)

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
            importStatus:SetTextColor(T("ACCENT_PRIMARY"))
            if ns.UI.Reset then ns.UI:Reset() end
            C_Timer.After(0.05, function()
                if ns.UI.Show then ns.UI:Show("settings") end
            end)
        end
    end)

    yOffset = yOffset - 175

    scrollChild:SetHeight(math.abs(yOffset) + 20)
    C_Timer.After(0.1, function() UpdateThumb() end)
end
