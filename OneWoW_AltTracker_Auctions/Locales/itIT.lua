local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — itIT (no official IT client), pending native review.
OneWoW.Locale:Register(ADDON_NAME, "itIT", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: tracciamento dei dati delle aste attivato",
    ["DATA_COLLECTED"] = "Dati delle aste raccolti",
    ["DATA_COLLECTION_FAILED"] = "Impossibile raccogliere i dati delle aste",
    ["AUCTION_HOUSE_OPENED"] = "Casa d'aste aperta, raccolta dei dati in corso...",
    ["NO_AUCTIONS"] = "Nessuna asta attiva",
    ["NO_BIDS"] = "Nessuna offerta attiva",
    ["AH_SCAN_COOLDOWN"] = "Scansione completa della casa d'aste disponibile tra %d minuti.",
    ["AH_SCAN_REQUIRED"] = "Addon AltTracker Auctions richiesto per la scansione della casa d'aste.",
})
