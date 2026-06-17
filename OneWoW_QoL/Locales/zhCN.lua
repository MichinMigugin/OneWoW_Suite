local ADDON_NAME = ...

-- Machine-drafted (Phase 4) — pending native review
OneWoW.Locale:Register(ADDON_NAME, "zhCN", {

    ["ADDON_TITLE"] = "OneWoW - QoL",
    ["ADDON_TITLE_SHORT"] = "QoL",
    ["ADDON_TITLE_FRAME"] = "OneWoW - QoL",
    ["ADDON_LOADED"] = "已加载。",

    ["TAB_FEATURES"] = "QoL 功能",
    ["TAB_TOGGLES"] = "开关",

    ["FEATURES_LIST_TITLE"] = "功能",
    ["FEATURES_FAVORITE_TT_TITLE"] = "收藏",
    ["FEATURES_FAVORITE_TT_DESC"] = "将此功能固定到顶部的收藏区。再次点击可将其从收藏中移除。",
    ["FEATURES_DETAIL_TITLE"] = "详情",
    ["FEATURES_EMPTY"] = "未加载任何模块。",
    ["FEATURES_NO_SELECTION"] = "请从列表中选择一项功能。",
    ["FEATURES_ENABLED"] = "已启用",
    ["FEATURES_DISABLED"] = "已禁用",
    ["FEATURES_CATEGORY_LABEL"] = "分类：",
    ["FEATURES_VERSION_LABEL"] = "版本：",
    ["FEATURES_AUTHOR_LABEL"] = "作者：",
    ["FEATURES_CONTACT_LABEL"] = "联系方式：",
    ["FEATURES_LINK_LABEL"] = "链接：",
    ["FEATURES_DETAILS_BTN"] = "详情",
    ["FEATURES_DETAILS_TITLE"] = "模块详情",
    ["FEATURES_TOGGLES_HEADER"] = "模块开关",
    ["FEATURES_ON"] = "开",
    ["FEATURES_OFF"] = "关",
    ["FEATURES_PREVIEW_LABEL"] = "预览：",

    ["CATEGORY_AUTOMATION"] = "自动化",
    ["CATEGORY_INTERFACE"] = "界面",
    ["CATEGORY_SOCIAL"] = "社交",
    ["CATEGORY_COMBAT"] = "战斗",
    ["CATEGORY_ECONOMY"] = "经济",
    ["CATEGORY_UTILITY"] = "实用工具",

    ["TOGGLES_LIST_TITLE"] = "游戏标志",
    ["TOGGLES_FAVORITE_TT_TITLE"] = "收藏",
    ["TOGGLES_FAVORITE_TT_DESC"] = "将此开关固定到顶部的收藏区。再次点击可将其从收藏中移除。",
    ["TOGGLES_DETAIL_TITLE"] = "标志详情",
    ["TOGGLES_COMING_SOON"] = "游戏开关标志将在未来的更新中加入。",
    ["TOGGLES_NO_SELECTION"] = "请从列表中选择一个标志。",

    ["SETTINGS_THEME_HEADER"] = "配色主题",
    ["SETTINGS_THEME_DESC"] = "选择一个配色主题。更改将即时生效。",
    ["SETTINGS_LANGUAGE_DESC"] = "选择你偏好的语言。更改将即时生效。",
    ["SETTINGS_DEVELOPER_HEADER"] = "开发者信息",
    ["SETTINGS_DEVELOPER_DESC"] = "此插件支持外部模块。通过在 Modules\\external\\ 中创建模块文件夹来添加 QoL 功能。点击“开发者帮助”按钮查看完整文档。",
    ["SETTINGS_DEV_HELP_BTN"] = "开发者帮助",

    ["DEVHELP_TITLE"] = "模块开发者指南",
    ["DEVHELP_BODY"] = [[即插即用模块系统

创建你的文件夹：
  Modules\external\yourmodule\

文件（module.lua 最先加载）：
  module.lua      - 元数据 + 注册
  yourmodule.lua  - 模块逻辑
  Locales\enUS.lua  （koKR.lua 可选）

在 module.lua 中定义你的模块
（id 仅存在于此处）：
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

在 yourmodule.lua 中获取它 + 你的
本地化视图（在加载时捕获，切勿在运行时）：
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
OneWoW_QoL.yourmodule（自动派生，无需
硬编码 scope 字符串）。

通过 id 引用其他模块：
  ns.ModuleRegistry:GetById("othermodule")
切勿使用 ns.<X>Module。

title、description 以及开关的标签和描述
均为本地化键。author、contact 和 link 为
可选项。contact 和 link 会在模块详情对话框
中显示为可复制的文本框。

可用分类：
  AUTOMATION  INTERFACE  SOCIAL
  COMBAT      ECONOMY    UTILITY

将你的文件添加到 TOC 的 EXTERNAL
MODULES 部分。顺序：module.lua 最先，然后
是 Locales，再然后是你的代码文件。

SavedVariables 数据库空间：
  OneWoW_QoL_DB.modules.yourmodule

完整的可运行示例请参阅
Modules\external\autodelete\。]],

    ["MINIMAP_TOOLTIP_TITLE"] = "OneWoW - QoL",
    ["MINIMAP_TOOLTIP_HINT"] = "点击打开",
    ["MINIMAP_RIGHT_CLICK"] = "右键点击查看选项",
    ["MINIMAP_OPEN"] = "打开 QoL",

    ["LANG_ENGLISH"] = "英语",
    ["LANG_KOREAN"] = "韩语",


    ["SEARCH_HINT"] = "筛选...",
    ["TOGGLES_STATUS_ALL"] = "显示 %d 个 CVar",
    ["TOGGLES_STATUS_FILTERED"] = "显示 %d 个，共 %d 个",
    ["FEATURES_STATUS_ENABLED"] = "已启用 %d 个，共 %d 个",

    ["TOGGLES_CVAR_LABEL"] = "CVar：",
    ["TOGGLES_ON"] = "开",
    ["TOGGLES_OFF"] = "关",
    ["TOGGLES_VALUE_LABEL"] = "数值：",

    ["TOGGLE_CAT_GAMEPLAY"] = "玩法",
    ["TOGGLE_CAT_INTERFACE"] = "界面",
    ["TOGGLE_CAT_NAMEPLATES"] = "姓名板",
    ["TOGGLE_CAT_COMBAT_TEXT"] = "战斗文字",
    ["TOGGLE_CAT_CAMERA"] = "镜头",
    ["TOGGLE_CAT_CHAT"] = "聊天与社交",
    ["TOGGLE_CAT_AUDIO"] = "音效",
    ["TOGGLE_CAT_GRAPHICS"] = "画面",
    ["TOGGLE_CAT_NETWORK"] = "网络",

    ["TOGGLE_NAME_autoLootDefault"] = "自动拾取",
    ["TOGGLE_NAME_autoSelfCast"] = "自动对自己施法",
    ["TOGGLE_NAME_autoDismount"] = "自动下坐骑",
    ["TOGGLE_NAME_autoDismountFlying"] = "飞行中自动下坐骑",
    ["TOGGLE_NAME_autoStand"] = "自动起身",
    ["TOGGLE_NAME_autoUnshift"] = "自动解除形态",
    ["TOGGLE_NAME_assistAttack"] = "协助攻击",
    ["TOGGLE_NAME_ActionButtonUseKeyDown"] = "按下时触发动作按钮",
    ["TOGGLE_NAME_deselectOnClick"] = "点击空地取消目标",
    ["TOGGLE_NAME_stopAutoAttackOnTargetChange"] = "切换目标时停止自动攻击",
    ["TOGGLE_NAME_lootUnderMouse"] = "在鼠标处打开拾取窗口",
    ["TOGGLE_NAME_lootLeftmostBag"] = "拾取到最左侧背包",
    ["TOGGLE_NAME_interactOnLeftClick"] = "左键交互",
    ["TOGGLE_NAME_autointeract"] = "自动交互",
    ["TOGGLE_NAME_autoClearAFK"] = "自动取消暂离状态",

    ["TOGGLE_NAME_countdownForCooldowns"] = "冷却倒计时",
    ["TOGGLE_NAME_displaySpellActivationOverlays"] = "法术触发光效",
    ["TOGGLE_NAME_alwaysShowActionBars"] = "始终显示动作条",
    ["TOGGLE_NAME_lockActionBars"] = "锁定动作条",
    ["TOGGLE_NAME_bottomLeftActionBar"] = "左下动作条",
    ["TOGGLE_NAME_bottomRightActionBar"] = "右下动作条",
    ["TOGGLE_NAME_rightActionBar"] = "右侧动作条",
    ["TOGGLE_NAME_rightTwoActionBar"] = "右侧动作条 2",
    ["TOGGLE_NAME_displayFreeBagSlots"] = "显示背包空格数",
    ["TOGGLE_NAME_buffDurations"] = "显示增益持续时间",
    ["TOGGLE_NAME_showTargetOfTarget"] = "显示目标的目标",
    ["TOGGLE_NAME_showTargetCastbar"] = "显示目标施法条",
    ["TOGGLE_NAME_fullSizeFocusFrame"] = "全尺寸焦点框体",
    ["TOGGLE_NAME_breakUpLargeNumbers"] = "格式化大数字",
    ["TOGGLE_NAME_alwaysCompareItems"] = "始终比较物品",
    ["TOGGLE_NAME_missingTransmogSourceInItemTooltips"] = "缺失的幻化来源",
    ["TOGGLE_NAME_autoQuestWatch"] = "自动追踪任务",
    ["TOGGLE_NAME_autoQuestProgress"] = "任务进度弹窗",
    ["TOGGLE_NAME_mapFade"] = "移动时地图淡出",
    ["TOGGLE_NAME_rotateMinimap"] = "旋转小地图",
    ["TOGGLE_NAME_useUiScale"] = "启用自定义界面缩放",
    ["TOGGLE_NAME_uiScale"] = "界面缩放",

    ["TOGGLE_NAME_nameplateShowEnemies"] = "显示敌方姓名板",
    ["TOGGLE_NAME_nameplateShowFriends"] = "显示友方姓名板",
    ["TOGGLE_NAME_nameplateShowSelf"] = "显示个人姓名板",
    ["TOGGLE_NAME_nameplatePersonalShowAlways"] = "始终显示个人姓名板",
    ["TOGGLE_NAME_nameplatePersonalShowInCombat"] = "战斗中显示个人姓名板",
    ["TOGGLE_NAME_ShowClassColorInNameplate"] = "敌方姓名板按职业着色",
    ["TOGGLE_NAME_ShowClassColorInFriendlyNameplate"] = "友方姓名板按职业着色",
    ["TOGGLE_NAME_ShowNamePlateLoseAggroFlash"] = "失去仇恨闪烁提示",
    ["TOGGLE_NAME_namePlateEnemyClickThrough"] = "敌方姓名板可穿透点击",
    ["TOGGLE_NAME_namePlateFriendlyClickThrough"] = "友方姓名板可穿透点击",
    ["TOGGLE_NAME_nameplateMaxDistance"] = "姓名板可见距离",
    ["TOGGLE_NAME_nameplateGlobalScale"] = "姓名板全局缩放",
    ["TOGGLE_NAME_namePlateEnemySize"] = "敌方姓名板大小",
    ["TOGGLE_NAME_namePlateFriendlySize"] = "友方姓名板大小",

    ["TOGGLE_NAME_enableFloatingCombatText"] = "浮动战斗文字",
    ["TOGGLE_NAME_enableCombatText"] = "默认战斗文字",
    ["TOGGLE_NAME_fctCombatState"] = "战斗状态文字",
    ["TOGGLE_NAME_floatingCombatTextCombatDamage"] = "伤害数字",
    ["TOGGLE_NAME_floatingCombatTextCombatHealing"] = "治疗数字",
    ["TOGGLE_NAME_floatingCombatTextCombatState"] = "进入/脱离战斗文字",
    ["TOGGLE_NAME_floatingCombatTextAuras"] = "增益/减益变化文字",
    ["TOGGLE_NAME_floatingCombatTextDodgeParryMiss"] = "躲闪/招架/未命中文字",
    ["TOGGLE_NAME_floatingCombatTextHonorGains"] = "荣誉获取",
    ["TOGGLE_NAME_floatingCombatTextRepChanges"] = "声望变化",
    ["TOGGLE_NAME_floatingCombatTextEnergyGains"] = "能量/法力获取",
    ["TOGGLE_NAME_floatingCombatTextComboPoints"] = "连击点获取",
    ["TOGGLE_NAME_floatingCombatTextReactives"] = "触发反应技能",
    ["TOGGLE_NAME_floatingCombatTextPetMeleeDamage"] = "宠物近战伤害",

    ["TOGGLE_NAME_cameraBobbing"] = "镜头晃动",
    ["TOGGLE_NAME_cameraWaterCollision"] = "镜头水面碰撞",
    ["TOGGLE_NAME_flightAngleLookAhead"] = "飞行角度前瞻",
    ["TOGGLE_NAME_cameraDynamicPitch"] = "动态镜头俯仰",
    ["TOGGLE_NAME_cameraDistanceMaxZoomFactor"] = "镜头最大拉远距离",
    ["TOGGLE_NAME_cameraYawMoveSpeed"] = "镜头水平转动速度",
    ["TOGGLE_NAME_cameraPitchMoveSpeed"] = "镜头垂直俯仰速度",
    ["TOGGLE_NAME_cameraZoomSpeed"] = "镜头缩放速度",

    ["TOGGLE_NAME_chatBubbles"] = "对话气泡（/说）",
    ["TOGGLE_NAME_chatBubblesParty"] = "对话气泡（小队）",
    ["TOGGLE_NAME_colorChatNamesByClass"] = "聊天中按职业着色名字",
    ["TOGGLE_NAME_blockTrades"] = "屏蔽交易请求",
    ["TOGGLE_NAME_blockChannelInvites"] = "屏蔽频道邀请",
    ["TOGGLE_NAME_guildMemberNotify"] = "公会登录提示",
    ["TOGGLE_NAME_removeChatDelay"] = "移除聊天延迟",
    ["TOGGLE_NAME_chatMouseScroll"] = "鼠标滚轮滚动聊天",
    ["TOGGLE_NAME_profanityFilter"] = "脏话过滤",
    ["TOGGLE_NAME_chatStyle"] = "聊天样式",

    ["TOGGLE_NAME_Sound_EnableAllSound"] = "全部声音",
    ["TOGGLE_NAME_Sound_EnableMusic"] = "音乐",
    ["TOGGLE_NAME_Sound_EnableSFX"] = "音效",
    ["TOGGLE_NAME_Sound_EnableDialog"] = "对话/语音",
    ["TOGGLE_NAME_Sound_EnableAmbience"] = "环境音",
    ["TOGGLE_NAME_Sound_EnablePetSounds"] = "宠物声音",
    ["TOGGLE_NAME_FootstepSounds"] = "脚步声",
    ["TOGGLE_NAME_Sound_MasterVolume"] = "主音量",
    ["TOGGLE_NAME_Sound_MusicVolume"] = "音乐音量",
    ["TOGGLE_NAME_Sound_SFXVolume"] = "音效音量",

    ["TOGGLE_NAME_ffxDeath"] = "死亡画面效果",
    ["TOGGLE_NAME_ffxGlow"] = "泛光/光晕效果",
    ["TOGGLE_NAME_ffxNether"] = "虚空视觉效果",
    ["TOGGLE_NAME_emphasizeMySpellEffects"] = "强调我的法术效果",
    ["TOGGLE_NAME_doNotFlashLowHealthWarning"] = "禁用低血量闪烁",
    ["TOGGLE_NAME_hdPlayerModels"] = "高清玩家模型",
    ["TOGGLE_NAME_findYourselfAnywhere"] = "角色高亮",
    ["TOGGLE_NAME_gxVSync"] = "垂直同步",
    ["TOGGLE_NAME_gxTripleBuffer"] = "三重缓冲",
    ["TOGGLE_NAME_particleDensity"] = "粒子密度",
    ["TOGGLE_NAME_maxFPS"] = "最大帧数（前台）",
    ["TOGGLE_NAME_maxFPSBk"] = "最大帧数（后台）",
    ["TOGGLE_NAME_gxMaxFrameLatency"] = "最大帧延迟",
    ["TOGGLE_NAME_RenderScale"] = "渲染缩放",
    ["TOGGLE_NAME_graphicsQuality"] = "画质预设",
    ["TOGGLE_NAME_ffxAntiAliasingMode"] = "抗锯齿模式",
    ["TOGGLE_NAME_colorblindMode"] = "色盲模式",

    ["TOGGLE_NAME_disableServerNagle"] = "禁用 Nagle 算法",
    ["TOGGLE_NAME_gxFixLag"] = "修复输入延迟",
    ["TOGGLE_NAME_reducedLagTolerance"] = "降低延迟容差",
    ["TOGGLE_NAME_SpellQueueWindow"] = "法术队列窗口",

    ["TOGGLE_DESC_autoLootDefault"] = "自动拾取所有战利品，无需逐个点击。",
    ["TOGGLE_DESC_autoSelfCast"] = "当你没有选择目标时，将有益法术施放在自己身上。",
    ["TOGGLE_DESC_autoDismount"] = "当你尝试采集、与 NPC 对话或进入战斗时，自动从坐骑上下来。",
    ["TOGGLE_DESC_autoDismountFlying"] = "即使在飞行中也自动下坐骑。警告：你会摔落！",
    ["TOGGLE_DESC_autoStand"] = "坐下时若尝试移动或行动，则自动起身。",
    ["TOGGLE_DESC_autoUnshift"] = "当你使用需要解除形态的技能时，自动离开形态或变形。",
    ["TOGGLE_DESC_assistAttack"] = "当你协助友方目标时，自动开始攻击其目标。",
    ["TOGGLE_DESC_ActionButtonUseKeyDown"] = "开启时：按下按键即施放法术。关闭时：松开按键才施放法术，可先查看技能距离。",
    ["TOGGLE_DESC_deselectOnClick"] = "点击空地时清除你的目标。",
    ["TOGGLE_DESC_stopAutoAttackOnTargetChange"] = "当你切换到新目标时停止自动攻击。",
    ["TOGGLE_DESC_lootUnderMouse"] = "在鼠标光标处打开拾取窗口，而非固定位置。",
    ["TOGGLE_DESC_lootLeftmostBag"] = "将拾取的物品放入最左侧背包，而非最右侧。",
    ["TOGGLE_DESC_interactOnLeftClick"] = "左键点击 NPC 和物体进行交互，而非右键。",
    ["TOGGLE_DESC_autointeract"] = "右键点击 NPC 会自动与其对话或拾取。",
    ["TOGGLE_DESC_autoClearAFK"] = "当你移动或进行任何操作时，自动取消暂离状态。",

    ["TOGGLE_DESC_countdownForCooldowns"] = "在冷却中的技能图标中央显示倒计时数字。",
    ["TOGGLE_DESC_displaySpellActivationOverlays"] = "当触发效果激活时，在技能上显示发光边框，例如瞬发触发效果。",
    ["TOGGLE_DESC_alwaysShowActionBars"] = "即使为空也保持动作条可见，防止动作条隐藏。",
    ["TOGGLE_DESC_lockActionBars"] = "防止意外将技能从动作条上拖出。",
    ["TOGGLE_DESC_bottomLeftActionBar"] = "在主动作条上方左侧显示额外动作条。",
    ["TOGGLE_DESC_bottomRightActionBar"] = "在主动作条上方右侧显示额外动作条。",
    ["TOGGLE_DESC_rightActionBar"] = "在屏幕右侧显示竖向动作条。",
    ["TOGGLE_DESC_rightTwoActionBar"] = "在屏幕右侧显示第二条竖向动作条。",
    ["TOGGLE_DESC_displayFreeBagSlots"] = "在背包栏上显示空背包格数。",
    ["TOGGLE_DESC_buffDurations"] = "以倒计时数字显示你增益的剩余时间。",
    ["TOGGLE_DESC_showTargetOfTarget"] = "显示你目标正在选中谁。对坦克和治疗很有用。",
    ["TOGGLE_DESC_showTargetCastbar"] = "为你当前的目标显示施法条，以便看清其正在施放什么。",
    ["TOGGLE_DESC_fullSizeFocusFrame"] = "为你的焦点目标使用全尺寸单位框体，而非小框体。",
    ["TOGGLE_DESC_breakUpLargeNumbers"] = "用千位分隔符显示大数字，例如 1,000,000 而非 1000000。",
    ["TOGGLE_DESC_alwaysCompareItems"] = "悬停于装备时自动显示物品比较提示。无需按住 Shift 键。",
    ["TOGGLE_DESC_missingTransmogSourceInItemTooltips"] = "在物品提示中显示你是否已拥有该外观，但并非来自这一具体物品来源。",
    ["TOGGLE_DESC_autoQuestWatch"] = "自动将新任务添加到屏幕右侧的任务追踪器。",
    ["TOGGLE_DESC_autoQuestProgress"] = "当你的任务取得进展时显示弹窗通知。",
    ["TOGGLE_DESC_mapFade"] = "移动时让地图变透明，以便仍能看到游戏世界。",
    ["TOGGLE_DESC_rotateMinimap"] = "小地图像指南针一样随你转向而旋转，而非固定为正北朝上。",
    ["TOGGLE_DESC_useUiScale"] = "允许自定义界面缩放。启用此项即可使用界面缩放滑块。",
    ["TOGGLE_DESC_uiScale"] = "用户界面的整体大小。需要启用自定义界面缩放。",

    ["TOGGLE_DESC_nameplateShowEnemies"] = "在敌方单位上方显示带生命条的姓名板。",
    ["TOGGLE_DESC_nameplateShowFriends"] = "在友方单位上方显示带生命条的姓名板。",
    ["TOGGLE_DESC_nameplateShowSelf"] = "在你的角色上方将个人资源条显示为姓名板。",
    ["TOGGLE_DESC_nameplatePersonalShowAlways"] = "始终显示你的个人资源条姓名板，即使脱离战斗。",
    ["TOGGLE_DESC_nameplatePersonalShowInCombat"] = "仅在战斗中显示你的个人资源条姓名板。",
    ["TOGGLE_DESC_ShowClassColorInNameplate"] = "在 PvP 中按职业为敌方姓名板着色。",
    ["TOGGLE_DESC_ShowClassColorInFriendlyNameplate"] = "按职业为友方姓名板着色。",
    ["TOGGLE_DESC_ShowNamePlateLoseAggroFlash"] = "作为坦克失去对敌人的威胁时，使姓名板闪烁。",
    ["TOGGLE_DESC_namePlateEnemyClickThrough"] = "可穿透点击敌方姓名板。你能看到生命条，但无法点击选取目标。",
    ["TOGGLE_DESC_namePlateFriendlyClickThrough"] = "可穿透点击友方姓名板。你能看到生命条，但无法点击选取友方。",
    ["TOGGLE_DESC_nameplateMaxDistance"] = "姓名板可见的最大距离（码）。副本内最大为 60。",
    ["TOGGLE_DESC_nameplateGlobalScale"] = "所有姓名板的主缩放倍数。在其他缩放设置之后生效。",
    ["TOGGLE_DESC_namePlateEnemySize"] = "敌方姓名板的尺寸倍数。越大在战斗中越易看清。",
    ["TOGGLE_DESC_namePlateFriendlySize"] = "友方玩家姓名板的尺寸倍数。",

    ["TOGGLE_DESC_enableFloatingCombatText"] = "显示从敌人和盟友身上升起的浮动伤害和治疗数字。",
    ["TOGGLE_DESC_enableCombatText"] = "在你角色附近的默认战斗文字区域显示伤害和治疗数字。",
    ["TOGGLE_DESC_fctCombatState"] = "使用默认战斗文字系统显示“你已进入战斗！”等浮动文字通知。",
    ["TOGGLE_DESC_floatingCombatTextCombatDamage"] = "以浮动数字显示你造成的伤害。",
    ["TOGGLE_DESC_floatingCombatTextCombatHealing"] = "以浮动绿色数字显示你受到的治疗。",
    ["TOGGLE_DESC_floatingCombatTextCombatState"] = "以浮动文字消息显示进入和脱离战斗。",
    ["TOGGLE_DESC_floatingCombatTextAuras"] = "以浮动文字显示你获得或失去增益和减益。",
    ["TOGGLE_DESC_floatingCombatTextDodgeParryMiss"] = "以浮动文字显示躲闪、招架和未命中的结果。",
    ["TOGGLE_DESC_floatingCombatTextHonorGains"] = "在 PvP 中以浮动文字显示荣誉点获取。",
    ["TOGGLE_DESC_floatingCombatTextRepChanges"] = "以浮动文字显示声望的获取和损失。",
    ["TOGGLE_DESC_floatingCombatTextEnergyGains"] = "以浮动文字显示能量、怒气和法力的获取。",
    ["TOGGLE_DESC_floatingCombatTextComboPoints"] = "以浮动文字显示连击点的获取。",
    ["TOGGLE_DESC_floatingCombatTextReactives"] = "以浮动文字显示反应技能的触发。",
    ["TOGGLE_DESC_floatingCombatTextPetMeleeDamage"] = "以浮动数字显示你宠物的近战伤害。",

    ["TOGGLE_DESC_cameraBobbing"] = "行走和奔跑时镜头会轻微上下晃动。更有沉浸感，但可能引起晕动症。",
    ["TOGGLE_DESC_cameraWaterCollision"] = "当你的角色在水面之上时，防止镜头沉入水下。",
    ["TOGGLE_DESC_flightAngleLookAhead"] = "你的飞行坐骑会倾斜以显示你的前进方向，更具真实感。",
    ["TOGGLE_DESC_cameraDynamicPitch"] = "镜头会根据你的移动方向自动倾斜。这就是动态镜头（Action Cam）功能。",
    ["TOGGLE_DESC_cameraDistanceMaxZoomFactor"] = "镜头最大拉远距离的倍数。数值越高可拉得越远。",
    ["TOGGLE_DESC_cameraYawMoveSpeed"] = "镜头左右旋转的速度。",
    ["TOGGLE_DESC_cameraPitchMoveSpeed"] = "镜头上下俯仰的速度。",
    ["TOGGLE_DESC_cameraZoomSpeed"] = "使用滚轮拉近和拉远镜头的速度。",

    ["TOGGLE_DESC_chatBubbles"] = "当角色使用 /说 或 /喊 时，在其头顶显示对话气泡。",
    ["TOGGLE_DESC_chatBubblesParty"] = "在角色头顶显示小队和团队聊天消息的对话气泡。",
    ["TOGGLE_DESC_colorChatNamesByClass"] = "在聊天中按玩家职业为其名字着色。",
    ["TOGGLE_DESC_blockTrades"] = "阻止其他玩家与你开启交易窗口。",
    ["TOGGLE_DESC_blockChannelInvites"] = "阻止其他玩家邀请你加入聊天频道。",
    ["TOGGLE_DESC_guildMemberNotify"] = "当公会成员上线或下线时在聊天中显示消息。",
    ["TOGGLE_DESC_removeChatDelay"] = "移除发送聊天消息之间的防刷屏延迟。",
    ["TOGGLE_DESC_chatMouseScroll"] = "使用鼠标滚轮浏览聊天记录。",
    ["TOGGLE_DESC_profanityFilter"] = "在聊天中用符号替换脏话。",
    ["TOGGLE_DESC_chatStyle"] = "经典样式使用独立聊天窗口。现代样式使用标签式聊天。",

    ["TOGGLE_DESC_Sound_EnableAllSound"] = "所有游戏音频的总开关。关闭后将静音一切。",
    ["TOGGLE_DESC_Sound_EnableMusic"] = "在区域中和事件期间播放背景音乐。",
    ["TOGGLE_DESC_Sound_EnableSFX"] = "播放音效，包括技能、战斗声音和界面点击声。",
    ["TOGGLE_DESC_Sound_EnableDialog"] = "播放 NPC 配音和任务对话音频。",
    ["TOGGLE_DESC_Sound_EnableAmbience"] = "播放环境背景声音，如风、鸟和水。",
    ["TOGGLE_DESC_Sound_EnablePetSounds"] = "播放你宠物的声音，如咆哮和移动声。",
    ["TOGGLE_DESC_FootstepSounds"] = "在行走和奔跑时播放脚步声。",
    ["TOGGLE_DESC_Sound_MasterVolume"] = "游戏总音量。影响所有其他音量滑块。",
    ["TOGGLE_DESC_Sound_MusicVolume"] = "背景音乐的音量。",
    ["TOGGLE_DESC_Sound_SFXVolume"] = "音效的音量，包括技能和战斗。",

    ["TOGGLE_DESC_ffxDeath"] = "当你死亡时显示灰度去色的画面效果。",
    ["TOGGLE_DESC_ffxGlow"] = "启用明亮物体周围柔和的泛光光晕效果。",
    ["TOGGLE_DESC_ffxNether"] = "在虚空和虚空区域启用特殊视觉效果。",
    ["TOGGLE_DESC_emphasizeMySpellEffects"] = "使你自己的法术效果相比其他玩家的更明显。",
    ["TOGGLE_DESC_doNotFlashLowHealthWarning"] = "禁用生命值危急时出现的红色画面闪烁。",
    ["TOGGLE_DESC_hdPlayerModels"] = "使用高清玩家角色模型。更好看，但占用更多内存。",
    ["TOGGLE_DESC_findYourselfAnywhere"] = "在你的角色下方显示一个高亮光环，让你在人群中总能找到自己。",
    ["TOGGLE_DESC_gxVSync"] = "将帧数限制为你显示器的刷新率。可防止画面撕裂，但会增加少量输入延迟。",
    ["TOGGLE_DESC_gxTripleBuffer"] = "三重缓冲以获得更平滑的帧节奏。会增加少量输入延迟。",
    ["TOGGLE_DESC_particleDensity"] = "同时出现的法术效果和粒子数量。数值越低，在繁忙团队中越能提升帧数。",
    ["TOGGLE_DESC_maxFPS"] = "游戏窗口处于活动状态时的最大帧数。设为 0 表示不限制。",
    ["TOGGLE_DESC_maxFPSBk"] = "游戏窗口处于后台时的最大帧数。数值越低，切出时越省电。",
    ["TOGGLE_DESC_gxMaxFrameLatency"] = "排队等待渲染的最大帧数。数值越低输入延迟越小，越高输出越平滑。",
    ["TOGGLE_DESC_RenderScale"] = "内部分辨率倍数。高于 1.0 会超采样以获得更锐利的画面，低于 1.0 可提升性能。",
    ["TOGGLE_DESC_graphicsQuality"] = "画质主预设。更改此项将自动调整所有其他画面设置。",
    ["TOGGLE_DESC_ffxAntiAliasingMode"] = "平滑物体的锯齿边缘。更高模式画质更好，但占用更多 GPU 资源。",
    ["TOGGLE_DESC_colorblindMode"] = "启用色盲友好的色彩调整。选择符合你色觉缺陷类型的模式。",

    ["TOGGLE_DESC_disableServerNagle"] = "通过禁用数据包合并降低网络延迟。可能略微增加带宽占用。",
    ["TOGGLE_DESC_gxFixLag"] = "通过修改渲染队列，在某些系统上降低鼠标光标的输入延迟。",
    ["TOGGLE_DESC_reducedLagTolerance"] = "针对低延迟连接优化网络性能。可能影响法术排队行为。",
    ["TOGGLE_DESC_SpellQueueWindow"] = "在当前法术结束前，你可以提前排入下一个法术的毫秒数。数值越高，对时机越宽容。",

    ["TOGGLE_OPT_chatStyle_classic"] = "经典",
    ["TOGGLE_OPT_chatStyle_im"] = "现代",
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
    ["TOGGLE_OPT_ffxAntiAliasingMode_0"] = "关",
    ["TOGGLE_OPT_ffxAntiAliasingMode_1"] = "CMAA",
    ["TOGGLE_OPT_ffxAntiAliasingMode_2"] = "FXAA 低",
    ["TOGGLE_OPT_ffxAntiAliasingMode_3"] = "FXAA 高",
    ["TOGGLE_OPT_colorblindMode_0"] = "关",
    ["TOGGLE_OPT_colorblindMode_1"] = "红色盲",
    ["TOGGLE_OPT_colorblindMode_2"] = "绿色盲",
    ["TOGGLE_OPT_colorblindMode_3"] = "蓝色盲",

    ["BINDING_HEADER_ONEWOW_QOL"] = "|cFF00FF00OneWoW|r QoL",
    ["BINDING_NAME_QUESTITEM_1"] = "任务物品 1",
    ["BINDING_NAME_QUESTITEM_2"] = "任务物品 2",
    ["BINDING_NAME_QUESTITEM_3"] = "任务物品 3",
    ["BINDING_NAME_QUESTITEM_4"] = "任务物品 4",
    ["BINDING_NAME_BAGITEM_1"] = "背包物品 1",
    ["BINDING_NAME_BAGITEM_2"] = "背包物品 2",
    ["BINDING_NAME_BAGITEM_3"] = "背包物品 3",
    ["BINDING_NAME_BAGITEM_4"] = "背包物品 4",
    ["BINDING_NAME_COPY_TEXT"] = "复制文本",
})
