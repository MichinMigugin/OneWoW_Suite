local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerPinned = {}
local TP = ns.TrackerPinned

local pairs, ipairs, format, tinsert, wipe, math_max = pairs, ipairs, format, tinsert, wipe, math.max

local BACKDROP_SOFT = OneWoW_GUI.Constants.BACKDROP_SOFT or OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

function TP:Create(listID)
    local TD = ns.TrackerData
    local TE = ns.TrackerEngine
    if not TD or not TE then return nil end

    local list = TD:GetList(listID)
    if not list then return nil end

    local frame = OneWoW_GUI:CreateFrame(nil, {
        name = "TrackerPinned_" .. listID:gsub("%-", "_"),
        width = list.pinnedWidth or 300,
        height = list.pinnedHeight or 400,
        backdrop = BACKDROP_SOFT,
    })
    frame:SetParent(UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetResizeBounds(200, 100, 500, 800)
    frame:EnableMouse(true)

    if list.pinnedPosition then
        local pp = list.pinnedPosition
        frame:SetPoint(pp.point or "CENTER", UIParent, pp.relativePoint or "CENTER", pp.x or 0, pp.y or 0)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 200, 0)
    end

    local titleBar = OneWoW_GUI:CreateTitleBar(frame, {
        title = list.title or "Tracker",
        height = 24,
        onClose = function()
            TE:DestroyPinnedWindow(listID)
        end,
    })

    local totalLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalLabel:SetPoint("RIGHT", titleBar, "RIGHT", -28, 0)
    totalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    if not list.pinnedLocked then
        titleBar:EnableMouse(true)
        titleBar:RegisterForDrag("LeftButton")
        titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
        titleBar:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
            list.pinnedPosition = { point = point, relativePoint = relativePoint, x = xOfs, y = yOfs }
        end)
    end

    local resizeBtn = CreateFrame("Button", nil, frame)
    resizeBtn:SetSize(12, 12)
    resizeBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
    resizeBtn:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeBtn:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeBtn:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

    if not list.pinnedLocked then
        resizeBtn:RegisterForDrag("LeftButton")
        resizeBtn:SetScript("OnDragStart", function() frame:StartSizing("BOTTOMRIGHT") end)
        resizeBtn:SetScript("OnDragStop", function()
            frame:StopMovingOrSizing()
            list.pinnedWidth = frame:GetWidth()
            list.pinnedHeight = frame:GetHeight()
        end)
    else
        resizeBtn:Hide()
    end

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(frame, {})
    scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 2, -2)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 16)

    local contentRows = {}

    local function ClearContent()
        for _, row in ipairs(contentRows) do
            if row.Hide then row:Hide() end
            if row.SetParent then row:SetParent(nil) end
        end
        wipe(contentRows)
    end

    function frame:Refresh()
        ClearContent()

        local currentList = TD:GetList(listID)
        if not currentList then return end

        local done, total = TD:GetListCompletion(listID)
        totalLabel:SetText(total > 0 and format("%d/%d", done, total) or "")

        local yOffset = 0

        for _, sec in ipairs(currentList.sections) do
            local secDone, secTotal = TD:GetSectionCompletion(listID, sec.key)

            local secHeader = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
            secHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            secHeader:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)
            secHeader:SetHeight(20)
            secHeader:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)

            if secTotal > 0 and secDone >= secTotal then
                secHeader:SetBackdropColor(0.15, 0.3, 0.15, 0.6)
            else
                secHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            end
            secHeader:SetBackdropBorderColor(0, 0, 0, 0)
            tinsert(contentRows, secHeader)

            local accent = secHeader:CreateTexture(nil, "ARTWORK")
            accent:SetSize(3, 20)
            accent:SetPoint("TOPLEFT", secHeader, "TOPLEFT", 0, 0)
            accent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

            local secLabel = secHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            secLabel:SetPoint("LEFT", accent, "RIGHT", 6, 0)
            secLabel:SetText(sec.label or "Section")
            secLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            if secTotal > 0 then
                local secCount = secHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                secCount:SetPoint("RIGHT", secHeader, "RIGHT", -6, 0)
                secCount:SetText(format("%d/%d", secDone, secTotal))
                secCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            yOffset = yOffset - 22

            for _, step in ipairs(sec.steps or {}) do
                local sp = TD:GetStepProgress(listID, sec.key, step.key)
                local isComplete = sp.completed or false

                local stepRow = CreateFrame("Button", nil, scrollChild)
                stepRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOffset)
                stepRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOffset)
                stepRow:SetHeight(18)
                tinsert(contentRows, stepRow)

                local dot = OneWoW_GUI:CreateStatusDot(stepRow, {
                    size = 6,
                    enabled = isComplete,
                })
                dot:SetPoint("LEFT", stepRow, "LEFT", 4, 0)

                local stepLabel = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                stepLabel:SetPoint("LEFT", dot, "RIGHT", 6, 0)
                stepLabel:SetPoint("RIGHT", stepRow, "RIGHT", -50, 0)
                stepLabel:SetJustifyH("LEFT")
                stepLabel:SetWordWrap(false)
                stepLabel:SetText(step.label or "Step")

                if isComplete then
                    stepLabel:SetTextColor(0.5, 0.5, 0.5)
                else
                    stepLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                end

                local progressStr = ""
                if step.trackType ~= "manual" or (step.max and step.max > 1) then
                    local current = sp.current or 0
                    local max = step.noMax and 0 or (step.max or 1)
                    if max > 0 then
                        progressStr = format("%d/%d", current, max)
                    elseif current > 0 then
                        progressStr = tostring(current)
                    end
                end

                local progLabel = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                progLabel:SetPoint("RIGHT", stepRow, "RIGHT", -4, 0)
                progLabel:SetText(progressStr)
                progLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

                local hasCoords = step.mapID and step.coordX and step.coordY and tonumber(step.mapID) and tonumber(step.coordX) and tonumber(step.coordY)
                if hasCoords then
                    stepRow:SetScript("OnClick", function()
                        local mid = tonumber(step.mapID)
                        local cx = tonumber(step.coordX) / 100
                        local cy = tonumber(step.coordY) / 100
                        local mapPoint = UiMapPoint.CreateFromCoordinates(mid, cx, cy)
                        C_Map.SetUserWaypoint(mapPoint)
                        C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                        print(format("|cFFFFD100OneWoW Notes:|r Waypoint set for %s (%.1f, %.1f)", step.label or "Step", tonumber(step.coordX), tonumber(step.coordY)))
                    end)
                elseif step.trackType == "manual" and (not step.objectives or #step.objectives == 0) then
                    stepRow:RegisterForClicks("AnyDown", "AnyUp")
                    stepRow:SetScript("OnClick", function(_, button)
                        if button == "LeftButton" then
                            if step.max and step.max > 1 then
                                TD:BumpStepProgress(listID, sec.key, step.key, 1, step.max)
                            else
                                TD:ToggleStepComplete(listID, sec.key, step.key)
                            end
                        elseif button == "RightButton" then
                            if sp.current and sp.current > 0 then
                                local newVal = sp.current - 1
                                TD:SetStepProgress(listID, sec.key, step.key, newVal, step.max)
                                if newVal < (step.max or 1) then
                                    sp.completed = false
                                end
                            end
                        end
                        frame:Refresh()
                        if ns.TrackerEngine then
                            ns.TrackerEngine:RefreshAllPinnedWindows()
                        end
                    end)
                end

                stepRow:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    ns.TrackerEngine:BuildStepTooltip(GameTooltip, listID, sec.key, step)
                    GameTooltip:Show()
                end)
                stepRow:SetScript("OnLeave", GameTooltip_Hide)

                yOffset = yOffset - 20

                if step.objectives and #step.objectives > 0 then
                    for _, obj in ipairs(step.objectives) do
                        local objComplete = TD:GetObjectiveProgress(listID, sec.key, step.key, obj.key)

                        local objRow = CreateFrame("Button", nil, scrollChild)
                        objRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
                        objRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOffset)
                        objRow:SetHeight(16)
                        tinsert(contentRows, objRow)

                        local objDot = OneWoW_GUI:CreateStatusDot(objRow, {
                            size = 4,
                            enabled = objComplete,
                        })
                        objDot:SetPoint("LEFT", objRow, "LEFT", 4, 0)

                        local objLabel = objRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        objLabel:SetPoint("LEFT", objDot, "RIGHT", 4, 0)
                        objLabel:SetPoint("RIGHT", objRow, "RIGHT", -4, 0)
                        objLabel:SetJustifyH("LEFT")
                        objLabel:SetWordWrap(false)
                        objLabel:SetText(obj.description or obj.type)

                        if objComplete then
                            objLabel:SetTextColor(0.5, 0.5, 0.5)
                        else
                            objLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                        end

                        if obj.type == "manual" then
                            objRow:SetScript("OnClick", function()
                                TD:SetObjectiveComplete(listID, sec.key, step.key, obj.key, not objComplete)
                                frame:Refresh()
                            end)
                        end

                        yOffset = yOffset - 18
                    end
                end
            end

            yOffset = yOffset - 4
        end

        scrollChild:SetHeight(math_max(1, math.abs(yOffset)))
    end

    function frame:ApplyThemeColors()
        frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        frame:Refresh()
    end

    frame:Refresh()
    frame:Show()
    return frame
end
