local addonName, ns = ...

ns.TransmogTracker = {}
local Module = ns.TransmogTracker

local private = {
    goldOnOpen = nil,
    waitingForMoney = false,
}

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("TRANSMOGRIFY_OPEN")
    frame:RegisterEvent("VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:SetScript("OnEvent", function(self, event, ...)
        if event == "TRANSMOGRIFY_OPEN" then
            private.goldOnOpen = GetMoney()
            private.waitingForMoney = false
        elseif event == "VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS" then
            private.waitingForMoney = true
            C_Timer.After(0.5, function()
                private.RecordCost()
            end)
        elseif event == "PLAYER_MONEY" then
            if private.waitingForMoney then
                private.RecordCost()
            end
        end
    end)
end

function private.RecordCost()
    if not private.waitingForMoney then return end
    if not private.goldOnOpen then return end

    private.waitingForMoney = false
    local cost = private.goldOnOpen - GetMoney()

    if cost > 0 then
        ns.Transactions:RecordExpense("transmog", cost, "Transmogrifier", nil, "Transmog Applied", nil, nil)
    end

    private.goldOnOpen = GetMoney()
end
