-- ============================================================================
-- Cursor Enhancer — situations (place × combat match / resolve)
-- ============================================================================
-- Profile-scoped situation cards decide WHEN pieces show and optional look
-- overrides. Global look/feel is the identity; situations gate + delta.
-- Full design: OneWoW_QoL/Docs/Modules/cursorenhancer.md
-- ============================================================================

local _, ns = ...
local CursorEnhancerModule = ns.ModuleRegistry:Current()
if not CursorEnhancerModule then return end

local IsInInstance = IsInInstance
local UnitAffectingCombat = UnitAffectingCombat
local UnitClass = UnitClass
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local pairs, type, tostring = pairs, type, tostring

local Situations = {}
CursorEnhancerModule.Situations = Situations

-- Place specificity: higher wins. mythic_plus beats any_instance / dungeon.
local PLACE_SPECIFICITY = {
    everywhere     = 0,
    open_world     = 1,
    any_instance   = 1,
    dungeon        = 2,
    raid           = 2,
    scenario       = 2,
    arena          = 2,
    battleground   = 2,
    mythic_plus    = 3,
}

local SHOW_KEYS = {
    "outerRing", "middleRing", "centerMarker", "trail",
    "gcd", "cast", "middleSwipe", "outerSwipe", "pips",
}

Situations.PLACE_SPECIFICITY = PLACE_SPECIFICITY
Situations.SHOW_KEYS = SHOW_KEYS

local function CopyColor(c)
    if type(c) ~= "table" then return { 1, 1, 1 } end
    return { c[1] or 1, c[2] or 1, c[3] or 1 }
end

local function DeepCopyTable(src)
    if type(src) ~= "table" then return src end
    local dst = {}
    for k, v in pairs(src) do
        dst[k] = type(v) == "table" and DeepCopyTable(v) or v
    end
    return dst
end

--- Stable id for a new situation card.
---@return string
function Situations.NewId()
    return "sit_" .. tostring(GetTime()) .. "_" .. tostring(math.random(100000, 999999))
end

--- Build the four teaching default situations.
---@return table[]
function Situations.DefaultSituations()
    return {
        {
            id = "default_world_ooc",
            enabled = true,
            place = "open_world",
            combat = "out",
            show = {
                outerRing = true, centerMarker = true,
            },
            overrideMouseLook = false,
            onlyWhileMouseLook = false,
            overrides = { alpha = 0.35 },
        },
        {
            id = "default_world_combat",
            enabled = true,
            place = "open_world",
            combat = "in",
            show = {
                outerRing = true, centerMarker = true,
            },
            overrideMouseLook = false,
            onlyWhileMouseLook = false,
            overrides = { alpha = 1.0 },
        },
        {
            id = "default_instance_ooc",
            enabled = true,
            place = "any_instance",
            combat = "out",
            show = {
                outerRing = true, centerMarker = true, gcd = true,
            },
            overrideMouseLook = false,
            onlyWhileMouseLook = false,
            overrides = { alpha = 0.55 },
        },
        {
            id = "default_instance_combat",
            enabled = true,
            place = "any_instance",
            combat = "in",
            show = {
                outerRing = true, middleRing = true, centerMarker = true,
                gcd = true, cast = true, pips = true,
            },
            overrideMouseLook = false,
            onlyWhileMouseLook = false,
            overrides = { alpha = 1.0 },
        },
    }
end

--- Global look/feel defaults (no situations — that list is user-owned).
---@return table
function Situations.GlobalDefaults()
    local _, class = UnitClass("player")
    local classColor = RAID_CLASS_COLORS[class] or { r = 1, g = 1, b = 1 }
    return {
        ringSize            = 90,
        offsetX             = 0,
        offsetY             = 0,
        alpha               = 1.0,
        onlyWhileMouseLook  = false,
        outerRingEnabled    = true,
        outerRingColor      = { classColor.r, classColor.g, classColor.b },
        outerRingClassColor = false,
        middleRingEnabled   = false,
        middleRingColor     = { 1.0, 1.0, 1.0 },
        centerMarker        = "Dot",
        centerMarkerColor   = { 1.0, 1.0, 1.0 },
        centerMarkerHidden  = false,
        mouseTrail          = false,
        trailColor          = { 1.0, 1.0, 1.0 },
        trailFadeTime       = 0.6,
        trailStyle          = "ring",
        trailSize           = 36,
        middleSwipe         = { enabled = false, fill = false },
        outerSwipe          = { enabled = false, fill = false },
        pipsEnabled         = false,
        pipSize             = 28,
        pipOffsetX          = 0,
        pipOffsetY          = 0,
        pipColor            = { 1.0, 1.0, 1.0 },
        pipClassColor       = false,
        pipFillLtr          = true,
        gcd = {
            enabled      = false,
            attached     = true,
            radius       = 21,
            ringTex      = "c1",
            scale        = 100,
            color        = { 1.0, 1.0, 1.0 },
            useClassColor = false,
            alpha        = 0.8,
        },
        castCircle = {
            enabled       = false,
            attached      = true,
            radius        = 30,
            ringTex       = "c1",
            scale         = 100,
            color         = { classColor.r, classColor.g, classColor.b },
            useClassColor = true,
            alpha         = 0.8,
            sparkEnabled  = true,
        },
    }
end

--- Show-set template cloned when the user adds a new situation card.
---@param profile table
---@return table
function Situations.ShowTemplateFromGlobal(profile)
    return {
        outerRing     = profile.outerRingEnabled ~= false,
        middleRing    = profile.middleRingEnabled == true,
        centerMarker  = not profile.centerMarkerHidden and (profile.centerMarker or "Dot") ~= "None",
        trail         = profile.mouseTrail == true,
        gcd           = profile.gcd and profile.gcd.enabled == true,
        cast          = profile.castCircle and profile.castCircle.enabled == true,
        middleSwipe   = profile.middleSwipe and profile.middleSwipe.enabled == true,
        outerSwipe    = profile.outerSwipe and profile.outerSwipe.enabled == true,
        pips          = profile.pipsEnabled == true,
    }
end

--- New empty situation card (inherits global; no overrides).
---@param profile table
---@return table
function Situations.NewSituation(profile)
    return {
        id = Situations.NewId(),
        enabled = true,
        place = "everywhere",
        combat = "either",
        show = Situations.ShowTemplateFromGlobal(profile),
        overrideMouseLook = false,
        onlyWhileMouseLook = false,
        overrides = {},
    }
end

-- ---- Place / combat context ----

--- Resolve current place kind flags for matching.
---@return string instanceType "" when not instanced
---@return boolean inInstance
---@return boolean challengeMode
function Situations.GetPlaceContext()
    local inInst, instType = IsInInstance()
    instType = instType or ""
    local challengeMode = OneWoW.Restriction.IsTypeActive(Enum.AddOnRestrictionType.ChallengeMode)
    return instType, inInst and true or false, challengeMode
end

--- Whether a situation's place selector matches the current world.
---@param place string
---@param instType string
---@param inInstance boolean
---@param challengeMode boolean
---@return boolean
function Situations.PlaceMatches(place, instType, inInstance, challengeMode)
    if place == "everywhere" then
        return true
    elseif place == "open_world" then
        return not inInstance
    elseif place == "any_instance" then
        return inInstance
    elseif place == "dungeon" then
        return inInstance and instType == "party" and not challengeMode
    elseif place == "mythic_plus" then
        return inInstance and instType == "party" and challengeMode
    elseif place == "raid" then
        return inInstance and instType == "raid"
    elseif place == "scenario" then
        return inInstance and instType == "scenario"
    elseif place == "arena" then
        return inInstance and instType == "arena"
    elseif place == "battleground" then
        return inInstance and instType == "pvp"
    end
    return false
end

---@return boolean
function Situations.IsPlayerInCombat()
    return OneWoW.Restriction.IsInCombat() or UnitAffectingCombat("player")
end

---@param combat string
---@param inCombat boolean
---@return boolean
function Situations.CombatMatches(combat, inCombat)
    if combat == "either" then return true end
    if combat == "in" then return inCombat end
    if combat == "out" then return not inCombat end
    return false
end

--- Pick the winning enabled situation (specificity, then list order).
---@param profile table
---@return table|nil situation
---@return number|nil index
function Situations.PickWinner(profile)
    local situations = profile.situations
    if type(situations) ~= "table" then return nil, nil end

    local instType, inInstance, challengeMode = Situations.GetPlaceContext()
    local inCombat = Situations.IsPlayerInCombat()

    local best, bestIdx, bestScore
    for i, sit in ipairs(situations) do
        if sit.enabled ~= false
            and Situations.PlaceMatches(sit.place or "everywhere", instType, inInstance, challengeMode)
            and Situations.CombatMatches(sit.combat or "either", inCombat)
        then
            local score = PLACE_SPECIFICITY[sit.place] or 0
            if not best or score > bestScore then
                best, bestIdx, bestScore = sit, i, score
            end
            -- Equal specificity: keep earlier list entry (first wins).
        end
    end
    return best, bestIdx
end

--- Enabled cards that share the same place×combat (config conflict).
---@param profile table
---@return table conflictSet  map of situation id → true
function Situations.FindConflicts(profile)
    local conflictSet = {}
    local situations = profile.situations
    if type(situations) ~= "table" then return conflictSet end

    local seen = {}
    for _, sit in ipairs(situations) do
        if sit.enabled ~= false then
            local key = (sit.place or "everywhere") .. "|" .. (sit.combat or "either")
            if seen[key] then
                conflictSet[sit.id] = true
                conflictSet[seen[key]] = true
            else
                seen[key] = sit.id
            end
        end
    end
    return conflictSet
end

local function MergeThingLook(globalLook, override)
    if type(override) ~= "table" then return globalLook end
    local merged = DeepCopyTable(globalLook)
    for k, v in pairs(override) do
        if type(v) == "table" and type(merged[k]) == "table" then
            for k2, v2 in pairs(v) do
                merged[k][k2] = v2
            end
        else
            merged[k] = v
        end
    end
    return merged
end

--- Snapshot global thing config into an override table (when Override is checked).
---@param profile table
---@param thing string
---@return table
function Situations.SnapshotOverride(profile, thing)
    if thing == "alpha" then
        return { alpha = profile.alpha or 1.0 }
    elseif thing == "outerRing" then
        return {
            color = CopyColor(profile.outerRingColor),
            classColor = profile.outerRingClassColor == true,
        }
    elseif thing == "middleRing" then
        return { color = CopyColor(profile.middleRingColor) }
    elseif thing == "centerMarker" then
        return {
            style = profile.centerMarker or "Dot",
            color = CopyColor(profile.centerMarkerColor),
        }
    elseif thing == "trail" then
        return {
            color = CopyColor(profile.trailColor),
            fadeTime = profile.trailFadeTime or 0.6,
            style = profile.trailStyle or "ring",
            size = profile.trailSize or 36,
        }
    elseif thing == "gcd" then
        return DeepCopyTable(profile.gcd or {})
    elseif thing == "cast" then
        return DeepCopyTable(profile.castCircle or {})
    elseif thing == "middleSwipe" then
        return DeepCopyTable(profile.middleSwipe or {})
    elseif thing == "outerSwipe" then
        return DeepCopyTable(profile.outerSwipe or {})
    elseif thing == "pips" then
        return {
            size = profile.pipSize or 28,
            color = CopyColor(profile.pipColor),
            classColor = profile.pipClassColor == true,
            offsetX = profile.pipOffsetX or 0,
            offsetY = profile.pipOffsetY or 0,
            fillLtr = profile.pipFillLtr ~= false,
        }
    end
    return {}
end

--- True when the situation customizes Look & Feel (size/offset/alpha/mouse look).
---@param sit table?
---@return boolean
function Situations.HasLookFeelOverride(sit)
    if not sit then return false end
    if sit.overrideMouseLook then return true end
    local ov = sit.overrides
    if type(ov) ~= "table" then return false end
    return ov.alpha ~= nil or ov.ringSize ~= nil or ov.offsetX ~= nil or ov.offsetY ~= nil
end

--- Snapshot global Look & Feel into the situation (Custom mode).
---@param sit table
---@param profile table
function Situations.SnapshotLookFeel(sit, profile)
    sit.overrides = sit.overrides or {}
    sit.overrides.ringSize = profile.ringSize or 90
    sit.overrides.offsetX = profile.offsetX or 0
    sit.overrides.offsetY = profile.offsetY or 0
    sit.overrides.alpha = profile.alpha or 1.0
    sit.overrideMouseLook = true
    sit.onlyWhileMouseLook = profile.onlyWhileMouseLook == true
end

--- Clear Look & Feel overrides (Use Global mode).
---@param sit table
function Situations.ClearLookFeel(sit)
    sit.overrideMouseLook = false
    sit.onlyWhileMouseLook = false
    if type(sit.overrides) ~= "table" then return end
    sit.overrides.ringSize = nil
    sit.overrides.offsetX = nil
    sit.overrides.offsetY = nil
    sit.overrides.alpha = nil
end

--- Resolve effective show + look for the current context.
---@param profile table
---@return table resolved
function Situations.Resolve(profile)
    local sit = Situations.PickWinner(profile)
    local show = {}
    if sit and type(sit.show) == "table" then
        for _, key in ipairs(SHOW_KEYS) do
            show[key] = sit.show[key] == true
        end
    end

    local overrides = (sit and type(sit.overrides) == "table") and sit.overrides or {}

    local alpha = profile.alpha or 1.0
    if overrides.alpha ~= nil then
        alpha = overrides.alpha
    end

    local onlyWhileMouseLook = profile.onlyWhileMouseLook == true
    if sit and sit.overrideMouseLook then
        onlyWhileMouseLook = sit.onlyWhileMouseLook == true
    end

    local ringSize = profile.ringSize or 90
    if overrides.ringSize ~= nil then ringSize = overrides.ringSize end
    local offsetX = profile.offsetX or 0
    if overrides.offsetX ~= nil then offsetX = overrides.offsetX end
    local offsetY = profile.offsetY or 0
    if overrides.offsetY ~= nil then offsetY = overrides.offsetY end

    -- Build effective look tables for Apply* paths.
    local outerColor = profile.outerRingColor
    local outerClass = profile.outerRingClassColor
    if type(overrides.outerRing) == "table" then
        if overrides.outerRing.color then outerColor = overrides.outerRing.color end
        if overrides.outerRing.classColor ~= nil then outerClass = overrides.outerRing.classColor end
    end

    local middleColor = profile.middleRingColor
    if type(overrides.middleRing) == "table" and overrides.middleRing.color then
        middleColor = overrides.middleRing.color
    end

    local markerStyle = profile.centerMarker or "Dot"
    local markerColor = profile.centerMarkerColor
    if type(overrides.centerMarker) == "table" then
        if overrides.centerMarker.style then markerStyle = overrides.centerMarker.style end
        if overrides.centerMarker.color then markerColor = overrides.centerMarker.color end
    end
    -- Style "None" means no marker, regardless of the situation show flag.
    if markerStyle == "None" then
        show.centerMarker = false
    end

    local trail = {
        color = profile.trailColor,
        fadeTime = profile.trailFadeTime or 0.6,
        style = profile.trailStyle or "ring",
        size = profile.trailSize or 36,
    }
    if type(overrides.trail) == "table" then
        trail = MergeThingLook(trail, overrides.trail)
    end

    local gcd = DeepCopyTable(profile.gcd or {})
    if type(overrides.gcd) == "table" then
        gcd = MergeThingLook(gcd, overrides.gcd)
    end
    gcd.enabled = show.gcd == true

    local castCircle = DeepCopyTable(profile.castCircle or {})
    if type(overrides.cast) == "table" then
        castCircle = MergeThingLook(castCircle, overrides.cast)
    end
    castCircle.enabled = show.cast == true

    local middleSwipe = DeepCopyTable(profile.middleSwipe or {})
    if type(overrides.middleSwipe) == "table" then
        middleSwipe = MergeThingLook(middleSwipe, overrides.middleSwipe)
    end
    middleSwipe.enabled = show.middleSwipe == true

    local outerSwipe = DeepCopyTable(profile.outerSwipe or {})
    if type(overrides.outerSwipe) == "table" then
        outerSwipe = MergeThingLook(outerSwipe, overrides.outerSwipe)
    end
    outerSwipe.enabled = show.outerSwipe == true

    local pipSize = profile.pipSize or 28
    local pipColor = profile.pipColor
    local pipClassColor = profile.pipClassColor == true
    local pipOffsetX = profile.pipOffsetX or 0
    local pipOffsetY = profile.pipOffsetY or 0
    local pipFillLtr = profile.pipFillLtr ~= false
    if type(overrides.pips) == "table" then
        if overrides.pips.size ~= nil then pipSize = overrides.pips.size end
        if overrides.pips.color then pipColor = overrides.pips.color end
        if overrides.pips.classColor ~= nil then pipClassColor = overrides.pips.classColor end
        if overrides.pips.offsetX ~= nil then pipOffsetX = overrides.pips.offsetX end
        if overrides.pips.offsetY ~= nil then pipOffsetY = overrides.pips.offsetY end
        if overrides.pips.fillLtr ~= nil then pipFillLtr = overrides.pips.fillLtr end
    end

    local anyVisual = show.outerRing or show.middleRing or show.centerMarker
        or show.trail or show.gcd or show.cast or show.middleSwipe or show.outerSwipe or show.pips

    return {
        situation          = sit,
        show               = show,
        alpha              = alpha,
        onlyWhileMouseLook = onlyWhileMouseLook,
        anyVisual          = anyVisual == true,
        ringSize           = ringSize,
        offsetX            = offsetX,
        offsetY            = offsetY,
        outerRingColor     = outerColor,
        outerRingClassColor = outerClass,
        middleRingColor    = middleColor,
        centerMarker       = markerStyle,
        centerMarkerColor  = markerColor,
        trail              = trail,
        gcd                = gcd,
        castCircle         = castCircle,
        middleSwipe        = middleSwipe,
        outerSwipe         = outerSwipe,
        pipsEnabled        = show.pips == true,
        pipSize            = pipSize,
        pipColor           = pipColor,
        pipClassColor      = pipClassColor,
        pipOffsetX         = pipOffsetX,
        pipOffsetY         = pipOffsetY,
        pipFillLtr         = pipFillLtr,
    }
end

-- ---- Migration from legacy visibility / alpha keys ----

local function MergeMissing(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            MergeMissing(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

--- Ensure profile has situations model; migrate legacy keys once.
--- Situations are never MergeMissing'd by index (that resurrected deleted teaching
--- cards whenever the list had fewer than four entries). Seed only when absent/empty.
---@param profile table
function Situations.MigrateProfile(profile)
    local defaults = Situations.GlobalDefaults()
    MergeMissing(profile, defaults)

    if type(profile.situations) ~= "table" or #profile.situations == 0 then
        profile.situations = Situations.DefaultSituations()

        -- Map legacy alpha into default cards.
        local combatA = profile.combatAlpha
        local oocA = profile.outOfCombatAlpha
        if combatA ~= nil or oocA ~= nil then
            for _, sit in ipairs(profile.situations) do
                sit.overrides = sit.overrides or {}
                if sit.combat == "in" and combatA ~= nil then
                    sit.overrides.alpha = combatA
                elseif sit.combat == "out" and oocA ~= nil then
                    sit.overrides.alpha = oocA
                end
            end
        end

        if profile.onlyWhenHidden ~= nil then
            profile.onlyWhileMouseLook = profile.onlyWhenHidden == true
        end

        local vis = profile.visibility
        if vis == "never" then
            for _, sit in ipairs(profile.situations) do
                sit.enabled = false
            end
        elseif vis == "in_combat" then
            for _, sit in ipairs(profile.situations) do
                if sit.combat == "out" then sit.enabled = false end
            end
        elseif vis == "out_of_combat" then
            for _, sit in ipairs(profile.situations) do
                if sit.combat == "in" then sit.enabled = false end
            end
        end

        if profile.showOutOfCombat == false then
            for _, sit in ipairs(profile.situations) do
                if sit.place == "open_world" and sit.combat == "out" then
                    sit.enabled = false
                end
            end
        end

        if profile.showInInstance == false then
            for _, sit in ipairs(profile.situations) do
                if sit.place == "any_instance" or sit.place == "dungeon"
                    or sit.place == "raid" or sit.place == "scenario"
                    or sit.place == "arena" or sit.place == "battleground"
                    or sit.place == "mythic_plus"
                then
                    sit.enabled = false
                end
            end
        end

        -- Single base alpha from max of legacy if neither combat-specific was set.
        if profile.alpha == nil then
            profile.alpha = 1.0
        end
    end

    -- Strip instanceOnly from nested configs if still present.
    if type(profile.gcd) == "table" then
        profile.gcd.instanceOnly = nil
    end
    if type(profile.castCircle) == "table" then
        profile.castCircle.instanceOnly = nil
    end
end
