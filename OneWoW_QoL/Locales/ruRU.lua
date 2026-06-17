local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — pending native review
OneWoW.Locale:Register(ADDON_NAME, "ruRU", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "загружено.",

    ["TAB_FEATURES"] = "Функции QoL",
    ["TAB_TOGGLES"] = "Переключатели",

    ["FEATURES_LIST_TITLE"] = "Функции",
    ["FEATURES_FAVORITE_TT_TITLE"] = "Избранное",
    ["FEATURES_FAVORITE_TT_DESC"] = "Закрепляет эту функцию в разделе «Избранное» вверху. Нажмите ещё раз, чтобы убрать её из избранного.",
    ["FEATURES_DETAIL_TITLE"] = "Подробности",
    ["FEATURES_EMPTY"] = "Модули не загружены.",
    ["FEATURES_NO_SELECTION"] = "Выберите функцию из списка.",
    ["FEATURES_ENABLED"] = "Включено",
    ["FEATURES_DISABLED"] = "Отключено",
    ["FEATURES_CATEGORY_LABEL"] = "Категория:",
    ["FEATURES_VERSION_LABEL"] = "Версия:",
    ["FEATURES_AUTHOR_LABEL"] = "Автор:",
    ["FEATURES_CONTACT_LABEL"] = "Контакт:",
    ["FEATURES_LINK_LABEL"] = "Ссылка:",
    ["FEATURES_DETAILS_BTN"] = "Подробности",
    ["FEATURES_DETAILS_TITLE"] = "Сведения о модуле",
    ["FEATURES_TOGGLES_HEADER"] = "Переключатели модуля",
    ["FEATURES_ON"] = "Вкл.",
    ["FEATURES_OFF"] = "Выкл.",
    ["FEATURES_PREVIEW_LABEL"] = "Предпросмотр:",

    ["CATEGORY_AUTOMATION"] = "Автоматизация",
    ["CATEGORY_INTERFACE"] = "Интерфейс",
    ["CATEGORY_SOCIAL"] = "Общение",
    ["CATEGORY_COMBAT"] = "Бой",
    ["CATEGORY_ECONOMY"] = "Экономика",
    ["CATEGORY_UTILITY"] = "Утилиты",

    ["TOGGLES_LIST_TITLE"] = "Игровые флаги",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "Избранное",
    ["TOGGLES_FAVORITE_TT_DESC"] = "Закрепляет этот переключатель в разделе «Избранное» вверху. Нажмите ещё раз, чтобы убрать его из избранного.",
    ["TOGGLES_DETAIL_TITLE"] = "Сведения о флаге",
    ["TOGGLES_COMING_SOON"] = "Игровые флаги-переключатели будут добавлены в одном из будущих обновлений.",
    ["TOGGLES_NO_SELECTION"] = "Выберите флаг из списка.",

    ["SETTINGS_THEME_HEADER"] = "Цветовая тема",
    ["SETTINGS_THEME_DESC"] = "Выберите цветовую тему. Изменения применяются мгновенно.",
    ["SETTINGS_LANGUAGE_DESC"] = "Выберите предпочитаемый язык. Изменения применяются мгновенно.",
    ["SETTINGS_DEVELOPER_HEADER"] = "Информация для разработчиков",
    ["SETTINGS_DEVELOPER_DESC"] = "Этот аддон поддерживает внешние модули. Добавляйте функции QoL, создавая папку модуля в Modules\\external\\. Нажмите кнопку «Помощь разработчику» для получения полной документации.",
    ["SETTINGS_DEV_HELP_BTN"] = "Помощь разработчику",

    ["DEVHELP_TITLE"] = "Руководство разработчика модулей",
    ["DEVHELP_BODY"] = [[СИСТЕМА ПОДКЛЮЧАЕМЫХ МОДУЛЕЙ

Создайте свою папку:
  Modules\external\yourmodule\

Файлы (module.lua загружается ПЕРВЫМ):
  module.lua      - Метаданные + регистрация
  yourmodule.lua  - Логика модуля
  Locales\enUS.lua  (koKR.lua по желанию)

В module.lua задайте свой модуль
(id существует ТОЛЬКО здесь):
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "Ваше имя",
    contact     = "your@email.com",
    link        = "https://yoursite.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

В yourmodule.lua получите его + ваше
представление локали (захватывайте при загрузке, не во время выполнения):
  local _, ns = ...
  local M, L = ns.ModuleRegistry:Current()
  if not M then return end

  function M:OnEnable() end
  function M:OnDisable() end
  function M:OnToggle(id, val) end

В Locales\enUS.lua:
  local _, ns = ...
  local M = ns.ModuleRegistry:Current()
  OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_TITLE"] = "My Title",
    ["MY_DESC"]  = "What it does",
  })

scope — это ADDON_NAME .. "." .. id, напр.
OneWoW_QoL.yourmodule (вычисляется, без
жёстко прописанной строки scope).

Ссылайтесь на другой модуль по id:
  ns.ModuleRegistry:GetById("othermodule")
Никогда не используйте ns.<X>Module.

Значения title, description, а также метка
и описание переключателей являются ключами
локали. author, contact и link необязательны.
contact и link отображаются как копируемые
поля в окне «Сведения о модуле».

Доступные категории:
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

Добавьте свои файлы в TOC в раздел EXTERNAL
MODULES. Порядок: module.lua ПЕРВЫМ, затем
Locales, затем ваши файлы кода.

Пространство базы данных SavedVariables:
  OneWoW_QoL_DB.modules.yourmodule

Полный рабочий пример см. в
Modules\external\autodelete\.]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "Нажмите, чтобы открыть",
    ["MINIMAP_RIGHT_CLICK"] = "Правый клик для настроек",
    ["MINIMAP_OPEN"] = "Открыть QoL",

    ["LANG_ENGLISH"] = "Английский",
    ["LANG_KOREAN"] = "Корейский",


    ["SEARCH_HINT"] = "Фильтр...",
    ["TOGGLES_STATUS_ALL"] = "Показано переменных: %d",
    ["TOGGLES_STATUS_FILTERED"] = "Показано %d из %d",
    ["FEATURES_STATUS_ENABLED"] = "Включено %d из %d",

    ["TOGGLES_CVAR_LABEL"] = "CVar:",
    ["TOGGLES_ON"] = "Вкл.",
    ["TOGGLES_OFF"] = "Выкл.",
    ["TOGGLES_VALUE_LABEL"] = "Значение:",

    ["TOGGLE_CAT_GAMEPLAY"] = "Игровой процесс",
    ["TOGGLE_CAT_INTERFACE"] = "Интерфейс",
    ["TOGGLE_CAT_NAMEPLATES"] = "Индикаторы",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "Боевой текст",
    ["TOGGLE_CAT_CAMERA"] = "Камера",
    ["TOGGLE_CAT_CHAT"] = "Чат и общение",
    ["TOGGLE_CAT_AUDIO"] = "Звук",
    ["TOGGLE_CAT_GRAPHICS"] = "Графика",
    ["TOGGLE_CAT_NETWORK"] = "Сеть",

    ["TOGGLE_NAME_autoLootDefault"] = "Автоматический сбор добычи",
    ["TOGGLE_NAME_autoSelfCast"] = "Автоприменение на себя",
    ["TOGGLE_NAME_autoDismount"] = "Автоматически спешиваться",
    ["TOGGLE_NAME_autoDismountFlying"] = "Спешиваться в полёте",
    ["TOGGLE_NAME_autoStand"] = "Автоматически вставать",
    ["TOGGLE_NAME_autoUnshift"] = "Автоматически выходить из облика",
    ["TOGGLE_NAME_assistAttack"] = "Атака при содействии",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "Кнопки действий по нажатию",
    ["TOGGLE_NAME_deselectOnClick"] = "Снимать цель при щелчке",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "Прерывать автоатаку при смене цели",
    ["TOGGLE_NAME_lootUnderMouse"] = "Окно добычи под курсором",
    ["TOGGLE_NAME_lootLeftmostBag"] = "Добыча в крайнюю левую сумку",
    ["TOGGLE_NAME_interactOnLeftClick"] = "Взаимодействие левым кликом",
    ["TOGGLE_NAME_autointeract"] = "Автовзаимодействие",
    ["TOGGLE_NAME_autoClearAFK"] = "Автоматически снимать статус «Отошёл»",

    ["TOGGLE_NAME_countdownForCooldowns"] = "Отсчёт времени восстановления",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "Подсветка срабатывания заклинаний",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "Всегда показывать панели команд",
    ["TOGGLE_NAME_lockActionBars"] = "Закрепить панели команд",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "Нижняя левая панель команд",
    ["TOGGLE_NAME_bottomRightActionBar"] = "Нижняя правая панель команд",
    ["TOGGLE_NAME_rightActionBar"] = "Правая панель команд",
    ["TOGGLE_NAME_rightTwoActionBar"] = "Правая панель команд 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "Показывать свободные ячейки сумок",
    ["TOGGLE_NAME_buffDurations"] = "Показывать длительность усилений",
    ["TOGGLE_NAME_showTargetOfTarget"] = "Показывать цель цели",
    ["TOGGLE_NAME_showTargetCastbar"] = "Показывать полосу заклинания цели",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "Полноразмерная рамка фокуса",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "Форматировать большие числа",
    ["TOGGLE_NAME_alwaysCompareItems"] = "Всегда сравнивать предметы",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "Отсутствующий источник трансмогрификации",
    ["TOGGLE_NAME_autoQuestWatch"] = "Автослежение за заданиями",
    ["TOGGLE_NAME_autoQuestProgress"] = "Всплывающие окна прогресса заданий",
    ["TOGGLE_NAME_mapFade"] = "Карта тускнеет при движении",
    ["TOGGLE_NAME_rotateMinimap"] = "Вращать миникарту",
    ["TOGGLE_NAME_useUiScale"] = "Включить свой масштаб интерфейса",
    ["TOGGLE_NAME_uiScale"] = "Масштаб интерфейса",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "Показывать индикаторы врагов",
    ["TOGGLE_NAME_nameplateShowFriends"] = "Показывать индикаторы союзников",
    ["TOGGLE_NAME_nameplateShowSelf"] = "Показывать личный индикатор",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "Личный индикатор всегда виден",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "Личный индикатор в бою",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "Цвета классов на индикаторах врагов",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "Цвета классов на индикаторах союзников",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "Вспышка при потере угрозы",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "Сквозные клики по индикаторам врагов",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "Сквозные клики по индикаторам союзников",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "Дальность видимости индикаторов",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "Общий масштаб индикаторов",
    ["TOGGLE_NAME_namePlateEnemySize"] = "Размер индикаторов врагов",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "Размер индикаторов союзников",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "Всплывающий боевой текст",
    ["TOGGLE_NAME_enableCombatText"] = "Стандартный боевой текст",
    ["TOGGLE_NAME_fctCombatState"] = "Текст состояния боя",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "Числа урона",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "Числа исцеления",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "Текст входа/выхода из боя",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "Текст смены усилений/ослаблений",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "Текст уклонения/парирования/промаха",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "Получение чести",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "Изменения репутации",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "Получение энергии/маны",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "Получение очков серий приёмов",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "Реактивные срабатывания",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "Урон питомца в ближнем бою",

    ["TOGGLE_NAME_cameraBobbing"] = "Покачивание камеры",
    ["TOGGLE_NAME_cameraWaterCollision"] = "Столкновение камеры с водой",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "Упреждение угла полёта",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "Динамический наклон камеры",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "Максимальная дальность отдаления камеры",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "Скорость горизонтального поворота камеры",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "Скорость вертикального наклона камеры",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "Скорость приближения камеры",

    ["TOGGLE_NAME_chatBubbles"] = "Облачка реплик (/сказать)",
    ["TOGGLE_NAME_chatBubblesParty"] = "Облачка реплик (группа)",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "Цвета классов в чате",
    ["TOGGLE_NAME_blockTrades"] = "Блокировать запросы обмена",
    ["TOGGLE_NAME_blockChannelInvites"] = "Блокировать приглашения в каналы",
    ["TOGGLE_NAME_guildMemberNotify"] = "Оповещения о входе гильдийцев",
    ["TOGGLE_NAME_removeChatDelay"] = "Убрать задержку чата",
    ["TOGGLE_NAME_chatMouseScroll"] = "Прокрутка чата колёсиком мыши",
    ["TOGGLE_NAME_profanityFilter"] = "Фильтр нецензурной лексики",
    ["TOGGLE_NAME_chatStyle"] = "Стиль чата",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "Все звуки",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "Музыка",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "Звуковые эффекты",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "Диалоги / Озвучка",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "Окружение",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "Звуки питомца",
    ["TOGGLE_NAME_FootstepSounds"] = "Звуки шагов",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "Общая громкость",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "Громкость музыки",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "Громкость эффектов",

    ["TOGGLE_NAME_ffxDeath"] = "Эффект экрана при смерти",
    ["TOGGLE_NAME_ffxGlow"] = "Эффект свечения / bloom",
    ["TOGGLE_NAME_ffxNether"] = "Визуальный эффект Круговерти Пустоты",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "Выделять мои эффекты заклинаний",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "Отключить вспышку при низком здоровье",
    ["TOGGLE_NAME_hdPlayerModels"] = "HD-модели персонажей",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "Подсветка персонажа",
    ["TOGGLE_NAME_gxVSync"] = "Вертикальная синхронизация",
    ["TOGGLE_NAME_gxTripleBuffer"] = "Тройная буферизация",
    ["TOGGLE_NAME_particleDensity"] = "Плотность частиц",
    ["TOGGLE_NAME_maxFPS"] = "Макс. FPS (активное окно)",
    ["TOGGLE_NAME_maxFPSBk"] = "Макс. FPS (фоновое окно)",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "Максимальная задержка кадров",
    ["TOGGLE_NAME_RenderScale"] = "Масштаб отрисовки",
    ["TOGGLE_NAME_graphicsQuality"] = "Предустановка качества графики",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "Режим сглаживания",
    ["TOGGLE_NAME_colorblindMode"] = "Режим для дальтоников",

    ["TOGGLE_NAME_disableServerNagle"] = "Отключить алгоритм Нейгла",
    ["TOGGLE_NAME_gxFixLag"] = "Исправить задержку ввода",
    ["TOGGLE_NAME_reducedLagTolerance"] = "Сниженный допуск задержки",
    ["TOGGLE_NAME_SpellQueueWindow"] = "Окно очереди заклинаний",

    ["TOGGLE_DESC_autoLootDefault"] = "Автоматически подбирает всю добычу без щелчка по каждому предмету.",
    ["TOGGLE_DESC_autoSelfCast"] = "Применяет полезные заклинания на вас, когда у вас не выбрана цель.",
    ["TOGGLE_DESC_autoDismount"] = "Автоматически спешивает вас при попытке собрать ресурс, поговорить с НИП или вступить в бой.",
    ["TOGGLE_DESC_autoDismountFlying"] = "Автоматически спешивает вас даже в полёте. Внимание: вы упадёте!",
    ["TOGGLE_DESC_autoStand"] = "Автоматически поднимает вас, когда вы пытаетесь двигаться или действовать сидя.",
    ["TOGGLE_DESC_autoUnshift"] = "Автоматически выводит из облика, когда вы используете способность, требующую этого.",
    ["TOGGLE_DESC_assistAttack"] = "Когда вы содействуете дружественной цели, автоматически начинаете атаковать её цель.",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "Вкл.: заклинания срабатывают сразу при нажатии клавиши. Выкл.: заклинания срабатывают при отпускании, позволяя сначала оценить дальность.",
    ["TOGGLE_DESC_deselectOnClick"] = "Снимает вашу цель при щелчке по пустой земле.",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "Прерывает автоатаку при переключении на новую цель.",
    ["TOGGLE_DESC_lootUnderMouse"] = "Открывает окно добычи там, где находится курсор мыши, а не в фиксированном месте.",
    ["TOGGLE_DESC_lootLeftmostBag"] = "Помещает добычу в крайнюю левую сумку, а не в крайнюю правую.",
    ["TOGGLE_DESC_interactOnLeftClick"] = "Левый щелчок по НИП и объектам для взаимодействия вместо правого.",
    ["TOGGLE_DESC_autointeract"] = "Правый щелчок по НИП автоматически заговаривает с ним или обыскивает его.",
    ["TOGGLE_DESC_autoClearAFK"] = "Автоматически снимает статус «Отошёл», когда вы двигаетесь или совершаете любое действие.",

    ["TOGGLE_DESC_countdownForCooldowns"] = "Показывает числа обратного отсчёта в центре значков способностей во время восстановления.",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "Показывает светящиеся рамки на способностях при срабатывании эффектов, например мгновенных применений.",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "Сохраняет панели команд видимыми даже пустыми, не позволяя им скрываться.",
    ["TOGGLE_DESC_lockActionBars"] = "Не даёт случайно перетащить способности с ваших панелей команд.",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "Показывает дополнительную панель команд над основной с левой стороны.",
    ["TOGGLE_DESC_bottomRightActionBar"] = "Показывает дополнительную панель команд над основной с правой стороны.",
    ["TOGGLE_DESC_rightActionBar"] = "Показывает вертикальную панель команд в правой части экрана.",
    ["TOGGLE_DESC_rightTwoActionBar"] = "Показывает вторую вертикальную панель команд в правой части экрана.",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "Показывает количество свободных ячеек сумок на панели сумок.",
    ["TOGGLE_DESC_buffDurations"] = "Показывает оставшееся время ваших усилений в виде чисел обратного отсчёта.",
    ["TOGGLE_DESC_showTargetOfTarget"] = "Показывает, кого выбрала ваша цель. Полезно для танков и лекарей.",
    ["TOGGLE_DESC_showTargetCastbar"] = "Показывает полосу заклинания для вашей текущей цели, чтобы видеть, что она применяет.",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "Использует полноразмерную рамку для вашего фокуса вместо маленькой.",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "Отображает большие числа с разделителями, например 1 000 000 вместо 1000000.",
    ["TOGGLE_DESC_alwaysCompareItems"] = "Автоматически показывает подсказку сравнения при наведении на снаряжение. Клавиша Shift не нужна.",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "Показывает в подсказках предметов, есть ли у вас этот облик, но не из данного конкретного источника предмета.",
    ["TOGGLE_DESC_autoQuestWatch"] = "Автоматически добавляет новые задания в трекер заданий в правой части экрана.",
    ["TOGGLE_DESC_autoQuestProgress"] = "Показывает всплывающие уведомления при прогрессе по заданиям.",
    ["TOGGLE_DESC_mapFade"] = "Делает карту полупрозрачной при движении, чтобы вы по-прежнему видели игровой мир.",
    ["TOGGLE_DESC_rotateMinimap"] = "Миникарта вращается при повороте, как компас, вместо фиксированного положения севером вверх.",
    ["TOGGLE_DESC_useUiScale"] = "Позволяет настраивать масштаб интерфейса. Включите это, чтобы использовать ползунок масштаба.",
    ["TOGGLE_DESC_uiScale"] = "Общий размер интерфейса. Требует включённого собственного масштаба интерфейса.",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "Отображает индикаторы с полосой здоровья над вражескими существами.",
    ["TOGGLE_DESC_nameplateShowFriends"] = "Отображает индикаторы с полосой здоровья над дружественными существами.",
    ["TOGGLE_DESC_nameplateShowSelf"] = "Показывает вашу личную полосу ресурса как индикатор над персонажем.",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "Всегда показывает ваш личный индикатор ресурса, даже вне боя.",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "Показывает ваш личный индикатор ресурса только в бою.",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "Окрашивает индикаторы врагов по классу в PvP.",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "Окрашивает индикаторы союзников по классу.",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "Мигает индикатором, когда вы как танк теряете угрозу на враге.",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "Сквозные клики по индикаторам врагов. Вы видите полосы здоровья, но не можете щёлкнуть для выбора цели.",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "Сквозные клики по индикаторам союзников. Вы видите полосы здоровья, но не можете щёлкнуть для выбора союзников.",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "Максимальное расстояние в метрах, на котором видны индикаторы. В подземельях максимум — 60.",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "Главный множитель размера для всех индикаторов. Применяется после остальных настроек масштаба.",
    ["TOGGLE_DESC_namePlateEnemySize"] = "Множитель размера индикаторов врагов. Больше — их легче видеть в бою.",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "Множитель размера индикаторов дружественных игроков.",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "Показывает всплывающие числа урона и исцеления, поднимающиеся над врагами и союзниками.",
    ["TOGGLE_DESC_enableCombatText"] = "Показывает числа урона и исцеления в стандартной области боевого текста рядом с персонажем.",
    ["TOGGLE_DESC_fctCombatState"] = "Показывает всплывающие уведомления вроде «Вы вступили в бой!» через стандартную систему боевого текста.",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "Показывает наносимый вами урон в виде всплывающих чисел.",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "Показывает получаемое вами исцеление в виде всплывающих зелёных чисел.",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "Показывает вход в бой и выход из него в виде всплывающих текстовых сообщений.",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "Показывает всплывающим текстом, когда вы получаете или теряете усиления и ослабления.",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "Показывает результаты «Уклонение», «Парирование» и «Промах» всплывающим текстом.",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "Показывает получение очков чести всплывающим текстом в PvP.",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "Показывает прирост и потерю репутации всплывающим текстом.",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "Показывает прирост энергии, ярости и маны всплывающим текстом.",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "Показывает получение очков серий приёмов всплывающим текстом.",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "Показывает срабатывания реактивных способностей всплывающим текстом.",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "Показывает урон вашего питомца в ближнем бою в виде всплывающих чисел.",

    ["TOGGLE_DESC_cameraBobbing"] = "Камера плавно покачивается вверх-вниз при ходьбе и беге. Атмосфернее, но может вызывать укачивание.",
    ["TOGGLE_DESC_cameraWaterCollision"] = "Не даёт камере уходить под воду, когда ваш персонаж находится над поверхностью.",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "Ваше летающее средство передвижения наклоняется, показывая направление движения, для большей реалистичности.",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "Камера автоматически наклоняется в зависимости от направления движения. Это функция Action Cam.",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "Множитель максимальной дальности отдаления камеры. Большие значения позволяют отдалять сильнее.",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "Насколько быстро камера поворачивается влево и вправо.",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "Насколько быстро камера наклоняется вверх и вниз.",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "Насколько быстро камера приближается и отдаляется колёсиком прокрутки.",

    ["TOGGLE_DESC_chatBubbles"] = "Показывает облачка реплик над головами персонажей, когда они используют /сказать или /крикнуть.",
    ["TOGGLE_DESC_chatBubblesParty"] = "Показывает облачка реплик для сообщений группы и рейда над головами персонажей.",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "Окрашивает имена игроков в чате по их классу.",
    ["TOGGLE_DESC_blockTrades"] = "Не даёт другим игрокам открывать с вами окна обмена.",
    ["TOGGLE_DESC_blockChannelInvites"] = "Не даёт другим игрокам приглашать вас в каналы чата.",
    ["TOGGLE_DESC_guildMemberNotify"] = "Показывает сообщение в чате, когда члены гильдии входят в игру или выходят из неё.",
    ["TOGGLE_DESC_removeChatDelay"] = "Убирает антиспам-задержку между отправкой сообщений в чат.",
    ["TOGGLE_DESC_chatMouseScroll"] = "Прокручивайте историю чата колёсиком мыши.",
    ["TOGGLE_DESC_profanityFilter"] = "Заменяет бранные слова символами в чате.",
    ["TOGGLE_DESC_chatStyle"] = "«Классический» использует отдельные окна чата. «Современный» использует чат со вкладками.",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "Главный переключатель всего игрового звука. Его отключение заглушает всё.",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "Воспроизводит фоновую музыку в зонах и во время событий.",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "Воспроизводит звуковые эффекты, включая способности, звуки боя и щелчки интерфейса.",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "Воспроизводит озвучку НИП и аудио диалогов заданий.",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "Воспроизводит фоновые звуки окружения, такие как ветер, птицы и вода.",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "Воспроизводит звуки вашего питомца, такие как рык и движение.",
    ["TOGGLE_DESC_FootstepSounds"] = "Воспроизводит звуки шагов при ходьбе и беге.",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "Общая громкость игры. Влияет на все остальные ползунки громкости.",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "Громкость фоновой музыки.",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "Громкость звуковых эффектов, включая способности и бой.",

    ["TOGGLE_DESC_ffxDeath"] = "Показывает обесцвеченный чёрно-белый эффект экрана при вашей смерти.",
    ["TOGGLE_DESC_ffxGlow"] = "Включает мягкий эффект свечения bloom вокруг ярких объектов.",
    ["TOGGLE_DESC_ffxNether"] = "Включает особые визуальные эффекты в Круговерти Пустоты и областях Бездны.",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "Делает ваши собственные эффекты заклинаний заметнее по сравнению с эффектами других игроков.",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "Отключает красную вспышку экрана, появляющуюся при критически низком здоровье.",
    ["TOGGLE_DESC_hdPlayerModels"] = "Использует модели персонажей высокой чёткости. Выглядят лучше, но используют больше памяти.",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "Показывает подсвеченный круг под вашим персонажем, чтобы вы всегда находили себя в толпе.",
    ["TOGGLE_DESC_gxVSync"] = "Ограничивает кадры частотой обновления вашего монитора. Предотвращает разрывы изображения, но добавляет небольшую задержку ввода.",
    ["TOGGLE_DESC_gxTripleBuffer"] = "Тройная буферизация для более плавной смены кадров. Добавляет небольшую задержку ввода.",
    ["TOGGLE_DESC_particleDensity"] = "Сколько эффектов заклинаний и частиц появляется одновременно. Меньшие значения повышают FPS в людных рейдах.",
    ["TOGGLE_DESC_maxFPS"] = "Максимум кадров в секунду, когда окно игры активно. Установите 0 для снятия ограничения.",
    ["TOGGLE_DESC_maxFPSBk"] = "Максимум кадров в секунду, когда окно игры в фоне. Меньшие значения экономят энергию при сворачивании.",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "Максимум кадров в очереди на отрисовку. Меньшие значения снижают задержку ввода. Большие дают более плавный вывод.",
    ["TOGGLE_DESC_RenderScale"] = "Множитель внутреннего разрешения. Значения выше 1.0 дают суперсэмплинг для более чёткого изображения. Ниже 1.0 повышают производительность.",
    ["TOGGLE_DESC_graphicsQuality"] = "Главная предустановка качества графики. Её изменение автоматически настраивает все остальные параметры графики.",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "Сглаживает зубчатые края объектов. Более высокие режимы дают лучшее качество, но используют больше ресурсов GPU.",
    ["TOGGLE_DESC_colorblindMode"] = "Включает цветовые настройки для дальтоников. Выберите режим, соответствующий вашему типу нарушения цветового зрения.",

    ["TOGGLE_DESC_disableServerNagle"] = "Снижает сетевую задержку, отключая объединение пакетов. Может незначительно увеличить расход трафика.",
    ["TOGGLE_DESC_gxFixLag"] = "Снижает задержку ввода курсора мыши на некоторых системах за счёт изменения очереди отрисовки.",
    ["TOGGLE_DESC_reducedLagTolerance"] = "Оптимизирует сетевую производительность для соединений с низкой задержкой. Может влиять на очередь заклинаний.",
    ["TOGGLE_DESC_SpellQueueWindow"] = "За сколько миллисекунд вы можете поставить следующее заклинание в очередь до окончания текущего. Большие значения снисходительнее к таймингу.",

    ["TOGGLE_OPT_chatStyle_classic"] = "Классический",
    ["TOGGLE_OPT_chatStyle_im"] = "Современный",
    ["TOGGLE_OPT_graphicsQuality_1"] = "1",
    ["TOGGLE_OPT_graphicsQuality_2"] = "2",
    ["TOGGLE_OPT_graphicsQuality_3"] = "3",
    ["TOGGLE_OPT_graphicsQuality_4"] = "4",
    ["TOGGLE_OPT_graphicsQuality_5"] = "5",
    ["TOGGLE_OPT_graphicsQuality_6"] = "6",
    ["TOGGLE_OPT_graphicsQuality_7"] = "7",
    ["TOGGLE_OPT_graphicsQuality_8"] = "8",
    ["TOGGLE_OPT_graphicsQuality_9"] = "9",
    ["TOGGLE_OPT_graphicsQuality_10"] = "10",
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "Выкл.",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA низкое",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA высокое",
    ["TOGGLE_OPT_colorblindMode_0"] = "Выкл.",
    ["TOGGLE_OPT_colorblindMode_1"] = "Протанопия",
    ["TOGGLE_OPT_colorblindMode_2"] = "Дейтеранопия",
    ["TOGGLE_OPT_colorblindMode_3"] = "Тританопия",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "Предмет задания 1",
    ["BINDING_NAME_QUESTITEM_2"] = "Предмет задания 2",
    ["BINDING_NAME_QUESTITEM_3"] = "Предмет задания 3",
    ["BINDING_NAME_QUESTITEM_4"] = "Предмет задания 4",
    ["BINDING_NAME_BAGITEM_1"] = "Предмет из сумки 1",
    ["BINDING_NAME_BAGITEM_2"] = "Предмет из сумки 2",
    ["BINDING_NAME_BAGITEM_3"] = "Предмет из сумки 3",
    ["BINDING_NAME_BAGITEM_4"] = "Предмет из сумки 4",
    ["BINDING_NAME_COPY_TEXT"] = "Копировать текст",
})
