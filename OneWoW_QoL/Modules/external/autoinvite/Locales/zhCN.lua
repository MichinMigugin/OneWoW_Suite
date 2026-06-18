local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhCN, pending native review.
OneWoW.Locale:Register(M._scope, "zhCN", {

    ["AUTOINVITE_TITLE"] = "自动接受组队邀请",
    ["AUTOINVITE_DESC"] = "自动接受来自你信任的人的组队邀请。在下方选择允许哪些来源。",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "来自好友",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "接受 WoW 好友和战网好友的邀请。",
    ["AUTOINVITE_TOGGLE_GUILD"] = "来自公会",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "接受你公会成员的邀请。",
    ["AUTOINVITE_TOGGLE_ALL"] = "来自任何人",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "接受任何组队邀请，无论发送者是谁。启用时会覆盖其他开关。",
})
