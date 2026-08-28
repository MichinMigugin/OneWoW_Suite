local _, ns = ...
local L = ns.L

local OneWoW_GUI = OneWoW_GUI
local C = OneWoW_GUI.Constants

-- ============================================================================
-- OneWay Pin create / edit dialog
-- ============================================================================

ns.UI = ns.UI or {}

local ICON_CELL = 26
local ICON_PAD = 4
local GRID_COLS = 10
local BG_CELL = 26

local dialog
local fields = {}
local selectedIcon
local selectedBg
local bgEnabled
local iconEffect
local bgEffect
local editingID
local iconButtons = {}
local bgButtons = {}

local function DefaultIcon()
    return { kind = "list", value = "VignetteEvent-SuperTracked" }
end

local function EffectOptions()
    return {
        { text = L["OVR_EFFECT_NONE"],     value = "none" },
        { text = L["OVR_EFFECT_SPINNING"], value = "spinning" },
        { text = L["OVR_EFFECT_ZOOMING"],  value = "zooming" },
        { text = L["OVR_EFFECT_BOTH"],     value = "both" },
    }
end

local function PaintIconCell(btn, spec, selected)
    OneWoW.OverlayIcons:ApplyIconSpec(btn.tex, spec)
    if selected then
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
    else
        btn:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        btn:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    end
end

local function RebuildIconGrid()
    if not dialog then return end
    local list = OneWoW.OverlayIcons:GetIconList()
    local i = 0
    for _, name in ipairs(list) do
        if name ~= "BLANK" then
            i = i + 1
            local btn = iconButtons[i]
            if not btn then
                btn = CreateFrame("Button", nil, dialog.iconChild, "BackdropTemplate")
                btn:SetSize(ICON_CELL, ICON_CELL)
                btn:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
                local tex = btn:CreateTexture(nil, "ARTWORK")
                tex:SetPoint("TOPLEFT", 2, -2)
                tex:SetPoint("BOTTOMRIGHT", -2, 2)
                btn.tex = tex
                btn:SetScript("OnClick", function(myself)
                    selectedIcon = { kind = "list", value = myself.iconName }
                    RebuildIconGrid()
                end)
                btn:SetScript("OnEnter", function(myself)
                    GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                    GameTooltip:SetText(OneWoW.OverlayIcons:GetDisplayName(myself.iconName), 1, 1, 1)
                    GameTooltip:Show()
                end)
                btn:SetScript("OnLeave", GameTooltip_Hide)
                iconButtons[i] = btn
            end
            btn.iconName = name
            local col = (i - 1) % GRID_COLS
            local row = math.floor((i - 1) / GRID_COLS)
            btn:ClearAllPoints()
            btn:SetPoint("TOPLEFT", dialog.iconChild, "TOPLEFT",
                col * (ICON_CELL + ICON_PAD),
                -row * (ICON_CELL + ICON_PAD))
            local spec = { kind = "list", value = name }
            local isSel = selectedIcon and selectedIcon.value == name
            PaintIconCell(btn, spec, isSel)
            btn:Show()
        end
    end
    local rows = math.ceil(i / GRID_COLS)
    dialog.iconChild:SetHeight(math.max(rows * (ICON_CELL + ICON_PAD), 1))
    for j = i + 1, #iconButtons do
        iconButtons[j]:Hide()
    end
end

local function RebuildBgGrid()
    if not dialog then return end
    local list = ns.WayPinsVisual.BG_STYLES
    for i, name in ipairs(list) do
        local btn = bgButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, dialog.bgChild, "BackdropTemplate")
            btn:SetSize(BG_CELL, BG_CELL)
            btn:SetBackdrop(C.BACKDROP_INNER_NO_INSETS)
            local tex = btn:CreateTexture(nil, "ARTWORK")
            tex:SetPoint("TOPLEFT", 2, -2)
            tex:SetPoint("BOTTOMRIGHT", -2, 2)
            btn.tex = tex
            btn:SetScript("OnClick", function(myself)
                selectedBg = myself.styleName
                RebuildBgGrid()
            end)
            btn:SetScript("OnEnter", function(myself)
                GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
                GameTooltip:SetText(OneWoW.OverlayIcons:GetDisplayName(myself.styleName), 1, 1, 1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", GameTooltip_Hide)
            bgButtons[i] = btn
        end
        btn.styleName = name
        local col = (i - 1) % GRID_COLS
        local row = math.floor((i - 1) / GRID_COLS)
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", dialog.bgChild, "TOPLEFT",
            col * (BG_CELL + ICON_PAD),
            -row * (BG_CELL + ICON_PAD))
        PaintIconCell(btn, { kind = "list", value = name }, selectedBg == name)
        btn:Show()
    end
    local rows = math.ceil(#list / GRID_COLS)
    dialog.bgChild:SetHeight(math.max(rows * (BG_CELL + ICON_PAD), 1))
end

local function ReadNumber(box)
    return tonumber(box:GetSearchText())
end

local function SaveFromDialog()
    local title = fields.title:GetSearchText()
    local mapID = ReadNumber(fields.mapID)
    local x = ReadNumber(fields.x)
    local y = ReadNumber(fields.y)
    if not mapID or not x or not y then
        return
    end
    local payload = {
        id      = editingID,
        title   = title,
        mapID   = mapID,
        x       = x,
        y       = y,
        icon    = selectedIcon or DefaultIcon(),
        effect  = iconEffect,
        mapSize = fields.mapSize,
        storage = fields.storageValue or "account",
        source  = fields.source or "manual",
        sourceKey = fields.sourceKey,
    }
    if bgEnabled and selectedBg then
        payload.bg = {
            enabled = true,
            style = selectedBg,
            effect = bgEffect or "none",
        }
    end
    if editingID and ns.WayPins:GetPin(editingID) then
        local existing = ns.WayPins:GetPin(editingID)
        payload.created = existing.created
        payload.source = existing.source or payload.source
        payload.sourceKey = existing.sourceKey or payload.sourceKey
        ns.WayPins:Save(editingID, payload)
    else
        ns.WayPins:Add(payload)
    end
    dialog.frame:Hide()
end

local function EnsureDialog()
    if dialog then return dialog end

    dialog = OneWoW_GUI:CreateDialog({
        name   = "OneWoW_NotesWayPinDialog",
        title  = L["WAYPINS_DIALOG_TITLE"],
        width  = 460,
        height = 640,
        buttons = {
            { text = SAVE, onClick = function() SaveFromDialog() end },
            { text = CANCEL, onClick = function(f) f:Hide() end },
        },
    })

    local content = dialog.contentFrame
    local y = -10

    local nameLabel = OneWoW_GUI:CreateFS(content, 12)
    nameLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    nameLabel:SetText(NAME)
    nameLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - 16

    fields.title = OneWoW_GUI:CreateEditBox(content, {
        placeholderText = L["WAYPINS_UNTITLED"],
        maxLetters = 80,
    })
    fields.title:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    fields.title:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    y = y - 30

    local coordLabel = OneWoW_GUI:CreateFS(content, 12)
    coordLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    coordLabel:SetText(L["WAYPINS_COORDS"])
    coordLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - 16

    fields.mapID = OneWoW_GUI:CreateEditBox(content, { width = 90, maxLetters = 8, showClear = false })
    fields.mapID:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    fields.mapID:SetNumeric(true)

    fields.x = OneWoW_GUI:CreateEditBox(content, { width = 90, maxLetters = 8, showClear = false })
    fields.x:SetPoint("LEFT", fields.mapID, "RIGHT", 8, 0)

    fields.y = OneWoW_GUI:CreateEditBox(content, { width = 90, maxLetters = 8, showClear = false })
    fields.y:SetPoint("LEFT", fields.x, "RIGHT", 8, 0)
    y = y - 30

    local storeDD = ns.UI.CreateThemedDropdown(content, L["LABEL_STORAGE"], 180, 24)
    storeDD:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    storeDD:SetOptions({
        { text = L["UI_STORAGE_ACCOUNT"], value = "account" },
        { text = CHARACTER, value = "character" },
    })
    storeDD.onSelect = function(value)
        fields.storageValue = value
    end
    fields.storageDD = storeDD

    local sizeLabel = OneWoW_GUI:CreateFS(content, 11)
    sizeLabel:SetPoint("LEFT", storeDD, "RIGHT", 16, 0)
    sizeLabel:SetText(L["WAYPINS_SIZE_WORLD"])
    sizeLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    y = y - 28

    local sizeSlider = OneWoW_GUI:CreateSlider(content, {
        minVal = 12,
        maxVal = 48,
        step = 1,
        currentVal = ns.WayPinsVisual.WorldDefault(),
        width = 220,
        fmt = "%.0f",
        onChange = function(val)
            fields.mapSize = val
        end,
    })
    sizeSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    fields.sizeSlider = sizeSlider
    y = y - 40

    local warn = OneWoW_GUI:CreateFS(content, 10)
    warn:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    warn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    warn:SetJustifyH("LEFT")
    warn:SetWordWrap(true)
    warn:SetText(L["WAYPINS_LAYERS_WARN"])
    warn:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
    y = y - 28

    local iconLabel = OneWoW_GUI:CreateFS(content, 12)
    iconLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    iconLabel:SetText(L["OVR_ICON_LABEL"])
    iconLabel:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    y = y - 18

    local iconScroll, iconChild = OneWoW_GUI:CreateScrollFrame(content, {})
    iconScroll:ClearAllPoints()
    iconScroll:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    iconScroll:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    iconScroll:SetHeight(118)
    dialog.iconScroll = iconScroll
    dialog.iconChild = iconChild
    y = y - 126

    local bgCheck = OneWoW_GUI:CreateCheckbox(content, {
        label = L["OVR_BG_ENABLE_LABEL"],
        checked = false,
        onClick = function(myself)
            bgEnabled = myself:GetChecked() and true or false
        end,
    })
    bgCheck:SetPoint("TOPLEFT", content, "TOPLEFT", 10, y)
    fields.bgCheck = bgCheck
    y = y - 26

    local bgScroll, bgChild = OneWoW_GUI:CreateScrollFrame(content, {})
    bgScroll:ClearAllPoints()
    bgScroll:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    bgScroll:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, y)
    bgScroll:SetHeight(64)
    dialog.bgScroll = bgScroll
    dialog.bgChild = bgChild
    y = y - 72

    local iconEffDD = ns.UI.CreateThemedDropdown(content, L["OVR_EFFECT_LABEL"], 200, 24)
    iconEffDD:SetPoint("TOPLEFT", content, "TOPLEFT", 14, y)
    iconEffDD:SetOptions(EffectOptions())
    iconEffDD.onSelect = function(value)
        iconEffect = value
    end
    fields.iconEffDD = iconEffDD

    local bgEffDD = ns.UI.CreateThemedDropdown(content, L["OVR_EFFECT_LABEL"], 200, 24)
    bgEffDD:SetPoint("LEFT", iconEffDD, "RIGHT", 10, 0)
    bgEffDD:SetOptions(EffectOptions())
    bgEffDD.onSelect = function(value)
        bgEffect = value
    end
    fields.bgEffDD = bgEffDD

    fields.deleteBtn = OneWoW_GUI:CreateFitTextButton(content, { text = DELETE, height = 24 })
    fields.deleteBtn:SetPoint("BOTTOMLEFT", content, "BOTTOMLEFT", 14, 8)
    fields.deleteBtn:SetScript("OnClick", function()
        if editingID then
            ns.WayPins:Remove(editingID)
        end
        dialog.frame:Hide()
    end)

    return dialog
end

--- Open the create/edit dialog. `seed` may be an existing pin or a coord draft.
---@param seed table|nil
function ns.UI.OpenWayPinDialog(seed)
    EnsureDialog()
    seed = seed or {}
    editingID = seed.id
    fields.source = seed.source
    fields.sourceKey = seed.sourceKey
    fields.storageValue = seed.storage == "character" and "character" or "account"
    if fields.storageDD then
        fields.storageDD:SetSelected(fields.storageValue)
    end
    selectedIcon = seed.icon and {
        kind = seed.icon.kind or "list",
        value = seed.icon.value,
    } or DefaultIcon()
    bgEnabled = seed.bg and seed.bg.enabled and true or false
    selectedBg = (seed.bg and seed.bg.style) or "Solid-Circle"
    iconEffect = seed.effect or "none"
    bgEffect = (seed.bg and seed.bg.effect) or "none"
    fields.mapSize = seed.mapSize or ns.WayPinsVisual.WorldDefault()

    fields.title:SetText(seed.title or "")
    fields.mapID:SetText(seed.mapID and tostring(seed.mapID) or "")
    fields.x:SetText(seed.x and string.format("%.2f", seed.x) or "")
    fields.y:SetText(seed.y and string.format("%.2f", seed.y) or "")
    fields.sizeSlider.slider:SetValue(fields.mapSize)
    fields.bgCheck:SetChecked(bgEnabled)
    fields.iconEffDD:SetSelected(iconEffect)
    fields.bgEffDD:SetSelected(bgEffect)

    if editingID then
        fields.deleteBtn:Show()
        dialog.titleBar._titleText:SetText(L["WAYPINS_DIALOG_EDIT"])
    else
        fields.deleteBtn:Hide()
        dialog.titleBar._titleText:SetText(L["WAYPINS_DIALOG_TITLE"])
    end

    RebuildIconGrid()
    RebuildBgGrid()
    dialog.frame:Show()
    dialog.frame:Raise()
end
