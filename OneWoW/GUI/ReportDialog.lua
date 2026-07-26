local OneWoW_GUI = OneWoW_GUI

local ipairs = ipairs
local pairs = pairs
local wipe = wipe
local max = math.max
local min = math.min

-- ============================================================================
-- Report dialog
-- ============================================================================
-- Renders a typed row list into a scrollable, themed dialog.
--
-- Built for the catalog write confirmation in Phase 8A and generalized here in
-- 8C, when the reference lint turned out to need the same thing: a grouped list
-- of findings, each naming a store and an item, with actions underneath. The
-- two differ only in what produces the rows.
--
-- Deliberately not a StaticPopup. A StaticPopup centre-justifies its text, so
-- indent-based structure collapses into a centred blob; it will not grow, so
-- headers wrap mid-phrase; and it offers one font at one colour, so a header, a
-- store name and an item name all look alike.
--
-- Row kinds:
--   prompt  — the caller's own question, when it has one
--   header  — a claim about what follows
--   source  — the store a group of findings lives in
--   usage   — one item inside that store
--   note    — qualifying text, muted
--   divider — a rule, drawn as a real line

local ROW_STYLE = {
    prompt = { size = 13, color = "TEXT_PRIMARY",   indent = 0,  gapAbove = 4 },
    header = { size = 12, color = "TEXT_PRIMARY",   indent = 0,  gapAbove = 10 },
    source = { size = 12, color = "ACCENT_PRIMARY", indent = 8,  gapAbove = 6 },
    usage  = { size = 11, color = "TEXT_SECONDARY", indent = 24, gapAbove = 1 },
    note   = { size = 11, color = "TEXT_MUTED",     indent = 0,  gapAbove = 8 },
}

local DIVIDER_GAP = 9
local DEFAULT_WIDTH = 540
local DEFAULT_MIN_HEIGHT = 200
local DEFAULT_MAX_HEIGHT = 560

-- One cached dialog per key. Keyed rather than shared because two report
-- dialogs can be meaningfully open at once — a lint listing broken references,
-- and a confirmation raised by acting on one of them — and a single reused frame
-- would have the second silently replace the first.
local dialogs = {} ---@type table<string, table>

local function AcquireRow(state, parent, index)
    local fs = state.rowPool[index]
    if not fs then
        fs = OneWoW_GUI:CreateFS(parent, 12, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        fs:SetWordWrap(true)
        fs:SetNonSpaceWrap(false)
        state.rowPool[index] = fs
    end
    return fs
end

local function AcquireLine(state, parent, index)
    local tex = state.linePool[index]
    if not tex then
        tex = parent:CreateTexture(nil, "ARTWORK")
        tex:SetHeight(1)
        state.linePool[index] = tex
    end
    return tex
end

local function ReleaseFrom(pool, index)
    for i = index, #pool do
        pool[i]:Hide()
    end
end

--- Lay rows into the scroll content and return the height used.
local function RenderRows(state, content, rows, width)
    local textWidth = max(1, width - 60)
    local y = 0
    local shown, lines = 0, 0

    for _, row in ipairs(rows) do
        if row.kind == "divider" then
            y = y + DIVIDER_GAP
            lines = lines + 1
            local tex = AcquireLine(state, content, lines)
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            tex:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
            tex:SetColorTexture(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            tex:Show()
            y = y + 1 + DIVIDER_GAP
        else
            local style = ROW_STYLE[row.kind] or ROW_STYLE.note
            shown = shown + 1
            local fs = AcquireRow(state, content, shown)
            OneWoW_GUI:ApplyFont(fs, style.size)
            fs:SetTextColor(OneWoW_GUI:GetThemeColor(row.color or style.color))
            fs:SetWidth(textWidth - style.indent)
            fs:SetText(row.text or "")
            fs:ClearAllPoints()
            y = y + style.gapAbove
            fs:SetPoint("TOPLEFT", content, "TOPLEFT", style.indent, -y)
            fs:Show()
            y = y + max(fs:GetStringHeight(), 1)
        end
    end

    ReleaseFrom(state.rowPool, shown + 1)
    ReleaseFrom(state.linePool, lines + 1)
    return y
end

--- Build (or fetch) the dialog for a key.
---
--- Buttons are created on the first call and only relabelled afterwards, because
--- `CreateDialog` bakes its button row at construction. A key must therefore keep
--- a stable button *count*; text and handlers may change per show.
local function EnsureDialog(opts)
    local state = dialogs[opts.key]
    if state then return state end

    state = { rowPool = {}, linePool = {}, handlers = {} }

    local buttonDefs = {}
    for i, def in ipairs(opts.buttons or {}) do
        buttonDefs[i] = {
            text = def.text,
            color = def.danger and { OneWoW_GUI:GetThemeColor("BTN_DANGER_NORMAL") } or nil,
            onClick = function(frame)
                if def.keepOpen ~= true then frame:Hide() end
                local fn = state.handlers[i]
                if fn then fn() end
            end,
        }
    end

    state.dialog = OneWoW_GUI:CreateDialog({
        name = "OneWoW_GUI_ReportDialog_" .. opts.key,
        title = opts.title or "OneWoW",
        width = opts.width or DEFAULT_WIDTH,
        height = opts.minHeight or DEFAULT_MIN_HEIGHT,
        movable = true,
        escClose = true,
        showBrand = true,
        showScrollFrame = true,
        onClose = function()
            wipe(state.handlers)
            if opts.onClose then opts.onClose() end
        end,
        buttons = buttonDefs,
    })

    dialogs[opts.key] = state
    return state
end

--- Show a report.
---
--- `rows` is a list of `{ kind, text }`. `buttons` is positional and must match
--- the count the key was first created with; each entry supplies `text` and
--- `onClick` for this showing.
---@param opts table { key, title, rows, buttons, width, minHeight, maxHeight, onClose }
function OneWoW_GUI:ShowReportDialog(opts)
    local state = EnsureDialog(opts)
    local width = opts.width or DEFAULT_WIDTH

    for i, def in ipairs(opts.buttons or {}) do
        local btn = state.dialog.buttons[i]
        if btn then
            if def.text then btn:SetFitText(def.text) end
            state.handlers[i] = def.onClick
        end
    end

    local used = RenderRows(state, state.dialog.scrollContent, opts.rows or {}, width)
    state.dialog.scrollContent:SetHeight(max(used, 1))

    -- Title bar + button row + scroll insets. Grow to the content, then clamp so
    -- a report naming forty items cannot run off the screen.
    local chrome = OneWoW_GUI.Constants.GUI.TITLEBAR_HEIGHT + 48 + 24
    state.dialog.frame:SetHeight(min(
        max(used + chrome, opts.minHeight or DEFAULT_MIN_HEIGHT),
        opts.maxHeight or DEFAULT_MAX_HEIGHT))
    state.dialog.frame:Show()
    return state.dialog
end

--- Hide a report dialog if it exists.
---@param key string
function OneWoW_GUI:HideReportDialog(key)
    local state = dialogs[key]
    if state then state.dialog.frame:Hide() end
end

--- Re-render an already-open report without touching its buttons.
---
--- For a dialog whose content can change while the user is looking at it — the
--- lint after a prune, say — so acting on a finding does not close the list that
--- showed it.
---@param key string
---@param rows table[]
---@param width number|nil
function OneWoW_GUI:UpdateReportDialog(key, rows, width)
    local state = dialogs[key]
    if not state or not state.dialog.frame:IsShown() then return end
    local used = RenderRows(state, state.dialog.scrollContent, rows or {}, width or DEFAULT_WIDTH)
    state.dialog.scrollContent:SetHeight(max(used, 1))
end

-- Colours and fonts are baked when a dialog is built, so a theme or font change
-- has to drop them rather than restyle. Same treatment and the same reason as
-- the CopyPaste dialogs; the next report rebuilds.
local ReportDialog = {}
local function DropDialogs()
    for _, state in pairs(dialogs) do
        state.dialog.frame:Hide()
    end
    wipe(dialogs)
end
OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", ReportDialog, DropDialogs)
OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", ReportDialog, DropDialogs)
OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", ReportDialog, DropDialogs)
