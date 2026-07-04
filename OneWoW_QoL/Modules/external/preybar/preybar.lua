-- ============================================================================
-- Prey Hunt Bar
-- ============================================================================
-- Movable HUD bar for the Midnight "prey hunt" lure mechanic.
--
-- Data sources (all live Blizzard APIs, no new collectors):
--   - Progress state (Cold/Warm/Hot/Final) comes from the prey-hunt-progress
--     UI widget via C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo.
--     Widget IDs are discovered at runtime through GetPowerBarWidgetSetID +
--     GetAllWidgetsBySetID (filter PreyHuntProgress), with a widgetFrames
--     container fallback. Visibility filtering mirrors Blizzard's template
--     (.wow_docs/preyhunt/Blizzard_UIWidgetTemplatePreyHuntProgress.lua):
--     discard entries where shownState == Hidden. UPDATE_UI_WIDGET /
--     UPDATE_ALL_UI_WIDGETS drive refresh; IDs are never hardcoded.
--   - Active hunt boss/difficulty comes from C_QuestLog.GetActivePreyQuest +
--     GetTitleForQuestID. Difficulty is classified by quest-ID range, which is
--     locale-independent (parsing the title's difficulty word is not). Quest
--     titles include a localized "Tag: " prefix and trailing " (Difficulty)"
--     suffix from Blizzard; both are stripped for the boss line because difficulty
--     has its own display row and the bar context already implies prey.
--   - Affixes are a function of difficulty only (every Normal hunt shares the
--     same affix set, etc.), so no per-boss table is needed.
--
-- Frame construction, layout, and theming live in preybar-ui.lua. This file
-- owns the module table, data resolution, events, and lifecycle.
-- ============================================================================
local _, ns = ...
local PreyBarModule = ns.ModuleRegistry:Current()
if not PreyBarModule then return end

local OneWoW_GUI = OneWoW_GUI

-- Live affix-advice signals (factual game data):
--   1245767 = the "kill something" forced-target aura applied by Bloody Command.
--   Ambush is announced via a RAID_BOSS_WHISPER whose text contains "ambush".
local KILL_SOMETHING_SPELL_ID = 1245767
local AMBUSH_WHISPER_MATCH     = "ambush"
local AMBUSH_HOLD_SECONDS      = 5
local POLL_INTERVAL            = 2
local PEW_DELAY_SECONDS        = 0.5
local PREY_WIDGET_TYPE         = Enum.UIWidgetVisualizationType.PreyHuntProgress

-- ---- Toggle / storage helpers ----
local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("preybar", id)
end
PreyBarModule.GetToggle = GetToggle

local function GetModuleStorage()
    return ns.ModuleRegistry:GetModuleBucket("preybar")
end

local function GetPositionStorage()
    local mod = GetModuleStorage()
    if not mod then return nil end
    if not mod.position then mod.position = {} end
    return mod.position
end
PreyBarModule.GetPositionStorage = GetPositionStorage

function PreyBarModule:GetOpacity()
    local mod = GetModuleStorage()
    return mod.opacity or 1.0
end

function PreyBarModule:SetOpacity(opacity)
    local mod = GetModuleStorage()
    mod.opacity = opacity
    self:ApplyOpacity()
end

function PreyBarModule:ApplyOpacity()
    if not self._frame then return end
    self._frame:SetAlpha(self:GetOpacity())
end

-- ---- Difficulty classification ----
-- Prey hunt weekly quest IDs split cleanly into difficulty bands. The 91210-91242
-- band interleaves Hard (even) and Nightmare (odd); the rest are contiguous.
---@param questID number|nil
---@return string|nil difficultyKey "NORMAL" | "HARD" | "NIGHTMARE"
function PreyBarModule:ClassifyDifficulty(questID)
    if not questID then return nil end
    if questID >= 91095 and questID <= 91124 then return "NORMAL" end
    if questID >= 91243 and questID <= 91255 then return "HARD" end
    if questID >= 91256 and questID <= 91269 then return "NIGHTMARE" end
    if questID >= 91210 and questID <= 91242 then
        if questID % 2 == 0 then return "HARD" end
        return "NIGHTMARE"
    end
    return nil
end

--- Normalize a prey quest title into the boss display name.
--- Strips Blizzard's localized "Tag: " prefix (tag metadata, then ^.-: fallback)
--- and trailing " (Difficulty)" suffix.
---@param questID number
---@param title string|nil
---@return string|nil
local function NormalizePreyQuestBossName(questID, title)
    if not title or title == "" then return title end

    local bossName = title:gsub(" %b()$", "")
    if bossName == "" then bossName = title end

    local tagInfo = C_QuestLog.GetQuestTagInfo(questID)
    if tagInfo and tagInfo.tagName ~= "" then
        local prefix = tagInfo.tagName .. ": "
        if bossName:sub(1, #prefix) == prefix then
            bossName = bossName:sub(#prefix + 1)
        end
    end

    -- Fallback when tag metadata is missing or tagName does not match the title
    -- (prey titles embed a localized "Tag: boss" prefix in the quest string).
    local tagStripped = bossName:gsub("^.-:%s*", "")
    if tagStripped ~= "" then
        bossName = tagStripped
    end

    if bossName == "" then return title end
    return bossName
end

--- Resolve the active prey hunt's difficulty and boss name from the quest log.
---@return string|nil difficultyKey
---@return string|nil bossName
function PreyBarModule:GetActiveHunt()
    local questID = C_QuestLog.GetActivePreyQuest()
    if not questID then return nil, nil end
    local difficultyKey = self:ClassifyDifficulty(questID)
    local bossName = NormalizePreyQuestBossName(questID, C_QuestLog.GetTitleForQuestID(questID))
    return difficultyKey, bossName
end

-- ---- Click-to-waypoint ----
--- True when a prey hunt is active and its progress has reached Final ("Ready").
--- Mirrors Blizzard's own template, which only enables the widget's click at Final.
---@return boolean
function PreyBarModule:IsHuntReady()
    local info = self:GetWidgetInfo()
    return info ~= nil
        and info.shownState == Enum.WidgetShownState.Shown
        and info.progressState == Enum.PreyHuntProgressState.Final
end

--- Super-track the active prey quest so its map waypoint / navigation arrow shows.
--- No-op when there is no active prey quest.
function PreyBarModule:SetPreyWaypoint()
    local questID = C_QuestLog.GetActivePreyQuest()
    if not questID then return end
    C_SuperTrack.SetSuperTrackedQuestID(questID)
end

-- ---- Widget resolution ----
-- Mirrors Blizzard_UIWidgetTemplatePreyHuntProgress GetPreyHuntProgressVisInfoData:
-- return visualization info only when shownState is not Hidden.
---@param widgetID number|nil
---@return table|nil widgetInfo
local function ProbePreyWidget(widgetID)
    if not widgetID then return nil end
    local widgetInfo = C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(widgetID)
    if widgetInfo and widgetInfo.shownState ~= Enum.WidgetShownState.Hidden then
        return widgetInfo
    end
end

--- Among Shown prey widgets, prefer the highest progressState.
---@param candidates table<number, table>
---@return number|nil widgetID
---@return table|nil widgetInfo
local function PickBestPreyWidget(candidates)
    local bestID, bestInfo
    for widgetID, info in pairs(candidates) do
        if not bestInfo or info.progressState > bestInfo.progressState then
            bestID = widgetID
            bestInfo = info
        end
    end
    return bestID, bestInfo
end

function PreyBarModule:InvalidateWidgetCache()
    self._widgetID = nil
end

--- Resolve the current Shown prey-hunt-progress widget; updates _widgetID for suppression.
--- Always scans fresh — _widgetID is not used as a lookup short-circuit.
---@return table|nil widgetInfo
function PreyBarModule:GetWidgetInfo()
    local candidates = {}

    local setID = C_UIWidgetManager.GetPowerBarWidgetSetID()
    local widgets = C_UIWidgetManager.GetAllWidgetsBySetID(setID)
    for _, entry in ipairs(widgets) do
        if entry.widgetType == PREY_WIDGET_TYPE then
            local info = ProbePreyWidget(entry.widgetID)
            if info then
                candidates[entry.widgetID] = info
            end
        end
    end

    if not next(candidates) then
        local container = UIWidgetPowerBarContainerFrame
        if container and container.widgetFrames then
            for widgetID in pairs(container.widgetFrames) do
                local info = ProbePreyWidget(widgetID)
                if info then
                    candidates[widgetID] = info
                end
            end
        end
    end

    local widgetID, info = PickBestPreyWidget(candidates)
    self._widgetID = widgetID
    return info
end

-- ---- Blizzard widget suppression ----
local function GetBlizzWidgetFrame(widgetID)
    local container = UIWidgetPowerBarContainerFrame
    if not (container and container.widgetFrames and widgetID) then return nil end
    return container.widgetFrames[widgetID]
end

function PreyBarModule:WantHideBlizzard()
    return GetToggle("hide_blizzard") == true
end

function PreyBarModule:SuppressBlizzWidget()
    local wf = GetBlizzWidgetFrame(self._widgetID)
    if not wf then return end
    wf:Hide()
    -- Post-hook Show (not a SetScript override) so Blizzard's own logic is kept
    -- intact; the hook re-hides only while suppression is still wanted. Tracked
    -- per-frame because the resolved widget frame can change between hunts.
    if not wf._oneWoWPreyHooked then
        wf._oneWoWPreyHooked = true
        hooksecurefunc(wf, "Show", function(frame)
            if PreyBarModule:WantHideBlizzard() and ns.ModuleRegistry:IsEnabled("preybar") then
                frame:Hide()
            end
        end)
    end
end

function PreyBarModule:UnsuppressBlizzWidget()
    local wf = GetBlizzWidgetFrame(self._widgetID)
    if not wf then return end
    wf:Show()
end

-- ---- Affix advice ----
--- True while the player carries the Bloody Command "kill something" aura.
---@return boolean
function PreyBarModule:IsKillSomethingActive()
    return C_UnitAuras.GetPlayerAuraBySpellID(KILL_SOMETHING_SPELL_ID) ~= nil
end

function PreyBarModule:IsAmbushed()
    return self._isAmbushed == true
end

-- An ambush whisper is a one-shot announcement; hold the warning briefly, then
-- clear it. A token guards against an older timer clearing a newer ambush.
function PreyBarModule:TriggerAmbush()
    self._isAmbushed = true
    self._ambushToken = self._ambushToken + 1
    local token = self._ambushToken
    C_Timer.After(AMBUSH_HOLD_SECONDS, function()
        if token ~= self._ambushToken then return end
        self._isAmbushed = false
        self:Refresh()
    end)
    self:Refresh()
end

-- ---- Preview (sample bar shown only while the QoL settings panel is open) ----
-- The settings panel is owned by the features UI, which clears its detail child
-- (hiding/reparenting our marker) whenever another module is selected or the
-- window closes. Watching the marker's visibility is therefore a reliable
-- "is the Prey Bar panel still on screen" signal without coupling to UI internals.
function PreyBarModule:StartPreview(parent)
    if not self._frame then return end
    self._previewActive = true

    if self._previewTicker then
        self._previewTicker:Cancel()
        self._previewTicker = nil
    end

    if not self._previewMarker then
        self._previewMarker = CreateFrame("Frame", nil, parent)
        self._previewMarker:SetSize(1, 1)
    else
        self._previewMarker:SetParent(parent)
    end
    self._previewMarker:Show()

    self._previewTicker = C_Timer.NewTicker(0.3, function()
        if not (self._previewMarker and self._previewMarker:IsVisible()) then
            self:StopPreview()
        end
    end)

    self:Refresh()
end

function PreyBarModule:StopPreview()
    self._previewActive = false
    if self._previewTicker then
        self._previewTicker:Cancel()
        self._previewTicker = nil
    end
    self:Refresh()
end

-- ---- Refresh scheduling ----
function PreyBarModule:ScheduleRefresh()
    if self._refreshTimer then return end
    self._refreshTimer = C_Timer.NewTimer(0.2, function()
        self._refreshTimer = nil
        self:Refresh()
    end)
end

-- ---- Events ----
local WIDGET_CACHE_INVALIDATE_EVENTS = {
    ZONE_CHANGED_NEW_AREA = true,
    QUEST_ACCEPTED        = true,
    QUEST_TURNED_IN       = true,
}

function PreyBarModule:RegisterEvents()
    if self._eventFrame then return end
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("UPDATE_UI_WIDGET")
    ef:RegisterEvent("UPDATE_ALL_UI_WIDGETS")
    ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ef:RegisterEvent("QUEST_LOG_UPDATE")
    ef:RegisterEvent("QUEST_ACCEPTED")
    ef:RegisterEvent("QUEST_TURNED_IN")
    ef:RegisterEvent("RAID_BOSS_WHISPER")
    ef:RegisterUnitEvent("UNIT_AURA", "player")
    ef:SetScript("OnEvent", function(_, event, arg1)
        if event == "UPDATE_UI_WIDGET" then
            if type(arg1) == "table" and arg1.widgetType == PREY_WIDGET_TYPE then
                self._widgetID = arg1.widgetID
            end
        elseif event == "UPDATE_ALL_UI_WIDGETS" then
            self:InvalidateWidgetCache()
        elseif event == "RAID_BOSS_WHISPER" then
            if type(arg1) == "string" and string.find(string.lower(arg1), AMBUSH_WHISPER_MATCH, 1, true) then
                self:TriggerAmbush()
            end
            return
        elseif WIDGET_CACHE_INVALIDATE_EVENTS[event] then
            self:InvalidateWidgetCache()
        end
        self:ScheduleRefresh()
    end)
    self._eventFrame = ef
end

function PreyBarModule:UnregisterEvents()
    if self._eventFrame then
        self._eventFrame:UnregisterAllEvents()
        self._eventFrame:SetScript("OnEvent", nil)
        self._eventFrame = nil
    end
    if self._refreshTimer then
        self._refreshTimer:Cancel()
        self._refreshTimer = nil
    end
end

-- ---- Lifecycle ----
function PreyBarModule:OnEnable()
    if not self._frame then
        self:CreateFrame()
    end

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(myself)
        myself:ApplyThemeColors()
        myself:Refresh()
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(myself)
        myself:ApplyFonts()
        myself:Refresh()
    end)

    self:RegisterEvents()
    OneWoW_QoL:RegisterEnteringWorldHandler("preybar", function()
        self:ScheduleRefresh()
        if self._pewDelayTimer then
            self._pewDelayTimer:Cancel()
        end
        self._pewDelayTimer = C_Timer.After(PEW_DELAY_SECONDS, function()
            self._pewDelayTimer = nil
            self:Refresh()
        end)
    end)

    -- Poll fallback so the fill % stays correct even if a widget update event
    -- is missed; cheap (every couple of seconds) and only while enabled.
    if not self._pollTicker then
        self._pollTicker = C_Timer.NewTicker(POLL_INTERVAL, function()
            self:Refresh()
        end)
    end

    self:Refresh()
end

function PreyBarModule:OnDisable()
    self:UnregisterEvents()
    OneWoW_QoL:UnregisterEnteringWorldHandler("preybar")
    self:StopPreview()
    self:UnsuppressBlizzWidget()
    self:InvalidateWidgetCache()
    if self._pewDelayTimer then
        self._pewDelayTimer:Cancel()
        self._pewDelayTimer = nil
    end
    if self._pollTicker then
        self._pollTicker:Cancel()
        self._pollTicker = nil
    end
    if self._frame then
        self._frame:Hide()
    end
end

function PreyBarModule:OnToggle(toggleId, value)
    if toggleId == "hide_blizzard" then
        if value then self:SuppressBlizzWidget() else self:UnsuppressBlizzWidget() end
    end
    self:Refresh()
end
