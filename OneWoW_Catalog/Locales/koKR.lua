-- OneWoW Addon File
-- OneWoW_Catalog/Locales/koKR.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
ns.Locales = ns.Locales or {}
ns.Locales["koKR"] = {}
for k, _ in pairs(ns.Locales["enUS"]) do
    ns.Locales["koKR"][k] = "TEST"
end
