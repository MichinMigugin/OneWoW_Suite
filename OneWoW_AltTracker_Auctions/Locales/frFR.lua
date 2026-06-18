local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — frFR, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "frFR", {
    ["ADDON_LOADED"] = "OneWoW AltTracker : suivi des données d'enchères activé",
    ["DATA_COLLECTED"] = "Données d'enchères collectées",
    ["DATA_COLLECTION_FAILED"] = "Échec de la collecte des données d'enchères",
    ["AUCTION_HOUSE_OPENED"] = "Hôtel des ventes ouvert, collecte des données...",
    ["NO_AUCTIONS"] = "Aucune vente active",
    ["NO_BIDS"] = "Aucune enchère active",
    ["AH_SCAN_COOLDOWN"] = "Analyse complète de l'HdV disponible dans %d minutes.",
    ["AH_SCAN_REQUIRED"] = "Addon AltTracker Auctions requis pour l'analyse de l'HdV.",
})
