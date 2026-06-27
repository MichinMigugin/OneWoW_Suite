local ADDON_NAME = ...

-- Machine-drafted — frFR, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "frFR", {
    ["ADDON_LOADED"] = "OneWoW AltTracker : suivi des données d'enchères activé",
    ["DATA_COLLECTED"] = "Données d'enchères collectées",
    ["DATA_COLLECTION_FAILED"] = "Échec de la collecte des données d'enchères",
    ["AUCTION_HOUSE_OPENED"] = "Hôtel des ventes ouvert, collecte des données...",
    ["NO_AUCTIONS"] = "Aucune vente active",
    ["NO_BIDS"] = "Aucune enchère active",
    ["AH_SCAN_COOLDOWN"] = "Analyse complète de l'HdV disponible dans %d minutes.",
    ["AH_SCAN_REQUIRED"] = "Addon AltTracker Auctions requis pour l'analyse de l'HdV.",
    ["AH_PANEL_TAB_TOOLTIP"] = "|cff00ccffOneWoW|r\nAuction House price scan",
    ["AH_PANEL_TITLE"] = "OneWoW AH Prices",
    ["AH_PANEL_SCAN"] = "Scan auction house",
    ["AH_PANEL_STOP_SCAN"] = "Stop scan",
    ["AH_PANEL_AUTO_SCAN"] = "Auto-scan on open",
    ["AH_PANEL_AUTO_SCAN_DESC"] = "When enabled, starts a background full scan each time you open the auction house (if cooldown allows).",
    ["AH_PANEL_STATUS_LAST"] = "Last scan: %s ago",
    ["AH_PANEL_STATUS_ENTRIES"] = "Cached entries: %d",
    ["AH_PANEL_STATUS_REALM"] = "Realm ID: %d",
    ["AH_PANEL_STATUS_COOLDOWN"] = "Scan cooldown: %d min",
    ["AH_PANEL_EXTERNAL_SOURCE"] = "AH prices are provided by your selected external source. Switch to OneWoW in the price source dropdown to use suite scans.",
    ["AH_PANEL_SCAN_WAITING"] = "Waiting for auction data…",
    ["AH_PANEL_SCAN_PROCESSING"] = "Processing… %d%%",
    ["AH_PANEL_SCAN_COMPLETE"] = "Scan complete (%d prices)",
    ["AH_PANEL_NEVER_SCANNED"] = "No full scan recorded for this realm yet.",
})
