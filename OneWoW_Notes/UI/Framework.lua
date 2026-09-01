local _, ns = ...

ns.UI = ns.UI or {}

local OneWoW_GUI = OneWoW_GUI

local mapClickDDs = {}

function ns.UI.BindWaypinMapClickDropdown(dd)
    local L = ns.L
    dd:SetOptions({
        { text = L["WAYPINS_MAP_CLICK_CTRL"], value = "ctrlRight" },
        { text = L["WAYPINS_MAP_CLICK_RIGHT"], value = "right" },
    })
    dd:SetSelected(ns.WayPinsVisual.MapClick())
    dd.onSelect = function(value)
        ns.db.global.waypinMapClick = value
        ns.UI.SyncWaypinMapClick()
    end
    tinsert(mapClickDDs, dd)
end

function ns.UI.SyncWaypinMapClick()
    local mode = ns.WayPinsVisual.MapClick()
    for _, dd in ipairs(mapClickDDs) do
        dd:SetSelected(mode)
    end
end
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE

function ns.UI.CreateSplitPanel(parent)
    local panels = OneWoW_GUI:CreateSplitPanel(parent)
    panels.listPanel:ClearAllPoints()
    panels.listPanel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    panels.listPanel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)

    panels.detailPanel:ClearAllPoints()
    panels.detailPanel:SetPoint("TOPLEFT", panels.listPanel, "TOPRIGHT", 10, 0)
    panels.detailPanel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    return {
        listPanel         = panels.listPanel,
        listTitle         = panels.listTitle,
        listScrollFrame   = panels.listScrollFrame,
        listScrollChild   = panels.listScrollChild,
        UpdateListThumb   = function() end,
        detailPanel       = panels.detailPanel,
        detailTitle       = panels.detailTitle,
        detailScrollFrame = panels.detailScrollFrame,
        detailScrollChild = panels.detailScrollChild,
        UpdateDetailThumb = function() end,
    }
end

local _openDropdowns = {}

function ns.UI.CreateThemedDropdown(parent, labelPrefix, width, height)
    width  = width  or 150
    height = height or 26

    local dropdown, textFS = OneWoW_GUI:CreateDropdown(parent, {
        width  = width,
        height = height,
    })

    dropdown._value       = nil
    dropdown._displayText = ""
    dropdown._labelPrefix = labelPrefix or ""
    dropdown._options     = {}
    dropdown.onSelect     = nil

    local function RefreshText()
        if dropdown._labelPrefix ~= "" then
            textFS:SetText(dropdown._labelPrefix .. ": " .. dropdown._displayText)
        else
            textFS:SetText(dropdown._displayText)
        end
    end

    function dropdown:SetOptions(options) self._options = options end

    function dropdown:SetSelected(value)
        for _, opt in ipairs(self._options) do
            if opt.value == value then
                self._value       = value
                self._displayText = opt.text
                self._activeValue = value
                RefreshText()
                return
            end
        end
    end

    function dropdown:SetText(txt)
        self._displayText = txt
        RefreshText()
    end

    function dropdown:GetText()  return self._displayText end
    function dropdown:GetValue() return self._value       end

    function dropdown:ClosePopup()
        if self._menu and self._menu:IsShown() then
            self._menu:Hide()
        end
    end

    OneWoW_GUI:AttachFilterMenu(dropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(dropdown._options) do
                table.insert(items, {
                    value     = opt.value,
                    text      = opt.text,
                    rightText = opt.rightText,
                })
            end
            return items
        end,
        onSelect = function(value, displayText)
            dropdown._value       = value
            dropdown._displayText = displayText
            dropdown._activeValue = value
            RefreshText()
            if dropdown.onSelect then dropdown.onSelect(value, displayText) end
        end,
        getActiveValue = function() return dropdown._value end,
    })

    table.insert(_openDropdowns, dropdown)
    return dropdown
end

function ns.UI.CreateFontDropdown(parent, width, height)
    width  = width  or 150
    height = height or 26

    local dropdown, textFS = OneWoW_GUI:CreateDropdown(parent, {
        width  = width,
        height = height,
    })

    dropdown._value       = nil
    dropdown._displayText = ""
    dropdown._options     = {}
    dropdown.onSelect     = nil

    local function RefreshText()
        textFS:SetText(dropdown._displayText)

        -- Preview the selected font, but route through SafeSetFont so a font
        -- whose file fails to load falls back to a stock path (instead of
        -- rendering blank — the "disappearing selection" bug) and so it honors
        -- the global font-size offset like the rest of the themed chrome.
        local fontPath
        if dropdown._value and dropdown._value ~= "default" then
            fontPath = OneWoW_GUI:GetFontByKey(dropdown._value)
        end
        OneWoW_GUI:SafeSetFont(textFS, fontPath, 11)
    end

    function dropdown:SetOptions(options) self._options = options end

    function dropdown:SetSelected(value)
        for _, opt in ipairs(self._options) do
            if opt.value == value then
                self._value       = value
                self._displayText = opt.text
                self._activeValue = value
                RefreshText()
                return
            end
        end
    end

    function dropdown:SetText(txt)
        self._displayText = txt
        RefreshText()
    end

    function dropdown:GetText()  return self._displayText end
    function dropdown:GetValue() return self._value       end

    function dropdown:ClosePopup()
        if self._menu and self._menu:IsShown() then
            self._menu:Hide()
        end
    end

    OneWoW_GUI:AttachFilterMenu(dropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(dropdown._options) do
                table.insert(items, { value = opt.value, text = opt.text })
            end
            return items
        end,
        onSelect = function(value, displayText)
            dropdown._value       = value
            dropdown._displayText = displayText
            dropdown._activeValue = value
            RefreshText()
            if dropdown.onSelect then dropdown.onSelect(value, displayText) end
        end,
        getActiveValue = function() return dropdown._value end,
    })

    table.insert(_openDropdowns, dropdown)
    return dropdown
end

function ns.UI.ApplyFontToFrame(frame)
    if not frame then return end
    local fontPath = OneWoW_GUI:GetFont()
    if not fontPath then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont and not region._skipGlobalFont then
            local _, sz = region:GetFont()
            if sz and sz > 0 then region:SetFont(fontPath, sz) end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child._skipGlobalFont then
        elseif child:GetObjectType() == "EditBox" and child.GetFont then
            local _, sz, flags = child:GetFont()
            if sz and sz > 0 then child:SetFont(fontPath, sz, flags or "") end
        end
        ns.UI.ApplyFontToFrame(child)
    end
end

function ns.UI.CloseAllOpenDropdowns()
    for _, dd in ipairs(_openDropdowns) do
        if dd._menu and dd._menu:IsShown() then
            dd._menu:Hide()
        end
    end
end

-- =====================================================================
-- Shared list row for the Notes/Zones/Players/NPCs/Items tabs.
-- One standard "bubble": [color bar] [icon] [title (2-line) / detail /
-- storage] [action icons, vertically centered] [reorder arrows].
-- =====================================================================

ns.UI.LIST_ROW_HEIGHT  = 52
ns.UI.LIST_ROW_SPACING = 57   -- row height + gap; used as the per-row yOffset step

local ACTION_BTN = 18
local ACTION_GAP = 2

local function AttachRowTooltip(btn, tip)
    if not tip then return end
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(tip.title or "", 1, 1, 1)
        if tip.desc then GameTooltip:AddLine(tip.desc, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function MakeActionButton(row, iconPath)
    return OneWoW_GUI:CreateIconButton(row, {
        iconTexture = iconPath,
        size = ACTION_BTN,
    })
end

-- Toggle button: owns its desaturate/alpha/checked visuals. onToggle(newState)
-- is called after the visual flips so callers just persist the new value.
local function MakeToggleButton(row, iconPath, active, onToggle)
    return OneWoW_GUI:CreateIconButton(row, {
        iconTexture = iconPath,
        size = ACTION_BTN,
        check = true,
        checked = active,
        onToggle = onToggle,
    })
end

-- opts:
--   yOffset, height, selected, onSelect
--   barColor = {r,g,b} | nil          -- left accent bar
--   icon = texturePath | nil, iconAtlas = atlasName | nil
--   title, detail, storageText        -- text block (title wraps to 2 lines)
--   pin/alert/fav = { active, onToggle, tooltip }  (toggles)
--   gotoAction/props/delete = { onClick, tooltip }  (buttons)
--   getReorderActive / shouldSuppressSelect = function() -> bool
--     Prefer shouldSuppressSelect (active drag OR completed drag this click).
--     Selection runs on MouseUp so MouseDown can start a reorder without
--     rebuilding the list and killing the drag ghost.
function ns.UI.CreateNotesListRow(scrollChild, opts)
    local height = opts.height or ns.UI.LIST_ROW_HEIGHT

    local row = CreateFrame("Frame", nil, scrollChild, "BackdropTemplate")
    row:SetPoint("TOPLEFT",  scrollChild, "TOPLEFT",  0, opts.yOffset)
    row:SetPoint("TOPRIGHT", scrollChild, "TOPRIGHT", 0, opts.yOffset)
    row:SetHeight(height)
    row:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row._zebraIndex = opts.zebraIndex or OneWoW_GUI:NextZebraIndex(scrollChild)
    OneWoW_GUI:ApplyListRowFill(row, {
        zebraIndex = row._zebraIndex,
        selected = opts.selected and true or false,
    })

    if opts.barColor then
        local bar = row:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", row, "TOPLEFT", 2, -3)
        bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 2, 3)
        bar:SetWidth(4)
        bar:SetColorTexture(opts.barColor[1], opts.barColor[2], opts.barColor[3], 1)
        row.colorBar = bar
    end

    -- Opt-in expand caret (tree parents, e.g. transmog-set nodes). A text caret
    -- (">"/"v") mirrors the Catalog group pattern — no atlas dependency — and
    -- reserves a left column so the icon/text shift right of it.
    local caretPad = 0
    if opts.expand then
        local caret = CreateFrame("Button", nil, row)
        caret:SetSize(16, 20)
        caret:SetPoint("LEFT", row, "LEFT", opts.barColor and 6 or 4, 0)
        local caretFS = OneWoW_GUI:CreateFS(caret, 12)
        caretFS:SetAllPoints()
        caretFS:SetJustifyH("CENTER")
        caretFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        local function renderCaret(expanded)
            caretFS:SetText(expanded and "v" or ">")
        end
        renderCaret(opts.expand.expanded)
        caret:SetScript("OnClick", function()
            if opts.expand.onToggle then opts.expand.onToggle() end
        end)
        AttachRowTooltip(caret, opts.expand.tooltip)
        row.expandBtn = caret
        caretPad = 18
    end

    local iconX = (opts.barColor and 10 or 8) + caretPad
    local textX = (opts.barColor and 12 or 10) + caretPad
    if opts.icon or opts.iconAtlas then
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(26, 26)
        icon:SetPoint("LEFT", row, "LEFT", iconX, 0)
        if opts.iconAtlas and C_Texture.GetAtlasInfo(opts.iconAtlas) then
            icon:SetAtlas(opts.iconAtlas)
        else
            icon:SetTexture(opts.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        end
        row.iconTexture = icon
        textX = iconX + 26 + 6
    end

    local rightReserve = 6

    -- Action cluster: pinned to the bottom-right, filling right -> left. Living
    -- in the bottom band (not vertically centered) keeps it from stealing the
    -- title's horizontal width, so the title stays readable in narrow lists.
    local anchor
    local function place(btn)
        if anchor then
            btn:SetPoint("RIGHT", anchor, "LEFT", -ACTION_GAP, 0)
        else
            btn:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -rightReserve, 5)
        end
        anchor = btn
    end

    if opts.delete then
        local b = MakeActionButton(row, MEDIA .. "icon-trash.png")
        b:SetScript("OnClick", opts.delete.onClick)
        AttachRowTooltip(b, opts.delete.tooltip)
        place(b); row.deleteBtn = b
    end
    if opts.props then
        local b = MakeActionButton(row, MEDIA .. "icon-gears.png")
        b:SetScript("OnClick", opts.props.onClick)
        AttachRowTooltip(b, opts.props.tooltip)
        place(b); row.propsBtn = b
    end
    if opts.fav then
        local b = MakeToggleButton(row, MEDIA .. "icon-fav.png", opts.fav.active, opts.fav.onToggle)
        AttachRowTooltip(b, opts.fav.tooltip)
        place(b); row.favBtn = b
    end
    if opts.alert then
        local b = MakeToggleButton(row, MEDIA .. "icon-alert.png", opts.alert.active, opts.alert.onToggle)
        AttachRowTooltip(b, opts.alert.tooltip)
        place(b); row.alertBtn = b
    end
    if opts.gotoAction then
        local b = MakeActionButton(row, MEDIA .. "icon-compass.png")
        b:SetScript("OnClick", opts.gotoAction.onClick)
        AttachRowTooltip(b, opts.gotoAction.tooltip)
        place(b); row.gotoBtn = b
    end
    if opts.pin then
        local b = MakeToggleButton(row, MEDIA .. "icon-pin.png", opts.pin.active, opts.pin.onToggle)
        AttachRowTooltip(b, opts.pin.tooltip)
        place(b); row.pinBtn = b
    end

    -- Title spans the top band nearly full width. The action cluster lives in
    -- the bottom band, so it does not constrain the title.
    local titleRight = -(rightReserve + 4)

    local title = OneWoW_GUI:CreateFS(row, 12)
    title:SetPoint("TOPLEFT",  row, "TOPLEFT",  textX, -7)
    title:SetPoint("TOPRIGHT", row, "TOPRIGHT", titleRight, -7)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    title:SetText(opts.title or "")
    title:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    row.titleFS = title

    local storageFS
    if opts.storageText and opts.storageText ~= "" then
        storageFS = OneWoW_GUI:CreateFS(row, 10)
        storageFS:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", textX, 7)
        storageFS:SetJustifyH("LEFT")
        storageFS:SetText(opts.storageText)
        storageFS:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row.storageFS = storageFS
    end

    if opts.detail and opts.detail ~= "" then
        local detail = OneWoW_GUI:CreateFS(row, 10)
        if storageFS then
            detail:SetPoint("BOTTOMLEFT", storageFS, "TOPLEFT", 0, 1)
        else
            detail:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", textX, 7)
        end
        detail:SetPoint("RIGHT", row, "RIGHT", titleRight, 0)
        detail:SetJustifyH("LEFT")
        detail:SetWordWrap(false)
        detail:SetText(opts.detail)
        detail:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
        row.detailFS = detail
    end

    row:EnableMouse(true)
    -- Select on MouseUp, not MouseDown: MouseDown must stay free for
    -- CreateReorderDrag. Selecting (and Refresh*List) on press was destroying
    -- the row before the ghost could follow the cursor.
    row:SetScript("OnMouseUp", function()
        local suppress = opts.shouldSuppressSelect or opts.getReorderActive
        if suppress and suppress() then return end
        if opts.onSelect then opts.onSelect() end
    end)
    row:SetScript("OnEnter", function(self)
        if not opts.selected then
            OneWoW_GUI:ApplyListRowFill(self, { hover = true })
        end
    end)
    row:SetScript("OnLeave", function(self)
        if not opts.selected then
            OneWoW_GUI:ApplyListRowFill(self, { zebraIndex = self._zebraIndex })
        end
    end)
    if opts.selected then
        row:SetBackdropBorderColor(1, 0.82, 0, 1)
    end
    row._notesListSelected = opts.selected and true or false

    return row
end

-- Curated icon set for the per-note icon picker (NPC/Zone notes). Every entry
-- uses a guaranteed-present texture (evergreen Blizzard art or shipped Media),
-- and the key is what gets persisted in SavedVariables.
ns.UI.NOTE_ICONS = {
    { key = "gossip",   texture = "Interface\\GossipFrame\\GossipGossipIcon" },
    { key = "quest",    texture = "Interface\\GossipFrame\\AvailableQuestIcon" },
    { key = "skull",    texture = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
    { key = "map",      texture = "Interface\\Icons\\INV_Misc_Map_01" },
    { key = "vendor",   texture = "Interface\\Icons\\INV_Misc_Coin_01" },
    { key = "question", texture = "Interface\\Icons\\INV_Misc_QuestionMark" },
    { key = "flag",     texture = MEDIA .. "icon-flag.png" },
    { key = "compass",  texture = MEDIA .. "icon-compass.png" },
    { key = "pin",      texture = MEDIA .. "icon-pin.png" },
    { key = "alert",    texture = MEDIA .. "icon-alert.png" },
    { key = "star",     texture = MEDIA .. "icon-fav.png" },
    { key = "horde",    texture = MEDIA .. "horde-mini.png" },
    { key = "alliance", texture = MEDIA .. "alliance-mini.png" },
    { key = "neutral",  texture = MEDIA .. "neutral-mini.png" },
}

local _noteIconByKey = {}
for _, def in ipairs(ns.UI.NOTE_ICONS) do _noteIconByKey[def.key] = def.texture end

--- Resolves a stored icon key to its texture. Returns nil for unknown/absent keys.
function ns.UI.ResolveNoteIcon(key)
    return key and _noteIconByKey[key] or nil
end

-- A compact grid of selectable icons. opts:
--   selectedKey, onSelect(key), size (default 26), perRow (default 7)
function ns.UI.CreateIconPicker(parent, opts)
    opts = opts or {}
    local size   = opts.size or 26
    local perRow = opts.perRow or 7
    local gap    = 4
    local icons  = ns.UI.NOTE_ICONS

    local picker = CreateFrame("Frame", nil, parent)
    picker._selectedKey = opts.selectedKey
    picker._buttons = {}

    local function refreshSelection()
        for _, b in ipairs(picker._buttons) do
            if b._iconKey == picker._selectedKey then
                b:SetBackdropBorderColor(1, 0.82, 0, 1)
            else
                b:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            end
        end
    end

    for i, def in ipairs(icons) do
        local col = (i - 1) % perRow
        local rowN = math.floor((i - 1) / perRow)

        local b = CreateFrame("Button", nil, picker, "BackdropTemplate")
        b:SetSize(size, size)
        b:SetPoint("TOPLEFT", picker, "TOPLEFT", col * (size + gap), -rowN * (size + gap))
        b:SetBackdrop(BACKDROP_INNER_NO_INSETS)
        b:SetBackdropColor(0, 0, 0, 0)
        b._iconKey = def.key

        local tex = b:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", -2, 2)
        tex:SetTexture(def.texture)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.2)

        b:SetScript("OnClick", function(self)
            picker._selectedKey = self._iconKey
            refreshSelection()
            if opts.onSelect then opts.onSelect(self._iconKey) end
        end)

        table.insert(picker._buttons, b)
    end

    local rows = math.ceil(#icons / perRow)
    picker:SetWidth(perRow * (size + gap) - gap)
    picker:SetHeight(rows * (size + gap) - gap)
    refreshSelection()

    return picker
end

local _themedDialogs = {}

function ns.UI.CreateThemedDialog(config)
    local dialogName     = config.name or "OneWoW_NotesThemedDialog"
    local destroyOnClose = config.destroyOnClose

    local cached = _themedDialogs[dialogName]
    if destroyOnClose and cached then
        cached:Hide()
        cached:SetParent(nil)
        _themedDialogs[dialogName] = nil
        cached = nil
    end
    if cached then
        if cached:IsShown() then cached:Raise() return cached end
        cached:Show()
        cached:Raise()
        return cached
    end

    local result = OneWoW_GUI:CreateDialog({
        name       = dialogName,
        title      = config.title or "",
        width      = config.width or 500,
        height     = config.height or 400,
        showBrand  = true,
        buttons    = config.buttons,
        onClose    = function()
            if config.onClose then config.onClose() end
            if destroyOnClose then
                _themedDialogs[dialogName] = nil
            end
        end,
    })

    local frame       = result.frame
    frame.content     = result.contentFrame
    frame.titleLabel  = result.titleBar._titleText
    frame.closeBtn    = result.titleBar._closeBtn
    frame.footer      = nil
    _themedDialogs[dialogName] = frame

    frame:SetScript("OnHide", function()
        ns.UI.CloseAllOpenDropdowns()
    end)

    frame:HookScript("OnShow", function(self)
        C_Timer.After(0, function()
            ns.UI.ApplyFontToFrame(self)
        end)
    end)

    frame:Hide()
    return frame
end

function ns.UI.CreateCustomScroll(parent)
    local container = CreateFrame("Frame", nil, parent)

    local scrollFrame, scrollChild = OneWoW_GUI:CreateScrollFrame(container, {})
    -- Fill the container. CreateScrollFrame owns the scrollbar gutter (and
    -- drops it when the bar hides).
    scrollFrame:ClearAllPoints()
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)

    return {
        container   = container,
        scrollFrame = scrollFrame,
        scrollChild = scrollChild,
        UpdateThumb = function() end,
    }
end
