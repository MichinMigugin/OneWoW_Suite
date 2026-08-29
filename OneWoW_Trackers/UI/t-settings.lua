local _, ns = ...

local OneWoW_GUI = OneWoW_GUI
local L = ns.L

ns.UI = ns.UI or {}

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(parent, {
        width = parent:GetWidth(),
        height = parent:GetHeight(),
    })
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local yOffset = -10
    local wrapWidth = (scrollContent:GetWidth() or 0) - 30
    if wrapWidth < 200 then wrapWidth = 740 end

    local displayHeader = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = DISPLAY, yOffset = yOffset })
    yOffset = displayHeader.bottomY - 8

    local scaleDesc = OneWoW_GUI:CreateFS(scrollContent, 12)
    scaleDesc:SetPoint("TOPLEFT", 15, yOffset)
    scaleDesc:SetPoint("TOPRIGHT", -15, yOffset)
    scaleDesc:SetJustifyH("LEFT")
    scaleDesc:SetWordWrap(true)
    scaleDesc:SetSpacing(3)
    scaleDesc:SetText(L["SETTINGS_PINNED_SCALE_DESC"])
    scaleDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    scaleDesc:SetWidth(wrapWidth)
    yOffset = yOffset - math.max(scaleDesc:GetStringHeight(), 12) - 10

    local scaleLbl = OneWoW_GUI:CreateFS(scrollContent, 12)
    scaleLbl:SetPoint("TOPLEFT", 15, yOffset)
    scaleLbl:SetText(L["SETTINGS_PINNED_SCALE"])
    scaleLbl:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_PRIMARY"))
    yOffset = yOffset - 18

    local TP = ns.TrackerPinned
    local slider = OneWoW_GUI:CreateSlider(scrollContent, {
        width = math.max(140, wrapWidth - 40),
        minVal = TP.SCALE_MIN,
        maxVal = TP.SCALE_MAX,
        step = TP.SCALE_STEP,
        currentVal = TP:ClampScalePercent(ns.db.global.pinnedScale),
        onChange = function(val)
            ns.db.global.pinnedScale = TP:ClampScalePercent(val)
            TP:ApplyAllScales()
        end,
        fmt = "%d%%",
    })
    slider:SetPoint("TOPLEFT", 15, yOffset)
    yOffset = yOffset - 48

    local TD = ns.TrackerData
    local resetTitle, resetDescText = TD:GetWeeklyResetUIText()

    local resetHeader = OneWoW_GUI:CreateSectionHeader(scrollContent, { title = resetTitle, yOffset = yOffset })
    yOffset = resetHeader.bottomY - 8

    local resetDesc = OneWoW_GUI:CreateFS(scrollContent, 12)
    resetDesc:SetPoint("TOPLEFT", 15, yOffset)
    resetDesc:SetPoint("TOPRIGHT", -15, yOffset)
    resetDesc:SetJustifyH("LEFT")
    resetDesc:SetWordWrap(true)
    resetDesc:SetSpacing(3)
    resetDesc:SetText(resetDescText)
    resetDesc:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    resetDesc:SetWidth(wrapWidth)
    yOffset = yOffset - math.max(resetDesc:GetStringHeight(), 12) - 12

    local dropdown = OneWoW_GUI:CreateDropdown(scrollContent, {
        width = 240,
        height = 28,
        text = TD:GetWeeklyResetRegionLabel(),
    })
    dropdown:SetPoint("TOPLEFT", 15, yOffset)

    OneWoW_GUI:AttachFilterMenu(dropdown, {
        searchable = false,
        buildItems = function()
            local items = {}
            for _, opt in ipairs(TD:GetWeeklyResetRegionOptions()) do
                items[#items + 1] = { text = opt.label, value = opt.value }
            end
            return items
        end,
        onSelect = function(value, text)
            TD:SetWeeklyResetRegion(value)
            dropdown._text:SetText(text)
        end,
        getActiveValue = function() return TD:GetWeeklyResetRegion() end,
    })

    yOffset = yOffset - 50
    scrollContent:SetHeight(math.abs(yOffset) + 20)
end
