local ADDON_NAME = ...

-- Machine-drafted — ptBR, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "ptBR", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: rastreamento de dados de leilões ativado",
    ["DATA_COLLECTED"] = "Dados de leilões coletados",
    ["DATA_COLLECTION_FAILED"] = "Falha ao coletar dados de leilões",
    ["AUCTION_HOUSE_OPENED"] = "Casa de leilões aberta, coletando dados...",
    ["NO_AUCTIONS"] = "Nenhum leilão ativo",
    ["NO_BIDS"] = "Nenhum lance ativo",
    ["AH_SCAN_COOLDOWN"] = "Escaneamento completo da casa de leilões disponível em %d minutos.",
    ["AH_SCAN_REQUIRED"] = "O addon AltTracker Auctions é necessário para escanear a casa de leilões.",
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
