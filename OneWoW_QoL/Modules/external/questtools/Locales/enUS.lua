-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/questtools/Locales/enUS.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...
local L_enUS = ns.L_enUS

L_enUS["QUESTTOOLS_TITLE"]                    = "Quest Tools"
L_enUS["QUESTTOOLS_DESC"]                     = "Automates quest acceptance, turn-in, reward highlight, and optional quest-labeled gossip. Hold Shift when opening a quest or gossip dialog to skip auto-accept or auto-gossip."
L_enUS["QUESTTOOLS_TOGGLE_ACCEPT"]            = "Auto Accept Quests"
L_enUS["QUESTTOOLS_TOGGLE_ACCEPT_DESC"]       = "Automatically accept quests when the quest dialog appears. Hold Shift while opening the dialog to skip auto-accept."
L_enUS["QUESTTOOLS_TOGGLE_TURNIN"]            = "Auto Turn In Quests"
L_enUS["QUESTTOOLS_TOGGLE_TURNIN_DESC"]       = "Automatically complete and turn in quests when you have met all requirements. If multiple rewards are available, it waits for you to choose."
L_enUS["QUESTTOOLS_TOGGLE_REWARDS"]           = "Highlight Best Reward"
L_enUS["QUESTTOOLS_TOGGLE_REWARDS_DESC"]      = "Shows a gold coin icon on the quest reward item with the highest vendor sell value."
L_enUS["QUESTTOOLS_TOGGLE_GOSSIP"]            = "Auto Gossip (quest-labeled lines)"
L_enUS["QUESTTOOLS_TOGGLE_GOSSIP_DESC"]       = "Automatically selects gossip options flagged as quest-labeled (QuestLabelPrepend), i.e. the same lines the UI shows with the quest-style label. If more than one qualifies, uses visible line text to decide. Hold Shift while opening gossip to skip. Requires C_GossipInfo and QuestLabelPrepend support (FlagsUtil / Enum.GossipOptionRecFlags) on your client."
