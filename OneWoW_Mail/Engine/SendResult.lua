local _, ns = ...

-- ============================================================================
-- SendResult
-- ============================================================================
-- SendMail is asynchronous: the server acks with MAIL_SEND_SUCCESS or
-- MAIL_FAILED. Waiting on a blind timer reports success for mails that never
-- left. One pending listener at a time — mail sends are strictly sequential
-- (SendQueue serializes its jobs; UI sends are user-paced).
--
-- MAIL_FAILED carries no reason string. The specific text players see
-- top-center (e.g. ERR_MAIL_CANT_SEND_REALM) arrives separately as
-- UI_ERROR_MESSAGE; we stash matching mail errors while a send is pending and
-- pass them through onFail.
-- ============================================================================

ns.SendResult = {}
local SendResult = ns.SendResult

-- Blind timeout: a very laggy ack gets treated as failure (send stops, user
-- retries; worst case a duplicate mail). If reports come in, bump the value —
-- never remove the failure path.
local SEND_ACK_TIMEOUT = 8

-- Whitelist by localized message (not errorType — those IDs shift by patch).
-- Omit non-send strings (ERR_MAIL_SENT, delete/return).
local MAIL_SEND_UI_ERRORS = {
    [ERR_MAIL_ATTACHMENT_EXPIRED] = true,
    [ERR_MAIL_BAG] = true,
    [ERR_MAIL_BOUND_ITEM] = true,
    [ERR_MAIL_CANT_SEND_REALM] = true,
    [ERR_MAIL_CONJURED_ITEM] = true,
    [ERR_MAIL_DATABASE_ERROR] = true,
    [ERR_MAIL_INVALID_ATTACHMENT] = true,
    [ERR_MAIL_INVALID_ATTACHMENT_SLOT] = true,
    [ERR_MAIL_LIMITED_DURATION_ITEM] = true,
    [ERR_MAIL_NOT_FRIEND_OR_GUILD] = true,
    [ERR_MAIL_QUEST_ITEM] = true,
    [ERR_MAIL_REACHED_CAP] = true,
    [ERR_MAIL_RECEPIENT_CANT_RECEIVE_MAIL] = true,
    [ERR_MAIL_TARGET_CANNOT_RECEIVE_MAIL] = true,
    [ERR_MAIL_TARGET_IS_TRIAL] = true,
    [ERR_MAIL_TARGET_NOT_FOUND] = true,
    [ERR_MAIL_TOO_MANY_ATTACHMENTS] = true,
    [ERR_MAIL_TO_SELF] = true,
    [ERR_MAIL_WRAPPED_COD] = true,
}

local pending
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
eventFrame:RegisterEvent("MAIL_FAILED")
eventFrame:RegisterEvent("UI_ERROR_MESSAGE")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "UI_ERROR_MESSAGE" then
        local _, message = ...
        local p = pending
        if p and message and MAIL_SEND_UI_ERRORS[message] then
            p.uiError = message
        end
        return
    end

    local p = pending
    if not p or p.settled then
        return
    end
    p.settled = true

    -- Defer out of the event dispatch: Blizzard runs SendMailFrame_Reset on
    -- MAIL_SEND_SUCCESS, and calling ClearSendMail from inside that handler
    -- re-enters the reset path (stack overflow — see Compose.lua WireEvents).
    -- Fail path uses a second frame so a UI_ERROR_MESSAGE that trails
    -- MAIL_FAILED in the same or next frame is still captured.
    if event == "MAIL_SEND_SUCCESS" then
        C_Timer.After(0, function()
            if pending ~= p then
                return
            end
            pending = nil
            p.onSuccess()
        end)
        return
    end

    C_Timer.After(0, function()
        if pending ~= p then
            return
        end
        C_Timer.After(0, function()
            if pending ~= p then
                return
            end
            pending = nil
            p.onFail("failed", p.uiError)
        end)
    end)
end)

--- Arm a listener for the ack of the next SendMail call; call right before
--- SendMail. Exactly one of onSuccess/onFail fires (deferred out of event
--- dispatch); no ack within SEND_ACK_TIMEOUT counts as failure with
--- reason `"timeout"`. Server rejection is `"failed"`; when Blizzard also
--- emits a mail UI_ERROR_MESSAGE, `uiError` is that already-localized string.
---@param onSuccess fun()
---@param onFail fun(reason: "failed"|"timeout", uiError: string|nil)
function SendResult:Listen(onSuccess, onFail)
    local token = { onSuccess = onSuccess, onFail = onFail, uiError = nil, settled = false }
    pending = token
    C_Timer.After(SEND_ACK_TIMEOUT, function()
        if pending == token then
            pending = nil
            onFail("timeout")
        end
    end)
end

--- Drop the armed listener without firing it (queue teardown / cancel).
function SendResult:Cancel()
    pending = nil
end
