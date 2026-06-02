-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/preybar/preybar.lua
-- Created by MichinMuggin (Ricky)
-- ============================================================================
-- Prey Hunt Bar
-- ============================================================================
-- Movable HUD bar for the Midnight "prey hunt" lure mechanic.
--
-- Data sources (all live Blizzard APIs, no new collectors):
--   - Progress state (Cold/Warm/Hot/Ready) comes from the prey-hunt-progress
--     UI widget via C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo.
--     The widget ID is discovered at runtime (probed from the power-bar widget
--     container and from UPDATE_UI_WIDGET), never hardcoded.
--   - Active hunt boss/difficulty comes from C_QuestLog.GetActivePreyQuest +
--     GetTitleForQuestID. Difficulty is classified by quest-ID range, which is
--     locale-independent (parsing the title's difficulty word is not).
--   - Affixes are a function of difficulty only (every Normal hunt shares the
--     same affix set, etc.), so no per-boss table is needed.
--
-- Frame construction, layout, and theming live in preybar-ui.lua. This file
-- owns the module table, data resolution, events, and lifecycle.
-- ============================================================================
local addonName, ns = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

-- Live affix-advice signals (factual game data):
--   1245767 = the "kill something" forced-target aura applied by Bloody Command.
--   Ambush is announced via a RAID_BOSS_WHISPER whose text contains "ambush".
local KILL_SOMETHING_SPELL_ID = 1245767
local AMBUSH_WHISPER_MATCH     = "ambush"
local AMBUSH_HOLD_SECONDS      = 5
local POLL_INTERVAL            = 2

local PreyBarModule = {
    id          = "preybar",
    title       = "PREYBAR_TITLE",
    category    = "INTERFACE",
    description = "PREYBAR_DESC",
    version     = "1.0",
    author      = "Ricky",
    contact     = "ricky@wow2.xyz",
    link        = "https://www.wow2.xyz",
    toggles = {
        { id = "show_boss",       label = "PREYBAR_TOGGLE_BOSS",          description = "PREYBAR_TOGGLE_BOSS_DESC",          default = true  },
        { id = "show_difficulty", label = "PREYBAR_TOGGLE_DIFFICULTY",    description = "PREYBAR_TOGGLE_DIFFICULTY_DESC",    default = true  },
        { id = "show_affixes",    label = "PREYBAR_TOGGLE_AFFIXES",       description = "PREYBAR_TOGGLE_AFFIXES_DESC",       default = true  },
        { id = "hide_blizzard",   label = "PREYBAR_TOGGLE_HIDE_BLIZZARD", description = "PREYBAR_TOGGLE_HIDE_BLIZZARD_DESC", default = true  },
        { id = "lock",            label = "PREYBAR_TOGGLE_LOCK",          description = "PREYBAR_TOGGLE_LOCK_DESC",          default = false },
    },
    preview        = false,
    defaultEnabled = true,
    _frame         = nil,
    _eventFrame    = nil,
    _widgetID      = nil,
    _refreshTimer  = nil,
    _pollTicker    = nil,
    _previewActive = false,
    _previewMarker = nil,
    _previewTicker = nil,
    _isAmbushed    = false,
    _ambushToken   = 0,
}

-- ---- Toggle / storage helpers ----
local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("preybar", id)
end
PreyBarModule.GetToggle = GetToggle

local function GetPositionStorage()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return nil end
    local mods = addon.db.global.modules
    if not mods["preybar"] then mods["preybar"] = {} end
    if not mods["preybar"].position then mods["preybar"].position = {} end
    return mods["preybar"].position
end
PreyBarModule.GetPositionStorage = GetPositionStorage

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

--- Resolve the active prey hunt's difficulty and boss name from the quest log.
---@return string|nil difficultyKey
---@return string|nil bossName
function PreyBarModule:GetActiveHunt()
    local questID = C_QuestLog.GetActivePreyQuest()
    if not questID then return nil, nil end
    local difficultyKey = self:ClassifyDifficulty(questID)
    local bossName = C_QuestLog.GetTitleForQuestID(questID)
    return difficultyKey, bossName
end

-- ---- Widget resolution ----
-- The prey widget ID is not stable across patches, so it is discovered rather
-- than hardcoded: probe a candidate ID with the prey-specific visualization
-- getter; a non-nil return means it really is the prey widget.
---@param widgetID number|nil
---@return table|nil widgetInfo
local function ProbePreyWidget(widgetID)
    if not widgetID then return nil end
    return C_UIWidgetManager.GetPreyHuntProgressWidgetVisualizationInfo(widgetID)
end

--- Return the current prey-hunt-progress widget info, caching the resolved ID.
---@return table|nil widgetInfo
function PreyBarModule:GetWidgetInfo()
    if self._widgetID then
        local info = ProbePreyWidget(self._widgetID)
        if info then return info end
        self._widgetID = nil
    end

    local container = UIWidgetPowerBarContainerFrame
    if container and container.widgetFrames then
        for widgetID in pairs(container.widgetFrames) do
            local info = ProbePreyWidget(widgetID)
            if info then
                self._widgetID = widgetID
                return info
            end
        end
    end

    return nil
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
function PreyBarModule:RegisterEvents()
    if self._eventFrame then return end
    local ef = CreateFrame("Frame")
    ef:RegisterEvent("UPDATE_UI_WIDGET")
    ef:RegisterEvent("PLAYER_ENTERING_WORLD")
    ef:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ef:RegisterEvent("QUEST_LOG_UPDATE")
    ef:RegisterEvent("QUEST_ACCEPTED")
    ef:RegisterEvent("QUEST_TURNED_IN")
    ef:RegisterEvent("RAID_BOSS_WHISPER")
    ef:RegisterUnitEvent("UNIT_AURA", "player")
    ef:SetScript("OnEvent", function(_, event, arg1)
        if event == "UPDATE_UI_WIDGET" then
            local widgetID = type(arg1) == "table" and arg1.widgetID or arg1
            if widgetID and ProbePreyWidget(widgetID) then
                self._widgetID = widgetID
            end
        elseif event == "RAID_BOSS_WHISPER" then
            if type(arg1) == "string" and string.find(string.lower(arg1), AMBUSH_WHISPER_MATCH, 1, true) then
                self:TriggerAmbush()
            end
            return
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
    self:StopPreview()
    self:UnsuppressBlizzWidget()
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

ns.PreyBarModule = PreyBarModule
