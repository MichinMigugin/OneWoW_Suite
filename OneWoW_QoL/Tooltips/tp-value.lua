local _, ns = ...
local OneWoW = OneWoW
local format = string.format

local function FormatMoneyLine(copper)
    return OneWoW.Format.FormatGold(copper)
end

local function GetVendorPrice(itemLink, itemID)
    local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemLink or itemID)
    return sellPrice or 0
end

local function FormatAge(timestamp)
    if not timestamp or timestamp == 0 then return nil end
    local age = time() - timestamp
    local L = ns.L
    if age < 3600 then
        return format(L["TIPS_TIME_MINUTES_AGO"], math.floor(age / 60))
    elseif age < 86400 then
        return format(L["TIPS_TIME_HOURS_AGO"], math.floor(age / 3600))
    else
        return format(L["TIPS_TIME_DAYS_AGO"], math.floor(age / 86400))
    end
end

local function FormatAHMeta(meta)
    if not meta then return nil end
    local L = ns.L
    if meta.timestamp then
        return FormatAge(meta.timestamp)
    end
    if meta.ageDays ~= nil then
        return format(L["TIPS_VALUE_AH_AGE_DAYS"], meta.ageDays)
    end
    return nil
end

local function ValueProvider(_, context)
    if not context.itemID then return nil end

    local L   = ns.L
    local cfg = OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "value")

    local showVendorPrice = cfg.showVendorPrice ~= false
    local showAHValue     = cfg.showAHValue     ~= false

    local lines = {}

    if showVendorPrice then
        local sellPrice = GetVendorPrice(context.itemLink, context.itemID)
        if sellPrice and sellPrice > 0 then
            table.insert(lines, {
                type  = "double",
                left  = "  " .. L["TIPS_VALUE_VENDOR_PRICE"],
                right = FormatMoneyLine(sellPrice),
                lr = 0.4, lg = 0.8, lb = 1.0,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
        end
    end

    if showAHValue and OneWoW.ItemPrices then
        local price, meta = OneWoW.ItemPrices:GetUnitAHPrice(context.itemID, context.itemLink)
        if price and price > 0 then
            local ageText = FormatAHMeta(meta)
            local rightText = FormatMoneyLine(price)
            if ageText then
                rightText = rightText .. "  |cFF888888(" .. ageText .. ")|r"
            end
            local leftLabel = L["TIPS_VALUE_AH_PRICE"]
            if meta and meta.source == "auctionator" then
                leftLabel = L["TIPS_VALUE_AH_PRICE_AUCTIONATOR"]
            elseif meta and meta.source == "tsm" then
                leftLabel = L["TIPS_VALUE_AH_PRICE_TSM"]
            end
            table.insert(lines, {
                type  = "double",
                left  = "  " .. leftLabel,
                right = rightText,
                lr = 0.4, lg = 0.8, lb = 1.0,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
        end
    end

    if cfg.showTSMValue == true and OneWoW.ItemPrices and context.itemLink then
        local tsmPrice, srcStr = OneWoW.ItemPrices:GetTSMUnitPrice(context.itemLink)
        if tsmPrice and tsmPrice > 0 then
            local tsmRight = FormatMoneyLine(tsmPrice)
            local leftT = L["TIPS_VALUE_TSM_PRICE"]
            if srcStr and srcStr ~= "" then
                leftT = format(L["TIPS_VALUE_TSM_PRICE_FMT"], srcStr)
            end
            table.insert(lines, {
                type  = "double",
                left  = "  " .. leftT,
                right = tsmRight,
                lr = 0.4, lg = 0.8, lb = 1.0,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
        end
    end

    if #lines == 0 then return nil end
    return lines
end

OneWoW.TooltipEngine:RegisterProvider({
    id           = "value",
    order        = 25,
    featureId    = "value",
    tooltipTypes = {"item"},
    callback     = ValueProvider,
})
