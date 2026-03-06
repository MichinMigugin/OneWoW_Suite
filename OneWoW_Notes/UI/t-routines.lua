local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local selectedRoutine = nil
local routineListItems = {}

local function CreateScrollPanel(parent, titleText)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(T("BG_PRIMARY"))
    panel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, -10)
    title:SetJustifyH("LEFT")
    title:SetText(titleText or "")
    title:SetTextColor(T("ACCENT_PRIMARY"))

    local scrollContainer = CreateFrame("Frame", nil, panel)
    scrollContainer:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -32)
    scrollContainer:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 8)

    local scrollFrame = CreateFrame("ScrollFrame", nil, scrollContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", scrollContainer, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -14, 0)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT", scrollContainer, "TOPRIGHT", -2, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", scrollContainer, "BOTTOMRIGHT", -2, 0)
        scrollBar:SetWidth(10)
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Hide()
            scrollBar.ScrollUpButton:SetAlpha(0)
            scrollBar.ScrollUpButton:EnableMouse(false)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Hide()
            scrollBar.ScrollDownButton:SetAlpha(0)
            scrollBar.ScrollDownButton:EnableMouse(false)
        end
        if scrollBar.Background then
            scrollBar.Background:SetColorTexture(T("BG_TERTIARY"))
        end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(8)
            scrollBar.ThumbTexture:SetColorTexture(T("ACCENT_PRIMARY"))
        end
    end

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetHeight(1)
    scrollFrame:SetScrollChild(scrollChild)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollChild:SetWidth(w)
    end)

    return {
        panel       = panel,
        title       = title,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
    }
end

function ns.UI.CreateRoutinesTab(parent)
    local controlPanel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    controlPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    controlPanel:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    controlPanel:SetHeight(40)
    controlPanel:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = true, tileSize = 16, edgeSize = 1,
    })
    controlPanel:SetBackdropColor(T("BG_SECONDARY"))
    controlPanel:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local newBtn = ns.UI.CreateButton(nil, controlPanel, L["ROUTINES_NEW"], 120, 25)
    ns.UI.AutoResizeButton(newBtn, 80, 200)
    newBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -8)

    local importBtn = ns.UI.CreateButton(nil, controlPanel, L["ROUTINES_IMPORT"], 90, 25)
    ns.UI.AutoResizeButton(importBtn, 80, 200)
    importBtn:SetPoint("LEFT", newBtn, "RIGHT", 5, 0)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -1)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local listScroll = CreateScrollPanel(contentArea, L["ROUTINES_LIST_TITLE"])
    listScroll.panel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
    listScroll.panel:SetPoint("BOTTOMLEFT", contentArea, "BOTTOMLEFT", 0, 0)
    listScroll.panel:SetWidth(ns.Constants.GUI.LEFT_PANEL_WIDTH)

    local detailScroll = CreateScrollPanel(contentArea, L["ROUTINES_DETAIL_TITLE"])
    detailScroll.panel:SetPoint("TOPLEFT", listScroll.panel, "TOPRIGHT", ns.Constants.GUI.PANEL_GAP, 0)
    detailScroll.panel:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", 0, 0)

    local listScrollChild = listScroll.scrollChild
    local detailScrollChild = detailScroll.scrollChild
    local detailTitle = detailScroll.title

    local emptyMessage = CreateFrame("Frame", nil, detailScroll.panel)
    emptyMessage:SetAllPoints(detailScroll.panel)
    local emptyText = emptyMessage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyText:SetPoint("CENTER", emptyMessage, "CENTER", 0, 0)
    emptyText:SetText(L["ROUTINES_SELECT"])
    emptyText:SetTextColor(T("TEXT_MUTED"))

    local function ClearDetailContent()
        for _, child in ipairs({detailScrollChild:GetChildren()}) do
            child:Hide()
            child:ClearAllPoints()
        end
    end

    local function ShowRoutineDetail(routineID)
        ClearDetailContent()
        emptyMessage:Hide()

        local routine = ns.RoutinesData:GetRoutine(routineID)
        if not routine then
            emptyMessage:Show()
            return
        end

        selectedRoutine = routineID
        detailTitle:SetText(routine.title or L["ROUTINES_UNTITLED"])

        local yOffset = 0

        local headerFrame = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
        headerFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
        headerFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
        headerFrame:SetHeight(50)
        headerFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        headerFrame:SetBackdropColor(T("BG_SECONDARY"))

        local isPinned = routine.pinned

        local pinBtn = ns.UI.CreateButton(nil, headerFrame, isPinned and L["ROUTINES_UNPIN"] or L["ROUTINES_PIN"], 80, 22)
        ns.UI.AutoResizeButton(pinBtn, 60, 100)
        pinBtn:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -10, -8)
        pinBtn:SetScript("OnClick", function()
            ns.RoutinesEngine:TogglePin(routineID)
            ShowRoutineDetail(routineID)
            parent.RefreshRoutinesList()
        end)
        pinBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(isPinned and L["ROUTINES_UNPIN"] or L["ROUTINES_PIN"], 1, 1, 1)
            GameTooltip:AddLine(isPinned and L["ROUTINES_UNPIN_DESC"] or L["ROUTINES_PIN_DESC"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        pinBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local exportBtn = ns.UI.CreateButton(nil, headerFrame, L["ROUTINES_EXPORT"], 70, 22)
        ns.UI.AutoResizeButton(exportBtn, 50, 90)
        exportBtn:SetPoint("RIGHT", pinBtn, "LEFT", -5, 0)
        exportBtn:SetScript("OnClick", function()
            local exportStr = ns.RoutinesData:ExportRoutine(routineID)
            if exportStr then
                ns.UI.ShowRoutineExportDialog(exportStr)
            end
        end)

        local deleteBtn = ns.UI.CreateButton(nil, headerFrame, L["ROUTINES_DELETE"], 70, 22)
        ns.UI.AutoResizeButton(deleteBtn, 50, 80)
        deleteBtn:SetPoint("RIGHT", exportBtn, "LEFT", -5, 0)
        deleteBtn:SetScript("OnClick", function()
            StaticPopup_Show("ONEWOW_NOTES_DELETE_ROUTINE", routine.title, nil, { routineID = routineID, refreshFunc = function()
                parent.RefreshRoutinesList()
            end})
        end)

        local resetBtn = ns.UI.CreateButton(nil, headerFrame, L["ROUTINES_RESET"], 60, 22)
        ns.UI.AutoResizeButton(resetBtn, 50, 80)
        resetBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -5, 0)
        resetBtn:SetScript("OnClick", function()
            StaticPopup_Show("ONEWOW_NOTES_RESET_ROUTINE", routine.title, nil, { routineID = routineID, refreshFunc = function()
                ShowRoutineDetail(routineID)
                parent.RefreshRoutinesList()
                ns.RoutinesEngine:RefreshPinnedWindow(routineID)
            end})
        end)

        local titleEditBox = CreateFrame("EditBox", nil, headerFrame, "BackdropTemplate")
        titleEditBox:SetSize(300, 25)
        titleEditBox:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 10, -12)
        titleEditBox:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        titleEditBox:SetBackdropColor(T("BG_TERTIARY"))
        titleEditBox:SetBackdropBorderColor(T("BORDER_DEFAULT"))
        titleEditBox:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        titleEditBox:SetTextColor(T("TEXT_PRIMARY"))
        titleEditBox:SetTextInsets(8, 8, 0, 0)
        titleEditBox:SetAutoFocus(false)
        titleEditBox:SetText(routine.title or "")
        titleEditBox:SetScript("OnEnterPressed", function(self)
            self:ClearFocus()
            ns.RoutinesData:UpdateRoutine(routineID, { title = self:GetText() })
            detailTitle:SetText(self:GetText())
            parent.RefreshRoutinesList()
            ns.RoutinesEngine:RefreshPinnedWindow(routineID)
        end)
        titleEditBox:SetScript("OnEscapePressed", function(self)
            self:ClearFocus()
        end)

        yOffset = yOffset - 55

        if not routine.sections or #routine.sections == 0 then
            local noSections = CreateFrame("Frame", nil, detailScrollChild)
            noSections:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
            noSections:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
            noSections:SetHeight(40)
            local noSecText = noSections:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noSecText:SetPoint("CENTER", noSections, "CENTER", 0, 0)
            noSecText:SetText(L["ROUTINES_NO_SECTIONS"])
            noSecText:SetTextColor(T("TEXT_MUTED"))
            yOffset = yOffset - 44
        end

        for secIdx, section in ipairs(routine.sections or {}) do
            local secFrame = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
            secFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
            secFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
            secFrame:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            secFrame:SetBackdropColor(T("BG_SECONDARY"))
            secFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))

            local secHeader = CreateFrame("Frame", nil, secFrame)
            secHeader:SetPoint("TOPLEFT", secFrame, "TOPLEFT", 0, 0)
            secHeader:SetPoint("TOPRIGHT", secFrame, "TOPRIGHT", 0, 0)
            secHeader:SetHeight(28)

            local secIcon = secHeader:CreateTexture(nil, "ARTWORK")
            secIcon:SetSize(16, 16)
            secIcon:SetPoint("LEFT", secHeader, "LEFT", 8, 0)
            secIcon:SetTexture("Interface\\ICONS\\INV_Misc_Folder")

            local secTitle = secHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            secTitle:SetPoint("LEFT", secIcon, "RIGHT", 6, 0)
            secTitle:SetPoint("RIGHT", secHeader, "RIGHT", -120, 0)
            secTitle:SetJustifyH("LEFT")
            secTitle:SetText((section.label or "") .. " |cff666666[" .. (section.type or "custom") .. "]|r")
            secTitle:SetTextColor(T("ACCENT_PRIMARY"))

            local btnX = -4
            local delSecBtn = CreateFrame("Button", nil, secHeader)
            delSecBtn:SetSize(16, 16)
            delSecBtn:SetPoint("RIGHT", secHeader, "RIGHT", btnX, 0)
            delSecBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
            delSecBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
            delSecBtn:GetHighlightTexture():SetAlpha(0.5)
            delSecBtn:SetScript("OnClick", function()
                ns.RoutinesData:RemoveSection(routineID, secIdx)
                ShowRoutineDetail(routineID)
                parent.RefreshRoutinesList()
                ns.RoutinesEngine:RefreshPinnedWindow(routineID)
            end)
            delSecBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["ROUTINES_DELETE_SECTION"], 1, 1, 1)
                GameTooltip:Show()
            end)
            delSecBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

            btnX = btnX - 20
            if secIdx > 1 then
                local moveUpBtn = CreateFrame("Button", nil, secHeader)
                moveUpBtn:SetSize(16, 16)
                moveUpBtn:SetPoint("RIGHT", secHeader, "RIGHT", btnX, 0)
                moveUpBtn:SetNormalTexture("Interface\\Buttons\\UI-MicroStream-Green")
                moveUpBtn:GetNormalTexture():SetRotation(math.rad(180))
                moveUpBtn:SetHighlightTexture("Interface\\Buttons\\UI-MicroStream-Green")
                moveUpBtn:GetHighlightTexture():SetAlpha(0.5)
                moveUpBtn:GetHighlightTexture():SetRotation(math.rad(180))
                moveUpBtn:SetScript("OnClick", function()
                    routine.sections[secIdx], routine.sections[secIdx - 1] = routine.sections[secIdx - 1], routine.sections[secIdx]
                    routine.modified = GetServerTime()
                    ShowRoutineDetail(routineID)
                    ns.RoutinesEngine:RefreshPinnedWindow(routineID)
                end)
                btnX = btnX - 20
            end

            if secIdx < #routine.sections then
                local moveDownBtn = CreateFrame("Button", nil, secHeader)
                moveDownBtn:SetSize(16, 16)
                moveDownBtn:SetPoint("RIGHT", secHeader, "RIGHT", btnX, 0)
                moveDownBtn:SetNormalTexture("Interface\\Buttons\\UI-MicroStream-Green")
                moveDownBtn:SetHighlightTexture("Interface\\Buttons\\UI-MicroStream-Green")
                moveDownBtn:GetHighlightTexture():SetAlpha(0.5)
                moveDownBtn:SetScript("OnClick", function()
                    routine.sections[secIdx], routine.sections[secIdx + 1] = routine.sections[secIdx + 1], routine.sections[secIdx]
                    routine.modified = GetServerTime()
                    ShowRoutineDetail(routineID)
                    ns.RoutinesEngine:RefreshPinnedWindow(routineID)
                end)
                btnX = btnX - 20
            end

            local innerH = 28
            local taskYOff = -28

            for taskIdx, task in ipairs(section.tasks or {}) do
                local taskRow = CreateFrame("Frame", nil, secFrame)
                taskRow:SetPoint("TOPLEFT", secFrame, "TOPLEFT", 8, taskYOff)
                taskRow:SetPoint("TOPRIGHT", secFrame, "TOPRIGHT", -8, taskYOff)
                taskRow:SetHeight(22)

                local prog = ns.RoutinesData:GetProgress(routineID, section.key, task.key)
                local isComplete = not task.noMax and prog >= task.max

                local dot = taskRow:CreateTexture(nil, "ARTWORK")
                dot:SetSize(8, 8)
                dot:SetPoint("LEFT", taskRow, "LEFT", 4, 0)
                if isComplete then
                    dot:SetColorTexture(0.2, 0.8, 0.3, 1)
                elseif prog > 0 then
                    dot:SetColorTexture(0.9, 0.7, 0.2, 1)
                else
                    dot:SetColorTexture(0.35, 0.35, 0.35, 1)
                end

                local taskLabel = taskRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                taskLabel:SetPoint("LEFT", dot, "RIGHT", 6, 0)
                taskLabel:SetPoint("RIGHT", taskRow, "RIGHT", -80, 0)
                taskLabel:SetJustifyH("LEFT")
                taskLabel:SetText(ns.RoutinesEngine:GetTaskDisplayLabel(task))
                if isComplete then
                    taskLabel:SetTextColor(0.4, 0.8, 0.4)
                else
                    taskLabel:SetTextColor(T("TEXT_PRIMARY"))
                end

                local countFS = taskRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                countFS:SetPoint("RIGHT", taskRow, "RIGHT", -30, 0)
                countFS:SetJustifyH("RIGHT")
                if task.noMax then
                    countFS:SetText(tostring(prog))
                else
                    countFS:SetText(string.format("%d/%d", prog, task.max))
                end
                countFS:SetTextColor(T("TEXT_SECONDARY"))

                local delTaskBtn = CreateFrame("Button", nil, taskRow)
                delTaskBtn:SetSize(14, 14)
                delTaskBtn:SetPoint("RIGHT", taskRow, "RIGHT", -4, 0)
                delTaskBtn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
                delTaskBtn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
                delTaskBtn:GetHighlightTexture():SetAlpha(0.5)
                delTaskBtn:SetScript("OnClick", function()
                    ns.RoutinesData:RemoveTask(routineID, secIdx, taskIdx)
                    ShowRoutineDetail(routineID)
                    parent.RefreshRoutinesList()
                    ns.RoutinesEngine:RefreshPinnedWindow(routineID)
                end)

                taskYOff = taskYOff - 24
                innerH = innerH + 24
            end

            if section.type == "custom" then
                local addTaskBtn = ns.UI.CreateButton(nil, secFrame, L["ROUTINES_ADD_TASK"], 110, 20)
                ns.UI.AutoResizeButton(addTaskBtn, 80, 140)
                addTaskBtn:SetPoint("TOPLEFT", secFrame, "TOPLEFT", 20, taskYOff - 4)
                addTaskBtn:SetScript("OnClick", function()
                    ns.UI.ShowRoutineTaskEditorDialog(routineID, secIdx, function()
                        ShowRoutineDetail(routineID)
                        parent.RefreshRoutinesList()
                        ns.RoutinesEngine:RefreshPinnedWindow(routineID)
                    end)
                end)
                taskYOff = taskYOff - 28
                innerH = innerH + 28
            end

            innerH = innerH + 6
            secFrame:SetHeight(innerH)
            yOffset = yOffset - innerH - 4
        end

        local addSectionBtn = ns.UI.CreateButton(nil, detailScrollChild, L["ROUTINES_ADD_SECTION"], 140, 28)
        ns.UI.AutoResizeButton(addSectionBtn, 100, 200)
        addSectionBtn:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yOffset - 8)
        addSectionBtn:SetScript("OnClick", function()
            ns.UI.ShowRoutineSectionEditorDialog(routineID, function()
                ShowRoutineDetail(routineID)
                parent.RefreshRoutinesList()
                ns.RoutinesEngine:RefreshPinnedWindow(routineID)
            end)
        end)

        yOffset = yOffset - 44
        detailScrollChild:SetHeight(math.abs(yOffset) + 20)
    end

    parent.ShowRoutineDetail = ShowRoutineDetail

    local function RefreshRoutinesList()
        for _, item in ipairs(routineListItems) do
            item:Hide()
            item:ClearAllPoints()
        end
        wipe(routineListItems)

        local routines = ns.RoutinesData:GetAllRoutines()
        local sorted = {}
        for id, routine in pairs(routines) do
            if type(routine) == "table" then
                table.insert(sorted, { id = id, routine = routine })
            end
        end

        table.sort(sorted, function(a, b)
            return (a.routine.title or "") < (b.routine.title or "")
        end)

        local yOff = 0

        for _, entry in ipairs(sorted) do
            local routineID = entry.id
            local routine = entry.routine

            local totalDone, totalAll = 0, 0
            for _, section in ipairs(routine.sections or {}) do
                for _, task in ipairs(section.tasks or {}) do
                    if not task.noMax then
                        totalAll = totalAll + 1
                        local prog = ns.RoutinesData:GetProgress(routineID, section.key, task.key)
                        if prog >= task.max then totalDone = totalDone + 1 end
                    end
                end
            end

            local row = CreateFrame("Button", nil, listScrollChild, "BackdropTemplate")
            row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 0, -yOff)
            row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", 0, -yOff)
            row:SetHeight(50)
            row:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })

            if routineID == selectedRoutine then
                row:SetBackdropColor(T("BG_ACTIVE"))
                row:SetBackdropBorderColor(T("BORDER_ACCENT"))
            else
                row:SetBackdropColor(T("BG_PRIMARY"))
                row:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            end

            if routine.pinned then
                local pinDot = row:CreateTexture(nil, "OVERLAY")
                pinDot:SetSize(8, 8)
                pinDot:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
                pinDot:SetTexture("Interface\\Buttons\\WHITE8x8")
                pinDot:SetVertexColor(T("ACCENT_HIGHLIGHT"))
            end

            local titleFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            titleFS:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -6)
            titleFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -40, -6)
            titleFS:SetJustifyH("LEFT")
            titleFS:SetText(routine.title or L["ROUTINES_UNTITLED"])
            titleFS:SetTextColor(T("TEXT_PRIMARY"))

            local secCount = routine.sections and #routine.sections or 0
            local metaFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            metaFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -2)
            metaFS:SetText(secCount .. " sections")
            metaFS:SetTextColor(T("TEXT_MUTED"))

            local progFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            progFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -6)
            progFS:SetText(totalDone .. "/" .. totalAll)
            if totalDone == totalAll and totalAll > 0 then
                progFS:SetTextColor(0.4, 0.8, 0.4, 1.0)
            else
                progFS:SetTextColor(T("TEXT_SECONDARY"))
            end

            local progBarBg = CreateFrame("Frame", nil, row, "BackdropTemplate")
            progBarBg:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 4)
            progBarBg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 4)
            progBarBg:SetHeight(4)
            progBarBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
            progBarBg:SetBackdropColor(T("BG_TERTIARY"))

            local progBarFill = progBarBg:CreateTexture(nil, "OVERLAY")
            progBarFill:SetPoint("TOPLEFT", progBarBg, "TOPLEFT", 0, 0)
            progBarFill:SetPoint("BOTTOMLEFT", progBarBg, "BOTTOMLEFT", 0, 0)
            progBarFill:SetTexture("Interface\\Buttons\\WHITE8x8")
            progBarFill:SetVertexColor(T("ACCENT_PRIMARY"))
            local barPct = totalAll > 0 and (totalDone / totalAll) or 0
            C_Timer.After(0.05, function()
                if progBarBg:GetWidth() > 0 then
                    progBarFill:SetWidth(math.max(1, progBarBg:GetWidth() * barPct))
                end
            end)

            row:SetScript("OnClick", function()
                ShowRoutineDetail(routineID)
                parent.RefreshRoutinesList()
            end)
            row:SetScript("OnEnter", function(self)
                if routineID ~= selectedRoutine then
                    self:SetBackdropColor(T("BG_HOVER"))
                end
            end)
            row:SetScript("OnLeave", function(self)
                if routineID ~= selectedRoutine then
                    self:SetBackdropColor(T("BG_PRIMARY"))
                end
            end)

            table.insert(routineListItems, row)
            yOff = yOff + 52
        end

        if #sorted == 0 then
            local emptyFrame = CreateFrame("Frame", nil, listScrollChild)
            emptyFrame:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 0, 0)
            emptyFrame:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", 0, 0)
            emptyFrame:SetHeight(40)
            local emptyFS = emptyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            emptyFS:SetPoint("CENTER", listScroll.panel, "CENTER", 0, 0)
            emptyFS:SetText(L["ROUTINES_EMPTY"])
            emptyFS:SetTextColor(T("TEXT_MUTED"))
            table.insert(routineListItems, emptyFrame)
        end

        listScrollChild:SetHeight(math.max(1, yOff))
    end

    parent.RefreshRoutinesList = RefreshRoutinesList

    newBtn:SetScript("OnClick", function()
        local routineID = ns.RoutinesData:AddRoutine({ title = "" })
        parent.RefreshRoutinesList()
        if routineID then
            ShowRoutineDetail(routineID)
        end
    end)

    importBtn:SetScript("OnClick", function()
        ns.UI.ShowRoutineImportDialog(function(routineID)
            parent.RefreshRoutinesList()
            if routineID then
                ShowRoutineDetail(routineID)
            end
        end)
    end)

    StaticPopupDialogs["ONEWOW_NOTES_RESET_ROUTINE"] = {
        text = L["ROUTINES_RESET_CONFIRM"],
        button1 = L["ROUTINES_RESET"],
        button2 = L["BUTTON_CANCEL"],
        OnAccept = function(self, data)
            ns.RoutinesData:ResetRoutineProgress(data.routineID)
            if data.refreshFunc then data.refreshFunc() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["ONEWOW_NOTES_DELETE_ROUTINE"] = {
        text = L["ROUTINES_DELETE_CONFIRM"],
        button1 = L["BUTTON_DELETE"],
        button2 = L["BUTTON_CANCEL"],
        OnAccept = function(self, data)
            ns.RoutinesEngine:DestroyPinnedWindow(data.routineID)
            ns.RoutinesData:RemoveRoutine(data.routineID)
            selectedRoutine = nil
            ClearDetailContent()
            emptyMessage:Show()
            detailTitle:SetText(L["ROUTINES_DETAIL_TITLE"])
            if data.refreshFunc then data.refreshFunc() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    C_Timer.After(0.2, function() RefreshRoutinesList() end)
end

function ns.UI.ShowRoutineSectionEditorDialog(routineID, callback)
    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_RoutineSectionEditor",
        title = L["ROUTINES_ADD_SECTION"],
        width = 450,
        height = 220,
        destroyOnClose = true,
        buttons = {
            {
                text = L["CATMGR_ADD"],
                onClick = function(frame)
                    local selectedType = frame._selectedType or "custom"
                    local opts = { label = frame._labelText or "" }
                    if selectedType == "professions" or selectedType == "prof_uniques" then
                        opts.professionKey = frame._professionKey
                        if not opts.professionKey then return end
                    end
                    local section = ns.RoutinesData:CreateSectionFromTemplate(selectedType, opts)
                    if section then
                        ns.RoutinesData:AddSection(routineID, section)
                        if ns.RoutinesEngine and ns.RoutinesEngine.RebuildSpellIndex then
                            ns.RoutinesEngine:RebuildSpellIndex()
                        end
                        frame:Hide()
                        if callback then callback() end
                    end
                end,
            },
            {
                text = L["BUTTON_CANCEL"],
                onClick = function(frame)
                    frame:Hide()
                end,
            },
        },
    })

    dialog._selectedType = "custom"
    dialog._labelText = ""

    local content = dialog.content

    local typeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    typeLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    typeLabel:SetText(L["ROUTINES_SECTION_TYPE"])
    typeLabel:SetTextColor(T("TEXT_PRIMARY"))

    local typeDD = ns.UI.CreateThemedDropdown(content, "", 200, 25)
    typeDD:SetPoint("TOPLEFT", typeLabel, "BOTTOMLEFT", 0, -4)
    local templates = ns.RoutinesData:GetSectionTemplates()
    local opts = {}
    for _, t in ipairs(templates) do
        table.insert(opts, { text = t.label, value = t.key })
    end
    typeDD:SetOptions(opts)
    typeDD:SetSelected("custom")

    local profLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    profLabel:SetPoint("TOPLEFT", typeDD, "TOPRIGHT", 10, 0)
    profLabel:SetText(L["ROUTINES_SECTION_PROFESSIONS"])
    profLabel:SetTextColor(T("TEXT_PRIMARY"))
    profLabel:Hide()

    local profDD = ns.UI.CreateThemedDropdown(content, "", 180, 25)
    profDD:SetPoint("TOPLEFT", profLabel, "BOTTOMLEFT", 0, -4)
    local profOpts = {}
    for _, pt in ipairs(ns.RoutinesData:GetProfessionTemplates()) do
        table.insert(profOpts, { text = pt.label, value = pt.key })
    end
    profDD:SetOptions(profOpts)
    if profOpts[1] then
        profDD:SetSelected(profOpts[1].value)
        dialog._professionKey = profOpts[1].value
    end
    profDD.onSelect = function(value)
        dialog._professionKey = value
    end
    profDD:Hide()

    typeDD.onSelect = function(value)
        dialog._selectedType = value
        if value == "professions" or value == "prof_uniques" then
            profLabel:Show()
            profDD:Show()
        else
            profLabel:Hide()
            profDD:Hide()
        end
    end

    local nameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", typeDD, "BOTTOMLEFT", 0, -10)
    nameLabel:SetText(L["ROUTINES_SECTION_LABEL"])
    nameLabel:SetTextColor(T("TEXT_PRIMARY"))

    local nameBox = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    nameBox:SetSize(200, 25)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    nameBox:SetBackdropColor(T("BG_TERTIARY"))
    nameBox:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    nameBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    nameBox:SetTextColor(T("TEXT_PRIMARY"))
    nameBox:SetTextInsets(8, 8, 0, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetScript("OnTextChanged", function(self)
        dialog._labelText = self:GetText() or ""
    end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    dialog:Show()
    dialog:Raise()
end

function ns.UI.ShowRoutineTaskEditorDialog(routineID, sectionIndex, callback)
    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_RoutineTaskEditor",
        title = L["ROUTINES_ADD_TASK"],
        width = 400,
        height = 380,
        destroyOnClose = true,
        buttons = {
            {
                text = L["CATMGR_ADD"],
                onClick = function(frame)
                    local taskData = {
                        label = frame._taskLabel or "",
                        max = tonumber(frame._taskMax) or 1,
                        trackType = frame._trackType or "manual",
                        trackParams = {},
                    }
                    if taskData.trackType == "quest" and frame._questIds and frame._questIds ~= "" then
                        local ids = {}
                        for id in frame._questIds:gmatch("%d+") do
                            table.insert(ids, tonumber(id))
                        end
                        taskData.trackParams.questIds = ids
                    elseif taskData.trackType == "currency" and frame._currencyId then
                        taskData.trackParams.currencyId = tonumber(frame._currencyId) or 0
                        if frame._noMax then
                            taskData.noMax = true
                        end
                    elseif taskData.trackType == "reputation" and frame._factionId then
                        taskData.trackParams.factionId = tonumber(frame._factionId) or 0
                        taskData.noMax = true
                    end
                    ns.RoutinesData:AddTask(routineID, sectionIndex, taskData)
                    frame:Hide()
                    if callback then callback() end
                end,
            },
            {
                text = L["BUTTON_CANCEL"],
                onClick = function(frame) frame:Hide() end,
            },
        },
    })

    dialog._taskLabel = ""
    dialog._taskMax = "1"
    dialog._trackType = "manual"
    dialog._questIds = ""
    dialog._currencyId = ""
    dialog._factionId = ""
    dialog._noMax = false

    local content = dialog.content

    local nameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    nameLabel:SetText(L["ROUTINES_TASK_LABEL"])
    nameLabel:SetTextColor(T("TEXT_PRIMARY"))

    local nameBox = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    nameBox:SetSize(260, 25)
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    nameBox:SetBackdropColor(T("BG_TERTIARY"))
    nameBox:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    nameBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    nameBox:SetTextColor(T("TEXT_PRIMARY"))
    nameBox:SetTextInsets(8, 8, 0, 0)
    nameBox:SetAutoFocus(false)
    nameBox:SetScript("OnTextChanged", function(self) dialog._taskLabel = self:GetText() or "" end)
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local maxLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    maxLabel:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -10)
    maxLabel:SetText(L["ROUTINES_TASK_MAX"])
    maxLabel:SetTextColor(T("TEXT_PRIMARY"))

    local maxBox = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    maxBox:SetSize(80, 25)
    maxBox:SetPoint("TOPLEFT", maxLabel, "BOTTOMLEFT", 0, -4)
    maxBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    maxBox:SetBackdropColor(T("BG_TERTIARY"))
    maxBox:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    maxBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    maxBox:SetTextColor(T("TEXT_PRIMARY"))
    maxBox:SetTextInsets(8, 8, 0, 0)
    maxBox:SetAutoFocus(false)
    maxBox:SetText("1")
    maxBox:SetScript("OnTextChanged", function(self) dialog._taskMax = self:GetText() or "1" end)
    maxBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local trackLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    trackLabel:SetPoint("TOPLEFT", maxBox, "BOTTOMLEFT", 0, -10)
    trackLabel:SetText(L["ROUTINES_TASK_TRACK_TYPE"])
    trackLabel:SetTextColor(T("TEXT_PRIMARY"))

    local trackDD = ns.UI.CreateThemedDropdown(content, "", 160, 25)
    trackDD:SetPoint("TOPLEFT", trackLabel, "BOTTOMLEFT", 0, -4)
    trackDD:SetOptions({
        { text = L["ROUTINES_TRACK_MANUAL"],     value = "manual" },
        { text = L["ROUTINES_TRACK_QUEST"],      value = "quest" },
        { text = L["ROUTINES_TRACK_CURRENCY"],   value = "currency" },
        { text = L["ROUTINES_TRACK_REPUTATION"], value = "reputation" },
    })
    trackDD:SetSelected("manual")

    local justTrackCheckbox = CreateFrame("CheckButton", nil, content, "BackdropTemplate")
    justTrackCheckbox:SetSize(20, 20)
    justTrackCheckbox:SetPoint("TOPLEFT", trackDD, "BOTTOMLEFT", 0, -10)
    justTrackCheckbox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    justTrackCheckbox:SetBackdropColor(T("BG_TERTIARY"))
    justTrackCheckbox:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    justTrackCheckbox:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    justTrackCheckbox:Hide()

    local justTrackLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    justTrackLabel:SetPoint("LEFT", justTrackCheckbox, "RIGHT", 6, 0)
    justTrackLabel:SetText(L["ROUTINES_JUST_TRACK"])
    justTrackLabel:SetTextColor(T("TEXT_PRIMARY"))
    justTrackLabel:Hide()

    justTrackCheckbox:SetScript("OnClick", function(self)
        dialog._noMax = self:GetChecked()
        if dialog._noMax then
            maxLabel:Hide()
            maxBox:Hide()
        else
            maxLabel:Show()
            maxBox:Show()
        end
    end)

    local questLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    questLabel:SetPoint("TOPLEFT", justTrackCheckbox, "BOTTOMLEFT", 0, -10)
    questLabel:SetText(L["ROUTINES_QUEST_IDS"] .. " / " .. L["ROUTINES_CURRENCY_ID"] .. " / " .. L["ROUTINES_FACTION_ID"])
    questLabel:SetTextColor(T("TEXT_SECONDARY"))

    local questBox = CreateFrame("EditBox", nil, content, "BackdropTemplate")
    questBox:SetSize(260, 25)
    questBox:SetPoint("TOPLEFT", questLabel, "BOTTOMLEFT", 0, -4)
    questBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    questBox:SetBackdropColor(T("BG_TERTIARY"))
    questBox:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    questBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    questBox:SetTextColor(T("TEXT_PRIMARY"))
    questBox:SetTextInsets(8, 8, 0, 0)
    questBox:SetAutoFocus(false)

    local currencyNameLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    currencyNameLabel:SetPoint("TOPLEFT", questBox, "BOTTOMLEFT", 0, -4)
    currencyNameLabel:SetText("")
    currencyNameLabel:SetTextColor(0.4, 0.9, 0.4)
    currencyNameLabel:Hide()

    questBox:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        dialog._questIds = txt
        dialog._currencyId = txt
        dialog._factionId = txt

        if dialog._trackType == "currency" then
            local id = tonumber(txt)
            if id and id > 0 then
                local info = C_CurrencyInfo.GetCurrencyInfo(id)
                if info and info.name then
                    currencyNameLabel:SetText(info.name)
                    currencyNameLabel:SetTextColor(0.4, 0.9, 0.4)
                    if nameBox:GetText() == "" then
                        nameBox:SetText(info.name)
                        dialog._taskLabel = info.name
                    end
                else
                    currencyNameLabel:SetText("Not found")
                    currencyNameLabel:SetTextColor(0.9, 0.3, 0.3)
                end
            else
                currencyNameLabel:SetText("")
            end
        end
    end)
    questBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local hintLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hintLabel:SetPoint("TOPLEFT", currencyNameLabel, "BOTTOMLEFT", 0, -4)
    hintLabel:SetText(L["ROUTINES_FACTION_ID_HINT"])
    hintLabel:SetTextColor(T("TEXT_MUTED"))

    trackDD.onSelect = function(value)
        dialog._trackType = value
        if value == "currency" then
            justTrackCheckbox:Show()
            justTrackLabel:Show()
            questLabel:SetText(L["ROUTINES_CURRENCY_ID"])
            currencyNameLabel:Show()
        else
            justTrackCheckbox:Hide()
            justTrackCheckbox:SetChecked(false)
            dialog._noMax = false
            maxLabel:Show()
            maxBox:Show()
            justTrackLabel:Hide()
            if value == "quest" then
                questLabel:SetText(L["ROUTINES_QUEST_IDS"])
            elseif value == "reputation" then
                questLabel:SetText(L["ROUTINES_FACTION_ID"])
            else
                questLabel:SetText(L["ROUTINES_QUEST_IDS"] .. " / " .. L["ROUTINES_CURRENCY_ID"] .. " / " .. L["ROUTINES_FACTION_ID"])
            end
            currencyNameLabel:SetText("")
            currencyNameLabel:Hide()
        end
    end

    dialog:Show()
    dialog:Raise()
end

function ns.UI.ShowRoutineImportDialog(callback)
    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_RoutineImport",
        title = L["ROUTINES_IMPORT"],
        width = 500,
        height = 300,
        destroyOnClose = true,
        buttons = {
            {
                text = L["ROUTINES_IMPORT"],
                onClick = function(frame)
                    local text = frame._importBox and frame._importBox:GetText() or ""
                    local routineID, err = ns.RoutinesData:ImportRoutine(text)
                    if routineID then
                        print("|cFFFFD100OneWoW Notes:|r " .. L["ROUTINES_IMPORT_SUCCESS"])
                        frame:Hide()
                        if callback then callback(routineID) end
                    else
                        print("|cFFFFD100OneWoW Notes:|r " .. L["ROUTINES_IMPORT_FAILED"] .. ": " .. (err or ""))
                    end
                end,
            },
            {
                text = L["BUTTON_CANCEL"],
                onClick = function(frame) frame:Hide() end,
            },
        },
    })

    local content = dialog.content

    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    hint:SetText(L["ROUTINES_IMPORT_HINT"])
    hint:SetTextColor(T("TEXT_SECONDARY"))

    local boxContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    boxContainer:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    boxContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)
    boxContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    boxContainer:SetBackdropColor(T("BG_TERTIARY"))
    boxContainer:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local scrollFrame = CreateFrame("ScrollFrame", nil, boxContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", boxContainer, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", boxContainer, "BOTTOMRIGHT", -24, 4)

    local importBox = CreateFrame("EditBox", nil, scrollFrame)
    importBox:SetSize(scrollFrame:GetWidth(), 1)
    importBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    importBox:SetTextColor(T("TEXT_PRIMARY"))
    importBox:SetTextInsets(4, 4, 4, 4)
    importBox:SetAutoFocus(false)
    importBox:SetMultiLine(true)
    importBox:SetScript("OnTextChanged", function(self)
        self:SetWidth(scrollFrame:GetWidth())
    end)
    scrollFrame:SetScrollChild(importBox)
    dialog._importBox = importBox

    dialog:Show()
    dialog:Raise()
end

function ns.UI.ShowRoutineExportDialog(exportStr)
    local dialog = ns.UI.CreateThemedDialog({
        name = "OneWoW_Notes_RoutineExport",
        title = L["ROUTINES_EXPORT"],
        width = 500,
        height = 300,
        destroyOnClose = true,
        buttons = {
            {
                text = L["BUTTON_CLOSE"],
                onClick = function(frame) frame:Hide() end,
            },
        },
    })

    local content = dialog.content

    local hint = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hint:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    hint:SetText(L["ROUTINES_EXPORT_HINT"])
    hint:SetTextColor(T("TEXT_SECONDARY"))

    local boxContainer = CreateFrame("Frame", nil, content, "BackdropTemplate")
    boxContainer:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
    boxContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -10, 10)
    boxContainer:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    boxContainer:SetBackdropColor(T("BG_TERTIARY"))
    boxContainer:SetBackdropBorderColor(T("BORDER_DEFAULT"))

    local scrollFrame = CreateFrame("ScrollFrame", nil, boxContainer, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", boxContainer, "TOPLEFT", 4, -4)
    scrollFrame:SetPoint("BOTTOMRIGHT", boxContainer, "BOTTOMRIGHT", -24, 4)

    local exportBox = CreateFrame("EditBox", nil, scrollFrame)
    exportBox:SetSize(scrollFrame:GetWidth(), 1)
    exportBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    exportBox:SetTextColor(T("TEXT_PRIMARY"))
    exportBox:SetTextInsets(4, 4, 4, 4)
    exportBox:SetAutoFocus(false)
    exportBox:SetMultiLine(true)
    exportBox:SetScript("OnTextChanged", function(self)
        self:SetWidth(scrollFrame:GetWidth())
    end)
    scrollFrame:SetScrollChild(exportBox)
    exportBox:SetText(exportStr or "")
    exportBox:HighlightText()

    dialog:Show()
    dialog:Raise()
end
