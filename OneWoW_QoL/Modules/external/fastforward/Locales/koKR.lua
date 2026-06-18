local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["FASTFORWARD_TITLE"] = "빨리 감기",
    ["FASTFORWARD_DESC"] = "게임 내 동영상과 시네마틱을 자동으로 건너뜁니다. 동영상이나 시네마틱이 시작될 때 아무 보조 키나 누르면 대신 시청합니다.",
    ["FASTFORWARD_TOGGLE_MOVIES"] = "동영상 건너뛰기",
    ["FASTFORWARD_TOGGLE_MOVIES_DESC"] = "게임 내 동영상이 재생되기 시작하면 자동으로 멈춥니다.",
    ["FASTFORWARD_TOGGLE_CINEMATICS"] = "시네마틱 건너뛰기",
    ["FASTFORWARD_TOGGLE_CINEMATICS_DESC"] = "게임 내 시네마틱 장면이 시작되면 자동으로 취소합니다.",
    ["FASTFORWARD_TOGGLE_INSTANCE"] = "인스턴스에서만",
    ["FASTFORWARD_TOGGLE_INSTANCE_DESC"] = "던전, 공격대 또는 기타 인스턴스 안에 있을 때만 동영상과 시네마틱을 건너뜁니다.",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE"] = "취소 불가 항목 존중",
    ["FASTFORWARD_TOGGLE_UNCANCELLABLE_DESC"] = "게임이 취소할 수 없다고 표시한 시네마틱은 건너뛰려 하지 않습니다.",
})
