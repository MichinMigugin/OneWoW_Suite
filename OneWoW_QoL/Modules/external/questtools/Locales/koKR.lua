local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — koKR (replaces TEST placeholder), pending native review.
OneWoW.Locale:Register(M._scope, "koKR", {

    ["QUESTTOOLS_TITLE"] = "퀘스트 도구",
    ["QUESTTOOLS_DESC"] = "퀘스트 수락, 완료 보고, 보상 강조, 선택적 퀘스트 표시 대화를 자동화합니다. 퀘스트 또는 대화 창을 열 때 Shift를 누르면 자동 수락이나 자동 대화를 건너뜁니다.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "퀘스트 자동 수락",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "퀘스트 창이 나타나면 퀘스트를 자동으로 수락합니다. 창을 열 때 Shift를 누르면 자동 수락을 건너뜁니다.",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "퀘스트 자동 완료 보고",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "모든 요구 조건을 충족하면 퀘스트를 자동으로 완료하고 보고합니다. 여러 보상이 있으면 선택을 기다립니다.",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "최고 보상 강조",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "상인 판매 가치가 가장 높은 퀘스트 보상 아이템에 금화 아이콘을 표시합니다.",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "자동 대화 (퀘스트 표시 줄)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "퀘스트 표시(QuestLabelPrepend)로 지정된 대화 옵션, 즉 UI가 퀘스트 스타일 라벨로 표시하는 것과 같은 줄을 자동으로 선택합니다. 여러 개가 해당되면 보이는 줄 텍스트로 결정합니다. 대화를 열 때 Shift를 누르면 건너뜁니다. 클라이언트에 C_GossipInfo와 QuestLabelPrepend(FlagsUtil / Enum.GossipOptionRecFlags) 지원이 필요합니다.",
})
