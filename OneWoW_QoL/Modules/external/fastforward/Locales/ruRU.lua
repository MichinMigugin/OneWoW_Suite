local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["FASTFORWARD_TITLE"] = "Перемотка",
    ["FASTFORWARD_DESC"] = "Автоматически пропускает внутриигровые ролики и кат-сцены. Удерживайте любую клавишу-модификатор, когда ролик или кат-сцена начинается, чтобы посмотреть её.",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "Пропускать ролики",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "Автоматически останавливает внутриигровые ролики, когда они начинают воспроизводиться.",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "Пропускать кат-сцены",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "Автоматически отменяет внутриигровые кат-сцены, когда они начинаются.",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "Только в подземельях",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "Пропускает ролики и кат-сцены только когда вы находитесь в подземелье, рейде или другой инстанции.",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "Учитывать неотменяемые",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "Не пытается пропускать кат-сцены, которые игра помечает как неотменяемые.",
})
