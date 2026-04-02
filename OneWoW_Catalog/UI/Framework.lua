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

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

function ns.UI.CreateSplitPanel(parent, options)
    return OneWoW_GUI:CreateSplitPanel(parent, options)
end

function ns.UI.CreateFilterBar(parent, options)
    return OneWoW_GUI:CreateFilterBar(parent, options)
end

function ns.UI.CreateDropdown(parent, options)
    return OneWoW_GUI:CreateDropdown(parent, options)
end

function ns.UI.ClearFrame(frame)
    return OneWoW_GUI:ClearFrame(frame)
end

function ns.UI.CreateItemIcon(parent, options)
    return OneWoW_GUI:CreateItemIcon(parent, options)
end
