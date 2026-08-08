local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — ruRU, pending native review.
OneWoW.Locale:Register(M._scope, "ruRU", {

    ["AUTOMOUNT_TITLE"] = "Авто-средство передвижения",
    ["AUTOMOUNT_DESC"] = "Автоматически призывает самое быстрое доступное средство передвижения, когда вы перестаёте двигаться в зоне, где это разрешено. Призывает снова после сбора.",
    ["AUTOMOUNT_MOUNT_PREFS"] = "Настройки средства передвижения",
    ["AUTOMOUNT_GROUND_LABEL"] = "Наземное средство",
    ["AUTOMOUNT_FLYING_LABEL"] = "Летающее средство",
    ["AUTOMOUNT_AQUATIC_LABEL"] = "Водное средство",
    ["AUTOMOUNT_CAT_ON"] = "Вкл",
    ["AUTOMOUNT_CAT_OFF"] = "Выкл",
    ["AUTOMOUNT_RANDOM_FAVORITE"] = "Случайное из избранного",
    ["AUTOMOUNT_SELECT_TITLE"] = "Выбрать средство (%s)",
    ["AUTOMOUNT_SELECT_TOOLTIP"] = "Щёлкните, чтобы выбрать средство передвижения",
    ["AUTOMOUNT_SELECT_TOOLTIP_DESC"] = "Выберите конкретное средство или позвольте автовыбору взять самое быстрое доступное.",
    ["AUTOMOUNT_DRUID_SECTION"] = "Друид",
    ["AUTOMOUNT_DRUID_MODE_LABEL"] = "Режим друида",
    ["AUTOMOUNT_DRUID_MODE_DESC"] = "Когда включено, автопризыв пропускается, чтобы вы могли вручную принять облик странника после сбора.",
    ["AUTOMOUNT_STATUS_LABEL"] = "Статус средства передвижения",
    ["AUTOMOUNT_STATUS_READY"] = "Готов к призыву",
    ["AUTOMOUNT_STATUS_MOUNTED"] = "Сейчас верхом",
    ["AUTOMOUNT_STATUS_DISABLED"] = "Авто-средство передвижения отключено",
    ["AUTOMOUNT_TIMING_SECTION"] = "Тайминг",
    ["AUTOMOUNT_DISMOUNT_DELAY"] = "Задержка после спешивания",
    ["AUTOMOUNT_DISMOUNT_DELAY_DESC"] = "Через сколько после спешивания возобновляется автопризыв.",
    ["AUTOMOUNT_FISHING_DELAY"] = "Задержка рыбной ловли",
    ["AUTOMOUNT_FISHING_DELAY_DESC"] = "Через сколько после рыбалки возобновляется автопризыв.",
    ["AUTOMOUNT_GATHER_DELAY"] = "Задержка повторного призыва после сбора",
    ["AUTOMOUNT_GATHER_DELAY_DESC"] = "Как быстро снова призывать средство после сбора.",
    ["AUTOMOUNT_DRUID_CANCEL_LABEL"] = "Автоотмена облика странника",
    ["AUTOMOUNT_DRUID_CANCEL_DESC"] = "Автоматически отменяет облик странника при входе в зону, где разрешён полёт, позволяя вместо этого призвать летающее средство.",
})
