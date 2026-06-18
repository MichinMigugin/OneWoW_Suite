local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — zhTW (Taiwan terms), pending native review.
OneWoW.Locale:Register(M._scope, "zhTW", {

    ["QUESTTOOLS_TITLE"] = "任務工具",
    ["QUESTTOOLS_DESC"] = "自動完成任務接受、繳交、獎勵突顯以及可選的任務標記對話。在開啟任務或對話視窗時按住 Shift 可跳過自動接受或自動對話。",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "自動接受任務",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "當任務對話框出現時自動接受任務。開啟對話框時按住 Shift 可跳過自動接受。",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "自動繳交任務",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "當你滿足所有要求時自動完成並繳交任務。如果有多個獎勵可選，則等待你選擇。",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "突顯最佳獎勵",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "在商人售價最高的任務獎勵物品上顯示一個金幣圖示。",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "自動對話（任務標記行）",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "自動選擇被標記為任務標籤（QuestLabelPrepend）的對話選項，即介面以任務樣式標籤顯示的相同行。如果有多項符合，則根據可見的行文字來決定。開啟對話時按住 Shift 可跳過。需要你的客戶端支援 C_GossipInfo 和 QuestLabelPrepend（FlagsUtil / Enum.GossipOptionRecFlags）。",
})
