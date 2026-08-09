local _, ns = ...
local _, L = ns.ModuleRegistry:Current()

local OneWoW_GUI = OneWoW_GUI
local format = format
local floor = math.floor
local C_Timer = C_Timer
local wipe = wipe
local tinsert = tinsert

local UI = {}
ns.FrameMoverUI = UI

-- Session-only collapse memory (survives tab switches; cleared on /reload)
local collapsedCards = {}

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

    local cardsHost = CreateFrame("Frame", nil, detailScrollChild)
    cardsHost:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
    cardsHost:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)

    local stack = OneWoW_GUI:CreateCardStack(cardsHost, {
        getCollapsed = function(key) return collapsedCards[key] end,
        setCollapsed = function(key, collapsed) collapsedCards[key] = collapsed end,
    })

    local function applyHostHeight()
        local h = math.max(1, cardsHost:GetHeight())
        if detailScrollChild.UpdateDetailHeight then
            detailScrollChild:SetHeight(h)
            detailScrollChild.UpdateDetailHeight()
        else
            detailScrollChild:SetHeight(math.abs(yOffset) + h + 20)
            if detailScrollChild.updateThumb then
                detailScrollChild.updateThumb()
            end
        end
    end

    -- Relayout skips hidden category cards (search filter).
    function stack:Relayout()
        if self._inLayout then
            return
        end
        self._inLayout = true
        local marginX = 4
        local startY = -6
        local gap = 8
        local y = startY
        local visible = {}
        for _, frame in ipairs(self.items) do
            if frame:IsShown() then
                tinsert(visible, frame)
            end
        end
        local n = #visible
        for i, frame in ipairs(visible) do
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", marginX, y)
            frame:SetPoint("TOPRIGHT", self.parent, "TOPRIGHT", -marginX, y)
            y = y - frame:GetHeight()
            if i < n then
                y = y - gap
            end
        end
        local newH = math.max(1, math.abs(y))
        if math.abs((self.parent:GetHeight() or 0) - newH) >= 0.5 then
            self.parent:SetHeight(newH)
        end
        if self.OnRelayout then self.OnRelayout() end
        self._inLayout = false
    end
    stack.OnRelayout = applyHostHeight

    local onLabel  = L["FEATURES_ON"]
    local offLabel = L["FEATURES_OFF"]
    local catStates = {}
    local emptyLabel
    local searchBox
    local actionsRefresh
    local rowRefreshers = {}
    local framesCard
    local framesCardBaseH = 22 + 8 + 24 + 4
    local ApplyFilter

    if registerRefresh then
        registerRefresh(function()
            if actionsRefresh then
                actionsRefresh()
            end
            for _, fn in ipairs(rowRefreshers) do
                fn()
            end
            UI:RefreshScaleLabels()
        end)
    end

    framesCard = stack:AddCard("framemover:frames", L["FRAMEMOVER_FRAMES_HEADER"], function(content, contentWidth)
        wipe(rowRefreshers)
        local resetPosBtn = OneWoW_GUI:CreateFitTextButton(content, {
            text = L["FRAMEMOVER_RESET_POSITIONS"],
            height = 22,
            minWidth = 120,
            paddingX = 16,
        })
        resetPosBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        resetPosBtn:SetEnabled(isEnabled)
        resetPosBtn:SetScript("OnClick", function()
            if FM then
                FM:ResetAllPositions()
                print("|cFF00FF00OneWoW QoL:|r " .. L["FRAMEMOVER_RESET_POS_DONE"])
            end
        end)

        local resetScaleBtn = OneWoW_GUI:CreateFitTextButton(content, {
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

        searchBox = OneWoW_GUI:CreateEditBox(content, {
            height = 24,
            placeholderText = L["SEARCH"],
        })
        searchBox:SetPoint("TOPLEFT", resetPosBtn, "BOTTOMLEFT", 0, -8)
        local w = tonumber(contentWidth) or 0
        if w < 1 then
            w = content:GetWidth() or 0
        end
        if w >= 1 then
            searchBox:SetWidth(w)
        else
            searchBox:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -30)
        end
        searchBox:SetEnabled(isEnabled)

        emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        emptyLabel:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -8)
        emptyLabel:SetTextColor(ThemeColor("TEXT_MUTED"))
        emptyLabel:SetText(L["FRAMEMOVER_FILTER_EMPTY"])
        emptyLabel:Hide()

        searchBox:SetScript("OnTextChanged", function(myself)
            local text = myself:GetText()
            if text == myself.placeholderText then text = "" end
            if ApplyFilter then
                ApplyFilter(text)
            end
            UI:RefreshScaleLabels()
        end)

        actionsRefresh = function()
            local on = ns.ModuleRegistry:IsEnabled("framemover")
            resetPosBtn:SetEnabled(on)
            resetScaleBtn:SetEnabled(on)
            searchBox:SetEnabled(on)
        end

        return framesCardBaseH
    end)

    for _, cat in ipairs(REG.CATEGORIES) do
        local frames = REG:GetFramesByCategory(cat.id)
        if #frames > 0 then
            local state = { catId = cat.id, rows = {} }
            catStates[cat.id] = state

            local card = stack:AddCard("framemover:cat:" .. cat.id, L[cat.label], function(content, contentWidth)
                wipe(state.rows)
                state.content = content

                local rowY = 0
                for _, entry in ipairs(frames) do
                    local frameName   = entry.name
                    local prettyName  = REG:PrettyName(frameName)
                    local frameOn     = FM and FM:IsFrameEnabled(frameName) or true

                    local rowFrame = CreateFrame("Frame", nil, content)
                    rowFrame:SetPoint("LEFT", content, "LEFT", 0, 0)
                    rowFrame:SetPoint("RIGHT", content, "RIGHT", 0, 0)
                    rowFrame:SetPoint("TOP", content, "TOP", 0, rowY)
                    rowFrame:SetHeight(1)

                    local scaleFs
                    local resetOneBtn

                    local newY, rowRefresh = OneWoW_GUI:CreateToggleRow(rowFrame, {
                        yOffset        = 0,
                        contentWidth   = contentWidth,
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

                            resetOneBtn = OneWoW_GUI:CreateTextLink(container, {
                                text = RESET,
                                fontSize = 10,
                                onClick = function()
                                    if not FM then return end
                                    FM:ResetScale(frameName)
                                    scaleFs:SetText(FormatScalePct(FM:GetDisplayScale(frameName)))
                                end,
                            })
                            resetOneBtn:SetPoint("LEFT", scaleFs, "RIGHT", 8, 0)
                            resetOneBtn:SetEnabled(isEnabled)

                            return nil, 22
                        end,
                    })

                    rowFrame:SetHeight(math.max(1, -newY))
                    rowY = rowY - rowFrame:GetHeight()

                    local rowInfo = {
                        frame  = rowFrame,
                        name   = frameName,
                        pretty = prettyName,
                        refresh = rowRefresh,
                        resetOneBtn = resetOneBtn,
                    }
                    tinsert(state.rows, rowInfo)

                    if rowRefresh then
                        local capturedName = frameName
                        tinsert(rowRefreshers, function()
                            local modOn = ns.ModuleRegistry:IsEnabled("framemover")
                            local val   = FM and FM:IsFrameEnabled(capturedName) or true
                            if rowInfo.refresh then
                                rowInfo.refresh(modOn, val)
                            end
                            UI:RefreshScaleLabel(capturedName)
                            if rowInfo.resetOneBtn then
                                rowInfo.resetOneBtn:SetEnabled(modOn)
                            end
                        end)
                    end
                end

                function state.relayoutRows()
                    local y = 0
                    local any = false
                    for _, r in ipairs(state.rows) do
                        if r.frame:IsShown() then
                            any = true
                            r.frame:ClearAllPoints()
                            r.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
                            r.frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
                            y = y - r.frame:GetHeight()
                        end
                    end
                    return math.max(1, math.abs(y)), any
                end

                local h = state.relayoutRows()
                return h
            end)
            state.card = card
        end
    end

    ApplyFilter = function(text)
        local filter = (text or ""):lower()
        local anyVisible = false

        for _, cat in ipairs(REG.CATEGORIES) do
            local state = catStates[cat.id]
            if state and state.card then
                local catAny = false
                for _, r in ipairs(state.rows) do
                    local match = filter == ""
                        or r.pretty:lower():find(filter, 1, true)
                        or r.name:lower():find(filter, 1, true)
                    r.frame:SetShown(match)
                    if match then
                        catAny = true
                        anyVisible = true
                    end
                end

                if catAny and state.relayoutRows then
                    state.card:Show()
                    local h = state.relayoutRows()
                    state.card:SetContentHeight(h)
                else
                    state.card:Hide()
                end
            end
        end

        if emptyLabel and framesCard then
            if anyVisible then
                emptyLabel:Hide()
                framesCard:SetContentHeight(framesCardBaseH)
            else
                emptyLabel:Show()
                framesCard:SetContentHeight(framesCardBaseH + 8 + 16)
            end
        end

        stack:Relayout()
    end

    stack:Finish()
    ApplyFilter("")
    -- Finish may defer ReflowContents until host width resolves; re-apply after.
    C_Timer.After(0, function()
        local text = ""
        if searchBox then
            text = searchBox:GetText() or ""
            if text == searchBox.placeholderText then text = "" end
        end
        ApplyFilter(text)
        applyHostHeight()
    end)
    applyHostHeight()

    return yOffset - cardsHost:GetHeight()
end
