local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(M._scope, "itIT", {

    ["CHARINFO_TITLE"] = "Scheda info personaggio",
    ["CHARINFO_DESC"] = "Mostra un pannello informativo ordinato accanto a ogni oggetto equipaggiato sulla scheda del personaggio, indicando livello oggetto (colorato per qualità), stato dell'incantamento, stato dei castoni e percentuale di durabilità.",
    ["CHARINFO_ENCHANTED"] = "Incantato",
    ["CHARINFO_MISSING_ENCHANT"] = "Incantamento mancante",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "Nessun incantamento necessario",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "Tutti i castoni vuoti",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "Alcuni castoni vuoti",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "Tutti i castoni pieni",
    ["CHARINFO_NO_SOCKETS"] = "Nessun castone",
    ["CHARINFO_TOGGLE_DURABILITY"] = "Mostra durabilità",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "Mostra la percentuale di durabilità sui pulsanti degli oggetti",
    ["CHARINFO_TOGGLE_SOCKETS"] = "Mostra icona senza castoni",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "Mostra un'icona quando gli oggetti non hanno castoni",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "Tracciamento slot incantamento",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "Scegli quali slot dell'equipaggiamento tracciare per gli incantamenti. Gli slot disattivati non mostreranno le icone di stato dell'incantamento.",
    ["CHARINFO_SLOT_HEAD"] = "Testa",
    ["CHARINFO_SLOT_NECK"] = "Collo",
    ["CHARINFO_SLOT_SHOULDER"] = "Spalle",
    ["CHARINFO_SLOT_CHEST"] = "Petto",
    ["CHARINFO_SLOT_WAIST"] = "Vita",
    ["CHARINFO_SLOT_LEGS"] = "Gambe",
    ["CHARINFO_SLOT_FEET"] = "Piedi",
    ["CHARINFO_SLOT_WRIST"] = "Polsi",
    ["CHARINFO_SLOT_HANDS"] = "Mani",
    ["CHARINFO_SLOT_RING1"] = "Anello 1",
    ["CHARINFO_SLOT_RING2"] = "Anello 2",
    ["CHARINFO_SLOT_BACK"] = "Schiena",
    ["CHARINFO_SLOT_MAINHAND"] = "Mano principale",
    ["CHARINFO_SLOT_OFFHAND"] = "Mano secondaria",
    ["FEATURES_ON"] = "Attivo",
    ["FEATURES_OFF"] = "Disattivo",
})
