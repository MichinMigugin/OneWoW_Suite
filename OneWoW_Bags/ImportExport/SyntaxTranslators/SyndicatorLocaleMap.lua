local _, OneWoW_Bags = ...

OneWoW_Bags.ImportExport = OneWoW_Bags.ImportExport or {}
OneWoW_Bags.ImportExport.SyntaxTranslators = OneWoW_Bags.ImportExport.SyntaxTranslators or {}
local ST = OneWoW_Bags.ImportExport.SyntaxTranslators

-- Reverse lookup: localized keyword (lowercased) -> English canonical form.
-- Used when (1) the Syndicator addon is not loaded (paste-string import of a
-- foreign-locale export) and (2) the keyword is not already in English.
--
-- This table covers the stable class/subclass/quality/binding keywords
-- across the official locales. Rare plugin- or expansion-specific keywords
-- are left out; the translator falls through to a warn-and-preserve path
-- for them.
--
-- Source of truth: Syndicator's Locales\*.lua keyword tables. If a row is
-- missing a locale, the translator will warn rather than silently guess.

ST.SyndicatorLocaleMap = {
    -- ---------- Quality ----------
    ["poor"]        = "poor",
    ["schlecht"]    = "poor",      -- deDE
    ["pobre"]       = "poor",      -- esES
    ["médiocre"]    = "poor",      -- frFR
    ["плохое"]      = "poor",      -- ruRU
    ["조악"]        = "poor",      -- koKR

    ["common"]      = "common",
    ["gewöhnlich"]  = "common",
    ["común"]       = "common",
    ["courant"]     = "common",
    ["обычное"]     = "common",
    ["일반"]        = "common",

    ["uncommon"]    = "uncommon",
    ["ungewöhnlich"] = "uncommon",
    ["poco común"]  = "uncommon",
    ["inhabituel"]  = "uncommon",
    ["необычное"]   = "uncommon",
    ["고급"]        = "uncommon",

    ["rare"]        = "rare",
    ["selten"]      = "rare",
    ["raro"]        = "rare",
    ["редкое"]      = "rare",
    ["희귀"]        = "rare",

    ["epic"]        = "epic",
    ["episch"]      = "epic",
    ["épique"]      = "epic",
    ["эпическое"]   = "epic",
    ["영웅"]        = "epic",

    ["legendary"]   = "legendary",
    ["legendär"]    = "legendary",
    ["legendario"]  = "legendary",
    ["légendaire"]  = "legendary",
    ["легендарное"] = "legendary",
    ["전설"]        = "legendary",

    ["artifact"]    = "artifact",
    ["artefakt"]    = "artifact",
    ["artefacto"]   = "artifact",
    ["artefact"]    = "artifact",
    ["артефакт"]    = "artifact",
    ["유물"]        = "artifact",

    ["heirloom"]    = "heirloom",
    ["erbstück"]    = "heirloom",
    ["reliquia"]    = "heirloom",
    ["héritage"]    = "heirloom",
    ["реликвия"]    = "heirloom",
    ["계승품"]      = "heirloom",

    -- ---------- Item classes ----------
    ["weapon"]      = "weapon",
    ["waffe"]       = "weapon",
    ["arma"]        = "weapon",
    ["arme"]        = "weapon",
    ["оружие"]      = "weapon",
    ["무기"]        = "weapon",

    ["armor"]       = "armor",
    ["rüstung"]     = "armor",
    ["armadura"]    = "armor",
    ["armure"]      = "armor",
    ["доспехи"]     = "armor",
    ["방어구"]      = "armor",

    ["consumable"]  = "consumable",
    ["verbrauchbar"] = "consumable",
    ["consumible"]  = "consumable",
    ["consommable"] = "consumable",
    ["расходуемое"] = "consumable",
    ["소비용품"]    = "consumable",

    ["container"]   = "container",
    ["behälter"]    = "container",
    ["contenedor"]  = "container",
    ["conteneur"]   = "container",
    ["контейнер"]   = "container",
    ["가방"]        = "container",

    ["reagent"]     = "reagent",
    ["reagenz"]     = "reagent",
    ["reactivo"]    = "reagent",
    ["реагент"]     = "reagent",
    ["재료"]        = "reagent",

    ["tradegoods"]  = "tradegoods",
    ["handelswaren"] = "tradegoods",
    ["manufactura"] = "tradegoods",
    ["artisanat"]   = "tradegoods",
    ["хозтовары"]   = "tradegoods",
    ["직업용품"]    = "tradegoods",

    ["recipe"]      = "recipe",
    ["rezept"]      = "recipe",
    ["receta"]      = "recipe",
    ["recette"]     = "recipe",
    ["рецепт"]      = "recipe",
    ["제조법"]      = "recipe",

    ["gem"]         = "gem",
    ["edelstein"]   = "gem",
    ["gema"]        = "gem",
    ["gemme"]       = "gem",
    ["самоцвет"]    = "gem",
    ["보석"]        = "gem",

    ["quest"]       = "quest",
    ["questitem"]   = "quest",
    ["questgegenstand"] = "quest",
    ["objeto de misión"] = "quest",
    ["objet de quête"] = "quest",
    ["задание"]     = "quest",
    ["퀘스트"]      = "quest",

    ["key"]         = "key",
    ["schlüssel"]   = "key",
    ["llave"]       = "key",
    ["clé"]         = "key",
    ["ключ"]        = "key",
    ["열쇠"]        = "key",

    ["miscellaneous"] = "miscellaneous",
    ["verschiedenes"] = "miscellaneous",
    ["misceláneo"]  = "miscellaneous",
    ["divers"]      = "miscellaneous",
    ["разное"]      = "miscellaneous",
    ["기타"]        = "miscellaneous",

    ["glyph"]       = "glyph",
    ["glyphe"]      = "glyph",
    ["glifo"]       = "glyph",
    ["символ"]      = "glyph",
    ["문양"]        = "glyph",

    ["tradeskill"]  = "tradeskill",
    ["profession"]  = "tradeskill",
    ["beruf"]       = "tradeskill",
    ["profesión"]   = "tradeskill",
    ["métier"]      = "tradeskill",
    ["профессия"]   = "tradeskill",
    ["전문기술"]    = "tradeskill",

    ["housing"]     = "housing",
    ["wohnen"]      = "housing",
    ["habitat"]     = "housing",
    ["жилище"]      = "housing",
    ["주거"]        = "housing",

    ["itemenhancement"] = "itemenhancement",
    ["enhancement"] = "itemenhancement",

    -- ---------- Binding ----------
    ["soulbound"]   = "soulbound",
    ["bound"]       = "soulbound",
    ["bop"]         = "soulbound",
    ["seelengebunden"] = "soulbound",
    ["ligado"]      = "soulbound",
    ["lié"]         = "soulbound",
    ["привязано"]   = "soulbound",
    ["귀속"]        = "soulbound",

    ["boe"]         = "boe",
    ["bindonequip"] = "boe",
    ["bou"]         = "bou",
    ["bindonuse"]   = "bou",
    ["boa"]         = "boa",
    ["accountbound"] = "boa",
    ["warbound"]    = "boa",
    ["wue"]         = "wue",
    ["warbounduntilequip"] = "wue",

    -- ---------- Special ----------
    ["junk"]        = "junk",
    ["trash"]       = "junk",
    ["müll"]        = "junk",
    ["basura"]      = "junk",
    ["camelote"]    = "junk",
    ["хлам"]        = "junk",
    ["잡동사니"]    = "junk",

    ["toy"]         = "toy",
    ["spielzeug"]   = "toy",
    ["juguete"]     = "toy",
    ["jouet"]       = "toy",
    ["игрушка"]     = "toy",
    ["장난감"]      = "toy",

    ["mount"]       = "mount",
    ["reittier"]    = "mount",
    ["montura"]     = "mount",
    ["monture"]     = "mount",
    ["транспорт"]   = "mount",
    ["탈것"]        = "mount",

    ["pet"]         = "pet",
    ["battlepet"]   = "pet",
    ["haustier"]    = "pet",
    ["mascota"]     = "pet",
    ["mascotte"]    = "pet",
    ["питомец"]     = "pet",
    ["애완동물"]    = "pet",

    ["set"]         = "set",
    ["equipmentset"] = "set",
    ["ausrüstungsset"] = "set",
    ["conjunto"]    = "set",
    ["ensemble"]    = "set",
    ["комплект"]    = "set",
    ["장비세트"]    = "set",
}
