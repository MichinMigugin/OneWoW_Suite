local _, ns = ...
local _, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI
local format = format
local floor = math.floor
local C_Timer = C_Timer

local UI = {}
ns.FrameMoverUI = UI

local HUD_DURATION = 5
local hudFrame
local hudHideTimer
local hudFrameName

-- ============================================================
-- Helpers
-- ============================================================

local function ThemeColor(key)
    return OneWoW_GUI:GetThemeColor(key)
end

local function CreateDivider(parent, yOffset)
    local tex = parent:CreateTexture(nil, "ARTWORK")
    tex:SetHeight(1)
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    tex:SetColorTexture(ThemeColor("BORDER_SUBTLE"))
    return tex
end

local function FormatScalePct(scale)
    return format("%d%%", floor((scale or 1) * 100 + 0.5))
end

-- ============================================================
-- Overview scale labels (live refresh)
-- ============================================================

UI.scaleLabels = UI.scaleLabels or {}

function UI:RefreshScaleLabel(frameName)
    local FM = ns.FrameMoverCore
    local fs = self.scaleLabels[frameName]
    if fs and FM then
        fs:SetText(FormatScalePct(FM:GetDisplayScale(frameName)))
    end
end

function UI:RefreshScaleLabels()
    local FM = ns.FrameMoverCore
    if not FM then return end
    for frameName, fs in pairs(self.scaleLabels) do
        fs:SetText(FormatScalePct(FM:GetDisplayScale(frameName)))
    end
end

-- ============================================================
-- Modify HUD (brief popup on the moved/scaled frame)
-- ============================================================

function UI:HideModifyHud()
    if hudHideTimer then
        hudHideTimer:Cancel()
        hudHideTimer = nil
    end
    hudFrameName = nil
    if hudFrame then
        hudFrame:Hide()
    end
end

local function EnsureModifyHud()
    if hudFrame then return hudFrame end

    local C = OneWoW_GUI.Constants
    hudFrame = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_QoL_FM_ModifyHud",
        width = 120,
        height = 32,
        backdrop = C.BACKDROP_SOFT,
        bgColor = "BG_SECONDARY",
        borderColor = "BORDER_ACCENT",
    })
    hudFrame:SetFrameStrata("TOOLTIP")
    hudFrame:SetFrameLevel(500)
    hudFrame:EnableMouse(true)
    hudFrame:Hide()

    hudFrame.scaleFs = hudFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(hudFrame.scaleFs, 12)
    OneWoW_GUI:SafeSetFont(hudFrame.scaleFs, OneWoW_GUI:GetFont(), 12)
    hudFrame.scaleFs:SetPoint("LEFT", hudFrame, "LEFT", 10, 0)
    hudFrame.scaleFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    hudFrame.resetBtn = OneWoW_GUI:CreateFitTextButton(hudFrame, {
        text = RESET,
        height = 22,
        minWidth = 40,
        paddingX = 14,
    })
    hudFrame.resetBtn:SetPoint("RIGHT", hudFrame, "RIGHT", -6, 0)
    hudFrame.resetBtn:SetScript("OnClick", function()
        local FM = ns.FrameMoverCore
        local name = hudFrameName
        if not FM or not name then return end
        FM:ResetFrame(name)
        UI:RefreshScaleLabel(name)
        UI:HideModifyHud()
    end)

    return hudFrame
end

function UI:ShowModifyHud(frameName)
    local FM = ns.FrameMoverCore
    if not FM or not FM.active or not FM:ShowModifyHud() then return end

    local state = FM.frameStates[frameName]
    local frame = state and state.frame
    if not frame or not frame:IsVisible() then return end

    local hud = EnsureModifyHud()
    hudFrameName = frameName
    hud.scaleFs:SetText(FormatScalePct(FM:GetDisplayScale(frameName)))

    local textW = hud.scaleFs:GetStringWidth()
    local btnW = hud.resetBtn:GetWidth()
    hud:SetWidth(math.max(120, textW + btnW + 28))

    hud:ClearAllPoints()
    hud:SetPoint("TOP", frame, "BOTTOM", 0, -4)
    hud:Show()

    if hudHideTimer then
        hudHideTimer:Cancel()
    end
    hudHideTimer = C_Timer.NewTimer(HUD_DURATION, function()
        hudHideTimer = nil
        UI:HideModifyHud()
    end)
end

function UI:OnFrameModified(frameName)
    self:RefreshScaleLabel(frameName)
    self:ShowModifyHud(frameName)
end

-- ============================================================
-- Build the full custom-detail panel
-- ============================================================

function UI:Build(detailScrollChild, yOffset, isEnabled, registerRefresh)
    local FM  = ns.FrameMoverCore
    local REG = ns.FrameMoverFrames
    if not REG then return yOffset end

    wipe(self.scaleLabels)

    -- Header --------------------------------------------------
    local header = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    header:SetText(L["FRAMEMOVER_FRAMES_HEADER"])
    header:SetTextColor(ThemeColor("ACCENT_SECONDARY"))
    yOffset = yOffset - 22

    CreateDivider(detailScrollChild, yOffset)
    yOffset = yOffset - 10

    -- Reset buttons -------------------------------------------
    local resetPosBtn = OneWoW_GUI:CreateFitTextButton(detailScrollChild, {
        text = L["FRAMEMOVER_RESET_POSITIONS"],
        height = 22,
        minWidth = 120,
        paddingX = 16,
    })
    resetPosBtn:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    resetPosBtn:SetEnabled(isEnabled)
    resetPosBtn:SetScript("OnClick", function()
        if FM then
            FM:ResetAllPositions()
            print("|cFF00FF00OneWoW QoL:|r " .. L["FRAMEMOVER_RESET_POS_DONE"])
        end
    end)

    local resetScaleBtn = OneWoW_GUI:CreateFitTextButton(detailScrollChild, {
        text = L["FRAMEMOVER_RESET_SCALES"],
        height = 22,
        minWidth = 120,
        paddingX = 16,
    })
    resetScaleBtn:SetPoint("LEFT", resetPosBtn, "RIGHT", 6, 0)
    resetScaleBtn:SetEnabled(isEnabled)
    resetScaleBtn:SetScript("OnClick", function()
        if FM then
            FM:ResetAllScales()
            UI:RefreshScaleLabels()
            print("|cFF00FF00OneWoW QoL:|r " .. L["FRAMEMOVER_RESET_SCALE_DONE"])
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

    -- Search filter -------------------------------------------
    local searchBox = OneWoW_GUI:CreateEditBox(detailScrollChild, {
        height = 24,
        placeholderText = L["SEARCH"],
    })
    searchBox:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, yOffset)
    searchBox:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -12, yOffset)
    searchBox:SetEnabled(isEnabled)
    yOffset = yOffset - 30

    local emptyLabel = detailScrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    emptyLabel:SetTextColor(ThemeColor("TEXT_MUTED"))
    emptyLabel:SetText(L["FRAMEMOVER_FILTER_EMPTY"])
    emptyLabel:Hide()

    -- Per-category frame lists (filterable containers) --------
    local onLabel  = L["FEATURES_ON"]
    local offLabel = L["FEATURES_OFF"]
    local layoutItems = {}
    local listStartY = yOffset

    for _, cat in ipairs(REG.CATEGORIES) do
        local frames = REG:GetFramesByCategory(cat.id)
        if #frames > 0 then
            local catFrame = CreateFrame("Frame", nil, detailScrollChild)
            catFrame:SetPoint("LEFT", detailScrollChild, "LEFT", 0, 0)
            catFrame:SetPoint("RIGHT", detailScrollChild, "RIGHT", 0, 0)
            catFrame:SetHeight(26)

            local catHeader = catFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            catHeader:SetPoint("TOPLEFT", catFrame, "TOPLEFT", 12, 0)
            catHeader:SetText(L[cat.label])
            if isEnabled then
                catHeader:SetTextColor(ThemeColor("ACCENT_SECONDARY"))
            else
                catHeader:SetTextColor(ThemeColor("TEXT_MUTED"))
            end

            local catDiv = catFrame:CreateTexture(nil, "ARTWORK")
            catDiv:SetHeight(1)
            catDiv:SetPoint("TOPLEFT", catFrame, "TOPLEFT", 12, -16)
            catDiv:SetPoint("TOPRIGHT", catFrame, "TOPRIGHT", -12, -16)
            catDiv:SetColorTexture(ThemeColor("BORDER_SUBTLE"))

            tinsert(layoutItems, { kind = "cat", frame = catFrame, id = cat.id })

            for _, entry in ipairs(frames) do
                local frameName   = entry.name
                local prettyName  = REG:PrettyName(frameName)
                local frameOn     = FM and FM:IsFrameEnabled(frameName) or true

                local rowFrame = CreateFrame("Frame", nil, detailScrollChild)
                rowFrame:SetPoint("LEFT", detailScrollChild, "LEFT", 0, 0)
                rowFrame:SetPoint("RIGHT", detailScrollChild, "RIGHT", 0, 0)
                rowFrame:SetHeight(1)

                local scaleFs
                local resetOneBtn

                local newY, rowRefresh = OneWoW_GUI:CreateToggleRow(rowFrame, {
                    yOffset        = 0,
                    label          = prettyName,
                    value          = frameOn,
                    isEnabled      = isEnabled,
                    onValueChange  = function(newVal)
                        if FM then FM:SetFrameEnabled(frameName, newVal) end
                    end,
                    onLabel     = onLabel,
                    offLabel    = offLabel,
                    buttonWidth = 50,
                    createContent = function(container)
                        scaleFs = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        OneWoW_GUI:SetFontBaseSize(scaleFs, 10)
                        OneWoW_GUI:SafeSetFont(scaleFs, OneWoW_GUI:GetFont(), 10)
                        scaleFs:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -2)
                        scaleFs:SetJustifyH("LEFT")
                        scaleFs:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                        scaleFs:SetText(FormatScalePct(FM and FM:GetDisplayScale(frameName) or 1))
                        UI.scaleLabels[frameName] = scaleFs

                        resetOneBtn = OneWoW_GUI:CreateFitTextButton(container, {
                            text = RESET,
                            height = 20,
                            minWidth = 40,
                            paddingX = 16,
                        })
                        resetOneBtn:SetPoint("LEFT", scaleFs, "RIGHT", 8, 0)
                        resetOneBtn:SetEnabled(isEnabled)
                        resetOneBtn:SetScript("OnClick", function()
                            if not FM then return end
                            FM:ResetScale(frameName)
                            scaleFs:SetText(FormatScalePct(FM:GetDisplayScale(frameName)))
                        end)

                        return nil, 22
                    end,
                })

                rowFrame:SetHeight(math.max(1, -newY))

                tinsert(layoutItems, {
                    kind   = "row",
                    frame  = rowFrame,
                    name   = frameName,
                    pretty = prettyName,
                    catId  = cat.id,
                })

                if registerRefresh and rowRefresh then
                    local capturedName = frameName
                    registerRefresh(function()
                        local modOn = ns.ModuleRegistry:IsEnabled("framemover")
                        local val   = FM and FM:IsFrameEnabled(capturedName) or true
                        rowRefresh(modOn, val)
                        UI:RefreshScaleLabel(capturedName)
                        if resetOneBtn then
                            resetOneBtn:SetEnabled(modOn)
                        end
                    end)
                end
            end
        end
    end

    local function ApplyFilter(text)
        local filter = (text or ""):lower()
        local catVisible = {}

        for _, item in ipairs(layoutItems) do
            if item.kind == "row" then
                item.match = filter == ""
                    or item.pretty:lower():find(filter, 1, true)
                    or item.name:lower():find(filter, 1, true)
                if item.match then
                    catVisible[item.catId] = true
                end
            end
        end

        local y = listStartY
        local anyVisible = false

        for _, item in ipairs(layoutItems) do
            local show = false
            if item.kind == "cat" then
                show = catVisible[item.id]
            else
                show = item.match
            end

            if show then
                anyVisible = true
                item.frame:ClearAllPoints()
                item.frame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, y)
                item.frame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, y)
                item.frame:Show()
                y = y - item.frame:GetHeight()
            else
                item.frame:Hide()
            end
        end

        if anyVisible then
            emptyLabel:Hide()
        else
            emptyLabel:ClearAllPoints()
            emptyLabel:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 12, listStartY)
            emptyLabel:Show()
            y = listStartY - 20
        end

        detailScrollChild:SetHeight(math.abs(y) + 20)
        return y
    end

    searchBox:SetScript("OnTextChanged", function(myself)
        local text = myself:GetText()
        if text == myself.placeholderText then text = "" end
        ApplyFilter(text)
        UI:RefreshScaleLabels()
    end)

    if registerRefresh then
        registerRefresh(function()
            local on = ns.ModuleRegistry:IsEnabled("framemover")
            searchBox:SetEnabled(on)
            UI:RefreshScaleLabels()
        end)
    end

    yOffset = ApplyFilter("")
    return yOffset
end
