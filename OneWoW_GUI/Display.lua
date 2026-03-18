local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

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

function OneWoW_GUI:CreateListRowBasic(parent, options)
    options = options or {}
    local height = options.height or 30
    local labelText = options.label or ""
    local onClick = options.onClick
    local showDot = options.showDot
    local dotEnabled = options.dotEnabled
    local showValueText = options.showValueText
    local valueText = options.valueText or ""

    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetHeight(height)
    row:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    row:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
    row:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    row.isActive = false

    if showDot then
        row.dot = self:CreateStatusDot(row, { enabled = dotEnabled })
        row.dot:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    end

    if showValueText then
        row.valueText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.valueText:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.valueText:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_MUTED"))
        row.valueText:SetJustifyH("RIGHT")
        row.valueText:SetText(valueText)
    end

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row, "LEFT", 10, 0)
    if showDot then
        row.label:SetPoint("RIGHT", row, "RIGHT", -24, 0)
    elseif showValueText and row.valueText then
        row.label:SetPoint("RIGHT", row.valueText, "LEFT", -4, 0)
    else
        row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    end
    row.label:SetJustifyH("LEFT")
    row.label:SetText(labelText)
    row.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))

    function row:SetActive(active)
        self.isActive = active
        if active then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_ACTIVE"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_ACCENT"))
            self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        else
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            self:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
            self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    row:SetScript("OnEnter", function(self)
        if not self.isActive then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
            self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_ACCENT"))
        end
    end)
    row:SetScript("OnLeave", function(self)
        if not self.isActive then
            self:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_SECONDARY"))
            self.label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end)

    if onClick then
        row:SetScript("OnClick", function(self) onClick(self) end)
    end

    return row
end
