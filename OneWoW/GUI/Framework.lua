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

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function GUI:ApplyFont(fs, size)
    local fontPath = OneWoW_GUI:GetFont()
    if not fontPath or not fs then return end
    if not size and fs.GetFont then
        local _, currentSize = fs:GetFont()
        size = currentSize or 13
    end
    if size and size > 0 then
        OneWoW_GUI:SafeSetFont(fs, fontPath, size)
    end
end

function GUI:ApplyFontToFrame(frame)
    if not frame then return end
    local fontPath = OneWoW_GUI:GetFont()
    if not fontPath then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont then
            local _, sz = region:GetFont()
            if sz and sz > 0 then OneWoW_GUI:SafeSetFont(region, fontPath, sz) end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" and child.GetFont then
            local _, sz, flags = child:GetFont()
            if sz and sz > 0 then OneWoW_GUI:SafeSetFont(child, fontPath, sz, flags or "") end
        end
        GUI:ApplyFontToFrame(child)
    end
end
