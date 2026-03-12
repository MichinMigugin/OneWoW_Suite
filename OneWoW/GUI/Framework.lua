-- ============================================================================
-- OneWoW/GUI/Framework.lua
-- INTERNAL BRIDGE ONLY - Do NOT add UI creation code here.
-- All shared UI functions belong in the OneWoW_GUI Library (OneWoW_GUI-1.0).
-- This file only maps library calls into the local GUI namespace.
-- If you need a new UI function, add it to OneWoW_GUI/OneWoW_GUI.lua first,
-- then add a thin wrapper here.
-- ============================================================================
local ADDON_NAME, OneWoW = ...

OneWoW.GUI = OneWoW.GUI or {}
local GUI = OneWoW.GUI

local lib = LibStub("OneWoW_GUI-1.0", true)

function GUI:CreateFrame(name, parent, width, height, useModernBackdrop)
    if not lib then return end
    local backdrop = nil
    if useModernBackdrop == true then
        backdrop = lib.Constants.BACKDROP_SOFT
    elseif type(useModernBackdrop) == "table" then
        backdrop = useModernBackdrop
    end
    return lib:CreateFrame(name, parent, width, height, backdrop)
end

function GUI:CreateButton(name, parent, text, width, height)
    if lib then return lib:CreateButton(name, parent, text, width, height) end
end

function GUI:CreateEditBox(name, parent, width, height)
    if lib then return lib:CreateEditBox(name, parent, { width = width, height = height }) end
end

function GUI:CreateCheckbox(name, parent, label)
    if lib then return lib:CreateCheckbox(name, parent, label) end
end

function GUI:CreateHeader(parent, text, yOffset)
    if lib then return lib:CreateHeader(parent, text, yOffset) end
end

function GUI:CreateDivider(parent, yOffset)
    if lib then return lib:CreateDivider(parent, yOffset) end
end

function GUI:CreateScrollFrame(name, parent, width, height)
    if lib then return lib:CreateScrollFrame(name, parent, width, height) end
end

function GUI:CreateSplitPanel(parent, options)
    if lib then return lib:CreateSplitPanel(parent, options) end
end

function GUI:ClearFrame(frame)
    if lib then return lib:ClearFrame(frame) end
end

function GUI:ApplyFont(fs, size)
    local fontPath = lib and lib.GetFont and lib:GetFont()
    if not fontPath or not fs then return end
    if not size and fs.GetFont then
        local _, currentSize = fs:GetFont()
        size = currentSize or 13
    end
    fs:SetFont(fontPath, size)
end

function GUI:ApplyFontToFrame(frame)
    if not frame then return end
    local fontPath = lib and lib.GetFont and lib:GetFont()
    if not fontPath then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont then
            local _, sz = region:GetFont()
            if sz then region:SetFont(fontPath, sz) end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" and child.GetFont then
            local _, sz, flags = child:GetFont()
            if sz then child:SetFont(fontPath, sz, flags or "") end
        end
        GUI:ApplyFontToFrame(child)
    end
end

function GUI.GetThemeColor(key)
    if lib then return lib:GetThemeColor(key) end
    return 0.5, 0.5, 0.5, 1.0
end

function GUI.GetSpacing(key)
    if lib then return lib:GetSpacing(key) end
    return 8
end
