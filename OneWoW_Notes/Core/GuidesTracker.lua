local addonName, ns = ...
local L = ns.L
local T = ns.T
local S = ns.S

ns.GuidesTracker = {}
local Tracker = ns.GuidesTracker

local activeGuideID = nil
local registeredEvents = {}
local trackerFrame = nil
local floatingTracker = nil
local lib = LibStub("OneWoW_GUI-1.0", true)

local OBJECTIVE_EVENTS = {
    level          = { "PLAYER_LEVEL_UP" },
    quest_complete = { "QUEST_TURNED_IN", "QUEST_LOG_UPDATE" },
    quest_active   = { "QUEST_ACCEPTED", "QUEST_LOG_UPDATE" },
    item_count     = { "BAG_UPDATE" },
    location       = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED" },
    achievement    = { "ACHIEVEMENT_EARNED" },
    reputation     = { "UPDATE_FACTION" },
    spell_known    = { "SPELLS_CHANGED" },
    ilvl           = { "PLAYER_EQUIPMENT_CHANGED" },
    currency       = { "CURRENCY_DISPLAY_UPDATE" },
}

local function CheckObjective(obj, params)
    if obj.type == "level" then
        local level = UnitLevel("player")
        return level >= (params.level or 0)

    elseif obj.type == "quest_complete" then
        local questID = params.questID
        if questID and questID > 0 then
            return C_QuestLog.IsQuestFlaggedCompleted(questID)
        end
        return false

    elseif obj.type == "quest_active" then
        local questID = params.questID
        if questID and questID > 0 then
            local idx = C_QuestLog.GetLogIndexForQuestID(questID)
            return idx and idx > 0
        end
        return false

    elseif obj.type == "item_count" then
        local itemID = params.itemID
        local needed = params.count or 1
        if itemID and itemID > 0 then
            local count = C_Item.GetItemCount(itemID, true)
            return count >= needed
        end
        return false

    elseif obj.type == "location" then
        local mapID = params.mapID
        if mapID and mapID > 0 then
            local currentMap = C_Map.GetBestMapForUnit("player")
            return currentMap == mapID
        end
        return false

    elseif obj.type == "achievement" then
        local achID = params.achievementID
        if achID and achID > 0 then
            local _, _, _, completed = GetAchievementInfo(achID)
            return completed
        end
        return false

    elseif obj.type == "reputation" then
        local factionID = params.factionID
        local needed = params.standing or 0
        if factionID and factionID > 0 then
            local factionData = C_Reputation.GetFactionDataByID(factionID)
            if factionData then
                return factionData.reaction >= needed
            end
        end
        return false

    elseif obj.type == "spell_known" then
        local spellID = params.spellID
        if spellID and spellID > 0 then
            return C_SpellBook.IsSpellKnown(spellID)
        end
        return false

    elseif obj.type == "ilvl" then
        local needed = params.ilvl or 0
        local _, equipped = GetAverageItemLevel()
        return equipped >= needed

    elseif obj.type == "currency" then
        local currencyID = params.currencyID
        local needed = params.amount or 0
        if currencyID and currencyID > 0 then
            local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
            if info then
                return info.quantity >= needed
            end
        end
        return false

    elseif obj.type == "manual" then
        return false
    end

    return false
end

local function GetRequiredEventsForStep(step)
    local events = {}
    if not step or not step.objectives then return events end

    for _, obj in ipairs(step.objectives) do
        local evtList = OBJECTIVE_EVENTS[obj.type]
        if evtList then
            for _, evt in ipairs(evtList) do
                events[evt] = true
            end
        end
    end
    return events
end

local function EnsureTrackerFrame()
    if not trackerFrame then
        trackerFrame = CreateFrame("Frame", "OneWoW_Notes_GuidesTrackerFrame", UIParent)
        trackerFrame:Hide()
    end
    return trackerFrame
end

local function UnregisterAllEvents()
    local frame = EnsureTrackerFrame()
    for evt in pairs(registeredEvents) do
        frame:UnregisterEvent(evt)
    end
    registeredEvents = {}
    frame:SetScript("OnEvent", nil)
end

local function OnTrackerEvent()
    Tracker:EvaluateCurrentStep()
end

local function RegisterEventsForStep(step)
    UnregisterAllEvents()
    local frame = EnsureTrackerFrame()
    local events = GetRequiredEventsForStep(step)

    for evt in pairs(events) do
        frame:RegisterEvent(evt)
        registeredEvents[evt] = true
    end

    if next(registeredEvents) then
        frame:SetScript("OnEvent", OnTrackerEvent)
    end
end

function Tracker:GetActiveGuideID()
    return activeGuideID
end

function Tracker:Activate(guideID)
    if activeGuideID == guideID then return end

    if activeGuideID then
        self:Deactivate()
    end

    local guide = ns.GuidesData:GetGuide(guideID)
    if not guide then return end

    activeGuideID = guideID

    self:FullEvaluate()
    self:ShowFloatingTracker(guideID)
end

function Tracker:Deactivate()
    UnregisterAllEvents()
    activeGuideID = nil
    self:HideFloatingTracker()
end

function Tracker:FullEvaluate()
    if not activeGuideID then return end

    local guide = ns.GuidesData:GetGuide(activeGuideID)
    if not guide or not guide.steps then return end

    local progress = ns.GuidesData:GetProgress(activeGuideID)
    local playerFaction = UnitFactionGroup("player")

    for stepIdx, step in ipairs(guide.steps) do
        local skipFaction = false
        if step.faction and step.faction ~= "both" then
            if step.faction ~= string.lower(playerFaction or "") then
                skipFaction = true
            end
        end

        if not skipFaction then
            for objIdx, obj in ipairs(step.objectives or {}) do
                if obj.type ~= "manual" then
                    local wasComplete = ns.GuidesData:IsObjectiveComplete(activeGuideID, stepIdx, objIdx)
                    local isComplete = CheckObjective(obj, obj.params or {})
                    if isComplete and not wasComplete then
                        ns.GuidesData:SetObjectiveComplete(activeGuideID, stepIdx, objIdx, true)
                    elseif not isComplete and wasComplete and obj.type == "location" then
                        ns.GuidesData:SetObjectiveComplete(activeGuideID, stepIdx, objIdx, false)
                    end
                end
            end
        end
    end

    local firstIncomplete = nil
    for stepIdx, step in ipairs(guide.steps) do
        local skipFaction = false
        if step.faction and step.faction ~= "both" then
            if step.faction ~= string.lower(playerFaction or "") then
                skipFaction = true
            end
        end

        if not skipFaction then
            if not ns.GuidesData:IsStepComplete(activeGuideID, stepIdx) then
                firstIncomplete = stepIdx
                break
            end
        end
    end

    if firstIncomplete then
        progress.currentStep = firstIncomplete
        progress.completed = false
        RegisterEventsForStep(guide.steps[firstIncomplete])
    else
        progress.currentStep = #guide.steps
        progress.completed = true
        UnregisterAllEvents()
    end

    self:RefreshFloatingTracker()

    if ns.GuidesTracker.onObjectiveUpdate then
        ns.GuidesTracker.onObjectiveUpdate(activeGuideID)
    end
end

function Tracker:EvaluateCurrentStep()
    if not activeGuideID then return end

    local guide = ns.GuidesData:GetGuide(activeGuideID)
    if not guide then return end

    local progress = ns.GuidesData:GetProgress(activeGuideID)
    local stepIndex = progress.currentStep or 1
    local step = guide.steps[stepIndex]
    if not step then return end

    local anyChanged = false
    for i, obj in ipairs(step.objectives or {}) do
        if obj.type ~= "manual" then
            local wasComplete = ns.GuidesData:IsObjectiveComplete(activeGuideID, stepIndex, i)
            local isComplete = CheckObjective(obj, obj.params or {})
            if isComplete and not wasComplete then
                ns.GuidesData:SetObjectiveComplete(activeGuideID, stepIndex, i, true)
                anyChanged = true
            elseif not isComplete and wasComplete and obj.type == "location" then
                ns.GuidesData:SetObjectiveComplete(activeGuideID, stepIndex, i, false)
                anyChanged = true
            end
        end
    end

    if anyChanged then
        if ns.GuidesData:IsStepComplete(activeGuideID, stepIndex) then
            if stepIndex < #guide.steps then
                self:AdvanceStep()
            else
                progress.completed = true
            end
        end

        self:RefreshFloatingTracker()

        if ns.GuidesTracker.onObjectiveUpdate then
            ns.GuidesTracker.onObjectiveUpdate(activeGuideID)
        end
    end
end

function Tracker:AdvanceStep()
    if not activeGuideID then return end

    local guide = ns.GuidesData:GetGuide(activeGuideID)
    if not guide then return end

    self:FullEvaluate()
end

function Tracker:GoToStep(stepIndex)
    if not activeGuideID then return end

    local guide = ns.GuidesData:GetGuide(activeGuideID)
    if not guide or not guide.steps[stepIndex] then return end

    local progress = ns.GuidesData:GetProgress(activeGuideID)
    progress.currentStep = stepIndex
    progress.completed = false
    RegisterEventsForStep(guide.steps[stepIndex])
    self:EvaluateCurrentStep()

    self:RefreshFloatingTracker()

    if ns.GuidesTracker.onObjectiveUpdate then
        ns.GuidesTracker.onObjectiveUpdate(activeGuideID)
    end
end

function Tracker:ManualComplete(stepIndex, objIndex, completed)
    if not activeGuideID then return end

    ns.GuidesData:SetObjectiveComplete(activeGuideID, stepIndex, objIndex, completed)

    local guide = ns.GuidesData:GetGuide(activeGuideID)
    if guide and ns.GuidesData:IsStepComplete(activeGuideID, stepIndex) then
        local progress = ns.GuidesData:GetProgress(activeGuideID)
        if stepIndex == progress.currentStep then
            if stepIndex < #guide.steps then
                self:AdvanceStep()
                return
            else
                progress.completed = true
            end
        end
    end

    self:RefreshFloatingTracker()

    if ns.GuidesTracker.onObjectiveUpdate then
        ns.GuidesTracker.onObjectiveUpdate(activeGuideID)
    end
end

local function CreateFloatingTracker()
    local addon = _G.OneWoW_Notes

    local frame = lib:CreateFrame("OneWoW_Notes_FloatingTracker", UIParent, 260, 180)
    frame:SetFrameStrata("MEDIUM")
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    local savedPos = addon.db.global.guideTrackerPosition
    if savedPos and savedPos.point then
        frame:ClearAllPoints()
        frame:SetPoint(savedPos.point, UIParent, savedPos.relativePoint or "TOPRIGHT", savedPos.xOfs or -20, savedPos.yOfs or -260)
    else
        frame:ClearAllPoints()
        frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -260)
    end

    local function SavePosition()
        local point, _, relativePoint, xOfs, yOfs = frame:GetPoint()
        addon.db.global.guideTrackerPosition = { point = point, relativePoint = relativePoint, xOfs = xOfs, yOfs = yOfs }
    end

    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)

    local titleBar = lib:CreateTitleBar(frame, "", {
        height = 22,
        onClose = function()
            Tracker:Deactivate()
            if ns.GuidesTracker.onObjectiveUpdate then
                ns.GuidesTracker.onObjectiveUpdate(nil)
            end
        end,
    })
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SavePosition()
    end)
    frame.titleText = titleBar._titleText

    local skipBtn = CreateFrame("Button", nil, titleBar)
    skipBtn:SetSize(16, 16)
    skipBtn:SetPoint("RIGHT", titleBar._closeBtn, "LEFT", -4, 0)
    skipBtn:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    skipBtn:SetHighlightTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    skipBtn:GetHighlightTexture():SetAlpha(0.5)
    skipBtn:SetScript("OnClick", function()
        if not activeGuideID then return end
        local guide = ns.GuidesData:GetGuide(activeGuideID)
        if not guide then return end
        local progress = ns.GuidesData:GetProgress(activeGuideID)
        local cur = progress.currentStep or 1
        if cur < #guide.steps then
            Tracker:GoToStep(cur + 1)
        end
    end)
    skipBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L["GUIDES_SKIP_STEP"], 1, 1, 1)
        GameTooltip:Show()
    end)
    skipBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    frame.skipBtn = skipBtn

    local stepLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    stepLabel:SetJustifyH("LEFT")
    stepLabel:SetTextColor(T("TEXT_ACCENT"))
    stepLabel:SetWidth(230)
    frame.stepLabel = stepLabel

    local stepTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stepTitle:SetJustifyH("LEFT")
    stepTitle:SetTextColor(T("TEXT_PRIMARY"))
    stepTitle:SetWordWrap(true)
    stepTitle:SetWidth(230)
    frame.stepTitle = stepTitle

    local objectivesContainer = CreateFrame("Frame", nil, frame)
    objectivesContainer:SetWidth(240)
    frame.objectivesContainer = objectivesContainer

    frame.objectiveRows = {}
    frame.isExtended = false

    local extendBtn = lib:CreateFitTextButton(frame, L["GUIDES_EXTEND"], { height = 18, minWidth = 60, paddingX = 16 })
    extendBtn:Hide()
    frame.extendBtn = extendBtn

    local extendContainer = CreateFrame("Frame", nil, frame)
    extendContainer:SetWidth(240)
    extendContainer:Hide()
    frame.extendContainer = extendContainer
    frame.extendRows = {}

    extendBtn:SetScript("OnClick", function()
        frame.isExtended = not frame.isExtended
        Tracker:RefreshFloatingTracker()
    end)
    extendBtn:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if frame.isExtended then
            GameTooltip:SetText(L["GUIDES_COLLAPSE"], 1, 1, 1)
            GameTooltip:AddLine(L["GUIDES_COLLAPSE_DESC"], 0.8, 0.8, 0.8, true)
        else
            GameTooltip:SetText(L["GUIDES_EXTEND"], 1, 1, 1)
            GameTooltip:AddLine(L["GUIDES_EXTEND_DESC"], 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    extendBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)

    frame:Hide()
    return frame
end

function Tracker:ShowFloatingTracker(guideID)
    if not floatingTracker then
        floatingTracker = CreateFloatingTracker()
    end
    floatingTracker:Show()
    self:RefreshFloatingTracker()
end

function Tracker:HideFloatingTracker()
    if floatingTracker then
        floatingTracker:Hide()
    end
end

function Tracker:RefreshFloatingTracker()
    if not floatingTracker or not floatingTracker:IsShown() then return end
    if not activeGuideID then
        floatingTracker:Hide()
        return
    end

    local guide = ns.GuidesData:GetGuide(activeGuideID)
    if not guide then
        floatingTracker:Hide()
        return
    end

    local progress = ns.GuidesData:GetProgress(activeGuideID)
    local stepIndex = progress.currentStep or 1
    local step = guide.steps[stepIndex]

    floatingTracker.titleText:SetText(guide.title or L["GUIDES_UNTITLED"])

    for _, row in ipairs(floatingTracker.objectiveRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(floatingTracker.objectiveRows)

    for _, row in ipairs(floatingTracker.extendRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(floatingTracker.extendRows)
    floatingTracker.extendContainer:Hide()

    local trackerW = floatingTracker:GetWidth()
    local contentW = math.max(100, trackerW - 20)
    local curY = -26

    if progress.completed or not step then
        floatingTracker.stepLabel:ClearAllPoints()
        floatingTracker.stepLabel:SetPoint("TOPLEFT", floatingTracker, "TOPLEFT", 8, curY)
        floatingTracker.stepLabel:SetText(L["GUIDES_COMPLETE"])
        floatingTracker.stepLabel:SetTextColor(0.4, 0.8, 0.4, 1.0)
        floatingTracker.stepTitle:SetText("")
        floatingTracker.stepTitle:ClearAllPoints()
        floatingTracker.objectivesContainer:ClearAllPoints()
        floatingTracker.extendBtn:Hide()
        floatingTracker:SetHeight(60)
        return
    end

    floatingTracker.stepLabel:ClearAllPoints()
    floatingTracker.stepLabel:SetPoint("TOPLEFT", floatingTracker, "TOPLEFT", 8, curY)
    floatingTracker.stepLabel:SetWidth(contentW)
    floatingTracker.stepLabel:SetText(string.format(L["GUIDES_STEP_OF"], stepIndex, #guide.steps))
    floatingTracker.stepLabel:SetTextColor(T("TEXT_ACCENT"))
    local stepLabelH = math.max(12, floatingTracker.stepLabel:GetStringHeight())
    curY = curY - stepLabelH - 4

    floatingTracker.stepTitle:ClearAllPoints()
    floatingTracker.stepTitle:SetPoint("TOPLEFT", floatingTracker, "TOPLEFT", 8, curY)
    floatingTracker.stepTitle:SetWidth(contentW)
    floatingTracker.stepTitle:SetText(step.title or "")
    local stepTitleH = math.max(14, floatingTracker.stepTitle:GetStringHeight())
    curY = curY - stepTitleH - 6

    floatingTracker.objectivesContainer:ClearAllPoints()
    floatingTracker.objectivesContainer:SetPoint("TOPLEFT", floatingTracker, "TOPLEFT", 8, curY)
    floatingTracker.objectivesContainer:SetWidth(contentW)

    local objY = 0
    local capturedStepIndex = stepIndex
    for objIdx, obj in ipairs(step.objectives or {}) do
        local isComplete = ns.GuidesData:IsObjectiveComplete(activeGuideID, stepIndex, objIdx)

        local row = CreateFrame("Frame", nil, floatingTracker.objectivesContainer)
        row:SetPoint("TOPLEFT", floatingTracker.objectivesContainer, "TOPLEFT", 0, objY)
        row:SetWidth(contentW)

        local checkBtn = CreateFrame("Button", nil, row)
        checkBtn:SetSize(14, 14)
        checkBtn:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -1)
        if isComplete then
            checkBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
        else
            checkBtn:SetNormalTexture("Interface\\RAIDFRAME\\ReadyCheck-NotReady")
        end

        local capturedObjIdx = objIdx
        local capturedComplete = isComplete
        checkBtn:SetScript("OnClick", function()
            Tracker:ManualComplete(capturedStepIndex, capturedObjIdx, not capturedComplete)
        end)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("TOPLEFT", checkBtn, "TOPRIGHT", 4, 0)
        text:SetJustifyH("LEFT")
        text:SetWordWrap(true)
        text:SetWidth(contentW - 22)
        text:SetText(obj.description or "")
        if isComplete then
            text:SetTextColor(0.4, 0.8, 0.4, 1.0)
        else
            text:SetTextColor(T("TEXT_PRIMARY"))
        end

        local textH = math.max(14, text:GetStringHeight())
        local rowH = textH + 4
        row:SetHeight(rowH)

        table.insert(floatingTracker.objectiveRows, row)
        objY = objY - rowH
    end

    curY = curY + objY

    if stepIndex < #guide.steps then
        curY = curY - 4
        floatingTracker.extendBtn:ClearAllPoints()
        floatingTracker.extendBtn:SetPoint("TOPLEFT", floatingTracker, "TOPLEFT", 8, curY)
        floatingTracker.extendBtn:Show()

        if floatingTracker.isExtended then
            floatingTracker.extendBtn:SetFitText(L["GUIDES_COLLAPSE"])
        else
            floatingTracker.extendBtn:SetFitText(L["GUIDES_EXTEND"])
        end

        curY = curY - 22

        if floatingTracker.isExtended then
            floatingTracker.extendContainer:ClearAllPoints()
            floatingTracker.extendContainer:SetPoint("TOPLEFT", floatingTracker, "TOPLEFT", 8, curY)
            floatingTracker.extendContainer:SetWidth(contentW)
            floatingTracker.extendContainer:Show()

            local extY = 0
            local playerFaction = UnitFactionGroup("player")
            local shown = 0

            for nextIdx = stepIndex + 1, #guide.steps do
                if shown >= 3 then break end
                local nextStep = guide.steps[nextIdx]

                local skipFaction = false
                if nextStep.faction and nextStep.faction ~= "both" then
                    if nextStep.faction ~= string.lower(playerFaction or "") then
                        skipFaction = true
                    end
                end

                if not skipFaction then
                    shown = shown + 1
                    local isStepDone = ns.GuidesData:IsStepComplete(activeGuideID, nextIdx)

                    local stepRow = CreateFrame("Button", nil, floatingTracker.extendContainer)
                    stepRow:SetPoint("TOPLEFT", floatingTracker.extendContainer, "TOPLEFT", 0, extY)
                    stepRow:SetWidth(contentW)

                    local icon = stepRow:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(12, 12)
                    icon:SetPoint("TOPLEFT", stepRow, "TOPLEFT", 0, -2)
                    if isStepDone then
                        icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Ready")
                    else
                        icon:SetTexture("Interface\\RAIDFRAME\\ReadyCheck-Waiting")
                    end

                    local stepText = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                    stepText:SetPoint("TOPLEFT", icon, "TOPRIGHT", 4, 0)
                    stepText:SetPoint("RIGHT", stepRow, "RIGHT", -4, 0)
                    stepText:SetJustifyH("LEFT")
                    stepText:SetWordWrap(true)
                    stepText:SetWidth(contentW - 20)
                    stepText:SetText(string.format("%d. %s", nextIdx, nextStep.title or ""))

                    if isStepDone then
                        stepText:SetTextColor(0.4, 0.8, 0.4, 1.0)
                    else
                        stepText:SetTextColor(T("TEXT_SECONDARY"))
                    end

                    local titleH = math.max(14, stepText:GetStringHeight())
                    local subtitleH = 0

                    if nextStep.objectives and #nextStep.objectives > 0 then
                        local firstObj = nextStep.objectives[1]
                        local subtitle = stepRow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                        subtitle:SetPoint("TOPLEFT", stepText, "BOTTOMLEFT", 0, -2)
                        subtitle:SetPoint("RIGHT", stepRow, "RIGHT", -4, 0)
                        subtitle:SetJustifyH("LEFT")
                        subtitle:SetWordWrap(false)
                        subtitle:SetWidth(contentW - 20)

                        local desc = firstObj.description or ""
                        if #desc > 50 then desc = desc:sub(1, 47) .. "..." end
                        local objCount = #nextStep.objectives
                        if objCount > 1 then
                            desc = desc .. string.format(" (+%d)", objCount - 1)
                        end
                        subtitle:SetText(desc)
                        subtitle:SetTextColor(T("TEXT_MUTED"))
                        subtitleH = subtitle:GetStringHeight() + 2
                    end

                    local rowH = titleH + subtitleH + 6
                    stepRow:SetHeight(rowH)

                    local capturedIdx = nextIdx
                    stepRow:SetHighlightTexture("Interface\\Buttons\\WHITE8x8")
                    stepRow:GetHighlightTexture():SetAlpha(0.1)
                    stepRow:SetScript("OnClick", function()
                        Tracker:GoToStep(capturedIdx)
                    end)
                    stepRow:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(string.format(L["GUIDES_STEP_FORMAT"], capturedIdx) .. " " .. (nextStep.title or ""), 1, 1, 1)
                        GameTooltip:AddLine(L["GUIDES_GO_TO_STEP"], 0.8, 0.8, 0.8, true)
                        GameTooltip:Show()
                    end)
                    stepRow:SetScript("OnLeave", function() GameTooltip:Hide() end)

                    table.insert(floatingTracker.extendRows, stepRow)
                    extY = extY - rowH - 2
                end
            end

            floatingTracker.extendContainer:SetHeight(math.max(1, math.abs(extY)))
            curY = curY + extY
        end
    else
        floatingTracker.extendBtn:Hide()
    end

    floatingTracker:SetHeight(math.max(60, math.abs(curY) + 10))
end
