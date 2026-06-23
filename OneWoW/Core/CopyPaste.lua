-- ============================================================================
-- ns.CopyPaste — copy/paste dialog service (formerly LibCopyPaste-1.0).
-- Method API: :Copy(title, text, options) / :Paste(title, callback, options)
-- with options = { readOnly, autoHide, frameStrata }.
-- Built on OneWoW_GUI components (CreateDialog + CreateScrollEditBox). One
-- lazy singleton dialog per mode; cached dialogs are dropped on theme/font
-- changes so the next open rebuilds with fresh styling.
-- ============================================================================
local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

local IsControlKeyDown = IsControlKeyDown
local IsMetaKeyDown = IsMetaKeyDown
local IsMacClient = IsMacClient
local tinsert = tinsert
local tContains = tContains
local wipe = wipe

ns.CopyPaste = {}
local CopyPaste = ns.CopyPaste

local DEFAULT_STRATA = "DIALOG"
local MAX_LETTERS = 999999

-- "copy" closes with CLOSE; "paste" confirms with ACCEPT (fires the consumer
-- callback with the editbox text). Titlebar X / ESC always cancel.
local dialogs = {}

local DIALOG_NAMES = {
    copy = "OneWoW_CopyPasteCopyDialog",
    paste = "OneWoW_CopyPastePasteDialog",
}

local function BuildDialog(mode)
    local dlg = {}
    local name = DIALOG_NAMES[mode]

    local dialog = OneWoW_GUI:CreateDialog({
        name = name,
        title = "",
        width = OneWoW_GUI.Constants.GUI.COPYPASTE_WIDTH,
        height = OneWoW_GUI.Constants.GUI.COPYPASTE_HEIGHT,
        strata = DEFAULT_STRATA,
        -- Registered idempotently below: dialogs rebuild on theme/font change
        -- and CreateDialog's escClose would re-insert the name each time.
        escClose = false,
        buttons = {
            {
                text = (mode == "paste") and ACCEPT or CLOSE,
                onClick = function(frame)
                    if mode == "paste" and dlg._callback then
                        local callback = dlg._callback
                        dlg._callback = nil
                        callback(dlg.editBox:GetText())
                    end
                    frame:Hide()
                end,
            },
        },
    })
    if not tContains(UISpecialFrames, name) then
        tinsert(UISpecialFrames, name)
    end

    dlg.frame = dialog.frame
    dlg.titleText = dialog.titleBar._titleText

    local _, editBox = OneWoW_GUI:CreateScrollEditBox(dialog.contentFrame, {
        maxLetters = MAX_LETTERS,
        onEscapePressed = function() dlg.frame:Hide() end,
    })
    -- "WoW Default" (GetFont() == nil) must not fall back to the stock Friz
    -- Quadrata path: its line metrics drift from the EditBox's selection-quad
    -- rows, visually breaking highlight on multiline text. Use ChatFontNormal's
    -- file (Blizzard's own editbox font) instead.
    local fontPath = OneWoW_GUI:GetFont() or ChatFontNormal:GetFont()
    OneWoW_GUI:SafeSetFont(editBox, fontPath, 12)
    -- The scrollFrame's OnSizeChanged (which sizes the editbox) can't fire
    -- until the hidden dialog is first shown, so SetText would otherwise lay
    -- out against an unsized editbox. Pre-size it to its settled width:
    -- dialog edges (±1) + scroll insets (8/-8). The hook corrects any drift.
    editBox:SetWidth(OneWoW_GUI.Constants.GUI.COPYPASTE_WIDTH - 18)
    dlg.editBox = editBox

    -- Large texts reflow over several frames after Show; a one-shot highlight
    -- renders selection quads against the partial layout. Re-assert select-all
    -- whenever the editbox resizes (its height grows as layout settles).
    editBox:HookScript("OnSizeChanged", function(eb)
        if dlg._selectAll then
            eb:HighlightText()
        end
    end)
    -- A manual click means the user is making their own selection.
    editBox:HookScript("OnMouseDown", function()
        dlg._selectAll = false
    end)

    if mode == "copy" then
        -- Footnote in the button row: the selection-highlight visual can lag
        -- behind on huge texts, so reassure users the copy works regardless.
        local hint = OneWoW_GUI:CreateFS(dlg.frame, 11)
        hint:SetPoint("LEFT", dlg.frame, "BOTTOMLEFT", 12, 24)
        hint:SetText(IsMacClient() and ns.L["COPYPASTE_HINT_COPY_MAC"] or ns.L["COPYPASTE_HINT_COPY"])
        hint:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    end

    -- Read-only: revert user edits to the canonical text supplied by the
    -- caller (never a GetText() snapshot, which can be stale/empty).
    -- Programmatic SetText arrives with userInput=false, so no loops.
    editBox:SetScript("OnTextChanged", function(eb, userInput)
        if dlg._readOnly and userInput then
            eb:SetText(dlg._text or "")
            eb:HighlightText()
        elseif userInput then
            dlg._selectAll = false
        end
    end)

    -- autoHide: dismiss right after the user copies (Ctrl+C or Cmd+C).
    editBox:SetScript("OnKeyDown", function(_, key)
        if dlg._autoHide and key == "C" and (IsControlKeyDown() or IsMetaKeyDown()) then
            dlg._hideQueued = true
        end
    end)
    editBox:SetScript("OnKeyUp", function(_, key)
        if dlg._autoHide and dlg._hideQueued
            and (key == "C" or key == "LCTRL" or key == "RCTRL" or key == "LMETA" or key == "RMETA") then
            dlg.frame:Hide()
        end
    end)

    -- Uniform cleanup for every dismissal path (button, titlebar X, ESC).
    dlg.frame:HookScript("OnHide", function()
        dlg._callback = nil
        dlg._readOnly = false
        dlg._autoHide = false
        dlg._hideQueued = false
        dlg._selectAll = false
        dlg._text = nil
        dlg.titleText:SetText("")
        dlg.editBox:SetText("")
        dlg.frame:SetFrameStrata(DEFAULT_STRATA)
    end)

    function dlg:Open(title, options)
        self.titleText:SetText(title)
        self._readOnly = options and options.readOnly or false
        self._autoHide = options and options.autoHide or false
        self._hideQueued = false
        self.frame:SetFrameStrata(options and options.frameStrata or DEFAULT_STRATA)
        -- Transient dialog: always reopen centered (still draggable while open).
        self.frame:ClearAllPoints()
        self.frame:SetPoint("CENTER")
        self.frame:Show()
        self.editBox:SetFocus()
    end

    return dlg
end

local function GetDialog(mode)
    -- The two modes are one conceptual surface; never show both at once.
    local other = dialogs[mode == "copy" and "paste" or "copy"]
    if other and other.frame:IsShown() then
        other.frame:Hide()
    end
    local dlg = dialogs[mode]
    if not dlg then
        dlg = BuildDialog(mode)
        dialogs[mode] = dlg
    end
    return dlg
end

function CopyPaste:Copy(title, text, options)
    assert(type(title) == "string" and type(text) == "string",
        "title and text are required and must be strings. Usage: Copy(title, text)")
    local dlg = GetDialog("copy")
    dlg._text = text
    dlg.editBox:SetText(text)
    dlg.editBox:SetCursorPosition(0)
    dlg:Open(title, options)
    dlg._selectAll = true
    dlg.editBox:HighlightText()
end

function CopyPaste:Paste(title, callback, options)
    assert(type(title) == "string" and type(callback) == "function",
        "title and callback are required. title must be a string and callback must be a function. Usage: Paste(title, callback)")
    local dlg = GetDialog("paste")
    dlg.editBox:SetText("")
    dlg:Open(title, options)
    dlg._callback = callback
end

-- Colors and fonts are baked at build time; drop the cached dialogs so the
-- next open rebuilds with the new styling.
local function DropDialogs()
    for _, dlg in pairs(dialogs) do
        dlg.frame:Hide()
    end
    wipe(dialogs)
end
OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", CopyPaste, DropDialogs)
OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", CopyPaste, DropDialogs)
OneWoW_GUI:RegisterSettingsCallback("OnFontSizeChanged", CopyPaste, DropDialogs)
