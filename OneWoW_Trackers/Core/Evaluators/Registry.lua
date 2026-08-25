local _, ns = ...

-- ============================================================================
-- TrackerEvaluators
-- ============================================================================
-- Live step evaluation. Family files Register(type, fn); unregistered types
-- (manual, kill_creature, loot, enter_instance, npc_interact, exploration, custom_timer)
-- return nil so the engine uses session bumps and step.max.
-- kill_encounter is live when a raid lock is complete, else nil (session latch).
--
-- Contract: Evaluate(obj) -> current, goal | nil
--   goal is the live target (currency amount, item count, quest pick, …).
--   step.max is only the goal when Evaluate returns nil.
--   step.noMax: show quantity only; do not auto-complete from a comparison.
-- ============================================================================

ns.TrackerEvaluators = ns.TrackerEvaluators or {}
local E = ns.TrackerEvaluators

local handlers = {}
local format = format
local tonumber = tonumber

function E.Register(trackType, fn)
    handlers[trackType] = fn
end

--- Live (current, goal), or nil when the type is session/manual.
---@param obj table|nil
---@return number|nil current
---@return number|nil goal
function E.Evaluate(obj)
    if not obj then return nil end
    local fn = handlers[obj.type]
    if not fn then return nil end
    return fn(obj.params or {})
end

--- Pin / hub progress text. Re-evaluates live types so the denominator is the
--- evaluator goal, not a stale step.max default of 1.
---@param step table
---@param sp table
---@param rosterCount number|nil
---@return string
function E.FormatStepProgress(step, sp, rosterCount)
    if rosterCount then
        return tostring(rosterCount)
    end

    local current, goal = E.Evaluate({
        type = step.trackType,
        params = step.trackParams or {},
    })

    if current == nil then
        current = (sp and sp.current) or 0
        if step.trackType == "manual" and not (step.max and step.max > 1) then
            return ""
        end
        if step.noMax then
            return current > 0 and tostring(current) or ""
        end
        local max = tonumber(step.max) or 1
        if max > 0 then
            return format("%d/%d", current, max)
        end
        return current > 0 and tostring(current) or ""
    end

    if step.noMax or not goal or goal <= 0 then
        return tostring(current)
    end
    return format("%d/%d", current, goal)
end
