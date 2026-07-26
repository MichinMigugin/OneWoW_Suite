local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local UI = ns.UI
local SE = ns.SearchExpand
local SC = ns.SearchCatalog

local ipairs = ipairs
local pairs = pairs
local sort = sort
local tinsert = tinsert
local tconcat = table.concat
local strlower = string.lower
local strtrim = strtrim
local format = string.format
local max = math.max

local StaticPopupDialogs = StaticPopupDialogs
local StaticPopup_Show = StaticPopup_Show
local GameTooltip = GameTooltip
local CreateFrame = CreateFrame
local MenuUtil = MenuUtil

-- ============================================================================
-- Search Shortcuts
-- ============================================================================
-- One list over the whole search catalog, filtered by kind.
--
-- Tokens and named expressions used to be two sections with two row types,
-- because a token was an alias for one built-in keyword and a SAVED was a free
-- expression. Since Phase 2 a token body is an arbitrary expression too, so the
-- only real difference left is how a reference to it is written — `#name` versus
-- `SAVED(Name)`. Two lists for one data model meant every feature had to be
-- built twice, and the alias editor was still enforcing the old restriction.
--
-- Categories appear read-only. They are Bags' data and are edited there, but
-- they resolve through the same catalog and can be referenced by the same
-- expressions, so leaving them out made the list a partial answer to "what can I
-- write in a search box, and what is using it".

-- TODO (Phase 8D): move to locale keys across all 11 locales. Kept inline so the
-- strings can settle first; this table is the single lookup point that pass has
-- to relocate. Strings already keyed in the locales stay on `L`.
local STRINGS = {
    HELP = "Everything you can reference from a search box. Right-click a row to edit, rename, or delete it.",
    EMPTY = "Nothing here yet.",
    EMPTY_FILTERED = "Nothing of this kind yet.",

    FILTER_TOKEN = "Keyword Synonyms",
    FILTER_SAVED = "Named Expressions",
    FILTER_CATEGORY = "Bags Categories",

    USAGE = "%d use(s)",
    USAGE_NONE = "unused",
    FORMER_NAMES = "also answers to %s",
    CATEGORY_READONLY = "Managed in Bags",

    EDIT_TITLE = "Edit expression — %s",
    NEW_TITLE = "New expression — %s",
    TOKEN_NAME_PROMPT = "Name for this keyword synonym (letters, numbers, _ only):",

    DUPLICATE_TITLE = "%s already holds this exact expression.",
    DUPLICATE_BODY = "Two copies of one rule drift apart the moment you edit one of them. Point this at %s instead?",
    DUPLICATE_ACCEPT = "Use a reference",
    DUPLICATE_KEEP = "Keep both",

    SHADOWED_TIP = "A built-in keyword of this name was registered later and wins, so this entry never matches. Rename it to get it back — the expression is kept either way.",
}

-- Kinds in display order. `ref` writes a reference the way a user would type it,
-- which is also what the reference index scans for.
local KIND_ORDER = { "token", "saved", "category" }

local KIND_REF = {
    token    = function(name) return "#" .. name end,
    saved    = function(name) return "SAVED(" .. name .. ")" end,
    category = function(name) return "CATEGORY(" .. name .. ")" end,
}

local KIND_FILTER_LABEL = {
    token    = STRINGS.FILTER_TOKEN,
    saved    = STRINGS.FILTER_SAVED,
    category = STRINGS.FILTER_CATEGORY,
}

-- Categories are provider-backed: Bags owns the record, and its editor also owns
-- filterMode and the type builder. Editing one from here would be a second
-- writer for the same field.
local KIND_EDITABLE = { token = true, saved = true, category = false }

local ROW_GAP = 4
local ROW_PAD_TOP = 6
local ROW_PAD_BOTTOM = 8
local ROW_LINE_GAP = 3

local function ShowExprDialog(title, initial, onAccept)
    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_SearchShortcutExpr",
        title = title,
        width = 480,
        height = 260,
        showBrand = false,
    })
    local dialog = result.frame
    local content = result.contentFrame

    local editContainer = OneWoW_GUI:CreateFrame(content, {
        bgColor = "BG_TERTIARY",
        borderColor = "BORDER_SUBTLE",
    })
    editContainer:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -14)
    editContainer:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 48)

    local _, box = OneWoW_GUI:CreateScrollEditBox(editContainer, {
        name = "OneWoW_SearchShortcutExprBox",
        fontSize = 12,
    })
    -- Width must be set before SetText so multi-line layout wraps correctly
    -- (scroll OnSizeChanged may not have fired yet on a freshly shown dialog).
    box:SetWidth(440)
    box:SetText(initial or "")
    box:SetCursorPosition(0)

    local saveBtn = OneWoW_GUI:CreateFitTextButton(content, { text = SAVE, height = 28 })
    saveBtn:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -14, 12)

    local cancelBtn = OneWoW_GUI:CreateFitTextButton(content, { text = CANCEL, height = 28 })
    cancelBtn:SetPoint("RIGHT", saveBtn, "LEFT", -8, 0)
    cancelBtn:SetScript("OnClick", function() dialog:Hide() end)

    saveBtn:SetScript("OnClick", function()
        local text = box:GetText() or ""
        onAccept(text)
        dialog:Hide()
    end)

    OneWoW_GUI:ApplyFontToFrame(dialog)
    dialog:Show()
    box:SetFocus()
end

local function RegisterPopups()
    if StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_NAME"] then return end

    local function DialogEditBox(dialog)
        return dialog.editBox or dialog.EditBox
    end

    StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_NAME"] = {
        text = "%s",
        hasEditBox = true,
        button1 = SAVE,
        button2 = CANCEL,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(dialog, data)
            data = data or dialog.data
            if not data or not data.onAccept then return end
            local editBox = DialogEditBox(dialog)
            data.onAccept(editBox and editBox:GetText() or "")
        end,
        EditBoxOnEnterPressed = function(editBox)
            local dialog = editBox:GetParent()
            local info = StaticPopupDialogs["ONEWOW_SEARCH_SHORTCUT_NAME"]
            info.OnAccept(dialog, dialog.data)
            dialog:Hide()
        end,
        EditBoxOnEscapePressed = function(editBox)
            editBox:GetParent():Hide()
        end,
    }

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
        button1 = STRINGS.DUPLICATE_ACCEPT,
        button2 = STRINGS.DUPLICATE_KEEP,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(_, data)
            if data and data.onAccept then data.onAccept() end
        end,
    }
end

local function ShowNamePopup(prompt, onAccept, initialText)
    local popup = StaticPopup_Show("ONEWOW_SEARCH_SHORTCUT_NAME", prompt, nil, {
        onAccept = onAccept,
    })
    local editBox = popup and (popup.editBox or popup.EditBox)
    if editBox then
        if initialText then
            editBox:SetText(initialText)
        end
        editBox:SetFocus()
    end
    return popup
end

local function StripHash(text)
    return strlower(strtrim((text or ""):gsub("^#", "")))
end

--- Report a catalog write failure. The catalog speaks generic codes; SearchExpand
--- owns the per-kind mapping onto locale keys, so this does not restate it.
---@param kind string
---@param errKey string|nil
local function ReportError(kind, errKey)
    if not errKey then return end
    local mapped = SE:MapCatalogError(kind, errKey)
    print(L[mapped] or mapped)
end

--- Offer to replace a freshly written body with a reference to the entry that
--- already holds it. Fires after the save, never blocks it.
---@param kind string
---@param entry table
local function OfferDuplicateReference(kind, entry)
    local other, otherKind = SC:FindDuplicateBody(entry.body, kind, entry.id)
    if not other or not otherKind then return end

    local ref = KIND_REF[otherKind](other.name)
    local text = format(STRINGS.DUPLICATE_TITLE, ref)
        .. "\n\n" .. format(STRINGS.DUPLICATE_BODY, ref)

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
local function CommitBody(kind, name, body)
    local entry, err = SC:Set(kind, name, body)
    if not entry then
        ReportError(kind, err)
        return
    end
    OfferDuplicateReference(kind, entry)
end

function UI:CreateSearchShortcutsTab(parent)
    RegisterPopups()

    -- Everything holding a frame lives in this scope, not at file scope. The
    -- builder runs again on every UI:FullReset() — theme, language and minimap
    -- changes all trigger one — and a cache that outlives the rebuild keeps rows
    -- parented to a window that no longer exists: refresh finds them non-nil,
    -- reuses them, and fills frames nobody can see.
    local rows = {}
    local listContent, emptyText
    local activeKind = nil ---@type string|nil nil means every kind
    local filterButtons = {}
    local RefreshRows

    local _, content = OneWoW_GUI:CreateScrollFrame(parent, { name = "OneWoW_SearchShortcutsScroll" })

    local y = -10

    local title = OneWoW_GUI:CreateFS(content, 16)
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    title:SetText(L["SEARCH_SHORTCUTS_TITLE"])
    title:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
    y = y - 24

    local desc = OneWoW_GUI:CreateFS(content, 12)
    desc:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    desc:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    desc:SetText(L["SEARCH_SHORTCUTS_DESC"])
    desc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 48

    local help = OneWoW_GUI:CreateFS(content, 11)
    help:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    help:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    help:SetJustifyH("LEFT")
    help:SetWordWrap(true)
    help:SetText(STRINGS.HELP)
    help:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 30

    -- ---- Filter bar ----

    -- `_kind` lives on the button rather than in the table key, because the
    -- "All" button's kind is nil and nil cannot key a table.
    local function SyncFilterButtons()
        for _, btn in pairs(filterButtons) do
            btn:SetActive(activeKind == btn._kind)
        end
    end

    local function AddFilterButton(label, kind, anchorTo)
        local btn = OneWoW_GUI:CreateFitTextButton(content, {
            text = label,
            height = 24,
            toggleable = true,
        })
        btn._kind = kind
        if anchorTo then
            btn:SetPoint("LEFT", anchorTo, "RIGHT", 6, 0)
        else
            btn:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
        end
        btn:SetScript("OnClick", function()
            activeKind = kind
            SyncFilterButtons()
            RefreshRows()
        end)
        tinsert(filterButtons, btn)
        return btn
    end

    local prev = AddFilterButton(ALL, nil, nil)
    for _, kind in ipairs(KIND_ORDER) do
        prev = AddFilterButton(KIND_FILTER_LABEL[kind], kind, prev)
    end
    y = y - 32

    -- ---- Add buttons ----

    local addToken = OneWoW_GUI:CreateFitTextButton(content, {
        text = L["SEARCH_SHORTCUTS_ADD_ALIAS"],
        height = 26,
    })
    addToken:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    addToken:SetScript("OnClick", function()
        ShowNamePopup(STRINGS.TOKEN_NAME_PROMPT, function(nameText)
            local name = StripHash(nameText)
            if name == "" then return end
            -- Creating under a name some entry retired takes it back, and every
            -- stale reference to it starts meaning something else.
            OneWoW_GUI:ConfirmCatalogClaim("token", name, nil, function()
                ShowExprDialog(format(STRINGS.NEW_TITLE, KIND_REF.token(name)), "", function(expr)
                    CommitBody("token", name, expr)
                end)
            end)
        end)
    end)

    local addSaved = OneWoW_GUI:CreateFitTextButton(content, {
        text = L["SEARCH_SHORTCUTS_ADD_SAVED"],
        height = 26,
    })
    addSaved:SetPoint("LEFT", addToken, "RIGHT", 6, 0)
    addSaved:SetScript("OnClick", function()
        ShowNamePopup(L["SEARCH_SHORTCUTS_SAVED_NAME_PROMPT"], function(nameText)
            local name = strtrim(nameText or "")
            if name == "" then return end
            OneWoW_GUI:ConfirmCatalogClaim("saved", name, nil, function()
                ShowExprDialog(format(STRINGS.NEW_TITLE, KIND_REF.saved(name)), "", function(expr)
                    CommitBody("saved", name, expr)
                end)
            end)
        end)
    end)
    y = y - 34

    -- ---- List ----

    local listFrame = CreateFrame("Frame", nil, content, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    listFrame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    listFrame:SetHeight(420)
    listFrame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    listFrame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    listFrame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))

    local _, scrollContent = OneWoW_GUI:CreateScrollFrame(listFrame, {})
    listContent = scrollContent

    emptyText = OneWoW_GUI:CreateFS(listContent, 11)
    emptyText:SetPoint("TOPLEFT", listContent, "TOPLEFT", 8, -8)
    emptyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 440

    local catNote = OneWoW_GUI:CreateFS(content, 11)
    catNote:SetPoint("TOPLEFT", content, "TOPLEFT", 15, y)
    catNote:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, y)
    catNote:SetJustifyH("LEFT")
    catNote:SetWordWrap(true)
    catNote:SetText(L["SEARCH_SHORTCUTS_CATEGORY_NOTE"])
    catNote:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

    content:SetHeight(1000)

    -- ---- Row actions ----

    local function EditEntry(kind, entry)
        ShowExprDialog(format(STRINGS.EDIT_TITLE, KIND_REF[kind](entry.name)), entry.body or "",
            function(text)
                CommitBody(kind, entry.name, text)
            end)
    end

    local function RenameEntry(kind, entry)
        ShowNamePopup(L["SEARCH_SHORTCUT_SAVED_RENAME_PROMPT"], function(newName)
            local target = kind == "token" and StripHash(newName) or strtrim(newName or "")
            if target == "" then return end
            OneWoW_GUI:ConfirmCatalogRenameById(kind, entry.id, target, function()
                local ok, err = SC:Rename(kind, entry.id, target)
                if not ok then ReportError(kind, err) end
            end)
        end, entry.name)
    end

    local function DeleteEntry(kind, entry)
        -- One confirmation, always. The reference report replaces the plain
        -- "are you sure" when there is something to report, rather than stacking
        -- a second popup on top of it.
        local report = SC:PreflightDelete(kind, entry.id)
        if report then
            OneWoW_GUI:ConfirmCatalogWrite(report, function()
                SC:Delete(kind, entry.id)
            end)
            return
        end
        local prompt = kind == "token"
            and L["SEARCH_SHORTCUT_ALIAS_DELETE"]:format(entry.name)
            or L["SEARCH_SHORTCUT_SAVED_DELETE"]:format(entry.name)
        StaticPopup_Show("ONEWOW_SEARCH_SHORTCUT_DELETE", prompt, nil, {
            onAccept = function() SC:Delete(kind, entry.id) end,
        })
    end

    -- ---- Rows ----

    local function AcquireRow(index)
        local row = rows[index]
        if row then return row end

        row = CreateFrame("Button", nil, listContent, "BackdropTemplate")
        row:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)

        row.nameText = OneWoW_GUI:CreateFS(row, 12)
        row.nameText:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -ROW_PAD_TOP)
        row.nameText:SetJustifyH("LEFT")
        row.nameText:SetWordWrap(false)

        row.usageText = OneWoW_GUI:CreateFS(row, 11)
        row.usageText:SetPoint("TOPRIGHT", row, "TOPRIGHT", -8, -ROW_PAD_TOP)
        row.usageText:SetJustifyH("RIGHT")
        row.nameText:SetPoint("RIGHT", row.usageText, "LEFT", -8, 0)

        row.bodyText = OneWoW_GUI:CreateFS(row, 11)
        row.bodyText:SetPoint("TOPLEFT", row.nameText, "BOTTOMLEFT", 0, -ROW_LINE_GAP)
        row.bodyText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.bodyText:SetJustifyH("LEFT")
        row.bodyText:SetJustifyV("TOP")
        row.bodyText:SetWordWrap(true)
        row.bodyText:SetNonSpaceWrap(true)

        row.formerText = OneWoW_GUI:CreateFS(row, 10)
        row.formerText:SetPoint("TOPLEFT", row.bodyText, "BOTTOMLEFT", 0, -ROW_LINE_GAP)
        row.formerText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.formerText:SetJustifyH("LEFT")
        row.formerText:SetWordWrap(false)

        row:SetScript("OnEnter", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            if myself._tip then
                GameTooltip:SetOwner(myself, "ANCHOR_TOPRIGHT")
                GameTooltip:ClearLines()
                GameTooltip:AddLine(myself._tip, 1, 0.35, 0.35, true)
                GameTooltip:Show()
            end
        end)
        row:SetScript("OnLeave", function(myself)
            myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            GameTooltip:Hide()
        end)
        row:SetScript("OnMouseDown", function(myself, button)
            if button ~= "RightButton" then return end
            local kind, entry = myself._kind, myself._entry
            if not kind or not entry or not KIND_EDITABLE[kind] then return end
            MenuUtil.CreateContextMenu(myself, function(_, root)
                root:CreateButton(L["SEARCH_SHORTCUT_SAVED_EDIT"], function()
                    EditEntry(kind, entry)
                end)
                root:CreateButton(L["RENAME"], function()
                    RenameEntry(kind, entry)
                end)
                root:CreateButton(DELETE, function()
                    DeleteEntry(kind, entry)
                end)
            end)
        end)

        rows[index] = row
        return row
    end

    --- Every entry of every visible kind, with its live usage count.
    local function CollectEntries()
        local out = {}
        for _, kind in ipairs(KIND_ORDER) do
            if not activeKind or activeKind == kind then
                local counts = SC:CountReferencesByName(kind)
                for _, entry in ipairs(SC:GetAll(kind)) do
                    tinsert(out, {
                        kind = kind,
                        entry = entry,
                        uses = counts[strlower(entry.name)] or 0,
                        -- A keyword registered after this token was stored
                        -- shadows it outright, so the row says so rather than
                        -- rendering as if it still worked.
                        shadowed = kind == "token" and SE:IsTokenShadowed(entry.name),
                    })
                end
            end
        end
        -- Kind first so the list reads as grouped, then name within a kind.
        sort(out, function(a, b)
            if a.kind ~= b.kind then return a.kind < b.kind end
            return strlower(a.entry.name) < strlower(b.entry.name)
        end)
        return out
    end

    RefreshRows = function()
        if not listContent then return end
        local items = CollectEntries()

        emptyText:SetText(activeKind and STRINGS.EMPTY_FILTERED or STRINGS.EMPTY)
        emptyText:SetShown(#items == 0)

        local yPos = 0
        for i, item in ipairs(items) do
            local row = AcquireRow(i)
            local entry, kind = item.entry, item.kind
            row._kind, row._entry = kind, entry
            row._tip = item.shadowed and STRINGS.SHADOWED_TIP or nil

            row.nameText:SetText(KIND_REF[kind](entry.name))
            row.nameText:SetTextColor(OneWoW_GUI:GetThemeColor(
                item.shadowed and "TEXT_WARNING" or "TEXT_PRIMARY"))

            row.usageText:SetText(item.uses > 0
                and format(STRINGS.USAGE, item.uses)
                or (KIND_EDITABLE[kind] and STRINGS.USAGE_NONE or STRINGS.CATEGORY_READONLY))
            row.usageText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))

            row.bodyText:SetText(entry.body or "")
            row.bodyText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))

            local formers = entry.formerNames
            if formers and #formers > 0 then
                local refs = {}
                for _, formerName in ipairs(formers) do
                    tinsert(refs, KIND_REF[kind](formerName))
                end
                row.formerText:SetText(format(STRINGS.FORMER_NAMES, tconcat(refs, ", ")))
                row.formerText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
                row.formerText:Show()
            else
                row.formerText:SetText("")
                row.formerText:Hide()
            end

            -- Width must be known before measuring wrapped body height.
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", listContent, "TOPLEFT", 0, -yPos)
            row:SetPoint("TOPRIGHT", listContent, "TOPRIGHT", 0, -yPos)
            row:SetHeight(80)

            local nameH = max(12, row.nameText:GetStringHeight() or 12)
            local bodyH = max(11, row.bodyText:GetStringHeight() or 11)
            local formerH = row.formerText:IsShown()
                and (ROW_LINE_GAP + max(10, row.formerText:GetStringHeight() or 10))
                or 0
            local rowHeight = ROW_PAD_TOP + nameH + ROW_LINE_GAP + bodyH + formerH + ROW_PAD_BOTTOM

            row:SetHeight(rowHeight)
            row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
            row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            row:Show()
            yPos = yPos + rowHeight + ROW_GAP
        end

        for i = #items + 1, #rows do
            rows[i]:Hide()
        end
        listContent:SetHeight(max(1, yPos))
    end

    SyncFilterButtons()

    parent.Activate = RefreshRows

    -- The catalog fires for provider-backed kinds too, so a category renamed in
    -- Bags updates this list without it knowing Bags exists.
    SC:RegisterChangedCallback("SearchShortcutsUI", RefreshRows)

    RefreshRows()
end
