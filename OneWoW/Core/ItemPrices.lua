local _, OneWoW = ...
local format = string.format

OneWoW.ItemPrices = OneWoW.ItemPrices or {}
local IP = OneWoW.ItemPrices

local CALLER_ID = "OneWoW"

local function GetValueCfg()
    return OneWoW.SettingsFeatureRegistry:GetFeatureSettings("tooltips", "value")
end

function IP:GetValueCfg()
    return GetValueCfg()
end

--- Resolve a TSM custom price for an item, independent of any UI toggle.
--- Used both by the optional TSM tooltip line and the TSM AH price source.
---@param itemLink string|nil
---@param priceStr string|nil TSM custom price string; defaults to "dbmarket"
---@return number|nil price in copper
---@return string|nil priceStr the price string actually used
local function ResolveTSMPrice(itemLink, priceStr)
    if not (itemLink and TSM_API and TSM_API.ToItemString and TSM_API.GetCustomPriceValue) then
        return nil, nil
    end
    priceStr = (type(priceStr) == "string" and priceStr ~= "") and priceStr or "dbmarket"
    local itemString = TSM_API.ToItemString(itemLink)
    if not itemString then return nil, nil end
    local ok, val, err = pcall(function()
        return TSM_API.GetCustomPriceValue(priceStr, itemString)
    end)
    if not ok or err or type(val) ~= "number" or val <= 0 then
        return nil, nil
    end
    return val, priceStr
end

function IP:IsAuctionatorAHSourceActive()
    local v = GetValueCfg()
    return v.ahPriceSource == "auctionator" and C_AddOns.IsAddOnLoaded("Auctionator")
        and Auctionator and Auctionator.API and Auctionator.API.v1
end

function IP:IsTSMAHSourceActive()
    local v = GetValueCfg()
    return v.ahPriceSource == "tsm" and C_AddOns.IsAddOnLoaded("TradeSkillMaster")
        and TSM_API ~= nil
end

function IP:ShouldOfferOneWoWAHScanUI()
    return not self:IsAuctionatorAHSourceActive() and not self:IsTSMAHSourceActive()
end

function IP:GetUnitAHPriceForSpecies(speciesID, displayName)
    if not speciesID then return nil, nil end
    local v = GetValueCfg()
    -- Auctionator and TSM resolve by item link, so build a battlepet link for them.
    local needsLink = v.ahPriceSource == "tsm"
        or (v.ahPriceSource == "auctionator" and C_AddOns.IsAddOnLoaded("Auctionator")
            and Auctionator and Auctionator.API and Auctionator.API.v1)
    if needsLink then
        local nm = displayName or "Pet"
        local link = format("|cffffffff|Hbattlepet:%d:1:3:1:0:0:0:0:0|h[%s]|h|r", speciesID, nm)
        return self:GetUnitAHPrice(82800, link)
    end
    return self:GetUnitAHPrice(82800, nil)
end

function IP:GetTSMUnitPriceForSpecies(speciesID, displayName)
    if not speciesID then return nil, nil end
    local nm = displayName or "Pet"
    local link = format("|cffffffff|Hbattlepet:%d:1:3:1:0:0:0:0:0|h[%s]|h|r", speciesID, nm)
    return self:GetTSMUnitPrice(link)
end

function IP:GetUnitAHPrice(itemID, itemLink)
    if not itemID then return nil, nil end

    local v = GetValueCfg()
    if v.showAHValue == false then return nil, nil end

    if v.ahPriceSource == "tsm" then
        local price, srcStr = ResolveTSMPrice(itemLink, v.tsmPriceString)
        if price and price > 0 then
            return price, {
                source = "tsm",
                priceStr = srcStr,
                ageDays = nil,
                timestamp = nil,
            }
        end
        return nil, nil
    end

    if v.ahPriceSource == "auctionator" and C_AddOns.IsAddOnLoaded("Auctionator")
        and Auctionator and Auctionator.API and Auctionator.API.v1 then
        local api = Auctionator.API.v1
        local price, ageDays
        local ok, p = pcall(function()
            if itemLink then
                return api.GetAuctionPriceByItemLink(CALLER_ID, itemLink)
            end
            return api.GetAuctionPriceByItemID(CALLER_ID, itemID)
        end)
        if ok and type(p) == "number" and p > 0 then
            price = p
            local okAge, d = pcall(function()
                if itemLink then
                    return api.GetAuctionAgeByItemLink(CALLER_ID, itemLink)
                end
                return api.GetAuctionAgeByItemID(CALLER_ID, itemID)
            end)
            if okAge and type(d) == "number" then
                ageDays = d
            end
            return price, {
                source = "auctionator",
                ageDays = ageDays,
                timestamp = nil,
            }
        end
        return nil, nil
    end

    local db = OneWoW_AHPrices
    if not db then return nil, nil end
    local row = db[itemID]
    if row and row.price and row.price > 0 then
        return row.price, {
            source = "onewow",
            timestamp = row.timestamp,
            ageDays = nil,
        }
    end
    return nil, nil
end

function IP:GetTSMUnitPrice(itemLink)
    local v = GetValueCfg()
    if v.showTSMValue ~= true then return nil, nil end
    return ResolveTSMPrice(itemLink, v.tsmPriceString)
end

OneWoW_ItemPricesAPI = {
    GetUnitAHPrice = function(itemID, itemLink)
        return IP:GetUnitAHPrice(itemID, itemLink)
    end,
    GetUnitAHPriceForSpecies = function(speciesID, displayName)
        return IP:GetUnitAHPriceForSpecies(speciesID, displayName)
    end,
    GetTSMUnitPrice = function(itemLink)
        return IP:GetTSMUnitPrice(itemLink)
    end,
    GetTSMUnitPriceForSpecies = function(speciesID, displayName)
        return IP:GetTSMUnitPriceForSpecies(speciesID, displayName)
    end,
    GetValueCfg = function()
        return IP:GetValueCfg()
    end,
    IsAuctionatorAHSourceActive = function()
        return IP:IsAuctionatorAHSourceActive()
    end,
    IsTSMAHSourceActive = function()
        return IP:IsTSMAHSourceActive()
    end,
}
