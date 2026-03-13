local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_SIMPLE = OneWoW_GUI.Constants.BACKDROP_SIMPLE

ns.UI = ns.UI or {}

function ns.UI.CreateRoutinePinnedWindow(routineID)
    local routine = ns.RoutinesData:GetRoutine(routineID)
    if not routine then return nil end

    local addon = _G.OneWoW_Notes

    local W = routine.pinnedWidth or 280
    local H = routine.pinnedHeight or 400
    local TITLE_H = 24
    local PAD = 6
    local SECTION_H = 20
    local ROW_H = 18

    local f = OneWoW_GUI:CreateFrame(UIParent, {
        name = "OneWoW_Notes_RoutinePin_" .. routineID:gsub("-", ""),
        width = W,
        height = H,
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT,
    })
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)

    local savedPos = routine.pinnedPosition
    if savedPos and savedPos.point then
        f:SetPoint(savedPos.point, UIParent, savedPos.relativePoint or savedPos.point, savedPos.x or 0, savedPos.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local titleBar = OneWoW_GUI:CreateTitleBar(f, {
        title = routine.title or L["ROUTINES_UNTITLED"],
        height = TITLE_H,
        onClose = function()
            ns.RoutinesEngine:UnpinRoutine(routineID)
        end,
    })
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if not routine.pinnedLocked then f:StartMoving() end
    end)
    titleBar:SetScript("OnDragStop", function()
        f:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = f:GetPoint()
        routine.pinnedPosition = { point = point, relativePoint = relativePoint, x = xOfs, y = yOfs }
    end)

    local titleText = titleBar._titleText
    titleText:ClearAllPoints()
    titleText:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleText:SetPoint("RIGHT", titleBar, "RIGHT", -60, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetFontObject("GameFontNormalSmall")
    f.titleText = titleText

    if titleBar._closeBtn then
        titleBar._closeBtn:SetSize(16, 16)
        titleBar._closeBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(L["ROUTINES_UNPIN"], 1, 1, 1)
            GameTooltip:AddLine(L["ROUTINES_UNPIN_DESC"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        titleBar._closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    local totalLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalLabel:SetPoint("RIGHT", titleBar, "RIGHT", -30, 0)
    totalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    f.totalLabel = totalLabel

    local scroll = ns.UI.CreateCustomScroll(f)
    scroll.container:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -1)
    scroll.container:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 4)
    f._scrollFrame = scroll.scrollFrame
    f._scrollChild = scroll.scrollChild

    local dragger = CreateFrame("Frame", nil, f)
    dragger:SetSize(12, 12)
    dragger:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    dragger:SetFrameLevel(f:GetFrameLevel() + 10)
    dragger:EnableMouse(true)

    local dTex = dragger:CreateTexture(nil, "OVERLAY")
    dTex:SetAllPoints()
    dTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    dragger:SetScript("OnEnter", function()
        if not routine.pinnedLocked then
            dTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
        end
    end)
    dragger:SetScript("OnLeave", function()
        dTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    end)

    local dragStartW, dragStartH, dragStartX, dragStartY
    dragger:SetScript("OnMouseDown", function(_, button)
        if button == "LeftButton" and not routine.pinnedLocked then
            dragStartW = f:GetWidth()
            dragStartH = f:GetHeight()
            local scale = f:GetEffectiveScale()
            dragStartX, dragStartY = GetCursorPosition()
            dragStartX = dragStartX / scale
            dragStartY = dragStartY / scale
            dragger._dragging = true
        end
    end)
    dragger:SetScript("OnMouseUp", function(_, button)
        if button == "LeftButton" and dragger._dragging then
            dragger._dragging = false
            local newW = math.max(200, math.min(500, math.floor(f:GetWidth())))
            local newH = math.max(100, math.min(800, math.floor(f:GetHeight())))
            routine.pinnedWidth = newW
            routine.pinnedHeight = newH
            f:SetSize(newW, newH)
            f:Refresh()
        end
    end)
    dragger:SetScript("OnUpdate", function()
        if not dragger._dragging then return end
        local cx, cy = GetCursorPosition()
        local scale = f:GetEffectiveScale()
        cx = cx / scale; cy = cy / scale
        f:SetWidth(math.max(200, math.min(500, dragStartW + (cx - dragStartX))))
        f:SetHeight(math.max(100, math.min(800, dragStartH + (dragStartY - cy))))
    end)

    f._widgets = {}
    f._titleBar = titleBar

    function f:ApplyThemeColors()
        self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
        self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
        self._titleBar:SetBackdropColor(OneWoW_GUI:GetThemeColor("TITLEBAR_BG"))
        self.titleText:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    end

    function f:Refresh()
        for _, w in ipairs(self._widgets) do
            w:Hide()
            w:SetParent(nil)
        end
        wipe(self._widgets)

        local curRoutine = ns.RoutinesData:GetRoutine(routineID)
        if not curRoutine then
            self:Hide()
            return
        end

        self:ApplyThemeColors()

        local curW = self:GetWidth()
        self._scrollChild:SetWidth(math.max(1, curW - 14))

        self.titleText:SetText(curRoutine.title or L["ROUTINES_UNTITLED"])

        local yOff = 0
        local allDone, allTotal = 0, 0

        for _, section in ipairs(curRoutine.sections or {}) do
            local secDone, secTotal = 0, 0
            for _, task in ipairs(section.tasks or {}) do
                if not task.noMax then
                    secTotal = secTotal + 1
                    local prog = ns.RoutinesData:GetProgress(routineID, section.key, task.key)
                    if prog >= task.max then secDone = secDone + 1 end
                end
            end
            allDone = allDone + secDone
            allTotal = allTotal + secTotal

            local hdr = CreateFrame("Frame", nil, self._scrollChild, "BackdropTemplate")
            hdr:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 0, -yOff)
            hdr:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -yOff)
            hdr:SetHeight(SECTION_H)
            hdr:SetBackdrop(BACKDROP_SIMPLE)
            local secComplete = secTotal > 0 and secDone == secTotal
            if secComplete then
                hdr:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            else
                hdr:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            end
            table.insert(self._widgets, hdr)

            local accent = hdr:CreateTexture(nil, "ARTWORK")
            accent:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, 0)
            accent:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
            accent:SetWidth(3)
            accent:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

            local hdrLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hdrLabel:SetPoint("LEFT", hdr, "LEFT", 8, 0)
            hdrLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            hdrLabel:SetText(section.label or "")

            if secTotal > 0 then
                local hdrCount = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                hdrCount:SetPoint("RIGHT", hdr, "RIGHT", -6, 0)
                if secComplete then
                    hdrCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                else
                    hdrCount:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
                end
                hdrCount:SetText(string.format("%d/%d", secDone, secTotal))
            end

            yOff = yOff + SECTION_H + 1

            for _, task in ipairs(section.tasks or {}) do
                local prog = ns.RoutinesData:GetProgress(routineID, section.key, task.key)
                local isComplete = not task.noMax and prog >= task.max
                local isHidden = curRoutine.hideComplete and isComplete

                if not isHidden then
                    local rowFrame = CreateFrame("Frame", nil, self._scrollChild)
                    rowFrame:SetPoint("TOPLEFT", self._scrollChild, "TOPLEFT", 0, -yOff)
                    rowFrame:SetPoint("TOPRIGHT", self._scrollChild, "TOPRIGHT", 0, -yOff)
                    rowFrame:SetHeight(ROW_H)
                    rowFrame:EnableMouse(true)
                    table.insert(self._widgets, rowFrame)

                    local hover = rowFrame:CreateTexture(nil, "BACKGROUND")
                    hover:SetAllPoints()
                    hover:SetColorTexture(1, 1, 1, 0)

                    local dot = OneWoW_GUI:CreateStatusDot(rowFrame, { size = 6 })
                    dot:SetPoint("LEFT", rowFrame, "LEFT", PAD, 0)
                    if isComplete then
                        dot:SetStatus(true)
                    elseif prog > 0 then
                        dot:SetVertexColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
                    else
                        dot:SetStatus(false)
                    end

                    local lbl = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    lbl:SetPoint("LEFT", rowFrame, "LEFT", PAD + 10, 0)
                    lbl:SetPoint("RIGHT", rowFrame, "RIGHT", -55, 0)
                    lbl:SetJustifyH("LEFT")
                    lbl:SetText(ns.RoutinesEngine:GetTaskDisplayLabel(task))
                    if isComplete then
                        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    else
                        lbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
                    end

                    if isComplete then
                        local strike = rowFrame:CreateTexture(nil, "OVERLAY")
                        strike:SetHeight(1)
                        strike:SetPoint("LEFT", lbl, "LEFT", 0, 0)
                        strike:SetPoint("RIGHT", lbl, "RIGHT", 0, 0)
                        strike:SetColorTexture(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    end

                    local countFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    countFS:SetPoint("RIGHT", rowFrame, "RIGHT", -4, 0)
                    countFS:SetJustifyH("RIGHT")
                    if task.trackType == "prof_knowledge" then
                        local unspent = ns.RoutinesData:GetProgress(routineID, section.key, task.key .. "_u")
                        if task.max and task.max > 0 then
                            countFS:SetText(string.format("%d (%d)/%d", prog, unspent, task.max))
                        else
                            countFS:SetText(string.format("%d (%d)", prog, unspent))
                        end
                    elseif task.noMax then
                        countFS:SetText(tostring(prog))
                    else
                        countFS:SetText(string.format("%d/%d", prog, task.max))
                    end

                    if isComplete then
                        countFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
                    elseif prog > 0 then
                        countFS:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_HIGHLIGHT"))
                    else
                        countFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                    end

                    local isManual = (task.trackType == "manual")
                    if isManual then
                        rowFrame:SetScript("OnMouseDown", function(_, button)
                            if button == "LeftButton" then
                                ns.RoutinesData:BumpProgress(routineID, section.key, task.key, 1, task.max)
                                self:Refresh()
                            elseif button == "RightButton" then
                                ns.RoutinesData:BumpProgress(routineID, section.key, task.key, -1, task.max)
                                self:Refresh()
                            end
                        end)
                    end

                    rowFrame:SetScript("OnEnter", function()
                        hover:SetColorTexture(1, 1, 1, 0.04)
                        ns.RoutinesEngine:BuildTaskTooltip(task, section, rowFrame)
                    end)
                    rowFrame:SetScript("OnLeave", function()
                        hover:SetColorTexture(1, 1, 1, 0)
                        GameTooltip:Hide()
                    end)

                    yOff = yOff + ROW_H
                end
            end

            yOff = yOff + 2
        end

        if allTotal > 0 then
            if allDone >= allTotal then
                self.totalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
            else
                self.totalLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            end
            self.totalLabel:SetText(string.format("%d/%d", allDone, allTotal))
        else
            self.totalLabel:SetText("")
        end

        self._scrollChild:SetHeight(math.max(yOff, 1))

        local maxScroll = math.max(self._scrollChild:GetHeight() - self._scrollFrame:GetHeight(), 0)
        local curScroll = self._scrollFrame:GetVerticalScroll()
        if curScroll > maxScroll then
            self._scrollFrame:SetVerticalScroll(maxScroll)
        end
    end

    f:Hide()
    return f
end
