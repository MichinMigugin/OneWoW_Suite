-- ============================================================================
-- OneWoW_Utility_DevTool/GUI/Framework.lua
-- INTERNAL BRIDGE ONLY - Do NOT add UI creation code here.
-- All shared UI functions belong in the OneWoW_GUI Library (OneWoW_GUI-1.0).
-- Call OneWoW_GUI directly for component creation.
-- ============================================================================
local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local GUI = {}
Addon.GUI = GUI
