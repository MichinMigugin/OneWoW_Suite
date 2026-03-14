local ADDON_NAME, Addon = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

Addon.COMMON_EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_LOGIN", "PLAYER_LOGOUT",
    "COMBAT_LOG_EVENT_UNFILTERED", "UNIT_HEALTH", "UNIT_POWER_UPDATE",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "BAG_UPDATE", "MERCHANT_SHOW", "MERCHANT_CLOSED",
    "CHAT_MSG_SAY", "CHAT_MSG_PARTY", "CHAT_MSG_GUILD",
    "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED",
    "ACTIONBAR_UPDATE_STATE", "SPELL_UPDATE_USABLE",
    "UPDATE_MOUSEOVER_UNIT", "CURSOR_CHANGED",
}

Addon.COMMON_SCRIPTS = {
    "OnShow", "OnHide", "OnUpdate", "OnEvent", "OnLoad",
    "OnClick", "OnEnter", "OnLeave",
    "OnMouseDown", "OnMouseUp", "OnMouseWheel",
    "OnDragStart", "OnDragStop", "OnReceiveDrag",
    "OnSizeChanged", "OnKeyDown", "OnKeyUp",
    "OnChar", "OnTextChanged", "OnValueChanged",
    "OnEditFocusGained", "OnEditFocusLost",
    "OnAttributeChanged",
    "OnGamePadButtonDown", "OnGamePadButtonUp", "OnGamePadStick",
    "OnHyperlinkClick", "OnHyperlinkEnter", "OnHyperlinkLeave",
    "OnDisable", "OnEnable",
}
