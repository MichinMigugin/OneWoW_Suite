local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

-- Shared reorder-drag controller.
--
-- Attach this to a list of sibling frames (bag trackers, bag sections, bag
-- categories, etc.) to get left-click-and-drag reordering. The helper handles:
--   * left-button press capture and threshold-gated activation
--   * reparenting the source to UIParent at its current on-screen pixel
--     position (no visual jump on pickup); preserves GetWidth/GetHeight so
--     multi-anchored stretch rows do not collapse during the drag ghost phase
--   * Blizzard StartMoving/StopMovingOrSizing for cursor-follow
--   * drop-target detection via :IsMouseOver() on the live item list, with a
--     fallback to the last hovered sibling (reliable inside scroll views)
--   * while the ghost is on UIParent, the dragged subtree ignores mouse hits so
--     a full-width ghost does not block IsMouseOver / hover on rows beneath
--   * clean restoration of parent / all SetPoint anchors / strata / level / alpha
--   * cancel on UI hide
--
-- Visual styling (hover highlight, pickup border color, alpha, etc.) is
-- delegated to caller-supplied callbacks so this helper stays domain-agnostic.
--
-- Optional drop-indicator: when dropIndicator is supplied, the helper draws a
-- horizontal insert line along the top or bottom edge of the currently hovered
-- item, chosen by cursor Y vs target mid-line. The resulting side is passed to
-- onHover / onReorder as insertBefore (true = drop above target, false = below).
-- Callers can temporarily suppress the line (e.g. to substitute a whole-row
-- glow for header targets) via controller:SetIndicatorVisible(false/true).
--
-- Optional autoScroll: when the list lives inside a ScrollFrame and the cursor
-- nears the top or bottom edge while dragging, the helper scrolls the frame
-- automatically so off-screen rows can become drop targets. Supply either a
-- direct frame reference or a getter for late-bound scroll frames.
--
-- Usage:
--   controller = OneWoW_GUI:CreateReorderDrag({
--       getItems      = function() return list end,                           -- required
--       onReorder     = function(from, to, insertBefore) ... end,             -- required
--       onPickup      = function(item, idx) ... end,                          -- optional
--       onRestore     = function(item, idx) ... end,                          -- optional
--       onHover       = function(item, idx, insertBefore) ... end,            -- optional
--       onUnhover     = function(item, idx) ... end,                          -- optional
--       dropIndicator = { thickness = 2, horizontalPadding = 4,               -- optional
--                         color = { r, g, b, a } },
--       autoScroll    = { frame = scrollFrame,                                -- optional
--                         -- or getFrame = function() return sf end,
--                         edgeZone = 40, maxSpeed = 14, minSpeed = 2 },
--       minDistSq     = 36,
--       strata        = "TOOLTIP",
--       levelBoost    = 50,
--       dragAlpha     = 0.92,
--   })
--   controller:Attach(itemFrame, index)
--   controller:Detach(itemFrame)
--   controller:Cancel()
--   controller:IsActive()
--   controller:SetIndicatorVisible(bool)

local DEFAULT_MIN_DIST_SQ = 36
local DEFAULT_STRATA = "TOOLTIP"
local DEFAULT_LEVEL_BOOST = 50
local DEFAULT_DRAG_ALPHA = 0.92
local DEFAULT_INDICATOR_THICKNESS = 2
local DEFAULT_INDICATOR_PADDING = 4
local DEFAULT_AUTOSCROLL_EDGE = 40
local DEFAULT_AUTOSCROLL_MAX_SPEED = 14
local DEFAULT_AUTOSCROLL_MIN_SPEED = 2
local AUTOSCROLL_TICK_SEC = 1 / 60

local tinsert = table.insert
local floor = math.floor

local function IndexOf(list, item)
    if not list then return nil end
    for i, v in ipairs(list) do
        if v == item then return i end
    end
    return nil
end

local function CaptureAllAnchorPoints(item)
    local pts = {}
    if item.GetNumPoints then
        for i = 1, item:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = item:GetPoint(i)
            tinsert(pts, { point, relativeTo, relativePoint, x, y })
        end
    else
        for i = 1, 32 do
            local point, relativeTo, relativePoint, x, y = item:GetPoint(i)
            if not point then break end
            tinsert(pts, { point, relativeTo, relativePoint, x, y })
        end
    end
    if #pts == 0 then
        local point, relativeTo, relativePoint, x, y = item:GetPoint(1)
        if point then
            tinsert(pts, { point, relativeTo, relativePoint, x, y })
        end
    end
    return pts
end

local function DisableDragGhostMouseHits(root)
    local stack = {}
    local function visit(f)
        for i = 1, select("#", f:GetChildren()) do
            local c = select(i, f:GetChildren())
            if c then visit(c) end
        end
        if f.EnableMouseMotion and f.EnableMouseClick and f.IsMouseMotionEnabled and f.IsMouseClickEnabled then
            tinsert(stack, { f, "s", f:IsMouseMotionEnabled(), f:IsMouseClickEnabled() })
            f:EnableMouseMotion(false)
            f:EnableMouseClick(false)
        elseif f.EnableMouse then
            local was = true
            if f.IsMouseEnabled then was = f:IsMouseEnabled() end
            tinsert(stack, { f, "l", was })
            f:EnableMouse(false)
        end
    end
    visit(root)
    root._oneWoWReorderMouseStack = stack
end

local function RestoreDragGhostMouseHits(root)
    local stack = root._oneWoWReorderMouseStack
    if not stack then return end
    for i = #stack, 1, -1 do
        local e = stack[i]
        local f = e[1]
        if e[2] == "s" then
            if f.EnableMouseMotion then f:EnableMouseMotion(e[3]) end
            if f.EnableMouseClick then f:EnableMouseClick(e[4]) end
        elseif e[2] == "l" then
            f:EnableMouse(e[3])
        end
    end
    root._oneWoWReorderMouseStack = nil
end

local function EnsureIndicator(controller)
    if not controller.dropIndicator then return nil end
    if controller._indicator then return controller._indicator end
    local tex = UIParent:CreateTexture(nil, "OVERLAY", nil, 7)
    local c = controller.dropIndicator.color
    tex:SetColorTexture(c and c[1] or 1, c and c[2] or 1, c and c[3] or 1, c and c[4] or 1)
    tex:Hide()
    controller._indicator = tex
    return tex
end

local function HideIndicator(controller)
    if controller._indicator then
        controller._indicator:Hide()
        controller._indicator:ClearAllPoints()
    end
end

local function PositionIndicator(controller, target, insertBefore)
    local tex = EnsureIndicator(controller)
    if not tex or not target then return end
    if controller._indicatorSuppressed then
        tex:Hide()
        return
    end
    local cfg = controller.dropIndicator
    local hPad = cfg.horizontalPadding or DEFAULT_INDICATOR_PADDING
    local thickness = cfg.thickness or DEFAULT_INDICATOR_THICKNESS
    local halfT = floor(thickness / 2)
    tex:SetParent(target:GetParent() or UIParent)
    tex:SetDrawLayer("OVERLAY", 7)
    tex:ClearAllPoints()
    if insertBefore then
        tex:SetPoint("TOPLEFT",  target, "TOPLEFT",  hPad, halfT)
        tex:SetPoint("TOPRIGHT", target, "TOPRIGHT", -hPad, halfT)
    else
        tex:SetPoint("BOTTOMLEFT",  target, "BOTTOMLEFT",  hPad, -halfT)
        tex:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", -hPad, -halfT)
    end
    tex:SetHeight(thickness)
    tex:Show()
end

local function ResolveAutoScrollFrame(controller)
    local as = controller.autoScroll
    if not as then return nil end
    local f = as.frame
    if not f and as.getFrame then f = as.getFrame() end
    if not f or not f.GetVerticalScroll or not f.SetVerticalScroll then return nil end
    return f
end

local function UpdateAutoScroll(controller, elapsed)
    local as = controller.autoScroll
    if not as then return end
    local frame = ResolveAutoScrollFrame(controller)
    if not frame then return end
    local top, bottom = frame:GetTop(), frame:GetBottom()
    if not top or not bottom then return end
    local height = top - bottom
    if height <= 0 then return end

    local edgeZone = as.edgeZone or DEFAULT_AUTOSCROLL_EDGE
    if edgeZone * 2 > height then edgeZone = height / 2 end
    if edgeZone < 1 then return end

    local _, cursorY = GetCursorPosition()
    local scale = frame:GetEffectiveScale()
    if scale and scale > 0 then cursorY = cursorY / scale end

    local direction, depth
    if cursorY > top - edgeZone then
        direction = -1
        depth = top - cursorY
    elseif cursorY < bottom + edgeZone then
        direction = 1
        depth = cursorY - bottom
    end
    if not direction then return end
    if depth < 0 then depth = 0 end
    if depth > edgeZone then depth = edgeZone end

    local maxSpeed = as.maxSpeed or DEFAULT_AUTOSCROLL_MAX_SPEED
    local minSpeed = as.minSpeed or DEFAULT_AUTOSCROLL_MIN_SPEED
    local ratio = 1 - (depth / edgeZone)
    local pxPerTick = minSpeed + (maxSpeed - minSpeed) * ratio

    local step = pxPerTick * ((elapsed or 0) / AUTOSCROLL_TICK_SEC)
    if step <= 0 then return end

    local current = frame:GetVerticalScroll() or 0
    local maxScroll = (frame.GetVerticalScrollRange and frame:GetVerticalScrollRange()) or 0
    local target = current + direction * step
    if target < 0 then target = 0 end
    if target > maxScroll then target = maxScroll end
    if target ~= current then
        frame:SetVerticalScroll(target)
    end
end

local function ComputeInsertBefore(target)
    if not target or not target.GetTop or not target.GetBottom then return true end
    local top, bottom = target:GetTop(), target:GetBottom()
    if not top or not bottom then return true end
    local midY = (top + bottom) / 2
    local _, cursorY = GetCursorPosition()
    local scale = target:GetEffectiveScale()
    if scale and scale > 0 then
        cursorY = cursorY / scale
    end
    return cursorY >= midY
end

local function ApplyPickupVisual(controller, item)
    if not item or item._oneWoWReorderOrigPoints then return end
    item._oneWoWReorderOrigParent = item:GetParent()
    item._oneWoWReorderOrigPoints = CaptureAllAnchorPoints(item)
    item._oneWoWReorderOrigLevel  = item:GetFrameLevel()
    item._oneWoWReorderOrigStrata = item:GetFrameStrata()
    item._oneWoWReorderOrigAlpha  = item:GetAlpha()

    local pickupW = item:GetWidth()
    local pickupH = item:GetHeight()
    local scale = item:GetEffectiveScale()
    local left = item:GetLeft() and item:GetLeft() * scale or 0
    local bottom = item:GetBottom() and item:GetBottom() * scale or 0
    local uiScale = UIParent:GetEffectiveScale()

    item:SetParent(UIParent)
    item:ClearAllPoints()
    item:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left / uiScale, bottom / uiScale)
    if pickupW and pickupW > 1 then
        item:SetWidth(pickupW)
    end
    if pickupH and pickupH > 1 then
        item:SetHeight(pickupH)
    end

    item:SetFrameStrata(controller.strata)
    item:SetFrameLevel(controller.levelBoost)
    item:SetAlpha(controller.dragAlpha)

    item:SetMovable(true)
    item:SetClampedToScreen(true)
    item:StartMoving()
    DisableDragGhostMouseHits(item)
end

local function RestorePickupVisual(item)
    if not item or not item._oneWoWReorderOrigPoints then return end
    item:StopMovingOrSizing()
    item:SetMovable(false)
    RestoreDragGhostMouseHits(item)
    item:SetFrameStrata(item._oneWoWReorderOrigStrata)
    item:SetParent(item._oneWoWReorderOrigParent)
    item:ClearAllPoints()
    for _, a in ipairs(item._oneWoWReorderOrigPoints) do
        local point, relativeTo, relativePoint, x, y = a[1], a[2], a[3], a[4], a[5]
        if point and relativeTo then
            item:SetPoint(point, relativeTo, relativePoint or point, x or 0, y or 0)
        end
    end
    item:SetFrameLevel(item._oneWoWReorderOrigLevel)
    item:SetAlpha(item._oneWoWReorderOrigAlpha or 1)
    item._oneWoWReorderOrigParent = nil
    item._oneWoWReorderOrigPoints = nil
    item._oneWoWReorderOrigLevel  = nil
    item._oneWoWReorderOrigStrata = nil
    item._oneWoWReorderOrigAlpha  = nil
end

local function ClearHover(controller)
    local hover = controller._state.hoverItem
    if not hover then return end
    if controller.onUnhover then
        local list = controller.getItems and controller.getItems()
        controller.onUnhover(hover, IndexOf(list, hover))
    end
    controller._state.hoverItem = nil
end

local function FinishDrag(controller, forceCancel)
    local st = controller._state
    local wasActive = st.active
    local fromIdx = st.fromIndex
    local sourceItem = st.sourceItem
    local hoverDrop = st.hoverItem
    local insertBefore = st.insertBefore

    controller._watch:Hide()
    controller._watch:SetScript("OnUpdate", nil)

    ClearHover(controller)
    HideIndicator(controller)

    if sourceItem then
        if st.pickupApplied then
            RestorePickupVisual(sourceItem)
        end
        if controller.onRestore then
            local list = controller.getItems and controller.getItems()
            controller.onRestore(sourceItem, IndexOf(list, sourceItem))
        end
    end

    if not forceCancel and wasActive and sourceItem then
        local list = controller.getItems and controller.getItems()
        if list then
            local fromIdxCurrent = IndexOf(list, sourceItem) or fromIdx
            local dropIdx
            local dropItem
            for idx, item in ipairs(list) do
                if item ~= sourceItem and item.IsMouseOver and item:IsMouseOver() then
                    dropIdx = idx
                    dropItem = item
                    break
                end
            end
            if not dropIdx and hoverDrop and hoverDrop ~= sourceItem then
                dropIdx = IndexOf(list, hoverDrop)
                dropItem = hoverDrop
            end
            if dropIdx and fromIdxCurrent and dropIdx ~= fromIdxCurrent and controller.onReorder then
                local finalInsertBefore = insertBefore
                if dropItem and dropItem ~= hoverDrop then
                    finalInsertBefore = ComputeInsertBefore(dropItem)
                end
                if finalInsertBefore == nil then
                    finalInsertBefore = true
                end
                controller.onReorder(fromIdxCurrent, dropIdx, finalInsertBefore)
            end
        end
    end

    if GameTooltip then GameTooltip:Hide() end

    st.fromIndex       = nil
    st.active          = false
    st.pickupApplied   = false
    st.startX          = 0
    st.startY          = 0
    st.sourceItem      = nil
    st.insertBefore    = nil
end

local function OnUpdate(controller, elapsed)
    local st = controller._state
    if not st.fromIndex then
        controller._watch:Hide()
        controller._watch:SetScript("OnUpdate", nil)
        return
    end

    if not IsMouseButtonDown("LeftButton") then
        FinishDrag(controller, false)
        return
    end

    if st.active then
        UpdateAutoScroll(controller, elapsed)
    end

    if not st.active then
        local x, y = GetCursorPosition()
        local dx = x - st.startX
        local dy = y - st.startY
        if dx * dx + dy * dy >= controller.minDistSq then
            st.active = true
            if st.sourceItem and not st.pickupApplied then
                st.pickupApplied = true
                ApplyPickupVisual(controller, st.sourceItem)
                if controller.onPickup then
                    local list = controller.getItems and controller.getItems()
                    controller.onPickup(st.sourceItem, IndexOf(list, st.sourceItem))
                end
            end
            if GameTooltip then GameTooltip:Hide() end
        end
    end

    if not st.active then return end

    local list = controller.getItems and controller.getItems()
    local newHover
    if list then
        for _, item in ipairs(list) do
            if item ~= st.sourceItem and item.IsMouseOver and item:IsMouseOver() then
                newHover = item
                break
            end
        end
    end

    if newHover then
        local insertBefore = ComputeInsertBefore(newHover)
        if newHover ~= st.hoverItem then
            ClearHover(controller)
            st.hoverItem = newHover
            st.insertBefore = insertBefore
            if controller.onHover then
                controller.onHover(newHover, IndexOf(list, newHover), insertBefore)
            end
            PositionIndicator(controller, newHover, insertBefore)
        elseif insertBefore ~= st.insertBefore then
            st.insertBefore = insertBefore
            if controller.onHover then
                controller.onHover(newHover, IndexOf(list, newHover), insertBefore)
            end
            PositionIndicator(controller, newHover, insertBefore)
        end
    elseif st.hoverItem then
        ClearHover(controller)
        st.insertBefore = nil
        HideIndicator(controller)
    end
end

local function BeginDrag(controller, item, index)
    if controller._state.fromIndex then return end
    local st = controller._state
    st.fromIndex     = index
    st.active        = false
    st.pickupApplied = false
    st.startX, st.startY = GetCursorPosition()
    st.sourceItem    = item
    controller._watch:SetScript("OnUpdate", function(_, elapsed) OnUpdate(controller, elapsed) end)
    controller._watch:Show()
end

local ControllerMethods = {}

function ControllerMethods:Attach(item, index)
    if not item then return end
    item:EnableMouse(true)
    local controller = self
    item._oneWoWReorderOnMouseDown = function(self, button)
        if button ~= "LeftButton" then return end
        local list = controller.getItems and controller.getItems()
        local idx = index or IndexOf(list, self)
        if not idx then return end
        BeginDrag(controller, self, idx)
    end
    item:HookScript("OnMouseDown", item._oneWoWReorderOnMouseDown)
end

function ControllerMethods:Detach(item)
    if not item then return end
    if self._state.sourceItem == item then
        FinishDrag(self, true)
    end
    item._oneWoWReorderOnMouseDown = nil
end

function ControllerMethods:Cancel()
    FinishDrag(self, true)
end

function ControllerMethods:IsActive()
    return self._state.active == true
end

function ControllerMethods:SetIndicatorVisible(visible)
    self._indicatorSuppressed = not visible
    if not self._indicator then return end
    if not visible then
        self._indicator:Hide()
    elseif self._state.hoverItem and self._state.insertBefore ~= nil then
        PositionIndicator(self, self._state.hoverItem, self._state.insertBefore)
    end
end

function OneWoW_GUI:CreateReorderDrag(options)
    assert(options and options.getItems and options.onReorder,
        "OneWoW_GUI:CreateReorderDrag requires getItems and onReorder callbacks")

    local controller = {
        getItems      = options.getItems,
        onReorder     = options.onReorder,
        onPickup      = options.onPickup,
        onRestore     = options.onRestore,
        onHover       = options.onHover,
        onUnhover     = options.onUnhover,
        dropIndicator = options.dropIndicator,
        autoScroll    = options.autoScroll,
        minDistSq     = options.minDistSq  or DEFAULT_MIN_DIST_SQ,
        strata        = options.strata     or DEFAULT_STRATA,
        levelBoost    = options.levelBoost or DEFAULT_LEVEL_BOOST,
        dragAlpha     = options.dragAlpha  or DEFAULT_DRAG_ALPHA,
        _watch        = CreateFrame("Frame", nil, UIParent),
        _state        = {
            fromIndex     = nil,
            active        = false,
            pickupApplied = false,
            startX        = 0,
            startY        = 0,
            sourceItem    = nil,
            hoverItem     = nil,
            insertBefore  = nil,
        },
    }
    controller._watch:Hide()

    for name, fn in pairs(ControllerMethods) do
        controller[name] = fn
    end

    return controller
end
