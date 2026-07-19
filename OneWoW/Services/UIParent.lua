local _, ns = ...

-- ============================================================================
-- UIParent
-- ============================================================================
-- Funnel for cinematic / fullscreen overlays that must hide the entire Blizzard
-- UI (`UIParent:Hide()`). Callers must not touch `UIParent` directly — hide and
-- restore through this service so fragile FrameXML indicators can be re-synced
-- when the parent comes back.
--
-- Why a funnel: MiniMapMailFrameMixin:OnHide calls ResetMailIcon() (clears the
-- envelope texture) but has no OnShow restore. Hiding UIParent cascades OnHide
-- to the mail frame; showing UIParent again leaves MailFrame shown with
-- MailIcon still hidden while HasNewMail() remains true. Same trap can hit any
-- future UIParent hide (AFK panel today).
--
-- Usage:
--   OneWoW.UIParent:Hide()     -- enter cinematic (refcount)
--   OneWoW.UIParent:Restore()  -- leave cinematic; re-sync indicators
-- ============================================================================

local UIParentSvc = {}
ns.UIParent = UIParentSvc

local hideDepth = 0
local mailIconHooked = false

--- Blizzard clears MailIcon on OnHide and never restores it on re-show.
---@param mailFrame Frame
local function ResyncMailIcon(mailFrame)
    if not mailFrame.MailIcon then
        return
    end
    mailFrame.MailIcon:SetShown(HasNewMail())
end

--- Hook once so reparent / parent-show paths also restore the envelope.
local function EnsureMailIconHook()
    if mailIconHooked then
        return
    end
    local mailFrame = MinimapCluster
        and MinimapCluster.IndicatorFrame
        and MinimapCluster.IndicatorFrame.MailFrame
    if not mailFrame then
        return
    end
    mailIconHooked = true
    mailFrame:HookScript("OnShow", function(myself)
        ResyncMailIcon(myself)
    end)
end

local function ResyncFragileIndicators()
    EnsureMailIconHook()
    local mailFrame = MinimapCluster
        and MinimapCluster.IndicatorFrame
        and MinimapCluster.IndicatorFrame.MailFrame
    if mailFrame and mailFrame:IsShown() then
        ResyncMailIcon(mailFrame)
    end
end

--- Hide Blizzard UIParent for a cinematic overlay. Nested calls are refcounted.
function UIParentSvc:Hide()
    EnsureMailIconHook()
    hideDepth = hideDepth + 1
    if hideDepth == 1 then
        UIParent:Hide()
    end
end

--- Undo a matching Hide(). When depth reaches zero, show UIParent and re-sync
--- indicators Blizzard leaves stale after the hide cascade (minimap mail icon).
--- Idempotent when nothing is hidden.
function UIParentSvc:Restore()
    if hideDepth == 0 then
        return
    end
    hideDepth = hideDepth - 1
    if hideDepth > 0 then
        return
    end
    UIParent:Show()
    ResyncFragileIndicators()
end

--- True while this service currently owns a UIParent hide (depth > 0).
---@return boolean
function UIParentSvc:IsHidden()
    return hideDepth > 0
end
