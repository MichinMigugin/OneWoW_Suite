local _, ns = ...
local M = ns.ModuleRegistry:Current()

-- Machine-drafted — deDE, pending native review.
OneWoW.Locale:Register(M._scope, "deDE", {

    ["CRAFTORDERS_TITLE"] = "Handwerksauftrage",
    ["CRAFTORDERS_DESC"] = "Ersetzt die Auftragsliste durch Jetzt herstellbar und Fehlende Materialien. Fehlende Reagenzien auf eine Einkaufsliste setzen. Starten, herstellen und abschliessen mit einer Schaltflache.",
    ["CRAFTORDERS_SECTION_READY"] = "Jetzt herstellbar",
    ["CRAFTORDERS_SECTION_MISSING"] = "Fehlende Materialien",
    ["CRAFTORDERS_WEEKLY_NOT_ACCEPTED"] = "Wochentlich: nicht angenommen",
    ["CRAFTORDERS_WEEKLY_NOT_LEARNED"] = "Wochentlich: nicht erlernt",
    ["CRAFTORDERS_WEEKLY_COMPLETE"] = "Wochentlich: abgeschlossen",
    ["CRAFTORDERS_WEEKLY_PROGRESS"] = "Wochentlich: %d / %d erledigt",
    ["CRAFTORDERS_LOADING"] = "Auftrage werden geladen...",
    ["CRAFTORDERS_ADD_ACTIVE"] = "Zu %s hinzufugen",
    ["CRAFTORDERS_MAKE_LIST"] = "Liste erstellen",
    ["CRAFTORDERS_ADD_MENU_HINT"] = "Rechtsklick, um eine Liste zu erstellen oder eine andere zu wahlen.",
    ["CRAFTORDERS_ELSEWHERE_TIP"] = "Auch in: %s",
    ["CRAFTORDERS_COL_CRAFT"] = "Auftrag",
    ["CRAFTORDERS_COL_YOU"] = "Ihr liefert",
    ["CRAFTORDERS_COL_CART"] = "Liste",
    ["CRAFTORDERS_COL_CUSTOMER"] = "Kunde liefert",
    ["CRAFTORDERS_COL_REWARD"] = "Ihr erhaltet",
    ["CRAFTORDERS_USE_WOWUI"] = "WoW UI",
    ["CRAFTORDERS_USE_ONEUI"] = "One UI",
    ["CRAFTORDERS_TOGGLE_WOWUI"] = "WoW-Liste verwenden",
    ["CRAFTORDERS_TOGGLE_WOWUI_DESC"] = "Blizzards Auftragstabelle statt Jetzt herstellbar und Fehlende Materialien anzeigen.",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED"] = "Nicht erlernte Rezepte ausblenden",
    ["CRAFTORDERS_TOGGLE_HIDE_UNLEARNED_DESC"] = "Auftrage ausblenden, deren Rezept ihr nicht erlernt habt.",
    ["CRAFTORDERS_BUCKET_COUNT"] = "%d Auftrage",
    ["CRAFTORDERS_ORDER_LIST_NAME"] = "Auftrag: %s",
    ["CRAFTORDERS_NO_SHOPPING"] = "Einkaufsliste aktivieren, um Reagenzien hinzuzufugen.",
    ["CRAFTORDERS_KP"] = "%d WP",
    ["CRAFTORDERS_ACUITY"] = "Scharfe x%d",
    ["CRAFTORDERS_INCOMPATIBLE_TITLE"] = "Andere Auftragslisten-Addons",
    ["CRAFTORDERS_INCOMPATIBLE_BODY"] = "%s ist aktiv. Diese Addons bleiben geladen. Schaltet dies ein fuer One UI, oder aus, um sie zu nutzen.",
})
