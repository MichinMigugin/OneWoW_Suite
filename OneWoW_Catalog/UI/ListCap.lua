local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local wipe = wipe

-- ============================================================================
-- Catalog left-list cap
-- ============================================================================
-- After a tab applies search/filters, slice the published array so the
-- virtualizer never paints the whole catalog. Unfiltered default browse is
-- 50 rows; any search box text or extra Type/expansion/status filter is 100.
-- A trailing notice row is not a data row and does not count toward the cap.
-- ============================================================================

local CAP_UNFILTERED = 50
local CAP_FILTERED = 100

local SENTINEL = { catalogListCap = true }

local HIDE_FIELDS = {
    "nameText",
    "infoText",
    "statusText",
    "countText",
    "metaText",
    "zoneText",
    "categoryText",
    "subText",
    "icon",
    "iconFrame",
    "portrait",
    "favBtn",
    "pinBtn",
    "rightCluster",
    "qtyBadge",
    "arrowText",
    "headerName",
    "selectedAccent",
    "groupToggle",
    "checkHit",
    "bgTex",
}

local HIDE_ARRAYS = {
    "catTexts",
    "bountifulCorners",
    "statusIcons",
}

--- Cap used for the current browse vs filtered state.
---@param isFiltered boolean
---@return number
function ns.GetCatalogListCap(isFiltered)
    if isFiltered then
        return CAP_FILTERED
    end
    return CAP_UNFILTERED
end

--- True when the search box has real text (not empty / whitespace).
---@param text string|nil
---@return boolean
function ns.CatalogListHasSearchText(text)
    return type(text) == "string" and text:match("%S") ~= nil
end

--- Whether `entry` is the trailing "narrow results" row.
---@param entry table|nil
---@return boolean
function ns.IsCatalogListCap(entry)
    return entry == SENTINEL or (entry ~= nil and entry.catalogListCap == true)
end

--- Slice `results` in place to the cap. Call after filters, before paint.
---@param results table
---@param isFiltered boolean
---@return boolean truncated
function ns.CapCatalogList(results, isFiltered)
    local cap = ns.GetCatalogListCap(isFiltered)
    local total = #results
    if total <= cap then
        return false
    end
    for i = cap + 1, total do
        results[i] = nil
    end
    return true
end

--- Shared-budget slice for two published arrays (quests + hoisted favorites).
---@param primary table
---@param secondary table|nil
---@param isFiltered boolean
---@return table primary
---@return table secondary
---@return number total
---@return boolean truncated
function ns.CapCatalogListPair(primary, secondary, isFiltered)
    secondary = secondary or {}
    local cap = ns.GetCatalogListCap(isFiltered)
    local total = #primary + #secondary
    if total <= cap then
        return primary, secondary, total, false
    end

    local qOut, fOut = {}, {}
    for i = 1, #primary do
        if #qOut >= cap then
            break
        end
        qOut[#qOut + 1] = primary[i]
    end
    for i = 1, #secondary do
        if (#qOut + #fOut) >= cap then
            break
        end
        fOut[#fOut + 1] = secondary[i]
    end
    return qOut, fOut, total, true
end

--- Append the locale notice row. Does not count toward the data cap.
---@param results table
function ns.AppendCatalogListCapNotice(results)
    if #results > 0 and ns.IsCatalogListCap(results[#results]) then
        return
    end
    results[#results + 1] = SENTINEL
end

--- Paint-time count when the backing array is still growing (Item Search).
---@param results table
---@param isFiltered boolean
---@return number
function ns.CatalogListVisibleCount(results, isFiltered)
    local n = #results
    if n > 0 and ns.IsCatalogListCap(results[n]) then
        return n
    end
    local cap = ns.GetCatalogListCap(isFiltered)
    if n > cap then
        return cap + 1
    end
    return n
end

--- Paint-time entry, synthesizing the notice row when the array is over cap.
---@param results table
---@param index number
---@param isFiltered boolean
---@return table|nil
function ns.CatalogListVisibleEntry(results, index, isFiltered)
    local n = #results
    if n > 0 and ns.IsCatalogListCap(results[n]) then
        return results[index]
    end
    local cap = ns.GetCatalogListCap(isFiltered)
    if n > cap and index == cap + 1 then
        return SENTINEL
    end
    return results[index]
end

--- Data rows only (excludes the notice). Avoids walking a 174k backing array.
---@param results table
---@param isFiltered boolean
---@return number
function ns.CatalogListDataCount(results, isFiltered)
    local n = #results
    if n > 0 and ns.IsCatalogListCap(results[n]) then
        return n - 1
    end
    local cap = ns.GetCatalogListCap(isFiltered)
    if n > cap then
        return cap
    end
    return n
end

local function HideCapWidget(row, widget)
    if not widget or not widget.Hide or not widget:IsShown() then
        return
    end
    local hidden = row._catalogListCapHidden
    hidden[#hidden + 1] = widget
    widget:Hide()
end

local function ClearCatalogListCapRow(row)
    if not row._catalogListCapActive then
        return
    end
    row._catalogListCapActive = false
    if row._catalogListCapNotice then
        row._catalogListCapNotice:Hide()
    end
    local hidden = row._catalogListCapHidden
    if hidden then
        for i = 1, #hidden do
            hidden[i]:Show()
        end
        wipe(hidden)
    end
end

--- Bind or clear the trailing notice row. Returns true when `entry` is the notice.
---@param row Frame
---@param entry table|nil
---@return boolean
function ns.BindCatalogListCapRow(row, entry)
    if not ns.IsCatalogListCap(entry) then
        ClearCatalogListCapRow(row)
        return false
    end

    row.instData = nil
    row.vendor = nil
    row.result = nil
    row.quest = nil
    row.entry = entry
    row._rowSelected = false

    if not row._catalogListCapHidden then
        row._catalogListCapHidden = {}
    elseif not row._catalogListCapActive then
        wipe(row._catalogListCapHidden)
    end

    if not row._catalogListCapActive then
        for i = 1, #HIDE_FIELDS do
            HideCapWidget(row, row[HIDE_FIELDS[i]])
        end
        for i = 1, #HIDE_ARRAYS do
            local arr = row[HIDE_ARRAYS[i]]
            if arr then
                for j = 1, #arr do
                    HideCapWidget(row, arr[j])
                end
            end
        end
        row._catalogListCapActive = true
    end

    if row.SetBackdropColor then
        row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
        row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end

    if not row._catalogListCapNotice then
        local fs = OneWoW_GUI:CreateFS(row, 11)
        fs:SetPoint("LEFT", row, "LEFT", 8, 0)
        fs:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(true)
        row._catalogListCapNotice = fs
    end
    local notice = row._catalogListCapNotice
    notice:SetText(L["CATALOG_LIST_NARROW"])
    notice:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    notice:Show()
    return true
end
