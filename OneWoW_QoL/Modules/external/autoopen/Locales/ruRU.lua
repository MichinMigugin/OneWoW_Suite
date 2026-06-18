local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted (Phase 4) — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AUTOOPEN_TITLE"] = "Автооткрытие",
    ["AUTOOPEN_DESC"] = "Автоматически открывает сумки, коробки и другие предметы-контейнеры, когда они появляются в вашем инвентаре. Не открывает предметы у банка, почтового ящика или торговца. Предметы, которые вы пока не можете открыть (запертые сундуки, неверный уровень/класс/профессия или пока ячейка занята), автоматически пропускаются.",
    ["AUTOOPEN_OPENING"] = "Автооткрытие: %s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "Добавьте предметы, чтобы Автооткрытие их не открывало.",
    ["AUTOOPEN_BLACKLIST_ADD"] = "Добавить ID предмета:",
    ["AUTOOPEN_BLACKLIST_EMPTY"] = "Нет предметов в чёрном списке",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "Убрано из чёрного списка: %s",
    ["AUTOOPEN_BLACKLIST_ADDED"] = "Добавлено в чёрный список: %s",
    ["AUTOOPEN_BLACKLIST_CLEARED"] = "Чёрный список очищен.",
})
