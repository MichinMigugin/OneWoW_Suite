local _, ns = ...
local _, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI

local UI = {}
ns.FrameMoverUI = UI

-- ============================================================
-- Helpers
-- ============================================================

local function ThemeColor(key)
    if OneWoW_GUI then return OneWoW_GUI:GetThemeColor(key) end
    if key == "ACCENT_SECONDARY" then return 1, 0.82, 0 end
    if key == "TEXT_PRIMARY"     then return 1, 1, 1 end
    if key == "TEXT_MUTED"       then return 0.5, 0.5, 0.5 end
    if key == "BORDER_SUBTLE"    then return 0.3, 0.3, 0.3 end
    return 1, 1, 1
end

local function CreateDivider(parent, yOffset)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetHeight(1)
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    tex:SetColorTexture(ThemeColor("BORDER_SUBTLE"))
    return tex
end

-- ============================================================
-- Build the full custom-detail panel
-- ============================================================

function UI:Build(detailScrollChild, yOffset, isEnabled, registerRefresh)
    local FM  = ns.FrameMoverCore
    local REG = ns.FrameMoverFrames
    if not REG or not OneWoW_GUI then return yOffset end

    -- Header --------------------------------------------------
    local header = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    header:SetText(L["FRAMEMOVER_FRAMES_HEADER"])
    header:SetTextColor(ThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - 22

    CreateDivider(detailScrollChild, yOffset)
    yOffset = yOffset - 10

    -- Reset buttons -------------------------------------------
    local resetPosBtn = CreateFrame("Button", nil, detailScrollChild, "UIPanelButtonTemplate")
    resetPosBtn:SetSize(150, 22)
    resetPosBtn:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    resetPosBtn:SetText(L["FRAMEMOVER_RESET_POSITIONS"])
    resetPosBtn:SetEnabled(isEnabled)
    resetPosBtn:SetScript("OnClick", function()
        if FM then
            FM:ResetAllPositions()
            print("|cFF00FF00OneWoW QoL:|r " .. (L["FRAMEMOVER_RESET_POS_DONE"]))
        end
    end)

    local resetScaleBtn = CreateFrame("Button", nil, detailScrollChild, "UIPanelButtonTemplate")
    resetScaleBtn:SetSize(150, 22)
    resetScaleBtn:SetPoint("LEFT", resetPosBtn, "RIGHT", 6, 0)
    resetScaleBtn:SetText(L["FRAMEMOVER_RESET_SCALES"])
    resetScaleBtn:SetEnabled(isEnabled)
    resetScaleBtn:SetScript("OnClick", function()
        if FM then
            FM:ResetAllScales()
            print("|cFF00FF00OneWoW QoL:|r " .. (L["FRAMEMOVER_RESET_SCALE_DONE"]))
        end
    end)

    if registerRefresh then
        registerRefresh(function()
            local on = ns.ModuleRegistry:IsEnabled("framemover")
            resetPosBtn:SetEnabled(on)
            resetScaleBtn:SetEnabled(on)
        end)
    end

    yOffset = yOffset - 32

    -- Per-category frame lists --------------------------------
    local onLabel  = L["FEATURES_ON"]
    local offLabel = L["FEATURES_OFF"]

    for _, cat in ipairs(REG.CATEGORIES) do
        local frames = REG:GetFramesByCategory(cat.id)
        if #frames > 0 then
            local catHeader = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            catHeader:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
            catHeader:SetText(L[cat.label])
            if isEnabled then
                catHeader:SetTextColor(ThemeColor("ACCENT_SECONDARY"))
            else
                catHeader:SetTextColor(ThemeColor("TEXT_MUTED"))
            end
            yOffset = yOffset - 18

            CreateDivider(detailScrollChild, yOffset)
            yOffset = yOffset - 8

            for _, entry in ipairs(frames) do
                local frameName   = entry.name
                local prettyName  = REG:PrettyName(frameName)
                local frameOn     = FM and FM:IsFrameEnabled(frameName) or true

                local rowRefresh
                yOffset, rowRefresh = OneWoW_GUI:CreateToggleRow(detailScrollChild, {
                    yOffset        = yOffset,
                    label          = prettyName,
                    value          = frameOn,
                    isEnabled      = isEnabled,
                    onValueChange  = function(newVal)
                        if FM then FM:SetFrameEnabled(frameName, newVal) end
                    end,
                    onLabel     = onLabel,
                    offLabel    = offLabel,
                    buttonWidth = 50,
                })

                if registerRefresh and rowRefresh then
                    local capturedName = frameName
                    registerRefresh(function()
                        local modOn = ns.ModuleRegistry:IsEnabled("framemover")
                        local val   = FM and FM:IsFrameEnabled(capturedName) or true
                        rowRefresh(modOn, val)
                    end)
                end
            end

            yOffset = yOffset - 6
        end
    end

    return yOffset
end
