local OneWoW_GUI = OneWoW_GUI

local CreateFrame = CreateFrame
local max = math.max
local floor = math.floor
local abs = math.abs
local tinsert = tinsert
local wipe = wipe
local tostring = tostring

local Constants = OneWoW_GUI.Constants

local SPARK_MAX_POINTS = 48
local SPARK_HEIGHT = 18

local function downsample(values, maxPoints)
    local n = #values
    if n <= maxPoints then
        return values
    end
    local out = {}
    local step = (n - 1) / (maxPoints - 1)
    for i = 1, maxPoints do
        local idx = floor((i - 1) * step + 1.5)
        if idx < 1 then idx = 1 end
        if idx > n then idx = n end
        out[i] = values[idx]
    end
    return out
end

local function toneColor(tone)
    if tone == "up" then
        return OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY")
    elseif tone == "down" then
        return OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER")
    end
    return OneWoW_GUI:GetThemeColor("TEXT_SECONDARY")
end

--- Splunk-style single-value metric panel: label + optional high/low (header
--- row), hero value, optional delta, and a dumb sparkline (texture pool,
--- redraw on SetSparkline only).
---@param parent Frame
---@param options table|nil label, height, ttTitle, ttDesc
---@return Frame panel
function OneWoW_GUI:CreateMetricPanel(parent, options)
    options = options or {}
    local labelText = options.label or ""
    local height = options.height or 88
    local ttTitle = options.ttTitle or labelText
    local ttDesc = options.ttDesc or ""

    local fontOffset = OneWoW_GUI:GetFontSizeOffset() or 0
    local totalHeight = height + math.max(0, fontOffset) * 6

    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetHeight(totalHeight)
    panel._baseHeight = height
    panel:SetBackdrop(Constants.BACKDROP_INNER_NO_INSETS)
    panel:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    panel:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    panel.extraTooltipLines = {}

    local rangeCol = CreateFrame("Frame", nil, panel)
    rangeCol:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -6)
    rangeCol:SetSize(1, 1)
    rangeCol:Hide()
    panel.rangeCol = rangeCol

    local rangeHigh = rangeCol:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SetFontBaseSize(rangeHigh, 9)
    OneWoW_GUI:SafeSetFont(rangeHigh, OneWoW_GUI:GetFont(), 9)
    rangeHigh:SetPoint("TOPRIGHT", rangeCol, "TOPRIGHT", 0, 0)
    rangeHigh:SetJustifyH("RIGHT")
    rangeHigh:SetText("")
    rangeHigh:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rangeHigh:Hide()
    panel.rangeHigh = rangeHigh

    local rangeLow = rangeCol:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SetFontBaseSize(rangeLow, 9)
    OneWoW_GUI:SafeSetFont(rangeLow, OneWoW_GUI:GetFont(), 9)
    rangeLow:SetPoint("TOPRIGHT", rangeHigh, "BOTTOMRIGHT", 0, -1)
    rangeLow:SetJustifyH("RIGHT")
    rangeLow:SetText("")
    rangeLow:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    rangeLow:Hide()
    panel.rangeLow = rangeLow
    -- Back-compat alias used by older callers poking panel.range
    panel.range = rangeHigh

    local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SetFontBaseSize(label, 10)
    OneWoW_GUI:SafeSetFont(label, OneWoW_GUI:GetFont(), 10)
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)
    label:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -6)
    label:SetJustifyH("LEFT")
    label:SetText(labelText)
    label:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    panel.label = label

    local value = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    OneWoW_GUI:SetFontBaseSize(value, 14)
    OneWoW_GUI:SafeSetFont(value, OneWoW_GUI:GetFont(), 14)
    value:SetJustifyH("LEFT")
    value:SetText("0")
    value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    panel.value = value

    local delta = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    OneWoW_GUI:SetFontBaseSize(delta, 10)
    OneWoW_GUI:SafeSetFont(delta, OneWoW_GUI:GetFont(), 10)
    delta:SetJustifyH("LEFT")
    delta:SetText("")
    delta:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    delta:Hide()
    panel.delta = delta

    local function layoutHeader()
        local rangeShown = rangeCol:IsShown()
        label:ClearAllPoints()
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -6)
        if rangeShown then
            label:SetPoint("RIGHT", rangeCol, "LEFT", -8, 0)
        else
            label:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -6)
        end

        value:ClearAllPoints()
        value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
        if rangeShown then
            value:SetPoint("RIGHT", rangeCol, "LEFT", -8, 0)
        else
            value:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
        end

        delta:ClearAllPoints()
        delta:SetPoint("TOPLEFT", value, "BOTTOMLEFT", 0, -2)
        if rangeShown then
            delta:SetPoint("RIGHT", rangeCol, "LEFT", -8, 0)
        else
            delta:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
        end
    end
    panel._layoutHeader = layoutHeader
    layoutHeader()

    local spark = CreateFrame("Frame", nil, panel)
    spark:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 8, 6)
    spark:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 6)
    spark:SetHeight(SPARK_HEIGHT)
    spark:Hide()
    panel.spark = spark
    panel._sparkBars = {}

    panel:EnableMouse(true)
    panel:SetScript("OnEnter", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_HOVER"))
        GameTooltip:SetOwner(myself, "ANCHOR_RIGHT")
        GameTooltip:SetText(ttTitle ~= "" and ttTitle or labelText, 1, 1, 1)
        if ttDesc ~= "" then
            GameTooltip:AddLine(ttDesc, nil, nil, nil, true)
        end
        if myself.extraTooltipLines and #myself.extraTooltipLines > 0 then
            GameTooltip:AddLine(" ")
            for _, line in ipairs(myself.extraTooltipLines) do
                GameTooltip:AddLine(line.text, line.r or 0.8, line.g or 0.8, line.b or 0.8, line.wrap)
            end
        end
        GameTooltip:Show()
    end)
    panel:SetScript("OnLeave", function(myself)
        myself:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        GameTooltip:Hide()
    end)

    ---@param text string|number
    ---@param opts table|nil color theme key
    function panel:SetValue(text, opts)
        opts = opts or {}
        self.value:SetText(text ~= nil and tostring(text) or "0")
        if opts.color then
            self.value:SetTextColor(OneWoW_GUI:GetThemeColor(opts.color))
        else
            self.value:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
        end
    end

    ---@param text string|nil
    ---@param opts table|nil tone = "up"|"down"|"neutral"
    function panel:SetDelta(text, opts)
        opts = opts or {}
        if not text or text == "" then
            self.delta:SetText("")
            self.delta:Hide()
            return
        end
        self.delta:SetText(text)
        self.delta:SetTextColor(toneColor(opts.tone or "neutral"))
        self.delta:Show()
    end

    ---@param highText string|nil
    ---@param lowText string|nil
    function panel:SetRange(highText, lowText)
        local hasHigh = highText and highText ~= ""
        local hasLow = lowText and lowText ~= ""
        if not hasHigh and not hasLow then
            self.rangeHigh:SetText("")
            self.rangeLow:SetText("")
            self.rangeHigh:Hide()
            self.rangeLow:Hide()
            self.rangeCol:Hide()
            self._layoutHeader()
            return
        end

        if hasHigh then
            self.rangeHigh:SetText(highText)
            self.rangeHigh:Show()
        else
            self.rangeHigh:SetText("")
            self.rangeHigh:Hide()
        end
        if hasLow then
            self.rangeLow:SetText(lowText)
            self.rangeLow:Show()
            if hasHigh then
                self.rangeLow:ClearAllPoints()
                self.rangeLow:SetPoint("TOPRIGHT", self.rangeHigh, "BOTTOMRIGHT", 0, -1)
            else
                self.rangeLow:ClearAllPoints()
                self.rangeLow:SetPoint("TOPRIGHT", self.rangeCol, "TOPRIGHT", 0, 0)
            end
        else
            self.rangeLow:SetText("")
            self.rangeLow:Hide()
        end

        local w = 0
        local h = 0
        if self.rangeHigh:IsShown() then
            w = max(w, self.rangeHigh:GetStringWidth())
            h = h + self.rangeHigh:GetStringHeight()
        end
        if self.rangeLow:IsShown() then
            w = max(w, self.rangeLow:GetStringWidth())
            if self.rangeHigh:IsShown() then
                h = h + 1
            end
            h = h + self.rangeLow:GetStringHeight()
        end
        self.rangeCol:SetSize(max(1, w), max(1, h))
        self.rangeCol:Show()
        self._layoutHeader()
    end

    ---@param values number[]|nil
    ---@param opts table|nil bipolar = true for signed profit series
    function panel:SetSparkline(values, opts)
        opts = opts or {}
        for _, bar in ipairs(self._sparkBars) do
            bar:Hide()
        end

        if not values or #values < 2 then
            self.spark:Hide()
            return
        end

        local samples = downsample(values, SPARK_MAX_POINTS)
        local n = #samples
        local lo, hi = samples[1], samples[1]
        for i = 2, n do
            local v = samples[i]
            if v < lo then lo = v end
            if v > hi then hi = v end
        end
        if hi == lo then
            hi = lo + 1
        end

        local width = self.spark:GetWidth()
        if width <= 0 then
            width = 100
        end
        local gap = 1
        local barW = max(1, floor((width - gap * (n - 1)) / n))

        local bipolar = opts.bipolar == true
        local zeroY = SPARK_HEIGHT / 2

        for i = 1, n do
            local bar = self._sparkBars[i]
            if not bar then
                bar = self.spark:CreateTexture(nil, "ARTWORK")
                self._sparkBars[i] = bar
            end
            local v = samples[i]
            local x = (i - 1) * (barW + gap)
            bar:ClearAllPoints()

            if bipolar then
                local mid = 0
                local span = max(abs(lo - mid), abs(hi - mid), 1)
                local h = max(1, floor((abs(v - mid) / span) * (SPARK_HEIGHT / 2)))
                if v >= 0 then
                    bar:SetPoint("BOTTOMLEFT", self.spark, "BOTTOMLEFT", x, zeroY)
                    bar:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
                else
                    bar:SetPoint("TOPLEFT", self.spark, "BOTTOMLEFT", x, zeroY)
                    bar:SetColorTexture(OneWoW_GUI:GetThemeColor("BTN_DANGER_BORDER"))
                end
                bar:SetSize(barW, h)
            else
                local h = max(1, floor(((v - lo) / (hi - lo)) * SPARK_HEIGHT))
                bar:SetPoint("BOTTOMLEFT", self.spark, "BOTTOMLEFT", x, 0)
                bar:SetSize(barW, h)
                bar:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            end
            bar:Show()
        end

        self.spark:Show()
    end

    ---@param lines table|nil list of { text, r, g, b, wrap }
    function panel:SetTooltipExtra(lines)
        wipe(self.extraTooltipLines)
        if not lines then return end
        for _, line in ipairs(lines) do
            tinsert(self.extraTooltipLines, line)
        end
    end

    ---@param text string
    function panel:SetLabel(text)
        self.label:SetText(text or "")
    end

    return panel
end
