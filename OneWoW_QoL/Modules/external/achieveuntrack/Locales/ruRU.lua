local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["ACHIEVEUNTRACK_TITLE"] = "Снять отслеживание выполненных достижений",
    ["ACHIEVEUNTRACK_DESC"] = "Автоматически ищет и снимает отслеживание уже выполненных достижений при входе в игру. Освобождает скрытые ячейки отслеживания, которые могут застрять после сбоя или выполнения на другом персонаже.",
})
