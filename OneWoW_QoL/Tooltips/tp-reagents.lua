local _, ns = ...

local OneWoW = OneWoW
local PE = OneWoW.PredicateEngine

local floor = math.floor
local format = string.format
local CreateTextureMarkup = CreateTextureMarkup
local GetItemNameByID = C_Item.GetItemNameByID
local GetItemIconByID = C_Item.GetItemIconByID
local GetItemCount = C_Item.GetItemCount
local GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo

local ENOUGH_R, ENOUGH_G, ENOUGH_B = 1, 1, 1
local SHORT_R, SHORT_G, SHORT_B = 1, 0.125, 0.125

local function IconMarkup(icon)
    if not icon then return "" end
    return CreateTextureMarkup(icon, 64, 64, 14, 14, 0.07, 0.93, 0.07, 0.93) .. " "
end

local function ReagentsProvider(_, context)
    if not context.itemID then return nil end

    local reagents = PE:GetCombineReagents(context.itemID)
    if not reagents then return nil end

    local L = ns.L
    local lines = {}
    local maxOutput
    local isMultiple = #reagents > 1

    for _, reagent in ipairs(reagents) do
        local name, count, icon
        if reagent.itemID then
            name = GetItemNameByID(reagent.itemID)
            if not name or name == "" then
                name = tostring(reagent.itemID)
            end
            count = GetItemCount(reagent.itemID, true, false, true, true)
            icon = GetItemIconByID(reagent.itemID)
            if isMultiple and reagent.itemID == context.itemID then
                name = "* " .. name
            end
        elseif reagent.currencyID then
            local currencyInfo = GetCurrencyInfo(reagent.currencyID)
            if currencyInfo then
                name = currencyInfo.name
                count = currencyInfo.quantity
                icon = currencyInfo.iconFileID
            end
        end

        if name then
            local required = reagent.quantityRequired
            local enough = count >= required
            local r = enough and ENOUGH_R or SHORT_R
            local g = enough and ENOUGH_G or SHORT_G
            local b = enough and ENOUGH_B or SHORT_B
            lines[#lines + 1] = {
                type = "double",
                left = "  " .. IconMarkup(icon) .. name,
                right = count .. "/" .. required,
                lr = r, lg = g, lb = b,
                rr = r, rg = g, rb = b,
            }
            if enough then
                local numOutput = floor(count / required)
                if not maxOutput or numOutput < maxOutput then
                    maxOutput = numOutput
                end
            else
                maxOutput = 0
            end
        end
    end

    if #lines == 0 then return nil end

    if maxOutput and maxOutput > 1 then
        lines[#lines + 1] = {
            type = "text",
            text = "  " .. format(L["TIPS_REAGENTS_CAN_CREATE"], maxOutput),
            r = 1, g = 0.82, b = 0,
        }
    end

    return lines
end

OneWoW.TooltipEngine:RegisterProvider({
    id = "reagents",
    order = 22,
    featureId = "reagents",
    tooltipTypes = {"item"},
    callback = ReagentsProvider,
})
