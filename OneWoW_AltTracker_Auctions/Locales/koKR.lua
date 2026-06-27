local ADDON_NAME = ...

-- Machine-drafted — koKR, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "koKR", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: 경매 데이터 추적 활성화됨",
    ["DATA_COLLECTED"] = "경매 데이터 수집됨",
    ["DATA_COLLECTION_FAILED"] = "경매 데이터 수집 실패",
    ["AUCTION_HOUSE_OPENED"] = "경매장이 열렸습니다. 데이터를 수집하는 중...",
    ["NO_AUCTIONS"] = "활성 경매 없음",
    ["NO_BIDS"] = "활성 입찰 없음",
    ["AH_SCAN_COOLDOWN"] = "전체 경매장 검색을 %d분 후에 사용할 수 있습니다.",
    ["AH_SCAN_REQUIRED"] = "경매장 검색을 위해 AltTracker Auctions 애드온이 필요합니다.",
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
