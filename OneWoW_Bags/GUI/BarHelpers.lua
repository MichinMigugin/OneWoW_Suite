local _, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local pairs = pairs
local string_format = string.format

OneWoW_Bags.BarHelpers = {}
local BH = OneWoW_Bags.BarHelpers

---@return Frame
function BH:CreateBarFrame(parent, frameName, barHeight)
    local frame = CreateFrame("Frame", frameName, parent, "BackdropTemplate")
    frame:SetHeight(barHeight)
    frame:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    frame:SetBackdrop(OneWoW_GUI.Constants.BACKDROP_INNER_NO_INSETS)
    frame:SetBackdropColor(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
    frame:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_SUBTLE"))
    return frame
end

function BH:CreateGoldDisplay(bar, anchorTo)
    local goldText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    goldText:SetPoint("RIGHT", anchorTo, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
    bar.goldText = goldText

    local freeSlots = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    freeSlots:SetPoint("RIGHT", goldText, "LEFT", -OneWoW_GUI:GetSpacing("SM"), 0)
    freeSlots:SetTextColor(OneWoW_GUI:GetThemeColor("TEXT_SECONDARY"))
    bar.freeSlots = freeSlots
end

function BH:RecycleTabButtons(buttons)
    for _, btn in pairs(buttons) do
        btn:Hide()
        btn:ClearAllPoints()
        btn:SetParent(UIParent)
    end
end

function BH:UpdateTabHighlights(buttons, selectedTab)
    for id, btn in pairs(buttons) do
        if btn._skinBorder then
            if selectedTab ~= nil and selectedTab == id then
                btn._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
            else
                btn._skinBorder:SetBackdropBorderColor(OneWoW_GUI:GetThemeColor("BORDER_DEFAULT"))
            end
        end
    end
end

function BH:UpdateFreeSlots(bar, free, total)
    if not bar or not bar.freeSlots then return end
    bar.freeSlots:SetText(string_format("%d/%d", free, total))
end

function BH:ResetBar(bar)
    if bar then
        bar:Hide()
        bar:SetParent(UIParent)
    end
end
