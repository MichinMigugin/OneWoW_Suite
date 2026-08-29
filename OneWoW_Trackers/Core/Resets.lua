local _, ns = ...

-- ============================================================================
-- Tracker resets
-- ============================================================================
-- Daily/weekly/custom-timer boundaries and the weekly-reset region picker
-- (Trackers settings tab). Methods stay on ns.TrackerData. See
-- OneWoW_Trackers/Docs/ARCHITECTURE.md.
-- ============================================================================

local TD = ns.TrackerData

local pairs, ipairs, tonumber, wipe = pairs, ipairs, tonumber, wipe
local time = time

local function GetDB()
    return ns.db
end

function TD:GetEffectiveResetType(list, section, step)
    if step and step.resetOverride then return step.resetOverride end
    if section and section.resetOverride then return section.resetOverride end
    if list then return list.listType end
    return "todo"
end

-- 1=Sunday .. 7=Saturday, matching C_DateAndTime.GetCurrentCalendarTime().weekday.
-- The weekly reset is just the daily reset that lands on the region's reset day:
--   North America = Tuesday, Europe = Wednesday, Asia (KR/TW) = Thursday.
local RESET_REGION_WEEKDAY = {
    us   = 3,
    eu   = 4,
    asia = 5,
}

-- Seconds until the next weekly reset for a forced reset weekday. Reuses the
-- region-correct daily reset time-of-day (GetSecondsUntilDailyReset) and only
-- overrides which weekday the reset falls on, so the hour stays accurate.
local function SecondsUntilWeeklyForWeekday(targetWeekday)
    local cal = C_DateAndTime.GetCurrentCalendarTime()
    local secUntilDaily = C_DateAndTime.GetSecondsUntilDailyReset()
    if not cal or not secUntilDaily then
        return C_DateAndTime.GetSecondsUntilWeeklyReset()
    end
    local localTOD = (cal.hour or 0) * 3600 + (cal.minute or 0) * 60
    local nextResetWeekday = cal.weekday
    if (localTOD + secUntilDaily) >= 86400 then
        nextResetWeekday = (cal.weekday % 7) + 1
    end
    local daysAhead = (targetWeekday - nextResetWeekday) % 7
    return secUntilDaily + daysAhead * 86400
end

--- Seconds until the next weekly reset, honoring the manual region override.
--- "auto" defers to Blizzard's region-aware API; a region key forces the day.
---@return number
function TD:GetSecondsUntilWeeklyReset()
    local region = GetDB().global.weeklyResetRegion or "auto"
    local weekday = RESET_REGION_WEEKDAY[region]
    if not weekday then
        return C_DateAndTime.GetSecondsUntilWeeklyReset()
    end
    return SecondsUntilWeeklyForWeekday(weekday)
end

-- ============================================================================
-- Weekly reset region — public API
-- ============================================================================
-- The weekly-reset-day picker lives on the Trackers settings tab. Region
-- accessors stay on TrackerData so the UI does not poke SavedVariables
-- directly. All user-facing strings stay localized in this addon.

local RESET_REGION_ORDER = { "auto", "us", "eu", "asia" }
local RESET_REGION_LABEL_KEY = {
    auto = "RESET_REGION_AUTO",
    us   = "RESET_REGION_US",
    eu   = "RESET_REGION_EU",
    asia = "RESET_REGION_ASIA",
}

--- Current weekly reset region key ("auto" | "us" | "eu" | "asia").
---@return string
function TD:GetWeeklyResetRegion()
    return GetDB().global.weeklyResetRegion or "auto"
end

--- Localized label for a region key (defaults to the active region).
---@param value string|nil
---@return string
function TD:GetWeeklyResetRegionLabel(value)
    local key = RESET_REGION_LABEL_KEY[value or self:GetWeeklyResetRegion()] or "RESET_REGION_AUTO"
    return ns.L[key]
end

--- Ordered { value, label } list for building a region dropdown.
---@return table[]
function TD:GetWeeklyResetRegionOptions()
    local out = {}
    for _, value in ipairs(RESET_REGION_ORDER) do
        out[#out + 1] = { value = value, label = ns.L[RESET_REGION_LABEL_KEY[value]] or value }
    end
    return out
end

--- Localized title/description for the region picker UI.
---@return string title, string desc
function TD:GetWeeklyResetUIText()
    return ns.L["SETTINGS_RESET_TITLE"], ns.L["SETTINGS_RESET_DESC"]
end

--- Set the weekly reset region and immediately reconcile any pending resets.
---@param value string
function TD:SetWeeklyResetRegion(value)
    if not RESET_REGION_LABEL_KEY[value] then value = "auto" end
    GetDB().global.weeklyResetRegion = value
    TD:CheckResets()
end

function TD:CheckResets()
    local db = GetDB()

    local now = GetServerTime()

    -- Account markers are newly introduced; seed them to `now` on first run so
    -- the update itself doesn't wipe in-progress account-wide lists. (`now` is
    -- never < a past reset boundary, so seeding can't trigger a spurious reset.)
    if db.global.trackerLastWeeklyReset == 0 then
        db.global.trackerLastWeeklyReset = now
    end
    if db.global.trackerLastDailyReset == 0 then
        db.global.trackerLastDailyReset = now
    end

    local secondsUntilDaily = C_DateAndTime.GetSecondsUntilDailyReset()
    local lastDailyReset = now + secondsUntilDaily - 86400

    local secondsUntilWeekly = self:GetSecondsUntilWeeklyReset()
    local lastWeeklyReset = now + secondsUntilWeekly - 604800

    -- Per-character markers gate char-scoped lists; per-account markers gate
    -- account-wide lists. Account-wide progress is shared across all characters,
    -- so gating it on a per-character marker let a stale alt login wipe shared
    -- progress on the wrong day.
    local needsCharDaily, needsCharWeekly = false, false
    if db.char.trackerLastDailyReset < lastDailyReset then
        needsCharDaily = true
        db.char.trackerLastDailyReset = now
    end
    if db.char.trackerLastWeeklyReset < lastWeeklyReset then
        needsCharWeekly = true
        db.char.trackerLastWeeklyReset = now
    end

    local needsAcctDaily, needsAcctWeekly = false, false
    if db.global.trackerLastDailyReset < lastDailyReset then
        needsAcctDaily = true
        db.global.trackerLastDailyReset = now
    end
    if db.global.trackerLastWeeklyReset < lastWeeklyReset then
        needsAcctWeekly = true
        db.global.trackerLastWeeklyReset = now
    end

    if not (needsCharDaily or needsCharWeekly or needsAcctDaily or needsAcctWeekly) then
        return
    end

    local lists = self:GetListsDB()

    for listID, list in pairs(lists) do
        local progress = self:GetProgressDBForList(listID)
        if progress[listID] then
            local needsDailyReset, needsWeeklyReset
            if list.accountWide then
                needsDailyReset, needsWeeklyReset = needsAcctDaily, needsAcctWeekly
            else
                needsDailyReset, needsWeeklyReset = needsCharDaily, needsCharWeekly
            end

            for _, sec in ipairs(list.sections) do
                for _, step in ipairs(sec.steps or {}) do
                    local resetType = self:GetEffectiveResetType(list, sec, step)
                    local shouldReset = false

                    if resetType == "daily" and needsDailyReset then
                        shouldReset = true
                    elseif resetType == "weekly" and needsWeeklyReset then
                        shouldReset = true
                    end

                    if shouldReset then
                        local sp = self:GetStepProgress(listID, sec.key, step.key)
                        sp.current = 0
                        sp.completed = false
                        wipe(sp.objectives or {})
                    end
                end
            end

            if (list.listType == "daily" and needsDailyReset) or
               (list.listType == "weekly" and needsWeeklyReset) then
                progress[listID].completed = false
                progress[listID].currentStep = 1
                progress[listID].lastReset = now
            end
        end
    end

    -- Roster completers are account-wide aggregates, so they reset on the
    -- account daily/weekly boundary regardless of the host list's own scope.
    if needsAcctDaily or needsAcctWeekly then
        local rosterStore = db.global.trackerRosters
        for listID, list in pairs(lists) do
            local listRosters = rosterStore[listID]
            if listRosters then
                for _, sec in ipairs(list.sections) do
                    for _, step in ipairs(sec.steps or {}) do
                        if step.rosterMode and listRosters[step.key] then
                            local resetType = self:GetEffectiveResetType(list, sec, step)
                            if (resetType == "daily" and needsAcctDaily) or
                               (resetType == "weekly" and needsAcctWeekly) then
                                wipe(listRosters[step.key].completers)
                                listRosters[step.key].lastReset = now
                            end
                        end
                    end
                end
            end
        end
    end

    if needsCharWeekly or needsAcctWeekly then
        print("|cFFFFD100OneWoW Trackers:|r Tracker weekly progress has been reset.")
    end
    if needsCharDaily or needsAcctDaily then
        print("|cFFFFD100OneWoW Trackers:|r Tracker daily progress has been reset.")
    end
end

function TD:CheckCustomTimerResets()
    local now = time()

    local lists = self:GetListsDB()

    for listID, list in pairs(lists) do
        if list.listType == "repeating" then
            local interval = tonumber(list.resetInterval)
            if interval and interval > 0 then
                local prog = self:GetProgress(listID)
                local lastReset = prog.lastReset or 0
                if lastReset == 0 then
                    prog.lastReset = now
                elseif (now - lastReset) >= interval then
                    self:ResetProgress(listID)
                end
            end
        end

        for _, sec in ipairs(list.sections) do
            for _, step in ipairs(sec.steps or {}) do
                if step.trackType == "custom_timer" and step.trackParams then
                    local interval = tonumber(step.trackParams.interval) or 0
                    if interval > 0 then
                        local sp = self:GetStepProgress(listID, sec.key, step.key)
                        local lastCompleted = sp.lastCompleted or 0
                        if sp.completed and (now - lastCompleted) >= interval then
                            sp.current = 0
                            sp.completed = false
                        end
                    end
                end
            end
        end
    end
end
