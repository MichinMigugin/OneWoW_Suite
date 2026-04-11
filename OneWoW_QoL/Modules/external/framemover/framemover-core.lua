local addonName, ns = ...

local FM = {}
ns.FrameMoverCore = FM

FM.active       = false
FM.frameStates  = {}
FM.combatQueue  = {}
FM._settingPoint = false

local MIN_SCALE  = 0.5
local MAX_SCALE  = 2.0
local SCALE_STEP = 0.05

local restoreQueue = {}
local restoreFrame
local captureFrame
local modifierFrame

-- ============================================================
-- Special per-frame handlers
-- Frames that need custom drag behaviour (e.g. GameMenuFrame
-- has OneWoW portals / panels attached to it).
-- ============================================================

-- Per-frame overrides (forceShift, onDragStart, onDragStop).
-- Add entries here for frames that need custom drag behaviour.
local SPECIAL = {}

local function SyncEscPanels()
    local esc = _G.OneWoW and OneWoW.PortalHubEsc
    if esc and esc.SyncEscLayout then
        esc:SyncEscLayout()
        return
    end
    local ow = _G.OneWoW
    local escPanels = ow and ow.EscPanels
    local ph = ow and ow.db and ow.db.global and ow.db.global.portalHub
    if escPanels and escPanels.EnsurePanelsContainer and ph then
        escPanels:EnsurePanelsContainer(ph)
        return
    end
end

SPECIAL["GameMenuFrame"] = {
    forceShift = true,

    onDragStart = function()
        local f = _G["OneWoW_QoL_FM_ESCSync"]
        if not f then
            f = CreateFrame("Frame", "OneWoW_QoL_FM_ESCSync")
        end
        f:SetScript("OnUpdate", SyncEscPanels)
        f:Show()
    end,

    onDragStop = function()
        local f = _G["OneWoW_QoL_FM_ESCSync"]
        if f then
            f:SetScript("OnUpdate", nil)
            f:Hide()
        end
        SyncEscPanels()
    end,
}

-- ============================================================
-- Database helpers
-- ============================================================

function FM:GetDB()
    local addon = _G.OneWoW_QoL
    if not addon or not addon.db then return nil end
    if not addon.db.global.modules["framemover"] then
        addon.db.global.modules["framemover"] = {}
    end
    local modDB = addon.db.global.modules["framemover"]
    if not modDB.fmdata then
        modDB.fmdata = { frames = {} }
    end
    return modDB.fmdata
end

function FM:GetFrameDB(frameName)
    local db = self:GetDB()
    if not db then return {} end
    if not db.frames[frameName] then
        db.frames[frameName] = {}
    end
    return db.frames[frameName]
end

-- ============================================================
-- Toggle helpers (read live from ModuleRegistry)
-- ============================================================

local function GetToggle(id)
    return ns.ModuleRegistry:GetToggleValue("framemover", id)
end

function FM:RequireShift()   return GetToggle("require_shift")  end
function FM:ScalingEnabled() return GetToggle("enable_scaling")  end
function FM:SavePositions()  return GetToggle("save_positions")  end
function FM:SaveScales()     return GetToggle("save_scales")     end
function FM:ClampToScreen()  return GetToggle("clamp_to_screen") end

-- ============================================================
-- Frame resolution  ("Foo.Bar.Baz" -> _G.Foo.Bar.Baz)
-- ============================================================

function FM:ResolveFrame(frameName)
    local parts = { strsplit(".", frameName) }
    local obj = _G[parts[1]]
    for i = 2, #parts do
        if type(obj) ~= "table" then return nil end
        obj = obj[parts[i]]
    end
    if type(obj) == "table" and type(obj.GetObjectType) == "function" then
        return obj
    end
    return nil
end

-- ============================================================
-- Per-frame enable / disable
-- ============================================================

function FM:IsFrameEnabled(frameName)
    local db = self:GetFrameDB(frameName)
    return not db.disabled
end

function FM:SetFrameEnabled(frameName, enabled)
    local db = self:GetFrameDB(frameName)
    db.disabled = (not enabled) or nil
    local state = self.frameStates[frameName]
    if not state or not state.frame then return end
    if enabled then
        self:RestoreScale(frameName)
        if state.dragged then self:QueueRestore(frameName) end
    else
        state.dragged = false
    end
end

-- ============================================================
-- Position save / restore
-- ============================================================

function FM:SavePosition(frameName)
    if not self:SavePositions() then return end
    local state = self.frameStates[frameName]
    if not state or not state.frame then return end

    local frame = state.frame
    local cx, cy = frame:GetCenter()
    if not cx then return end

    local db    = self:GetFrameDB(frameName)
    db.centerX  = cx
    db.centerY  = cy
    state.dragged = true
end

function FM:RestorePosition(frameName)
    local state = self.frameStates[frameName]
    if not state or not state.frame then return false end
    if not state.dragged then return false end

    local db = self:GetFrameDB(frameName)
    if not db.centerX or not db.centerY then return false end

    local frame = state.frame
    if InCombatLockdown() and frame:IsProtected() then
        self:QueueForCombatEnd(function() FM:RestorePosition(frameName) end)
        return false
    end

    self._settingPoint = true
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", db.centerX, db.centerY)
    self._settingPoint = false
    return true
end

-- ============================================================
-- Scale save / restore
-- ============================================================

function FM:SaveScale(frameName, scale)
    if not self:SaveScales() then return end
    self:GetFrameDB(frameName).scale = scale
end

function FM:RestoreScale(frameName)
    local state = self.frameStates[frameName]
    if not state or not state.frame then return false end

    local db = self:GetFrameDB(frameName)
    if not db.scale then return false end

    local frame = state.frame
    if InCombatLockdown() and frame:IsProtected() then
        self:QueueForCombatEnd(function() FM:RestoreScale(frameName) end)
        return false
    end

    frame:SetScale(db.scale)
    return true
end

function FM:AdjustScale(frameName, frame, delta)
    if not self.active then return end
    if not self:IsFrameEnabled(frameName) then return end
    if InCombatLockdown() and frame:IsProtected() then return end

    local oldScale = frame:GetScale()
    local newScale = oldScale + (delta > 0 and SCALE_STEP or -SCALE_STEP)
    newScale = math.max(MIN_SCALE, math.min(MAX_SCALE, newScale))
    if newScale == oldScale then return end

    local cx, cy = frame:GetCenter()
    if not cx then return end

    frame:SetScale(newScale)

    self._settingPoint = true
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    self._settingPoint = false

    local state = self.frameStates[frameName]
    if state then state.dragged = true end
    self:SaveScale(frameName, newScale)
    self:SavePosition(frameName)
end

-- ============================================================
-- Reset helpers
-- ============================================================

function FM:ResetAllPositions()
    local db = self:GetDB()
    if not db then return end
    for frameName, fdb in pairs(db.frames) do
        fdb.centerX = nil
        fdb.centerY = nil
        local state = self.frameStates[frameName]
        if state then state.dragged = false end
    end
end

function FM:ResetAllScales()
    local db = self:GetDB()
    if not db then return end
    for frameName, fdb in pairs(db.frames) do
        fdb.scale = nil
        local state = self.frameStates[frameName]
        if state and state.frame then
            if not (InCombatLockdown() and state.frame:IsProtected()) then
                state.frame:SetScale(1.0)
            end
        end
    end
end

function FM:ResetFrame(frameName)
    local db = self:GetFrameDB(frameName)
    db.centerX = nil
    db.centerY = nil
    db.scale   = nil
    local state = self.frameStates[frameName]
    if state then
        state.dragged = false
        if state.frame and not (InCombatLockdown() and state.frame:IsProtected()) then
            state.frame:SetScale(1.0)
        end
    end
end

-- ============================================================
-- Make a frame movable
-- ============================================================

function FM:MakeMovable(frame, frameName)
    if self.frameStates[frameName] and self.frameStates[frameName].hooked then return end

    local state = self.frameStates[frameName] or {}
    state.frame      = frame
    state.hooked      = true
    state.dragging    = false
    state.dragged     = false

    local db = self:GetFrameDB(frameName)
    if db.centerX and db.centerY then
        state.dragged = true
    end

    state.wasMovable = frame:IsMovable()
    state.wasClamp   = frame:IsClampedToScreen()

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(self:ClampToScreen())

    self.frameStates[frameName] = state

    local special = SPECIAL[frameName]

    -- Drag hooks ------------------------------------------------
    frame:HookScript("OnMouseDown", function(f, button)
        if not FM.active then return end
        if not FM:IsFrameEnabled(frameName) then return end
        if button ~= "LeftButton" then return end
        if (special and special.forceShift) or FM:RequireShift() then
            if not IsShiftKeyDown() then return end
        end
        if InCombatLockdown() and f:IsProtected() then return end
        if special and special.onDragStart then special.onDragStart() end
        f:StartMoving()
        state.dragging = true
    end)

    frame:HookScript("OnMouseUp", function(f, button)
        if not FM.active then return end
        if button ~= "LeftButton" then return end
        if not state.dragging then return end
        f:StopMovingOrSizing()
        state.dragging = false
        state.dragged  = true
        FM:SavePosition(frameName)
        if special and special.onDragStop then special.onDragStop() end
    end)

    -- Catch interrupted drags (frame hidden mid-drag) -----------
    frame:HookScript("OnHide", function(f)
        if state.dragging then
            f:StopMovingOrSizing()
            state.dragging = false
            state.dragged  = true
            FM:SavePosition(frameName)
            if special and special.onDragStop then special.onDragStop() end
        end
    end)

    -- Persist position across Blizzard anchor resets ------------
    hooksecurefunc(frame, "SetPoint", function()
        if FM._settingPoint then return end
        if not FM.active then return end
        if not FM:IsFrameEnabled(frameName) then return end
        if not state.dragged then return end
        FM:QueueRestore(frameName)
    end)

    -- Restore on show -------------------------------------------
    frame:HookScript("OnShow", function()
        if not FM.active then return end
        if not FM:IsFrameEnabled(frameName) then return end
        FM:RestoreScale(frameName)
        if state.dragged then
            FM:QueueRestore(frameName)
        end
    end)

    -- Apply saved state if already visible ----------------------
    if frame:IsVisible() then
        FM:RestoreScale(frameName)
        if state.dragged then
            FM:RestorePosition(frameName)
        end
    end
end

-- ============================================================
-- Restore queue  (batches SetPoint overrides into one OnUpdate)
-- ============================================================

function FM:QueueRestore(frameName)
    restoreQueue[frameName] = true
    if restoreFrame then restoreFrame:Show() end
end

local function ProcessRestoreQueue()
    restoreFrame:Hide()
    for frameName in pairs(restoreQueue) do
        FM:RestorePosition(frameName)
    end
    wipe(restoreQueue)
end

local function CreateRestoreFrame()
    restoreFrame = CreateFrame("Frame")
    restoreFrame:Hide()
    restoreFrame:SetScript("OnUpdate", ProcessRestoreQueue)
end

-- ============================================================
-- Scale capture frame  (intercepts Ctrl+Scroll globally)
-- ============================================================

function FM:GetFrameUnderCursor()
    local best, bestName
    local bestLevel = -1

    for frameName, state in pairs(self.frameStates) do
        local f = state.frame
        if f and f:IsVisible() and self:IsFrameEnabled(frameName) then
            if f:IsMouseOver() then
                local lvl = f:GetFrameLevel()
                if lvl > bestLevel then
                    bestLevel = lvl
                    best      = f
                    bestName  = frameName
                end
            end
        end
    end
    return bestName, best
end

function FM:SetScalingEnabled(on)
    if captureFrame then
        if not on then captureFrame:EnableMouseWheel(false) end
    end
end

local function CreateCaptureFrame()
    captureFrame = CreateFrame("Frame", "OneWoW_QoL_FM_ScaleCapture", UIParent)
    captureFrame:SetFrameStrata("TOOLTIP")
    captureFrame:SetAllPoints()
    captureFrame:EnableMouse(false)
    captureFrame:EnableMouseWheel(false)
    captureFrame:SetScript("OnMouseWheel", function(_, delta)
        if not FM.active then return end
        if not FM:ScalingEnabled() then return end
        local name, frame = FM:GetFrameUnderCursor()
        if name and frame then
            FM:AdjustScale(name, frame, delta)
        end
    end)

    modifierFrame = CreateFrame("Frame")
    modifierFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    modifierFrame:SetScript("OnEvent", function(_, _, key, down)
        if not FM.active or not FM:ScalingEnabled() then
            captureFrame:EnableMouseWheel(false)
            return
        end
        if key == "LCTRL" or key == "RCTRL" then
            captureFrame:EnableMouseWheel(down == 1)
        end
    end)
end

-- ============================================================
-- Combat lockdown queue
-- ============================================================

function FM:QueueForCombatEnd(func)
    table.insert(self.combatQueue, func)
end

function FM:FlushCombatQueue()
    for _, func in ipairs(self.combatQueue) do
        func()
    end
    wipe(self.combatQueue)
end

-- ============================================================
-- Frame processing
-- ============================================================

function FM:ProcessFrame(frameName)
    if self.frameStates[frameName] and self.frameStates[frameName].hooked then return true end

    local frame = self:ResolveFrame(frameName)
    if not frame then return false end

    if InCombatLockdown() and frame:IsProtected() then
        self:QueueForCombatEnd(function() FM:ProcessFrame(frameName) end)
        return false
    end

    self:MakeMovable(frame, frameName)
    return true
end

function FM:ProcessGlobalFrames()
    local reg = ns.FrameMoverFrames
    if not reg then return end
    for _, entry in ipairs(reg.GLOBAL) do
        if not self:ProcessFrame(entry.name) then
            local name = entry.name
            C_Timer.After(0, function() FM:ProcessFrame(name) end)
        end
    end
end

function FM:ProcessAddonFrames(loadedAddon)
    local reg = ns.FrameMoverFrames
    if not reg then return end
    local list = reg.ADDONS[loadedAddon]
    if not list then return end
    for _, entry in ipairs(list) do
        if not self:ProcessFrame(entry.name) then
            local name = entry.name
            C_Timer.After(0, function() FM:ProcessFrame(name) end)
        end
    end
end

-- ============================================================
-- Initialize / Shutdown
-- ============================================================

function FM:Initialize()
    if self.active then return end
    self.active = true

    CreateRestoreFrame()
    CreateCaptureFrame()

    if not self._eventFrame then
        self._eventFrame = CreateFrame("Frame", "OneWoW_QoL_FM_Events")
    end
    self._eventFrame:RegisterEvent("ADDON_LOADED")
    self._eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    self._eventFrame:SetScript("OnEvent", function(_, event, arg1)
        if event == "ADDON_LOADED" then
            FM:ProcessAddonFrames(arg1)
        elseif event == "PLAYER_REGEN_ENABLED" then
            FM:FlushCombatQueue()
        end
    end)

    self:ProcessGlobalFrames()

    local reg = ns.FrameMoverFrames
    if reg then
        for addonKey in pairs(reg.ADDONS) do
            if C_AddOns and C_AddOns.IsAddOnLoaded(addonKey) then
                self:ProcessAddonFrames(addonKey)
            end
        end
    end
end

function FM:Shutdown()
    self.active = false
    if captureFrame then captureFrame:EnableMouseWheel(false) end
    if self._eventFrame then self._eventFrame:UnregisterAllEvents() end
end
