local ADDON_NAME = ...

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(ADDON_NAME, "zhTW", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: 已啟用拍賣資料追蹤",
    ["DATA_COLLECTED"] = "已收集拍賣資料",
    ["DATA_COLLECTION_FAILED"] = "收集拍賣資料失敗",
    ["AUCTION_HOUSE_OPENED"] = "拍賣場已開啟，正在收集資料...",
    ["NO_AUCTIONS"] = "沒有進行中的拍賣",
    ["NO_BIDS"] = "沒有進行中的出價",
    ["AH_SCAN_COOLDOWN"] = "%d 分鐘後可進行拍賣場完整掃描。",
    ["AH_SCAN_REQUIRED"] = "拍賣場掃描需要 AltTracker Auctions 插件。",
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
