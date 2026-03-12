-- ============================================================================
-- OneWoW_AltTracker/UI/Framework.lua
-- INTERNAL BRIDGE ONLY - Do NOT add UI creation code here.
-- All shared UI functions belong in the OneWoW_GUI Library (OneWoW_GUI-1.0).
-- This file only maps library calls into the local ns.UI namespace.
-- If you need a new UI function, add it to OneWoW_GUI/OneWoW_GUI.lua first,
-- then add a thin wrapper here.
-- ============================================================================
local addonName, ns = ...

ns.UI = ns.UI or {}

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function ns.UI.CreateButton(name, parent, text, width, height)
    return OneWoW_GUI:CreateButton(name, parent, text, width, height)
end

function ns.UI.CreateEditBox(name, parent, width, height)
    return OneWoW_GUI:CreateEditBox(name, parent, { width = width, height = height })
end

function ns.UI.CreateCheckbox(name, parent, label)
    return OneWoW_GUI:CreateCheckbox(name, parent, label)
end

function ns.UI.CreateSearchBox(parent, options)
    return OneWoW_GUI:CreateEditBox(nil, parent, options)
end

function ns.UI.CreateScrollFrame(name, parent, width, height)
    return OneWoW_GUI:CreateScrollFrame(name, parent, width, height)
end

function ns.UI.CreateSectionHeader(parent, title, yOffset)
    return OneWoW_GUI:CreateSectionHeader(parent, title, yOffset)
end

function ns.UI.ClearFrame(frame)
    return OneWoW_GUI:ClearFrame(frame)
end

function ns.UI.CreateDialog(config)
    return OneWoW_GUI:CreateDialog(config)
end

function ns.UI.CreateConfirmDialog(config)
    return OneWoW_GUI:CreateConfirmDialog(config)
end

function ns.UI.CreateFilterBar(parent, config)
    return OneWoW_GUI:CreateFilterBar(parent, config)
end

function ns.UI.ApplyFont(fs, size)
    local fontPath = OneWoW_GUI:GetFont()
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
    local fontPath = OneWoW_GUI:GetFont()
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
