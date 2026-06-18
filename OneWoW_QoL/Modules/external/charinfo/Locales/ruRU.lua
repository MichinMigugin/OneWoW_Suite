local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["CHARINFO_TITLE"] = "Лист информации о персонаже",
    ["CHARINFO_DESC"] = "Показывает рядом с каждым надетым предметом на листе персонажа аккуратную панель с уровнем предмета (с цветом по качеству), статусом чар, статусом гнёзд и прочностью в процентах.",
    ["CHARINFO_ENCHANTED"] = "Зачаровано",
    ["CHARINFO_MISSING_ENCHANT"] = "Нет чар",
    ["CHARINFO_NO_ENCHANT_NEEDED"] = "Чары не нужны",
    ["CHARINFO_ALL_SOCKETS_EMPTY"] = "Все гнёзда пусты",
    ["CHARINFO_SOME_SOCKETS_EMPTY"] = "Некоторые гнёзда пусты",
    ["CHARINFO_ALL_SOCKETS_FILLED"] = "Все гнёзда заполнены",
    ["CHARINFO_NO_SOCKETS"] = "Нет гнёзд",
    ["CHARINFO_TOGGLE_DURABILITY"] = "Показывать прочность",
    ["CHARINFO_TOGGLE_DURABILITY_DESC"] = "Показывает прочность в процентах на кнопках предметов",
    ["CHARINFO_TOGGLE_SOCKETS"] = "Показывать значок отсутствия гнёзд",
    ["CHARINFO_TOGGLE_SOCKETS_DESC"] = "Показывает значок, когда у предметов нет гнёзд",
    ["CHARINFO_ENCHANT_SLOTS_HEADER"] = "Отслеживание ячеек для чар",
    ["CHARINFO_ENCHANT_SLOTS_DESC"] = "Выберите, какие ячейки экипировки отслеживать на наличие чар. Отключённые ячейки не будут показывать значки статуса чар.",
    ["CHARINFO_SLOT_HEAD"] = "Голова",
    ["CHARINFO_SLOT_NECK"] = "Шея",
    ["CHARINFO_SLOT_SHOULDER"] = "Плечи",
    ["CHARINFO_SLOT_CHEST"] = "Грудь",
    ["CHARINFO_SLOT_WAIST"] = "Пояс",
    ["CHARINFO_SLOT_LEGS"] = "Ноги",
    ["CHARINFO_SLOT_FEET"] = "Ступни",
    ["CHARINFO_SLOT_WRIST"] = "Запястья",
    ["CHARINFO_SLOT_HANDS"] = "Кисти рук",
    ["CHARINFO_SLOT_RING1"] = "Кольцо 1",
    ["CHARINFO_SLOT_RING2"] = "Кольцо 2",
    ["CHARINFO_SLOT_BACK"] = "Спина",
    ["CHARINFO_SLOT_MAINHAND"] = "Правая рука",
    ["CHARINFO_SLOT_OFFHAND"] = "Левая рука",
    ["FEATURES_ON"] = "Вкл",
    ["FEATURES_OFF"] = "Выкл",
})
