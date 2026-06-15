local _, ns = ...
local M = ns.ModuleRegistry:Current()

OneWoW.Locale:Register(M._scope, "koKR", {

    ["QUESTTOOLS_TITLE"] = "TEST",
    ["QUESTTOOLS_DESC"] = "Automates quest acceptance, turn-in, reward highlight, and optional quest-labeled gossip. Hold Shift when opening a quest or gossip dialog to skip auto-accept or auto-gossip.",
    ["QUESTTOOLS_TOGGLE_ACCEPT"] = "TEST",
    ["QUESTTOOLS_TOGGLE_ACCEPT_DESC"] = "TEST",
    ["QUESTTOOLS_TOGGLE_TURNIN"] = "TEST",
    ["QUESTTOOLS_TOGGLE_TURNIN_DESC"] = "TEST",
    ["QUESTTOOLS_TOGGLE_REWARDS"] = "TEST",
    ["QUESTTOOLS_TOGGLE_REWARDS_DESC"] = "TEST",
    ["QUESTTOOLS_TOGGLE_GOSSIP"] = "Auto Gossip (quest-labeled lines)",
    ["QUESTTOOLS_TOGGLE_GOSSIP_DESC"] = "Automatically selects gossip options flagged as quest-labeled (QuestLabelPrepend), i.e. the same lines the UI shows with the quest-style label. If more than one qualifies, uses visible line text to decide. Hold Shift while opening gossip to skip. Requires C_GossipInfo and QuestLabelPrepend support (FlagsUtil / Enum.GossipOptionRecFlags) on your client.",
})
