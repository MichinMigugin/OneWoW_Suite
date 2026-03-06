local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

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

    local f = CreateFrame("Frame", "OneWoW_Notes_RoutinePin_" .. routineID:gsub("-", ""), UIParent, "BackdropTemplate")
    f:SetSize(W, H)
    f:SetFrameStrata("MEDIUM")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    f:SetBackdropColor(T("BG_PRIMARY"))
    f:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local savedPos = routine.pinnedPosition
    if savedPos and savedPos.point then
        f:SetPoint(savedPos.point, UIParent, savedPos.relativePoint or savedPos.point, savedPos.x or 0, savedPos.y or 0)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    local titleBar = CreateFrame("Frame", nil, f, "BackdropTemplate")
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    titleBar:SetHeight(TITLE_H)
    titleBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    titleBar:SetBackdropColor(T("TITLEBAR_BG"))
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

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleText:SetPoint("RIGHT", titleBar, "RIGHT", -60, 0)
    titleText:SetJustifyH("LEFT")
    titleText:SetTextColor(T("ACCENT_PRIMARY"))
    titleText:SetText(routine.title or L["ROUTINES_UNTITLED"])
    f.titleText = titleText

    local totalLabel = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    totalLabel:SetPoint("RIGHT", titleBar, "RIGHT", -30, 0)
    totalLabel:SetTextColor(T("TEXT_SECONDARY"))
    f.totalLabel = totalLabel

    local closeBtn = CreateFrame("Button", nil, titleBar)
    closeBtn:SetSize(16, 16)
    closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)
    closeBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
    closeBtn:GetHighlightTexture():SetAlpha(0.5)
    closeBtn:SetScript("OnClick", function()
        ns.RoutinesEngine:UnpinRoutine(routineID)
    end)
    closeBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["ROUTINES_UNPIN"], 1, 1, 1)
        GameTooltip:AddLine(L["ROUTINES_UNPIN_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    closeBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local scrollFrame = CreateFrame("ScrollFrame", nil, f)
    scrollFrame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -1)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)
    scrollFrame:EnableMouseWheel(true)
    f._scrollFrame = scrollFrame

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetWidth(W - 8)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)
    f._scrollChild = scrollChild

    local scrollTrack = CreateFrame("Frame", nil, f, "BackdropTemplate")
    scrollTrack:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 1, 0)
    scrollTrack:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 1, 0)
    scrollTrack:SetWidth(5)
    local trackBg = scrollTrack:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetColorTexture(0, 0, 0, 0.3)

    local scrollThumb = scrollTrack:CreateTexture(nil, "OVERLAY")
    scrollThumb:SetWidth(5)
    scrollThumb:SetColorTexture(T("ACCENT_PRIMARY"))
    f._scrollThumb = scrollThumb
    f._scrollTrack = scrollTrack

    local function UpdateScrollBar()
        local viewH = scrollFrame:GetHeight()
        local contentH = scrollChild:GetHeight()
        if contentH <= viewH or viewH <= 0 then scrollThumb:Hide() return end
        scrollThumb:Show()
        local trackH = math.max(scrollTrack:GetHeight(), 1)
        local thumbH = math.max(trackH * (viewH / contentH), 14)
        local pct = scrollFrame:GetVerticalScroll() / math.max(contentH - viewH, 1)
        scrollThumb:SetHeight(thumbH)
        scrollThumb:ClearAllPoints()
        scrollThumb:SetPoint("TOPLEFT", scrollTrack, "TOPLEFT", 0, -((trackH - thumbH) * pct))
    end

    scrollFrame:SetScript("OnMouseWheel", function(_, d)
        local cur = scrollFrame:GetVerticalScroll()
        local max = math.max(scrollChild:GetHeight() - scrollFrame:GetHeight(), 0)
        scrollFrame:SetVerticalScroll(math.max(0, math.min(cur - d * 30, max)))
        UpdateScrollBar()
    end)
    scrollFrame:SetScript("OnScrollRangeChanged", function() UpdateScrollBar() end)
    scrollFrame:SetScript("OnVerticalScroll", function() UpdateScrollBar() end)

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
    f._trackBg = trackBg

    function f:ApplyThemeColors()
        self:SetBackdropColor(T("BG_PRIMARY"))
        self:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        self._titleBar:SetBackdropColor(T("TITLEBAR_BG"))
        self.titleText:SetTextColor(T("ACCENT_PRIMARY"))
        self._scrollThumb:SetColorTexture(T("ACCENT_PRIMARY"))
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
        self._scrollChild:SetWidth(math.max(1, curW - 8))

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
            hdr:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            local secComplete = secTotal > 0 and secDone == secTotal
            if secComplete then
                hdr:SetBackdropColor(0.15, 0.35, 0.15, 0.8)
            else
                hdr:SetBackdropColor(T("BG_SECONDARY"))
            end
            table.insert(self._widgets, hdr)

            local accent = hdr:CreateTexture(nil, "ARTWORK")
            accent:SetPoint("TOPLEFT", hdr, "TOPLEFT", 0, 0)
            accent:SetPoint("BOTTOMLEFT", hdr, "BOTTOMLEFT", 0, 0)
            accent:SetWidth(3)
            accent:SetColorTexture(T("ACCENT_PRIMARY"))

            local hdrLabel = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            hdrLabel:SetPoint("LEFT", hdr, "LEFT", 8, 0)
            hdrLabel:SetTextColor(T("ACCENT_PRIMARY"))
            hdrLabel:SetText(section.label or "")

            if secTotal > 0 then
                local hdrCount = hdr:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                hdrCount:SetPoint("RIGHT", hdr, "RIGHT", -6, 0)
                if secComplete then
                    hdrCount:SetTextColor(0.4, 0.9, 0.4)
                else
                    hdrCount:SetTextColor(T("TEXT_SECONDARY"))
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

                    local dot = rowFrame:CreateTexture(nil, "ARTWORK")
                    dot:SetSize(6, 6)
                    dot:SetPoint("LEFT", rowFrame, "LEFT", PAD, 0)
                    if isComplete then
                        dot:SetColorTexture(0.2, 0.8, 0.3, 1)
                    elseif prog > 0 then
                        dot:SetColorTexture(0.9, 0.7, 0.2, 1)
                    else
                        dot:SetColorTexture(0.35, 0.35, 0.35, 1)
                    end

                    local lbl = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    lbl:SetPoint("LEFT", rowFrame, "LEFT", PAD + 10, 0)
                    lbl:SetPoint("RIGHT", rowFrame, "RIGHT", -55, 0)
                    lbl:SetJustifyH("LEFT")
                    lbl:SetText(ns.RoutinesEngine:GetTaskDisplayLabel(task))
                    if isComplete then
                        lbl:SetTextColor(0.4, 0.4, 0.4)
                    else
                        lbl:SetTextColor(T("TEXT_PRIMARY"))
                    end

                    if isComplete then
                        local strike = rowFrame:CreateTexture(nil, "OVERLAY")
                        strike:SetHeight(1)
                        strike:SetPoint("LEFT", lbl, "LEFT", 0, 0)
                        strike:SetPoint("RIGHT", lbl, "RIGHT", 0, 0)
                        strike:SetColorTexture(0.35, 0.35, 0.35, 0.7)
                    end

                    local countFS = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    countFS:SetPoint("RIGHT", rowFrame, "RIGHT", -4, 0)
                    countFS:SetJustifyH("RIGHT")
                    if task.noMax then
                        countFS:SetText(tostring(prog))
                    else
                        countFS:SetText(string.format("%d/%d", prog, task.max))
                    end

                    if isComplete then
                        countFS:SetTextColor(0.4, 0.9, 0.4)
                    elseif prog > 0 then
                        countFS:SetTextColor(0.9, 0.7, 0.2)
                    else
                        countFS:SetTextColor(T("TEXT_MUTED"))
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
                        GameTooltip:SetOwner(rowFrame, "ANCHOR_RIGHT")
                        GameTooltip:SetText(task.label or "", 1, 1, 1, 1, true)
                        if isManual then
                            GameTooltip:AddLine(L["ROUTINES_TRACK_MANUAL"] .. " - Left/Right click", 0.5, 0.5, 0.5)
                        end
                        if task.trackType == "vault_raid" or task.trackType == "vault_dungeon" or task.trackType == "vault_world" then
                            local actType = task.trackType == "vault_raid" and 3 or (task.trackType == "vault_dungeon" and 1 or 4)
                            local tierName, tierColor = ns.RoutinesEngine:GetVaultTierInfo(actType)
                            if tierName then
                                GameTooltip:AddLine("|cff" .. tierColor .. tierName .. "|r", 1, 1, 1)
                            end
                        end
                        if task.trackType == "renown" and task.trackParams and task.trackParams.factionId then
                            local data = C_MajorFactions.GetMajorFactionData(task.trackParams.factionId)
                            if data then
                                local rep = data.renownReputationEarned or 0
                                local needed = data.renownLevelThreshold or 2500
                                GameTooltip:AddLine(string.format("%d / %d rep", rep, needed), 0.7, 0.7, 0.7)
                            end
                        end
                        if task.trackType == "reputation" and task.trackParams and task.trackParams.factionId then
                            local factionData = C_Reputation.GetFactionDataByID(task.trackParams.factionId)
                            if factionData then
                                GameTooltip:AddLine(factionData.name or "", T("ACCENT_PRIMARY"))
                                local cur = factionData.currentStanding or 0
                                local low = factionData.currentReactionThreshold or 0
                                local high = factionData.nextReactionThreshold or 0
                                if high > low then
                                    GameTooltip:AddLine(string.format("%d / %d", cur - low, high - low), 0.7, 0.7, 0.7)
                                end
                            end
                        end
                        GameTooltip:Show()
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
                self.totalLabel:SetTextColor(0.4, 0.9, 0.4)
            else
                self.totalLabel:SetTextColor(T("TEXT_SECONDARY"))
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

        C_Timer.After(0.05, function()
            if self._scrollFrame and self._scrollFrame:IsShown() then
                UpdateScrollBar()
            end
        end)
    end

    f:Hide()
    return f
end
