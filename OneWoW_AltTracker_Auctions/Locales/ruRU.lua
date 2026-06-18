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
})
