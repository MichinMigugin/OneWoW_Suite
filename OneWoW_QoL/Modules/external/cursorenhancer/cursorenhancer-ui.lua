local _, ns = ...
local CursorEnhancerModule, L = ns.ModuleRegistry:Current()
local CE = CursorEnhancerModule.CE

local colorSwatches = {}

local function OpenColorPicker(dbKey)
    local settings = CE:GetSettings()
    local color = settings[dbKey] or {1, 1, 1}

    ColorPickerFrame:SetupColorPickerAndShow({
        r = color[1],
        g = color[2],
        b = color[3],
        opacity = 1,
        swatchFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            settings[dbKey] = {r, g, b}
            CE:UpdateAll()
            if colorSwatches[dbKey] then
                colorSwatches[dbKey]:UpdateColor()
            end
        end,
        opacityFunc = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            settings[dbKey] = {r, g, b}
            CE:UpdateAll()
            if colorSwatches[dbKey] then
                colorSwatches[dbKey]:UpdateColor()
            end
        end,
        cancelFunc = function() end,
    })
end

function CE:CreateColorSwatch(parent, dbKey, colorLabel)
    local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
    swatch:SetSize(24, 24)
    swatch:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    swatch:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    swatch.dbKey = dbKey
    swatch.UpdateColor = function(self)
        local settings = CE:GetSettings()
        local color = settings[self.dbKey] or {1, 1, 1}
        swatch:SetBackdropColor(color[1], color[2], color[3], 1)
    end

    swatch:SetScript("OnClick", function()
        OpenColorPicker(dbKey)
    end)

    swatch:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(L[colorLabel])
        GameTooltip:Show()
    end)

    swatch:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    swatch:UpdateColor()
    colorSwatches[dbKey] = swatch
    return swatch
end

function CE:UpdateColorSwatches()
    for dbKey, swatch in pairs(colorSwatches) do
        if swatch then swatch:UpdateColor() end
    end
end
