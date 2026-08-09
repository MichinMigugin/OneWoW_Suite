local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["PLAYMOUNTS_TITLE"] = "Spieler-Reittiere",
    ["PLAYMOUNTS_DESC"] = "Erkennt und zeigt das Reittier oder die Fortbewegungsgestalt an, die andere Spieler gerade verwenden.",
    ["PLAYMOUNTS_TOGGLE_CHAT"] = "Im Chat ansagen",
    ["PLAYMOUNTS_TOGGLE_CHAT_DESC"] = "Gibt den Reittiernamen in deinem Chatfenster aus, wenn du einen aufgesessenen Spieler auswählst.",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT"] = "Reittier abgleichen",
    ["PLAYMOUNTS_TOGGLE_MATCHMOUNT_DESC"] = "Fügt bei Spielern eine Rechtsklick-Option hinzu, um ein Reittier desselben Typs zu rufen, das sie gerade reiten.",
    ["PLAYMOUNTS_COLLECTED"] = "(Gesammelt)",
    ["PLAYMOUNTS_NOT_COLLECTED"] = "(Nicht gesammelt)",
    ["PLAYMOUNTS_USING"] = "%s verwendet %s",
    ["PLAYMOUNTS_SOURCE"] = "Quelle: %s",
    ["PLAYMOUNTS_DISPLAYMODE_DESC"] = "Steuert, wie viele Reittierinformationen in Tooltips und Chatausgabe angezeigt werden.",
    ["PLAYMOUNTS_MODE_NAME"] = "Name",
    ["PLAYMOUNTS_MODE_NAMETYPE"] = "Name + Typ",
    ["PLAYMOUNTS_MODE_ALL"] = "Vollständige Details",
    ["PLAYMOUNTS_TOOLTIP_HEADER"] = "Tooltip-Integration",
    ["PLAYMOUNTS_TOOLTIP_REQUIRES"] = "Benötigt: OneWoW Core",
    ["PLAYMOUNTS_TOOLTIP_DETECTED"] = "Status: Erkannt",
    ["PLAYMOUNTS_TOOLTIP_NOT_DETECTED"] = "Status: Nicht erkannt",
    ["PLAYMOUNTS_TOOLTIP_NOTE"] = "Reittier-Tooltipzeilen unter QoL → Tooltips → Spielerreittiere aktivieren oder deaktivieren.",
    ["PLAYMOUNTS_TOOLTIP_VIEW_BTN"] = "Einstellungen anzeigen",
})
