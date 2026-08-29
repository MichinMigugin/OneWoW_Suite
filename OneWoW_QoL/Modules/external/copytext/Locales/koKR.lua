local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["COPYTEXT_TITLE"] = "텍스트 복사",
    ["COPYTEXT_DESC"] = "툴팁이나 UI 요소의 보이는 텍스트를 클립보드로 복사합니다. /1wcopytext(또는 /1wct)를 사용하여 커서 아래에 있는 것을 복사하세요.",
    ["COPYTEXT_TOGGLE_TOOLTIPS"] = "툴팁 모드",
    ["COPYTEXT_TOGGLE_TOOLTIPS_DESC"] = "복사할 때 커서 아래의 모든 보이는 툴팁에서 텍스트를 가져옵니다.",
    ["COPYTEXT_TOGGLE_ANYTHING"] = "전체 모드",
    ["COPYTEXT_TOGGLE_ANYTHING_DESC"] = "복사할 때 툴팁뿐 아니라 커서 아래의 모든 보이는 UI 요소에서 텍스트를 가져옵니다.",
    ["COPYTEXT_TOGGLE_FAST"] = "빠른 복사",
    ["COPYTEXT_TOGGLE_FAST_DESC"] = "복사 대화 상자의 모든 텍스트를 자동으로 선택하여 클릭하지 않고 즉시 복사할 수 있습니다.",
    ["COPYTEXT_NO_TEXT"] = "커서 아래에서 텍스트를 찾을 수 없습니다.",
    ["COPYTEXT_TOOLTIP_CONTENT"] = "툴팁 내용",
    ["COPYTEXT_UI_CONTENT"] = "UI 텍스트",
})
