local _, ns = ...

local E = ns.TrackerEvaluators
local tonumber = tonumber

E.Register("item", function(op)
    local itemID = tonumber(op.itemID)
    local needed = tonumber(op.count) or 1
    if itemID then
        local count = C_Item.GetItemCount(itemID, true) or 0
        return count, needed
    end
end)

E.Register("currency", function(op)
    local currID = tonumber(op.currencyID)
    local needed = tonumber(op.amount) or 0
    if not currID then return end
    local info = C_CurrencyInfo.GetCurrencyInfo(currID)
    if not info then return end
    local current = info.quantity or 0
    if needed == 0 then
        local weekCap = info.maxWeeklyQuantity or 0
        local totalCap = info.maxQuantity or 0
        local dynamicCap = (weekCap > 0) and weekCap or totalCap
        if dynamicCap > 0 then
            return current, dynamicCap
        end
        return current, 0
    end
    return current, needed
end)
