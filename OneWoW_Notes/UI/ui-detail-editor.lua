-- ============================================================================
-- Notes detail-editor chrome builders
-- ============================================================================
-- Shared shells for per-type detail panels (Notes / Zones / Players / NPCs /
-- Items / Collectibles). Each tab still owns composition; these helpers only
-- build the recurring chrome so header/body/tooltip sizes stay aligned.
--
-- Layout numbers: ns.Constants.Detail
-- ============================================================================

local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local BACKDROP_INNER_NO_INSETS = OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS
local MEDIA = OneWoW_GUI.Constants.MEDIA_BASE

ns.UI = ns.UI or {}

local function Detail()
    return ns.Constants.Detail
end

--- Secondary-toned themed bar (control strips, headers, content chrome).
function ns.UI.CreateThemedBar(name, parentFrame)
    local f = CreateFrame("Frame", name, parentFrame, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    return f
end

--- Primary-toned themed panel (list / detail containers).
function ns.UI.CreateThemedPanel(name, parentFrame)
    local f = CreateFrame("Frame", name, parentFrame, "BackdropTemplate")
    f:SetBackdrop(BACKDROP_INNER_NO_INSETS)
    f:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_PRIMARY"))
    f:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
    return f
end

--- Detail header shell: panel insets + HEADER_HEIGHT. Caller adds type-owned children.
---@param detailPanel Frame
---@return Frame header
function ns.UI.CreateDetailHeader(detailPanel)
    local D = Detail()
    local inset = D.PANEL_INSET
    local header = ns.UI.CreateThemedBar(nil, detailPanel)
    header:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", inset, -inset)
    header:SetPoint("TOPRIGHT", detailPanel, "TOPRIGHT", -inset, -inset)
    header:SetHeight(D.HEADER_HEIGHT)
    return header
end

--- Note-body chrome: themed bar + CreateScrollEditBox at BODY_HEIGHT below anchor.
---@param detailPanel Frame
---@param anchorFrame Frame  header, or Collectibles infoBar
---@param options table|nil  { onTextChanged = function(self, userInput) }
---@return table body  { contentBg, contentScroll, contentEditBox }
function ns.UI.CreateDetailBody(detailPanel, anchorFrame, options)
    options = options or {}
    local D = Detail()
    local gap = D.SECTION_GAP
    local inset = D.BODY_SCROLL_INSET

    local contentBg = ns.UI.CreateThemedBar(nil, detailPanel)
    contentBg:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", 0, -gap)
    contentBg:SetPoint("TOPRIGHT", anchorFrame, "BOTTOMRIGHT", 0, -gap)
    contentBg:SetHeight(D.BODY_HEIGHT)
    contentBg:EnableMouse(true)

    local contentScroll, contentEditBox = OneWoW_GUI:CreateScrollEditBox(contentBg, {
        onTextChanged = options.onTextChanged,
    })
    contentScroll:ClearAllPoints()
    contentScroll:SetPoint("TOPLEFT", contentBg, "TOPLEFT", inset[1], inset[2])
    contentScroll:SetPoint("BOTTOMRIGHT", contentBg, "BOTTOMRIGHT", inset[3], inset[4])
    contentBg:SetFrameLevel(contentScroll:GetFrameLevel() - 1)

    return {
        contentBg = contentBg,
        contentScroll = contentScroll,
        contentEditBox = contentEditBox,
    }
end

--- Height of the tooltip-lines section derived from Detail constants.
---@return number
function ns.UI.GetTooltipLinesSectionHeight()
    local D = Detail()
    -- Top pad to first row + remaining rows + bottom pad matching Players (8).
    return math.abs(D.TOOLTIP_FIRST_ROW_Y) + (D.TOOLTIP_LINE_COUNT - 1) * D.TOOLTIP_LINE_PITCH + D.TOOLTIP_LINE_HEIGHT + 8
end

--- Themed tooltip-line edits (Players pattern — not InputBoxTemplate).
---@param detailPanel Frame
---@param contentBg Frame
---@param options table|nil
---  onLineChanged = function(index, text, userInput)
---  enableHyperlinks = boolean (default true)
---@return table result  { section, edits }
function ns.UI.CreateTooltipLinesSection(detailPanel, contentBg, options)
    options = options or {}
    local D = Detail()
    local gap = D.SECTION_GAP
    local enableHyperlinks = options.enableHyperlinks ~= false
    local onLineChanged = options.onLineChanged

    local section = ns.UI.CreateThemedBar(nil, detailPanel)
    section:SetPoint("TOPLEFT", contentBg, "BOTTOMLEFT", 0, -gap)
    section:SetPoint("TOPRIGHT", contentBg, "BOTTOMRIGHT", 0, -gap)
    section:SetHeight(ns.UI.GetTooltipLinesSectionHeight())

    local ttLabel = OneWoW_GUI:CreateFS(section, 12)
    ttLabel:SetPoint("TOPLEFT", section, "TOPLEFT", 10, D.TOOLTIP_LABEL_Y)
    ttLabel:SetText(L["UI_TOOLTIP_LINES"])
    ttLabel:SetTextColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))

    local edits = {}
    for i = 1, D.TOOLTIP_LINE_COUNT do
        local edit = OneWoW_GUI:CreateEditBox(section, {
            height = D.TOOLTIP_LINE_HEIGHT,
            maxLetters = 255,
        })
        edit:ClearAllPoints()
        local y = D.TOOLTIP_FIRST_ROW_Y - (i - 1) * D.TOOLTIP_LINE_PITCH
        edit:SetPoint("TOPLEFT", section, "TOPLEFT", 10, y)
        edit:SetPoint("TOPRIGHT", section, "TOPRIGHT", -10, y)
        edit:SetAutoFocus(false)

        if enableHyperlinks then
            edit:SetHyperlinksEnabled(true)
            edit:SetScript("OnHyperlinkClick", function(_, link, text, button)
                SetItemRef(link, text, button)
            end)
        end

        edit:SetScript("OnEnterPressed", function(myself) myself:ClearFocus() end)
        edit:SetScript("OnEscapePressed", function(myself) myself:ClearFocus() end)
        edit:SetScript("OnTextChanged", function(myself, userInput)
            if onLineChanged then
                onLineChanged(i, myself:GetText(), userInput)
            end
        end)
        edit:SetScript("OnReceiveDrag", function(myself)
            local cursorType, _, itemLink = GetCursorInfo()
            if cursorType == "item" and itemLink then
                myself:Insert(itemLink)
                ClearCursor()
            end
        end)
        edit:SetScript("OnMouseUp", function(myself, button)
            if button == "RightButton" and ns.NotesContextMenu then
                ns.NotesContextMenu:ShowEditBoxContextMenu(myself)
            end
        end)
        if ns.NotesHyperlinks then
            ns.NotesHyperlinks:EnhanceEditBox(edit)
        end
        edits[i] = edit
    end

    return { section = section, edits = edits }
end

--- Standard header action icon (Button or CheckButton with MEDIA texture).
---@param header Frame
---@param options table
---  check = boolean → CheckButton with desaturate inactive look
---  texture = string filename under MEDIA (e.g. "icon-trash.png")
---  relativeTo = Frame|nil  default TOPRIGHT of header
---  point / relativePoint / x / y
---  onClick, tooltipTitle, tooltipDesc
---@return Button|CheckButton
function ns.UI.CreateHeaderIconButton(header, options)
    options = options or {}
    local D = Detail()
    local btn = OneWoW_GUI:CreateIconButton(header, {
        iconTexture = MEDIA .. (options.texture or "icon-gears.png"),
        size = D.HEADER_ICON_SIZE,
        check = options.check,
        checked = options.checked,
        tooltipTitle = options.tooltipTitle,
        tooltipText = options.tooltipDesc,
        onClick = options.onClick,
        onToggle = options.onToggle,
    })

    if options.relativeTo then
        btn:SetPoint(
            options.point or "RIGHT",
            options.relativeTo,
            options.relativePoint or "LEFT",
            options.x or -2,
            options.y or 0
        )
    else
        btn:SetPoint(
            options.point or "TOPRIGHT",
            header,
            options.relativePoint or "TOPRIGHT",
            options.x or -12,
            options.y or -12
        )
    end

    return btn
end
