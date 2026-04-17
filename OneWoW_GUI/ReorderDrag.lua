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
-- Usage:
--   controller = OneWoW_GUI:CreateReorderDrag({
--       getItems   = function() return list end,       -- required
--       onReorder  = function(from, to) ... end,       -- required
--       onPickup   = function(item, idx) ... end,      -- optional
--       onRestore  = function(item, idx) ... end,      -- optional
--       onHover    = function(item, idx) ... end,      -- optional
--       onUnhover  = function(item, idx) ... end,      -- optional
--       minDistSq  = 36,
--       strata     = "TOOLTIP",
--       levelBoost = 50,
--       dragAlpha  = 0.92,
--   })
--   controller:Attach(itemFrame, index)
--   controller:Detach(itemFrame)
--   controller:Cancel()
--   controller:IsActive()

local DEFAULT_MIN_DIST_SQ = 36
local DEFAULT_STRATA = "TOOLTIP"
local DEFAULT_LEVEL_BOOST = 50
local DEFAULT_DRAG_ALPHA = 0.92

local tinsert = table.insert

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

    controller._watch:Hide()
    controller._watch:SetScript("OnUpdate", nil)

    ClearHover(controller)

    if sourceItem then
        if st.pickupApplied then
            RestorePickupVisual(sourceItem)
        end
        if controller.onRestore then
            local list = controller.getItems and controller.getItems()
            controller.onRestore(sourceItem, IndexOf(list, sourceItem))
        end
    end

    if not forceCancel and wasActive and fromIdx then
        local list = controller.getItems and controller.getItems()
        if list then
            local dropIdx
            for idx, item in ipairs(list) do
                if item ~= sourceItem and item.IsMouseOver and item:IsMouseOver() then
                    dropIdx = idx
                    break
                end
            end
            if not dropIdx and hoverDrop and hoverDrop ~= sourceItem then
                dropIdx = IndexOf(list, hoverDrop)
            end
            if dropIdx and dropIdx ~= fromIdx and controller.onReorder then
                controller.onReorder(fromIdx, dropIdx)
            end
        end
    end

    if GameTooltip then GameTooltip:Hide() end

    st.fromIndex      = nil
    st.active         = false
    st.pickupApplied  = false
    st.startX         = 0
    st.startY         = 0
    st.sourceItem     = nil
end

local function OnUpdate(controller)
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

    if newHover ~= st.hoverItem then
        ClearHover(controller)
        st.hoverItem = newHover
        if newHover and controller.onHover then
            controller.onHover(newHover, IndexOf(list, newHover))
        end
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
    controller._watch:SetScript("OnUpdate", function() OnUpdate(controller) end)
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

function OneWoW_GUI:CreateReorderDrag(options)
    assert(options and options.getItems and options.onReorder,
        "OneWoW_GUI:CreateReorderDrag requires getItems and onReorder callbacks")

    local controller = {
        getItems   = options.getItems,
        onReorder  = options.onReorder,
        onPickup   = options.onPickup,
        onRestore  = options.onRestore,
        onHover    = options.onHover,
        onUnhover  = options.onUnhover,
        minDistSq  = options.minDistSq  or DEFAULT_MIN_DIST_SQ,
        strata     = options.strata     or DEFAULT_STRATA,
        levelBoost = options.levelBoost or DEFAULT_LEVEL_BOOST,
        dragAlpha  = options.dragAlpha  or DEFAULT_DRAG_ALPHA,
        _watch     = CreateFrame("Frame", nil, UIParent),
        _state     = {
            fromIndex     = nil,
            active        = false,
            pickupApplied = false,
            startX        = 0,
            startY        = 0,
            sourceItem    = nil,
            hoverItem     = nil,
        },
    }
    controller._watch:Hide()

    for name, fn in pairs(ControllerMethods) do
        controller[name] = fn
    end

    return controller
end
