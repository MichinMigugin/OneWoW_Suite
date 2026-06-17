local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — pending native review
OneWoW.Locale:Register(ADDON_NAME, "zhTW", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "已載入。",

    ["TAB_FEATURES"] = "QoL 功能",
    ["TAB_TOGGLES"] = "開關",

    ["FEATURES_LIST_TITLE"] = "功能",
    ["FEATURES_FAVORITE_TT_TITLE"] = "最愛",
    ["FEATURES_FAVORITE_TT_DESC"] = "將此功能釘選到頂端的最愛區。再次點擊可將其從最愛中移除。",
    ["FEATURES_DETAIL_TITLE"] = "詳情",
    ["FEATURES_EMPTY"] = "未載入任何模組。",
    ["FEATURES_NO_SELECTION"] = "請從清單中選擇一項功能。",
    ["FEATURES_ENABLED"] = "已啟用",
    ["FEATURES_DISABLED"] = "已停用",
    ["FEATURES_CATEGORY_LABEL"] = "分類：",
    ["FEATURES_VERSION_LABEL"] = "版本：",
    ["FEATURES_AUTHOR_LABEL"] = "作者：",
    ["FEATURES_CONTACT_LABEL"] = "聯絡方式：",
    ["FEATURES_LINK_LABEL"] = "連結：",
    ["FEATURES_DETAILS_BTN"] = "詳情",
    ["FEATURES_DETAILS_TITLE"] = "模組詳情",
    ["FEATURES_TOGGLES_HEADER"] = "模組開關",
    ["FEATURES_ON"] = "開",
    ["FEATURES_OFF"] = "關",
    ["FEATURES_PREVIEW_LABEL"] = "預覽：",

    ["CATEGORY_AUTOMATION"] = "自動化",
    ["CATEGORY_INTERFACE"] = "介面",
    ["CATEGORY_SOCIAL"] = "社交",
    ["CATEGORY_COMBAT"] = "戰鬥",
    ["CATEGORY_ECONOMY"] = "經濟",
    ["CATEGORY_UTILITY"] = "實用工具",

    ["TOGGLES_LIST_TITLE"] = "遊戲旗標",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "最愛",
    ["TOGGLES_FAVORITE_TT_DESC"] = "將此開關釘選到頂端的最愛區。再次點擊可將其從最愛中移除。",
    ["TOGGLES_DETAIL_TITLE"] = "旗標詳情",
    ["TOGGLES_COMING_SOON"] = "遊戲開關旗標將在未來的更新中加入。",
    ["TOGGLES_NO_SELECTION"] = "請從清單中選擇一個旗標。",

    ["SETTINGS_THEME_HEADER"] = "配色主題",
    ["SETTINGS_THEME_DESC"] = "選擇一個配色主題。變更會即時套用。",
    ["SETTINGS_LANGUAGE_DESC"] = "選擇你偏好的語言。變更會即時套用。",
    ["SETTINGS_DEVELOPER_HEADER"] = "開發者資訊",
    ["SETTINGS_DEVELOPER_DESC"] = "此插件支援外部模組。透過在 Modules\\external\\ 中建立模組資料夾來新增 QoL 功能。點擊「開發者說明」按鈕查看完整文件。",
    ["SETTINGS_DEV_HELP_BTN"] = "開發者說明",

    ["DEVHELP_TITLE"] = "模組開發者指南",
    ["DEVHELP_BODY"] = [[隨插即用模組系統

建立你的資料夾：
  Modules\external\yourmodule\

檔案（module.lua 最先載入）：
  module.lua      - 中繼資料 + 註冊
  yourmodule.lua  - 模組邏輯
  Locales\enUS.lua  （koKR.lua 選用）

在 module.lua 中定義你的模組
（id 僅存在於此處）：
  local ADDON_NAME, ns = ...
  ns.ModuleRegistry:Define(ADDON_NAME, {
    id          = "yourmodule",
    title       = "MY_TITLE",
    category    = "AUTOMATION",
    description = "MY_DESC",
    version     = "1.0",
    author      = "你的名字",
    contact     = "your@email.com",
    link        = "https://yoursite.com",
    toggles = {
      { id = "myToggle", label = "MY_TOGGLE_LABEL",
        description = "MY_TOGGLE_DESC", default = true },
    },
    defaultEnabled = true,
  })

在 yourmodule.lua 中取得它 + 你的
本地化檢視（在載入時擷取，切勿在執行時）：
  local _, ns = ...
  local M, L = ns.ModuleRegistry:Current()
  if not M then return end

  function M:OnEnable() end
  function M:OnDisable() end
  function M:OnToggle(id, val) end

在 Locales\enUS.lua 中：
  local _, ns = ...
  local M = ns.ModuleRegistry:Current()
  OneWoW.Locale:Register(M._scope, "enUS", {
    ["MY_TITLE"] = "My Title",
    ["MY_DESC"]  = "What it does",
  })

scope 即 ADDON_NAME .. "." .. id，例如
OneWoW_QoL.yourmodule（自動衍生，無需
硬寫 scope 字串）。

透過 id 參照其他模組：
  ns.ModuleRegistry:GetById("othermodule")
切勿使用 ns.<X>Module。

title、description 以及開關的標籤和描述
皆為本地化鍵。author、contact 和 link 為
選用項目。contact 和 link 會在模組詳情對話框
中顯示為可複製的文字框。

可用分類：
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

將你的檔案加入 TOC 的 EXTERNAL
MODULES 區段。順序：module.lua 最先，然後
是 Locales，再然後是你的程式碼檔案。

SavedVariables 資料庫空間：
  OneWoW_QoL_DB.modules.yourmodule

完整的可執行範例請參閱
Modules\external\autodelete\。]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "點擊以開啟",
    ["MINIMAP_RIGHT_CLICK"] = "右鍵點擊查看選項",
    ["MINIMAP_OPEN"] = "開啟 QoL",

    ["LANG_ENGLISH"] = "英文",
    ["LANG_KOREAN"] = "韓文",


    ["SEARCH_HINT"] = "篩選...",
    ["TOGGLES_STATUS_ALL"] = "顯示 %d 個 CVar",
    ["TOGGLES_STATUS_FILTERED"] = "顯示 %d 個，共 %d 個",
    ["FEATURES_STATUS_ENABLED"] = "已啟用 %d 個，共 %d 個",

    ["TOGGLES_CVAR_LABEL"] = "CVar：",
    ["TOGGLES_ON"] = "開",
    ["TOGGLES_OFF"] = "關",
    ["TOGGLES_VALUE_LABEL"] = "數值：",

    ["TOGGLE_CAT_GAMEPLAY"] = "遊戲玩法",
    ["TOGGLE_CAT_INTERFACE"] = "介面",
    ["TOGGLE_CAT_NAMEPLATES"] = "名條",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "戰鬥文字",
    ["TOGGLE_CAT_CAMERA"] = "鏡頭",
    ["TOGGLE_CAT_CHAT"] = "聊天與社交",
    ["TOGGLE_CAT_AUDIO"] = "音效",
    ["TOGGLE_CAT_GRAPHICS"] = "畫面",
    ["TOGGLE_CAT_NETWORK"] = "網路",

    ["TOGGLE_NAME_autoLootDefault"] = "自動拾取",
    ["TOGGLE_NAME_autoSelfCast"] = "自動對自己施法",
    ["TOGGLE_NAME_autoDismount"] = "自動下坐騎",
    ["TOGGLE_NAME_autoDismountFlying"] = "飛行中自動下坐騎",
    ["TOGGLE_NAME_autoStand"] = "自動起身",
    ["TOGGLE_NAME_autoUnshift"] = "自動解除形態",
    ["TOGGLE_NAME_assistAttack"] = "協助攻擊",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "按下時觸發動作按鈕",
    ["TOGGLE_NAME_deselectOnClick"] = "點擊空地取消目標",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "切換目標時停止自動攻擊",
    ["TOGGLE_NAME_lootUnderMouse"] = "在滑鼠處開啟拾取視窗",
    ["TOGGLE_NAME_lootLeftmostBag"] = "拾取至最左側背包",
    ["TOGGLE_NAME_interactOnLeftClick"] = "左鍵互動",
    ["TOGGLE_NAME_autointeract"] = "自動互動",
    ["TOGGLE_NAME_autoClearAFK"] = "自動取消暫離狀態",

    ["TOGGLE_NAME_countdownForCooldowns"] = "冷卻倒數計時",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "法術觸發光效",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "永遠顯示動作列",
    ["TOGGLE_NAME_lockActionBars"] = "鎖定動作列",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "左下動作列",
    ["TOGGLE_NAME_bottomRightActionBar"] = "右下動作列",
    ["TOGGLE_NAME_rightActionBar"] = "右側動作列",
    ["TOGGLE_NAME_rightTwoActionBar"] = "右側動作列 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "顯示背包空格數",
    ["TOGGLE_NAME_buffDurations"] = "顯示增益持續時間",
    ["TOGGLE_NAME_showTargetOfTarget"] = "顯示目標的目標",
    ["TOGGLE_NAME_showTargetCastbar"] = "顯示目標施法條",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "全尺寸專注目標框架",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "格式化大數字",
    ["TOGGLE_NAME_alwaysCompareItems"] = "永遠比較物品",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "缺少的幻化來源",
    ["TOGGLE_NAME_autoQuestWatch"] = "自動追蹤任務",
    ["TOGGLE_NAME_autoQuestProgress"] = "任務進度彈出視窗",
    ["TOGGLE_NAME_mapFade"] = "移動時地圖淡出",
    ["TOGGLE_NAME_rotateMinimap"] = "旋轉小地圖",
    ["TOGGLE_NAME_useUiScale"] = "啟用自訂介面縮放",
    ["TOGGLE_NAME_uiScale"] = "介面縮放",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "顯示敵方名條",
    ["TOGGLE_NAME_nameplateShowFriends"] = "顯示友方名條",
    ["TOGGLE_NAME_nameplateShowSelf"] = "顯示個人名條",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "永遠顯示個人名條",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "戰鬥中顯示個人名條",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "敵方名條依職業著色",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "友方名條依職業著色",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "失去仇恨閃爍提示",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "敵方名條可穿透點擊",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "友方名條可穿透點擊",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "名條可見距離",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "名條全域縮放",
    ["TOGGLE_NAME_namePlateEnemySize"] = "敵方名條大小",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "友方名條大小",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "浮動戰鬥文字",
    ["TOGGLE_NAME_enableCombatText"] = "預設戰鬥文字",
    ["TOGGLE_NAME_fctCombatState"] = "戰鬥狀態文字",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "傷害數字",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "治療數字",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "進入/脫離戰鬥文字",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "增益/減益變化文字",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "閃躲/招架/未命中文字",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "榮譽獲得",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "聲望變化",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "能量/法力獲得",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "連擊點數獲得",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "觸發反應技能",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "寵物近戰傷害",

    ["TOGGLE_NAME_cameraBobbing"] = "鏡頭晃動",
    ["TOGGLE_NAME_cameraWaterCollision"] = "鏡頭水面碰撞",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "飛行角度前瞻",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "動態鏡頭俯仰",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "鏡頭最大拉遠距離",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "鏡頭水平轉動速度",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "鏡頭垂直俯仰速度",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "鏡頭縮放速度",

    ["TOGGLE_NAME_chatBubbles"] = "對話泡泡（/說）",
    ["TOGGLE_NAME_chatBubblesParty"] = "對話泡泡（隊伍）",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "聊天中依職業著色名字",
    ["TOGGLE_NAME_blockTrades"] = "封鎖交易請求",
    ["TOGGLE_NAME_blockChannelInvites"] = "封鎖頻道邀請",
    ["TOGGLE_NAME_guildMemberNotify"] = "公會登入通知",
    ["TOGGLE_NAME_removeChatDelay"] = "移除聊天延遲",
    ["TOGGLE_NAME_chatMouseScroll"] = "滑鼠滾輪捲動聊天",
    ["TOGGLE_NAME_profanityFilter"] = "髒話過濾",
    ["TOGGLE_NAME_chatStyle"] = "聊天樣式",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "全部聲音",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "音樂",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "音效",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "對話/語音",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "環境音",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "寵物聲音",
    ["TOGGLE_NAME_FootstepSounds"] = "腳步聲",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "主音量",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "音樂音量",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "音效音量",

    ["TOGGLE_NAME_ffxDeath"] = "死亡畫面效果",
    ["TOGGLE_NAME_ffxGlow"] = "泛光/光暈效果",
    ["TOGGLE_NAME_ffxNether"] = "虛空視覺效果",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "強調我的法術效果",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "停用低血量閃爍",
    ["TOGGLE_NAME_hdPlayerModels"] = "高清玩家模型",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "角色高亮",
    ["TOGGLE_NAME_gxVSync"] = "垂直同步",
    ["TOGGLE_NAME_gxTripleBuffer"] = "三重緩衝",
    ["TOGGLE_NAME_particleDensity"] = "粒子密度",
    ["TOGGLE_NAME_maxFPS"] = "最大幀數（前景）",
    ["TOGGLE_NAME_maxFPSBk"] = "最大幀數（背景）",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "最大幀延遲",
    ["TOGGLE_NAME_RenderScale"] = "算繪縮放",
    ["TOGGLE_NAME_graphicsQuality"] = "畫質預設",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "反鋸齒模式",
    ["TOGGLE_NAME_colorblindMode"] = "色盲模式",

    ["TOGGLE_NAME_disableServerNagle"] = "停用 Nagle 演算法",
    ["TOGGLE_NAME_gxFixLag"] = "修復輸入延遲",
    ["TOGGLE_NAME_reducedLagTolerance"] = "降低延遲容許值",
    ["TOGGLE_NAME_SpellQueueWindow"] = "法術佇列視窗",

    ["TOGGLE_DESC_autoLootDefault"] = "自動拾取所有戰利品，無需逐一點擊。",
    ["TOGGLE_DESC_autoSelfCast"] = "當你沒有選擇目標時，將有益法術施放在自己身上。",
    ["TOGGLE_DESC_autoDismount"] = "當你嘗試採集、與 NPC 對話或進入戰鬥時，自動從坐騎上下來。",
    ["TOGGLE_DESC_autoDismountFlying"] = "即使在飛行中也自動下坐騎。警告：你會摔落！",
    ["TOGGLE_DESC_autoStand"] = "坐下時若嘗試移動或行動，則自動起身。",
    ["TOGGLE_DESC_autoUnshift"] = "當你使用需要解除形態的技能時，自動離開形態或變身。",
    ["TOGGLE_DESC_assistAttack"] = "當你協助友方目標時，自動開始攻擊其目標。",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "開啟時：按下按鍵即施放法術。關閉時：放開按鍵才施放法術，可先查看技能距離。",
    ["TOGGLE_DESC_deselectOnClick"] = "點擊空地時清除你的目標。",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "當你切換到新目標時停止自動攻擊。",
    ["TOGGLE_DESC_lootUnderMouse"] = "在滑鼠游標處開啟拾取視窗，而非固定位置。",
    ["TOGGLE_DESC_lootLeftmostBag"] = "將拾取的物品放入最左側背包，而非最右側。",
    ["TOGGLE_DESC_interactOnLeftClick"] = "左鍵點擊 NPC 和物件進行互動，而非右鍵。",
    ["TOGGLE_DESC_autointeract"] = "右鍵點擊 NPC 會自動與其對話或拾取。",
    ["TOGGLE_DESC_autoClearAFK"] = "當你移動或進行任何操作時，自動取消暫離狀態。",

    ["TOGGLE_DESC_countdownForCooldowns"] = "在冷卻中的技能圖示中央顯示倒數計時數字。",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "當觸發效果啟動時，在技能上顯示發光邊框，例如瞬發觸發效果。",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "即使為空也保持動作列可見，避免動作列隱藏。",
    ["TOGGLE_DESC_lockActionBars"] = "防止意外將技能從動作列上拖出。",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "在主動作列上方左側顯示額外動作列。",
    ["TOGGLE_DESC_bottomRightActionBar"] = "在主動作列上方右側顯示額外動作列。",
    ["TOGGLE_DESC_rightActionBar"] = "在螢幕右側顯示直向動作列。",
    ["TOGGLE_DESC_rightTwoActionBar"] = "在螢幕右側顯示第二條直向動作列。",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "在背包列上顯示空背包格數。",
    ["TOGGLE_DESC_buffDurations"] = "以倒數計時數字顯示你增益的剩餘時間。",
    ["TOGGLE_DESC_showTargetOfTarget"] = "顯示你目標正在選取誰。對坦克和補師很有用。",
    ["TOGGLE_DESC_showTargetCastbar"] = "為你目前的目標顯示施法條，以便看清其正在施放什麼。",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "為你的專注目標使用全尺寸單位框架，而非小框架。",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "以千位分隔符顯示大數字，例如 1,000,000 而非 1000000。",
    ["TOGGLE_DESC_alwaysCompareItems"] = "滑鼠移到裝備上時自動顯示物品比較提示。無需按住 Shift 鍵。",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "在物品提示中顯示你是否已擁有此外觀，但並非來自這個特定物品來源。",
    ["TOGGLE_DESC_autoQuestWatch"] = "自動將新任務加入螢幕右側的任務追蹤器。",
    ["TOGGLE_DESC_autoQuestProgress"] = "當你的任務取得進展時顯示彈出通知。",
    ["TOGGLE_DESC_mapFade"] = "移動時讓地圖變透明，以便仍能看到遊戲世界。",
    ["TOGGLE_DESC_rotateMinimap"] = "小地圖像羅盤一樣隨你轉向而旋轉，而非固定為正北朝上。",
    ["TOGGLE_DESC_useUiScale"] = "允許自訂介面縮放。啟用此項即可使用介面縮放滑桿。",
    ["TOGGLE_DESC_uiScale"] = "使用者介面的整體大小。需要啟用自訂介面縮放。",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "在敵方單位上方顯示帶生命條的名條。",
    ["TOGGLE_DESC_nameplateShowFriends"] = "在友方單位上方顯示帶生命條的名條。",
    ["TOGGLE_DESC_nameplateShowSelf"] = "在你的角色上方將個人資源條顯示為名條。",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "永遠顯示你的個人資源條名條，即使脫離戰鬥。",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "僅在戰鬥中顯示你的個人資源條名條。",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "在 PvP 中依職業為敵方名條著色。",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "依職業為友方名條著色。",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "身為坦克失去對敵人的仇恨時，使名條閃爍。",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "可穿透點擊敵方名條。你能看到生命條，但無法點擊選取目標。",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "可穿透點擊友方名條。你能看到生命條，但無法點擊選取友方。",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "名條可見的最大距離（碼）。地城內最大為 60。",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "所有名條的主縮放倍數。在其他縮放設定之後生效。",
    ["TOGGLE_DESC_namePlateEnemySize"] = "敵方名條的尺寸倍數。越大在戰鬥中越易看清。",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "友方玩家名條的尺寸倍數。",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "顯示從敵人和盟友身上升起的浮動傷害和治療數字。",
    ["TOGGLE_DESC_enableCombatText"] = "在你角色附近的預設戰鬥文字區域顯示傷害和治療數字。",
    ["TOGGLE_DESC_fctCombatState"] = "使用預設戰鬥文字系統顯示「你已進入戰鬥！」等浮動文字通知。",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "以浮動數字顯示你造成的傷害。",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "以浮動綠色數字顯示你受到的治療。",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "以浮動文字訊息顯示進入和脫離戰鬥。",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "以浮動文字顯示你獲得或失去增益和減益。",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "以浮動文字顯示閃躲、招架和未命中的結果。",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "在 PvP 中以浮動文字顯示榮譽點數獲得。",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "以浮動文字顯示聲望的獲得和損失。",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "以浮動文字顯示能量、怒氣和法力的獲得。",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "以浮動文字顯示連擊點數的獲得。",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "以浮動文字顯示反應技能的觸發。",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "以浮動數字顯示你寵物的近戰傷害。",

    ["TOGGLE_DESC_cameraBobbing"] = "行走和奔跑時鏡頭會輕微上下晃動。更有沉浸感，但可能引起暈眩。",
    ["TOGGLE_DESC_cameraWaterCollision"] = "當你的角色在水面之上時，防止鏡頭沉入水下。",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "你的飛行坐騎會傾斜以顯示你的前進方向，更具真實感。",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "鏡頭會根據你的移動方向自動傾斜。這就是動態鏡頭（Action Cam）功能。",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "鏡頭最大拉遠距離的倍數。數值越高可拉得越遠。",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "鏡頭左右旋轉的速度。",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "鏡頭上下俯仰的速度。",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "使用滾輪拉近和拉遠鏡頭的速度。",

    ["TOGGLE_DESC_chatBubbles"] = "當角色使用 /說 或 /大喊 時，在其頭頂顯示對話泡泡。",
    ["TOGGLE_DESC_chatBubblesParty"] = "在角色頭頂顯示隊伍和團隊聊天訊息的對話泡泡。",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "在聊天中依玩家職業為其名字著色。",
    ["TOGGLE_DESC_blockTrades"] = "阻止其他玩家與你開啟交易視窗。",
    ["TOGGLE_DESC_blockChannelInvites"] = "阻止其他玩家邀請你加入聊天頻道。",
    ["TOGGLE_DESC_guildMemberNotify"] = "當公會成員上線或下線時在聊天中顯示訊息。",
    ["TOGGLE_DESC_removeChatDelay"] = "移除傳送聊天訊息之間的防洗版延遲。",
    ["TOGGLE_DESC_chatMouseScroll"] = "使用滑鼠滾輪瀏覽聊天記錄。",
    ["TOGGLE_DESC_profanityFilter"] = "在聊天中用符號取代髒話。",
    ["TOGGLE_DESC_chatStyle"] = "經典樣式使用獨立聊天視窗。現代樣式使用分頁式聊天。",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "所有遊戲音訊的總開關。關閉後將靜音一切。",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "在區域中和事件期間播放背景音樂。",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "播放音效，包括技能、戰鬥聲音和介面點擊聲。",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "播放 NPC 配音和任務對話音訊。",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "播放環境背景聲音，如風、鳥和水。",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "播放你寵物的聲音，如咆哮和移動聲。",
    ["TOGGLE_DESC_FootstepSounds"] = "在行走和奔跑時播放腳步聲。",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "遊戲總音量。影響所有其他音量滑桿。",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "背景音樂的音量。",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "音效的音量，包括技能和戰鬥。",

    ["TOGGLE_DESC_ffxDeath"] = "當你死亡時顯示灰階去色的畫面效果。",
    ["TOGGLE_DESC_ffxGlow"] = "啟用明亮物體周圍柔和的泛光光暈效果。",
    ["TOGGLE_DESC_ffxNether"] = "在虛空和虛無區域啟用特殊視覺效果。",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "使你自己的法術效果相比其他玩家的更明顯。",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "停用生命值危急時出現的紅色畫面閃爍。",
    ["TOGGLE_DESC_hdPlayerModels"] = "使用高清玩家角色模型。更好看，但佔用更多記憶體。",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "在你的角色下方顯示一個高亮光環，讓你在人群中總能找到自己。",
    ["TOGGLE_DESC_gxVSync"] = "將幀數限制為你螢幕的更新率。可防止畫面撕裂，但會增加少量輸入延遲。",
    ["TOGGLE_DESC_gxTripleBuffer"] = "三重緩衝以獲得更流暢的幀節奏。會增加少量輸入延遲。",
    ["TOGGLE_DESC_particleDensity"] = "同時出現的法術效果和粒子數量。數值越低，在繁忙團隊中越能提升幀數。",
    ["TOGGLE_DESC_maxFPS"] = "遊戲視窗處於使用中時的最大幀數。設為 0 表示不限制。",
    ["TOGGLE_DESC_maxFPSBk"] = "遊戲視窗處於背景時的最大幀數。數值越低，切出時越省電。",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "排隊等待算繪的最大幀數。數值越低輸入延遲越小，越高輸出越流暢。",
    ["TOGGLE_DESC_RenderScale"] = "內部解析度倍數。高於 1.0 會超取樣以獲得更銳利的畫面，低於 1.0 可提升效能。",
    ["TOGGLE_DESC_graphicsQuality"] = "畫質主預設。更改此項將自動調整所有其他畫面設定。",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "平滑物體的鋸齒邊緣。更高模式畫質更好，但佔用更多 GPU 資源。",
    ["TOGGLE_DESC_colorblindMode"] = "啟用色盲友善的色彩調整。選擇符合你色覺缺陷類型的模式。",

    ["TOGGLE_DESC_disableServerNagle"] = "透過停用封包合併降低網路延遲。可能略微增加頻寬占用。",
    ["TOGGLE_DESC_gxFixLag"] = "透過修改算繪佇列，在某些系統上降低滑鼠游標的輸入延遲。",
    ["TOGGLE_DESC_reducedLagTolerance"] = "針對低延遲連線最佳化網路效能。可能影響法術排隊行為。",
    ["TOGGLE_DESC_SpellQueueWindow"] = "在目前法術結束前，你可以提前排入下一個法術的毫秒數。數值越高，對時機越寬容。",

    ["TOGGLE_OPT_chatStyle_classic"] = "經典",
    ["TOGGLE_OPT_chatStyle_im"] = "現代",
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
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "關",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA 低",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA 高",
    ["TOGGLE_OPT_colorblindMode_0"] = "關",
    ["TOGGLE_OPT_colorblindMode_1"] = "紅色盲",
    ["TOGGLE_OPT_colorblindMode_2"] = "綠色盲",
    ["TOGGLE_OPT_colorblindMode_3"] = "藍色盲",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "任務物品 1",
    ["BINDING_NAME_QUESTITEM_2"] = "任務物品 2",
    ["BINDING_NAME_QUESTITEM_3"] = "任務物品 3",
    ["BINDING_NAME_QUESTITEM_4"] = "任務物品 4",
    ["BINDING_NAME_BAGITEM_1"] = "背包物品 1",
    ["BINDING_NAME_BAGITEM_2"] = "背包物品 2",
    ["BINDING_NAME_BAGITEM_3"] = "背包物品 3",
    ["BINDING_NAME_BAGITEM_4"] = "背包物品 4",
    ["BINDING_NAME_COPY_TEXT"] = "複製文字",
})
