local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

-- Resolved per call, never captured. This file loads with the GUI block, which
-- runs before Services/LocaleService.lua publishes `ns.L` — taking it at file
-- scope silently yields nil and the first lookup aborts the rest of the file.
-- Per-call also means a language change is picked up without a rebuild.
local function T(key)
    return ns.L[key]
end

local ipairs = ipairs
local tinsert = tinsert
local tconcat = table.concat
local format = string.format
local min = math.min

-- ============================================================================
-- Catalog write confirmation
-- ============================================================================
-- Renders a SearchCatalog preflight report and asks before going ahead.
--
-- The catalog never prompts on its own — it returns an account of what a write
-- would cost, or nil when it costs nothing — so this is where that account
-- becomes a question. Shared rather than per-tab because the same three writes
-- happen in core Settings and in the Bags category manager, and a warning that
-- only fires in one of them is worse than none: it teaches that the other is safe.
--
-- The report always names *where*, never just how many. "3 references" tells a
-- user nothing they can act on; "Mail — Shipments (1: Weekly mats)" tells them
-- which window to open.
--
-- This file owns only the report-to-rows mapping. Drawing lives in
-- GUI/ReportDialog.lua, shared with the reference lint, which renders the same
-- row shapes from different data.

local REASON_HEADER_KEY = {
    deleted   = "CATALOG_WRITE_BREAKS_DELETE",
    reclaimed = "CATALOG_WRITE_BREAKS_RECLAIM",
    capped    = "CATALOG_WRITE_BREAKS_CAPPED",
}

local REASON_HEADER_RESTORABLE_KEY = {
    deleted   = "CATALOG_WRITE_SAFE_DELETE",
    reclaimed = "CATALOG_WRITE_SAFE_RECLAIM",
    capped    = "CATALOG_WRITE_SAFE_CAPPED",
}

local PROCEED_LABEL_KEY = {
    delete = "CATALOG_WRITE_PROCEED_DELETE",
    rename = "CATALOG_WRITE_PROCEED_RENAME",
    claim  = "CATALOG_WRITE_PROCEED_CLAIM",
}

-- Long enough to be useful, short enough that the dialog stays scannable.
local MAX_USAGES_PER_GROUP = 6

-- ---- Row model ----
--
-- The report is flattened to a typed row list first, then rendered. Keeping the
-- two apart is what lets 8C reuse this: a lint finding produces the same row
-- shapes from different data, and the renderer never learns which it is looking
-- at.

---@param rows table[]
---@param kind string "prompt" | "header" | "source" | "usage" | "note" | "divider"
---@param text string|nil
local function Row(rows, kind, text)
    tinsert(rows, { kind = kind, text = text })
end

---@param rows table[]
---@param groups table[]
local function AppendGroups(rows, groups)
    for _, group in ipairs(groups) do
        local shown = min(#group.usages, MAX_USAGES_PER_GROUP)
        Row(rows, "source", format("%s (%d)", group.sourceLabel or "?", #group.usages))
        for i = 1, shown do
            Row(rows, "usage", group.usages[i].label or "?")
        end
        if #group.usages > shown then
            Row(rows, "usage", format(T("CATALOG_WRITE_MORE"), #group.usages - shown))
        end
    end
end

--- Flatten a preflight report into rows.
---
--- `opts.prompt` is the caller's own question, shown above the report — a caller
--- that has one is asking something the reference report does not answer, so it
--- leads. `opts.note` qualifies that question and is styled like the report's own
--- explanatory lines, which keeps the question itself short: a heading that has
--- to explain what it will *not* do reads like a threat.
---@param report table|nil
---@param opts table
---@return table[] rows
local function BuildRows(report, opts)
    local rows = {}
    local anyRestorable = false

    if opts.prompt then
        Row(rows, "prompt", opts.prompt)
        if opts.note then Row(rows, "note", opts.note) end
        if report then Row(rows, "divider") end
    end
    if not report then return rows end

    for _, loss in ipairs(report.losses or {}) do
        local refs = loss.references
        if refs then
            if refs.total > 0 then
                local key = REASON_HEADER_KEY[loss.reason] or REASON_HEADER_KEY.deleted
                Row(rows, "header", format(T(key), loss.name, refs.total))
                AppendGroups(rows, refs.groups)
                if loss.reason == "reclaimed" then
                    Row(rows, "note", T("CATALOG_WRITE_RECLAIM_TAIL"))
                end
            elseif refs.restorableTotal > 0 then
                -- No live usage, so lead with the reassurance rather than a
                -- breakage headline that would be untrue.
                local key = REASON_HEADER_RESTORABLE_KEY[loss.reason] or REASON_HEADER_RESTORABLE_KEY.deleted
                Row(rows, "header", format(T(key), loss.name))
            end
            if refs.restorableTotal > 0 then anyRestorable = true end
        end
    end

    if anyRestorable then
        Row(rows, "divider")
        Row(rows, "header", T("CATALOG_WRITE_RESTORABLE_HEADER"))
        for _, loss in ipairs(report.losses or {}) do
            local refs = loss.references
            if refs and refs.restorableTotal > 0 then
                AppendGroups(rows, refs.restorableGroups)
            end
        end
        Row(rows, "note", T("CATALOG_WRITE_RESTORABLE_TAIL"))
    end

    -- A disabled unit's SavedVariables are not loaded, so its references are
    -- invisible to the walk that produced this. Saying so beats presenting a
    -- lower bound as if it were the whole picture.
    local incomplete = report.incomplete
    if incomplete and #incomplete > 0 then
        Row(rows, "divider")
        Row(rows, "note", format(T("CATALOG_WRITE_INCOMPLETE"), #incomplete, tconcat(incomplete, ", ")))
    end

    return rows
end

--- Show the report and run `onProceed` only if the user accepts.
---@param report table|nil
---@param onProceed fun()
---@param opts table
local function ShowReport(report, onProceed, opts)
    OneWoW_GUI:ShowReportDialog({
        key = "catalog_confirm",
        title = "OneWoW",
        rows = BuildRows(report, opts),
        buttons = {
            { text = CANCEL },
            {
                text = opts.proceedText
                    or (report and T(PROCEED_LABEL_KEY[report.action]))
                    or T("CATALOG_WRITE_PROCEED"),
                danger = true,
                onClick = onProceed,
            },
        },
    })
end

--- Confirm a catalog write that would change or break existing references.
---
--- Pass the report straight from `PreflightDelete` / `PreflightClaim` /
--- `PreflightRename`; a nil report means the write costs nothing, and
--- `onProceed` runs immediately with no dialog. Callers therefore never need to
--- branch on whether a warning is warranted.
---
--- Cancelling does not offer to fix anything for the user: the report names the
--- store and the item, and the windows that own them live in other addons.
---
--- `opts.prompt` is a question of the caller's own, shown above the report — and
--- passing one also means *always ask*, because a caller with its own question
--- has something to confirm whether or not anything references the entry.
--- `opts.proceedText` overrides the action button's label.
---@param report table|nil
---@param onProceed fun()
---@param opts table|nil { prompt: string|nil, note: string|nil, proceedText: string|nil }
function OneWoW_GUI:ConfirmCatalogWrite(report, onProceed, opts)
    opts = opts or {}
    local costs = report and ((report.total or 0) + (report.restorableTotal or 0)) > 0
    if not costs and not opts.prompt then
        onProceed()
        return
    end
    ShowReport(costs and report or nil, onProceed, opts)
end

--- Preflight a delete by name and confirm it. Convenience for the common case,
--- where the caller has a display name rather than an entry id.
---@param kind string
---@param name string
---@param onProceed fun()
function OneWoW_GUI:ConfirmCatalogDelete(kind, name, onProceed)
    local entry = ns.SearchCatalog:Resolve(kind, name)
    if not entry then
        onProceed()
        return
    end
    self:ConfirmCatalogWrite(ns.SearchCatalog:PreflightDelete(kind, entry.id), onProceed)
end

--- Preflight a rename by name and confirm it. Covers both hazards a rename
--- carries: taking back a name another entry retired, and the per-entry cap
--- evicting the oldest former name to make room.
---@param kind string
---@param oldName string
---@param newName string
---@param onProceed fun()
function OneWoW_GUI:ConfirmCatalogRename(kind, oldName, newName, onProceed)
    local entry = ns.SearchCatalog:Resolve(kind, oldName)
    if not entry then
        onProceed()
        return
    end
    self:ConfirmCatalogWrite(ns.SearchCatalog:PreflightRename(kind, entry.id, newName), onProceed)
end

--- Preflight deleting a provider-owned entry by id, then confirm.
---
--- For owners that hold ids rather than display names, and that have a question
--- of their own to ask — a Bags category takes its items with it, which the
--- reference report says nothing about. Pass it as `opts.prompt` and it leads.
---@param kind string
---@param id string|nil
---@param onProceed fun()
---@param opts table|nil
function OneWoW_GUI:ConfirmCatalogDeleteById(kind, id, onProceed, opts)
    if not id then
        onProceed()
        return
    end
    self:ConfirmCatalogWrite(ns.SearchCatalog:PreflightDelete(kind, id), onProceed, opts)
end

--- Preflight renaming a provider-owned entry by id, then confirm.
---@param kind string
---@param id string|nil
---@param newName string|nil
---@param onProceed fun()
function OneWoW_GUI:ConfirmCatalogRenameById(kind, id, newName, onProceed)
    if not id or not newName then
        onProceed()
        return
    end
    self:ConfirmCatalogWrite(ns.SearchCatalog:PreflightRename(kind, id, newName), onProceed)
end

--- Preflight taking a name that may be another entry's former name, then
--- confirm. `exceptId` excludes the entry being edited from the clash check.
---@param kind string
---@param name string
---@param exceptId string|nil
---@param onProceed fun()
function OneWoW_GUI:ConfirmCatalogClaim(kind, name, exceptId, onProceed)
    self:ConfirmCatalogWrite(ns.SearchCatalog:PreflightClaim(kind, name, exceptId), onProceed)
end
