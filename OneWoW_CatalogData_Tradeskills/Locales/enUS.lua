-- OneWoW Addon File
-- OneWoW_CatalogData_Tradeskills/Locales/enUS.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

ns.Locales = ns.Locales or {}
ns.Locales["enUS"] = {
    ["ADDON_LOADED"] = "OneWoW CatalogData: Tradeskills loaded.",
    ["PROF_ALCHEMY"] = "Alchemy",
    ["PROF_BLACKSMITHING"] = "Blacksmithing",
    ["PROF_COOKING"] = "Cooking",
    ["PROF_ENCHANTING"] = "Enchanting",
    ["PROF_ENGINEERING"] = "Engineering",
    ["PROF_FISHING"] = "Fishing",
    ["PROF_HERBALISM"] = "Herbalism",
    ["PROF_INSCRIPTION"] = "Inscription",
    ["PROF_JEWELCRAFTING"] = "Jewelcrafting",
    ["PROF_LEATHERWORKING"] = "Leatherworking",
    ["PROF_MINING"] = "Mining",
    ["PROF_SKINNING"] = "Skinning",
    ["PROF_TAILORING"] = "Tailoring",
    ["REAGENT_REQUIRED"] = "Required",
    ["REAGENT_OPTIONAL"] = "Optional",
    ["REAGENT_QUALITY"] = "Quality",
    ["SCAN_COMPLETE"] = "Scan complete: %d recipes found.",
    ["RECIPE_KNOWN"] = "Known",
    ["RECIPE_UNKNOWN"] = "Not Known",
    ["EXP_CLASSIC"] = "Classic",
    ["EXP_BURNING_CRUSADE"] = "The Burning Crusade",
    ["EXP_WRATH"] = "Wrath of the Lich King",
    ["EXP_CATACLYSM"] = "Cataclysm",
    ["EXP_MISTS"] = "Mists of Pandaria",
    ["EXP_WARLORDS"] = "Warlords of Draenor",
    ["EXP_LEGION"] = "Legion",
    ["EXP_BFA"] = "Battle for Azeroth",
    ["EXP_SHADOWLANDS"] = "Shadowlands",
    ["EXP_DRAGONFLIGHT"] = "Dragonflight",
    ["EXP_TWW"] = "The War Within",
    ["EXP_MIDNIGHT"] = "Midnight",
    ["TYPE_CRAFTING"] = "Crafting",
    ["TYPE_GATHERING"] = "Gathering",
    ["TYPE_SECONDARY"] = "Secondary",
}

ns.L = {}
for k, v in pairs(ns.Locales["enUS"]) do
    ns.L[k] = v
end
