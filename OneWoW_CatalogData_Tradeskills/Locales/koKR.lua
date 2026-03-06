-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Locales/koKR.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.Locales = ns.Locales or {}
ns.Locales["koKR"] = {}

if ns.Locales["enUS"] then
    for k, _ in pairs(ns.Locales["enUS"]) do
        ns.Locales["koKR"][k] = "TEST"
    end
end
