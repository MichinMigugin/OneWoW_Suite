local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["INSPECTMOG_TITLE"] = "Осмотр экипировки",
    ["INSPECTMOG_DESC"] = "Добавляет в окно осмотра боковую панель со списком надетой экипировки осматриваемого игрока. Сохраните весь список в заметку игрока OneWoW Notes или Shift-щёлкните любой предмет, чтобы добавить его в свои заметки о предметах.",

    ["INSPECTMOG_ADD_NOTE"] = "Добавить в заметку игрока",
    ["INSPECTMOG_ADD_ALL"] = "Добавить всё",
    ["INSPECTMOG_EMPTY"] = "Пока нет экипировки для осмотра.",
    ["INSPECTMOG_PANEL_TITLE"] = "Инструмент осмотра трансмога",
    ["INSPECTMOG_NO_DATA"] = "Данные осмотра недоступны.",
    ["INSPECTMOG_UNKNOWN_PLAYER"] = "Осмотренный игрок",
    ["INSPECTMOG_NATIVE_APPEARANCE"] = "Исходный облик",
    ["INSPECTMOG_SOURCE_FORMAT"] = "Источник #%d",
    ["INSPECTMOG_APPEARANCE_SOURCE_FORMAT"] = "Источник облика: %d",

    ["INSPECTMOG_TT_PREVIEW"] = "Ctrl-щелчок для предпросмотра в примерочной",
    ["INSPECTMOG_TT_NOTES"] = "Shift-щелчок, чтобы добавить в Notes > Предметы",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED"] = "Shift-щелчок, чтобы добавить надетый предмет в Notes > Предметы",
    ["INSPECTMOG_TT_SHIFT_ADD_EQUIPPED_COLL"] = "Shift-щелчок, чтобы добавить облик этого предмета в Notes > Коллекционные предметы",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE"] = "Shift-щелчок, чтобы добавить облик трансмога в Notes > Предметы",
    ["INSPECTMOG_TT_SHIFT_ADD_APPEARANCE_COLL"] = "Shift-щелчок, чтобы добавить облик трансмога в Notes > Коллекционные предметы",
    ["INSPECTMOG_ROUTE_COLLECTIBLES"] = "Добавлять облики в Коллекционные предметы",
    ["INSPECTMOG_TT_PREVIEW_EQUIPPED"] = "Ctrl-щелчок для предпросмотра надетого предмета",
    ["INSPECTMOG_TT_PREVIEW_APPEARANCE"] = "Ctrl-щелчок для предпросмотра облика трансмога",
    ["INSPECTMOG_TT_HIDDEN_APPEARANCE"] = "Скрытые облики не добавляются в заметки о предметах",
    ["INSPECTMOG_TT_ADD_ALL_TITLE"] = "Добавить весь трансмог",
    ["INSPECTMOG_TT_ADD_ALL_DESC"] = "Добавляет все видимые предметы облика трансмога в Notes > Предметы.",

    ["INSPECTMOG_TT_ADD_NOTE_TITLE"] = "Сохранить экипировку в заметку игрока",
    ["INSPECTMOG_TT_ADD_NOTE_DESC"] = "Записывает каждый указанный слот и предмет в заметку этого игрока в OneWoW Notes. Повторное сохранение обновляет блок экипировки и сохраняет остальную часть заметки.",

    ["INSPECTMOG_NOTE_HEADER"] = "[OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_FOOTER"] = "[/OneWoW Inspect Mog]",
    ["INSPECTMOG_NOTE_UPDATED"] = "Осмотрено: %s",
    ["INSPECTMOG_NOTE_LINE"] = "%s - %s",

    ["INSPECTMOG_ITEM_STAMP"] = "TMOG осмотрен %s - %s",

    ["INSPECTMOG_STATUS_NOTE_SAVED"] = "Экипировка сохранена в заметке игрока %s.",
    ["INSPECTMOG_STATUS_NOTE_UPDATED"] = "Экипировка обновлена в заметке игрока %s.",
    ["INSPECTMOG_STATUS_ITEM_ADDED"] = "%s добавлен в заметки о предметах.",
    ["INSPECTMOG_STATUS_NOTES_MISSING"] = "OneWoW Notes не установлен.",
    ["INSPECTMOG_STATUS_NO_DATA"] = "Данные об экипировке пока недоступны.",
})
