local _, ns = ...

local OneWoW_GUI = OneWoW_GUI

function ns.UI.CreateSettingsTab(parent)
    local scrollFrame, scrollContent = OneWoW_GUI:CreateScrollFrame(parent, { width = parent:GetWidth(), height = parent:GetHeight() })
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

    local yOffset = -10

    -- Weekly reset region picker. Hosted here, but owned by OneWoW_Trackers,
    -- which exposes the data + strings through its public API. Only shown when
    -- Trackers is loaded (it is the sole consumer of the setting).
    if OneWoW_Trackers_API and OneWoW_Trackers_API.GetWeeklyResetRegionOptions then
        local resetTitle, resetDescText = OneWoW_Trackers_API.GetWeeklyResetUIText()

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

        local wrapWidth = (scrollContent:GetWidth() or 0) - 30
        if wrapWidth < 200 then wrapWidth = 740 end
        resetDesc:SetWidth(wrapWidth)
        local resetDescHeight = math.max(resetDesc:GetStringHeight() or 12, 12)
        yOffset = yOffset - resetDescHeight - 12

        local dropdown = OneWoW_GUI:CreateDropdown(scrollContent, {
            width = 240,
            height = 28,
            text = OneWoW_Trackers_API.GetWeeklyResetRegionLabel(),
        })
        dropdown:SetPoint("TOPLEFT", 15, yOffset)

        OneWoW_GUI:AttachFilterMenu(dropdown, {
            searchable = false,
            buildItems = function()
                local items = {}
                for _, opt in ipairs(OneWoW_Trackers_API.GetWeeklyResetRegionOptions()) do
                    items[#items + 1] = { text = opt.label, value = opt.value }
                end
                return items
            end,
            onSelect = function(value, text)
                OneWoW_Trackers_API.SetWeeklyResetRegion(value)
                dropdown._text:SetText(text)
            end,
            getActiveValue = function() return OneWoW_Trackers_API.GetWeeklyResetRegion() end,
        })

        yOffset = yOffset - 30
    end

    yOffset = yOffset - 20
    scrollContent:SetHeight(math.abs(yOffset) + 20)
end
