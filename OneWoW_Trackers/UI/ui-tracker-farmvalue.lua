local addonName, ns = ...
local L = ns.L

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local BACKDROP_INNER = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local tinsert, sort, math_max = table.insert, table.sort, math.max
local format = string.format
local pcall = pcall

local API = _G.OneWoW_ItemPricesAPI

ns.TrackerFarmValue = ns.TrackerFarmValue or {}
local TFV = ns.TrackerFarmValue

local ROW_H = 30
local PIN_HEADER_H = 22

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
    local loc
    if ItemLocation and ItemLocation.CreateFromBagAndSlot then
        loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    end
    if loc and loc.IsValid and loc:IsValid() and C_Item and C_Item.IsBound then
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
    if link and C_Item.GetItemInfoInstant then
        local id = C_Item.GetItemInfoInstant(link)
        if type(id) == "number" and id > 0 then return id end
    end
    if a and C_Item and C_Item.GetItemID then
        local ok, id = pcall(C_Item.GetItemID, a)
        if ok and type(id) == "number" and id > 0 then return id end
    end
    if b and C_Item and C_Item.GetItemID then
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

local function MutateOneWoWValue(fn)
    local ow = _G.OneWoW
    if not ow or not ow.db or not ow.db.global or not ow.db.global.settings then return false end
    local tips = ow.db.global.settings.tooltips
    if not tips then return false end
    if type(tips.value) ~= "table" then
        tips.value = {}
    end
    fn(tips.value)
    return true
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

    local ow = _G.OneWoW
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
        row.unit:SetText(OneWoW_GUI:FormatGold(unit))
        row.tot:SetText(OneWoW_GUI:FormatGold(unit * qty))
        row.unit:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        row.tot:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    else
        row.unit:SetText("—")
        row.tot:SetText("—")
        row.unit:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row.tot:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    end
end

local COL_PAD = 4
local COL_GAP = 3
local COL_TOT_W = 92
local COL_UNIT_W = 72
local COL_QTY_W = 36

local function ApplyFarmColumnLayout(row, width)
    if not row or not row.name or not width or width < 180 then return end
    local pad = COL_PAD
    local gap = COL_GAP
    row.tot:ClearAllPoints()
    row.tot:SetPoint("RIGHT", row, "RIGHT", -pad, 0)
    row.tot:SetWidth(COL_TOT_W)
    row.tot:SetJustifyH("RIGHT")
    row.unit:ClearAllPoints()
    row.unit:SetPoint("RIGHT", row.tot, "LEFT", -gap, 0)
    row.unit:SetWidth(COL_UNIT_W)
    row.unit:SetJustifyH("RIGHT")
    row.qty:ClearAllPoints()
    row.qty:SetPoint("RIGHT", row.unit, "LEFT", -gap, 0)
    row.qty:SetWidth(COL_QTY_W)
    row.qty:SetJustifyH("RIGHT")
    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.qty, "LEFT", -gap, 0)
    row.name:SetJustifyH("LEFT")
end

local function ApplyPinnedHeaderLayout(hdr, width)
    if not hdr or not hdr._h1 or not width or width < 180 then return end
    local pad, gap = COL_PAD, COL_GAP
    hdr._h4:ClearAllPoints()
    hdr._h4:SetPoint("RIGHT", hdr, "RIGHT", -pad, 0)
    hdr._h4:SetWidth(COL_TOT_W)
    hdr._h4:SetJustifyH("RIGHT")
    hdr._h3:ClearAllPoints()
    hdr._h3:SetPoint("RIGHT", hdr._h4, "LEFT", -gap, 0)
    hdr._h3:SetWidth(COL_UNIT_W)
    hdr._h3:SetJustifyH("RIGHT")
    hdr._h2:ClearAllPoints()
    hdr._h2:SetPoint("RIGHT", hdr._h3, "LEFT", -gap, 0)
    hdr._h2:SetWidth(COL_QTY_W)
    hdr._h2:SetJustifyH("RIGHT")
    hdr._h1:ClearAllPoints()
    hdr._h1:SetPoint("LEFT", hdr, "LEFT", pad + 22 + 6, 0)
    hdr._h1:SetPoint("RIGHT", hdr._h2, "LEFT", -gap, 0)
    hdr._h1:SetJustifyH("LEFT")
end

local function AcquireFarmRow(parent, pool, index)
    if not pool[index] then
        local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetHeight(ROW_H - 2)
        row:SetBackdrop(BACKDROP_INNER)
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(22, 22)
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
        h1:SetText(L["FARM_COL_ITEM"] or "Item")
        h1:SetWordWrap(false)
        h1:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        local h2 = OneWoW_GUI:CreateFS(h, 9)
        h2:SetText(L["FARM_COL_QTY"] or "Qty")
        h2:SetWordWrap(false)
        h2:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        local h3 = OneWoW_GUI:CreateFS(h, 9)
        h3:SetText(L["FARM_COL_UNIT"] or "Unit")
        h3:SetWordWrap(false)
        h3:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        local h4 = OneWoW_GUI:CreateFS(h, 9)
        h4:SetText(L["FARM_COL_TOTAL"] or "Total")
        h4:SetWordWrap(false)
        h4:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        h._h1, h._h2, h._h3, h._h4 = h1, h2, h3, h4
        ApplyPinnedHeaderLayout(h, 300)
    end
    return h
end

function TFV:RenderPinned(list, scrollChild, hostFrame)
    if not hostFrame._farmBagHook then
        hostFrame._farmBagHook = true
        hostFrame:RegisterEvent("BAG_UPDATE_DELAYED")
        hostFrame:SetScript("OnEvent", function(self, event)
            if event == "BAG_UPDATE_DELAYED" and self.Refresh then
                self:Refresh()
            end
        end)
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
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local iid = self.itemID
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
                GameTooltip:AddLine(L["FARM_PIN_RIGHT_REMOVE"] or "", 0.65, 0.65, 0.65, true)
            else
                GameTooltip:AddLine(L["FARM_PIN_ALLBAGS_NO_REMOVE"] or "", 0.55, 0.55, 0.55, true)
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

    local box = OneWoW_GUI:CreateFrame(detailScrollChild, {
        height = 460,
        backdrop = BACKDROP_INNER,
        bgColor = "BG_SECONDARY",
        borderColor = "BORDER_SUBTLE",
    })
    box:SetPoint("TOPLEFT", detailScrollChild, "TOPLEFT", 4, yOffset)
    box:SetPoint("TOPRIGHT", detailScrollChild, "TOPRIGHT", -4, yOffset)
    tinsert(detailRows, box)

    local RefreshSessionNote, RefreshFarmPricingUI, RedrawDetailRows

    local warn = OneWoW_GUI:CreateFS(box, 10)
    warn:SetPoint("TOPLEFT", box, "TOPLEFT", 8, -8)
    warn:SetPoint("TOPRIGHT", box, "TOPRIGHT", -8, -8)
    warn:SetJustifyH("LEFT")
    warn:SetWordWrap(true)
    if not (_G.OneWoW and _G.OneWoW.ItemPrices) then
        warn:SetText(L["FARM_NEED_ONEWOW"] or "")
        warn:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    else
        warn:SetText(L["FARM_HINT"] or "")
        warn:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end

    local srcLine1 = OneWoW_GUI:CreateFS(box, 10)
    srcLine1:SetPoint("TOPLEFT", warn, "BOTTOMLEFT", 0, -10)
    srcLine1:SetPoint("TOPRIGHT", warn, "BOTTOMRIGHT", 0, -10)
    srcLine1:SetJustifyH("LEFT")
    srcLine1:SetWordWrap(true)
    srcLine1:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local srcLine2 = OneWoW_GUI:CreateFS(box, 10)
    srcLine2:SetPoint("TOPLEFT", srcLine1, "BOTTOMLEFT", 0, -4)
    srcLine2:SetPoint("TOPRIGHT", srcLine1, "BOTTOMRIGHT", 0, -4)
    srcLine2:SetJustifyH("LEFT")
    srcLine2:SetWordWrap(true)
    srcLine2:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local cbShowAH = OneWoW_GUI:CreateCheckbox(box, { label = L["FARM_SHOW_AH"] or "AH" })
    cbShowAH:SetPoint("TOPLEFT", srcLine2, "BOTTOMLEFT", -4, -10)

    local cbUseTSM = OneWoW_GUI:CreateCheckbox(box, { label = L["FARM_USE_TSM"] or "TSM" })
    cbUseTSM:SetPoint("TOPLEFT", cbShowAH, "BOTTOMLEFT", 0, -2)

    local ahSrcBtn = OneWoW_GUI:CreateFitTextButton(box, { text = L["FARM_AH_SOURCE"] or "AH", height = 22 })
    ahSrcBtn:SetPoint("TOPLEFT", cbUseTSM, "BOTTOMLEFT", 0, -6)

    local openOwBtn = OneWoW_GUI:CreateFitTextButton(box, { text = L["FARM_OPEN_ONEWOW"] or "OneWoW", height = 22 })
    openOwBtn:SetPoint("LEFT", ahSrcBtn, "RIGHT", 8, 0)
    openOwBtn:SetScript("OnClick", function()
        if _G.OneWoW and _G.OneWoW.GUI and _G.OneWoW.GUI.Show then
            _G.OneWoW.GUI:Show()
        end
    end)
    openOwBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["FARM_OPEN_ONEWOW_TT"] or "")
        GameTooltip:Show()
    end)
    openOwBtn:SetScript("OnLeave", GameTooltip_Hide)

    OneWoW_GUI:AttachFilterMenu(ahSrcBtn, {
        buildItems = function()
            local t = { { value = "onewow", text = L["FARM_AH_ONEWOW"] or "OneWoW" } }
            if C_AddOns.IsAddOnLoaded("Auctionator") then
                tinsert(t, { value = "auctionator", text = L["FARM_AH_AUCTIONATOR"] or "Auctionator" })
            end
            return t
        end,
        onSelect = function(value)
            MutateOneWoWValue(function(val)
                val.ahPriceSource = value
            end)
            RefreshFarmPricingUI()
            RedrawDetailRows()
            RefreshAllFarmWindows()
        end,
        getActiveValue = function()
            local v = API and API.GetValueCfg and API.GetValueCfg()
            return (v and v.ahPriceSource) or "onewow"
        end,
    })

    local cbHeaders = OneWoW_GUI:CreateCheckbox(box, {
        label = L["FARM_PIN_HEADERS"] or "Headers",
        checked = fp.showPinnedHeaders and true or false,
        onClick = function(self)
            fp.showPinnedHeaders = self:GetChecked() and true or false
            RefreshAllFarmWindows()
        end,
    })
    cbHeaders:SetPoint("TOPLEFT", ahSrcBtn, "BOTTOMLEFT", -4, -6)

    local sessionNote = OneWoW_GUI:CreateFS(box, 9)
    sessionNote:SetPoint("TOPLEFT", cbHeaders, "BOTTOMLEFT", 4, -4)
    sessionNote:SetPoint("TOPRIGHT", cbHeaders, "BOTTOMRIGHT", -4, -4)
    sessionNote:SetJustifyH("LEFT")
    sessionNote:SetWordWrap(true)
    sessionNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local snapBtn = OneWoW_GUI:CreateFitTextButton(box, { text = L["FARM_SNAPSHOT"] or "Count", height = 22 })
    snapBtn:SetPoint("TOPLEFT", cbHeaders, "BOTTOMLEFT", -4, -8)
    snapBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["FARM_SNAPSHOT_TT"] or "")
        GameTooltip:Show()
    end)
    snapBtn:SetScript("OnLeave", GameTooltip_Hide)
    snapBtn:SetScript("OnClick", function()
        TFV:TakeSessionSnapshot(list)
        RefreshSessionNote()
        RedrawDetailRows()
        RefreshAllFarmWindows()
    end)

    local resetSessionBtn = OneWoW_GUI:CreateFitTextButton(box, { text = L["FARM_RESET_TOTALS"] or "Reset", height = 22 })
    resetSessionBtn:SetPoint("LEFT", snapBtn, "RIGHT", 8, 0)
    resetSessionBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["FARM_RESET_TOTALS_TT"] or "")
        GameTooltip:Show()
    end)
    resetSessionBtn:SetScript("OnLeave", GameTooltip_Hide)
    resetSessionBtn:SetScript("OnClick", function()
        TFV:ClearSessionSnapshot(list)
        RefreshSessionNote()
        RedrawDetailRows()
        RefreshAllFarmWindows()
    end)

    local toolbar = OneWoW_GUI:CreateFrame(box, {
        height = 36,
        backdrop = BACKDROP_INNER,
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    toolbar:SetPoint("TOPLEFT", snapBtn, "BOTTOMLEFT", -2, -10)
    toolbar:SetPoint("TOPRIGHT", snapBtn, "BOTTOMRIGHT", 2, -10)

    local modeText = OneWoW_GUI:CreateFS(toolbar, 11)
    modeText:SetPoint("LEFT", toolbar, "LEFT", 8, 0)
    modeText:SetText(fp.mode == "allbags" and (L["FARM_MODE_ALL"] or "") or (L["FARM_MODE_WATCH"] or ""))
    modeText:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L["FARM_MODE_WATCH"] or "", 1, 1, 1)
        GameTooltip:AddLine(L["FARM_MODE_WATCH_TT"] or "", 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L["FARM_MODE_ALL"] or "", 1, 1, 1)
        GameTooltip:AddLine(L["FARM_MODE_ALL_TT"] or "", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    modeText:SetScript("OnLeave", GameTooltip_Hide)

    local modeBtn = OneWoW_GUI:CreateFitTextButton(toolbar, { text = L["FARM_MODE_CHANGE"] or "Mode", height = 22 })
    modeBtn:SetPoint("LEFT", modeText, "RIGHT", 10, 0)
    modeBtn:SetScript("OnEnter", modeText:GetScript("OnEnter"))
    modeBtn:SetScript("OnLeave", GameTooltip_Hide)
    OneWoW_GUI:AttachFilterMenu(modeBtn, {
        buildItems = function()
            return {
                { value = "watchlist", text = L["FARM_MODE_WATCH"] or "Watchlist" },
                { value = "allbags", text = L["FARM_MODE_ALL"] or "All unbound in bags" },
            }
        end,
        onSelect = function(value)
            fp.mode = value
            modeText:SetText(value == "allbags" and (L["FARM_MODE_ALL"] or "") or (L["FARM_MODE_WATCH"] or ""))
            parent.RefreshList()
            parent.ShowDetail(list.id)
            RefreshAllFarmWindows()
        end,
        getActiveValue = function() return fp.mode end,
    })

    local addCursor = OneWoW_GUI:CreateFitTextButton(toolbar, { text = L["FARM_ADD_CURSOR"] or "Add cursor", height = 22 })
    addCursor:SetPoint("LEFT", modeBtn, "RIGHT", 10, 0)
    addCursor:SetScript("OnClick", function()
        local id = TFV.ResolveItemIDFromCursor()
        ClearCursor()
        if not id then return end
        local set = ItemSetFromList(fp.items)
        if not set[id] then
            tinsert(fp.items, id)
            parent.RefreshList()
            parent.ShowDetail(list.id)
            RefreshAllFarmWindows()
        end
    end)

    local removeBtn = OneWoW_GUI:CreateFitTextButton(toolbar, { text = L["FARM_REMOVE"] or "Remove", height = 22 })
    removeBtn:SetPoint("LEFT", addCursor, "RIGHT", 8, 0)
    removeBtn:SetScript("OnClick", function()
        local sel = box._farmSelected
        if not sel or not sel.itemID then return end
        local rid = sel.itemID
        for i = #fp.items, 1, -1 do
            if fp.items[i] == rid then table.remove(fp.items, i) end
        end
        box._farmSelected = nil
        parent.RefreshList()
        parent.ShowDetail(list.id)
        RefreshAllFarmWindows()
    end)

    local function UpdateRemoveVisible()
        removeBtn:SetShown(fp.mode ~= "allbags")
    end

    local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -22, 8)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(scroll:GetWidth() - 4)
    scroll:SetScrollChild(child)

    local header = OneWoW_GUI:CreateFrame(child, { height = 20, backdrop = BACKDROP_INNER, bgColor = "BG_TERTIARY", borderColor = "BORDER_SUBTLE" })
    header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, 0)
    local h1 = OneWoW_GUI:CreateFS(header, 10)
    h1:SetText(L["FARM_COL_ITEM"] or "Item")
    h1:SetWordWrap(false)
    local h2 = OneWoW_GUI:CreateFS(header, 10)
    h2:SetText(L["FARM_COL_QTY"] or "Qty")
    h2:SetWordWrap(false)
    local h3 = OneWoW_GUI:CreateFS(header, 10)
    h3:SetText(L["FARM_COL_UNIT"] or "Unit")
    h3:SetWordWrap(false)
    local h4 = OneWoW_GUI:CreateFS(header, 10)
    h4:SetText(L["FARM_COL_TOTAL"] or "Total")
    h4:SetWordWrap(false)
    header._h1, header._h2, header._h3, header._h4 = h1, h2, h3, h4
    ApplyPinnedHeaderLayout(header, 300)

    box._farmRows = box._farmRows or {}

    RefreshSessionNote = function()
        if fp.useSessionDelta then
            sessionNote:SetText(L["FARM_SESSION_ACTIVE"] or "")
            sessionNote:Show()
            snapBtn:ClearAllPoints()
            resetSessionBtn:ClearAllPoints()
            snapBtn:SetPoint("TOPLEFT", sessionNote, "BOTTOMLEFT", -8, -4)
            resetSessionBtn:SetPoint("LEFT", snapBtn, "RIGHT", 8, 0)
        else
            sessionNote:SetText("")
            sessionNote:Hide()
            snapBtn:ClearAllPoints()
            resetSessionBtn:ClearAllPoints()
            snapBtn:SetPoint("TOPLEFT", cbHeaders, "BOTTOMLEFT", -4, -8)
            resetSessionBtn:SetPoint("LEFT", snapBtn, "RIGHT", 8, 0)
        end
    end

    RefreshFarmPricingUI = function()
        local v = API and API.GetValueCfg and API.GetValueCfg()
        if not v then
            srcLine1:SetText("")
            srcLine2:SetText("")
            return
        end
        local showAH = v.showAHValue ~= false
        local useTSM = v.showTSMValue == true
        local tsmOk = useTSM and TSM_API and TSM_API.GetCustomPriceValue
        local tsmStr = (type(v.tsmPriceString) == "string" and v.tsmPriceString ~= "") and v.tsmPriceString or "dbmarket"

        local summary
        if not showAH and not useTSM then
            summary = L["FARM_VAL_NONE"] or ""
        elseif useTSM and not showAH and tsmOk then
            summary = format(L["FARM_VAL_TSM_ONLY"] or "%s", tsmStr)
        elseif useTSM and not tsmOk then
            summary = L["FARM_VAL_TSM_MISSING"] or ""
        elseif useTSM and showAH and tsmOk then
            summary = format(L["FARM_VAL_TSM_FIRST"] or "%s", tsmStr)
        else
            summary = L["FARM_VAL_AH_ONLY"] or ""
        end

        srcLine1:SetText(format(L["FARM_VAL_LINE1"] or "%s", summary))
        if showAH then
            local supplier = (v.ahPriceSource == "auctionator") and (L["FARM_AH_AUCTIONATOR"] or "Auctionator") or (L["FARM_AH_ONEWOW"] or "OneWoW")
            srcLine2:SetText(format(L["FARM_VAL_LINE2"] or "%s", supplier))
            srcLine2:Show()
        elseif useTSM then
            srcLine2:SetText(L["FARM_VAL_NO_AH_TSM"] or "")
            srcLine2:Show()
        else
            srcLine2:SetText("")
            srcLine2:Hide()
        end

        cbShowAH:SetChecked(showAH)
        cbUseTSM:SetChecked(useTSM)
        local ahLbl = (v.ahPriceSource == "auctionator") and (L["FARM_AH_AUCTIONATOR"] or "Auctionator") or (L["FARM_AH_ONEWOW"] or "OneWoW")
        ahSrcBtn:SetFitText(format("%s: %s", L["FARM_AH_SOURCE"] or "AH", ahLbl))
    end

    RedrawDetailRows = function()
        for _, r in ipairs(box._farmRows) do
            r:Hide()
        end
        local ids, counts = TFV:GetSortedIdsAndCounts(list)
        local y = -22
        local cw = math.max(200, child:GetWidth() or 200)
        ApplyPinnedHeaderLayout(header, cw)
        for i, id in ipairs(ids) do
            local row = AcquireFarmRow(child, box._farmRows, i)
            row:SetParent(child)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
            row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
            local qty = counts[id] or 0
            ApplyFarmColumnLayout(row, cw)
            LayoutFarmRow(row, id, qty, true)
            row:SetScript("OnClick", function(self)
                box._farmSelected = self
                for _, rr in ipairs(box._farmRows) do
                    if rr:IsShown() then
                        rr:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
                    end
                end
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end)
            row:Show()
            y = y - ROW_H
        end
        child:SetHeight(math_max(24, math.abs(y)))
        UpdateRemoveVisible()
    end

    if not scroll._farmDetailHooks then
        scroll._farmDetailHooks = true
        scroll:EnableMouse(true)
        child:EnableMouse(true)
        local function DetailFarmReceiveDrag()
            TFV:TryAddItemFromCursor(list, fp, function()
                parent.RefreshList()
                parent.ShowDetail(list.id)
                RefreshAllFarmWindows()
                RedrawDetailRows()
            end)
        end
        scroll:SetScript("OnReceiveDrag", DetailFarmReceiveDrag)
        child:SetScript("OnReceiveDrag", DetailFarmReceiveDrag)
        scroll:HookScript("OnSizeChanged", function()
            local nw = child:GetWidth()
            ApplyPinnedHeaderLayout(header, nw)
            for _, r in ipairs(box._farmRows) do
                if r:IsShown() then ApplyFarmColumnLayout(r, nw) end
            end
        end)
    end

    cbShowAH:SetScript("OnClick", function(self)
        MutateOneWoWValue(function(val)
            val.showAHValue = self:GetChecked() and true or false
        end)
        RefreshFarmPricingUI()
        RedrawDetailRows()
        RefreshAllFarmWindows()
    end)

    cbUseTSM:SetScript("OnClick", function(self)
        MutateOneWoWValue(function(val)
            val.showTSMValue = self:GetChecked() and true or false
        end)
        RefreshFarmPricingUI()
        RedrawDetailRows()
        RefreshAllFarmWindows()
    end)

    RefreshFarmPricingUI()
    RefreshSessionNote()
    RedrawDetailRows()

    if not box._farmDetailHook then
        box._farmDetailHook = true
        box:RegisterEvent("BAG_UPDATE_DELAYED")
        box:SetScript("OnEvent", function()
            RedrawDetailRows()
            RefreshAllFarmWindows()
        end)
    end

    box:SetScript("OnShow", function()
        RefreshFarmPricingUI()
        RefreshSessionNote()
        RedrawDetailRows()
    end)

    OneWoW_GUI:ApplyFontToFrame(box)
    return yOffset - box:GetHeight() - 8
end
