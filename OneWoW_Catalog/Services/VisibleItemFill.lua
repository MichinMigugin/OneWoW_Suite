local _, ns = ...

-- ============================================================================
-- Catalog visible-item fill
-- ============================================================================
-- Cache hit paints immediately. A miss loads only for this row; a fill token
-- plus IsShown() drops stale callbacks after rebind. Call sites stay
-- Instant-only (GetItemInfoInstant). RequestLoadItemDataByID runs inside
-- opts.load, for the visible row only.
--
-- Journal lazy hydrate: resolved journal pack (ZoneDB).
-- ============================================================================

local TOKEN_KEY = "_catalogFillToken"

--- Fill name / icon / quality for a visible item row.
---@param row Frame
---@param itemID number
---@param opts table
---  getCached fun(itemID: number): table|nil
---  load fun(itemID: number, cb: fun(itemID: number, result: table|nil))
---  apply fun(result: table, paintWidgets: boolean)
---  onStale fun(result: table)|nil
function ns.FillVisibleItem(row, itemID, opts)
    itemID = tonumber(itemID)
    if not row or not itemID or not opts then
        return
    end

    local cached = opts.getCached(itemID)
    if cached then
        opts.apply(cached, true)
        return
    end

    local token = {}
    row[TOKEN_KEY] = token
    opts.load(itemID, function(_, result)
        if not result then
            return
        end
        local canPaint = row[TOKEN_KEY] == token and row:IsShown()
        opts.apply(result, canPaint)
        if not canPaint and opts.onStale then
            opts.onStale(result)
        end
    end)
end
