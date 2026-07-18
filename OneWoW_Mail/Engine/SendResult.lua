local _, ns = ...

-- ============================================================================
-- SendResult
-- ============================================================================
-- SendMail is asynchronous: the server acks with MAIL_SEND_SUCCESS or
-- MAIL_FAILED. Waiting on a blind timer reports success for mails that never
-- left. One pending listener at a time — mail sends are strictly sequential
-- (SendQueue serializes its jobs; UI sends are user-paced).

ns.SendResult = {}
local SendResult = ns.SendResult

-- Blind timeout: a very laggy ack gets treated as failure (send stops, user
-- retries; worst case a duplicate mail). If reports come in, bump the value —
-- never remove the failure path.
local SEND_ACK_TIMEOUT = 8

local pending
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("MAIL_SEND_SUCCESS")
eventFrame:RegisterEvent("MAIL_FAILED")
eventFrame:SetScript("OnEvent", function(_, event)
    local p = pending
    if not p then
        return
    end
    pending = nil
    -- Defer out of the event dispatch: Blizzard runs SendMailFrame_Reset on
    -- MAIL_SEND_SUCCESS, and calling ClearSendMail from inside that handler
    -- re-enters the reset path (stack overflow — see Compose.lua WireEvents).
    C_Timer.After(0, function()
        if event == "MAIL_SEND_SUCCESS" then
            p.onSuccess()
        else
            p.onFail("failed")
        end
    end)
end)

--- Arm a listener for the ack of the next SendMail call; call right before
--- SendMail. Exactly one of onSuccess/onFail fires (deferred out of event
--- dispatch); no ack within SEND_ACK_TIMEOUT counts as failure with
--- reason `"timeout"`. Server rejection is `"failed"`.
---@param onSuccess fun()
---@param onFail fun(reason: "failed"|"timeout")
function SendResult:Listen(onSuccess, onFail)
    local token = { onSuccess = onSuccess, onFail = onFail }
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
