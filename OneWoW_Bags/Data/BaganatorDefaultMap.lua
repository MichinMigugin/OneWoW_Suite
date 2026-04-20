local _, OneWoW_Bags = ...

-- Maps Baganator `default_*` source IDs to the matching OneWoW built-in
-- category name. Values MUST match the built-in names declared in
-- Data\Categories.lua (CATEGORY_DEFINITIONS) and Core\SectionDefaults.lua
-- (EQUIPMENT_CATEGORIES / CRAFTING_CATEGORIES / HOUSING_CATEGORIES) exactly.
--
-- Unmapped default_* entries fall through to the "Keep / Ignore" flow in the
-- ImportPreview dialog. Keeping one creates an empty placeholder custom
-- category inside a dedicated "Baganator Import" section.
OneWoW_Bags.BaganatorDefaultMap = {
    ["default_auto_recents"]        = "Recent Items",
    ["default_weapon"]              = "Weapons",
    ["default_armor"]               = "Armor",
    ["default_auto_equipment_sets"] = "Equipment Sets",
    ["default_consumable"]          = "Consumables",
    ["default_food"]                = "Food",
    ["default_potion"]              = "Potions",
    ["default_reagent"]             = "Reagents",
    ["default_tradegoods"]          = "Trade Goods",
    ["default_profession"]          = "Tradeskill",
    ["default_recipe"]              = "Recipes",
    ["default_gem"]                 = "Gems",
    ["default_questitem"]           = "Quest Items",
    ["default_toy"]                 = "Toys",
    ["default_battlepet"]           = "Battle Pets",
    ["default_miscellaneous"]       = "Miscellaneous",
    ["default_key"]                 = "Keys",
    ["default_keystone"]            = "Keystone",
    ["default_junk"]                = "Junk",
    ["default_other"]               = "Other",
    ["default_housing"]             = "Housing",
    ["default_container"]           = "Containers",
    ["default_itemenhancement"]     = "Item Enhancement",
    ["default_hearthstone"]         = "Hearthstone",
    ["default_special_empty"]       = "Empty",
}

-- Stable display-name hints (English) used when the planner needs to show an
-- unmapped default in the preview's Keep/Ignore panel. Baganator's localized
-- names are used first when available; this is a fallback for when the
-- addon isn't loaded (paste-string import).
OneWoW_Bags.BaganatorDefaultDisplayHints = {
    ["default_mount"]           = "Mounts",
    ["default_glyph"]           = "Glyphs",
    ["default_auto_junk"]       = "Auto Junk",
    ["default_auto_new_items"]  = "Auto New Items",
    ["default_auto_upgrade"]    = "Auto Upgrades",
}
