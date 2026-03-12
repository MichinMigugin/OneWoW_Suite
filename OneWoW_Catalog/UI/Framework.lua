-- ============================================================================
-- OneWoW_Catalog/UI/Framework.lua
-- INTERNAL BRIDGE ONLY - Do NOT add UI creation code here.
-- All shared UI functions belong in the OneWoW_GUI Library (OneWoW_GUI-1.0).
-- This file only maps library calls into the local ns.UI namespace.
-- If you need a new UI function, add it to OneWoW_GUI/OneWoW_GUI.lua first,
-- then add a thin wrapper here.
-- ============================================================================
local addonName, ns = ...

ns.UI = ns.UI or {}

local lib = LibStub("OneWoW_GUI-1.0", true)

function ns.UI.CreateButton(name, parent, text, width, height)
    if lib then return lib:CreateButton(name, parent, text, width, height) end
end

function ns.UI.CreateFitTextButton(parent, text, options)
    if lib then return lib:CreateFitTextButton(parent, text, options) end
end

function ns.UI.CreateScrollFrame(name, parent, width, height)
    if lib then return lib:CreateScrollFrame(name, parent, width, height) end
end

function ns.UI.CreateSectionHeader(parent, title, yOffset)
    if lib then return lib:CreateSectionHeader(parent, title, yOffset) end
end

function ns.UI.CreateSplitPanel(parent, options)
    if lib then return lib:CreateSplitPanel(parent, options) end
end

function ns.UI.CreateTitleBar(parent, title, options)
    if lib then return lib:CreateTitleBar(parent, title, options) end
end

function ns.UI.CreateFilterBar(parent, options)
    if lib then return lib:CreateFilterBar(parent, options) end
end

function ns.UI.CreateEditBox(name, parent, options)
    if lib then return lib:CreateEditBox(name, parent, options) end
end

function ns.UI.CreateDropdown(parent, options)
    if lib then return lib:CreateDropdown(parent, options) end
end

function ns.UI.AttachFilterMenu(dropdown, text, options)
    if lib then return lib:AttachFilterMenu(dropdown, text, options) end
end

function ns.UI.CreateCheckbox(name, parent, label)
    if lib then return lib:CreateCheckbox(name, parent, label) end
end

function ns.UI.ClearFrame(frame)
    if lib then return lib:ClearFrame(frame) end
end

function ns.UI.CreateItemIcon(parent, options)
    if lib then return lib:CreateItemIcon(parent, options) end
end

function ns.UI.CreateDivider(parent, yOffset)
    if lib then return lib:CreateDivider(parent, yOffset) end
end

function ns.UI.ApplyFont(fs, size)
    local fontPath = lib and lib.GetFont and lib:GetFont()
    if not fontPath or not fs then return end
    if not size and fs.GetFont then
        local _, currentSize = fs:GetFont()
        size = currentSize or 13
    end
    if size and size > 0 then
        fs:SetFont(fontPath, size)
    end
end

function ns.UI.ApplyFontToFrame(frame)
    if not frame then return end
    local fontPath = lib and lib.GetFont and lib:GetFont()
    if not fontPath then return end
    for _, region in ipairs({frame:GetRegions()}) do
        if region.GetFont and region.SetFont then
            local _, sz = region:GetFont()
            if sz and sz > 0 then region:SetFont(fontPath, sz) end
        end
    end
    for _, child in ipairs({frame:GetChildren()}) do
        if child:GetObjectType() == "EditBox" and child.GetFont then
            local _, sz, flags = child:GetFont()
            if sz and sz > 0 then child:SetFont(fontPath, sz, flags or "") end
        end
        ns.UI.ApplyFontToFrame(child)
    end
end
