local _, ns = ...
local format = string.format

local OneWoW_GUI = OneWoW_GUI

ns.ItemPrices = ns.ItemPrices or {}
local IP = ns.ItemPrices

local CALLER_ID = "OneWoW"
local Registry = ns.SettingsFeatureRegistry

local function GetValueCfg()
    return Registry:GetFeatureSettings("tooltips", "value")
end

local function GetSharedL()
    return ns.Locale:GetTable("shared")
end

function IP:GetValueCfg()
    return GetValueCfg()
end

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

function IP:BuildAHSourceMenuItems()
    local L = GetSharedL()
    local items = {
        { value = "onewow", text = L["SHARED_AH_SOURCE_ONEWOW"] },
        { value = "auctionator", text = L["SHARED_AH_SOURCE_AUCTIONATOR"] },
        { value = "tsm", text = L["SHARED_AH_SOURCE_TSM"] },
    }
    return items
end

function IP:GetAHSourceLabel(source)
    local L = GetSharedL()
    if source == "auctionator" then
        return L["SHARED_AH_SOURCE_AUCTIONATOR"]
    end
    if source == "tsm" then
        return L["SHARED_AH_SOURCE_TSM"]
    end
    return L["SHARED_AH_SOURCE_ONEWOW"]
end

-- Single source of truth. SetSetting persists the value and fires the registry's
-- Notify, which drives every BindAHSourceWatcher subscriber (AH panel, QoL
-- Tooltips/Value) to re-sync -- so no caller needs an after-hook.
function IP:SetAHPriceSource(value)
    Registry:SetSetting("tooltips", "value", "ahPriceSource", value)
end

-- Live two-way sync for AH source pickers. The setting is the single source of
-- truth; SetSetting already broadcasts via the registry's Notify. Each attached
-- control subscribes while visible and re-applies the current value, so the AH
-- panel and the QoL Tooltips/Value tab update the moment the source changes
-- anywhere -- no window reopen required. Listeners are registered on show and
-- dropped on hide so they never accumulate or touch dead frames.
local sourceWatcherCount = 0
local function BindAHSourceWatcher(frame, refresh)
    sourceWatcherCount = sourceWatcherCount + 1
    local id = "ItemPrices.AHSourceWatcher." .. sourceWatcherCount
    local function listener(_, _, key)
        if key == nil or key == "ahPriceSource" then
            refresh()
        end
    end
    frame:HookScript("OnShow", function()
        Registry:RegisterListener(id, listener)
        refresh()
    end)
    frame:HookScript("OnHide", function()
        Registry:RegisterListener(id, nil)
    end)
    -- Already-visible frames (built shown) miss OnShow; register now for live
    -- changes. Skip the immediate refresh -- the caller has already rendered its
    -- initial state and may not be fully built yet.
    if frame:IsShown() then
        Registry:RegisterListener(id, listener)
    end
end

function IP:AttachAHSourceMenu(btn, opts)
    local options = opts or {}
    OneWoW_GUI:AttachFilterMenu(btn, {
        searchable = false,
        buildItems = function()
            return self:BuildAHSourceMenuItems()
        end,
        onSelect = function(value)
            self:SetAHPriceSource(value)
        end,
        getActiveValue = function()
            local v = GetValueCfg()
            return (v and v.ahPriceSource) or "onewow"
        end,
    })
    if options.onSelect then
        BindAHSourceWatcher(btn, function()
            options.onSelect((GetValueCfg().ahPriceSource) or "onewow")
        end)
    end
end

---@param parent Frame
---@param opts table? yOffset, width, onSelect
---@return table widgets label, dropdown, desc, and bottomY fields
function IP:AttachAHSourceControl(parent, opts)
    local L = GetSharedL()
    local options = opts or {}
    local yOffset = options.yOffset or 0
    local width = options.width or 220

    local label = OneWoW_GUI:CreateFS(parent, 12)
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    label:SetJustifyH("LEFT")
    label:SetText(L["SHARED_AH_SOURCE_LABEL"])
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - label:GetStringHeight() - 4

    local valSettings = GetValueCfg()
    local ahSource = valSettings.ahPriceSource or "onewow"
    local drop, dropText = OneWoW_GUI:CreateDropdown(parent, {
        width = width,
        height = 26,
        text = self:GetAHSourceLabel(ahSource),
    })
    drop:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)

    OneWoW_GUI:AttachFilterMenu(drop, {
        searchable = false,
        buildItems = function()
            return self:BuildAHSourceMenuItems()
        end,
        onSelect = function(value)
            self:SetAHPriceSource(value)
        end,
        getActiveValue = function()
            local v = GetValueCfg()
            return (v and v.ahPriceSource) or "onewow"
        end,
    })

    -- Keep this dropdown's text (and any consumer-supplied onSelect) in step with
    -- the shared setting whenever it changes here or in another window.
    local function applyValue()
        local value = (GetValueCfg().ahPriceSource) or "onewow"
        dropText:SetText(self:GetAHSourceLabel(value))
        if options.onSelect then options.onSelect(value) end
    end
    BindAHSourceWatcher(drop, applyValue)

    yOffset = yOffset - 32

    local desc = OneWoW_GUI:CreateFS(parent, 10)
    desc:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    desc:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetSpacing(2)
    desc:SetText(L["SHARED_AH_SOURCE_DESC"])
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    yOffset = yOffset - desc:GetStringHeight() - 8

    return {
        label = label,
        dropdown = drop,
        desc = desc,
        bottomY = yOffset,
    }
end

function IP:GetUnitAHPriceForSpecies(speciesID, displayName)
    if not speciesID then return nil, nil end
    local v = GetValueCfg()
    local needsLink = v.ahPriceSource == "tsm"
        or (v.ahPriceSource == "auctionator" and C_AddOns.IsAddOnLoaded("Auctionator")
            and Auctionator and Auctionator.API and Auctionator.API.v1)
    if needsLink then
        local nm = displayName or "Pet"
        local link = format("|cffffffff|Hbattlepet:%d:1:3:1:0:0:0:0:0|h[%s]|h|r", speciesID, nm)
        return self:GetUnitAHPrice(82800, link)
    end
    if OneWoW_AltTracker_Auctions_API and OneWoW_AltTracker_Auctions_API.GetPriceForSpecies then
        local row = OneWoW_AltTracker_Auctions_API.GetPriceForSpecies(speciesID)
        if row and row.price and row.price > 0 then
            return row.price, {
                source = "onewow",
                timestamp = row.timestamp,
                dbKey = row.dbKey,
                ageDays = nil,
            }
        end
    end
    return self:GetUnitAHPrice(82800, nil)
end

function IP:GetTSMUnitPriceForSpecies(speciesID, displayName)
    if not speciesID then return nil, nil end
    local nm = displayName or "Pet"
    local link = format("|cffffffff|Hbattlepet:%d:1:3:1:0:0:0:0:0|h[%s]|h|r", speciesID, nm)
    return self:GetTSMUnitPrice(link)
end

-- Same TSM / Auctionator / OneWoW-scan branches as GetUnitAHPrice, without
-- the tooltip Value `showAHValue` gate. Callers that need a number for their
-- own UI (Crafting Orders profit) pass an explicit source.
function IP:GetUnitAHPriceFrom(source, itemID, itemLink)
    source = source or "onewow"

    if source == "tsm" then
        local v = GetValueCfg()
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

    if source == "auctionator" then
        if not (C_AddOns.IsAddOnLoaded("Auctionator")
            and Auctionator and Auctionator.API and Auctionator.API.v1) then
            return nil, nil
        end
        if not itemID and not itemLink then
            return nil, nil
        end
        local api = Auctionator.API.v1
        local ok, p = pcall(function()
            if itemLink then
                return api.GetAuctionPriceByItemLink(CALLER_ID, itemLink)
            end
            return api.GetAuctionPriceByItemID(CALLER_ID, itemID)
        end)
        if ok and type(p) == "number" and p > 0 then
            local ageDays
            local okAge, d = pcall(function()
                if itemLink then
                    return api.GetAuctionAgeByItemLink(CALLER_ID, itemLink)
                end
                return api.GetAuctionAgeByItemID(CALLER_ID, itemID)
            end)
            if okAge and type(d) == "number" then
                ageDays = d
            end
            return p, {
                source = "auctionator",
                ageDays = ageDays,
                timestamp = nil,
            }
        end
        return nil, nil
    end

    if not itemID then return nil, nil end
    if OneWoW_AltTracker_Auctions_API and OneWoW_AltTracker_Auctions_API.GetPrice then
        local row = OneWoW_AltTracker_Auctions_API.GetPrice(itemID, itemLink)
        if row and row.price and row.price > 0 then
            return row.price, {
                source = "onewow",
                timestamp = row.timestamp,
                dbKey = row.dbKey,
                ageDays = nil,
            }
        end
    end
    return nil, nil
end

function IP:GetUnitAHPrice(itemID, itemLink)
    if not itemID then return nil, nil end

    local v = GetValueCfg()
    if v.showAHValue == false then return nil, nil end

    local price, meta = self:GetUnitAHPriceFrom(v.ahPriceSource, itemID, itemLink)
    if price then
        return price, meta
    end
    if v.ahPriceSource == "auctionator" then
        return self:GetUnitAHPriceFrom("onewow", itemID, itemLink)
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
    GetUnitAHPriceFrom = function(source, itemID, itemLink)
        return IP:GetUnitAHPriceFrom(source, itemID, itemLink)
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
    ShouldOfferOneWoWAHScanUI = function()
        return IP:ShouldOfferOneWoWAHScanUI()
    end,
    GetAHSourceLabel = function(source)
        return IP:GetAHSourceLabel(source)
    end,
}
