local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["AUTOINVITE_TITLE"] = "自動接受組隊邀請",
    ["AUTOINVITE_DESC"] = "自動接受來自你信任的人的組隊邀請。在下方選擇允許哪些來源。",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "來自好友",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "接受 WoW 好友和戰網好友的邀請。",
    ["AUTOINVITE_TOGGLE_GUILD"] = "來自公會",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "接受你公會成員的邀請。",
    ["AUTOINVITE_TOGGLE_ALL"] = "來自任何人",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "接受任何組隊邀請，無論傳送者是誰。啟用時會覆蓋其他開關。",
})
