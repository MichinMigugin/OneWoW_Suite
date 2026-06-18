local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["AUTODELETE_TITLE"] = "자동 삭제",
    ["AUTODELETE_DESC"] = "아이템을 파괴할 때 삭제를 입력하지 않아도 됩니다. 아무것도 입력하지 않아도 확인 버튼이 즉시 사용 가능해집니다.",
    ["AUTODELETE_TOGGLE_SKIP"] = "입력 확인 건너뛰기",
    ["AUTODELETE_TOGGLE_SKIP_DESC"] = "삭제를 입력하지 않아도 삭제 버튼을 자동으로 활성화합니다.",
    ["AUTODELETE_TOGGLE_LINK"] = "아이템 링크 표시",
    ["AUTODELETE_TOGGLE_LINK_DESC"] = "확인 팝업에 아이템 링크를 표시하여 무엇을 삭제하려는지 볼 수 있습니다.",
})
