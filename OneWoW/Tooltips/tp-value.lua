local ADDON_NAME, OneWoW = ...

local function GetVendorPrice(itemLink, itemID)
    local _, _, _, _, _, _, _, _, _, _, sellPrice = C_Item.GetItemInfo(itemLink or itemID)
    return sellPrice or 0
end

local function GetAHPrice(itemID)
    local db = _G.OneWoW_AHPrices
    if not db then return nil end
    return db[itemID]
end

local function FormatAge(timestamp)
    if not timestamp or timestamp == 0 then return nil end
    local age = time() - timestamp
    if age < 3600 then
        return math.floor(age / 60) .. "m ago"
    elseif age < 86400 then
        return math.floor(age / 3600) .. "h ago"
    else
        return math.floor(age / 86400) .. "d ago"
    end
end

local function ValueProvider(tooltip, context)
    if not context.itemID then return nil end

    local L   = OneWoW.L
    local db  = OneWoW.db and OneWoW.db.global and OneWoW.db.global.settings
    local cfg = db and db.tooltips and db.tooltips.value or {}

    local showVendorPrice = cfg.showVendorPrice ~= false
    local showAHValue     = cfg.showAHValue     ~= false

    local lines = {}

    if showVendorPrice then
        local sellPrice = GetVendorPrice(context.itemLink, context.itemID)
        if sellPrice and sellPrice > 0 then
            table.insert(lines, {
                type  = "double",
                left  = "  " .. L["TIPS_VALUE_VENDOR_PRICE"],
                right = GetCoinTextureString(sellPrice),
                lr = 0.4, lg = 0.8, lb = 1.0,
                rr = 1.0, rg = 1.0, rb = 1.0,
            })
        end
    end

    if showAHValue and C_AddOns.IsAddOnLoaded("OneWoW_AltTracker_Auctions") then
        local ahData = GetAHPrice(context.itemID)
        if ahData and ahData.price and ahData.price > 0 then
            local ageText = FormatAge(ahData.timestamp)
            local rightText = GetCoinTextureString(ahData.price)
            if ageText then
                rightText = rightText .. "  |cFF888888(" .. ageText .. ")|r"
            end
            table.insert(lines, {
                type  = "double",
                left  = "  " .. L["TIPS_VALUE_AH_PRICE"],
                right = rightText,
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
