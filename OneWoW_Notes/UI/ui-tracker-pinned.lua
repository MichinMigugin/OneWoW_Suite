local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

ns.TrackerPinned = {}
local TP = ns.TrackerPinned

local pairs, ipairs, format, tinsert, tremove, wipe, math_max = pairs, ipairs, format, tinsert, tremove, wipe, math.max

local BACKDROP_SOFT = OneWoW_GUI.Constants.BACKDROP_SOFT or OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS

local sectionPool = {}
local stepPool = {}
local objPool = {}

local function AcquireSection(parent)
    local f = tremove(sectionPool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
        f:Show()
        f._count:SetText("")
        f._count:Hide()
        f:SetScript("OnClick", nil)
        return f
    end
    f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetHeight(20)
    f._accent = f:CreateTexture(nil, "ARTWORK")
    f._accent:SetSize(3, 20)
    f._accent:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    f._collapseIcon = f:CreateTexture(nil, "ARTWORK")
    f._collapseIcon:SetSize(10, 10)
    f._collapseIcon:SetPoint("LEFT", f._accent, "RIGHT", 4, 0)
    f._label = OneWoW_GUI:CreateFS(f, 10)
    f._label:SetPoint("LEFT", f._collapseIcon, "RIGHT", 3, 0)
    f._count = OneWoW_GUI:CreateFS(f, 10)
    f._count:SetPoint("RIGHT", f, "RIGHT", -6, 0)
    return f
end

local function ReleaseSection(f)
    f:Hide()
    f:SetScript("OnClick", nil)
    tinsert(sectionPool, f)
end

local function AcquireStep(parent)
    local f = tremove(stepPool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
        f:Show()
        f:SetScript("OnClick", nil)
        f:SetScript("OnEnter", nil)
        f:SetScript("OnLeave", nil)
        f:RegisterForClicks("LeftButtonUp")
        return f
    end
    f = CreateFrame("Button", nil, parent)
    f:SetHeight(18)
    f._dot = f:CreateTexture(nil, "ARTWORK")
    f._dot:SetSize(6, 6)
    f._dot:SetPoint("LEFT", f, "LEFT", 4, 0)
    f._label = OneWoW_GUI:CreateFS(f, 10)
    f._label:SetPoint("LEFT", f._dot, "RIGHT", 6, 0)
    f._label:SetJustifyH("LEFT")
    f._label:SetWordWrap(false)
    f._prog = OneWoW_GUI:CreateFS(f, 10)
    f._prog:SetPoint("RIGHT", f, "RIGHT", -4, 0)
    return f
end

local function ReleaseStep(f)
    f:Hide()
    f:SetScript("OnClick", nil)
    f:SetScript("OnEnter", nil)
    f:SetScript("OnLeave", nil)
    tinsert(stepPool, f)
end

local function AcquireObj(parent)
    local f = tremove(objPool)
    if f then
        f:SetParent(parent)
        f:ClearAllPoints()
        f:Show()
        f:SetScript("OnClick", nil)
        return f
    end
    f = CreateFrame("Button", nil, parent)
    f:SetHeight(16)
    f._dot = f:CreateTexture(nil, "ARTWORK")
    f._dot:SetSize(4, 4)
    f._dot:SetPoint("LEFT", f, "LEFT", 4, 0)
    f._label = OneWoW_GUI:CreateFS(f, 10)
    f._label:SetPoint("LEFT", f._dot, "RIGHT", 4, 0)
    f._label:SetJustifyH("LEFT")
    f._label:SetWordWrap(false)
    return f
end

local function ReleaseObj(f)
    f:Hide()
    f:SetScript("OnClick", nil)
    tinsert(objPool, f)
end

local function SetDotStatus(dot, enabled)
    if enabled then
        dot:SetColorTexture(OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED"))
    else
        dot:SetColorTexture(OneWoW_GUI:GetThemeColor("DOT_FEATURES_DISABLED"))
    end
end

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

    local totalLabel = OneWoW_GUI:CreateFS(titleBar, 10)
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

    local scrollContainer = CreateFrame("Frame", nil, frame)
    scrollContainer:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -2)
    scrollContainer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 14)

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(scrollContainer, {})

    local activeSections = {}
    local activeSteps = {}
    local activeObjs = {}

    local function ClearContent()
        for i = #activeSections, 1, -1 do
            ReleaseSection(tremove(activeSections, i))
        end
        for i = #activeSteps, 1, -1 do
            ReleaseStep(tremove(activeSteps, i))
        end
        for i = #activeObjs, 1, -1 do
            ReleaseObj(tremove(activeObjs, i))
        end
    end

    function frame:Refresh()
        ClearContent()

        local currentList = TD:GetList(listID)
        if not currentList then return end

        local done, total = TD:GetListCompletion(listID)
        totalLabel:SetText(total > 0 and format("%d/%d", done, total) or "")

        local yOffset = 0

        for _, sec in ipairs(currentList.sections) do
          if TE:IsSectionVisible(sec) then
            local secDone, secTotal = TD:GetSectionCompletion(listID, sec.key)

            local secHeader = AcquireSection(scrollChild)
            secHeader:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
            secHeader:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)
            secHeader:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_SIMPLE)

            if secTotal > 0 and secDone >= secTotal then
                secHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("ACCENT_MUTED"))
            else
                secHeader:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            end
            secHeader:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tinsert(activeSections, secHeader)

            secHeader._accent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            secHeader._collapseIcon:SetTexture(sec.collapsed and "Interface\\Buttons\\UI-PlusButton-UP" or "Interface\\Buttons\\UI-MinusButton-UP")
            secHeader._label:SetText(sec.label or "Section")
            secHeader._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

            if secTotal > 0 then
                secHeader._count:SetText(format("%d/%d", secDone, secTotal))
                secHeader._count:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                secHeader._count:Show()
            end

            secHeader:SetScript("OnClick", function()
                sec.collapsed = not sec.collapsed
                frame:Refresh()
            end)

            yOffset = yOffset - 22

          if not sec.collapsed then
            for _, step in ipairs(sec.steps or {}) do
              if TE:IsStepVisible(step, sec) then
                local sp = TD:GetStepProgress(listID, sec.key, step.key)
                local isComplete = sp.completed or false

                local stepRow = AcquireStep(scrollChild)
                stepRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 4, yOffset)
                stepRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOffset)
                tinsert(activeSteps, stepRow)

                if step.optional then
                    stepRow._dot:SetSize(6, 6)
                    stepRow._dot:SetColorTexture(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                else
                    stepRow._dot:SetSize(6, 6)
                    SetDotStatus(stepRow._dot, isComplete)
                end

                stepRow._label:ClearAllPoints()
                stepRow._label:SetPoint("LEFT", stepRow._dot, "RIGHT", 6, 0)
                stepRow._label:SetPoint("RIGHT", stepRow, "RIGHT", -50, 0)
                stepRow._label:SetText(step.label or "Step")

                if step.optional then
                    stepRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                elseif isComplete then
                    stepRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                else
                    stepRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
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

                stepRow._prog:SetText(progressStr)
                stepRow._prog:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

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

                        local objRow = AcquireObj(scrollChild)
                        objRow:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 20, yOffset)
                        objRow:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", -4, yOffset)
                        tinsert(activeObjs, objRow)

                        SetDotStatus(objRow._dot, objComplete)

                        objRow._label:ClearAllPoints()
                        objRow._label:SetPoint("LEFT", objRow._dot, "RIGHT", 4, 0)
                        objRow._label:SetPoint("RIGHT", objRow, "RIGHT", -4, 0)
                        objRow._label:SetText(obj.description or obj.type)

                        if objComplete then
                            objRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                        else
                            objRow._label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
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
            end
          end

            yOffset = yOffset - 4
          end
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
