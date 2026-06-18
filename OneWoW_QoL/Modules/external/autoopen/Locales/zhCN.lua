local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted (Phase 4) — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AUTOOPEN_TITLE"] = "自动打开",
    ["AUTOOPEN_DESC"] = "当背包、箱子和其他容器物品出现在你的物品栏中时自动打开它们。在银行、邮箱或商人处不会打开物品。你尚无法打开的物品（上锁的保险箱、等级/职业/专业不符，或栏位忙碌时）会被自动跳过。",
    ["AUTOOPEN_OPENING"] = "正在自动打开：%s",
    ["AUTOOPEN_BLACKLIST_DESC"] = "添加物品以防止自动打开将其打开。",
    ["AUTOOPEN_BLACKLIST_ADD"] = "添加物品 ID：",
    ["AUTOOPEN_BLACKLIST_EMPTY"] = "黑名单中没有物品",
    ["AUTOOPEN_BLACKLIST_REMOVED"] = "已从黑名单移除：%s",
    ["AUTOOPEN_BLACKLIST_ADDED"] = "已添加到黑名单：%s",
    ["AUTOOPEN_BLACKLIST_CLEARED"] = "黑名单已清除。",
})
