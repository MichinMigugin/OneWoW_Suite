local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame

local Constants = OneWoW_GUI.Constants

function OneWoW_GUI:CreateStatusDot(parent, options)
    options = options or {}
    local size = options.size or 8

    local dot = parent:CreateTexture(nil, "OVERLAY")
    dot:SetSize(size, size)
    dot:SetTexture(Constants.BACKDROP_SIMPLE.bgFile)

    if options.enabled == true then
        dot:SetVertexColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED"))
    elseif options.enabled == false then
        dot:SetVertexColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_DISABLED"))
    end

    function dot:SetStatus(enabled)
        if enabled then
            self:SetVertexColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_ENABLED"))
        else
            self:SetVertexColor(OneWoW_GUI:GetThemeColor("DOT_FEATURES_DISABLED"))
        end
    end

    return dot
end

--- Odd rows use BG_PRIMARY, even rows BG_SECONDARY.
---@param index number|nil
---@return string
function OneWoW_GUI:GetZebraThemeKey(index)
    if (index or 0) % 2 == 1 then
        return "BG_PRIMARY"
    end
    return "BG_SECONDARY"
end

--- Next 1-based stripe index for stacked rows on parent. ClearFrame resets the seq.
---@param parent Frame
---@return number
function OneWoW_GUI:NextZebraIndex(parent)
    parent._onewowZebraSeq = (parent._onewowZebraSeq or 0) + 1
    return parent._onewowZebraSeq
end

--- Idle / hover / selected fill. fillKey wins when set (quest section tints, opt-out).
---@param frame Frame
---@param state table|nil
function OneWoW_GUI:ApplyListRowFill(frame, state)
    state = state or {}
    local fillKey
    if state.fillKey then
        fillKey = state.fillKey
    elseif state.selected then
        fillKey = "BG_ACTIVE"
    elseif state.hover then
        fillKey = "BG_HOVER"
    elseif state.header then
        fillKey = "BG_TERTIARY"
    else
        fillKey = self:GetZebraThemeKey(state.zebraIndex or frame._zebraIndex or 1)
    end
    frame:SetBackdropColor(self:GetThemeColor(fillKey))
end

function OneWoW_GUI:CreateListRowBasic(parent, options)
    options = options or {}
    local height = options.height or 30
    local labelText = options.label or ""
    local onClick = options.onClick
    local showDot = options.showDot
    local dotEnabled = options.dotEnabled
    local showValueText = options.showValueText
    local valueText = options.valueText or ""
    local showFavoriteGlyph = options.showFavoriteGlyph
    local favoriteToggle = options.favoriteToggle

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(height)
    row:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row.isActive = false

    local useZebra = options.zebra ~= false
    if useZebra then
        row._zebraIndex = options.zebraIndex or OneWoW_GUI:NextZebraIndex(parent)
    else
        row._idleFillKey = "BG_SECONDARY"
    end
    OneWoW_GUI:ApplyListRowFill(row, {
        zebraIndex = row._zebraIndex,
        fillKey = row._idleFillKey,
    })

    if showDot then
        row.dot = self:CreateStatusDot(row, { enabled = dotEnabled })
        row.dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    end

    if favoriteToggle and type(favoriteToggle) == "table" and Constants.FAVORITE_ATLAS then
        local ft = favoriteToggle
        row.favoriteBtn = self:CreateFavoriteToggleButton(row, {
            size     = ft.size or 18,
            favorite = ft.isFavorite == true,
            tooltipTitle = ft.tooltipTitle,
            tooltipText  = ft.tooltipText,
            onClick = function(_, isFav)
                if ft.onChange then
                    ft.onChange(isFav)
                end
            end,
        })
        if showDot and row.dot then
            row.favoriteBtn:SetPoint("RIGHT", row.dot, "LEFT", -6, 0)
        else
            row.favoriteBtn:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        end
        row.favoriteBtn:SetFrameLevel((row:GetFrameLevel() or 0) + 20)
    elseif showFavoriteGlyph and Constants.FAVORITE_ATLAS then
        row.favoriteGlyph = row:CreateTexture(nil, "OVERLAY")
        row.favoriteGlyph:SetSize(14, 14)
        row.favoriteGlyph:SetAtlas(Constants.FAVORITE_ATLAS)
        if showDot and row.dot then
            row.favoriteGlyph:SetPoint("RIGHT", row.dot, "LEFT", -6, 0)
        else
            row.favoriteGlyph:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        end
    end

    if showValueText then
        row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.valueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row.valueText:SetJustifyH("RIGHT")
        row.valueText:SetText(valueText)
    end

    -- Right-edge stack: dot (outer) → favorite → valueText → label.
    if row.valueText then
        if row.favoriteBtn then
            row.valueText:SetPoint("RIGHT", row.favoriteBtn, "LEFT", -6, 0)
        elseif row.favoriteGlyph then
            row.valueText:SetPoint("RIGHT", row.favoriteGlyph, "LEFT", -6, 0)
        elseif row.dot then
            row.valueText:SetPoint("RIGHT", row.dot, "LEFT", -6, 0)
        else
            row.valueText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        end
    end

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
    if row.valueText then
        row.label:SetPoint("RIGHT", row.valueText, "LEFT", -4, 0)
    elseif showDot then
        local labelRightPad = -24
        if row.favoriteBtn then
            labelRightPad = -48
        elseif showFavoriteGlyph and row.favoriteGlyph then
            labelRightPad = -40
        end
        row.label:SetPoint("RIGHT", row, "RIGHT", labelRightPad, 0)
    else
        row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    end
    row.label:SetJustifyH("LEFT")
    row.label:SetText(labelText)
    row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    function row:SetActive(active)
        self.isActive = active
        if active then
            OneWoW_GUI:ApplyListRowFill(self, { selected = true })
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            OneWoW_GUI:ApplyListRowFill(self, {
                zebraIndex = self._zebraIndex,
                fillKey = self._idleFillKey,
            })
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    row:SetScript("OnEnter", function(myself)
        if not myself.isActive then
            OneWoW_GUI:ApplyListRowFill(myself, { hover = true })
            myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end
    end)
    row:SetScript("OnLeave", function(myself)
        if not myself.isActive then
            OneWoW_GUI:ApplyListRowFill(myself, {
                zebraIndex = myself._zebraIndex,
                fillKey = myself._idleFillKey,
            })
            myself.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    if onClick then
        row:SetScript("OnClick", function(myself) onClick(myself) end)
    end

    return row
end
