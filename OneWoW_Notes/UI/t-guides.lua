local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.UI = ns.UI or {}

local selectedGuide = nil
local guideListItems = {}
local categoryFilter = "All"
local searchText = ""

local OBJECTIVE_TYPE_ICONS = {
    level          = "Interface\\ICONS\\Ability_Rogue_EvisceratingBlade",
    quest_complete = "Interface\\ICONS\\INV_Misc_Map_01",
    quest_active   = "Interface\\ICONS\\INV_Misc_Map_01",
    item_count     = "Interface\\ICONS\\INV_Misc_Bag_07",
    location       = "Interface\\ICONS\\Ability_Tracking",
    achievement    = "Interface\\ICONS\\Achievement_General",
    reputation     = "Interface\\ICONS\\INV_Misc_Tournaments_Symbol_Human",
    spell_known    = "Interface\\ICONS\\INV_Misc_Book_09",
    ilvl           = "Interface\\ICONS\\INV_Helmet_03",
    currency       = "Interface\\ICONS\\INV_Misc_Coin_01",
    manual         = "Interface\\ICONS\\Ability_Marksmanship",
}

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

local function CreateSmallIconButton(parent, texture, size, tooltip, tooltipDesc)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(size, size)
    btn:SetNormalTexture(texture)
    btn:SetHighlightTexture(texture)
    btn:GetHighlightTexture():SetAlpha(0.5)
    if tooltip then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            if tooltipDesc then
                GameTooltip:AddLine(tooltipDesc, 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return btn
end

function ns.UI.CreateGuidesTab(parent)
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

    local newBtn = ns.UI.CreateButton(nil, controlPanel, L["GUIDES_NEW"], 110, 25)
    ns.UI.AutoResizeButton(newBtn, 80, 200)
    newBtn:SetPoint("TOPLEFT", controlPanel, "TOPLEFT", 10, -8)

    local importBtn = ns.UI.CreateButton(nil, controlPanel, L["GUIDES_IMPORT"], 90, 25)
    ns.UI.AutoResizeButton(importBtn, 80, 200)
    importBtn:SetPoint("LEFT", newBtn, "RIGHT", 5, 0)

    local restoreBtn = ns.UI.CreateButton(nil, controlPanel, L["GUIDES_RESTORE_BUNDLED"], 120, 25)
    ns.UI.AutoResizeButton(restoreBtn, 80, 200)
    restoreBtn:SetPoint("LEFT", importBtn, "RIGHT", 5, 0)
    restoreBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(L["GUIDES_RESTORE_BUNDLED"], 1, 1, 1)
        GameTooltip:AddLine(L["GUIDES_RESTORE_BUNDLED_DESC"], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    restoreBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    restoreBtn:SetScript("OnClick", function()
        if ns.GuidesData:LoadBundledGuides(true) then
            print("|cFFFFD100OneWoW Notes:|r " .. L["GUIDES_RESTORE_SUCCESS"])
            parent.RefreshGuidesList()
        end
    end)

    local catDD = ns.UI.CreateThemedDropdown(controlPanel, L["LABEL_CATEGORY"], 140, 25)
    catDD:SetPoint("LEFT", restoreBtn, "RIGHT", 8, 0)
    local function RefreshCatOpts()
        local opts = {{text = L["UI_ALL"], value = "All"}}
        for _, c in ipairs(ns.GuidesData:GetCategories()) do
            table.insert(opts, {text = c, value = c})
        end
        catDD:SetOptions(opts)
        catDD:SetSelected(categoryFilter)
    end
    RefreshCatOpts()
    catDD.onSelect = function(value)
        categoryFilter = value
        parent.RefreshGuidesList()
    end

    local searchBox = CreateFrame("EditBox", nil, controlPanel, "BackdropTemplate")
    searchBox:SetSize(150, 25)
    searchBox:SetPoint("LEFT", catDD, "RIGHT", 8, 0)
    searchBox:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    searchBox:SetBackdropColor(T("BG_TERTIARY"))
    searchBox:SetBackdropBorderColor(T("BORDER_DEFAULT"))
    searchBox:SetFont("Fonts\\FRIZQT__.TTF", 11, "")
    searchBox:SetTextColor(T("TEXT_PRIMARY"))
    searchBox:SetTextInsets(8, 8, 0, 0)
    searchBox:SetAutoFocus(false)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText() or ""
        parent.RefreshGuidesList()
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local searchPlaceholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    searchPlaceholder:SetText(L["GUIDES_SEARCH"])
    searchPlaceholder:SetTextColor(T("TEXT_MUTED"))
    searchBox:SetScript("OnEditFocusGained", function() searchPlaceholder:Hide() end)
    searchBox:SetScript("OnEditFocusLost", function()
        if searchBox:GetText() == "" then searchPlaceholder:Show() end
    end)

    local contentArea = CreateFrame("Frame", nil, parent)
    contentArea:SetPoint("TOPLEFT", controlPanel, "BOTTOMLEFT", 0, -1)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local listScroll = CreateScrollPanel(contentArea, L["GUIDES_LIST_TITLE"])
    listScroll.panel:SetPoint("TOPLEFT", contentArea, "TOPLEFT", 0, 0)
    listScroll.panel:SetPoint("BOTTOMLEFT", contentArea, "BOTTOMLEFT", 0, 0)
    listScroll.panel:SetWidth(ns.Constants.GUI.LEFT_PANEL_WIDTH)

    local detailScroll = CreateScrollPanel(contentArea, L["GUIDES_DETAIL_TITLE"])
    detailScroll.panel:SetPoint("TOPLEFT", listScroll.panel, "TOPRIGHT", ns.Constants.GUI.PANEL_GAP, 0)
    detailScroll.panel:SetPoint("BOTTOMRIGHT", contentArea, "BOTTOMRIGHT", 0, 0)

    local listScrollChild = listScroll.scrollChild
    local detailScrollChild = detailScroll.scrollChild
    local detailTitle = detailScroll.title

    local emptyMessage = CreateFrame("Frame", nil, detailScroll.panel)
    emptyMessage:SetAllPoints(detailScroll.panel)
    local emptyText = emptyMessage:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    emptyText:SetPoint("CENTER", emptyMessage, "CENTER", 0, 0)
    emptyText:SetText(L["GUIDES_SELECT"])
    emptyText:SetTextColor(T("TEXT_MUTED"))

    local function ClearDetailContent()
        for _, child in ipairs({detailScrollChild:GetChildren()}) do
            child:Hide()
            child:ClearAllPoints()
        end
    end

    local function RefreshDetail()
        if selectedGuide then
            parent.ShowGuideDetail(selectedGuide)
        end
    end

    local function CreateObjectiveRow(parentFrame, obj, guideID, stepIndex, objIndex, yOffset)
        local row = CreateFrame("Frame", nil, parentFrame, "BackdropTemplate")
        row:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, yOffset)
        row:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, yOffset)

        local isComplete = ns.GuidesData:IsObjectiveComplete(guideID, stepIndex, objIndex)

        local checkBtn = CreateFrame("Button", nil, row)
        checkBtn:SetSize(18, 18)
        checkBtn:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -3)

        if isComplete then
            checkBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        else
            checkBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
        end

        checkBtn:SetScript("OnClick", function()
            if ns.GuidesTracker:GetActiveGuideID() == guideID then
                ns.GuidesTracker:ManualComplete(stepIndex, objIndex, not isComplete)
            else
                ns.GuidesData:SetObjectiveComplete(guideID, stepIndex, objIndex, not isComplete)
            end
            RefreshDetail()
        end)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(16, 16)
        icon:SetPoint("TOPLEFT", checkBtn, "TOPRIGHT", 4, -1)
        icon:SetTexture(OBJECTIVE_TYPE_ICONS[obj.type] or OBJECTIVE_TYPE_ICONS["manual"])

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 6, 0)
        text:SetPoint("RIGHT", row, "RIGHT", -50, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        local rowW = parentFrame:GetWidth()
        if rowW and rowW > 100 then
            text:SetWidth(rowW - 100)
        end
        text:SetText(obj.description or "")
        if isComplete then
            text:SetTextColor(0.4, 0.8, 0.4, 1.0)
        else
            text:SetTextColor(T("TEXT_PRIMARY"))
        end

        local textH = math.max(14, text:GetStringHeight())
        local rowH = math.max(24, textH + 10)
        row:SetHeight(rowH)

        local editObjBtn = CreateSmallIconButton(row, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", 16, L["GUIDES_EDIT_OBJECTIVE"])
        editObjBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -22, -3)
        editObjBtn:SetScript("OnClick", function()
            ns.UI.ShowObjectiveEditorDialog(guideID, stepIndex, objIndex, function()
                RefreshDetail()
                parent.RefreshGuidesList()
            end)
        end)

        local delObjBtn = CreateSmallIconButton(row, "Interface\\Buttons\\UI-StopButton", 16, L["GUIDES_DELETE_OBJECTIVE"])
        delObjBtn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -4, -3)
        delObjBtn:SetScript("OnClick", function()
            ns.GuidesData:RemoveObjective(guideID, stepIndex, objIndex)
            RefreshDetail()
            parent.RefreshGuidesList()
        end)

        return row, rowH
    end

    local function ShowGuideDetail(guideID)
        ClearDetailContent()
        emptyMessage:Hide()

        local guide = ns.GuidesData:GetGuide(guideID)
        if not guide then
            emptyMessage:Show()
            return
        end

        selectedGuide = guideID
        detailTitle:SetText(guide.title or L["GUIDES_UNTITLED"])

        local progress = ns.GuidesData:GetProgress(guideID)
        local done, total = ns.GuidesData:GetCompletedStepCount(guideID)
        local isActive = ns.GuidesTracker:GetActiveGuideID() == guideID

        local yOffset = 0

        local headerFrame = CreateFrame("Frame", nil, detailScrollChild, "BackdropTemplate")
        headerFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
        headerFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
        headerFrame:SetHeight(80)
        headerFrame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        headerFrame:SetBackdropColor(T("BG_SECONDARY"))

        local authorText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        authorText:SetPoint("TOPLEFT", headerFrame, "TOPLEFT", 10, -8)
        authorText:SetText(L["GUIDES_AUTHOR"] .. ": " .. (guide.author or ""))
        authorText:SetTextColor(T("TEXT_SECONDARY"))

        local catText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        catText:SetPoint("LEFT", authorText, "RIGHT", 20, 0)
        catText:SetText(L["LABEL_CATEGORY"] .. ": " .. (guide.category or L["UI_GENERAL"]))
        catText:SetTextColor(T("TEXT_SECONDARY"))

        local progressText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        progressText:SetPoint("TOPLEFT", authorText, "BOTTOMLEFT", 0, -4)
        progressText:SetText(string.format(L["GUIDES_PROGRESS_FORMAT"], done, total))
        progressText:SetTextColor(T("ACCENT_PRIMARY"))

        local progressBarBg = CreateFrame("Frame", nil, headerFrame, "BackdropTemplate")
        progressBarBg:SetPoint("TOPLEFT", progressText, "BOTTOMLEFT", 0, -4)
        progressBarBg:SetPoint("RIGHT", headerFrame, "RIGHT", -10, 0)
        progressBarBg:SetHeight(8)
        progressBarBg:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        progressBarBg:SetBackdropColor(T("BG_TERTIARY"))

        local progressBarFill = progressBarBg:CreateTexture(nil, "OVERLAY")
        progressBarFill:SetPoint("TOPLEFT", progressBarBg, "TOPLEFT", 0, 0)
        progressBarFill:SetPoint("BOTTOMLEFT", progressBarBg, "BOTTOMLEFT", 0, 0)
        local pct = total > 0 and (done / total) or 0
        progressBarFill:SetTexture("Interface\\Buttons\\WHITE8x8")
        progressBarFill:SetVertexColor(T("ACCENT_PRIMARY"))

        C_Timer.After(0.05, function()
            if progressBarBg:GetWidth() > 0 then
                progressBarFill:SetWidth(math.max(1, progressBarBg:GetWidth() * pct))
            end
        end)

        local activateBtn = ns.UI.CreateButton(nil, headerFrame, isActive and L["GUIDES_DEACTIVATE"] or L["GUIDES_ACTIVATE"], 100, 22)
        ns.UI.AutoResizeButton(activateBtn, 70, 120)
        activateBtn:SetPoint("TOPRIGHT", headerFrame, "TOPRIGHT", -10, -8)
        activateBtn:SetScript("OnClick", function()
            if isActive then
                ns.GuidesTracker:Deactivate()
            else
                ns.GuidesTracker:Activate(guideID)
            end
            ShowGuideDetail(guideID)
            parent.RefreshGuidesList()
        end)
        activateBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(isActive and L["GUIDES_DEACTIVATE"] or L["GUIDES_ACTIVATE"], 1, 1, 1)
            GameTooltip:AddLine(isActive and L["GUIDES_TT_STOP_DESC"] or L["GUIDES_TT_TRACK_DESC"], 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        activateBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        local editBtn = ns.UI.CreateButton(nil, headerFrame, L["GUIDES_EDIT"], 60, 22)
        ns.UI.AutoResizeButton(editBtn, 50, 80)
        editBtn:SetPoint("RIGHT", activateBtn, "LEFT", -5, 0)
        editBtn:SetScript("OnClick", function()
            ns.UI.ShowGuideEditorDialog(guideID, function()
                ShowGuideDetail(guideID)
                parent.RefreshGuidesList()
            end)
        end)

        local exportBtn = ns.UI.CreateButton(nil, headerFrame, L["GUIDES_EXPORT"], 70, 22)
        ns.UI.AutoResizeButton(exportBtn, 50, 80)
        exportBtn:SetPoint("RIGHT", editBtn, "LEFT", -5, 0)
        exportBtn:SetScript("OnClick", function()
            ns.UI.ShowGuideExportDialog(guideID)
        end)

        local deleteBtn = ns.UI.CreateButton(nil, headerFrame, L["GUIDES_DELETE"], 70, 22)
        ns.UI.AutoResizeButton(deleteBtn, 50, 80)
        deleteBtn:SetPoint("RIGHT", exportBtn, "LEFT", -5, 0)
        deleteBtn:SetScript("OnClick", function()
            StaticPopup_Show("ONEWOW_NOTES_DELETE_GUIDE", guide.title, nil, { guideID = guideID, refreshFunc = function()
                parent.RefreshGuidesList()
            end})
        end)

        local resetBtn = ns.UI.CreateButton(nil, headerFrame, L["GUIDES_RESET"], 60, 22)
        ns.UI.AutoResizeButton(resetBtn, 50, 80)
        resetBtn:SetPoint("RIGHT", deleteBtn, "LEFT", -5, 0)
        resetBtn:SetScript("OnClick", function()
            StaticPopup_Show("ONEWOW_NOTES_RESET_GUIDE", guide.title, nil, { guideID = guideID, refreshFunc = function()
                ShowGuideDetail(guideID)
                parent.RefreshGuidesList()
            end})
        end)

        yOffset = yOffset - 85

        if guide.description and guide.description ~= "" then
            local descFrame = CreateFrame("Frame", nil, detailScrollChild)
            descFrame:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
            descFrame:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)

            local descText = descFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            descText:SetPoint("TOPLEFT", descFrame, "TOPLEFT", 10, -6)
            descText:SetPoint("TOPRIGHT", descFrame, "TOPRIGHT", -10, -6)
            descText:SetJustifyH("LEFT")
            descText:SetWordWrap(true)
            descText:SetText(guide.description)
            descText:SetTextColor(T("TEXT_SECONDARY"))

            local panelW = detailScroll.panel:GetWidth()
            if panelW and panelW > 40 then
                descText:SetWidth(panelW - 40)
            end
            local descH = math.max(20, descText:GetStringHeight()) + 16
            descFrame:SetHeight(descH)
            yOffset = yOffset - descH - 4
        end

        if not guide.steps or #guide.steps == 0 then
            local noSteps = CreateFrame("Frame", nil, detailScrollChild)
            noSteps:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 0, yOffset)
            noSteps:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", 0, yOffset)
            noSteps:SetHeight(40)
            local noStepsText = noSteps:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            noStepsText:SetPoint("CENTER", noSteps, "CENTER", 0, 0)
            noStepsText:SetText(L["GUIDES_NO_STEPS"])
            noStepsText:SetTextColor(T("TEXT_MUTED"))
            yOffset = yOffset - 44
        end

        local currentStep = progress.currentStep or 1
        local playerFaction = UnitFactionGroup("player")

        for stepIdx, step in ipairs(guide.steps or {}) do
            local skipStep = false
            if step.faction and step.faction ~= "both" then
                if step.faction ~= string.lower(playerFaction or "") then
                    skipStep = true
                end
            end
            if not skipStep then
                yOffset = CreateStepBlock(detailScrollChild, step, stepIdx, guideID, guide, currentStep, yOffset, parent, RefreshDetail)
            end
        end

        local addStepBtn = ns.UI.CreateButton(nil, detailScrollChild, L["GUIDES_ADD_STEP"], 140, 28)
        ns.UI.AutoResizeButton(addStepBtn, 100, 200)
        addStepBtn:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 10, yOffset - 8)
        addStepBtn:SetScript("OnClick", function()
            ns.UI.ShowStepEditorDialog(guideID, nil, function()
                ShowGuideDetail(guideID)
                parent.RefreshGuidesList()
            end)
        end)

        yOffset = yOffset - 44

        detailScrollChild:SetHeight(math.abs(yOffset) + 20)
    end

    parent.ShowGuideDetail = ShowGuideDetail

    function CreateStepBlock(scrollChild, step, stepIdx, guideID, guide, currentStep, yOffset, parentTab, refreshFunc)
        local isCurrentStep = (stepIdx == currentStep)
        local isStepDone = ns.GuidesData:IsStepComplete(guideID, stepIdx)

        local stepFrame = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
        stepFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, yOffset)
        stepFrame:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, yOffset)
        stepFrame:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })

        if isCurrentStep then
            stepFrame:SetBackdropColor(T("BG_ACTIVE"))
            stepFrame:SetBackdropBorderColor(T("BORDER_ACCENT"))
        elseif isStepDone then
            stepFrame:SetBackdropColor(T("BG_SECONDARY"))
            stepFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        else
            stepFrame:SetBackdropColor(T("BG_PRIMARY"))
            stepFrame:SetBackdropBorderColor(T("BORDER_SUBTLE"))
        end

        local stepHeader = CreateFrame("Frame", nil, stepFrame)
        stepHeader:SetPoint("TOPLEFT", stepFrame, "TOPLEFT", 0, 0)
        stepHeader:SetPoint("TOPRIGHT", stepFrame, "TOPRIGHT", 0, 0)
        stepHeader:SetHeight(28)

        local stepIcon = stepHeader:CreateTexture(nil, "ARTWORK")
        stepIcon:SetSize(16, 16)
        stepIcon:SetPoint("LEFT", stepHeader, "LEFT", 8, 0)
        if isStepDone then
            stepIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        elseif isCurrentStep then
            stepIcon:SetTexture("Interface\\MINIMAP\\TRACKING\\None")
        else
            stepIcon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Waiting")
        end

        local stepNum = stepHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stepNum:SetPoint("LEFT", stepIcon, "RIGHT", 6, 0)
        stepNum:SetText(string.format(L["GUIDES_STEP_FORMAT"], stepIdx))
        if isStepDone then
            stepNum:SetTextColor(0.4, 0.8, 0.4, 1.0)
        elseif isCurrentStep then
            stepNum:SetTextColor(T("TEXT_ACCENT"))
        else
            stepNum:SetTextColor(T("TEXT_SECONDARY"))
        end

        local stepTitle = stepHeader:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        stepTitle:SetPoint("LEFT", stepNum, "RIGHT", 6, 0)
        stepTitle:SetPoint("RIGHT", stepHeader, "RIGHT", -110, 0)
        stepTitle:SetJustifyH("LEFT")
        stepTitle:SetText(step.title or "")
        if isStepDone then
            stepTitle:SetTextColor(0.4, 0.8, 0.4, 1.0)
        elseif isCurrentStep then
            stepTitle:SetTextColor(T("TEXT_ACCENT"))
        else
            stepTitle:SetTextColor(T("TEXT_PRIMARY"))
        end

        if step.optional then
            local optTag = stepHeader:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            optTag:SetPoint("RIGHT", stepHeader, "RIGHT", -100, 0)
            optTag:SetText(L["GUIDES_OPTIONAL"])
            optTag:SetTextColor(T("TEXT_MUTED"))
        end

        local btnX = -4
        local delStepBtn = CreateSmallIconButton(stepHeader, "Interface\\Buttons\\UI-StopButton", 16, L["GUIDES_DELETE_STEP"])
        delStepBtn:SetPoint("RIGHT", stepHeader, "RIGHT", btnX, 0)
        delStepBtn:SetScript("OnClick", function()
            ns.GuidesData:RemoveStep(guideID, stepIdx)
            refreshFunc()
            parentTab.RefreshGuidesList()
        end)

        btnX = btnX - 20
        local editStepBtn = CreateSmallIconButton(stepHeader, "Interface\\Buttons\\UI-GuildButton-PublicNote-Up", 16, L["GUIDES_EDIT_STEP"])
        editStepBtn:SetPoint("RIGHT", stepHeader, "RIGHT", btnX, 0)
        editStepBtn:SetScript("OnClick", function()
            ns.UI.ShowStepEditorDialog(guideID, stepIdx, function()
                refreshFunc()
                parentTab.RefreshGuidesList()
            end)
        end)

        btnX = btnX - 20
        if stepIdx > 1 then
            local moveUpBtn = CreateSmallIconButton(stepHeader, "Interface\\Buttons\\UI-MicroStream-Green", 16, L["GUIDES_MOVE_UP"])
            moveUpBtn:SetPoint("RIGHT", stepHeader, "RIGHT", btnX, 0)
            moveUpBtn:GetNormalTexture():SetRotation(math.rad(180))
            moveUpBtn:SetScript("OnClick", function()
                guide.steps[stepIdx], guide.steps[stepIdx - 1] = guide.steps[stepIdx - 1], guide.steps[stepIdx]
                guide.modified = GetServerTime()
                refreshFunc()
            end)
            btnX = btnX - 20
        end

        if stepIdx < #guide.steps then
            local moveDownBtn = CreateSmallIconButton(stepHeader, "Interface\\Buttons\\UI-MicroStream-Green", 16, L["GUIDES_MOVE_DOWN"])
            moveDownBtn:SetPoint("RIGHT", stepHeader, "RIGHT", btnX, 0)
            moveDownBtn:SetScript("OnClick", function()
                guide.steps[stepIdx], guide.steps[stepIdx + 1] = guide.steps[stepIdx + 1], guide.steps[stepIdx]
                guide.modified = GetServerTime()
                refreshFunc()
            end)
            btnX = btnX - 20
        end

        if not isCurrentStep and ns.GuidesTracker:GetActiveGuideID() == guideID then
            local goBtn = CreateSmallIconButton(stepHeader, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", 16, L["GUIDES_GO_TO_STEP"])
            goBtn:SetPoint("RIGHT", stepHeader, "RIGHT", btnX, 0)
            goBtn:SetScript("OnClick", function()
                ns.GuidesTracker:GoToStep(stepIdx)
                refreshFunc()
            end)
        end

        local innerHeight = 28
        local objsYOffset = -28

        if step.description and step.description ~= "" then
            local descText = stepFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            descText:SetPoint("TOPLEFT", stepFrame, "TOPLEFT", 30, objsYOffset - 4)
            descText:SetPoint("TOPRIGHT", stepFrame, "TOPRIGHT", -10, objsYOffset - 4)
            descText:SetJustifyH("LEFT")
            descText:SetWordWrap(true)
            local stepFrameW = scrollChild:GetWidth()
            if stepFrameW and stepFrameW > 50 then
                descText:SetWidth(stepFrameW - 40)
            end
            descText:SetText(step.description)
            descText:SetTextColor(T("TEXT_SECONDARY"))
            local dH = math.max(14, descText:GetStringHeight()) + 12
            objsYOffset = objsYOffset - dH
            innerHeight = innerHeight + dH
        end

        for objIdx, obj in ipairs(step.objectives or {}) do
            local _, rowH = CreateObjectiveRow(stepFrame, obj, guideID, stepIdx, objIdx, objsYOffset)
            rowH = rowH or 24
            objsYOffset = objsYOffset - rowH - 2
            innerHeight = innerHeight + rowH + 2
        end

        local addObjBtn = ns.UI.CreateButton(nil, stepFrame, L["GUIDES_ADD_OBJECTIVE"], 130, 20)
        ns.UI.AutoResizeButton(addObjBtn, 100, 160)
        addObjBtn:SetPoint("TOPLEFT", stepFrame, "TOPLEFT", 30, objsYOffset - 4)
        addObjBtn:SetScript("OnClick", function()
            ns.UI.ShowObjectiveEditorDialog(guideID, stepIdx, nil, function()
                refreshFunc()
                parentTab.RefreshGuidesList()
            end)
        end)
        objsYOffset = objsYOffset - 28
        innerHeight = innerHeight + 28

        innerHeight = innerHeight + 6
        stepFrame:SetHeight(innerHeight)

        return yOffset - innerHeight - 4
    end

    ns.GuidesTracker.onObjectiveUpdate = function(guideID)
        if guideID and selectedGuide == guideID then
            ShowGuideDetail(guideID)
        end
        parent.RefreshGuidesList()
    end

    local function RefreshGuidesList()
        for _, item in ipairs(guideListItems) do
            item:Hide()
            item:ClearAllPoints()
        end
        wipe(guideListItems)

        local guides = ns.GuidesData:GetAllGuides()
        local sorted = {}
        for id, guide in pairs(guides) do
            if type(guide) == "table" then
                local passCategory = (categoryFilter == "All") or (guide.category == categoryFilter)
                local passSearch = true
                if searchText ~= "" then
                    local lower = string.lower(searchText)
                    passSearch = string.lower(guide.title or ""):find(lower, 1, true)
                        or string.lower(guide.author or ""):find(lower, 1, true)
                end
                if passCategory and passSearch then
                    table.insert(sorted, { id = id, guide = guide })
                end
            end
        end

        table.sort(sorted, function(a, b)
            local aFav = a.guide.favorite and 1 or 0
            local bFav = b.guide.favorite and 1 or 0
            if aFav ~= bFav then return aFav > bFav end
            return (a.guide.title or "") < (b.guide.title or "")
        end)

        local yOff = 0
        local activeID = ns.GuidesTracker:GetActiveGuideID()

        for _, entry in ipairs(sorted) do
            local guideID = entry.id
            local guide = entry.guide
            local done, total = ns.GuidesData:GetCompletedStepCount(guideID)
            local isActive = (activeID == guideID)

            local row = CreateFrame("Button", nil, listScrollChild, "BackdropTemplate")
            row:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 0, -yOff)
            row:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", 0, -yOff)
            row:SetHeight(50)
            row:SetBackdrop({
                bgFile   = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })

            if guideID == selectedGuide then
                row:SetBackdropColor(T("BG_ACTIVE"))
                row:SetBackdropBorderColor(T("BORDER_ACCENT"))
            else
                row:SetBackdropColor(T("BG_PRIMARY"))
                row:SetBackdropBorderColor(T("BORDER_SUBTLE"))
            end

            if isActive then
                local activeDot = row:CreateTexture(nil, "OVERLAY")
                activeDot:SetSize(8, 8)
                activeDot:SetPoint("TOPLEFT", row, "TOPLEFT", 4, -4)
                activeDot:SetTexture("Interface\\Buttons\\WHITE8x8")
                activeDot:SetVertexColor(T("ACCENT_HIGHLIGHT"))
            end

            local titleFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            titleFS:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -6)
            titleFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -40, -6)
            titleFS:SetJustifyH("LEFT")
            titleFS:SetText(guide.title or L["GUIDES_UNTITLED"])
            titleFS:SetTextColor(T("TEXT_PRIMARY"))

            local metaFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            metaFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -2)
            metaFS:SetText((guide.category or "") .. " | " .. (guide.author or ""))
            metaFS:SetTextColor(T("TEXT_MUTED"))

            local progFS = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            progFS:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -6)
            progFS:SetText(done .. "/" .. total)
            if done == total and total > 0 then
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
            local barPct = total > 0 and (done / total) or 0
            C_Timer.After(0.05, function()
                if progBarBg:GetWidth() > 0 then
                    progBarFill:SetWidth(math.max(1, progBarBg:GetWidth() * barPct))
                end
            end)

            row:SetScript("OnClick", function()
                ShowGuideDetail(guideID)
                parent.RefreshGuidesList()
            end)
            row:SetScript("OnEnter", function(self)
                if guideID ~= selectedGuide then
                    self:SetBackdropColor(T("BG_HOVER"))
                end
            end)
            row:SetScript("OnLeave", function(self)
                if guideID ~= selectedGuide then
                    self:SetBackdropColor(T("BG_PRIMARY"))
                end
            end)

            table.insert(guideListItems, row)
            yOff = yOff + 52
        end

        if #sorted == 0 then
            local emptyFrame = CreateFrame("Frame", nil, listScrollChild)
            emptyFrame:SetPoint("TOPLEFT", listScrollChild, "TOPLEFT", 0, 0)
            emptyFrame:SetPoint("TOPRIGHT", listScrollChild, "TOPRIGHT", 0, 0)
            emptyFrame:SetHeight(40)
            local emptyFS = emptyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            emptyFS:SetPoint("CENTER", listScroll.panel, "CENTER", 0, 0)
            emptyFS:SetText(L["GUIDES_EMPTY"])
            emptyFS:SetTextColor(T("TEXT_MUTED"))
            table.insert(guideListItems, emptyFrame)
        end

        listScrollChild:SetHeight(math.max(1, yOff))
    end

    parent.RefreshGuidesList = RefreshGuidesList

    newBtn:SetScript("OnClick", function()
        ns.UI.ShowGuideEditorDialog(nil, function(newGuideID)
            parent.RefreshGuidesList()
            if newGuideID then
                ShowGuideDetail(newGuideID)
            end
        end)
    end)

    importBtn:SetScript("OnClick", function()
        ns.UI.ShowGuideImportDialog(function(guideID)
            parent.RefreshGuidesList()
            if guideID then
                ShowGuideDetail(guideID)
            end
        end)
    end)

    StaticPopupDialogs["ONEWOW_NOTES_RESET_GUIDE"] = {
        text = L["GUIDES_RESET_CONFIRM"],
        button1 = L["GUIDES_RESET"],
        button2 = L["BUTTON_CANCEL"],
        OnAccept = function(self, data)
            ns.GuidesData:ResetProgress(data.guideID)
            if ns.GuidesTracker:GetActiveGuideID() == data.guideID then
                ns.GuidesTracker:Deactivate()
                ns.GuidesTracker:Activate(data.guideID)
            end
            if data.refreshFunc then data.refreshFunc() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    StaticPopupDialogs["ONEWOW_NOTES_DELETE_GUIDE"] = {
        text = L["GUIDES_DELETE_CONFIRM"],
        button1 = L["BUTTON_DELETE"],
        button2 = L["BUTTON_CANCEL"],
        OnAccept = function(self, data)
            if ns.GuidesTracker:GetActiveGuideID() == data.guideID then
                ns.GuidesTracker:Deactivate()
            end
            ns.GuidesData:RemoveGuide(data.guideID)
            selectedGuide = nil
            ClearDetailContent()
            emptyMessage:Show()
            detailTitle:SetText(L["GUIDES_DETAIL_TITLE"])
            if data.refreshFunc then data.refreshFunc() end
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    C_Timer.After(0.2, function() RefreshGuidesList() end)
end
