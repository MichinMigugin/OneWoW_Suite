local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local Inventory = OneWoW.Inventory

local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local tinsert, sort, math_max = table.insert, table.sort, math.max
local format = string.format
local pcall = pcall

local API = OneWoW_ItemPricesAPI

ns.TrackerFarmValue = ns.TrackerFarmValue or {}
local TFV = ns.TrackerFarmValue

local ROW_H = 30
local PIN_HEADER_H = 22

local INVENTORY_OWNER = "Trackers_FarmValue"
local inventoryArmed = false
local pinnedBagRefreshHosts = {}
local bagDelayedDetailFn = nil

local function EnsureInventoryDelayed()
    if inventoryArmed then return end
    inventoryArmed = true
    Inventory.RegisterDelayedCallback(INVENTORY_OWNER, function()
        for hostFrame in pairs(pinnedBagRefreshHosts) do
            if hostFrame.Refresh then
                hostFrame:Refresh()
            end
        end
        if bagDelayedDetailFn then
            bagDelayedDetailFn()
        end
    end)
end

local function ItemSetFromList(list)
    local s = {}
    for _, id in ipairs(list or {}) do
        if type(id) == "number" and id > 0 then
            s[id] = true
        end
    end
    return s
end

local function LastPlayerBagIndex()
    local first = BACKPACK_CONTAINER or 0
    local n = NUM_BAG_SLOTS or 4
    local last = first + n
    if last < 5 then
        last = 5
    end
    return first, last
end

local function IsBagSlotUnboundTradeable(bag, slot, info)
    if not info or not info.itemID or info.itemID < 1 then return false end
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if loc and loc:IsValid() then
        local ok, bound = pcall(C_Item.IsBound, loc)
        if ok and bound then
            return false
        end
    elseif info.isBound == true then
        return false
    end
    return true
end

local function CollectBagCounts(watchSet)
    local counts = {}
    local first, last = LastPlayerBagIndex()
    for bag = first, last do
        local num = C_Container.GetContainerNumSlots(bag)
        if num and num > 0 then
            for slot = 1, num do
                local info = C_Container.GetContainerItemInfo(bag, slot)
                if info and info.itemID and info.itemID > 0 and IsBagSlotUnboundTradeable(bag, slot, info) then
                    local stack = info.stackCount
                    if not stack or stack < 1 then
                        stack = 1
                    end
                    local id = info.itemID
                    if not watchSet or watchSet[id] then
                        counts[id] = (counts[id] or 0) + stack
                    end
                end
            end
        end
    end
    return counts
end

function TFV:GetFarmPanel(list)
    if not list then return nil end
    if type(list.farmPanel) ~= "table" then
        list.farmPanel = { mode = "watchlist", items = {} }
    end
    if type(list.farmPanel.items) ~= "table" then
        list.farmPanel.items = {}
    end
    if list.farmPanel.mode ~= "allbags" and list.farmPanel.mode ~= "watchlist" then
        list.farmPanel.mode = "watchlist"
    end
    if list.farmPanel.showPinnedHeaders == nil then
        list.farmPanel.showPinnedHeaders = false
    end
    if list.farmPanel.useSessionDelta == nil then
        list.farmPanel.useSessionDelta = false
    end
    if not list.farmPanel.useSessionDelta then
        list.farmPanel.sessionBaseline = nil
    elseif type(list.farmPanel.sessionBaseline) ~= "table" then
        list.farmPanel.sessionBaseline = {}
    end
    return list.farmPanel
end

local function BuildSortedIdsAndRawCounts(fp)
    local watchSet = ItemSetFromList(fp.items)
    local raw = CollectBagCounts(fp.mode == "allbags" and nil or watchSet)
    local ids = {}
    if fp.mode == "allbags" then
        for id in pairs(raw) do tinsert(ids, id) end
    else
        for _, id in ipairs(fp.items) do
            tinsert(ids, id)
        end
    end
    sort(ids)
    return ids, raw
end

function TFV:GetSortedIdsAndCounts(list)
    local fp = self:GetFarmPanel(list)
    if not fp then return {}, {} end
    local ids, raw = BuildSortedIdsAndRawCounts(fp)
    local display = {}
    for _, id in ipairs(ids) do
        local r = raw[id] or 0
        if fp.useSessionDelta and type(fp.sessionBaseline) == "table" then
            local b = fp.sessionBaseline[id] or 0
            display[id] = math_max(0, r - b)
        else
            display[id] = r
        end
    end
    return ids, display
end

function TFV:TakeSessionSnapshot(list)
    local fp = self:GetFarmPanel(list)
    if not fp then return end
    local _, raw = BuildSortedIdsAndRawCounts(fp)
    fp.sessionBaseline = {}
    if fp.mode == "allbags" then
        for id, n in pairs(raw) do
            fp.sessionBaseline[id] = n
        end
    else
        for _, id in ipairs(fp.items) do
            fp.sessionBaseline[id] = raw[id] or 0
        end
    end
    fp.useSessionDelta = true
end

function TFV:ClearSessionSnapshot(list)
    local fp = self:GetFarmPanel(list)
    if not fp then return end
    fp.useSessionDelta = false
    fp.sessionBaseline = nil
end

function TFV.ResolveItemIDFromCursor()
    local ctype, a, b = GetCursorInfo()
    if ctype ~= "item" then return nil end
    if type(a) == "number" and a > 0 then
        return a
    end
    local link = (type(a) == "string" and a:find("|H")) and a or (type(b) == "string" and b:find("|H") and b or nil)
    if link then
        local id = C_Item.GetItemInfoInstant(link)
        if type(id) == "number" and id > 0 then return id end
    end
    if a then
        local ok, id = pcall(C_Item.GetItemID, a)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    if b then
        local ok, id = pcall(C_Item.GetItemID, b)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    return nil
end

function TFV:TryAddItemFromCursor(list, fp, onAdded)
    if not list or not fp then return end
    local id = TFV.ResolveItemIDFromCursor()
    if not id then return end
    ClearCursor()
    local set = ItemSetFromList(fp.items)
    if set[id] then return end
    tinsert(fp.items, id)
    if onAdded then onAdded() end
end

function TFV:RemoveItemFromFarmWatchlist(list, itemID)
    local fp = self:GetFarmPanel(list)
    if not fp or fp.mode ~= "watchlist" or not itemID then return false end
    local removed = false
    for i = #fp.items, 1, -1 do
        if fp.items[i] == itemID then
            table.remove(fp.items, i)
            removed = true
        end
    end
    return removed
end

local function RefreshAllFarmWindows()
    if ns.TrackerEngine and ns.TrackerEngine.RefreshAllPinnedWindows then
        ns.TrackerEngine:RefreshAllPinnedWindows()
    end
end

local function ConfigureFarmRowFontStrings(row)
    for _, fs in ipairs({ row.name, row.qty, row.unit, row.tot }) do
        if fs and fs.SetWordWrap then
            fs:SetWordWrap(false)
        end
    end
end

local function LayoutFarmRow(row, id, qty, showValueColumns)
    local name, link, quality, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
    row.itemID = id
    if icon then row.icon:SetTexture(icon) else row.icon:SetTexture(134400) end
    row.name:SetText(name or ("#" .. tostring(id)))
    if quality and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        row.name:SetTextColor(c.r, c.g, c.b)
    else
        row.name:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    end
    row.qty:SetText(tostring(qty))
    row.qty:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    if not showValueColumns then
        row.unit:Hide()
        row.tot:Hide()
        return
    end
    row.unit:Show()
    row.tot:Show()

    local ow = OneWoW
    local unitAH, unitTSM = 0, 0
    if API then
        unitAH = select(1, API.GetUnitAHPrice(id, link)) or 0
        if link and API.GetTSMUnitPrice then
            unitTSM = select(1, API.GetTSMUnitPrice(link)) or 0
        end
    end
    local valCfg = ow and ow.ItemPrices and ow.ItemPrices:GetValueCfg()
    local unit = 0
    if valCfg and valCfg.showTSMValue == true and unitTSM > 0 then
        unit = unitTSM
    elseif valCfg and valCfg.showAHValue ~= false and unitAH > 0 then
        unit = unitAH
    end
    if unit > 0 then
        row.unit:SetText(OneWoW.Format.FormatGold(unit))
        row.tot:SetText(OneWoW.Format.FormatGold(unit * qty))
        row.unit:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        row.tot:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        row.unit:SetText("-")
        row.tot:SetText("-")
        row.unit:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row.tot:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

local COL_PAD = 4
local COL_GAP = 3
local COL_TOT_W = 92
local COL_UNIT_W = 72
local COL_QTY_W = 36
local COL_ICON_W = 22
-- CreateScrollFrame default inset and CreateEntryList row inset. Header
-- columns on the detail editor sit on the list frame, so they need the
-- same left/right shift as the rows inside the scroll child.
local LIST_SCROLL_INSET = 8
local LIST_ROW_INSET = 10

local function RemoveColumnReserve()
    return OneWoW_GUI.Constants.GUI.ENTRY_LIST_ICON_SIZE + COL_GAP
end

local function DetailListHeaderInsets()
    local gutter = OneWoW_GUI.Constants.GUI.SCROLLBAR_CONTENT_GUTTER
    return LIST_SCROLL_INSET + LIST_ROW_INSET,
        LIST_SCROLL_INSET + gutter + LIST_ROW_INSET
end

--- Qty / Unit / Stack chain used by both header labels and row values.
local function LayoutFarmValueColumns(host, cols, opts)
    opts = opts or {}
    local pad, gap = COL_PAD, COL_GAP
    local leftInset = opts.leftInset or 0
    local rightInset = opts.rightInset or 0
    local reserve = opts.hasRemove and RemoveColumnReserve() or 0

    if cols.removeBtn then
        cols.removeBtn:ClearAllPoints()
        cols.removeBtn:SetPoint("RIGHT", host, "RIGHT", -(pad + rightInset), 0)
    end

    cols.tot:ClearAllPoints()
    cols.tot:SetPoint("RIGHT", host, "RIGHT", -(pad + reserve + rightInset), 0)
    cols.tot:SetWidth(COL_TOT_W)
    cols.tot:SetJustifyH("RIGHT")

    cols.unit:ClearAllPoints()
    cols.unit:SetPoint("RIGHT", cols.tot, "LEFT", -gap, 0)
    cols.unit:SetWidth(COL_UNIT_W)
    cols.unit:SetJustifyH("RIGHT")

    cols.qty:ClearAllPoints()
    cols.qty:SetPoint("RIGHT", cols.unit, "LEFT", -gap, 0)
    cols.qty:SetWidth(COL_QTY_W)
    cols.qty:SetJustifyH("RIGHT")

    cols.name:ClearAllPoints()
    if cols.icon then
        cols.name:SetPoint("LEFT", cols.icon, "RIGHT", 6, 0)
    else
        cols.name:SetPoint("LEFT", host, "LEFT", leftInset + pad + COL_ICON_W + 6, 0)
    end
    cols.name:SetPoint("RIGHT", cols.qty, "LEFT", -gap, 0)
    cols.name:SetJustifyH("LEFT")
end

local function ApplyFarmColumnLayout(row, width)
    if not row or not row.name or not width or width < 180 then return end
    LayoutFarmValueColumns(row, {
        name = row.name,
        qty = row.qty,
        unit = row.unit,
        tot = row.tot,
        icon = row.icon,
        removeBtn = row.removeBtn,
    }, {
        hasRemove = row.removeBtn and row.removeBtn:IsShown() and true or false,
    })
end

local function ApplyPinnedHeaderLayout(hdr, width, opts)
    if not hdr or not hdr._h1 or not width or width < 180 then return end
    LayoutFarmValueColumns(hdr, {
        name = hdr._h1,
        qty = hdr._h2,
        unit = hdr._h3,
        tot = hdr._h4,
    }, opts)
end

local function AcquireFarmRow(parent, pool, index)
    if not pool[index] then
        local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetHeight(ROW_H - 2)
        row:SetBackdrop(BACKDROP_INNER)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(COL_ICON_W, COL_ICON_W)
        row.icon:SetPoint("LEFT", row, "LEFT", COL_PAD, 0)
        row.name = OneWoW_GUI:CreateFS(row, 10)
        row.qty = OneWoW_GUI:CreateFS(row, 10)
        row.unit = OneWoW_GUI:CreateFS(row, 10)
        row.tot = OneWoW_GUI:CreateFS(row, 10)
        ConfigureFarmRowFontStrings(row)
        ApplyFarmColumnLayout(row, 300)
        pool[index] = row
    end
    return pool[index]
end

local function EnsurePinnedHeader(hostFrame, scrollChild)
    local h = hostFrame._pinnedFarmHeader
    if not h then
        h = OneWoW_GUI:CreateFrame(scrollChild, {
            height = PIN_HEADER_H,
            backdrop = BACKDROP_INNER,
            bgColor = "BG_TERTIARY",
            borderColor = "BORDER_SUBTLE",
        })
        hostFrame._pinnedFarmHeader = h
        local h1 = OneWoW_GUI:CreateFS(h, 9)
        h1:SetText(L["ITEM"])
        h1:SetWordWrap(false)
        h1:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        local h2 = OneWoW_GUI:CreateFS(h, 9)
        h2:SetText(L["FARM_COL_QTY"])
        h2:SetWordWrap(false)
        h2:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        local h3 = OneWoW_GUI:CreateFS(h, 9)
        h3:SetText(L["FARM_COL_UNIT"])
        h3:SetWordWrap(false)
        h3:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        local h4 = OneWoW_GUI:CreateFS(h, 9)
        h4:SetText(L["FARM_COL_TOTAL"])
        h4:SetWordWrap(false)
        h4:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        h._h1, h._h2, h._h3, h._h4 = h1, h2, h3, h4
        ApplyPinnedHeaderLayout(h, 300)
    end
    return h
end

function TFV:RenderPinned(list, scrollChild, hostFrame)
    EnsureInventoryDelayed()
    if not hostFrame._farmBagHook then
        hostFrame._farmBagHook = true
        pinnedBagRefreshHosts[hostFrame] = true
    end

    hostFrame._farmRows = hostFrame._farmRows or {}
    local rows = hostFrame._farmRows
    for _, r in ipairs(rows) do
        r:Hide()
    end

    local fp = self:GetFarmPanel(list)
    local y = 0
    if fp and fp.showPinnedHeaders then
        local hdr = EnsurePinnedHeader(hostFrame, scrollChild)
        hdr:SetParent(scrollChild)
        hdr:ClearAllPoints()
        hdr:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
        hdr:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, y)
        hdr:Show()
        y = y - PIN_HEADER_H - 2
    elseif hostFrame._pinnedFarmHeader then
        hostFrame._pinnedFarmHeader:Hide()
    end

    local ids, counts = self:GetSortedIdsAndCounts(list)
    local layoutW = math.max(220, scrollChild:GetWidth())
    if fp and fp.showPinnedHeaders and hostFrame._pinnedFarmHeader then
        ApplyPinnedHeaderLayout(hostFrame._pinnedFarmHeader, layoutW)
    end
    for i, id in ipairs(ids) do
        local row = AcquireFarmRow(scrollChild, rows, i)
        row:SetParent(scrollChild)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, y)
        row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        row:SetScript("OnClick", function(_, button)
            if button ~= "RightButton" then return end
            if TFV:RemoveItemFromFarmWatchlist(list, row.itemID) then
                if hostFrame.Refresh then hostFrame:Refresh() end
                RefreshAllFarmWindows()
            end
        end)
        row:SetScript("OnEnter", function(myself)
            GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
            local iid = myself.itemID
            if iid then
                local nm, link = C_Item.GetItemInfo(iid)
                if link then
                    GameTooltip:SetHyperlink(link)
                elseif nm then
                    GameTooltip:SetText(nm, 1, 1, 1)
                else
                    GameTooltip:SetText("#" .. tostring(iid), 1, 1, 1)
                end
            end
            if fp.mode == "watchlist" then
                GameTooltip:AddLine(L["FARM_PIN_RIGHT_REMOVE"], 0.65, 0.65, 0.65, true)
            else
                GameTooltip:AddLine(L["FARM_PIN_ALLBAGS_NO_REMOVE"], 0.55, 0.55, 0.55, true)
            end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", GameTooltip_Hide)
        ApplyFarmColumnLayout(row, layoutW)
        LayoutFarmRow(row, id, counts[id] or 0, true)
        row:Show()
        y = y - ROW_H
    end
    scrollChild:SetWidth(layoutW)
    scrollChild:SetHeight(math_max(24, math.abs(y)))
    hostFrame._farmDropList = list
    scrollChild._farmHostFrame = hostFrame
    local scrollFrameWidget = scrollChild:GetParent()
    if scrollFrameWidget and not scrollFrameWidget._farmPinnedHooks then
        scrollFrameWidget._farmPinnedHooks = true
        scrollFrameWidget:EnableMouse(true)
        scrollChild:EnableMouse(true)
        scrollFrameWidget:HookScript("OnSizeChanged", function()
            local nw = scrollChild:GetWidth()
            local hf = scrollChild._farmHostFrame
            if not hf then return end
            for _, r in ipairs(hf._farmRows or {}) do
                if r:IsShown() then ApplyFarmColumnLayout(r, nw) end
            end
            if hf._pinnedFarmHeader and hf._pinnedFarmHeader:IsShown() then
                ApplyPinnedHeaderLayout(hf._pinnedFarmHeader, nw)
            end
        end)
        local function PinnedFarmReceiveDrag()
            local hf = scrollChild._farmHostFrame
            local lst = hf and hf._farmDropList
            if not lst then return end
            TFV:TryAddItemFromCursor(lst, TFV:GetFarmPanel(lst), function()
                if hf.Refresh then hf:Refresh() end
            end)
        end
        scrollFrameWidget:SetScript("OnReceiveDrag", PinnedFarmReceiveDrag)
        scrollChild:SetScript("OnReceiveDrag", PinnedFarmReceiveDrag)
    end
    OneWoW_GUI:ApplyFontToFrame(scrollChild)
end

function TFV:RenderDetailEditor(list, detailScrollChild, detailRows, yOffset, parent)
    local fp = self:GetFarmPanel(list)
    if not fp then return yOffset end

    local PAD = 8
    local DD_H = 26
    local HEADER_H = 20
    local LIST_H = 200
    local isWatchlist = fp.mode == "watchlist"

    local box = OneWoW_GUI:CreateFrame(detailScrollChild, {
        backdrop = BACKDROP_INNER,
        bgColor = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    box:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
    box:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
    tinsert(detailRows, box)

    local y = -PAD

    local warn = OneWoW_GUI:CreateFS(box, 10)
    warn:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, y)
    warn:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, y)
    warn:SetJustifyH("LEFT")
    warn:SetWordWrap(true)
    warn:SetText(L["FARM_HINT"])
    warn:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - (warn:GetStringHeight() or 14) - 8

    local priceLine = OneWoW_GUI:CreateFS(box, 10)
    priceLine:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, y)
    priceLine:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, y)
    priceLine:SetJustifyH("LEFT")
    priceLine:SetWordWrap(true)
    priceLine:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local function RefreshFarmPricingUI()
        local v = API.GetValueCfg()
        if not v then
            priceLine:SetText("")
            return
        end
        local showAH = v.showAHValue ~= false
        local useTSM = v.showTSMValue == true
        local tsmOk = useTSM and TSM_API and TSM_API.GetCustomPriceValue
        local tsmStr = (type(v.tsmPriceString) == "string" and v.tsmPriceString ~= "") and v.tsmPriceString or "dbmarket"

        local summary
        if not showAH and not useTSM then
            summary = L["FARM_VAL_NONE"]
        elseif useTSM and not showAH and tsmOk then
            summary = format(L["FARM_VAL_TSM_ONLY"], tsmStr)
        elseif useTSM and not tsmOk then
            summary = L["FARM_VAL_TSM_MISSING"]
        elseif useTSM and showAH and tsmOk then
            summary = format(L["FARM_VAL_TSM_FIRST"], tsmStr)
        else
            summary = L["FARM_VAL_AH_ONLY"]
        end

        local text = format(L["FARM_VAL_LINE1"], summary)
        if showAH then
            local supplier = OneWoW.ItemPrices:GetAHSourceLabel(v.ahPriceSource or "onewow")
            text = text .. "  " .. format(L["FARM_VAL_LINE2"], supplier)
        end
        priceLine:SetText(text)
    end
    RefreshFarmPricingUI()
    y = y - (priceLine:GetStringHeight() or 14) - 6

    local valueLink = OneWoW_GUI:CreateTextLink(box, {
        text = L["FARM_VALUE_SETTINGS_LINK"],
        fontSize = 11,
        nav = true,
        onClick = function()
            OneWoW:BringUp("OneWoW_QoL")
            OneWoW_QoL_API.SelectTooltipFeature("value")
        end,
    })
    valueLink:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, y)
    y = y - (valueLink:GetHeight() or 14) - 10

    local cbHeaders = OneWoW_GUI:CreateCheckbox(box, {
        label = L["FARM_PIN_HEADERS"],
        checked = fp.showPinnedHeaders and true or false,
        onClick = function(myself)
            fp.showPinnedHeaders = myself:GetChecked() and true or false
            RefreshAllFarmWindows()
        end,
    })
    cbHeaders:SetPoint("TOPLEFT", box, "TOPLEFT", PAD - 4, y)
    y = y - (cbHeaders.GetMeasuredHeight and cbHeaders:GetMeasuredHeight() or 24) - 8

    local sessionDD, sessionText = OneWoW_GUI:CreateDropdown(box, {
        width = 180,
        height = DD_H,
        text = fp.useSessionDelta and L["FARM_SNAPSHOT"] or L["FARM_RESET_TOTALS"],
    })
    sessionDD:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, y)

    local modeDD, modeText = OneWoW_GUI:CreateDropdown(box, {
        width = 220,
        height = DD_H,
        text = isWatchlist and L["FARM_MODE_WATCH"] or L["FARM_MODE_ALL"],
    })
    modeDD:SetPoint("LEFT", sessionDD, "RIGHT", 8, 0)

    sessionDD:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["FARM_SNAPSHOT"], 1, 1, 1)
        GameTooltip:AddLine(L["FARM_SNAPSHOT_TT"], 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["FARM_RESET_TOTALS"], 1, 1, 1)
        GameTooltip:AddLine(L["FARM_RESET_TOTALS_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    sessionDD:HookScript("OnLeave", GameTooltip_Hide)

    modeDD:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["FARM_MODE_WATCH"], 1, 1, 1)
        GameTooltip:AddLine(L["FARM_MODE_WATCH_TT"], 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["FARM_MODE_ALL"], 1, 1, 1)
        GameTooltip:AddLine(L["FARM_MODE_ALL_TT"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    modeDD:HookScript("OnLeave", GameTooltip_Hide)

    y = y - DD_H - 4

    local sessionNote = OneWoW_GUI:CreateFS(box, 9)
    sessionNote:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, y)
    sessionNote:SetPoint("RIGHT", box, "RIGHT", -PAD, 0)
    sessionNote:SetJustifyH("LEFT")
    sessionNote:SetWordWrap(true)
    sessionNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local function RefreshSessionNote()
        if fp.useSessionDelta then
            sessionNote:SetText(L["FARM_SESSION_ACTIVE"])
            sessionNote:Show()
        else
            sessionNote:SetText("")
            sessionNote:Hide()
        end
    end
    RefreshSessionNote()
    if fp.useSessionDelta then
        y = y - (sessionNote:GetStringHeight() or 12) - 6
    else
        y = y - 4
    end

    local editorY = y
    local _, editor = OneWoW_GUI:CreateItemListEditor(box, {
        yOffset = editorY,
        x = PAD,
        rightInset = PAD,
        gapAfterAdd = HEADER_H + 4,
        height = LIST_H,
        label = L["ITEM_ID"],
        addText = ADD,
        emptyText = L["NO_ITEMS"],
        drop = { text = L["DRAG_ITEM_HERE"] },
        sortKey = "trackers:farmvalue",
        getEntries = function()
            local ids, counts = TFV:GetSortedIdsAndCounts(list)
            local entries = {}
            for _, id in ipairs(ids) do
                C_Item.RequestLoadItemDataByID(id)
                local name, _, _, _, _, _, _, _, _, icon = C_Item.GetItemInfo(id)
                tinsert(entries, {
                    id = id,
                    label = name or ("#" .. tostring(id)),
                    icon = icon,
                    data = { qty = counts[id] or 0 },
                })
            end
            return entries
        end,
        onAdd = function(itemID)
            if fp.mode ~= "watchlist" then return false end
            local id = tonumber(itemID)
            if not id or id < 1 then return false end
            local set = ItemSetFromList(fp.items)
            if set[id] then return false end
            tinsert(fp.items, id)
            parent.RefreshList()
            RefreshAllFarmWindows()
            return true
        end,
        onRemove = function(itemID)
            if TFV:RemoveItemFromFarmWatchlist(list, itemID) then
                parent.RefreshList()
                RefreshAllFarmWindows()
            end
        end,
        createRow = function(row, entry, api)
            local id = entry.id
            local qty = entry.data and entry.data.qty or 0
            row:EnableMouse(true)
            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetSize(COL_ICON_W, COL_ICON_W)
            row.icon:SetPoint("LEFT", row, "LEFT", COL_PAD, 0)
            row.name = OneWoW_GUI:CreateFS(row, 10)
            row.qty = OneWoW_GUI:CreateFS(row, 10)
            row.unit = OneWoW_GUI:CreateFS(row, 10)
            row.tot = OneWoW_GUI:CreateFS(row, 10)
            ConfigureFarmRowFontStrings(row)
            if isWatchlist then
                local iconSize = OneWoW_GUI.Constants.GUI.ENTRY_LIST_ICON_SIZE
                local removeBtn = CreateFrame("Button", nil, row)
                removeBtn:SetSize(iconSize, iconSize)
                removeBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
                removeBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
                removeBtn:SetScript("OnClick", function()
                    if not api.IsEnabled() then return end
                    if TFV:RemoveItemFromFarmWatchlist(list, id) then
                        parent.RefreshList()
                        RefreshAllFarmWindows()
                    end
                    api.RequestRefresh()
                end)
                row.removeBtn = removeBtn
            end
            local function layoutRow()
                ApplyFarmColumnLayout(row, math.max(200, row:GetWidth() or 200))
            end
            row:HookScript("OnSizeChanged", layoutRow)
            layoutRow()
            LayoutFarmRow(row, id, qty, true)
            row:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                local nm, link = C_Item.GetItemInfo(id)
                if link then
                    GameTooltip:SetHyperlink(link)
                elseif nm then
                    GameTooltip:SetText(nm, 1, 1, 1)
                else
                    GameTooltip:SetText("#" .. tostring(id), 1, 1, 1)
                end
                GameTooltip:Show()
            end)
            row:SetScript("OnLeave", GameTooltip_Hide)
            return ROW_H
        end,
        rowHeight = ROW_H,
    })

    if not isWatchlist then
        editor.addRow.frame:Hide()
        editor.list.frame:ClearAllPoints()
        local listY = editorY - HEADER_H - 4
        editor.list.frame:SetPoint("TOPLEFT", box, "TOPLEFT", PAD, listY)
        editor.list.frame:SetPoint("TOPRIGHT", box, "TOPRIGHT", -PAD, listY)
    end

    local header = OneWoW_GUI:CreateFrame(box, {
        height = HEADER_H,
        backdrop = BACKDROP_INNER,
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    header:SetPoint("BOTTOMLEFT", editor.list.frame, "TOPLEFT", 0, 4)
    header:SetPoint("BOTTOMRIGHT", editor.list.frame, "TOPRIGHT", 0, 4)
    local h1 = OneWoW_GUI:CreateFS(header, 10)
    h1:SetText(L["ITEM"])
    h1:SetWordWrap(false)
    local h2 = OneWoW_GUI:CreateFS(header, 10)
    h2:SetText(L["FARM_COL_QTY"])
    h2:SetWordWrap(false)
    local h3 = OneWoW_GUI:CreateFS(header, 10)
    h3:SetText(L["FARM_COL_UNIT"])
    h3:SetWordWrap(false)
    local h4 = OneWoW_GUI:CreateFS(header, 10)
    h4:SetText(L["FARM_COL_TOTAL"])
    h4:SetWordWrap(false)
    header._h1, header._h2, header._h3, header._h4 = h1, h2, h3, h4
    local headerLeft, headerRight = DetailListHeaderInsets()
    local headerOpts = {
        hasRemove = isWatchlist,
        leftInset = headerLeft,
        rightInset = headerRight,
    }
    ApplyPinnedHeaderLayout(header, math.max(200, editor.list.frame:GetWidth() or 200), headerOpts)

    editor.list.frame:HookScript("OnSizeChanged", function(myself)
        ApplyPinnedHeaderLayout(header, myself:GetWidth(), headerOpts)
    end)

    local function RefreshFarmList()
        RefreshFarmPricingUI()
        RefreshSessionNote()
        editor:Refresh()
        sessionText:SetText(fp.useSessionDelta and L["FARM_SNAPSHOT"] or L["FARM_RESET_TOTALS"])
    end

    OneWoW_GUI:AttachFilterMenu(sessionDD, {
        searchable = false,
        buildItems = function()
            return {
                { value = "session", text = L["FARM_SNAPSHOT"] },
                { value = "totals", text = L["FARM_RESET_TOTALS"] },
            }
        end,
        onSelect = function(value)
            if value == "session" then
                TFV:TakeSessionSnapshot(list)
            else
                TFV:ClearSessionSnapshot(list)
            end
            RefreshAllFarmWindows()
            parent.ShowDetail(list.id)
        end,
        getActiveValue = function()
            return fp.useSessionDelta and "session" or "totals"
        end,
    })

    OneWoW_GUI:AttachFilterMenu(modeDD, {
        searchable = false,
        buildItems = function()
            return {
                { value = "watchlist", text = L["FARM_MODE_WATCH"] },
                { value = "allbags", text = L["FARM_MODE_ALL"] },
            }
        end,
        onSelect = function(value)
            fp.mode = value
            modeText:SetText(value == "allbags" and L["FARM_MODE_ALL"] or L["FARM_MODE_WATCH"])
            parent.RefreshList()
            parent.ShowDetail(list.id)
            RefreshAllFarmWindows()
        end,
        getActiveValue = function() return fp.mode end,
    })

    local boxBottom = math.abs(editorY)
    if isWatchlist then
        boxBottom = boxBottom + editor.addRow:GetHeight() + HEADER_H + 4 + LIST_H + PAD
    else
        boxBottom = boxBottom + HEADER_H + 4 + LIST_H + PAD
    end
    box:SetHeight(boxBottom)

    EnsureInventoryDelayed()
    bagDelayedDetailFn = function()
        RefreshFarmList()
        RefreshAllFarmWindows()
    end

    box:SetScript("OnShow", function()
        RefreshFarmList()
    end)

    OneWoW_GUI:ApplyFontToFrame(box)
    return yOffset - box:GetHeight() - 8
end
