local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — koKR, pending native review.
OneWoW.Locale:Register(ADDON_NAME, "koKR", {
    ["ADDON_LOADED"] = "OneWoW AltTracker: 경매 데이터 추적 활성화됨",
    ["DATA_COLLECTED"] = "경매 데이터 수집됨",
    ["DATA_COLLECTION_FAILED"] = "경매 데이터 수집 실패",
    ["AUCTION_HOUSE_OPENED"] = "경매장이 열렸습니다. 데이터를 수집하는 중...",
    ["NO_AUCTIONS"] = "활성 경매 없음",
    ["NO_BIDS"] = "활성 입찰 없음",
    ["AH_SCAN_COOLDOWN"] = "전체 경매장 검색을 %d분 후에 사용할 수 있습니다.",
    ["AH_SCAN_REQUIRED"] = "경매장 검색을 위해 AltTracker Auctions 애드온이 필요합니다.",
})
