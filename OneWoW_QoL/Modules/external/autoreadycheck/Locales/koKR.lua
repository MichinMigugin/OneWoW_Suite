local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["AUTOREADYCHECK_TITLE"] = "준비 확인 자동 수락",
    ["AUTOREADYCHECK_DESC"] = "그룹에서 준비 확인이 호출되면 준비 상태를 자동으로 확인합니다.",
    ["AUTOREADYCHECK_TOGGLE_DEAD"] = "죽었을 때 건너뛰기",
    ["AUTOREADYCHECK_TOGGLE_DEAD_DESC"] = "죽었거나 유령 상태일 때는 자동으로 수락하지 않아, 그룹이 당신이 시작할 준비가 안 됐음을 알 수 있게 합니다.",
})
