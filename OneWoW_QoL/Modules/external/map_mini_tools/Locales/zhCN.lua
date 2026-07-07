local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["MMSKIN_TITLE"] = "地图（小）工具",
    ["MMSKIN_DESC"] = "自定义你的小地图区域：形状、边框、区域文字、时钟、点击动作、缩放控制、元素显示等。支持主题且完全可配置。",

    ["MMSKIN_GROUP_SHAPE"] = "形状与外观",
    ["MMSKIN_GROUP_INFO"] = "信息覆盖层",
    ["MMSKIN_GROUP_ZOOM"] = "缩放与滚动",
    ["MMSKIN_GROUP_CLICKS"] = "点击动作",
    ["MMSKIN_GROUP_ELEMENTS"] = "元素显示",
    ["MMSKIN_GROUP_EXTRAS"] = "额外",
    ["MMSKIN_GROUP_COMPAT"] = "兼容性",

    ["MMSKIN_SQUARE"] = "方形小地图",
    ["MMSKIN_SQUARE_DESC"] = "将小地图形状从圆形改为方形。禁用需要重载界面。",
    ["MMSKIN_BORDER"] = "显示边框",
    ["MMSKIN_BORDER_DESC"] = "在小地图周围显示彩色边框。",
    ["MMSKIN_CLASS_BORDER"] = "职业颜色边框",
    ["MMSKIN_CLASS_BORDER_DESC"] = "使用你的职业颜色作为小地图边框，而非主题颜色。",
    ["MMSKIN_UNLOCK"] = "解锁小地图",
    ["MMSKIN_UNLOCK_DESC"] = "将小地图从默认位置分离，使其可自由拖动。",
    ["MMSKIN_LOCK_POS"] = "锁定位置",
    ["MMSKIN_LOCK_POS_DESC"] = "阻止拖动小地图，同时将其保持在当前位置。",

    ["MMSKIN_ZONE_TEXT"] = "区域文字",
    ["MMSKIN_ZONE_TEXT_DESC"] = "在小地图上方显示当前区域名称，并采用 PvP 类型着色。",
    ["MMSKIN_CLOCK"] = "时钟",
    ["MMSKIN_CLOCK_DESC"] = "在小地图下方显示时钟。工具提示显示服务器/本地时间以及每日/每周重置计时器。",
    ["MMSKIN_CLASS_CLOCK_COLOR"] = "职业颜色时钟",
    ["MMSKIN_CLASS_CLOCK_COLOR_DESC"] = "使用你的职业颜色作为时钟文字颜色，而非主题颜色。",
    ["MMSKIN_ZONE_ALIGN_LABEL"] = "区域名称对齐",
    ["MMSKIN_CLOCK_ALIGN_LABEL"] = "时钟对齐",
    ["MMSKIN_ALIGN_LEFT"] = "左对齐",
    ["MMSKIN_ALIGN_CENTER"] = "居中",
    ["MMSKIN_ALIGN_RIGHT"] = "右对齐",

    ["MMSKIN_ZONE_CLOCK_INSIDE"] = "区域与时钟置于小地图内",
    ["MMSKIN_ZONE_CLOCK_INSIDE_DESC"] = "将区域名称和时钟固定在小地图的内边缘，而非其上方和下方。",

    ["MMSKIN_ZONE_CLOCK_DRAG"] = "拖动区域与时钟（按住 Shift）",
    ["MMSKIN_ZONE_CLOCK_DRAG_DESC"] = "拖动区域名称或时钟以在屏幕上移动它们时，必须按住 Shift 键。位置会被保存。松开 Shift 进行正常点击（时钟仍会打开时间管理器）。",

    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM"] = "将区域与时钟锚定到小地图",
    ["MMSKIN_ZONE_CLOCK_ANCHOR_MM_DESC"] = "启用拖动时，将区域名称和时钟锚定到小地图，使其随小地图移动而一同移动。若将它们叠放在一起，则作为整体移动。",

    ["MMSKIN_WHEEL_ZOOM"] = "鼠标滚轮缩放",
    ["MMSKIN_WHEEL_ZOOM_DESC"] = "使用鼠标滚轮放大和缩小小地图。",
    ["MMSKIN_AUTO_ZOOM"] = "自动缩小",
    ["MMSKIN_AUTO_ZOOM_DESC"] = "放大后自动将小地图缩小回去。",

    ["MMSKIN_CLICK_ACTIONS"] = "点击动作",
    ["MMSKIN_CLICK_ACTIONS_DESC"] = "启用小地图上的右键、中键及额外鼠标按键动作。",

    ["MMSKIN_MAIL"] = "邮件指示器",
    ["MMSKIN_MAIL_DESC"] = "在小地图上显示邮件指示器。",
    ["MMSKIN_CRAFTING"] = "制造订单",
    ["MMSKIN_CRAFTING_DESC"] = "在小地图上显示制造订单指示器。",
    ["MMSKIN_DIFFICULTY"] = "难度图标",
    ["MMSKIN_DIFFICULTY_DESC"] = "在小地图上显示副本难度图标。",

    ["MMSKIN_TRACKING"] = "追踪筛选",
    ["MMSKIN_TRACKING_DESC"] = "显示小地图追踪筛选（资源 / 草药 / 矿石 / 等下拉菜单）。关闭它会移除小地图旁的小圆环/控件。",
    ["MMSKIN_MISSIONS"] = "任务按钮",
    ["MMSKIN_MISSIONS_DESC"] = "显示资料片登陆页面 / 任务按钮。",
    ["MMSKIN_GAMETIME"] = "日历图标",
    ["MMSKIN_GAMETIME_DESC"] = "在小地图上显示日历（GameTime）按钮。",

    ["MMSKIN_PLUMBER_HIDE_BLIZZARD"] = "使用 Plumber 时隐藏重复的暴雪资料片按钮",
    ["MMSKIN_PLUMBER_HIDE_BLIZZARD_DESC"] = "当 Plumber 已加载时，保持暴雪的资料片小地图按钮隐藏，使其仅显示 Plumber 的资料片摘要控件。关闭则同时显示两者（不推荐）。",
    ["MMSKIN_PLUMBER_STATUS_ON"] = "Plumber 已加载——此选项生效。",
    ["MMSKIN_PLUMBER_STATUS_OFF"] = "Plumber 未加载——请在登录前启用此项，或在安装 Plumber 后重载。",

    ["MMSKIN_HIDE_ADDONS"] = "隐藏插件图标",
    ["MMSKIN_HIDE_ADDONS_DESC"] = "隐藏小地图插件按钮，直到你将鼠标悬停在小地图区域上。",
    ["MMSKIN_COMBAT_FADE"] = "战斗淡出",
    ["MMSKIN_COMBAT_FADE_DESC"] = "战斗期间降低小地图不透明度。",
    ["MMSKIN_PET_HIDE"] = "宠物对战时隐藏",
    ["MMSKIN_PET_HIDE_DESC"] = "在宠物对战期间隐藏小地图。",

    ["MMSKIN_SCALE_LABEL"] = "小地图区域缩放",
    ["MMSKIN_SECTION_BORDER"] = "边框设置",
    ["MMSKIN_BORDER_SIZE"] = "边框大小",
    ["MMSKIN_BORDER_RED"] = "红",
    ["MMSKIN_BORDER_GREEN"] = "绿",
    ["MMSKIN_BORDER_BLUE"] = "蓝",
    ["MMSKIN_USE_THEME_COLOR"] = "使用主题颜色",

    ["MMSKIN_ZONE_BG"] = "区域背景",
    ["MMSKIN_CLOCK_BG"] = "时钟背景",

    ["MMSKIN_AUTO_ZOOM_DELAY"] = "自动缩小延迟",
    ["MMSKIN_SHOW_ZOOM_BTNS"] = "显示缩放按钮",

    ["MMSKIN_HIDE_WM_BTN"] = "隐藏世界地图按钮",
    ["MMSKIN_HIDE_WM_BTN_DESC"] = "隐藏小地图上的小型世界地图切换按钮（你仍可使用其快捷键打开地图）。",

    ["MMSKIN_SECTION_COMBAT"] = "战斗淡出设置",
    ["MMSKIN_COMBAT_ALPHA"] = "战斗不透明度",

    ["MMSKIN_SECTION_CLICKS"] = "点击绑定设置",
    ["MMSKIN_CLICK_RIGHT"] = "右键点击",
    ["MMSKIN_CLICK_MIDDLE"] = "中键点击",
    ["MMSKIN_CLICK_BTN4"] = "按键 4",
    ["MMSKIN_CLICK_BTN5"] = "按键 5",
    ["MMSKIN_ACTION_NONE"] = "无",
    ["MMSKIN_ACTION_CALENDAR"] = "日历",
    ["MMSKIN_ACTION_TRACKING"] = "追踪",
    ["MMSKIN_ACTION_MISSIONS"] = "任务",
    ["MMSKIN_ACTION_MAP"] = "地图",
    ["MMSKIN_WORLD_MAP_BUTTON"] = "世界地图",

    ["MMSKIN_SHOW_COMPARTMENT"] = "插件挂件栏",

    ["MMSKIN_CLOCK_TT_TOGGLE"] = "点击以切换时间管理器",

    ["MMSKIN_UNCLAMP"] = "解除屏幕边缘限制",

    ["MMSKIN_ZONE_FONT_LABEL"] = "字体",
    ["MMSKIN_CLOCK_FONT_LABEL"] = "字体",
    ["MMSKIN_FONT_GLOBAL"] = "全局字体",
    ["MMSKIN_FONT_WOW_DEFAULT"] = "WoW 默认（小）",

    ["MMSKIN_SECTION_OPACITY"] = "缩放与不透明度",
    ["MMSKIN_OPACITY"] = "小地图不透明度",

    ["MMSKIN_SECTION_DEBUG"] = "开发者工具",
    ["MMSKIN_DEBUG_SHOW"] = "显示调试图标",
    ["MMSKIN_DEBUG_HIDE"] = "隐藏调试图标",
    ["MMSKIN_DEBUG_DESC"] = "强制显示所有被追踪的图标并带有彩色标签。拖动任意标签即可将该图标放置到小地图上；位置会被保存。隐藏调试可将图标返回到区域（除非小地图已分离）。当图标未被主动触发时（例如邮箱中没有邮件）很有用。",
    ["MMSKIN_DEBUG_TT_DRAG_HINT"] = "左键点击并拖动以在小地图上移动此图标。",
    ["MMSKIN_DEBUG_TT_POS_FMT"] = "已保存偏移：%.0f, %.0f",

    ["MMSKIN_RELOAD_PROMPT"] = "更改小地图形状需要重载界面。\n现在重载吗？",
})
