-- OneWoW_QoL Addon File
-- OneWoW_QoL/Modules/external/questtools/Locales/koKR.lua
-- Created by MichinMuggin (Ricky)
local addonName, ns = ...

if GetLocale() ~= "koKR" then return end

local L_enUS = ns.L_enUS
L_enUS["QUESTTOOLS_TITLE"]                    = "TEST"
L_enUS["QUESTTOOLS_DESC"]                     = "Automates quest acceptance, turn-in, reward highlight, and optional quest-labeled gossip. Hold Shift when opening a quest or gossip dialog to skip auto-accept or auto-gossip."
L_enUS["QUESTTOOLS_TOGGLE_ACCEPT"]            = "TEST"
L_enUS["QUESTTOOLS_TOGGLE_ACCEPT_DESC"]       = "TEST"
L_enUS["QUESTTOOLS_TOGGLE_TURNIN"]            = "TEST"
L_enUS["QUESTTOOLS_TOGGLE_TURNIN_DESC"]       = "TEST"
L_enUS["QUESTTOOLS_TOGGLE_REWARDS"]           = "TEST"
L_enUS["QUESTTOOLS_TOGGLE_REWARDS_DESC"]      = "TEST"
L_enUS["QUESTTOOLS_TOGGLE_GOSSIP"]            = "Auto Gossip (quest-labeled lines)"
L_enUS["QUESTTOOLS_TOGGLE_GOSSIP_DESC"]       = "Automatically selects gossip options flagged as quest-labeled (QuestLabelPrepend), i.e. the same lines the UI shows with the quest-style label. If more than one qualifies, uses visible line text to decide. Hold Shift while opening gossip to skip. Requires C_GossipInfo and QuestLabelPrepend support (FlagsUtil / Enum.GossipOptionRecFlags) on your client."
