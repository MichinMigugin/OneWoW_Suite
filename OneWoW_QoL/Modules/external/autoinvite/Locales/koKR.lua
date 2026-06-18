local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["AUTOINVITE_TITLE"] = "파티 초대 자동 수락",
    ["AUTOINVITE_DESC"] = "신뢰하는 사람의 파티 초대를 자동으로 수락합니다. 아래에서 허용할 출처를 선택하세요.",
    ["AUTOINVITE_TOGGLE_FRIENDS"] = "친구로부터",
    ["AUTOINVITE_TOGGLE_FRIENDS_DESC"] = "WoW 친구와 Battle.net 친구의 초대를 수락합니다.",
    ["AUTOINVITE_TOGGLE_GUILD"] = "길드로부터",
    ["AUTOINVITE_TOGGLE_GUILD_DESC"] = "길드원의 초대를 수락합니다.",
    ["AUTOINVITE_TOGGLE_ALL"] = "누구로부터든",
    ["AUTOINVITE_TOGGLE_ALL_DESC"] = "보낸 사람에 관계없이 모든 파티 초대를 수락합니다. 활성화하면 다른 설정보다 우선합니다.",
})
