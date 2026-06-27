local ADDON_NAME = ...

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "ruRU", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: отслеживание данных аукционов включено",
    ["DATA_COLLECTED"] = "Данные аукционов собраны",
    ["DATA_COLLECTION_FAILED"] = "Не удалось собрать данные аукционов",
    ["AUCTION_HOUSE_OPENED"] = "Аукцион открыт, сбор данных...",
    ["NO_AUCTIONS"] = "Нет активных лотов",
    ["NO_BIDS"] = "Нет активных ставок",
    ["AH_SCAN_COOLDOWN"] = "Полное сканирование аукциона будет доступно через %d мин.",
    ["AH_SCAN_REQUIRED"] = "Для сканирования аукциона требуется аддон AltTracker Auctions.",
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
