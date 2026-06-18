local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — zhCN, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "zhCN", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: 已启用拍卖数据追踪",
    ["DATA_COLLECTED"] = "已收集拍卖数据",
    ["DATA_COLLECTION_FAILED"] = "收集拍卖数据失败",
    ["AUCTION_HOUSE_OPENED"] = "拍卖行已打开，正在收集数据...",
    ["NO_AUCTIONS"] = "没有进行中的拍卖",
    ["NO_BIDS"] = "没有进行中的出价",
    ["AH_SCAN_COOLDOWN"] = "%d 分钟后可进行拍卖行完整扫描。",
    ["AH_SCAN_REQUIRED"] = "拍卖行扫描需要 AltTracker Auctions 插件。",
})
