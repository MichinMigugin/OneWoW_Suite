local _, ns = ...

ns.InteractionTracker = {}
local Module = ns.InteractionTracker

local private = {
    pending = nil,
}

local CLEAR_DELAY = 0.5
local MONEY_WINDOW = 10

local INTERACTION_CATEGORIES = {
    [Enum.PlayerInteractionType.TaxiNode] = {
        category = "taxi",
        source = "Flight Master",
        itemName = "Taxi Fare",
    },
    [Enum.PlayerInteractionType.BarbersChoice] = {
        category = "barber",
        source = "Barber Shop",
        itemName = "Appearance Change",
    },
}

function Module:Initialize()
    if self.initialized then return end
    self.initialized = true

    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
    frame:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")
    frame:RegisterEvent("PLAYER_MONEY")
    frame:SetScript("OnEvent", function(_, event, ...)
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            Module:OnInteractionShow(...)
        elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" then
            Module:OnInteractionHide(...)
        elseif event == "PLAYER_MONEY" then
            Module:OnPlayerMoney()
        end
    end)
end

function Module:OnInteractionShow(interactionType)
    local info = INTERACTION_CATEGORIES[interactionType]
    if not info then return end
    private.pending = {
        category = info.category,
        source = info.source,
        itemName = info.itemName,
        goldBefore = GetMoney(),
        time = GetTime(),
    }
end

function Module:OnInteractionHide(interactionType)
    local info = INTERACTION_CATEGORIES[interactionType]
    if not info then return end
    if private.pending and private.pending.category == info.category then
        -- Delay clear so a money event that fires on close still attributes.
        C_Timer.After(CLEAR_DELAY, function()
            if private.pending and private.pending.category == info.category then
                private.pending = nil
            end
        end)
    end
end

function Module:OnPlayerMoney()
    local pending = private.pending
    if not pending then return end
    if (GetTime() - pending.time) > MONEY_WINDOW then
        private.pending = nil
        return
    end

    local goldAfter = GetMoney()
    local delta = goldAfter - pending.goldBefore
    pending.goldBefore = goldAfter

    if delta == 0 then return end

    local absDelta = math.abs(delta)
    if delta < 0 then
        ns.Transactions:RecordExpense(
            pending.category, absDelta, pending.source, nil, pending.itemName, nil, nil)
    else
        ns.Transactions:RecordIncome(
            pending.category, absDelta, pending.source, nil, pending.itemName, nil, nil)
    end
end
