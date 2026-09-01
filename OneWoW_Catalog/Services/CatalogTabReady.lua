local _, ns = ...

local C_Timer = C_Timer

-- ============================================================================
-- Catalog data-ready bootstrap
-- ============================================================================
-- Browse tabs start on NO_DATA. The watcher is idempotent (catch-up and the
-- live signal can both fire). Tab-specific scan callbacks and the first
-- RefreshList stay in onReady.
-- ============================================================================

--- Wire a Catalog browse tab to a data pack.
---@param addonName string
---@param opts table
---  emptyList FontString|nil
---  emptyDetail FontString|nil
---  noDataText string|nil
---  emptyText string|nil
---  selectText string|nil
---  delay number|nil
---  isReady (fun(): boolean)|nil
---  onReady fun()
function ns.WatchCatalogDataReady(addonName, opts)
    addonName = ns.ResolveCatalogPack(addonName) or addonName
    if opts.emptyList and opts.noDataText then
        opts.emptyList:SetText(opts.noDataText)
    end
    if opts.emptyDetail and opts.noDataText then
        opts.emptyDetail:SetText(opts.noDataText)
    end

    local wired = false
    OneWoW:RegisterDataReadyWatcher(addonName, function()
        if wired then
            return
        end
        if opts.isReady and not opts.isReady() then
            return
        end
        wired = true
        if opts.emptyList and opts.emptyText then
            opts.emptyList:SetText(opts.emptyText)
        end
        if opts.emptyDetail and opts.selectText then
            opts.emptyDetail:SetText(opts.selectText)
        end
        C_Timer.After(opts.delay or 0.1, opts.onReady)
    end)
end
