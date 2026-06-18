local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(ADDON_NAME, "zhTW", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: 已啟用拍賣資料追蹤",
    ["DATA_COLLECTED"] = "已收集拍賣資料",
    ["DATA_COLLECTION_FAILED"] = "收集拍賣資料失敗",
    ["AUCTION_HOUSE_OPENED"] = "拍賣場已開啟，正在收集資料...",
    ["NO_AUCTIONS"] = "沒有進行中的拍賣",
    ["NO_BIDS"] = "沒有進行中的出價",
    ["AH_SCAN_COOLDOWN"] = "%d 分鐘後可進行拍賣場完整掃描。",
    ["AH_SCAN_REQUIRED"] = "拍賣場掃描需要 AltTracker Auctions 插件。",
})
