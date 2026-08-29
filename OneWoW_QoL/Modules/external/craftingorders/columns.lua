local _, ns = ...
local M, L = ns.ModuleRegistry:Current()
if not M then return end

local OneWoW_GUI = OneWoW_GUI
local C_AddOns = C_AddOns
local CopyTable = CopyTable

-- ============================================================================
-- Column layout
-- ============================================================================
-- Player-owned overlay columns. Order name stays pinned left. Everything else
-- is a right-packed lane list: show, hide, reorder, resize. Defaults match the
-- original overlay so an empty save looks unchanged.
-- ============================================================================

local SPACING = OneWoW_GUI.Constants.SPACING

local MAX_YOU = 4
local MAX_CUST = 4
local MAX_REWARDS = 4
local MAT_GAP = SPACING.XS
local COL_GAP = SPACING.SM
local COL_PAD = SPACING.SM
local TIME_W = 64
local CART_W = 40
local GOLD_W = 84
local PROFIT_W = 100
local DEFAULT_ROW_H = 60
local SIZE_MIN = 16
local SIZE_MAX = 48

local COLUMN_IDS = { "you", "cart", "customer", "reward", "time", "gold", "profit" }

local COLUMN_META = {
    you = { kind = "icons", sizeKey = "you", maxIcons = MAX_YOU, labelKey = "CRAFTORDERS_COL_YOU", justify = "LEFT" },
    cart = { kind = "cart", width = CART_W, labelKey = "CRAFTORDERS_COL_CART", justify = "CENTER" },
    customer = { kind = "icons", sizeKey = "customer", maxIcons = MAX_CUST, labelKey = "CRAFTORDERS_COL_CUSTOMER", justify = "LEFT" },
    reward = { kind = "icons", sizeKey = "reward", maxIcons = MAX_REWARDS, labelKey = "CRAFTORDERS_COL_REWARD", justify = "LEFT" },
    time = { kind = "text", width = TIME_W, labelKey = nil, justify = "RIGHT" },
    gold = { kind = "text", width = GOLD_W, labelKey = "CRAFTORDERS_COL_GOLD", justify = "RIGHT" },
    profit = { kind = "profit", width = PROFIT_W, labelKey = "CRAFTORDERS_COL_PROFIT", justify = "RIGHT" },
}

local DEFAULT_HIDDEN = { gold = true, profit = true }
local DEFAULT_SIZES = { product = 36, you = 24, customer = 24, reward = 24 }

local function ClusterW(n, size)
    return n * (size + MAT_GAP) - MAT_GAP
end

local function CopyLayoutDefaults()
    return {
        order = CopyTable(COLUMN_IDS),
        hidden = CopyTable(DEFAULT_HIDDEN),
        sizes = CopyTable(DEFAULT_SIZES),
        hideHaveMats = false,
        priceSource = nil,
    }
end

local function ClampSize(n)
    n = tonumber(n) or 24
    if n < SIZE_MIN then return SIZE_MIN end
    if n > SIZE_MAX then return SIZE_MAX end
    return math.floor(n + 0.5)
end

local function KnownId(id)
    return COLUMN_META[id] ~= nil
end

local function MergeLayout(saved)
    local layout = CopyLayoutDefaults()
    if type(saved) ~= "table" then
        return layout
    end
    if type(saved.order) == "table" then
        local seen = {}
        local order = {}
        for i = 1, #saved.order do
            local id = saved.order[i]
            if KnownId(id) and not seen[id] then
                seen[id] = true
                order[#order + 1] = id
            end
        end
        for i = 1, #COLUMN_IDS do
            local id = COLUMN_IDS[i]
            if not seen[id] then
                order[#order + 1] = id
            end
        end
        layout.order = order
    end
    if type(saved.hidden) == "table" then
        for i = 1, #COLUMN_IDS do
            local id = COLUMN_IDS[i]
            if saved.hidden[id] ~= nil then
                layout.hidden[id] = saved.hidden[id] == true
            end
        end
    end
    if type(saved.sizes) == "table" then
        for key in pairs(DEFAULT_SIZES) do
            if saved.sizes[key] ~= nil then
                layout.sizes[key] = ClampSize(saved.sizes[key])
            end
        end
    end
    if saved.hideHaveMats ~= nil then
        layout.hideHaveMats = saved.hideHaveMats == true
    end
    if type(saved.priceSource) == "string" then
        layout.priceSource = saved.priceSource
    end
    return layout
end

function M:EnsureLayout()
    local bucket = ns.ModuleRegistry:GetModuleBucket("craftingorders")
    if type(bucket.layout) ~= "table" or M._layoutObj ~= bucket.layout then
        bucket.layout = MergeLayout(bucket.layout)
        M._layoutObj = bucket.layout
    end
    return bucket.layout
end

function M:GetLayout()
    return M:EnsureLayout()
end

function M:ResetLayout()
    local bucket = ns.ModuleRegistry:GetModuleBucket("craftingorders")
    bucket.layout = CopyLayoutDefaults()
    M._layoutObj = bucket.layout
    M:OnLayoutChanged(true)
end

function M:ColumnIds()
    return COLUMN_IDS
end

function M:ColumnMeta(id)
    return COLUMN_META[id]
end

function M:ColumnLabel(id)
    if id == "time" then
        return CLOSES_IN
    end
    local meta = COLUMN_META[id]
    if meta and meta.labelKey then
        return L[meta.labelKey]
    end
    return id
end

function M:IsColumnVisible(id)
    local layout = M:EnsureLayout()
    return layout.hidden[id] ~= true
end

function M:SetColumnHidden(id, hidden)
    if not KnownId(id) then return end
    local layout = M:EnsureLayout()
    layout.hidden[id] = hidden == true
    M:OnLayoutChanged()
end

function M:SetColumnOrder(order)
    local layout = M:EnsureLayout()
    layout.order = MergeLayout({ order = order, hidden = layout.hidden, sizes = layout.sizes }).order
    M:OnLayoutChanged()
end

function M:SetIconSize(key, value)
    if not DEFAULT_SIZES[key] then return end
    local layout = M:EnsureLayout()
    local nextSize = ClampSize(value)
    if layout.sizes[key] == nextSize then
        return
    end
    layout.sizes[key] = nextSize
    M:OnLayoutChanged()
end

function M:SetHideHaveMats(hidden)
    local layout = M:EnsureLayout()
    layout.hideHaveMats = hidden == true
    M:OnLayoutChanged(true)
end

function M:SetPriceSource(source)
    local layout = M:EnsureLayout()
    layout.priceSource = source
    M:OnLayoutChanged()
end

function M:ClusterWidth(n, size)
    return ClusterW(n, size)
end

function M:LaneConstants()
    return {
        maxYou = MAX_YOU,
        maxCust = MAX_CUST,
        maxRewards = MAX_REWARDS,
        matGap = MAT_GAP,
        colGap = COL_GAP,
        colPad = COL_PAD,
        timeW = TIME_W,
        cartW = CART_W,
        goldW = GOLD_W,
        profitW = PROFIT_W,
        defaultRowH = DEFAULT_ROW_H,
        sizeMin = SIZE_MIN,
        sizeMax = SIZE_MAX,
    }
end

local MIN_NAME_W = 140
-- Keeps header labels readable when a lane holds a single small icon.
local LANE_MIN_W = 50
-- Order-cell chrome inside a row: product icon left inset + icon-to-name gap.
local NAME_LEFT_PAD = 4
local NAME_GAP = 6
local LANE_KEYS = { "you", "customer", "reward" }

--- Icon slots the current entry list actually uses, per lane (1..maxIcons).
--- The overlay reports them after each entry build; nil means no data yet
--- (reserve the full maxIcons). Returns true when widths need re-applying.
function M:SetLaneCounts(counts)
    local prev = M._laneCounts
    if counts == nil then
        M._laneCounts = nil
        return prev ~= nil
    end
    local next = {}
    local changed = prev == nil
    for i = 1, #LANE_KEYS do
        local key = LANE_KEYS[i]
        local n = counts[key] or 1
        if n < 1 then n = 1 end
        local cap = COLUMN_META[key].maxIcons
        if n > cap then n = cap end
        next[key] = n
        if prev and prev[key] ~= n then
            changed = true
        end
    end
    M._laneCounts = next
    return changed
end

local function LaneWidth(id, sizes)
    local meta = COLUMN_META[id]
    if meta.kind == "icons" then
        local count = (M._laneCounts and M._laneCounts[id]) or meta.maxIcons
        local w = ClusterW(count, sizes[meta.sizeKey])
        return w > LANE_MIN_W and w or LANE_MIN_W
    end
    return meta.width
end

local function LaneHeight(id, sizes)
    local meta = COLUMN_META[id]
    if meta.kind == "icons" then
        return sizes[meta.sizeKey]
    end
    if meta.kind == "cart" then
        return 20
    end
    return 16
end

--- Overlay row interior width (overlay width minus list/scroll/row chrome).
--- The overlay owns the frame and reports it here; nil means unknown (no
--- clip budget until the first real measure).
function M:SetRowContentWidth(width)
    if width and width >= 100 then
        M._rowContentW = math.floor(width + 0.5)
    else
        M._rowContentW = nil
    end
end

local function PackWidth(layout, sizes)
    local total = COL_PAD
    for i = 1, #layout.order do
        local id = layout.order[i]
        if layout.hidden[id] ~= true then
            total = total + LaneWidth(id, sizes) + COL_GAP
        end
    end
    return total
end

local function StripFits(layout, sizes, w)
    return PackWidth(layout, sizes)
        + NAME_LEFT_PAD + sizes.product + NAME_GAP + MIN_NAME_W <= w
end

local SIZE_KEYS = { "product", "you", "customer", "reward" }

local function ScaledSizes(base, f)
    local sizes = {}
    for i = 1, #SIZE_KEYS do
        local key = SIZE_KEYS[i]
        local s = math.floor(base[key] * f)
        if s < SIZE_MIN then
            s = SIZE_MIN
        elseif s > base[key] then
            s = base[key]
        end
        sizes[key] = s
    end
    return sizes
end

-- Rendered icon sizes. layout.sizes is the player's slider preference and
-- renders as-is whenever the visible columns fit the row. When they do not
-- (many columns shown, large icons), every icon - lanes and product - scales
-- down by one shared factor, exactly enough to keep every visible column on
-- screen with the order name at MIN_NAME_W. Hidden columns cost nothing
-- (PackWidth skips them). Binary search over the factor handles the
-- per-icon floors; if even SIZE_MIN overflows, the overlay's clip host
-- trims the strip's left edge as a last resort.
function M:IconSizes()
    local layout = M:EnsureLayout()
    local base = layout.sizes
    local w = M._rowContentW
    if not w or StripFits(layout, base, w) then
        return base
    end
    local lo, hi = 0, 1
    local best
    for _ = 1, 12 do
        local mid = (lo + hi) / 2
        local sizes = ScaledSizes(base, mid)
        if StripFits(layout, sizes, w) then
            best = sizes
            lo = mid
        else
            hi = mid
        end
    end
    return best or ScaledSizes(base, 0)
end

--- Max width the right-packed column strip may occupy in a row before it
--- clips: row width minus the product icon and the name column's minimum.
--- nil when the overlay width is not measured yet (no clipping).
function M:LaneStripBudget()
    local w = M._rowContentW
    if not w then
        return nil
    end
    local budget = w - NAME_LEFT_PAD - M:IconSizes().product - NAME_GAP - MIN_NAME_W
    if budget < 1 then
        budget = 1
    end
    return budget
end

function M:ColumnWidth(id)
    return LaneWidth(id, M:IconSizes())
end

function M:ColumnHeight(id)
    return LaneHeight(id, M:IconSizes())
end

function M:ComputeInsets()
    local layout = M:EnsureLayout()
    local sizes = M:IconSizes()
    local right = COL_PAD
    local map = {}
    for i = #layout.order, 1, -1 do
        local id = layout.order[i]
        if layout.hidden[id] ~= true then
            local width = LaneWidth(id, sizes)
            map[id] = {
                right = right,
                width = width,
                height = LaneHeight(id, sizes),
                justify = COLUMN_META[id].justify,
            }
            right = right + width + COL_GAP
        end
    end
    map.orderRight = right
    return map
end

function M:RowHeight()
    local layout = M:EnsureLayout()
    local sizes = M:IconSizes()
    local h = DEFAULT_ROW_H
    local product = sizes.product + 16
    if product > h then
        h = product
    end
    for i = 1, #layout.order do
        local id = layout.order[i]
        if layout.hidden[id] ~= true then
            local laneH = LaneHeight(id, sizes) + 16
            if laneH > h then
                h = laneH
            end
        end
    end
    return h
end

local function AddonEnabled(name)
    if not C_AddOns.DoesAddOnExist(name) then
        return false
    end
    if C_AddOns.IsAddOnLoaded(name) then
        return true
    end
    return C_AddOns.GetAddOnEnableState(name) > Enum.AddOnEnableState.None
end

function M:IsPriceSourceAvailable(source)
    if source == "tsm" then
        return AddonEnabled("TradeSkillMaster")
    end
    if source == "auctionator" then
        return AddonEnabled("Auctionator")
    end
    return source == "onewow"
end

function M:DefaultPriceSource()
    if AddonEnabled("TradeSkillMaster") then
        return "tsm"
    end
    if AddonEnabled("Auctionator") then
        return "auctionator"
    end
    return "onewow"
end

function M:GetPriceSource()
    local src = M:EnsureLayout().priceSource
    if src and M:IsPriceSourceAvailable(src) then
        return src
    end
    return M:DefaultPriceSource()
end

function M:DetectedPriceSources()
    local list = {}
    if AddonEnabled("TradeSkillMaster") then
        list[#list + 1] = "tsm"
    end
    if AddonEnabled("Auctionator") then
        list[#list + 1] = "auctionator"
    end
    list[#list + 1] = "onewow"
    return list
end

function M:PriceSourceIcon(source)
    if source == "tsm" then
        local icon = C_AddOns.GetAddOnMetadata("TradeSkillMaster", "IconTexture")
        if icon and icon ~= "" then
            return icon
        end
        return "Interface\\Icons\\INV_Misc_Coin_02"
    end
    if source == "auctionator" then
        local icon = C_AddOns.GetAddOnMetadata("Auctionator", "IconTexture")
        if icon and icon ~= "" then
            return icon
        end
        return "Interface\\Icons\\INV_Misc_Coin_01"
    end
    -- OneWoW's own addon icon, same as every suite TOC IconTexture.
    return OneWoW_GUI.Constants.FACTION_ICONS.neutral
end

function M:PriceSourceLabel(source)
    local shared = OneWoW.Locale:GetTable("shared")
    if source == "tsm" then
        return shared["SHARED_AH_SOURCE_TSM"]
    end
    if source == "auctionator" then
        return shared["SHARED_AH_SOURCE_AUCTIONATOR"]
    end
    return shared["SHARED_AH_SOURCE_ONEWOW"]
end

function M:FilterYouReagents(list)
    if not M:EnsureLayout().hideHaveMats then
        return list
    end
    local out = {}
    if not list then
        return out
    end
    for i = 1, #list do
        local row = list[i]
        if row.short and row.short > 0 then
            out[#out + 1] = row
        end
    end
    return out
end

function M:ComputeOrderProfit(entry)
    if not entry or entry.kind == "header" then
        return nil
    end
    local source = M:GetPriceSource()
    local prices = OneWoW.ItemPrices
    local profit = (entry.gold or 0) - (entry.consortiumCut or 0)
    local raw = entry.raw
    local rewards = raw and raw.npcOrderRewards
    if rewards then
        for i = 1, #rewards do
            local reward = rewards[i]
            if reward.itemLink or reward.itemID then
                local itemID = reward.itemID
                if not itemID and reward.itemLink then
                    itemID = C_Item.GetItemInfoInstant(reward.itemLink)
                end
                local price = prices:GetUnitAHPriceFrom(source, itemID, reward.itemLink)
                if price then
                    profit = profit + price * (reward.count or 1)
                end
            end
        end
    end
    local you = entry.youReagents
    if you then
        for i = 1, #you do
            local mat = you[i]
            if mat.itemID then
                local link = mat.itemLink or ("item:" .. mat.itemID)
                local price = prices:GetUnitAHPriceFrom(source, mat.itemID, link)
                if price then
                    profit = profit - price * (mat.need or 1)
                end
            end
        end
    end
    return profit
end

--- Geometry changes (sizes, hidden, order) re-apply in place: icons SetSize,
--- lanes re-anchor, the virtualizer refreshes row heights. entriesChanged is
--- for settings that alter the entry list itself (hideHaveMats), which also
--- re-derives lane counts.
function M:OnLayoutChanged(entriesChanged)
    if entriesChanged and M:WantsOverlay() then
        M:RefreshOverlay()
    end
    M:ApplyOverlayLayout()
end
