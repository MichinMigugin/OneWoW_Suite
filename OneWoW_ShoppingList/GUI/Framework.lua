local ADDON_NAME, ns = ...

ns.GUI = ns.GUI or {}
local GUI = ns.GUI

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function GUI:CreateFrame(name, parent, width, height, useModernBackdrop)
    local backdrop = nil
    if useModernBackdrop == true then
        backdrop = OneWoW_GUI.Constants.BACKDROP_SOFT
    elseif type(useModernBackdrop) == "table" then
        backdrop = useModernBackdrop
    end
    return OneWoW_GUI:CreateFrame(name, parent, width, height, backdrop)
end

function GUI:CreateEditBox(name, parent, width, height)
    return OneWoW_GUI:CreateEditBox(name, parent, { width = width, height = height })
end

function GUI:CreateButton(name, parent, text, width, height)
    return OneWoW_GUI:CreateButton(name, parent, text, width, height)
end

-- LESSON 9 compliant scroll area
-- Returns: container, scrollFrame, scrollContent, UpdateThumb
function GUI:CreateScrollArea(parent, name, offsetL, offsetR, offsetT, offsetB)
    offsetL = offsetL or 0
    offsetR = offsetR or 0
    offsetT = offsetT or 0
    offsetB = offsetB or 0

    local container = CreateFrame("Frame", name and (name .. "Container") or nil, parent)
    container:SetPoint("TOPLEFT",     parent, "TOPLEFT",     offsetL, offsetT)
    container:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", offsetR, offsetB)

    local scrollFrame = CreateFrame("ScrollFrame", name and (name .. "ScrollFrame") or nil, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     container, "TOPLEFT",     0,   0)
    scrollFrame:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -14, 0)

    local scrollBar = scrollFrame.ScrollBar
    if scrollBar then
        scrollBar:ClearAllPoints()
        scrollBar:SetPoint("TOPRIGHT",    container, "TOPRIGHT",    -2, 0)
        scrollBar:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -2, 0)
        scrollBar:SetWidth(10)
        if scrollBar.ScrollUpButton then
            scrollBar.ScrollUpButton:Hide()
            scrollBar.ScrollUpButton:SetAlpha(0)
            scrollBar.ScrollUpButton:EnableMouse(false)
        end
        if scrollBar.ScrollDownButton then
            scrollBar.ScrollDownButton:Hide()
            scrollBar.ScrollDownButton:SetAlpha(0)
            scrollBar.ScrollDownButton:EnableMouse(false)
        end
        if scrollBar.Background then
            scrollBar.Background:SetColorTexture(OneWoW_GUI:GetThemeColor("BG_TERTIARY"))
        end
        if scrollBar.ThumbTexture then
            scrollBar.ThumbTexture:SetWidth(8)
            scrollBar.ThumbTexture:SetColorTexture(OneWoW_GUI:GetThemeColor("ACCENT_PRIMARY"))
        end
    end

    local scrollContent = CreateFrame("Frame", name and (name .. "Content") or nil, scrollFrame)
    scrollContent:SetHeight(1)
    scrollFrame:SetScrollChild(scrollContent)

    scrollFrame:HookScript("OnSizeChanged", function(self, w)
        scrollContent:SetWidth(w)
    end)

    container.scrollFrame   = scrollFrame
    container.scrollContent = scrollContent
    container.UpdateThumb   = function() end

    return container
end
