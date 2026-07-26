local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local ipairs = ipairs
local tinsert = tinsert
local tconcat = table.concat
local wipe = wipe
local format = string.format
local min = math.min
local max = math.max

-- Owner token for settings callbacks; this file publishes onto OneWoW_GUI rather
-- than owning a module table of its own.
local CatalogConfirm = {}

-- ============================================================================
-- Catalog write confirmation
-- ============================================================================
-- Loads after GUI/Settings.lua (registers settings callbacks at file scope) and
-- after GUI/Fonts.lua (CreateFS), so it sits last in the GUI block of the TOC.
--
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
-- Built as a dialog with real rows rather than a StaticPopup. A StaticPopup
-- centre-justifies its text, so any indent-based structure collapses into a
-- centred blob; it will not grow, so headers wrap mid-phrase; and it offers one
-- font at one colour, so a header, a store name and an item name all look alike.
-- Every one of those was visible in the first screenshot of a real report.

-- TODO (Phase 8D): move to locale keys across all 11 locales. Kept inline for
-- now so the strings can settle while 8B-2 and 8C move them around; this table is
-- the single lookup point that pass has to relocate.
local STRINGS = {
    TITLE = "OneWoW",

    -- Named per action: a button that says what it will do is harder to click by
    -- reflex than one that always says the same thing.
    PROCEED_DEFAULT = "Save anyway",
    PROCEED_DELETE  = "Delete anyway",
    PROCEED_RENAME  = "Rename anyway",
    PROCEED_CLAIM   = "Use this name",

    -- Plain "(s)" rather than WoW's |4singular:plural; markup: the phrasing is
    -- placeholder English that Phase 8D replaces per locale anyway, and several
    -- of the target languages do not pluralize the way that markup assumes.
    HEADER_DELETED = 'Deleting "%s" will break %d reference(s):',
    HEADER_RECLAIMED = 'The name "%s" is still in use as a former name. Taking it back silently changes what %d reference(s) mean:',
    HEADER_CAPPED = 'Renaming drops the oldest former name "%s" to make room, and %d reference(s) still use it:',

    -- Same three, for a name that only survives inside a profile or a snapshot.
    HEADER_DELETED_RESTORABLE = 'Deleting "%s" breaks nothing right now.',
    HEADER_RECLAIMED_RESTORABLE = 'Taking back the name "%s" changes nothing right now.',
    HEADER_CAPPED_RESTORABLE = 'Dropping the former name "%s" breaks nothing right now.',

    RECLAIM_TAIL = "If the new entry is later deleted, this name resolves to nothing at all — the old redirect does not come back.",

    RESTORABLE_HEADER = "Not broken now, but stored in states you can return to:",
    RESTORABLE_TAIL = "Nothing changes until one of these is loaded — then the text above comes back with nothing behind it.",

    MORE = "...and %d more",
    INCOMPLETE = "%d other addon(s) not loaded, so this list may be incomplete: %s",

    NOTHING = "Nothing else refers to this.",
}

local REASON_HEADER = {
    deleted   = STRINGS.HEADER_DELETED,
    reclaimed = STRINGS.HEADER_RECLAIMED,
    capped    = STRINGS.HEADER_CAPPED,
}

local REASON_HEADER_RESTORABLE = {
    deleted   = STRINGS.HEADER_DELETED_RESTORABLE,
    reclaimed = STRINGS.HEADER_RECLAIMED_RESTORABLE,
    capped    = STRINGS.HEADER_CAPPED_RESTORABLE,
}

local PROCEED_LABEL = {
    delete = STRINGS.PROCEED_DELETE,
    rename = STRINGS.PROCEED_RENAME,
    claim  = STRINGS.PROCEED_CLAIM,
}

-- Long enough to be useful, short enough that the dialog stays scannable.
local MAX_USAGES_PER_GROUP = 6

local DIALOG_WIDTH = 540
local DIALOG_MIN_HEIGHT = 200
local DIALOG_MAX_HEIGHT = 560

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
            Row(rows, "usage", format(STRINGS.MORE, #group.usages - shown))
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
                local header = REASON_HEADER[loss.reason] or REASON_HEADER.deleted
                Row(rows, "header", format(header, loss.name, refs.total))
                AppendGroups(rows, refs.groups)
                if loss.reason == "reclaimed" then
                    Row(rows, "note", STRINGS.RECLAIM_TAIL)
                end
            elseif refs.restorableTotal > 0 then
                -- No live usage, so lead with the reassurance rather than a
                -- breakage headline that would be untrue.
                local header = REASON_HEADER_RESTORABLE[loss.reason] or REASON_HEADER_RESTORABLE.deleted
                Row(rows, "header", format(header, loss.name))
            end
            if refs.restorableTotal > 0 then anyRestorable = true end
        end
    end

    if anyRestorable then
        Row(rows, "divider")
        Row(rows, "header", STRINGS.RESTORABLE_HEADER)
        for _, loss in ipairs(report.losses or {}) do
            local refs = loss.references
            if refs and refs.restorableTotal > 0 then
                AppendGroups(rows, refs.restorableGroups)
            end
        end
        Row(rows, "note", STRINGS.RESTORABLE_TAIL)
    end

    -- A disabled unit's SavedVariables are not loaded, so its references are
    -- invisible to the walk that produced this. Saying so beats presenting a
    -- lower bound as if it were the whole picture.
    local incomplete = report.incomplete
    if incomplete and #incomplete > 0 then
        Row(rows, "divider")
        Row(rows, "note", format(STRINGS.INCOMPLETE, #incomplete, tconcat(incomplete, ", ")))
    end

    return rows
end

-- ---- Rendering ----

local ROW_STYLE = {
    prompt = { size = 13, color = "TEXT_PRIMARY",   indent = 0,  gapAbove = 4 },
    header = { size = 12, color = "TEXT_PRIMARY",   indent = 0,  gapAbove = 10 },
    source = { size = 12, color = "ACCENT_PRIMARY", indent = 8,  gapAbove = 6 },
    usage  = { size = 11, color = "TEXT_SECONDARY", indent = 24, gapAbove = 1 },
    note   = { size = 11, color = "TEXT_MUTED",     indent = 0,  gapAbove = 8 },
}

local DIVIDER_GAP = 9

-- One dialog reused across calls; lazy on first use. Rows are pooled because a
-- report is rebuilt from scratch every time it is shown.
local _dialog
local _rowPool = {}
local _linePool = {}
local _onProceed

local function AcquireRow(parent, index)
    local fs = _rowPool[index]
    if not fs then
        fs = OneWoW_GUI:CreateFS(parent, 12, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(false)
        _rowPool[index] = fs
    end
    return fs
end

local function AcquireLine(parent, index)
    local tex = _linePool[index]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetHeight(1)
        _linePool[index] = tex
    end
    return tex
end

local function ReleaseFrom(pool, index)
    for i = index, #pool do
        pool[i]:Hide()
    end
end

--- Lay the rows into the scroll content and return the total height used.
---@param content table
---@param rows table[]
---@return number height
local function RenderRows(content, rows)
    local width = max(1, DIALOG_WIDTH - 60)
    local y = 0
    local shown, lines = 0, 0

    for _, row in ipairs(rows) do
        if row.kind == "divider" then
            y = y + DIVIDER_GAP
            lines = lines + 1
            local tex = AcquireLine(content, lines)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            tex:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            tex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tex:Show()
            y = y + 1 + DIVIDER_GAP
        else
            local style = ROW_STYLE[row.kind] or ROW_STYLE.note
            shown = shown + 1
            local fs = AcquireRow(content, shown)
            OneWoW_GUI:ApplyFont(fs, style.size)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor(style.color))
            fs:SetWidth(width - style.indent)
            fs:SetText(row.text or "")
            fs:ClearAllPoints()
            y = y + style.gapAbove
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", style.indent, -y)
            fs:Show()
            y = y + max(fs:GetStringHeight(), 1)
        end
    end

    ReleaseFrom(_rowPool, shown + 1)
    ReleaseFrom(_linePool, lines + 1)
    return y
end

local function EnsureDialog()
    if _dialog then return _dialog end

    _dialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_GUI_CatalogConfirmDialog",
        title = STRINGS.TITLE,
        width = DIALOG_WIDTH,
        height = DIALOG_MIN_HEIGHT,
        movable = true,
        escClose = true,
        showBrand = true,
        showScrollFrame = true,
        -- Closing by ESC or the X is a decline. Drop the callback so a later
        -- report cannot inherit the previous one's action.
        onClose = function() _onProceed = nil end,
        buttons = {
            {
                text = CANCEL,
                onClick = function(frame) frame:Hide() end,
            },
            {
                text = STRINGS.PROCEED_DEFAULT,
                color = { OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL") },
                onClick = function(frame)
                    frame:Hide()
                    local fn = _onProceed
                    _onProceed = nil
                    if fn then fn() end
                end,
            },
        },
    })

    -- Cancel is the safe default, so it leads; the destructive action sits right,
    -- where a reflex click is less likely to land.
    _dialog.proceedButton = _dialog.buttons[2]
    return _dialog
end

-- The danger colour and the pooled rows' fonts are baked when the dialog is
-- built, so a theme or font change has to drop it rather than restyle it. Same
-- treatment as the CopyPaste dialogs; the next confirmation rebuilds.
local function DropDialog()
    if not _dialog then return end
    _dialog.frame:Hide()
    _dialog = nil
    _onProceed = nil
    wipe(_rowPool)
    wipe(_linePool)
end
OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", CatalogConfirm, DropDialog)
OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", CatalogConfirm, DropDialog)
OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", CatalogConfirm, DropDialog)

--- Show the report and run `onProceed` only if the user accepts.
---@param report table|nil
---@param onProceed fun()
---@param opts table
local function ShowReport(report, onProceed, opts)
    local dialog = EnsureDialog()
    _onProceed = onProceed

    dialog.proceedButton:SetFitText(opts.proceedText
        or (report and PROCEED_LABEL[report.action])
        or STRINGS.PROCEED_DEFAULT)

    local rows = BuildRows(report, opts)
    local used = RenderRows(dialog.scrollContent, rows)
    dialog.scrollContent:SetHeight(max(used, 1))

    -- Title bar + button row + scroll insets. Grow to the content, then clamp so
    -- a report naming forty categories cannot run off the screen.
    local chrome = OneWoW_GUI.Constants.GUI.TITLEBAR_HEIGHT + 48 + 24
    dialog.frame:SetHeight(min(max(used + chrome, DIALOG_MIN_HEIGHT), DIALOG_MAX_HEIGHT))
    dialog.frame:Show()
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
