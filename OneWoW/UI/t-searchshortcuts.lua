local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local UI = ns.UI
local SE = ns.SearchExpand
local SC = ns.SearchCatalog
local PE = ns.PredicateEngine

local ipairs = ipairs
local sort = sort
local tinsert = tinsert
local tconcat = table.concat
local strlower = string.lower
local strtrim = strtrim
local strfind = string.find
local strsub = string.sub
local format = string.format
local max = math.max
local min = math.min

local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show
local CreateFrame = CreateFrame
local GameTooltip = GameTooltip

-- ============================================================================
-- Search Shortcuts
-- ============================================================================
-- Master–detail editor over the whole search catalog.
--
-- Tokens and saved expressions used to be two sections with two row types,
-- because a token was an alias for one built-in keyword and a SAVED was a free
-- expression. Since Phase 2 a token body is an arbitrary expression too, so the
-- only real difference left is how a reference to it is written — `#name` versus
-- `SAVED(Name)`.
--
-- Categories appear read-only. They are Bags' data and are edited there, but
-- they resolve through the same catalog and can be referenced by the same
-- expressions, so leaving them out made the list a partial answer to "what can I
-- write in a search box, and what is using it".
--
-- Writes only happen on Save (or Delete). Switching selection silently discards
-- unsaved edits. New creates an in-memory draft until the first Save.

local KIND_ORDER = { "token", "saved", "category" }

local KIND_RANK = {}
for i, kind in ipairs(KIND_ORDER) do
    KIND_RANK[kind] = i
end

local KIND_REF = {
    token    = function(name) return "#" .. name end,
    saved    = function(name) return "SAVED(" .. name .. ")" end,
    category = function(name) return "CATEGORY(" .. name .. ")" end,
}

local KIND_FILTER_LABEL_KEY = {
    token    = "SEARCH_SHORTCUTS_FILTER_TOKEN",
    saved    = "SEARCH_SHORTCUTS_FILTER_SAVED",
    category = "SEARCH_SHORTCUTS_FILTER_CATEGORY",
}

local KIND_TYPE_LABEL_KEY = {
    token    = "SEARCH_SHORTCUTS_TYPE_TOKEN",
    saved    = "SEARCH_SHORTCUTS_TYPE_SAVED",
    category = "SEARCH_SHORTCUTS_TYPE_CATEGORY",
}

local KIND_RAIL_COLOR = {
    token    = "KIND_TOKEN",
    saved    = "KIND_SAVED",
    category = "KIND_CATEGORY",
}

local KIND_EDITABLE = { token = true, saved = true, category = false }

local NAME_COL_WIDTH = 185
local ROW_HEIGHT = 36
local ROW_GAP = 2
local DETAIL_HEIGHT = 236
local USED_BY_INLINE_MAX = 2

local function RegisterPopups()
    if StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_DELETE"] then return end

    StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_DELETE"] = {
        text = "%s",
        button1 = DELETE,
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, data)
            if data and data.onAccept then data.onAccept() end
        end,
    }

    -- Non-blocking: the write already happened. Accepting replaces the body with
    -- a reference to the entry that already held it, which is the whole point —
    -- one definition, many callers.
    StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_DUPLICATE"] = {
        text = "%s",
        button1 = L["SEARCH_SHORTCUTS_DUPLICATE_ACCEPT"],
        button2 = L["SEARCH_SHORTCUTS_DUPLICATE_KEEP"],
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, data)
            if data and data.onAccept then data.onAccept() end
        end,
    }
end

local function StripHash(text)
    return strlower(strtrim((text or ""):gsub("^#", "")))
end

--- Built-in PE keywords for the insert menu. Display is primary then aliases;
--- `value` is always the canonical name (what gets inserted).
---@return table[]
local function BuildKeywordMenuItems()
    local items = {}
    if not PE or not PE.GetAllKeywords then return items end
    local entries = PE:GetAllKeywords()
    sort(entries, function(a, b)
        return (a.canonical or "") < (b.canonical or "")
    end)
    for _, entry in ipairs(entries) do
        local canonical = entry.canonical
        if canonical and canonical ~= "" then
            local labels = { "#" .. canonical }
            local filterParts = { canonical }
            for _, alias in ipairs(entry.aliases or {}) do
                tinsert(labels, "#" .. alias)
                tinsert(filterParts, alias)
            end
            tinsert(items, {
                value = canonical,
                text = tconcat(labels, ", "),
                filterKey = tconcat(filterParts, " "),
                fontSize = 12,
            })
        end
    end
    return items
end

--- Insert `#canonical` at the expression cursor. Adds a leading space when the
--- previous character is not already a separator.
---@param editBox EditBox
---@param canonical string
local function InsertKeywordAtCursor(editBox, canonical)
    if not editBox or not canonical or canonical == "" then return end
    local token = "#" .. canonical
    local text = editBox:GetText() or ""
    local pos = editBox:GetCursorPosition() or #text
    if pos < 0 then pos = 0 end
    if pos > #text then pos = #text end
    local before = strsub(text, 1, pos)
    local after = strsub(text, pos + 1)
    if before ~= "" and not before:match("[%s%(&|!]$") then
        token = " " .. token
    end
    editBox:SetText(before .. token .. after)
    editBox:SetFocus()
    editBox:SetCursorPosition(pos + #token)
end

-- Wired once the editor widgets exist (ReportError / CommitBody need them).
local ShowFieldError ---@type fun(kind: string, errKey: string|nil, field: "name"|"body"|nil)
local ClearFieldErrors ---@type fun()

local BODY_ERROR_KEYS = {
    CATALOG_EMPTY_BODY = true,
}

--- Show a catalog write failure on the Name or Expression field (no chat spam).
---@param kind string
---@param errKey string|nil
---@param field "name"|"body"|nil
local function ReportError(kind, errKey, field)
    if not errKey or not ShowFieldError then return end
    ShowFieldError(kind, errKey, field)
end

--- Offer to replace a freshly written body with a reference to the entry that
--- already holds it. Fires after the save, never blocks it.
---@param kind string
---@param entry table
local function OfferDuplicateReference(kind, entry)
    local other, otherKind = SC:FindDuplicateBody(entry.body, kind, entry.id)
    if not other or not otherKind then return end

    local ref = KIND_REF[otherKind](other.name)
    local text = format(L["SEARCH_SHORTCUTS_DUPLICATE_TITLE"], ref)
        .. "\n\n" .. format(L["SEARCH_SHORTCUTS_DUPLICATE_BODY"], ref)

    StaticPopup_Show("ONEWOW_SEARCH_SHORTCUT_DUPLICATE", text, nil, {
        onAccept = function()
            local updated, err = SC:Set(kind, entry.name, ref)
            if not updated then ReportError(kind, err) end
        end,
    })
end

--- Write a body and surface anything worth saying about the result.
---@param kind string
---@param name string
---@param body string
---@return table|nil entry
local function CommitBody(kind, name, body)
    local entry, err = SC:Set(kind, name, body)
    if not entry then
        ReportError(kind, err)
        return nil
    end
    OfferDuplicateReference(kind, entry)
    return entry
end

local LINT_STATUS_NOTE = {
    missing = L["CATALOG_LINT_STATUS_MISSING"],
    former  = L["CATALOG_LINT_STATUS_FORMER"],
    empty   = L["CATALOG_LINT_STATUS_EMPTY"],
}

local LINT_KEY = "catalog_lint"
local PRUNE_KEY = "catalog_prune"
local PRUNE_EMPTY_KEY = "catalog_prune_empty"
local REFS_KEY = "catalog_refs"

local function Row(rows, kind, text)
    tinsert(rows, { kind = kind, text = text })
end

local function BuildLintRows()
    local findings, incomplete = SC:Lint()
    local rows = {}

    if #findings > 0 then
        Row(rows, "header", format(L["CATALOG_LINT_HEADER"], #findings))

        local byStatus = {}
        local statusOrder = {}
        for _, f in ipairs(findings) do
            local bucket = byStatus[f.status]
            if not bucket then
                bucket = {}
                byStatus[f.status] = bucket
                tinsert(statusOrder, f.status)
            end
            tinsert(bucket, f)
        end

        for _, status in ipairs(statusOrder) do
            Row(rows, "note", LINT_STATUS_NOTE[status] or status)
            for _, f in ipairs(byStatus[status]) do
                Row(rows, "source", format("%s (%s)", KIND_REF[f.kind](f.name),
                    f.sourceLabel or "?"))
                Row(rows, "usage", f.label or "?")
            end
        end
    end

    local extras = SC:LintExtras()
    if #extras > 0 then
        if #rows > 0 then Row(rows, "divider") end
        Row(rows, "header", L["CATALOG_LINT_EXTRAS_HEADER"])
        for _, group in ipairs(extras) do
            Row(rows, "source", group.sourceLabel or "?")
            for _, finding in ipairs(group.findings) do
                Row(rows, "usage", format("%s — %s", finding.label or "?", finding.note or ""))
            end
        end
    end

    if #rows == 0 then
        Row(rows, "header", L["CATALOG_LINT_CLEAN"])
    end

    if incomplete and #incomplete > 0 then
        Row(rows, "divider")
        Row(rows, "note", format(L["CATALOG_LINT_INCOMPLETE"], #incomplete, tconcat(incomplete, ", ")))
    end

    return rows
end

local ShowLint

local function ShowPrunePreview()
    local count, blocked, dropped = SC:PruneFormerNames({ dryRun = true })
    local rows = {}

    if not count then
        Row(rows, "header", format(L["CATALOG_PRUNE_BLOCKED"], tconcat(blocked or {}, ", ")))
    elseif count == 0 then
        Row(rows, "header", L["CATALOG_PRUNE_NONE"])
    else
        Row(rows, "header", format(L["CATALOG_PRUNE_HEADER"], count))
        for _, d in ipairs(dropped) do
            Row(rows, "usage", format(L["CATALOG_PRUNE_ITEM"],
                KIND_REF[d.kind](d.name), KIND_REF[d.kind](d.owner or "?")))
        end
        Row(rows, "divider")
        Row(rows, "note", L["CATALOG_PRUNE_TAIL"])
    end

    local canApply = (count or 0) > 0
    if canApply then
        OneWoW_GUI:ShowReportDialog({
            key = PRUNE_KEY,
            title = L["CATALOG_PRUNE_TITLE"],
            rows = rows,
            buttons = {
                { text = CANCEL },
                {
                    text = L["CATALOG_PRUNE_CONFIRM"],
                    danger = true,
                    onClick = function()
                        SC:PruneFormerNames({})
                        OneWoW_GUI:UpdateReportDialog(LINT_KEY, BuildLintRows())
                    end,
                },
            },
        })
    else
        -- Single dismiss control — Cancel+Close both did nothing useful.
        OneWoW_GUI:ShowReportDialog({
            key = PRUNE_EMPTY_KEY,
            title = L["CATALOG_PRUNE_TITLE"],
            rows = rows,
            buttons = {
                { text = CLOSE },
            },
        })
    end
end

ShowLint = function()
    OneWoW_GUI:ShowReportDialog({
        key = LINT_KEY,
        title = L["CATALOG_LINT_TITLE"],
        rows = BuildLintRows(),
        buttons = {
            { text = CLOSE },
            { text = L["CATALOG_PRUNE_BUTTON"], onClick = ShowPrunePreview },
        },
    })
end

---@param label string
---@return string|nil kind
---@return string|nil name
local function ParseKindRef(label)
    if type(label) ~= "string" then return nil end
    local token = label:match("^#([%w_]+)$")
    if token then return "token", token end
    local saved = label:match("^SAVED%((.+)%)$")
    if saved then return "saved", saved end
    local category = label:match("^CATEGORY%((.+)%)$")
    if category then return "category", category end
    return nil
end

--- Catalog entries that reference this name (for inline Used by links).
---@param kind string
---@param name string
---@param formerNames string[]|nil
---@return table[] refs { kind, name, label }
---@return table report
local function CollectCatalogUsers(kind, name, formerNames)
    local names = { name }
    if formerNames then
        for _, former in ipairs(formerNames) do
            tinsert(names, former)
        end
    end

    local seen = {}
    local refs = {}
    local primaryReport = nil

    for _, probe in ipairs(names) do
        local report = SC:FindReferences(kind, probe)
        if not primaryReport then primaryReport = report end
        for _, group in ipairs(report.groups or {}) do
            for _, usage in ipairs(group.usages or {}) do
                local refKind, refName
                if group.id == "catalog_token" or group.id == "catalog_saved" then
                    refKind, refName = ParseKindRef(usage.label)
                elseif group.id == "bags_categories" then
                    refKind, refName = "category", usage.label
                end
                if refKind and refName then
                    local key = refKind .. "\0" .. strlower(refName)
                    if not seen[key] then
                        seen[key] = true
                        tinsert(refs, {
                            kind = refKind,
                            name = refName,
                            label = KIND_REF[refKind](refName),
                        })
                    end
                end
            end
        end
    end

    return refs, primaryReport or { total = 0, groups = {}, incomplete = {} }
end

local function BuildRefsReportRows(report)
    local rows = {}
    local total = report.total or 0
    if total > 0 then
        Row(rows, "header", format(L["SEARCH_SHORTCUTS_REFS_HEADER"], total))
        for _, group in ipairs(report.groups or {}) do
            Row(rows, "source", group.sourceLabel or "?")
            for _, usage in ipairs(group.usages or {}) do
                Row(rows, "usage", usage.label or "?")
            end
        end
    else
        Row(rows, "header", L["SEARCH_SHORTCUTS_USED_BY_NONE"])
    end

    if report.restorableTotal and report.restorableTotal > 0 then
        Row(rows, "divider")
        Row(rows, "note", L["CATALOG_WRITE_RESTORABLE_HEADER"])
        for _, group in ipairs(report.restorableGroups or {}) do
            Row(rows, "source", group.sourceLabel or "?")
            for _, usage in ipairs(group.usages or {}) do
                Row(rows, "usage", usage.label or "?")
            end
        end
    end

    local incomplete = report.incomplete
    if incomplete and #incomplete > 0 then
        Row(rows, "divider")
        Row(rows, "note", format(L["CATALOG_WRITE_INCOMPLETE"], #incomplete, tconcat(incomplete, ", ")))
    end

    return rows
end

local function OpenInBags(catId)
    OneWoW:WithAddon("OneWoW_Bags", function()
        if OneWoW_Bags_API and OneWoW_Bags_API.OpenCategoryManager then
            OneWoW_Bags_API.OpenCategoryManager(catId)
        else
            print(L["SEARCH_SHORTCUTS_BAGS_UNAVAILABLE"])
        end
    end, function()
        print(L["SEARCH_SHORTCUTS_BAGS_UNAVAILABLE"])
    end)
end

function UI:CreateSearchShortcutsTab(parent)
    RegisterPopups()

    -- Everything holding a frame lives in this scope, not at file scope. The
    -- builder runs again on every UI:FullReset() — theme, language and minimap
    -- changes all trigger one — and a cache that outlives the rebuild keeps rows
    -- parented to a window that no longer exists.
    local rows = {}
    local listContent, emptyText
    local activeKind = nil ---@type string|nil
    local searchNeedle = ""
    local selectedKey = nil ---@type string|nil  "kind:id" or "draft:token"/"draft:saved"
    local draft = nil ---@type { kind: string, name: string, body: string }|nil
    local loadedName = ""
    local loadedBody = ""
    local suppressDirty = false
    local RefreshRows, SelectItem, SyncDetail, SyncDirtyButtons

    local root = CreateFrame("Frame", nil, parent)
    root:SetAllPoints(parent)

    local C = OneWoW_GUI.Constants

    -- ---- Header ----

    local title = OneWoW_GUI:CreateFS(root, 16)
    title:SetPoint("TOPLEFT", root, "TOPLEFT", 12, -10)
    title:SetText(L["SEARCH_SHORTCUTS_TITLE"])
    title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local desc = OneWoW_GUI:CreateFS(root, 11)
    desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    desc:SetPoint("TOPRIGHT", root, "TOPRIGHT", -12, -28)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(L["SEARCH_SHORTCUTS_DESC"])
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    -- ---- Toolbar ----
    -- Row 1: search + type filter. Row 2: New (left) + lint link (right), flush
    -- with the list panel edges and spaced below row 1.

    local toolbar = CreateFrame("Frame", nil, root)
    toolbar:SetPoint("TOPLEFT", root, "TOPLEFT", 12, -52)
    toolbar:SetPoint("TOPRIGHT", root, "TOPRIGHT", -12, -52)
    toolbar:SetHeight(60)

    local searchBox = OneWoW_GUI:CreateEditBox(toolbar, {
        placeholderText = L["SEARCH_SHORTCUTS_FILTER_PLACEHOLDER"],
        height = 26,
        showClear = true,
        onTextChanged = function(text)
            searchNeedle = strlower(strtrim(text or ""))
            RefreshRows()
        end,
        onClear = function()
            searchNeedle = ""
            RefreshRows()
        end,
    })
    searchBox:SetPoint("TOPLEFT", toolbar, "TOPLEFT", 0, 0)
    searchBox:SetPoint("TOPRIGHT", toolbar, "TOPRIGHT", -148, 0)

    local typeDropdown, typeText = OneWoW_GUI:CreateDropdown(toolbar, {
        width = 140,
        height = 26,
        text = L["SEARCH_SHORTCUTS_FILTER_ALL_TYPES"],
    })
    typeDropdown:SetPoint("TOPRIGHT", toolbar, "TOPRIGHT", 0, 0)
    OneWoW_GUI:AttachFilterMenu(typeDropdown, {
        searchable = false,
        buildItems = function()
            local items = {
                { value = nil, text = L["SEARCH_SHORTCUTS_FILTER_ALL_TYPES"] },
            }
            for _, kind in ipairs(KIND_ORDER) do
                tinsert(items, { value = kind, text = L[KIND_FILTER_LABEL_KEY[kind]] })
            end
            return items
        end,
        onSelect = function(value, displayText)
            activeKind = value
            typeText:SetText(displayText)
            RefreshRows()
        end,
        getActiveValue = function() return activeKind end,
    })

    local newBtn = OneWoW_GUI:CreateFitTextButton(toolbar, {
        text = NEW,
        height = 26,
        minWidth = 56,
    })
    newBtn:SetPoint("BOTTOMLEFT", toolbar, "BOTTOMLEFT", 0, 0)
    OneWoW_GUI:AttachFilterMenu(newBtn, {
        searchable = false,
        menuWidth = 180,
        buildItems = function()
            return {
                { value = "token", text = L["SEARCH_SHORTCUTS_NEW_TOKEN"], fontSize = 12 },
                { value = "saved", text = L["SEARCH_SHORTCUTS_NEW_SAVED"], fontSize = 12 },
            }
        end,
        onSelect = function(value)
            draft = { kind = value, name = "", body = "" }
            selectedKey = "draft:" .. value
            if activeKind and activeKind ~= value then
                activeKind = nil
                typeText:SetText(L["SEARCH_SHORTCUTS_FILTER_ALL_TYPES"])
            end
            RefreshRows()
            SelectItem(selectedKey)
        end,
    })

    local lintLink = OneWoW_GUI:CreateTextLink(toolbar, {
        text = L["SEARCH_SHORTCUTS_LINT_LINK"],
        fontSize = 11,
        onClick = ShowLint,
    })
    lintLink:SetPoint("BOTTOMRIGHT", toolbar, "BOTTOMRIGHT", 0, 4)

    -- ---- Detail (bottom, fixed height) ----

    local detail = CreateFrame("Frame", nil, root, "BackdropTemplate")
    detail:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 12, 10)
    detail:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -12, 10)
    detail:SetHeight(DETAIL_HEIGHT)
    detail:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
    detail:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    detail:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local placeholder = OneWoW_GUI:CreateFS(detail, 12)
    placeholder:SetPoint("CENTER", detail, "CENTER", 0, 0)
    placeholder:SetText(L["SEARCH_SHORTCUTS_SELECT_PLACEHOLDER"])
    placeholder:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local editor = CreateFrame("Frame", nil, detail)
    editor:SetAllPoints(detail)
    editor:Hide()

    local typePill = OneWoW_GUI:CreateFS(editor, 10)
    typePill:SetPoint("TOPLEFT", editor, "TOPLEFT", 12, -10)
    typePill:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    -- Forward-declared: Copy Name's OnClick closes over nameBox before it is created.
    local nameBox

    local copyNameLink = OneWoW_GUI:CreateTextLink(editor, {
        text = COPY_NAME,
        fontSize = 11,
        onClick = function()
            local kind = editor._kind
            if not kind then return end
            local nameText = nameBox:GetSearchText() or ""
            if nameText == "" then nameText = loadedName end
            if kind == "token" then nameText = StripHash(nameText) end
            nameText = strtrim(nameText)
            if nameText == "" then return end
            OneWoW_GUI:ShowCopyURLDialog(COPY_NAME, KIND_REF[kind](nameText))
        end,
    })
    copyNameLink:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -12, -10)

    local nameLabel = OneWoW_GUI:CreateFS(editor, 11)
    nameLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 12, -34)
    nameLabel:SetText(NAME)
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local exprLabel = OneWoW_GUI:CreateFS(editor, 11)
    exprLabel:SetPoint("TOPLEFT", editor, "TOPLEFT", 210, -34)
    exprLabel:SetText(L["SEARCH_SHORTCUTS_EXPRESSION_LABEL"])
    exprLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    nameBox = OneWoW_GUI:CreateEditBox(editor, {
        height = 26,
        onTextChanged = function()
            if suppressDirty then return end
            if ClearFieldErrors then ClearFieldErrors("name") end
            SyncDirtyButtons()
        end,
    })
    nameBox:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
    nameBox:SetWidth(185)

    local nameHint = OneWoW_GUI:CreateFS(editor, 10)
    nameHint:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -3)
    nameHint:SetPoint("RIGHT", nameBox, "RIGHT", 0, 0)
    nameHint:SetJustifyH("LEFT")
    nameHint:SetWordWrap(true)
    nameHint:SetText(L["SEARCH_SHORTCUTS_TOKEN_HINT"])
    nameHint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    local nameError = OneWoW_GUI:CreateFS(editor, 10)
    nameError:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -3)
    nameError:SetPoint("RIGHT", nameBox, "RIGHT", 0, 0)
    nameError:SetJustifyH("LEFT")
    nameError:SetWordWrap(true)
    nameError:SetTextColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
    nameError:Hide()

    local exprContainer = OneWoW_GUI:CreateFrame(editor, {
        backdrop = C.BACKDROP_INNER_NO_INSETS,
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    exprContainer:SetPoint("TOPLEFT", exprLabel, "BOTTOMLEFT", 0, -4)
    exprContainer:SetPoint("TOPRIGHT", editor, "TOPRIGHT", -12, -56)
    exprContainer:SetHeight(72)

    local _, exprBox = OneWoW_GUI:CreateScrollEditBox(exprContainer, {
        fontSize = 12,
        onTextChanged = function(_, userInput)
            if suppressDirty or not userInput then return end
            if ClearFieldErrors then ClearFieldErrors("body") end
            SyncDirtyButtons()
        end,
    })

    local exprError = OneWoW_GUI:CreateFS(editor, 10)
    exprError:SetJustifyH("LEFT")
    exprError:SetWordWrap(true)
    exprError:SetTextColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
    exprError:Hide()

    local keywordDropdown, keywordDropText = OneWoW_GUI:CreateDropdown(editor, {
        width = 200,
        height = 26,
        text = L["SEARCH_SHORTCUTS_INSERT_KEYWORD"],
    })
    keywordDropdown:SetPoint("TOPLEFT", exprContainer, "BOTTOMLEFT", 0, -6)
    keywordDropdown:Hide()
    OneWoW_GUI:AttachFilterMenu(keywordDropdown, {
        searchable = true,
        menuWidth = 320,
        menuHeight = 314,
        buildItems = BuildKeywordMenuItems,
        getActiveValue = function() return nil end,
        onSelect = function(canonical)
            keywordDropText:SetText(L["SEARCH_SHORTCUTS_INSERT_KEYWORD"])
            keywordDropdown._activeValue = nil
            InsertKeywordAtCursor(exprBox, canonical)
            if ClearFieldErrors then ClearFieldErrors("body") end
            SyncDirtyButtons()
        end,
    })
    keywordDropdown:HookScript("OnEnter", function(myself)
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["SEARCH_SHORTCUTS_INSERT_KEYWORD"], 1, 1, 1)
        GameTooltip:AddLine(L["SEARCH_SHORTCUTS_INSERT_KEYWORD_TIP"], 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
        -- Default SharedTooltip fill still reads translucent over busy chrome; lock opaque.
        local r, g, b = OneWoW_GUI:GetThemeColor("BG_PRIMARY")
        GameTooltip.NineSlice:SetCenterColor(r, g, b, 1)
        GameTooltip:SetAlpha(1)
    end)
    keywordDropdown:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local openInBagsLink = OneWoW_GUI:CreateTextLink(editor, {
        text = L["SEARCH_SHORTCUTS_OPEN_IN_BAGS"],
        fontSize = 11,
        onClick = function()
            if editor._entry and editor._entry.id then
                OpenInBags(editor._entry.id)
            end
        end,
    })
    openInBagsLink:SetPoint("TOPLEFT", exprContainer, "BOTTOMLEFT", 0, -8)
    openInBagsLink:Hide()

    local function RelayoutExprSub()
        exprError:ClearAllPoints()
        exprError:SetPoint("RIGHT", exprContainer, "RIGHT", 0, 0)
        if keywordDropdown:IsShown() then
            exprError:SetPoint("TOPLEFT", keywordDropdown, "BOTTOMLEFT", 0, -3)
        else
            exprError:SetPoint("TOPLEFT", exprContainer, "BOTTOMLEFT", 0, -3)
        end
    end
    RelayoutExprSub()

    local formerText = OneWoW_GUI:CreateFS(editor, 10)
    formerText:SetPoint("TOPLEFT", nameHint, "BOTTOMLEFT", 0, -6)
    formerText:SetPoint("RIGHT", nameBox, "RIGHT", 0, 0)
    formerText:SetJustifyH("LEFT")
    formerText:SetWordWrap(true)
    formerText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

    --- Toggle name/expression fields between editable and category read-only.
    local function SetEditorFieldsReadOnly(readOnly)
        if readOnly then
            nameBox:Disable()
            nameBox:ClearFocus()
            nameBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
            exprBox:Disable()
            exprBox:ClearFocus()
            exprBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        else
            nameBox:Enable()
            nameBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
            exprBox:Enable()
            exprBox:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    local nameHasError, bodyHasError = false, false

    local function RelayoutNameSub()
        formerText:ClearAllPoints()
        formerText:SetPoint("RIGHT", nameBox, "RIGHT", 0, 0)
        if nameError:IsShown() then
            formerText:SetPoint("TOPLEFT", nameError, "BOTTOMLEFT", 0, -6)
        elseif nameHint:IsShown() then
            formerText:SetPoint("TOPLEFT", nameHint, "BOTTOMLEFT", 0, -6)
        else
            formerText:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -6)
        end
    end

    local function ApplyNameBorder()
        if nameHasError then
            nameBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
        elseif nameBox:HasFocus() then
            nameBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
        else
            nameBox:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end

    local function ApplyBodyBorder()
        if bodyHasError then
            exprContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
        else
            exprContainer:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
        end
    end

    ClearFieldErrors = function(which)
        if which == "name" or not which then
            nameHasError = false
            nameError:Hide()
            ApplyNameBorder()
            if editor._kind == "token" then
                nameHint:Show()
            else
                nameHint:Hide()
            end
            RelayoutNameSub()
        end
        if which == "body" or not which then
            bodyHasError = false
            exprError:Hide()
            ApplyBodyBorder()
        end
    end

    ShowFieldError = function(kind, errKey, field)
        if not errKey then return end
        local mapped = SE:MapCatalogError(kind, errKey)
        local msg = L[mapped] or mapped
        local target = field
        if not target then
            target = BODY_ERROR_KEYS[errKey] and "body" or "name"
        end
        if target == "body" then
            bodyHasError = true
            exprError:SetText(msg)
            exprError:Show()
            ApplyBodyBorder()
        else
            nameHasError = true
            nameHint:Hide()
            nameError:SetText(msg)
            nameError:Show()
            ApplyNameBorder()
            RelayoutNameSub()
        end
    end

    nameBox:HookScript("OnEditFocusGained", function()
        ApplyNameBorder()
    end)
    nameBox:HookScript("OnEditFocusLost", function()
        ApplyNameBorder()
    end)

    local shadowedNote = OneWoW_GUI:CreateFS(editor, 10)
    shadowedNote:SetPoint("TOPLEFT", formerText, "BOTTOMLEFT", 0, -4)
    shadowedNote:SetPoint("RIGHT", editor, "RIGHT", -12, 0)
    shadowedNote:SetJustifyH("LEFT")
    shadowedNote:SetWordWrap(true)
    shadowedNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_WARNING"))
    shadowedNote:Hide()

    local usedByLabel = OneWoW_GUI:CreateFS(editor, 11)
    usedByLabel:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 12, 42)
    usedByLabel:SetText(L["SEARCH_SHORTCUTS_USED_BY"])
    usedByLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    local usedByRow = CreateFrame("Frame", nil, editor)
    usedByRow:SetPoint("LEFT", usedByLabel, "RIGHT", 8, 0)
    usedByRow:SetPoint("RIGHT", editor, "RIGHT", -12, 0)
    usedByRow:SetHeight(16)
    local usedByLinks = {}
    local usedBySeps = {}

    local function AcquireUsedBySep(index)
        local sep = usedBySeps[index]
        if sep then return sep end
        sep = OneWoW_GUI:CreateFS(usedByRow, 11)
        sep:SetText(" / ")
        sep:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        usedBySeps[index] = sep
        return sep
    end

    local function ClearUsedBySeps()
        for _, sep in ipairs(usedBySeps) do
            sep:Hide()
        end
    end

    local actionBar = OneWoW_GUI:CreateActionBar(editor, {
        yOffset = 0,
        insetX = 12,
        gap = 16,
        rowHeight = 28,
    })
    actionBar:ClearAllPoints()
    actionBar:SetPoint("BOTTOMLEFT", editor, "BOTTOMLEFT", 0, 8)
    actionBar:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", 0, 8)

    local deleteBtn = OneWoW_GUI:CreateFitTextButton(actionBar.left, {
        text = DELETE,
        height = 26,
        danger = true,
    })
    deleteBtn:SetPoint("LEFT", actionBar.left, "LEFT", 12, 0)

    local saveBtn = OneWoW_GUI:CreateFitTextButton(actionBar.right, {
        text = SAVE,
        height = 26,
        minWidth = 64,
    })
    saveBtn:SetPoint("RIGHT", actionBar.right, "RIGHT", -12, 0)
    saveBtn:SetEnabled(false)

    local revertBtn = OneWoW_GUI:CreateFitTextButton(actionBar.right, {
        text = REVERT,
        height = 26,
        minWidth = 64,
    })
    revertBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    revertBtn:SetEnabled(false)

    -- ---- List ----

    local listFrame = CreateFrame("Frame", nil, root, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -8)
    listFrame:SetPoint("BOTTOMRIGHT", detail, "TOPRIGHT", 0, 8)
    listFrame:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
    listFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    listFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local listScroll, scrollContent = OneWoW_GUI:CreateScrollFrame(listFrame, {})
    listScroll:ClearAllPoints()
    listScroll:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -4, 4)
    listContent = scrollContent

    emptyText = OneWoW_GUI:CreateFS(listContent, 11)
    emptyText:SetPoint("TOPLEFT", listContent, "TOPLEFT", 8, -8)
    emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    -- ---- State helpers ----

    local function ItemKey(kind, entry)
        if entry and entry.id then
            return kind .. ":" .. entry.id
        end
        return nil
    end

    local function IsDirty()
        if not editor:IsShown() then return false end
        local kind = editor._kind
        if not kind or not KIND_EDITABLE[kind] then return false end
        local nameNow = kind == "token" and StripHash(nameBox:GetSearchText()) or strtrim(nameBox:GetSearchText() or "")
        local bodyNow = exprBox:GetText() or ""
        return nameNow ~= loadedName or bodyNow ~= loadedBody
    end

    SyncDirtyButtons = function()
        local dirty = IsDirty()
        local editable = editor._kind and KIND_EDITABLE[editor._kind]
        if editable then
            saveBtn:SetEnabled(dirty)
            revertBtn:SetEnabled(dirty)
            deleteBtn:Show()
            if editor._isDraft and draft then
                local nameText = nameBox:GetSearchText() or ""
                draft.name = editor._kind == "token" and StripHash(nameText) or strtrim(nameText)
                draft.body = exprBox:GetText() or ""
                for _, row in ipairs(rows) do
                    if row._key == selectedKey and row:IsShown() then
                        local display = KIND_REF[draft.kind](draft.name ~= "" and draft.name or "…")
                        row.nameText:SetText(display)
                        row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor(KIND_RAIL_COLOR[draft.kind] or "KIND_TOKEN"))
                        row.bodyText:SetText(draft.body or "")
                        break
                    end
                end
            end
        else
            saveBtn:SetEnabled(false)
            revertBtn:SetEnabled(false)
        end
        if actionBar.Refresh then actionBar:Refresh() end
    end

    local function ClearUsedBy()
        for _, link in ipairs(usedByLinks) do
            link:Hide()
        end
        ClearUsedBySeps()
    end

    local function ShowUsedBy(kind, entry)
        ClearUsedBy()
        local refs, report = CollectCatalogUsers(kind, entry.name, entry.formerNames)
        local x = 0
        local showCount = min(#refs, USED_BY_INLINE_MAX)
        local extra = #refs - showCount
        -- Prefer showing catalog refs; if none but report has other sources, show a single "N use(s)" link.
        if showCount == 0 then
            local total = report.total or 0
            if total > 0 then
                local link = usedByLinks[1]
                if not link then
                    link = OneWoW_GUI:CreateTextLink(usedByRow, { text = "", fontSize = 11 })
                    usedByLinks[1] = link
                end
                link:SetText(format(L["SEARCH_SHORTCUTS_USAGE"], total))
                link:SetScript("OnClick", function()
                    OneWoW_GUI:ShowReportDialog({
                        key = REFS_KEY,
                        title = L["SEARCH_SHORTCUTS_USED_BY"],
                        rows = BuildRefsReportRows(report),
                        buttons = { { text = CLOSE } },
                    })
                end)
                link:ClearAllPoints()
                link:SetPoint("LEFT", usedByRow, "LEFT", 0, 0)
                link:Show()
            else
                local none = usedByLinks[1]
                if not none then
                    none = OneWoW_GUI:CreateTextLink(usedByRow, { text = "", fontSize = 11 })
                    usedByLinks[1] = none
                end
                -- Non-clickable muted label via disabled link.
                none:SetText(L["SEARCH_SHORTCUTS_USED_BY_NONE"])
                none:SetEnabled(false)
                none:ClearAllPoints()
                none:SetPoint("LEFT", usedByRow, "LEFT", 0, 0)
                none:Show()
            end
            return
        end

        local sepIdx = 0
        for i = 1, showCount do
            if i > 1 then
                sepIdx = sepIdx + 1
                local sep = AcquireUsedBySep(sepIdx)
                sep:ClearAllPoints()
                sep:SetPoint("LEFT", usedByRow, "LEFT", x, 0)
                sep:Show()
                x = x + (sep:GetStringWidth() or 0)
            end
            local ref = refs[i]
            local link = usedByLinks[i]
            if not link then
                link = OneWoW_GUI:CreateTextLink(usedByRow, { text = "", fontSize = 11 })
                usedByLinks[i] = link
            end
            link:SetEnabled(true)
            link:SetText(ref.label)
            link:SetScript("OnClick", function()
                local target = SC:Resolve(ref.kind, ref.name)
                if target then
                    SelectItem(ItemKey(ref.kind, target))
                end
            end)
            link:ClearAllPoints()
            link:SetPoint("LEFT", usedByRow, "LEFT", x, 0)
            link:Show()
            x = x + (link:GetWidth() or 0)
        end

        if extra > 0 or (report.total or 0) > #refs then
            sepIdx = sepIdx + 1
            local sep = AcquireUsedBySep(sepIdx)
            sep:ClearAllPoints()
            sep:SetPoint("LEFT", usedByRow, "LEFT", x, 0)
            sep:Show()
            x = x + (sep:GetStringWidth() or 0)

            local idx = showCount + 1
            local more = usedByLinks[idx]
            if not more then
                more = OneWoW_GUI:CreateTextLink(usedByRow, { text = "", fontSize = 11 })
                usedByLinks[idx] = more
            end
            more:SetEnabled(true)
            more:SetText(format(L["SEARCH_SHORTCUTS_MORE_REFS"], max(extra, (report.total or 0) - showCount)))
            more:SetScript("OnClick", function()
                OneWoW_GUI:ShowReportDialog({
                    key = REFS_KEY,
                    title = L["SEARCH_SHORTCUTS_USED_BY"],
                    rows = BuildRefsReportRows(report),
                    buttons = { { text = CLOSE } },
                })
            end)
            more:ClearAllPoints()
            more:SetPoint("LEFT", usedByRow, "LEFT", x, 0)
            more:Show()
        end
    end

    local function LoadEditor(kind, entry, isDraft)
        suppressDirty = true
        editor._kind = kind
        editor._entry = entry
        editor._isDraft = isDraft and true or false
        ClearFieldErrors()

        typePill:SetText(L[KIND_TYPE_LABEL_KEY[kind]] or kind)
        typePill:SetTextColor(OneWoW_GUI:GetThemeColor(KIND_RAIL_COLOR[kind] or "KIND_TOKEN"))

        placeholder:Hide()
        editor:Show()

        if kind == "category" then
            nameLabel:Show()
            nameBox:Show()
            nameHint:Hide()
            copyNameLink:Show()
            exprContainer:Show()
            exprContainer:SetHeight(72)
            keywordDropdown:Hide()
            RelayoutExprSub()
            SetEditorFieldsReadOnly(true)
            nameBox:SetText(entry.name or "")
            exprBox:SetText(entry.body or "")
            exprBox:SetCursorPosition(0)
            openInBagsLink:Show()
            formerText:SetText("")
            formerText:Hide()
            shadowedNote:Hide()
            actionBar:Hide()
            loadedName = entry.name or ""
            loadedBody = entry.body or ""
            RelayoutNameSub()
            ShowUsedBy(kind, entry)
            suppressDirty = false
            SyncDirtyButtons()
            return
        end

        nameLabel:Show()
        nameBox:Show()
        copyNameLink:Show()
        exprContainer:Show()
        openInBagsLink:Hide()
        keywordDropdown:Show()
        keywordDropText:SetText(L["SEARCH_SHORTCUTS_INSERT_KEYWORD"])
        keywordDropdown._activeValue = nil
        RelayoutExprSub()
        actionBar:Show()
        SetEditorFieldsReadOnly(false)

        local name = entry.name or ""
        local body = entry.body or ""
        loadedName = name
        loadedBody = body

        nameBox:SetText(kind == "token" and name or name)
        exprBox:SetText(body)
        exprBox:SetCursorPosition(0)

        if kind == "token" then
            nameHint:Show()
            exprContainer:SetHeight(56)
        else
            nameHint:Hide()
            exprContainer:SetHeight(72)
        end
        RelayoutNameSub()

        local formers = entry.formerNames
        if formers and #formers > 0 then
            local refs = {}
            for _, formerName in ipairs(formers) do
                tinsert(refs, KIND_REF[kind](formerName))
            end
            formerText:SetText(format(L["SEARCH_SHORTCUTS_FORMER_NAMES"], tconcat(refs, ", ")))
            formerText:Show()
        else
            formerText:SetText("")
            formerText:Hide()
        end

        if kind == "token" and not isDraft and SE:IsTokenShadowed(name) then
            shadowedNote:SetText(L["SEARCH_SHORTCUTS_SHADOWED_TIP"])
            shadowedNote:Show()
        else
            shadowedNote:Hide()
        end

        ShowUsedBy(kind, entry)
        suppressDirty = false
        SyncDirtyButtons()

        if isDraft then
            nameBox:SetFocus()
        end
    end

    SelectItem = function(key)
        selectedKey = key
        if not key then
            draft = nil
            editor:Hide()
            placeholder:Show()
            ClearUsedBy()
            RefreshRows()
            return
        end

        if key:sub(1, 6) == "draft:" and draft then
            LoadEditor(draft.kind, draft, true)
            RefreshRows()
            return
        end

        local kind, id = key:match("^([^:]+):(.+)$")
        if kind and id then
            local entry = SC:GetById(kind, id)
            if entry then
                draft = nil
                LoadEditor(kind, entry, false)
            else
                selectedKey = nil
                editor:Hide()
                placeholder:Show()
            end
        end
        RefreshRows()
    end

    local function RevertEditor()
        if editor._isDraft and draft then
            draft.name = ""
            draft.body = ""
            LoadEditor(draft.kind, draft, true)
            return
        end
        if editor._entry and editor._kind then
            LoadEditor(editor._kind, editor._entry, false)
        end
    end

    local function DoSave()
        local kind = editor._kind
        if not kind or not KIND_EDITABLE[kind] then return end
        if not IsDirty() then return end

        ClearFieldErrors()

        local nameText = nameBox:GetSearchText() or ""
        local bodyText = exprBox:GetText() or ""
        local rawName = kind == "token" and StripHash(nameText) or strtrim(nameText)

        if strtrim(bodyText) == "" then
            ReportError(kind, "CATALOG_EMPTY_BODY", "body")
            return
        end

        local exceptId = (not editor._isDraft and editor._entry) and editor._entry.id or nil
        local name, nameErr = SC:ValidateWritableName(kind, rawName, exceptId)
        if not name then
            ReportError(kind, nameErr, "name")
            return
        end

        if editor._isDraft then
            OneWoW_GUI:ConfirmCatalogClaim(kind, name, nil, function()
                local entry = CommitBody(kind, name, bodyText)
                if entry then
                    draft = nil
                    selectedKey = ItemKey(kind, entry)
                    SelectItem(selectedKey)
                end
            end)
            return
        end

        local entry = editor._entry
        local nameChanged = name ~= loadedName
        local bodyChanged = bodyText ~= loadedBody

        local function AfterRename()
            if bodyChanged then
                local updated = CommitBody(kind, name, bodyText)
                if updated then
                    selectedKey = ItemKey(kind, updated)
                    SelectItem(selectedKey)
                end
            else
                local refreshed = SC:GetById(kind, entry.id)
                if refreshed then
                    selectedKey = ItemKey(kind, refreshed)
                    SelectItem(selectedKey)
                end
            end
        end

        if nameChanged then
            OneWoW_GUI:ConfirmCatalogRenameById(kind, entry.id, name, function()
                local ok, err = SC:Rename(kind, entry.id, name)
                if not ok then
                    ReportError(kind, err, "name")
                    return
                end
                loadedName = name
                AfterRename()
            end)
        elseif bodyChanged then
            local updated = CommitBody(kind, name, bodyText)
            if updated then
                selectedKey = ItemKey(kind, updated)
                SelectItem(selectedKey)
            end
        end
    end

    local function DoDelete()
        if editor._isDraft then
            draft = nil
            selectedKey = nil
            editor:Hide()
            placeholder:Show()
            RefreshRows()
            return
        end

        local kind, entry = editor._kind, editor._entry
        if not kind or not entry or not KIND_EDITABLE[kind] then return end

        local report = SC:PreflightDelete(kind, entry.id)
        if report then
            OneWoW_GUI:ConfirmCatalogWrite(report, function()
                SC:Delete(kind, entry.id)
                selectedKey = nil
                editor:Hide()
                placeholder:Show()
            end)
            return
        end
        local prompt = kind == "token"
            and L["SEARCH_SHORTCUT_ALIAS_DELETE"]:format(entry.name)
            or L["SEARCH_SHORTCUT_SAVED_DELETE"]:format(entry.name)
        StaticPopup_Show("ONEWOW_SEARCH_SHORTCUT_DELETE", prompt, nil, {
            onAccept = function()
                SC:Delete(kind, entry.id)
                selectedKey = nil
                editor:Hide()
                placeholder:Show()
            end,
        })
    end

    saveBtn:SetScript("OnClick", DoSave)
    revertBtn:SetScript("OnClick", RevertEditor)
    deleteBtn:SetScript("OnClick", DoDelete)

    -- ---- Rows ----

    local function AcquireRow(index)
        local row = rows[index]
        if row then return row end

        row = CreateFrame("Button", nil, listContent, "BackdropTemplate")
        row:SetHeight(ROW_HEIGHT)
        row:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)

        row.rail = row:CreateTexture(nil, "ARTWORK")
        row.rail:SetWidth(3)
        row.rail:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
        row.rail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 1, 1)

        row.nameText = OneWoW_GUI:CreateFS(row, 12)
        row.nameText:SetPoint("LEFT", row, "LEFT", 10, 0)
        row.nameText:SetWidth(NAME_COL_WIDTH)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)

        row.usageText = OneWoW_GUI:CreateFS(row, 11)
        row.usageText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.usageText:SetJustifyH("RIGHT")

        row.bodyText = OneWoW_GUI:CreateFS(row, 11)
        row.bodyText:SetPoint("LEFT", row.nameText, "RIGHT", 8, 0)
        row.bodyText:SetPoint("RIGHT", row.usageText, "LEFT", -8, 0)
        row.bodyText:SetJustifyH("LEFT")
        row.bodyText:SetWordWrap(false)
        row.bodyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

        row:SetScript("OnEnter", function(myself)
            if myself._key ~= selectedKey then
                myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            end
        end)
        row:SetScript("OnLeave", function(myself)
            myself:ApplyChrome()
        end)
        row:SetScript("OnClick", function(myself)
            if myself._key then
                SelectItem(myself._key)
            end
        end)

        function row:ApplyChrome()
            local selected = self._key and self._key == selectedKey
            if selected then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            elseif self._stripe then
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            else
                self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
                self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end

        -- Category list "Open in Bags" link overlay (right column).
        row.openLink = OneWoW_GUI:CreateTextLink(row, {
            text = L["SEARCH_SHORTCUTS_OPEN_IN_BAGS"],
            fontSize = 11,
            onClick = function()
                if row._entry and row._entry.id then
                    OpenInBags(row._entry.id)
                end
            end,
        })
        row.openLink:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.openLink:SetFrameLevel((row:GetFrameLevel() or 0) + 5)
        row.openLink:Hide()

        rows[index] = row
        return row
    end

    local function MatchesSearch(entry, kind)
        if searchNeedle == "" then return true end
        local ref = strlower(KIND_REF[kind](entry.name))
        local body = strlower(entry.body or "")
        local name = strlower(entry.name or "")
        return strfind(ref, searchNeedle, 1, true)
            or strfind(name, searchNeedle, 1, true)
            or strfind(body, searchNeedle, 1, true)
    end

    local function CollectEntries()
        local out = {}
        if draft and (not activeKind or activeKind == draft.kind) then
            if searchNeedle == "" or MatchesSearch(draft, draft.kind) then
                tinsert(out, {
                    kind = draft.kind,
                    entry = draft,
                    uses = 0,
                    isDraft = true,
                    key = "draft:" .. draft.kind,
                    shadowed = false,
                })
            end
        end
        for _, kind in ipairs(KIND_ORDER) do
            if not activeKind or activeKind == kind then
                local counts = SC:CountReferencesByName(kind)
                for _, entry in ipairs(SC:GetAll(kind)) do
                    if MatchesSearch(entry, kind) then
                        tinsert(out, {
                            kind = kind,
                            entry = entry,
                            uses = counts[strlower(entry.name)] or 0,
                            isDraft = false,
                            key = ItemKey(kind, entry),
                            shadowed = kind == "token" and SE:IsTokenShadowed(entry.name),
                        })
                    end
                end
            end
        end
        sort(out, function(a, b)
            if a.isDraft ~= b.isDraft then return a.isDraft end
            if a.kind ~= b.kind then
                return (KIND_RANK[a.kind] or 99) < (KIND_RANK[b.kind] or 99)
            end
            return strlower(a.entry.name) < strlower(b.entry.name)
        end)
        return out
    end

    RefreshRows = function()
        if not listContent then return end
        local items = CollectEntries()

        if #items == 0 then
            if searchNeedle ~= "" then
                emptyText:SetText(L["SEARCH_SHORTCUTS_EMPTY_SEARCH"])
            elseif activeKind then
                emptyText:SetText(L["SEARCH_SHORTCUTS_EMPTY_FILTERED"])
            else
                emptyText:SetText(L["SEARCH_SHORTCUTS_EMPTY"])
            end
            emptyText:Show()
        else
            emptyText:Hide()
        end

        local yPos = 0
        for i, item in ipairs(items) do
            local row = AcquireRow(i)
            local entry, kind = item.entry, item.kind
            row._kind, row._entry, row._key = kind, entry, item.key
            row._stripe = (i % 2 == 0)

            local displayName = item.isDraft and (KIND_REF[kind](entry.name ~= "" and entry.name or "…"))
                or KIND_REF[kind](entry.name)
            local displayBody = entry.body or ""
            row.nameText:SetText(displayName)
            row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor(
                item.shadowed and "TEXT_WARNING" or (KIND_RAIL_COLOR[kind] or "KIND_TOKEN")))
            row.bodyText:SetText(displayBody)

            row.rail:SetColorTexture(OneWoW_GUI:GetThemeColor(KIND_RAIL_COLOR[kind] or "KIND_TOKEN"))

            if kind == "category" and not item.isDraft then
                row.usageText:SetText("")
                row.openLink:Show()
            else
                row.openLink:Hide()
                row.usageText:SetText(format(L["SEARCH_SHORTCUTS_USAGE"], item.uses))
                row.usageText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -yPos)
            row:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -yPos)
            row:ApplyChrome()
            row:Show()
            yPos = yPos + ROW_HEIGHT + ROW_GAP
        end

        for i = #items + 1, #rows do
            rows[i]:Hide()
        end
        listContent:SetHeight(max(1, yPos))
    end

    SyncDetail = function()
        if selectedKey then
            SelectItem(selectedKey)
        else
            editor:Hide()
            placeholder:Show()
        end
    end

    parent.Activate = function()
        RefreshRows()
        SyncDetail()
    end

    SC:RegisterChangedCallback("SearchShortcutsUI", function()
        -- Keep selection if the entry still exists; drafts are local and survive.
        if selectedKey and selectedKey:sub(1, 6) ~= "draft:" then
            local kind, id = selectedKey:match("^([^:]+):(.+)$")
            if not (kind and id and SC:GetById(kind, id)) then
                selectedKey = nil
                editor:Hide()
                placeholder:Show()
            elseif editor:IsShown() and not IsDirty() then
                local entry = SC:GetById(kind, id)
                if entry then LoadEditor(kind, entry, false) end
            end
        end
        RefreshRows()
    end)

    editor:Hide()
    placeholder:Show()
    RefreshRows()
end
