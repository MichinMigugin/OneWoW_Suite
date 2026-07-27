local _, ns = ...

-- ============================================================================
-- NativeSend
-- ============================================================================
-- Keeps Blizzard's SendMailFrame alive but invisible so bag right-click attach
-- (SetSendMailShowing) and ClickSendMailItemButton / SendMail stay engine-correct
-- while OneWoW Compose chrome owns the visible UI (GoblinMailbox pattern).
-- Holders: "compose" | "sendqueue" | "other" — any holder keeps native send up.
-- ============================================================================

ns.NativeSend = {}
local NativeSend = ns.NativeSend

local MT = ns.MailTrace
local function Trace(event, fields)
    if MT.enabled then
        MT:Record("shell", event, fields)
    end
end

local holders = {}
local active = false

local function ParkSendMailFrame()
    if not SendMailFrame then
        return
    end
    -- Stay under Blizzard MailFrame — never reparent into our shell.
    SendMailFrame:Show()
    SendMailFrame:SetAlpha(0)
    SendMailFrame:EnableMouse(false)
end

local function EnsureActive()
    if active then
        ParkSendMailFrame()
        if SetSendMailShowing then
            SetSendMailShowing(true)
        end
        return
    end
    active = true

    if InboxFrame and InboxFrame:IsShown() then
        InboxFrame:Hide()
    end
    if MailFrame and PanelTemplates_SetTab then
        PanelTemplates_SetTab(MailFrame, 2)
    elseif MailFrameTab2 and MailFrameTab2.Click then
        MailFrameTab2:Click()
    end

    ParkSendMailFrame()
    if SetSendMailShowing then
        SetSendMailShowing(true)
    end
end

local function TearDown()
    if not active then
        return
    end
    active = false

    if SetSendMailShowing then
        SetSendMailShowing(false)
    end
    if SendMailFrame then
        SendMailFrame:SetAlpha(1)
        SendMailFrame:EnableMouse(true)
        SendMailFrame:Hide()
    end
    if InboxFrame and not InboxFrame:IsShown() then
        InboxFrame:Show()
    end
    if MailFrame and PanelTemplates_SetTab then
        PanelTemplates_SetTab(MailFrame, 1)
    end
end

--- Activate native send for a named holder (idempotent per holder).
---@param holder string
function NativeSend:Activate(holder)
    holders[holder] = true
    Trace("nativesend_activate", { holder = holder, wasActive = active })
    EnsureActive()
end

--- Release one holder. Tears down when no holders remain.
---@param holder string
function NativeSend:Deactivate(holder)
    holders[holder] = nil
    Trace("nativesend_deactivate", { holder = holder, remaining = next(holders) and true or false })
    if next(holders) then
        return
    end
    TearDown()
end

--- Drop all holders (mailbox closed / shell hide).
function NativeSend:DeactivateAll()
    Trace("nativesend_deactivate_all", {})
    wipe(holders)
    TearDown()
end

function NativeSend:IsActive()
    return active
end

function NativeSend:HasHolder(holder)
    return holders[holder] == true
end

--- Re-park SendMailFrame while shell owns the mailbox (after Blizzard show flicker).
function NativeSend:ReassertPark()
    if active then
        ParkSendMailFrame()
        if SetSendMailShowing then
            SetSendMailShowing(true)
        end
    end
end
