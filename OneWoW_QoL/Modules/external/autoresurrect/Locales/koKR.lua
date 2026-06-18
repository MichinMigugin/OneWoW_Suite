local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["AUTORESURRECT_TITLE"] = "부활 자동 수락",
    ["AUTORESURRECT_DESC"] = "누군가 당신에게 부활을 시전하면 부활 요청을 자동으로 수락합니다. 전투 중에는 건너뜁니다.",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE"] = "인스턴스에서는 수락 안 함",
    ["AUTORESURRECT_TOGGLE_SKIP_INSTANCE_DESC"] = "던전, 공격대, 전장 또는 투기장 안에 있을 때는 자동 수락을 건너뜁니다. 부활할 적절한 순간을 기다리고 싶을 때 유용합니다.",
})
